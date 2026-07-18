SHELL := /bin/sh

CXX := clang++
CC := clang

include Resources/ProductVersion.mk

OFX_SDK_ROOT ?= /Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/OpenFX

BUILD_DIR := build
OBJECT_DIR := $(BUILD_DIR)/objects
BUNDLE_NAME := Filmtone.ofx.bundle
BUNDLE_ROOT := $(BUILD_DIR)/$(BUNDLE_NAME)
BUNDLE_BINARY := $(BUNDLE_ROOT)/Contents/MacOS/Filmtone.ofx
BUNDLE_INFO := $(BUNDLE_ROOT)/Contents/Info.plist

CPPFLAGS := -I"$(OFX_SDK_ROOT)/OpenFX-1.4/include" \
	-I"$(OFX_SDK_ROOT)/Support/include" \
	-ISources \
	-ISources/Host
CXXFLAGS := -std=c++17 -O2 -arch arm64 -fvisibility=hidden \
	-fvisibility-inlines-hidden -Wall -Wextra -Wpedantic \
	-mmacosx-version-min=$(FILMTONE_RESOLVE_MACOS_DEPLOYMENT_TARGET)
# Vendored ed25519 is third-party C; keep its own conservative flag set.
CFLAGS := -std=c11 -O2 -arch arm64 -fvisibility=hidden -Wall \
	-mmacosx-version-min=$(FILMTONE_RESOLVE_MACOS_DEPLOYMENT_TARGET)
LDFLAGS := -bundle -arch arm64 -fvisibility=hidden \
	-mmacosx-version-min=$(FILMTONE_RESOLVE_MACOS_DEPLOYMENT_TARGET) \
	-framework AppKit -framework Foundation -framework Metal

SIGN_IDENTITY ?=

PLUGIN_CPP_SOURCES := Sources/Host/FilmtonePlugin.cpp \
	Sources/Integration/FilmtoneParameters.cpp \
	Sources/Effects/FilmBreath/FilmBreathOffsets.cpp \
	Sources/Effects/GateWeave/GateWeaveTransform.cpp
PLUGIN_MM_SOURCES := Sources/Host/MetalIdentityBlit.mm \
	Sources/Host/MetalPipelineCache.mm \
	Sources/Integration/FilmtoneRenderGraph.mm \
	Sources/Effects/FilmBreath/FilmBreathProcessor.mm \
	Sources/Effects/GateWeave/GateWeaveProcessor.mm \
	Sources/Effects/FilmDamage/FilmDamageProcessor.mm \
	Sources/License/LicenseStore.mm
PLUGIN_C_SOURCES := Sources/License/vendor/ed25519/fe.c \
	Sources/License/vendor/ed25519/ge.c \
	Sources/License/vendor/ed25519/sc.c \
	Sources/License/vendor/ed25519/sha512.c \
	Sources/License/vendor/ed25519/verify.c
PLUGIN_CPP_OBJECTS := $(patsubst Sources/%.cpp,$(OBJECT_DIR)/%.o,$(PLUGIN_CPP_SOURCES))
PLUGIN_MM_OBJECTS := $(patsubst Sources/%.mm,$(OBJECT_DIR)/%.o,$(PLUGIN_MM_SOURCES))
PLUGIN_C_OBJECTS := $(patsubst Sources/%.c,$(OBJECT_DIR)/%.o,$(PLUGIN_C_SOURCES))

SUPPORT_UNITS := ofxsCore ofxsImageEffect ofxsInteract ofxsLog \
	ofxsMultiThread ofxsParams ofxsProperty ofxsPropertyValidation
SUPPORT_OBJECTS := $(addprefix $(OBJECT_DIR)/Support/,$(addsuffix .o,$(SUPPORT_UNITS)))

OBJECTS := $(PLUGIN_CPP_OBJECTS) $(PLUGIN_MM_OBJECTS) $(PLUGIN_C_OBJECTS) $(SUPPORT_OBJECTS)

.PHONY: all clean sign-bundle

# Expected product: build/Filmtone.ofx.bundle
all: $(BUNDLE_BINARY) $(BUNDLE_INFO)

$(BUNDLE_BINARY): $(OBJECTS)
	@mkdir -p "$(@D)"
	$(CXX) $(OBJECTS) -o "$@" $(LDFLAGS)

$(BUNDLE_INFO): Resources/Info.plist Resources/ProductVersion.mk
	@mkdir -p "$(@D)"
	cp "$<" "$@"
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(FILMTONE_RESOLVE_MARKETING_VERSION)" "$@"
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(FILMTONE_RESOLVE_BUILD_VERSION)" "$@"
	/usr/libexec/PlistBuddy -c "Set :LSMinimumSystemVersion $(FILMTONE_RESOLVE_MACOS_DEPLOYMENT_TARGET)" "$@"

$(OBJECT_DIR)/%.o: Sources/%.cpp Resources/ProductVersion.mk
	@mkdir -p "$(@D)"
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c "$<" -o "$@"

$(OBJECT_DIR)/%.o: Sources/%.mm Resources/ProductVersion.mk
	@mkdir -p "$(@D)"
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c "$<" -o "$@"

$(OBJECT_DIR)/%.o: Sources/%.c Resources/ProductVersion.mk
	@mkdir -p "$(@D)"
	$(CC) $(CPPFLAGS) $(CFLAGS) -c "$<" -o "$@"

define compile_support_unit
$(OBJECT_DIR)/Support/$(1).o: Resources/ProductVersion.mk
	@mkdir -p "$$(@D)"
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c "$(OFX_SDK_ROOT)/Support/Library/$(1).cpp" -o "$$@"
endef

$(foreach unit,$(SUPPORT_UNITS),$(eval $(call compile_support_unit,$(unit))))

sign-bundle: all
	@if [ -z "$(SIGN_IDENTITY)" ]; then \
		echo 'SIGN_IDENTITY must name a Developer ID Application identity' >&2; \
		exit 2; \
	fi
	/usr/bin/codesign --force --options runtime --timestamp \
		--sign "$(SIGN_IDENTITY)" "$(BUNDLE_ROOT)"

clean:
	rm -rf "$(BUILD_DIR)"
