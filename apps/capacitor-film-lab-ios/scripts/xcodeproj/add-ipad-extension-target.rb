#!/usr/bin/env ruby
# frozen_string_literal: true

# M5-B: Add separate `FilmtoneExportActivityIPad` app-extension target
# to App.xcodeproj.
#
# Mirrors the existing `FilmtoneExportActivity` (iPhone) extension's
# source / Info.plist / build settings into a new
# `FilmtoneExportActivityIPad` target with:
#   - PRODUCT_BUNDLE_IDENTIFIER = com.chibatakumi.film.lab.ipad.exportactivity
#   - TARGETED_DEVICE_FAMILY    = 2 (iPad-only)
#   - INFOPLIST_FILE             = App/FilmtoneExportActivity/Info.plist (shared)
#
# Then embeds the new extension into the `App-iPad` host target via:
#   - PBXTargetDependency
#   - PBXCopyFilesBuildPhase (dstSubfolderSpec=13 "Plug-ins",
#     name "Embed Foundation Extensions")
#
# Leaves the existing iPhone `FilmtoneExportActivity` target and its
# embed-link from `App` untouched.
#
# Idempotent guard: aborts if `FilmtoneExportActivityIPad` already exists.

require 'xcodeproj'

PROJECT_PATH         = 'ios/App/App.xcodeproj'
SOURCE_EXT_TARGET    = 'FilmtoneExportActivity'
NEW_EXT_TARGET       = 'FilmtoneExportActivityIPad'
IPAD_HOST_TARGET     = 'App-iPad'
NEW_BUNDLE_ID        = 'com.chibatakumi.film.lab.ipad.exportactivity'
IPAD_DEVICE_FAMILY   = '2'

unless File.directory?(PROJECT_PATH)
  abort "ERROR: cannot find #{PROJECT_PATH}. Run from apps/capacitor-film-lab-ios."
end

proj = Xcodeproj::Project.open(PROJECT_PATH)

if proj.targets.any? { |t| t.name == NEW_EXT_TARGET }
  abort "ERROR: target '#{NEW_EXT_TARGET}' already exists. This script is one-shot."
end

src_ext = proj.targets.find { |t| t.name == SOURCE_EXT_TARGET }
abort "ERROR: source extension target '#{SOURCE_EXT_TARGET}' not found." unless src_ext

ipad_host = proj.targets.find { |t| t.name == IPAD_HOST_TARGET }
abort "ERROR: iPad host target '#{IPAD_HOST_TARGET}' not found. Run add-ipad-target.rb first." unless ipad_host

puts "Source extension '#{SOURCE_EXT_TARGET}' located. Phases:"
src_ext.build_phases.each { |bp| puts "  #{bp.class.name.split('::').last} files=#{bp.files.length}" }

# ---------------------------------------------------------------------------
# Create the new app-extension target.
# ---------------------------------------------------------------------------
puts "\nCreating new target '#{NEW_EXT_TARGET}'..."
new_ext = proj.new_target(
  :app_extension,
  NEW_EXT_TARGET,
  :ios,
  src_ext.build_configurations.first.build_settings['IPHONEOS_DEPLOYMENT_TARGET'],
  nil,
  :swift
)

# ---------------------------------------------------------------------------
# Mirror build settings from source extension; override identity only.
# ---------------------------------------------------------------------------
%w[Debug Release].each do |cfg_name|
  src = src_ext.build_configurations.find { |c| c.name == cfg_name }
  dst = new_ext.build_configurations.find { |c| c.name == cfg_name }
  abort "ERROR: missing #{cfg_name} config on source or new extension target." unless src && dst

  dst.build_settings = src.build_settings.dup
  dst.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = NEW_BUNDLE_ID
  dst.build_settings['TARGETED_DEVICE_FAMILY']   = IPAD_DEVICE_FAMILY
  dst.build_settings['PRODUCT_NAME']             = '$(TARGET_NAME)'
  # INFOPLIST_FILE = same shared path string (D4 — shared plist).
  # The source extension does not use a Pods xcconfig base, so leave
  # base_configuration_reference nil.
end

# ---------------------------------------------------------------------------
# Mirror source files into new target's Sources build phase.
# ---------------------------------------------------------------------------
src_sources = src_ext.source_build_phase
dst_sources = new_ext.source_build_phase
puts "\nMirroring #{src_sources.files.length} source files..."
src_sources.files.each do |bf|
  next unless bf.file_ref
  new_bf = dst_sources.add_file_reference(bf.file_ref, true)
  new_bf.settings = bf.settings.dup if bf.settings && !bf.settings.empty?
end

# ---------------------------------------------------------------------------
# Strip xcodeproj-gem auto-default Foundation.framework if added with
# a stale SDK path (matches add-ipad-target.rb logic for parity with
# source extension which carries no Foundation.framework link).
# ---------------------------------------------------------------------------
dst_fw = new_ext.frameworks_build_phase
dst_fw.files.dup.each do |bf|
  next unless bf.file_ref&.path&.include?('iPhoneOS') &&
              bf.file_ref.path.include?('Foundation.framework')
  ref = bf.file_ref
  bf.remove_from_project
  ref.remove_from_project if proj.objects.none? { |o|
    o.respond_to?(:file_ref) && o.file_ref == ref
  }
end
puts "Framework links after default strip: #{dst_fw.files.length}"

# Source extension has no resources / frameworks / package deps to mirror.
abort "ERROR: source extension unexpectedly has resources; mirror logic needed." \
  unless src_ext.resources_build_phase.files.empty?
abort "ERROR: source extension unexpectedly has frameworks; mirror logic needed." \
  unless src_ext.frameworks_build_phase.files.empty?
abort "ERROR: source extension unexpectedly has package deps; mirror logic needed." \
  unless src_ext.package_product_dependencies.empty?

# ---------------------------------------------------------------------------
# Add new extension as a target dependency of App-iPad.
# ---------------------------------------------------------------------------
puts "\nAdding '#{NEW_EXT_TARGET}' as dependency of '#{IPAD_HOST_TARGET}'..."
ipad_host.add_dependency(new_ext)

# ---------------------------------------------------------------------------
# Add "Embed Foundation Extensions" copy-files build phase to App-iPad.
# Use the same shape App uses for the iPhone extension:
#   dstSubfolderSpec = "13" (Plug-ins)
#   name            = "Embed Foundation Extensions"
#   file_ref        = new extension's product_reference (FilmtoneExportActivityIPad.appex)
#   settings        = { ATTRIBUTES = [RemoveHeadersOnCopy] }
# ---------------------------------------------------------------------------
puts "Adding Embed Foundation Extensions copy-files phase to '#{IPAD_HOST_TARGET}'..."
embed_phase = ipad_host.new_copy_files_build_phase('Embed Foundation Extensions')
embed_phase.symbol_dst_subfolder_spec = :plug_ins
embed_phase.dst_path = ''

embed_bf = embed_phase.add_file_reference(new_ext.product_reference, true)
embed_bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

proj.save
puts "\nProject saved: #{PROJECT_PATH}"
puts "\nDone. Verify with:"
puts "  xcodebuild -workspace ios/App/App.xcworkspace -scheme #{IPAD_HOST_TARGET} \\"
puts "    -destination 'generic/platform=iOS Simulator' -configuration Debug \\"
puts "    build CODE_SIGNING_ALLOWED=NO"
