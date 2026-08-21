#!/usr/bin/env node
// @ts-check

import { readdir, readFile, writeFile } from "node:fs/promises";
import { extname, resolve } from "node:path";

const [rootArgument] = process.argv.slice(2);

if (!rootArgument) {
    console.error("Usage: normalize-site-json.mjs <directory>");
    process.exit(2);
}

/** @param {unknown} value @returns {unknown} */
function sorted(value) {
    if (Array.isArray(value)) {
        return value.map(sorted);
    }
    if (typeof value !== "object" || value === null) {
        return value;
    }

    /** @type {Record<string, unknown>} */
    const result = {};
    for (const key of Object.keys(value).sort()) {
        result[key] = sorted(/** @type {Record<string, unknown>} */ (value)[key]);
    }
    return result;
}

/** @param {string} directory */
async function normalizeDirectory(directory) {
    const entries = await readdir(directory, { withFileTypes: true });
    await Promise.all(entries.map(async (entry) => {
        const path = resolve(directory, entry.name);
        if (entry.isDirectory()) {
            await normalizeDirectory(path);
        } else if (entry.isFile() && extname(entry.name) === ".json") {
            const value = JSON.parse(await readFile(path, "utf8"));
            await writeFile(path, `${JSON.stringify(sorted(value))}\n`, "utf8");
        }
    }));
}

await normalizeDirectory(resolve(rootArgument));
