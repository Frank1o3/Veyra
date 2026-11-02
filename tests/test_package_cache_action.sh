#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${ROOT}/.github/actions/veyra-package-cache/scripts/package-cache.sh"
TEMP="$(mktemp -d)"
trap 'rm -rf -- "$TEMP"' EXIT
mkdir -p "$TEMP/bin" "$TEMP/cache"

cat > "$TEMP/bin/pacman" <<'MOCK_PACMAN'
#!/usr/bin/env bash
file="${!#}"
base="${file##*/}"
if [[ "$base" =~ ^(.+)-([0-9][0-9.]*-[0-9]+)-([^-]+)\.pkg\.tar\.zst$ ]]; then
    printf '%s\t%s\t%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
else
    exit 1
fi
MOCK_PACMAN

cat > "$TEMP/bin/vercmp" <<'MOCK_VERCMP'
#!/usr/bin/env bash
[[ "$1" == "$2" ]] && { echo 0; exit; }
first="$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n 1)"
if [[ "$first" == "$1" ]]; then
    echo -1
else
    echo 1
fi
MOCK_VERCMP
chmod +x "$TEMP/bin/pacman" "$TEMP/bin/vercmp"

printf 'old package' > "$TEMP/cache/demo-1.0-1-x86_64.pkg.tar.zst"
printf 'new package' > "$TEMP/cache/demo-2.0-1-x86_64.pkg.tar.zst"
printf 'unreadable package' > "$TEMP/cache/not-a-package.pkg.tar.zst"

export PATH="$TEMP/bin:$PATH"
export CACHE_PATHS="$TEMP/cache"
export MANIFEST_PATH="$TEMP/manifest.tsv"

bash "$SCRIPT" validate
[[ ! -e "$TEMP/cache/not-a-package.pkg.tar.zst" ]]
bash "$SCRIPT" prune
[[ ! -e "$TEMP/cache/demo-1.0-1-x86_64.pkg.tar.zst" ]]
[[ -e "$TEMP/cache/demo-2.0-1-x86_64.pkg.tar.zst" ]]
bash "$SCRIPT" manifest
[[ "$(awk 'END { print NR }' "$MANIFEST_PATH")" -eq 2 ]]
grep -q $'^demo\t2.0-1\tx86_64\t[0-9a-f]\{64\}\t' "$MANIFEST_PATH"

echo "Package cache helper tests passed."
