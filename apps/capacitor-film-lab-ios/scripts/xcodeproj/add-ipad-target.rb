#!/usr/bin/env ruby
# frozen_string_literal: true

# M5-A: Add separate `App-iPad` native target to App.xcodeproj.
#
# Mirrors the existing `App` (iPhone) target's source / resources /
# frameworks / copy-files / Swift package / target-dependency surface
# into a new `App-iPad` target with:
#   - PRODUCT_BUNDLE_IDENTIFIER = com.chibatakumi.film.lab.ipad
#   - TARGETED_DEVICE_FAMILY    = 2 (iPad-only)
#   - Same Info.plist, deployment target, team, marketing/build version
#   - Same Pods-App xcconfig base (Capacitor pods purged; xcconfig is
#     boilerplate, framework is a stub — sharing is safe and avoids
#     `pod install` side effects)
#
# Also restores the existing `App` (iPhone) target's
# TARGETED_DEVICE_FAMILY from "1,2" (M2 vertical-slice scaffold) back to
# "1" (iPhone-only) — see active.md "Resolved Decisions / Device Family".
#
# Adds a shared scheme `App-iPad.xcscheme` mirroring App.xcscheme.
#
# Idempotent guard: aborts if `App-iPad` target already exists.

require 'xcodeproj'
require 'fileutils'

PROJECT_PATH      = 'ios/App/App.xcodeproj'
SOURCE_TARGET     = 'App'
NEW_TARGET        = 'App-iPad'
NEW_BUNDLE_ID     = 'com.chibatakumi.film.lab.ipad'
IPAD_DEVICE_FAMILY = '2'
IPHONE_DEVICE_FAMILY_RESTORED = '1'

unless File.directory?(PROJECT_PATH)
  abort "ERROR: cannot find #{PROJECT_PATH}. Run from apps/capacitor-film-lab-ios."
end

proj = Xcodeproj::Project.open(PROJECT_PATH)

if proj.targets.any? { |t| t.name == NEW_TARGET }
  abort "ERROR: target '#{NEW_TARGET}' already exists. This script is one-shot."
end

app = proj.targets.find { |t| t.name == SOURCE_TARGET }
abort "ERROR: source target '#{SOURCE_TARGET}' not found." unless app

puts "Source target '#{SOURCE_TARGET}' located. Build phases:"
app.build_phases.each { |bp| puts "  #{bp.class.name.split('::').last}  files=#{bp.files.length}" }

# ---------------------------------------------------------------------------
# Create the new target.
# ---------------------------------------------------------------------------
puts "\nCreating new target '#{NEW_TARGET}'..."
ipad = proj.new_target(
  :application,
  NEW_TARGET,
  :ios,
  app.build_configurations.first.build_settings['IPHONEOS_DEPLOYMENT_TARGET'],
  nil,
  :swift
)

# ---------------------------------------------------------------------------
# Mirror build settings from App (Debug + Release), then override identity.
# ---------------------------------------------------------------------------
%w[Debug Release].each do |cfg_name|
  src = app.build_configurations.find { |c| c.name == cfg_name }
  dst = ipad.build_configurations.find { |c| c.name == cfg_name }
  abort "ERROR: missing #{cfg_name} config on source or new target." unless src && dst

  # Replace dst settings wholesale to avoid xcodeproj defaults bleeding in.
  dst.build_settings = src.build_settings.dup
  dst.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = NEW_BUNDLE_ID
  dst.build_settings['TARGETED_DEVICE_FAMILY']   = IPAD_DEVICE_FAMILY
  dst.build_settings['PRODUCT_NAME']             = '$(TARGET_NAME)'

  # Share the same Pods xcconfig base (empty Capacitor stub).
  dst.base_configuration_reference = src.base_configuration_reference
end

# ---------------------------------------------------------------------------
# Mirror source files into new target's Sources build phase.
# ---------------------------------------------------------------------------
src_sources = app.source_build_phase
dst_sources = ipad.source_build_phase
puts "\nMirroring #{src_sources.files.length} source files..."
src_sources.files.each do |bf|
  next unless bf.file_ref
  new_bf = dst_sources.add_file_reference(bf.file_ref, true)
  new_bf.settings = bf.settings.dup if bf.settings && !bf.settings.empty?
end

# ---------------------------------------------------------------------------
# Mirror frameworks (Pods_App.framework, FilmLabSwiftCore product).
#
# First strip xcodeproj's auto-default Foundation.framework link (added by
# new_target with a stale iPhoneOS14.0.sdk path); the App target does not
# carry it, so mirror parity demands removal.
# ---------------------------------------------------------------------------
dst_fw_default = ipad.frameworks_build_phase
dst_fw_default.files.dup.each do |bf|
  next unless bf.file_ref&.path&.include?('iPhoneOS') &&
              bf.file_ref.path.include?('Foundation.framework')
  ref = bf.file_ref
  bf.remove_from_project
  ref.remove_from_project if proj.objects.none? { |o|
    o.respond_to?(:file_ref) && o.file_ref == ref
  }
