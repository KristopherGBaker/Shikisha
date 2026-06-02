SWIFTLINT ?= swiftlint

.PHONY: help lint test build clean xcode docs docs-preview

help:
	@printf "Available targets:\n"
	@printf "  build         swift build\n"
	@printf "  test          swift test\n"
	@printf "  lint          run SwiftLint\n"
	@printf "  docs          build static DocC site into ./docs\n"
	@printf "  docs-preview  serve DocC docs locally with live reload\n"
	@printf "  xcode         regenerate Shikisha.xcodeproj via xcodegen\n"
	@printf "  clean         remove .build and DerivedData\n"

build:
	swift build

test:
	swift test

lint:
	$(SWIFTLINT) lint --quiet --strict --config .swiftlint.yml

xcode:
	xcodegen generate

# Build a static DocC site suitable for GitHub Pages hosting under /Shikisha.
docs:
	SHIKISHA_BUILD_DOCS=1 swift package --allow-writing-to-directory ./docs \
		generate-documentation --target Shikisha \
		--disable-indexing \
		--transform-for-static-hosting \
		--hosting-base-path Shikisha \
		--output-path ./docs

# Preview the documentation locally (opens an interactive server).
docs-preview:
	SHIKISHA_BUILD_DOCS=1 swift package --disable-sandbox preview-documentation --target Shikisha

clean:
	rm -rf .build .swiftpm DerivedData docs
