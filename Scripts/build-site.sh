#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
website_directory="$repository_root/Website"
website_dist_directory="$website_directory/dist"
documentation_directory="$repository_root/docs"
hosting_base_path="pathways-swift/documentation/pathways"
preview_port="${PORT:-4321}"

mode="build"

usage() {
    echo "Usage: $0 [--setup|--validate-only|--preview]" >&2
}

require_website() {
    if [[ ! -f "$website_directory/package.json" ]]; then
        echo "Website/package.json is required. Add the Astro site before running this command." >&2
        exit 1
    fi
}

run_setup() {
    require_website

    if [[ -f "$website_directory/package-lock.json" ]]; then
        (cd "$website_directory" && npm ci)
    else
        (cd "$website_directory" && npm install)
    fi
}

run_astro_check() {
    if [[ -x "$website_directory/node_modules/.bin/astro" ]]; then
        (cd "$website_directory" && ./node_modules/.bin/astro check)
        return
    fi

    echo "Astro is not installed. Run 'make site-setup' first." >&2
    exit 1
}

assemble_site() {
    local output_directory="$1"

    run_astro_check
    (cd "$website_directory" && npm run build)

    if [[ ! -d "$website_dist_directory" ]]; then
        echo "Astro did not create Website/dist." >&2
        exit 1
    fi

    mkdir -p "$output_directory"
    cp -R "$website_dist_directory/." "$output_directory/"

    swift package --allow-writing-to-directory "$output_directory" generate-documentation \
        --target Pathways \
        --output-path "$output_directory/documentation/pathways" \
        --disable-indexing \
        --transform-for-static-hosting \
        --hosting-base-path "$hosting_base_path"

    node "$repository_root/Scripts/normalize-site-json.mjs" \
        "$output_directory/documentation/pathways"

    if [[ ! -f "$website_dist_directory/documentation/pathways/index.html" ]]; then
        echo "Astro did not create the Pathways module landing page." >&2
        exit 1
    fi
    cp "$website_dist_directory/documentation/pathways/index.html" \
        "$output_directory/documentation/pathways/index.html"

    node "$repository_root/Scripts/check-site-links.mjs" "$output_directory" "pathways-swift"
}

case "${1:-}" in
    "")
        ;;
    --setup)
        mode="setup"
        ;;
    --validate-only)
        mode="validate"
        ;;
    --preview)
        mode="preview"
        ;;
    *)
        usage
        exit 2
        ;;
esac

if [[ "$mode" == "setup" ]]; then
    run_setup
    exit 0
fi

require_website
mkdir -p "$repository_root/.build"
staging_root="$(mktemp -d "$repository_root/.build/site.XXXXXX")"
cleanup_staging() {
    rm -rf "$staging_root"
}
trap cleanup_staging EXIT

if [[ "$mode" == "preview" ]]; then
    preview_root="$staging_root/preview"
    assemble_site "$preview_root/pathways-swift"
    echo "Preview: http://localhost:$preview_port/pathways-swift/"
    python3 -m http.server "$preview_port" --directory "$preview_root"
    exit 0
fi

assembled_site="$staging_root/docs"
assemble_site "$assembled_site"

if [[ "$mode" == "validate" ]]; then
    echo "Site validation passed."
    exit 0
fi

backup_directory="$repository_root/.build/docs-backup"
rm -rf "$backup_directory"

if [[ -e "$documentation_directory" ]]; then
    mv "$documentation_directory" "$backup_directory"
fi

if ! mv "$assembled_site" "$documentation_directory"; then
    if [[ -e "$backup_directory" ]]; then
        mv "$backup_directory" "$documentation_directory"
    fi
    echo "Could not replace docs. The previous docs were restored." >&2
    exit 1
fi

rm -rf "$backup_directory"
touch "$documentation_directory/.nojekyll"
echo "Built $documentation_directory"
