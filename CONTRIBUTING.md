# Contributing to GradTrackLite

Thanks for your interest in improving GradTrackLite. This project stays deliberately small and clean, so every change should earn its place.

## Getting started

1. Fork the repository and clone your fork.
2. Create a branch from `main`: `git switch -c feat/my-change`.
3. Open `GradTrackLite.xcodeproj` in Xcode and make your change.
4. Make sure it builds and the tests pass:

   ```bash
   xcodebuild -project GradTrackLite.xcodeproj \
     -scheme GradTrackLite \
     -destination 'platform=iOS Simulator,name=iPhone 15' \
     CODE_SIGNING_ALLOWED=NO test
   ```

5. Commit with a clear message and open a pull request.

## Reporting bugs

Open an issue with:

- A short title and a clear description.
- Steps to reproduce.
- What you expected vs. what happened.
- Xcode version, simulator/device, and iOS version.
- A screenshot or crash log if relevant.

## Development conventions

- **Swift style** — follow the existing style in the project: SwiftUI views, value types for models where possible, `@Observable` / `SwiftData` rather than global singletons.
- **Keep logic pure** — any scoring or status rule belongs in `Services/ProgressRules.swift` as a pure function so it can be unit-tested.
- **No new frameworks without a reason** — prefer the platform SDKs.
- **Prefer the smallest change** that fully addresses the issue.
- **Security** — never log tokens or secrets, and never weaken auth/validation checks. Secrets belong in `Services/TokenStore.swift` (Keychain) only.

## Testing

Every change to `ProgressRules` should update or add a unit test in `GradTrackLiteTests/GradTrackLiteTests.swift`. CI will fail the build if tests don't pass.

## Code of conduct

By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
