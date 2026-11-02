# Veyra package archive cache

This composite action restores cached Arch/CachyOS package archives, removes archives that Pacman cannot inspect, and writes a TSV manifest containing package names, versions, architectures, SHA-256 hashes, and archive paths. The action uses a unique cache key for each run and a stable restore prefix, so GitHub can restore the most recent compatible archive cache and save additions at the end of the job.

## Use in the ISO build workflow

Add the action after checkout and before `./build.sh`, pointing `cache-paths` at the persistent archive directories used by the build. Keep the cache scope tied to architecture and repository family; do not share caches across incompatible architectures.

The package manifest is an inventory of cached archives, not proof that those packages are current in the repositories. The build must still resolve against current repository metadata and download any newer package versions. Do not use a cache hit as a substitute for dependency resolution or signature verification.

## Manual validation

Run **Actions → Veyra package cache check → Run workflow**. The workflow validates whatever archives are present in the two cache directories and uploads a manifest artifact. It does not build or publish an ISO.

## Important limitation

This first iteration supplies the cache/validation mechanism independently of the existing ISO build. It intentionally does not change `build.sh` or the production ISO workflow. Repository snapshot consistency and the current Hyprland dependency failure must be resolved separately before integrating this cache into the ISO build.
