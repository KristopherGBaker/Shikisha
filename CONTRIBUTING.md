# Contributing to Shikisha

Thanks for your interest in improving Shikisha! This is an early-stage project, so issues and pull requests are welcome.

## Requirements

- Swift 6.3+ (macOS 14+ / iOS 17+)
- [SwiftLint](https://github.com/realm/SwiftLint) and [xcodegen](https://github.com/yonaskolb/XcodeGen) for the `make lint` / `make xcode` targets: `brew install swiftlint xcodegen`

## Workflow

```bash
make build   # swift build
make test    # swift test
make lint    # swiftlint --strict
```

Before opening a pull request, make sure `make test` and `make lint` both pass — CI runs the same checks.

## Style

- Code follows the rules in [`.swiftlint.yml`](.swiftlint.yml), enforced in strict mode. Multi-line function declarations put one parameter per line.
- Match the conventions of the surrounding code: `Sendable` types, structured concurrency, `AsyncSequence` for streaming, and `Codable` wire shapes.

## Commits

This repo uses [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`, …). Keep commits focused, and call out any breaking API changes with a `BREAKING CHANGE:` footer.