end

src_fw = app.frameworks_build_phase
dst_fw = ipad.frameworks_build_phase
puts "Mirroring #{src_fw.files.length} framework links..."
src_fw.files.each do |bf|
  if bf.product_ref
    # SwiftPM product (FilmLabSwiftCore) — share the same product ref.
    new_bf = proj.new(Xcodeproj::Project::Object::PBXBuildFile)
    new_bf.product_ref = bf.product_ref
    dst_fw.files << new_bf
  elsif bf.file_ref
    dst_fw.add_file_reference(bf.file_ref, true)
  end
end

# ---------------------------------------------------------------------------
# Mirror resources.
# ---------------------------------------------------------------------------
src_rs = app.resources_build_phase
dst_rs = ipad.resources_build_phase
puts "Mirroring #{src_rs.files.length} resource entries..."
src_rs.files.each do |bf|
  next unless bf.file_ref
  dst_rs.add_file_reference(bf.file_ref, true)
end

# ---------------------------------------------------------------------------
# DO NOT mirror "Embed Foundation Extensions" or the corresponding target
# dependency. The existing `FilmtoneExportActivity` extension has bundle ID
# `com.chibatakumi.film.lab.ios.exportactivity` — Apple's embedded-binary
# rule requires the extension's bundle ID to be prefixed with the host
# app's bundle ID, but the iPad host is `com.chibatakumi.film.lab.ipad`,
# which does not match the .ios. prefix.
#
# Renaming the extension or creating a parallel iPad-prefixed extension
# both fall outside the M5-A "iPhone-target-only device-family restore"
# scope. Therefore the iPad target ships without the share-sheet
# extension in M5-A. Revisit in a later milestone.
# ---------------------------------------------------------------------------
puts "Skipping copy-files (extension embed) — iPad host bundle ID prefix\n" \
     "  mismatch with FilmtoneExportActivity bundle ID. Honest Limitation\n" \
     "  recorded in active.md."

# ---------------------------------------------------------------------------
# Swift Package product dependencies.
# ---------------------------------------------------------------------------
puts "\nMirroring #{app.package_product_dependencies.length} package dep(s)..."
app.package_product_dependencies.each do |dep|
  ipad.package_product_dependencies << dep
end

# ---------------------------------------------------------------------------
# Target dependencies — skip FilmtoneExportActivity (see Embed comment above).
# Any future non-extension target deps are mirrored.
# ---------------------------------------------------------------------------
puts "Mirroring target dep(s), skipping FilmtoneExportActivity..."
app.dependencies.each do |dep|
  next unless dep.target
  next if dep.target.name == 'FilmtoneExportActivity'
  ipad.add_dependency(dep.target)
end

# ---------------------------------------------------------------------------
# Restore App (iPhone) target device family from "1,2" -> "1".
# ---------------------------------------------------------------------------
puts "\nRestoring '#{SOURCE_TARGET}' TARGETED_DEVICE_FAMILY to '#{IPHONE_DEVICE_FAMILY_RESTORED}'..."
app.build_configurations.each do |cfg|
  before = cfg.build_settings['TARGETED_DEVICE_FAMILY']
  cfg.build_settings['TARGETED_DEVICE_FAMILY'] = IPHONE_DEVICE_FAMILY_RESTORED
  puts "  #{cfg.name}: #{before.inspect} -> #{IPHONE_DEVICE_FAMILY_RESTORED.inspect}"
end

proj.save
puts "\nProject saved: #{PROJECT_PATH}"

# ---------------------------------------------------------------------------
# Shared scheme.
# ---------------------------------------------------------------------------
scheme_dir = File.join(PROJECT_PATH, 'xcshareddata/xcschemes')
FileUtils.mkdir_p(scheme_dir)

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(ipad)
scheme.set_launch_target(ipad)
scheme.save_as(PROJECT_PATH, NEW_TARGET, true)
puts "Shared scheme saved: #{scheme_dir}/#{NEW_TARGET}.xcscheme"

puts "\nDone. Verify with:"
puts "  xcodebuild -workspace ios/App/App.xcworkspace -scheme #{NEW_TARGET} \\"
puts "    -destination 'generic/platform=iOS Simulator' -configuration Debug \\"
puts "    build CODE_SIGNING_ALLOWED=NO"
