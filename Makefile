# Builds the Swift app with SwiftPM, assembles a .app bundle, signs it with the
# local self-signed identity and installs it into /Applications.
#
#   make            build (release)
#   make run        build, bundle, sign, install, launch
#   make install    same without launching
#   make test       swift test
#   make fmt        format Sources and Tests in place
#   make lint       swift-format lint, fails on any warning
#   make debug      debug build + run straight from .build (no bundle)
#   make clean

# The bundle id and signing identity must stay stable: macOS keys Accessibility
# and other permission grants on them.
APP_NAME  ?= Clavis
BUNDLE_ID ?= com.svenbakkenes.clavis
IDENTITY  ?= MyLauncher Local Signing
CONFIG    ?= release

DIST   := dist
APP    := $(DIST)/$(APP_NAME).app
BIN    := .build/$(CONFIG)/Clavis
RES    := Resources
CONTENTS := $(APP)/Contents

.PHONY: build bundle sign install run debug test fmt lint clean

build:
	swift build -c $(CONFIG)

bundle: build
	rm -rf "$(APP)"
	mkdir -p "$(CONTENTS)/MacOS" "$(CONTENTS)/Resources"
	cp "$(BIN)" "$(CONTENTS)/MacOS/$(APP_NAME)"
	sed -e 's/__APP_NAME__/$(APP_NAME)/g' -e 's/__BUNDLE_ID__/$(BUNDLE_ID)/g' \
		"$(RES)/Info.plist" > "$(CONTENTS)/Info.plist"
	printf 'APPL????' > "$(CONTENTS)/PkgInfo"
	iconutil -c icns "$(RES)/AppIcon.iconset" -o "$(CONTENTS)/Resources/AppIcon.icns"

sign: bundle
	codesign --force --sign "$(IDENTITY)" --entitlements "$(RES)/Clavis.entitlements" \
		--options runtime "$(APP)"
	codesign --verify --strict "$(APP)"

install: sign
	@if pgrep -f "/Applications/$(APP_NAME).app/Contents/MacOS/" >/dev/null; then \
		echo "==> Quitting running instance"; \
		pkill -f "/Applications/$(APP_NAME).app/Contents/MacOS/" || true; sleep 1; \
	fi
	rm -rf "/Applications/$(APP_NAME).app"
	cp -R "$(APP)" /Applications/
	@echo "Installed /Applications/$(APP_NAME).app"

run: install
	open "/Applications/$(APP_NAME).app"

debug:
	swift build -c debug
	.build/debug/Clavis

test:
	swift test

fmt:
	swift format format --in-place --recursive Sources Tests Package.swift

lint:
	swift format lint --strict --recursive Sources Tests Package.swift

clean:
	rm -rf .build "$(DIST)"
