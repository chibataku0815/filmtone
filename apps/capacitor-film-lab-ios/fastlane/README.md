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

### ios release_notes

```sh
[bundle exec] fastlane ios release_notes
```

Upload only localized What's New release notes

### ios ipad_archive

```sh
[bundle exec] fastlane ios ipad_archive
```

Archive Filmtone Studio from the native App-iPad target

### ios ipad_preflight

```sh
[bundle exec] fastlane ios ipad_preflight
```

Validate staged Filmtone Studio App Store assets without uploading

### ios ipad_upload_assets

```sh
[bundle exec] fastlane ios ipad_upload_assets
```

Upload Filmtone Studio metadata and screenshots without binary or review submission

### ios ipad_release

```sh
[bundle exec] fastlane ios ipad_release
```

Upload Filmtone Studio binary, metadata, and screenshots to App Store Connect

### ios ipad_beta

```sh
[bundle exec] fastlane ios ipad_beta
```

Upload Filmtone Studio build to TestFlight

### ios ipad_submit_review

```sh
[bundle exec] fastlane ios ipad_submit_review
```

Submit an already uploaded Filmtone Studio build without touching screenshots or binary

### ios release_binary

```sh
[bundle exec] fastlane ios release_binary
```

Upload only the App Store binary without metadata or screenshots

### ios submit_review_release_notes

```sh
[bundle exec] fastlane ios submit_review_release_notes
```

Submit the current build after syncing only What's New release notes

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

### ios submit_review

```sh
[bundle exec] fastlane ios submit_review
```

Submit an already uploaded App Store Connect build without touching screenshots or binary

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
