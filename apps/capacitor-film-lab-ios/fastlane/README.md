fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios archive

```sh
[bundle exec] fastlane ios archive
```

Archive Filmtone with Xcode automatic signing and app-store export

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Capture App Store screenshots with a deterministic UI test rail

### ios metadata

```sh
[bundle exec] fastlane ios metadata
```

Upload localized App Store metadata and review info

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Upload an archive to TestFlight

### ios release

```sh
[bundle exec] fastlane ios release
```

Upload the app-store build, metadata, and screenshots to App Store Connect

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
