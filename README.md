# mpv2winget

Automated CI/CD pipeline that packages shinchiro's portable mpv builds into a fully integrated Windows installer (.exe) for Winget distribution.

## Overview
This repository uses GitHub Actions to run a daily workflow that:
1. Fetches the latest stable version of [mpv-player/mpv](https://github.com/mpv-player/mpv).
2. Checks [shinchiro/mpv-winbuild-cmake](https://github.com/shinchiro/mpv-winbuild-cmake) for the latest compiled binary.
3. Validates the downloaded binary against the official stable tag.
4. Packages the portable binaries into a native Windows Installer using Inno Setup, fully integrating `mpv` into the OS (Registry, Default Apps, Context Menus).
5. Publishes the compiled installer as a GitHub Release.
6. Automatically submits the update to Microsoft Winget.

## Zero Maintenance
This project requires no manual intervention. The entire pipeline runs in the cloud (GitHub Actions), eliminating the need for local building or testing. It strictly follows the provided `build_mpv.iss` to assure consistent native OS integration.

## License
MIT License. See [LICENSE](LICENSE) for more information.
