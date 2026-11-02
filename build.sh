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
command -v rsync >/dev/null || {
    echo "rsync is missing; install it before building the ISO." >&2
    exit 1
}
command -v repo-add >/dev/null || {
    echo "repo-add is missing; install pacman before building the ISO." >&2
    exit 1
}
command -v rate-mirrors >/dev/null || {
    echo "rate-mirrors is missing. Install the rate-mirrors package first." >&2
    exit 1
}

# Keep cached package archives outside /var/cache/pacman/pkg: mkarchiso removes
# that directory during cleanup. The ISO uses these as local package repos for
# the full offline pacstrap transaction.
KERNEL_CACHE="${PROFILE_DIR}/airootfs/usr/share/veyra/kernel-cache"
PACKAGE_CACHE="${PROFILE_DIR}/airootfs/usr/share/veyra/package-cache"
DOTFILES_SOURCE="${DOTFILES_SOURCE:-${REPO_DIR%/*}/dotfiles}"
DOTFILES_STAGE="${PROFILE_DIR}/airootfs/usr/share/veyra/dotfiles"
MIRRORLIST_STAGE="${PROFILE_DIR}/airootfs/etc/pacman.d"
RANKED_MIRRORS="$(mktemp -d)"
mkdir -p "$OUT_DIR"

if [[ ! -f "$DOTFILES_SOURCE/setup.sh" ]]; then
    echo "Dotfiles checkout not found at ${DOTFILES_SOURCE}. Set DOTFILES_SOURCE to its path." >&2
    exit 1
fi
mkdir -p "$(dirname -- "$DOTFILES_STAGE")"
trap 'rm -rf -- "$DOTFILES_STAGE" "$RANKED_MIRRORS"' EXIT
rsync -a --delete --exclude=.git --exclude=nvim "$DOTFILES_SOURCE/" "$DOTFILES_STAGE/"

