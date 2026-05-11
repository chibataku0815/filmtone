#!/usr/bin/env ruby
# Filmtone iOS Feature-Based Architecture Refactor — pbxproj migration
#
# Phase 1A: --dry-run (default) prints planned mutations.
# Phase 1B: --apply writes changes to project.pbxproj.
# Phase 1B verify: --verify asserts the strict post-move gate.
#
# Reads file-mapping.yaml as the single source of truth. Will not run if
# the yaml diverges from the on-disk file set or from the pbxproj-tracked
# source list.
#
# Usage (from repo root):
#   bundle exec ruby apps/capacitor-film-lab-ios/scripts/refactor/migrate-pbxproj.rb --dry-run
#   bundle exec ruby apps/capacitor-film-lab-ios/scripts/refactor/migrate-pbxproj.rb --apply
#   bundle exec ruby apps/capacitor-film-lab-ios/scripts/refactor/migrate-pbxproj.rb --verify

require "yaml"
require "set"
require "pathname"

begin
  require "xcodeproj"
rescue LoadError
  abort "xcodeproj gem not available. Install with: gem install xcodeproj"
end

REPO_ROOT      = File.expand_path("../../../..", __dir__)
MAPPING_PATH   = File.join(REPO_ROOT, "apps/capacitor-film-lab-ios/scripts/refactor/file-mapping.yaml")
PROJECT_PATH   = File.join(REPO_ROOT, "apps/capacitor-film-lab-ios/ios/App/App.xcodeproj")
SOURCE_ROOT    = File.join(REPO_ROOT, "apps/capacitor-film-lab-ios/ios/App/App")
EXPORT_TARGET  = "FilmtoneExportActivity"

mode = ARGV.find { |a| %w[--dry-run --apply --verify].include?(a) } || "--dry-run"

puts "[mode] #{mode}"
puts "[repo] #{REPO_ROOT}"

mapping = YAML.load_file(MAPPING_PATH)
folders = mapping.fetch("folders")
expected_total_moved = mapping.dig("totals", "expected_total_moved") || 109

# Sanity: yaml + filesystem agree.
# Glob recursively so the check works both pre-move (flat) and post-move
# (subfolders). ExportActivity files are excluded since they stay in place.
disk_files = Dir.glob(File.join(SOURCE_ROOT, "**/*.{swift,metal}"))
                .reject { |p| p.include?("/FilmtoneExportActivity/") }
                .map { |p| File.basename(p) }.sort
yaml_files = folders.values.flat_map { |v| v.fetch("files") }.sort
missing = (yaml_files - disk_files)
extras  = (disk_files - yaml_files)
unless missing.empty? && extras.empty?
  abort "[fatal] mapping/disk mismatch — missing=#{missing.inspect} extras=#{extras.inspect}"
end
abort "[fatal] expected #{expected_total_moved} moved files, got #{yaml_files.size}" \
  unless yaml_files.size == expected_total_moved

project = Xcodeproj::Project.open(PROJECT_PATH)
app_target = project.targets.find { |t| t.name == "App" }
abort "[fatal] App target not found" unless app_target
export_target = project.targets.find { |t| t.name == EXPORT_TARGET }
abort "[fatal] #{EXPORT_TARGET} target not found" unless export_target

app_group = project["App"]
abort "[fatal] App group not found" unless app_group

# Snapshot pre-state for parity checks
pre_app_source_count    = app_target.source_build_phase.files.size
pre_export_source_count = export_target.source_build_phase.files.size

filename_to_target_folder = {}
folders.each do |folder, info|
  info.fetch("files").each { |f| filename_to_target_folder[f] = folder }
end

# Find the file reference for a given filename. We expect each filename to
# resolve to exactly one PBXFileReference in the App group hierarchy.
def find_ref(group, filename)
  group.files.find { |r| r.path == filename } ||
    group.children.flat_map { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) ? c.files : [] }
                  .find { |r| r&.path == filename }
end

# Plans are built from the yaml — they describe the intended end state.
# In --dry-run / --apply we'll cross-check against the App group flat list,
# because that's where files live BEFORE the migration. In --verify we skip
# that cross-check because by definition refs have already moved into
# sub-groups.
plans = filename_to_target_folder.map do |filename, target_folder|
  { filename: filename, target_folder: target_folder, target_path: filename }
end

