# =====================================================================
# Append this block to your config.py.
# Everything the other modules import from config is either in your
# existing constants (LOG_FILE, MOUNT, DOTFILES_URL, BTRFS_OPTS,
# BASE_PACKAGES, XKB_TO_CONSOLE, V3_FLAGS) or in this block.
# =====================================================================

# --- Defaults offered by the prompts ---
DEFAULT_HOSTNAME = "veyra"
DEFAULT_LOCALE = "en_US.UTF-8"
DEFAULT_TIMEZONE = "America/Santo_Domingo"

# --- Disk layout ---
ESP_SIZE_MIB = 1024
MIN_ROOT_GIB = 20
SWAP_ROUND_GIB = 1  # swap = installed RAM rounded UP to this many GiB (hibernation)
SWAP_PRIORITY = 10  # disk swap; zram uses 100 so it is preferred

# (subvolume, mountpoint). "@" MUST be first. No @snapshots: snapper nests
# .snapshots inside @, which limine-snapper-sync expects.
SUBVOLUMES = [
    ("@", "/"),
    ("@home", "/home"),
    ("@cache", "/var/cache"),  # keeps pacman cache out of snapshots
    ("@var_log", "/var/log"),
    ("@tmp", "/var/tmp"),
]

# --- zram ---
ZRAM_CONF = """[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
"""

ZRAM_SYSCTL = """vm.swappiness = 150
vm.page-cluster = 0
"""

# --- Snapper: your current "tune", unchanged ---
SNAPPER_CONF = """SUBVOLUME="/"
FSTYPE="btrfs"
QGROUP=""
SPACE_LIMIT="0.5"
FREE_LIMIT="0.2"
ALLOW_USERS=""
ALLOW_GROUPS=""
SYNC_ACL="no"
BACKGROUND_COMPARISON="yes"
NUMBER_CLEANUP="yes"
NUMBER_MIN_AGE="1800"
NUMBER_LIMIT="3"
NUMBER_LIMIT_IMPORTANT="1"
TIMELINE_CREATE="yes"
TIMELINE_CLEANUP="yes"
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="2"
TIMELINE_LIMIT_DAILY="2"
TIMELINE_LIMIT_WEEKLY="1"
TIMELINE_LIMIT_MONTHLY="0"
TIMELINE_LIMIT_YEARLY="0"
EMPTY_PRE_POST_CLEANUP="yes"
EMPTY_PRE_POST_MIN_AGE="1800"
"""

# --- Bootloader ---
# No `quiet splash`: kernel messages stay visible. resume= enables hibernation.
KERNEL_CMDLINE = (
    "rw rootflags=subvol=/@ root=UUID={root_uuid} resume=UUID={swap_uuid} "
    "nowatchdog loglevel=6"
)

LIMINE_BASE_CONF = """timeout: 3
graphics: yes
interface_branding: Veyra OS

/+Veyra OS
"""

LIMINE_DEFAULT = """ESP_PATH="/boot"
TARGET_OS_NAME="Veyra OS"
KERNEL_CMDLINE[default]+="{cmdline}"
BOOT_ORDER="*, *lts, *fallback, Snapshots"
LIMIT_USAGE_PERCENT=85
SNAPPER_CONFIG_NAME="root"
ROOT_SUBVOLUME_PATH="/@"
ROOT_SNAPSHOTS_PATH="/@/.snapshots"
RESTORE_METHOD=replace
SNAPSHOT_FORMAT_CHOICE=2
"""

# --- Services (enabled inside the chroot) ---
SERVICES_ENABLE = [
    "NetworkManager",
    "sddm",
    "bluetooth",
    "systemd-timesyncd",
    "snapper-timeline.timer",
    "snapper-cleanup.timer",
    "limine-snapper-sync.service",
    "fstrim.timer",
    "paccache.timer",
    "btrfs-scrub@-.timer",  # monthly integrity scrub of "/"
]
SERVICES_GLOBAL = ["systemd-tmpfiles-clean.timer"]  # per-user cache aging

# --- Automatic cleanup / sanitization (path -> content) ---
CLEANUP_FILES = {
    "/etc/systemd/journald.conf.d/size.conf": "[Journal]\nSystemMaxUse=200M\n",
    "/etc/systemd/coredump.conf.d/none.conf": "[Coredump]\nStorage=none\n",
    # keep 2 versions of each cached package instead of 3
    "/etc/systemd/system/paccache.service.d/keep.conf": (
        "[Service]\nExecStart=\nExecStart=/usr/bin/paccache -rk2\n"
    ),
    # wait for deleted snapshots to actually free their space
    "/etc/systemd/system/snapper-cleanup.service.d/sync.conf": (
        "[Service]\nExecStartPost=-/usr/bin/btrfs subvolume sync /\n"
    ),
    # delete ~/.cache files untouched for 30 days
    "/etc/user-tmpfiles.d/veyra-cache.conf": "e %C - - - 30d\n",
}

# --- First-boot AUR installs (run once via paru, then the service deletes itself) ---
# Verify names with `paru -Ss temurin`; plain `wallust` may exist in extra.
AUR_PACKAGES = ["wallust-git", "catppuccin-cursors-mocha", "jdk-temurin"]