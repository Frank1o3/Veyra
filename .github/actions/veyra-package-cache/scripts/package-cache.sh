#!/usr/bin/env bash
set -euo pipefail

: "${CACHE_PATHS:?CACHE_PATHS must contain newline-separated package cache directories}"
: "${MANIFEST_PATH:=.veyra-cache/package-manifest.tsv}"

mapfile -t cache_dirs < <(printf '%s\n' "$CACHE_PATHS" | sed '/^[[:space:]]*$/d')

if (("${#cache_dirs[@]}" == 0)); then
    echo "No package cache paths were provided." >&2
    exit 2
fi

validate_archives() {
    local dir file metadata
    local invalid=0

    for dir in "${cache_dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r -d '' file; do
            # Only package archives belong in the reusable cache.
            [[ "$file" == *.pkg.tar.zst || "$file" == *.pkg.tar.xz || "$file" == *.pkg.tar.gz ]] || continue
            if ! metadata="$(pacman -Qp --print-format '%n\t%v\t%a' "$file" 2>/dev/null)"; then
                echo "Removing invalid package archive: $file" >&2
                rm -f -- "$file"
                invalid=1
                continue
            fi
            [[ -n "$metadata" ]] || {
                echo "Removing package archive with empty metadata: $file" >&2
                rm -f -- "$file"
                invalid=1
            }
        done < <(find "$dir" -type f -print0)
    done

    if (( invalid )); then
        echo "Invalid cached archives were removed; the package manager can download them again."
    fi
}

write_manifest() {
    local dir file metadata checksum relative
    mkdir -p "$(dirname "$MANIFEST_PATH")"
    local temp
    temp="$(mktemp)"
    trap 'rm -f "$temp"' RETURN

    printf 'name\tversion\tarchitecture\tsha256\tarchive\n' > "$temp"
    for dir in "${cache_dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r -d '' file; do
            [[ "$file" == *.pkg.tar.zst || "$file" == *.pkg.tar.xz || "$file" == *.pkg.tar.gz ]] || continue
            metadata="$(pacman -Qp --print-format '%n\t%v\t%a' "$file" 2>/dev/null)" || continue
            checksum="$(sha256sum "$file" | cut -d ' ' -f1)"
            relative="$file"
            printf '%s\t%s\t%s\t%s\t%s\n' ${metadata//$'\t'/$'\t'} "$checksum" "$relative" >> "$temp"
        done < <(find "$dir" -type f -print0)
    done

    # Stable ordering makes the manifest diffable and useful as a build artifact.
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
