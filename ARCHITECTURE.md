# CI/CD Workflow Architecture

This document outlines the 3-phase automated pipeline used by this repository to ensure zero-maintenance updates for MPV Player on Winget.

## Trigger
- **Scheduled:** The GitHub Action wakes up every 24 hours (Midnight UTC).
- **Manual:** Can be triggered manually via the `workflow_dispatch` event in the Actions tab.

## Phase 1: The Entry Barrier (Official Binary vs Our Release)
The bot compares the official MPV version against the last version we published to prevent unnecessary downloads and processing.

1. **Check Release Existence:** Does our repository have any published releases?
   - **NO:** First run detected. Proceed to Phase 2.
   - **YES:** Continue checking.
2. **Fetch APIs:**
   - **Bin Release:** Queries our GitHub repository API for the latest published tag (e.g., `v0.41.0`).
   - **Bin Original:** Queries the official `mpv-player/mpv` GitHub API for the latest stable tag (e.g., `v0.41.0`).
3. **Compare Versions:** Is the Original Binary tag equal to or greater than our Release tag?
   - **EQUAL:** We are up to date. The bot stops the process and waits until the next day.
   - **SUPERIOR:** A new official stable version is out. Proceed to Phase 2.

## Phase 2: Quality Control (Original Binary vs Shinchiro Binary)
The bot verifies if the Windows compiler (Shinchiro) has updated their binaries to match the new official stable release.

1. **Fetch APIs:**
   - **Bin Original:** `https://github.com/mpv-player/mpv/releases`
   - **Bin Shinchiro:** `https://github.com/shinchiro/mpv-winbuild-cmake`
2. **Download & Extract:** Downloads Shinchiro's latest `.7z` archive and extracts `mpv.com`.
3. **Execute & Read Output:** Runs `mpv.com --version` to capture the internal build tag.
4. **Compare Versions:** 
   - **INFERIOR / MISMATCH:** The internal version from Shinchiro says `-git` or an older version. Shinchiro hasn't compiled the new stable yet. The bot stops the process and waits until the next day.
   - **EQUAL:** Shinchiro's internal tag matches the official MPV tag. Proceed to Phase 3.

## Phase 3: Packaging and Publishing
The bot executes the compilation and distribution of the installer.

1. **Compile:** Uses Inno Setup (`build_mpv.iss`) to silently package the verified Shinchiro binaries into a native `mpv_installer_x64.exe` with deep OS integration.
2. **Publish Release:** Uploads the compiled `.exe` to our GitHub repository's Releases section, tagging it with the official version number.
3. **Submit to Winget:** Automatically creates and submits a Pull Request to the `microsoft/winget-pkgs` repository to update the global Winget registry.