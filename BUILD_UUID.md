# WolFox UUID Build

Branch: `wolfox-uuid-input`

## Target bundles
- `sa.gov.moia.mosques2`
- `sa.gov.moia.mosques-2`

## Requirements
- Ubuntu 24.04 GitHub Actions runner
- Theos
- iPhoneOS 16.5 SDK
- `WOLFOX_PROJECT_KEY` repository secret

## Expected outputs
- `WolFox.dylib`
- `WolFox_v2.0.0_iOS15.8-26.5_Rootful.deb`
- `WolFox_v2.0.0_iOS15.8-26.5_Rootless.deb`
- `SHA256SUMS.txt`

The workflow validates identifier storage keys, builds the dylib for arm64, verifies artifacts are non-empty, then uploads them as the `WolFox-UUID-Build` artifact.
