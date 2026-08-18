#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_directory="$repository_root/.build/documentation"
derived_data_directory="$output_directory/DerivedData"
archive_directory="$output_directory/archives"
archive_path="$output_directory/Pathways-Documentation.zip"
archive_name="Pathways.doccarchive"

mkdir -p "$output_directory"
rm -rf "$archive_directory"
rm -f "$archive_path"
mkdir -p "$archive_directory"

xcodebuild docbuild \
    -scheme Pathways \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$derived_data_directory"

archive_source="$(find "$derived_data_directory/Build/Products" -type d -name "$archive_name" -print -quit)"
if [[ -z "$archive_source" ]]; then
    echo "Expected documentation archive was not generated: $archive_name" >&2
    exit 1
fi
cp -R "$archive_source" "$archive_directory/$archive_name"

(
    cd "$archive_directory"
    zip -qry "$archive_path" "$archive_name"
)

unzip -tq "$archive_path" >/dev/null
echo "Created $archive_path"