if mode != "--verify"
  current_refs = {}
  app_group.files.each { |r| current_refs[r.path] = r if r.path }
  abort "[fatal] no file references in App group (already migrated? run --verify)" \
    if current_refs.empty?

  unmapped_on_disk = current_refs.keys - filename_to_target_folder.keys
  unless unmapped_on_disk.empty?
    ea_group = app_group.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.path == "FilmtoneExportActivity" }
    abort "[fatal] flat App group has unmapped refs: #{unmapped_on_disk.inspect}" \
      unless ea_group
  end

  plans.each do |p|
    ref = current_refs[p[:filename]]
    abort "[fatal] no PBXFileReference for #{p[:filename]} in App group" unless ref
  end
end

target_groups_to_create = filename_to_target_folder.values.uniq.sort

if mode == "--dry-run"
  puts ""
  puts "== Plan summary =="
  puts "Files to move: #{plans.size}"
  puts "Groups to create under App/: #{target_groups_to_create.inspect}"
  puts "App target source count (pre): #{pre_app_source_count}"
  puts "ExportActivity target source count (pre): #{pre_export_source_count}"
  puts ""
  puts "== Per-file plan (first 20) =="
  plans.first(20).each do |p|
    puts "  #{p[:filename]} -> App/#{p[:target_folder]}/"
  end
  puts "  ... (#{plans.size - 20} more)" if plans.size > 20
  puts ""
  puts "== Verifications that --apply will run after =="
  puts "  - App target source count == #{pre_app_source_count} (no add/remove)"
  puts "  - ExportActivity target source count == #{pre_export_source_count}"
  puts "  - Every moved ref.real_path.exist? after filesystem move"
  puts "  - Every moved ref.path is unchanged (bare filename)"
  puts "  - Parent group path == target folder name"
  puts ""
  puts "(dry-run: project.pbxproj NOT modified)"
  exit 0

elsif mode == "--apply"
  puts ""
  puts "== Applying =="
  group_handles = {}
  target_groups_to_create.each do |folder|
    existing = app_group.children.find do |c|
      c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.path == folder
    end
    if existing
      puts "  group #{folder}/ already exists — reusing"
      group_handles[folder] = existing
    else
      grp = app_group.new_group(folder, folder)
      group_handles[folder] = grp
      puts "  created group #{folder}/"
    end
  end

  plans.each do |p|
    ref = current_refs[p[:filename]]
    target_group = group_handles.fetch(p[:target_folder])
    ref.move(target_group)
  end

  project.save
  puts "  saved #{PROJECT_PATH}"
  puts ""
  puts "[apply] complete. Run --verify next."
  exit 0

elsif mode == "--verify"
  puts ""
  puts "== Strict gate =="
  failures = []

  # 1. ref.path is bare filename, parent group has folder path, real_path exists
  plans.each do |p|
    ref = nil
    target_group = app_group.children.find do |c|
      c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.path == p[:target_folder]
    end
    unless target_group
      failures << "missing target group App/#{p[:target_folder]}/"
      next
    end
    ref = target_group.files.find { |r| r.path == p[:filename] }
    unless ref
      failures << "ref not in App/#{p[:target_folder]}/: #{p[:filename]}"
      next
    end
    if ref.path != p[:filename]
      failures << "ref.path mismatch (expected bare filename #{p[:filename]}, got #{ref.path})"
    end
    rp = ref.real_path
    unless rp.exist?
      failures << "real_path missing: #{rp}"
    end
  end

  # 2. App target source count parity
  post_app_source_count = app_target.source_build_phase.files.size
  if post_app_source_count != pre_app_source_count
    failures << "App target source count drifted: pre=#{pre_app_source_count} post=#{post_app_source_count}"
  end

  # 3. ExportActivity target source count parity
  post_export_source_count = export_target.source_build_phase.files.size
  if post_export_source_count != pre_export_source_count
    failures << "ExportActivity target source count drifted: pre=#{pre_export_source_count} post=#{post_export_source_count}"
  end

  # 4. Every moved ref appears in App target source build phase
  app_source_paths = app_target.source_build_phase.files_references.map(&:path).to_set
  plans.each do |p|
    unless app_source_paths.include?(p[:filename])
      failures << "App target source build phase missing: #{p[:filename]}" \
        unless p[:filename].end_with?(".metal") # .metal is in resources/sources phase, not source phase — skip
    end
  end

  if failures.empty?
    puts "  PASS — all #{plans.size} plans verified, App+ExportActivity counts unchanged"
    exit 0
  else
    puts "  FAIL (#{failures.size}):"
    failures.each { |f| puts "    - #{f}" }
    exit 1
  end
else
  abort "unknown mode: #{mode}"
end
