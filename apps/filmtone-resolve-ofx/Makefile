SHELL := /bin/sh

CXX := clang++
CC := clang

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
	-fvisibility-inlines-hidden -Wall -Wextra -Wpedantic
# Vendored ed25519 is third-party C; keep its own conservative flag set.
CFLAGS := -std=c11 -O2 -arch arm64 -fvisibility=hidden -Wall
LDFLAGS := -bundle -arch arm64 -fvisibility=hidden \
	-framework AppKit -framework Foundation -framework Metal

PLUGIN_CPP_SOURCES := Sources/Host/FilmtonePlugin.cpp \
	Sources/Integration/FilmtoneParameters.cpp \
	Sources/Effects/FilmBreath/FilmBreathOffsets.cpp \
	Sources/Effects/GateWeave/GateWeaveTransform.cpp
PLUGIN_MM_SOURCES := Sources/Host/MetalIdentityBlit.mm \
	Sources/Host/MetalPipelineCache.mm \
	Sources/Host/Spatial/SpatialMetalHost.mm \
	Sources/Integration/FilmtoneRenderGraph.mm \
	Sources/Effects/TextureSoftness/TextureSoftnessProcessor.mm \
	Sources/Effects/PeripheralChromaticShift/PeripheralChromaticShiftProcessor.mm \
	Sources/Effects/LensSoftness/LensSoftnessProcessor.mm \
	Sources/Effects/DeepGlow/DeepGlowProcessor.mm \
	Sources/Effects/Vignette/VignetteProcessor.mm \
	Sources/Effects/FilmBreath/FilmBreathProcessor.mm \
	Sources/Effects/GateWeave/GateWeaveProcessor.mm \
	Sources/Effects/FilmDamage/FilmDamageProcessor.mm \
	Sources/License/LicenseStore.mm \
	Sources/License/WatermarkPass.mm
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

.PHONY: all clean

# Expected product: build/Filmtone.ofx.bundle
all: $(BUNDLE_BINARY) $(BUNDLE_INFO)

$(BUNDLE_BINARY): $(OBJECTS)
	@mkdir -p "$(@D)"
	$(CXX) $(OBJECTS) -o "$@" $(LDFLAGS)

$(BUNDLE_INFO): Resources/Info.plist
	@mkdir -p "$(@D)"
	cp "$<" "$@"

$(OBJECT_DIR)/%.o: Sources/%.cpp
	@mkdir -p "$(@D)"
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c "$<" -o "$@"

$(OBJECT_DIR)/%.o: Sources/%.mm
	@mkdir -p "$(@D)"
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c "$<" -o "$@"

$(OBJECT_DIR)/%.o: Sources/%.c
	@mkdir -p "$(@D)"
	$(CC) $(CPPFLAGS) $(CFLAGS) -c "$<" -o "$@"

define compile_support_unit
$(OBJECT_DIR)/Support/$(1).o:
	@mkdir -p "$$(@D)"
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c "$(OFX_SDK_ROOT)/Support/Library/$(1).cpp" -o "$$@"
endef

$(foreach unit,$(SUPPORT_UNITS),$(eval $(call compile_support_unit,$(unit))))

clean:
	rm -rf "$(BUILD_DIR)"
