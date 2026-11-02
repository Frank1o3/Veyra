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
    [[ "$1" == *.pkg.tar.zst || "$1" == *.pkg.tar.xz || "$1" == *.pkg.tar.gz ]]
}

validate_archives() {
    local dir file metadata
    local invalid=0

    for dir in "${cache_dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r -d '' file; do
            is_package_archive "$file" || continue
            if ! metadata="$(pacman -Qp --print-format '%n %v %a' "$file" 2>/dev/null)" || [[ -z "$metadata" ]]; then
                echo "Removing invalid package archive: $file" >&2
                rm -f -- "$file"
                invalid=1
            fi
        done < <(find "$dir" -type f -print0)
    done

    if (( invalid )); then
        echo "Invalid cached archives were removed; the package manager can download them again."
    fi
}

write_manifest() {
    local dir file metadata checksum name version architecture
    mkdir -p "$(dirname "$MANIFEST_PATH")"
    local temp
    temp="$(mktemp)"

    printf 'name\tversion\tarchitecture\tsha256\tarchive\n' > "$temp"
    for dir in "${cache_dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r -d '' file; do
            is_package_archive "$file" || continue
            metadata="$(pacman -Qp --print-format '%n %v %a' "$file" 2>/dev/null)" || continue
            read -r name version architecture <<< "$metadata"
            checksum="$(sha256sum "$file" | cut -d ' ' -f1)"
            printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$version" "$architecture" "$checksum" "$file" >> "$temp"
        done < <(find "$dir" -type f -print0)
    done

    { head -n 1 "$temp"; tail -n +2 "$temp" | sort -t $'\t' -k1,1 -k2,2 -k5,5; } > "$MANIFEST_PATH"
    rm -f "$temp"
    echo "Wrote package manifest: $MANIFEST_PATH"
}

case "${1:-}" in
    validate) validate_archives ;;
    manifest) write_manifest ;;
    *)
        echo "Usage: $0 {validate|manifest}" >&2
        exit 2
        ;;
esac
