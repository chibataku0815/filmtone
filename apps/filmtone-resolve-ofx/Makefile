SHELL := /bin/sh

CXX := clang++

OFX_SDK_ROOT ?= /Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/OpenFX

BUILD_DIR := build
OBJECT_DIR := $(BUILD_DIR)/objects
BUNDLE_NAME := FilmtoneFinish.ofx.bundle
BUNDLE_ROOT := $(BUILD_DIR)/$(BUNDLE_NAME)
BUNDLE_BINARY := $(BUNDLE_ROOT)/Contents/MacOS/FilmtoneFinish.ofx
BUNDLE_INFO := $(BUNDLE_ROOT)/Contents/Info.plist

CPPFLAGS := -I"$(OFX_SDK_ROOT)/OpenFX-1.4/include" \
	-I"$(OFX_SDK_ROOT)/Support/include" \
	-ISources \
	-ISources/Host
CXXFLAGS := -std=c++17 -O2 -arch arm64 -fvisibility=hidden \
	-fvisibility-inlines-hidden -Wall -Wextra -Wpedantic
LDFLAGS := -bundle -arch arm64 -fvisibility=hidden \
	-framework AppKit -framework Foundation -framework Metal

PLUGIN_CPP_SOURCES := Sources/Host/FilmtoneFinishPlugin.cpp \
	Sources/Integration/FilmtoneFinishParameters.cpp \
	Sources/Effects/FilmBreath/FilmBreathOffsets.cpp \
	Sources/Effects/GateWeave/GateWeaveTransform.cpp
PLUGIN_MM_SOURCES := Sources/Host/MetalIdentityBlit.mm \
	Sources/Host/MetalPipelineCache.mm \
	Sources/Integration/FilmtoneFinishRenderGraph.mm \
	Sources/Effects/FilmBreath/FilmBreathProcessor.mm \
	Sources/Effects/GateWeave/GateWeaveProcessor.mm \
	Sources/Effects/FilmDamage/FilmDamageProcessor.mm
PLUGIN_CPP_OBJECTS := $(patsubst Sources/%.cpp,$(OBJECT_DIR)/%.o,$(PLUGIN_CPP_SOURCES))
PLUGIN_MM_OBJECTS := $(patsubst Sources/%.mm,$(OBJECT_DIR)/%.o,$(PLUGIN_MM_SOURCES))

SUPPORT_UNITS := ofxsCore ofxsImageEffect ofxsInteract ofxsLog \
	ofxsMultiThread ofxsParams ofxsProperty ofxsPropertyValidation
SUPPORT_OBJECTS := $(addprefix $(OBJECT_DIR)/Support/,$(addsuffix .o,$(SUPPORT_UNITS)))

OBJECTS := $(PLUGIN_CPP_OBJECTS) $(PLUGIN_MM_OBJECTS) $(SUPPORT_OBJECTS)

.PHONY: all clean

# Expected product: build/FilmtoneFinish.ofx.bundle
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

define compile_support_unit
$(OBJECT_DIR)/Support/$(1).o:
	@mkdir -p "$$(@D)"
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c "$(OFX_SDK_ROOT)/Support/Library/$(1).cpp" -o "$$@"
endef

$(foreach unit,$(SUPPORT_UNITS),$(eval $(call compile_support_unit,$(unit))))

clean:
	rm -rf "$(BUILD_DIR)"
