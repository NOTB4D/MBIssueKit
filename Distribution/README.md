# Binary distribution

This directory is the seed for the repository consumed by application teams.

1. Create a version tag in the SDK development repository.
2. Download `MBIssueKit.xcframework.zip` and `checksum.txt` from the generated GitHub release.
3. Copy `Package.swift.template` to the distribution repository as `Package.swift`.
4. Replace `__BINARY_URL__` with the tagged release asset URL and `__CHECKSUM__` with the generated checksum.
5. Copy `Sources/MBIssueKitDependencies` into the distribution repository.
6. Commit and tag the distribution repository with the same semantic version.

Application repositories add only that distribution repository. The binary package keeps MBAsyncNetworking and its
MobKitCore module dependency in the SwiftPM graph while exposing the `MBIssueKit` library product.
