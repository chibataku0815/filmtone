fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Mac

### mac release_env

```sh
[bundle exec] fastlane mac release_env
```

Print Mac App Store release environment readiness without secret values

### mac metadata

```sh
[bundle exec] fastlane mac metadata
```

Upload localized Mac App Store metadata and review information

### mac upload

```sh
[bundle exec] fastlane mac upload
```

Upload a Mac App Store pkg without touching metadata or screenshots

### mac release

```sh
[bundle exec] fastlane mac release
```

Upload the Mac App Store pkg and metadata; screenshots are opt-in

### mac submit_review

```sh
[bundle exec] fastlane mac submit_review
```

Submit an already uploaded Mac App Store build without uploading a binary

### mac status

```sh
[bundle exec] fastlane mac status
```

Check altool delivery status for a previously uploaded package

### mac privacy

```sh
[bundle exec] fastlane mac privacy
```

Print the current App Privacy automation boundary

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
