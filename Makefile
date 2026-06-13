# SwiftProyecto Makefile
# Build and install the proyecto CLI with full Metal shader support

SCHEME = proyecto
BINARY = proyecto
BIN_DIR = ./bin
DESTINATION = platform=macOS,arch=arm64
DERIVED_DATA = $(HOME)/Library/Developer/Xcode/DerivedData

.PHONY: all build release install clean test lint resolve help codesign-cli

all: install

# Resolve all SPM package dependencies via xcodebuild
resolve:
	xcodebuild -resolvePackageDependencies -scheme $(SCHEME) -destination '$(DESTINATION)'
	@echo "Package dependencies resolved."

# Development build with xcodebuild
build:
	xcodebuild build -scheme SwiftProyecto-Package -destination '$(DESTINATION)' CODE_SIGNING_ALLOWED=NO

# Release build with xcodebuild + copy to bin
release: resolve
	xcodebuild -scheme $(SCHEME) -destination '$(DESTINATION)' -configuration Release build
	@mkdir -p $(BIN_DIR)
	@PRODUCT_DIR=$$(find $(DERIVED_DATA)/SwiftProyecto-*/Build/Products/Release -name $(BINARY) -type f 2>/dev/null | head -1 | xargs dirname); \
	if [ -n "$$PRODUCT_DIR" ]; then \
		cp "$$PRODUCT_DIR/$(BINARY)" $(BIN_DIR)/; \
		if [ -d "$$PRODUCT_DIR/mlx-swift_Cmlx.bundle" ]; then \
			rm -rf $(BIN_DIR)/mlx-swift_Cmlx.bundle; \
			cp -R "$$PRODUCT_DIR/mlx-swift_Cmlx.bundle" $(BIN_DIR)/; \
			echo "Installed $(BINARY) + Metal bundle to $(BIN_DIR)/ (Release)"; \
		else \
			echo "Warning: Metal bundle not found, binary may not work"; \
			echo "Installed $(BINARY) to $(BIN_DIR)/ (Release, no Metal bundle)"; \
		fi; \
	else \
		echo "Error: Could not find $(BINARY) in DerivedData"; \
		exit 1; \
	fi

# Debug build with xcodebuild + copy to bin (default)
install: resolve
	xcodebuild -scheme $(SCHEME) -destination '$(DESTINATION)' build
	@mkdir -p $(BIN_DIR)
	@PRODUCT_DIR=$$(find $(DERIVED_DATA)/SwiftProyecto-*/Build/Products/Debug -name $(BINARY) -type f 2>/dev/null | head -1 | xargs dirname); \
	if [ -n "$$PRODUCT_DIR" ]; then \
		cp "$$PRODUCT_DIR/$(BINARY)" $(BIN_DIR)/; \
		if [ -d "$$PRODUCT_DIR/mlx-swift_Cmlx.bundle" ]; then \
			rm -rf $(BIN_DIR)/mlx-swift_Cmlx.bundle; \
			cp -R "$$PRODUCT_DIR/mlx-swift_Cmlx.bundle" $(BIN_DIR)/; \
			echo "Installed $(BINARY) + Metal bundle to $(BIN_DIR)/ (Debug)"; \
		else \
			echo "Warning: Metal bundle not found, binary may not work"; \
			echo "Installed $(BINARY) to $(BIN_DIR)/ (Debug, no Metal bundle)"; \
		fi; \
	else \
		echo "Error: Could not find $(BINARY) in DerivedData"; \
		exit 1; \
	fi

# Run tests
test:
	xcodebuild test -scheme SwiftProyecto-Package -destination '$(DESTINATION)' CODE_SIGNING_ALLOWED=NO

# Format Swift source files with swift-format
lint:
	swift format -i -r .
	@echo "Swift source files formatted."

# Clean build artifacts
clean:
	swift package clean
	rm -rf $(BIN_DIR)
	rm -rf $(DERIVED_DATA)/SwiftProyecto-*

# ── App Group code-signing ────────────────────────────────────────────────
# Sign the proyecto CLI with the com.apple.security.application-groups
# entitlement so the group ID is embedded in the binary and SwiftAcervo resolves
# the shared models container (~/Library/Group Containers/group.intrusive-memory.models/)
# WITHOUT requiring ACERVO_APP_GROUP_ID in the environment. Container access is
# plain POSIX (same-user, mode 700); the entitlement only supplies the group
# identifier at runtime via SecTaskCopyValueForEntitlement.
#
# Default identity is ad-hoc (-). For a distributable build, override with a
# Developer ID by certificate SHA-1 (names collide in the keychain):
#   make install codesign-cli CODESIGN_IDENTITY=<sha1>
APP_GROUP_ID ?= group.intrusive-memory.models
CODESIGN_IDENTITY ?= -
CODESIGN_FLAGS ?=
CODESIGN_ENTITLEMENTS ?= cli.entitlements

codesign-cli:
	@test -f "$(BIN_DIR)/$(BINARY)" || { echo "Error: $(BIN_DIR)/$(BINARY) not found — run 'make install' or 'make release' first."; exit 1; }
	@codesign --force --sign "$(CODESIGN_IDENTITY)" --entitlements "$(CODESIGN_ENTITLEMENTS)" $(CODESIGN_FLAGS) "$(BIN_DIR)/$(BINARY)"
	@echo "Signed $(BIN_DIR)/$(BINARY) (identity: $(CODESIGN_IDENTITY), group: $(APP_GROUP_ID))"
	@codesign -d --entitlements - "$(BIN_DIR)/$(BINARY)" 2>/dev/null | grep -A1 "application-groups" || true

help:
	@echo "SwiftProyecto Makefile"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  resolve  - Resolve all SPM package dependencies"
	@echo "  build    - Development build with xcodebuild"
	@echo "  install  - Debug build with xcodebuild + copy to ./bin (default)"
	@echo "  release  - Release build with xcodebuild + copy to ./bin"
	@echo "  test     - Run tests"
	@echo "  lint     - Format Swift source files with swift-format"
	@echo "  clean    - Clean build artifacts"
	@echo "  codesign-cli  - Sign the proyecto CLI with the App Group entitlement (run after install/release)"
	@echo "  help     - Show this help"
	@echo ""
	@echo "All builds use: -destination '$(DESTINATION)'"
