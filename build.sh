#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="${REPO_DIR}/veyra-iso"
OUT_DIR="${REPO_DIR}/out"
KERNEL_PROFILES="${KERNEL_PROFILES:-generic,v3,v4,znver4}"

command -v mkarchiso >/dev/null || {
    echo "mkarchiso is missing. Install the archiso package first." >&2
    exit 1
}

# Keep kernel package archives outside /var/cache/pacman/pkg: mkarchiso removes
# that directory during cleanup. These archives are installed by the ISO's
# first pacstrap stage before the network package transaction begins.
KERNEL_CACHE="${PROFILE_DIR}/airootfs/usr/share/veyra/kernel-cache"
mkdir -p "$OUT_DIR"

stage_kernel_cache() (
    local profile="$1" repo_suffix="$2" mirrorlist="$3" config staging_root
    config="$(mktemp)"
    staging_root="$(mktemp -d)"
    trap 'rm -f -- "$config"; sudo rm -rf -- "$staging_root"' EXIT
    mkdir -p "${staging_root}/var/lib/pacman"
    rm -f "${KERNEL_CACHE}/${profile}"/*.pkg.tar.*
    if [[ -n "$repo_suffix" ]]; then
        awk -v suffix="$repo_suffix" -v mirrorlist="$mirrorlist" '
            /^\[cachyos\]$/ {
                print "[cachyos" suffix "]"
                print "Include = /etc/pacman.d/" mirrorlist ""
                print ""
                print "[cachyos-core" suffix "]"
                print "Include = /etc/pacman.d/" mirrorlist ""
                print ""
                print "[cachyos-extra" suffix "]"
                print "Include = /etc/pacman.d/" mirrorlist ""
                print ""
            }
            { print }
        ' "${PROFILE_DIR}/pacman.conf" > "$config"
    else
        cp "${PROFILE_DIR}/pacman.conf" "$config"
    fi
    # The cached files are not executed on the build host. Allow pacman to
    # accept the optimized archive architectures while fetching each repo.
    sed -i 's/^Architecture = auto$/Architecture = x86_64 x86_64_v3 x86_64_v4/' "$config"
    echo "Staging CachyOS ${profile} kernel packages in the ISO..."
    # Use an empty local package database so dependencies already installed on
    # the build host are still included in the ISO cache.
    sudo pacman --config "$config" --root "$staging_root" \
        --dbpath "${staging_root}/var/lib/pacman" \
        --gpgdir /etc/pacman.d/gnupg \
        --cachedir "${KERNEL_CACHE}/${profile}" \
        -Syw --noconfirm linux-cachyos linux-cachyos-lts linux-cachyos-headers
)

IFS=',' read -r -a profiles <<< "$KERNEL_PROFILES"
if ((${#profiles[@]} == 0)); then
    echo "KERNEL_PROFILES must include at least one profile." >&2
    exit 1
fi

for profile in "${profiles[@]}"; do
    case "$profile" in
        generic|v3|v4|znver4) ;;
        *)
            echo "Unknown kernel profile '${profile}'. Use generic,v3,v4,znver4." >&2
            exit 1
            ;;
    esac
done

for profile in generic v3 v4 znver4; do
    if [[ ",$KERNEL_PROFILES," != *",$profile,"* ]]; then
        rm -rf -- "${KERNEL_CACHE}/${profile}"
    fi
done

for profile in "${profiles[@]}"; do
    case "$profile" in
        generic)
            mkdir -p "${KERNEL_CACHE}/generic"
            stage_kernel_cache generic "" ""
            ;;
        v3)
            mkdir -p "${KERNEL_CACHE}/v3"
            stage_kernel_cache v3 "-v3" "cachyos-v3-mirrorlist"
            ;;
        v4)
            mkdir -p "${KERNEL_CACHE}/v4"
            stage_kernel_cache v4 "-v4" "cachyos-v4-mirrorlist"
            ;;
        znver4)
            mkdir -p "${KERNEL_CACHE}/znver4"
            stage_kernel_cache znver4 "-znver4" "cachyos-v4-mirrorlist"
            ;;
    esac
done

cd "$REPO_DIR"
sudo mkarchiso -r -v -o "$OUT_DIR" "$PROFILE_DIR"
echo "ISO build complete: ${OUT_DIR}"
