# SlipStream iOS — lint & format (see CLAUDE.md → Linting).
#   swift-format owns ALL formatting; SwiftLint owns semantic / correctness lint only.
# Tooling: SwiftLint via Homebrew (`brew install swiftlint`); swift-format from the Swift
# toolchain (`xcrun swift-format`, no install needed).

SWIFT_FORMAT := xcrun swift-format
# All first-party Swift sources (excludes SPM build artifacts & caches).
SWIFT_FILES := $(shell find App Packages -name '*.swift' -not -path '*/.build/*' -not -path '*/.swiftpm/*')
# Fail with a clear message (not a swift-format "no input" error) if the list is empty,
# e.g. when invoked from the wrong directory.
require-files = @[ -n "$(SWIFT_FILES)" ] || { echo "No Swift files found — run make from the repo root." >&2; exit 1; }

.PHONY: format lint format-check install-hooks

## format: apply swift-format in place across the codebase.
format:
	$(require-files)
	$(SWIFT_FORMAT) format --in-place --parallel --configuration .swift-format $(SWIFT_FILES)

## lint: check-only — formatting (swift-format) + semantics (SwiftLint, --strict). Used by CI.
lint: format-check
	swiftlint lint --strict --quiet

## format-check: verify formatting without modifying files.
format-check:
	$(require-files)
	$(SWIFT_FORMAT) lint --strict --parallel --configuration .swift-format $(SWIFT_FILES)

## install-hooks: route git's hooks to ./scripts for this checkout (worktree-safe; no symlink
## to dangle). core.hooksPath is resolved relative to each working tree's root.
install-hooks:
	@chmod +x scripts/pre-commit
	@git config core.hooksPath scripts
	@echo "✓ git hooks → ./scripts (core.hooksPath); pre-commit active."