stage_cache() (
    local cache_dir="$1" label="$2" repo_suffix="$3" mirrorlist="$4" config staging_root stamp
    shift 4
    config="$(mktemp)"
    staging_root="$(mktemp -d)"
    stamp="${cache_dir}/.veyra-cache-complete"
    trap 'rm -f -- "$config"; sudo rm -rf -- "$staging_root"' EXIT
    mkdir -p "${staging_root}/var/lib/pacman"
    mkdir -p "$cache_dir"
    # Keep restored package archives between CI runs. The custom GitHub
    # Actions cache validates and prunes superseded versions before this step;
    # Pacman fetches newer versions as needed. Only rebuild generated repo DBs.
    sudo rm -f "$cache_dir"/*.db* "$cache_dir"/*.files* "$stamp"
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
    echo "Staging ${label} packages in the ISO..."
    # Use an empty local package database so dependencies already installed on
    # the build host are still included in the ISO cache.
    sudo pacman --config "$config" --root "$staging_root" \
        --dbpath "${staging_root}/var/lib/pacman" \
        --gpgdir /etc/pacman.d/gnupg \
        --cachedir "$cache_dir" \
        -Syw --noconfirm "$@"
    if [[ "$label" == kernel* ]]; then
        # Cache the conflicting NVIDIA branches in separate transactions.
        sudo pacman --config "$config" --root "$staging_root" \
            --dbpath "${staging_root}/var/lib/pacman" \
            --gpgdir /etc/pacman.d/gnupg --cachedir "$cache_dir" \
            -Sw --noconfirm nvidia-open-dkms nvidia-utils lib32-nvidia-utils
        sudo pacman --config "$config" --root "$staging_root" \
            --dbpath "${staging_root}/var/lib/pacman" \
            --gpgdir /etc/pacman.d/gnupg --cachedir "$cache_dir" \
            -Sw --noconfirm nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils
    fi
    # repo-add writes both the normal .db and the package file-list .files DB.
    (cd "$cache_dir" && sudo repo-add "veyra-${label}.db.tar.gz" ./*.pkg.tar.zst)
    sudo chown -R "$(id -u):$(id -g)" "$cache_dir"
    touch "$stamp"
)

# Hardware packages live beside kernels, in each kernel profile cache, so
# driver and kernel snapshots stay compatible. Keep these names in sync with
# hardware.py's selection logic.
KERNEL_HARDWARE_PACKAGES=(
    linux-cachyos linux-cachyos-lts linux-cachyos-headers linux-firmware
    intel-ucode amd-ucode mesa vulkan-intel intel-media-driver
    vulkan-radeon dkms
    vulkan-icd-loader lib32-vulkan-icd-loader
)

# Extract the installer's baseline list without importing its third-party UI
# dependencies on the build host. Repository dependencies are resolved by
# pacman and every downloaded archive is retained as the offline snapshot.
PACKAGE_LIST_FILE="$(mktemp)"
python3 - "$REPO_DIR/veyra-iso/airootfs/usr/local/lib/veyra/veyra-installer/src/veyra_installer/config.py" > "$PACKAGE_LIST_FILE" <<'PY'
import ast
import sys

tree = ast.parse(open(sys.argv[1], encoding="utf-8").read())
for node in tree.body:
    if isinstance(node, ast.Assign) and any(
        isinstance(target, ast.Name) and target.id == "BASE_PACKAGES"
        for target in node.targets
    ):
        packages = ast.literal_eval(node.value)
        excluded = {"linux-firmware", "cachyos-rate-mirrors"}
        print("\n".join(package for package in packages if package not in excluded
                           and not package.startswith("linux-cachyos")))
        break
else:
    raise SystemExit("Could not find BASE_PACKAGES in installer config.py")
PY
mapfile -t BASE_CACHE_PACKAGES < "$PACKAGE_LIST_FILE"
rm -f -- "$PACKAGE_LIST_FILE"
BASE_CACHE_PACKAGES+=(cachyos-v3-mirrorlist cachyos-v4-mirrorlist)

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
        sudo rm -rf -- "${KERNEL_CACHE}/${profile}"
        sudo rm -rf -- "${PACKAGE_CACHE}/${profile}"
    fi
done

for profile in "${profiles[@]}"; do
    case "$profile" in
        generic)
            mkdir -p "${KERNEL_CACHE}/generic"
            stage_cache "${KERNEL_CACHE}/generic" kernel "" "" "${KERNEL_HARDWARE_PACKAGES[@]}"
            mkdir -p "${PACKAGE_CACHE}/generic"
            stage_cache "${PACKAGE_CACHE}/generic" packages-generic "" "" "${BASE_CACHE_PACKAGES[@]}"
            ;;
        v3)
            mkdir -p "${KERNEL_CACHE}/v3"
            stage_cache "${KERNEL_CACHE}/v3" kernel-v3 "-v3" "cachyos-v3-mirrorlist" "${KERNEL_HARDWARE_PACKAGES[@]}"
            mkdir -p "${PACKAGE_CACHE}/v3"
            stage_cache "${PACKAGE_CACHE}/v3" packages-v3 "-v3" "cachyos-v3-mirrorlist" "${BASE_CACHE_PACKAGES[@]}"
            ;;
        v4)
            mkdir -p "${KERNEL_CACHE}/v4"
            stage_cache "${KERNEL_CACHE}/v4" kernel-v4 "-v4" "cachyos-v4-mirrorlist" "${KERNEL_HARDWARE_PACKAGES[@]}"
            mkdir -p "${PACKAGE_CACHE}/v4"
            stage_cache "${PACKAGE_CACHE}/v4" packages-v4 "-v4" "cachyos-v4-mirrorlist" "${BASE_CACHE_PACKAGES[@]}"
            ;;
        znver4)
            mkdir -p "${KERNEL_CACHE}/znver4"
            stage_cache "${KERNEL_CACHE}/znver4" kernel-znver4 "-znver4" "cachyos-v4-mirrorlist" "${KERNEL_HARDWARE_PACKAGES[@]}"
            mkdir -p "${PACKAGE_CACHE}/znver4"
            stage_cache "${PACKAGE_CACHE}/znver4" packages-znver4 "-znver4" "cachyos-v4-mirrorlist" "${BASE_CACHE_PACKAGES[@]}"
            ;;
    esac
done

# Embed mirror rankings made on the build network. rate-mirrors writes only to
# this temporary directory, so the build never edits the host's /etc files.
echo "Ranking Arch and CachyOS mirrors for the live ISO..."
rate-mirrors --allow-root --save "${RANKED_MIRRORS}/mirrorlist" arch
rate-mirrors --allow-root --save "${RANKED_MIRRORS}/cachyos-mirrorlist" cachyos
mkdir -p "$MIRRORLIST_STAGE"
install -m 0644 "${RANKED_MIRRORS}/mirrorlist" "${MIRRORLIST_STAGE}/mirrorlist"
install -m 0644 "${RANKED_MIRRORS}/cachyos-mirrorlist" "${MIRRORLIST_STAGE}/cachyos-mirrorlist"
install -m 0644 "${RANKED_MIRRORS}/cachyos-mirrorlist" "${MIRRORLIST_STAGE}/cachyos-v3-mirrorlist"
install -m 0644 "${RANKED_MIRRORS}/cachyos-mirrorlist" "${MIRRORLIST_STAGE}/cachyos-v4-mirrorlist"
sed -i 's|/$arch/|/$arch_v3/|g' "${MIRRORLIST_STAGE}/cachyos-v3-mirrorlist"
sed -i 's|/$arch/|/$arch_v4/|g' "${MIRRORLIST_STAGE}/cachyos-v4-mirrorlist"

cd "$REPO_DIR"
sudo mkarchiso -r -v -o "$OUT_DIR" "$PROFILE_DIR"
echo "ISO build complete: ${OUT_DIR}"
