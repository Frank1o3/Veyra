#!/usr/bin/env bash
set -euo pipefail

: "${CACHE_PATHS:?CACHE_PATHS must contain newline-separated package cache directories}"
: "${MANIFEST_PATH:=.veyra-cache/package-manifest.tsv}"

mapfile -t cache_dirs < <(printf '%s\n' "$CACHE_PATHS" | sed '/^[[:space:]]*$/d')
if (("${#cache_dirs[@]}" == 0)); then
    echo "No package cache paths were provided." >&2
    exit 2
fi

is_package_archive() {
    case "$1" in
        *.pkg.tar.zst|*.pkg.tar.xz|*.pkg.tar.gz|*.pkg.tar.bz2|*.pkg.tar.lrz|*.pkg.tar.lzo|*.pkg.tar.Z|*.pkg.tar.lz4|*.pkg.tar.lz)
            return 0 ;;
        *) return 1 ;;
    esac
}

# Print metadata as tab-separated fields to avoid parsing package names,
# versions, and architectures as shell words.
package_metadata() {
    pacman -Qp --print-format '%n\t%v\t%a' "$1" 2>/dev/null
}

validate_archives() {
    local dir file metadata invalid=0
    for dir in "${cache_dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r -d '' file; do
            is_package_archive "$file" || continue
            if ! metadata="$(package_metadata "$file")" || [[ -z "$metadata" ]]; then
                echo "Removing unreadable package archive: $file" >&2
                rm -f -- "$file"
                invalid=1
            fi
        done < <(find "$dir" -type f -print0)
    done
    if (( invalid )); then
        echo "Invalid cached archives were removed; pacman can download them again."
    fi
}

# Keep only the newest version of each package/architecture in each cache
# directory. This avoids repo-add publishing several versions of one package.
# Separate profile directories remain independent (generic, v3, v4, znver4).
prune_old_versions() {
    local dir file metadata name version architecture key previous
    declare -A latest_version latest_file

    for dir in "${cache_dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        latest_version=()
        latest_file=()

        while IFS= read -r -d '' file; do
            is_package_archive "$file" || continue
            metadata="$(package_metadata "$file")" || continue
            IFS=$'\t' read -r name version architecture <<< "$metadata"
            [[ -n "$name" && -n "$version" && -n "$architecture" ]] || continue
            key="$name"$'\t'"$architecture"
            previous="${latest_version[$key]-}"
            if [[ -z "$previous" ]] || [[ "$(vercmp "$version" "$previous")" -gt 0 ]]; then
                latest_version[$key]="$version"
                latest_file[$key]="$file"
            fi
        done < <(find "$dir" -type f -print0)

        while IFS= read -r -d '' file; do
            is_package_archive "$file" || continue
            metadata="$(package_metadata "$file")" || continue
            IFS=$'\t' read -r name version architecture <<< "$metadata"
            [[ -n "$name" && -n "$version" && -n "$architecture" ]] || continue
            key="$name"$'\t'"$architecture"
            if [[ "${latest_file[$key]-}" != "$file" ]]; then
                echo "Pruning superseded archive: $file" >&2
                rm -f -- "$file"
            fi
        done < <(find "$dir" -type f -print0)
    done
}

write_manifest() {
    local dir file metadata checksum name version architecture
    local temp
    mkdir -p "$(dirname "$MANIFEST_PATH")"
    temp="$(mktemp)"
    trap 'rm -f -- "$temp"' RETURN

    printf 'name\tversion\tarchitecture\tsha256\tarchive\n' > "$temp"
    for dir in "${cache_dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r -d '' file; do
            is_package_archive "$file" || continue
            metadata="$(package_metadata "$file")" || continue
            IFS=$'\t' read -r name version architecture <<< "$metadata"
            [[ -n "$name" && -n "$version" && -n "$architecture" ]] || continue
            checksum="$(sha256sum "$file" | cut -d ' ' -f1)"
            printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$version" "$architecture" "$checksum" "$file" >> "$temp"
        done < <(find "$dir" -type f -print0)
    done

    { head -n 1 "$temp"; tail -n +2 "$temp" | sort -t $'\t' -k1,1 -k2,2 -k5,5; } > "$MANIFEST_PATH"
    echo "Wrote package manifest: $MANIFEST_PATH"
}

case "${1:-}" in
    validate) validate_archives ;;
    prune) prune_old_versions ;;
    manifest) write_manifest ;;
    all)
        validate_archives
        prune_old_versions
        write_manifest
        ;;
    *)
        echo "Usage: $0 {validate|prune|manifest|all}" >&2
        exit 2
        ;;
esac
