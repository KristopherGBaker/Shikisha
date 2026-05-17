SWIFTLINT ?= swiftlint

.PHONY: help lint test build clean xcode

help:
	@printf "Available targets:\n"
	@printf "  build      swift build\n"
	@printf "  test       swift test\n"
	@printf "  lint       run SwiftLint\n"
	@printf "  xcode      regenerate Shikisha.xcodeproj via xcodegen\n"
	@printf "  clean      remove .build and DerivedData\n"

build:
	swift build

test:
	swift test

lint:
	$(SWIFTLINT) lint --quiet --strict --config .swiftlint.yml

xcode:
	xcodegen generate

clean:
	rm -rf .build .swiftpm DerivedData
