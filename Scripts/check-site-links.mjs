#!/usr/bin/env node
// @ts-check

import { existsSync, readdirSync, readFileSync } from "node:fs";
import { resolve, dirname, extname, relative, sep } from "node:path";

const [siteRootArgument, hostingBasePath] = process.argv.slice(2);

if (!siteRootArgument || !hostingBasePath) {
    console.error("Usage: check-site-links.mjs <site-root> <hosting-base-path>");
    process.exit(2);
}

const siteRoot = resolve(siteRootArgument);
const hostingPrefix = `/${hostingBasePath.replace(/^\/+|\/+$/g, "")}`;
/** @type {string[]} */
const htmlFiles = [];

/** @param {string} directory */
function collectHtmlFiles(directory) {
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
        const entryPath = resolve(directory, entry.name);
        if (entry.isDirectory()) {
            collectHtmlFiles(entryPath);
        } else if (entry.isFile() && extname(entry.name) === ".html") {
            htmlFiles.push(entryPath);
        }
    }
}

/** @param {string} path */
function isInsideSite(path) {
    const pathFromRoot = relative(siteRoot, path);
    return !pathFromRoot.startsWith(`..${sep}`) && pathFromRoot !== "..";
}

/** @param {string} path */
function existingTarget(path) {
    if (existsSync(path)) {
        return true;
    }
    if (existsSync(`${path}.html`)) {
        return true;
    }
    return existsSync(resolve(path, "index.html"));
}

/** @param {string} reference @param {string} sourceFile @returns {string | null} */
function targetFor(reference, sourceFile) {
    const pathOnly = reference.split(/[?#]/, 1)[0];
    if (!pathOnly || pathOnly.startsWith("#") || /^(data:|mailto:|tel:|https?:|\/\/)/i.test(pathOnly)) {
        return null;
    }

    if (pathOnly.startsWith("/")) {
        if (pathOnly !== hostingPrefix && !pathOnly.startsWith(`${hostingPrefix}/`)) {
            return resolve(siteRoot, "..", pathOnly.slice(1));
        }
        return resolve(siteRoot, pathOnly.slice(hostingPrefix.length).replace(/^\//, ""));
    }

    return resolve(dirname(sourceFile), pathOnly);
}

collectHtmlFiles(siteRoot);
/** @type {string[]} */
const failures = [];
const attributePattern = /(?:href|src)=["']([^"']+)["']/gi;

for (const htmlFile of htmlFiles) {
    const html = readFileSync(htmlFile, "utf8");
    for (const match of html.matchAll(attributePattern)) {
        const reference = match[1];
        const target = targetFor(reference, htmlFile);
        if (target && (!isInsideSite(target) || !existingTarget(target))) {
            failures.push(`${relative(siteRoot, htmlFile)} -> ${reference}`);
        }
    }
}

if (failures.length > 0) {
    console.error("Broken internal links:");
    for (const failure of failures) {
        console.error(`  ${failure}`);
    }
    process.exit(1);
}

console.log(`Validated internal links in ${htmlFiles.length} HTML files.`);
