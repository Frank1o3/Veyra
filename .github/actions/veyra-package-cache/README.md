# Veyra package archive cache

This composite action restores cached Arch/CachyOS package archives, validates that each archive can be inspected by Pacman, prunes superseded versions within each profile directory, and writes a TSV inventory containing package names, versions, architectures, SHA-256 hashes, and archive paths.

## Use in the ISO build workflow

Run the action after checkout and before `./build.sh`, pointing `cache-paths` at the persistent archive directories used by the build. Keep the cache scope tied to the architecture, repository family, and package/repository configuration. The action uses a unique key per run and a stable restore prefix, allowing the cache action to save updated contents at the end of the job.

The build script must preserve restored package archives. It may remove generated local repository databases and regenerate them with `repo-add`, but it must not delete all package archives on every run. Pacman must still synchronize current repository metadata, resolve dependencies, verify signatures, and download newer versions as needed.

The package manifest is an inventory of cached archives, not proof that those packages are current in the repositories. A cache hit must never replace dependency resolution or signature verification. The action does not disable package signature checks.

## Outputs

- `cache-hit`: whether GitHub restored an exact cache key.
- `manifest-path`: path to the generated TSV manifest.
- `package-count`: number of package archives listed in the manifest.

## Manual validation

Run **Actions → Veyra package cache check → Run workflow**. The workflow validates the restored archive directories and uploads the generated manifest as an artifact. It does not build or publish an ISO.

## Cache behavior and limitations

- Archives are separated by the supplied cache scope and runner platform.
- Invalid/unreadable package archives are removed so Pacman can fetch them again.
- Only the highest version for each package and architecture is retained inside each cache directory; separate CPU-profile directories are processed independently.
- GitHub Actions caches are immutable. Each run uses a unique save key and restores from the latest compatible prefix, so old cache entries may eventually be evicted by GitHub's cache retention policy.
- This action reduces repeat downloads. It does not fix inconsistent live repository snapshots or unsatisfied dependencies such as a mismatched Hyprland/Hyprgraphics package set; those must still be resolved by the package repositories and build configuration.
