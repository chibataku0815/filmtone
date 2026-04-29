-- Filmtone Connect for DaVinci v0 spike.
--
-- Install as a Resolve Workspace Script, or run with fuscript while Resolve is open.
-- Package path resolution order:
--   1. --package /path/to/FilmtoneExport
--   2. first positional argument
--   3. FILMTONE_CONNECT_PACKAGE environment variable
--   4. DEFAULT_PACKAGE_DIR below
--   5. macOS folder picker
--   6. console prompt
--
-- Dry-run parser check:
--   /Applications/DaVinci\ Resolve/DaVinci\ Resolve.app/Contents/Libraries/Fusion/fuscript \
--     filmtone_connect_import_package.lua --dry-run --package /path/to/package

local DEFAULT_PACKAGE_DIR = nil
local CONNECT_VERSION = "filmtone-connect-davinci-v0"
local SIDECAR_SUFFIX = ".filmtone-ios-export-session-v1.json"
local DEFAULT_LUT_FILENAME = "combined-color.cube"
local DEFAULT_REFERENCE_FILENAME = "reference-after.jpg"

local function log(message)
    print("[Filmtone Connect] " .. tostring(message))
end

local function fatal(message)
    error("[Filmtone Connect] " .. tostring(message), 0)
end

local function trim(value)
    if value == nil then
        return nil
    end
    return tostring(value):gsub("^%s+", ""):gsub("%s+$", "")
end

local function shell_quote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function path_join(base, name)
    if base:sub(-1) == "/" then
        return base .. name
    end
    return base .. "/" .. name
end

local function basename(path)
    local normalized = tostring(path):gsub("/+$", "")
    return normalized:match("([^/]+)$") or normalized
end

local function dirname(path)
    return tostring(path):match("^(.*)/[^/]+$") or "."
end

local function without_extension(name)
    return tostring(name):gsub("%.[^.]+$", "")
end

local function ends_with(value, suffix)
    value = tostring(value)
    return suffix == "" or value:sub(-#suffix) == suffix
end

local function file_exists(path)
    local handle = io.open(path, "rb")
    if handle then
        handle:close()
        return true
    end
    return false
end

local function read_file(path)
    local handle = io.open(path, "rb")
    if not handle then
        fatal("could not read file: " .. tostring(path))
    end
    local data = handle:read("*a")
    handle:close()
    return data
end

local function list_files(dir)
    local command = "find " .. shell_quote(dir) .. " -maxdepth 1 -type f -print"
    local pipe = io.popen(command)
    if not pipe then
        fatal("could not list package directory: " .. tostring(dir))
    end
    local files = {}
    for line in pipe:lines() do
        files[#files + 1] = line
    end
    pipe:close()
    table.sort(files)
    return files
end

local function first_table_value(values)
    if type(values) ~= "table" then
        return nil
    end
    if values[1] ~= nil then
        return values[1]
    end
    for _, value in pairs(values) do
        return value
    end
    return nil
end

local function parse_args()
    local options = {
        dry_run = false,
        package_dir = nil,
    }
    local i = 1
    local args = _G.arg or {}
    while i <= #args do
        local value = args[i]
        if value == "--dry-run" then
            options.dry_run = true
        elseif value == "--package" then
            i = i + 1
            options.package_dir = args[i]
        elseif value and value:sub(1, 2) ~= "--" and not options.package_dir then
            options.package_dir = value
        end
        i = i + 1
    end
    return options
end

local function prompt_package_dir()
    io.write("Filmtone package folder: ")
    local value = io.read("*l")
    return trim(value)
end

local function choose_package_dir_with_osascript()
    if (os.getenv("OSTYPE") or ""):lower():match("linux") then
        return nil
    end
    local script = 'POSIX path of (choose folder with prompt "Select Filmtone package folder")'
    local pipe = io.popen("osascript -e " .. shell_quote(script) .. " 2>/dev/null")
    if not pipe then
        return nil
    end
    local value = trim(pipe:read("*a"))
    pipe:close()
    if value == "" then
        return nil
    end
    return value
end

local function resolve_package_dir(options)
    local dir = trim(options.package_dir)
        or trim(os.getenv("FILMTONE_CONNECT_PACKAGE"))
        or trim(DEFAULT_PACKAGE_DIR)
    if not dir or dir == "" then
        dir = choose_package_dir_with_osascript()
    end
    if not dir or dir == "" then
        dir = prompt_package_dir()
    end
    if not dir or dir == "" then
        fatal("missing package folder. Set FILMTONE_CONNECT_PACKAGE or pass --package.")
    end
    return dir:gsub("/+$", "")
end

-- Minimal JSON decoder for sidecar manifests. No external modules are available
-- in Resolve Workspace Scripts, so keep this parser local and tolerant.
local Json = {}

function Json:new(text)
    return setmetatable({ text = text, pos = 1, len = #text }, { __index = self })
end

function Json:peek()
    return self.text:sub(self.pos, self.pos)
end

function Json:next_char()
    local char = self:peek()
    self.pos = self.pos + 1
    return char
end

function Json:skip_ws()
    while self.pos <= self.len do
        local char = self:peek()
        if char ~= " " and char ~= "\n" and char ~= "\r" and char ~= "\t" then
            break
        end
        self.pos = self.pos + 1
    end
end

function Json:expect(expected)
    local actual = self:next_char()
    if actual ~= expected then
        fatal("invalid JSON at byte " .. tostring(self.pos - 1) .. ": expected " .. expected)
    end
end

local function utf8_from_codepoint(codepoint)
    if codepoint <= 0x7f then
        return string.char(codepoint)
    elseif codepoint <= 0x7ff then
        return string.char(
            0xc0 + math.floor(codepoint / 0x40),
            0x80 + (codepoint % 0x40)
        )
    elseif codepoint <= 0xffff then
        return string.char(
            0xe0 + math.floor(codepoint / 0x1000),
            0x80 + (math.floor(codepoint / 0x40) % 0x40),
            0x80 + (codepoint % 0x40)
        )
    end
    return string.char(
        0xf0 + math.floor(codepoint / 0x40000),
        0x80 + (math.floor(codepoint / 0x1000) % 0x40),
        0x80 + (math.floor(codepoint / 0x40) % 0x40),
        0x80 + (codepoint % 0x40)
    )
end

function Json:parse_string()
    self:expect('"')
    local chunks = {}
    while self.pos <= self.len do
        local char = self:next_char()
        if char == '"' then
            return table.concat(chunks)
        elseif char == "\\" then
            local escaped = self:next_char()
            if escaped == '"' or escaped == "\\" or escaped == "/" then
                chunks[#chunks + 1] = escaped
            elseif escaped == "b" then
                chunks[#chunks + 1] = "\b"
            elseif escaped == "f" then
                chunks[#chunks + 1] = "\f"
            elseif escaped == "n" then
                chunks[#chunks + 1] = "\n"
            elseif escaped == "r" then
                chunks[#chunks + 1] = "\r"
            elseif escaped == "t" then
                chunks[#chunks + 1] = "\t"
            elseif escaped == "u" then
                local hex = self.text:sub(self.pos, self.pos + 3)
                self.pos = self.pos + 4
                local codepoint = tonumber(hex, 16) or 0x3f
                chunks[#chunks + 1] = utf8_from_codepoint(codepoint)
            else
                fatal("invalid JSON escape at byte " .. tostring(self.pos - 1))
            end
        else
            chunks[#chunks + 1] = char
        end
    end
    fatal("unterminated JSON string")
end

function Json:parse_number()
    local start_pos = self.pos
    local char = self:peek()
    if char == "-" then
        self.pos = self.pos + 1
    end
    while self:peek():match("%d") do
        self.pos = self.pos + 1
    end
    if self:peek() == "." then
        self.pos = self.pos + 1
        while self:peek():match("%d") do
            self.pos = self.pos + 1
        end
    end
    char = self:peek()
    if char == "e" or char == "E" then
        self.pos = self.pos + 1
        char = self:peek()
        if char == "+" or char == "-" then
            self.pos = self.pos + 1
        end
        while self:peek():match("%d") do
            self.pos = self.pos + 1
        end
    end
    return tonumber(self.text:sub(start_pos, self.pos - 1))
end

function Json:parse_literal(literal, value)
    if self.text:sub(self.pos, self.pos + #literal - 1) ~= literal then
        fatal("invalid JSON literal at byte " .. tostring(self.pos))
    end
    self.pos = self.pos + #literal
    return value
end

function Json:parse_array()
    self:expect("[")
    local result = {}
    self:skip_ws()
    if self:peek() == "]" then
        self.pos = self.pos + 1
        return result
    end
    while true do
        result[#result + 1] = self:parse_value()
        self:skip_ws()
        local char = self:next_char()
        if char == "]" then
            return result
        elseif char ~= "," then
            fatal("invalid JSON array at byte " .. tostring(self.pos - 1))
        end
    end
end

function Json:parse_object()
    self:expect("{")
    local result = {}
    self:skip_ws()
    if self:peek() == "}" then
        self.pos = self.pos + 1
        return result
    end
    while true do
        self:skip_ws()
        local key = self:parse_string()
        self:skip_ws()
        self:expect(":")
        result[key] = self:parse_value()
        self:skip_ws()
        local char = self:next_char()
        if char == "}" then
            return result
        elseif char ~= "," then
            fatal("invalid JSON object at byte " .. tostring(self.pos - 1))
        end
    end
end

function Json:parse_value()
    self:skip_ws()
    local char = self:peek()
    if char == "{" then
        return self:parse_object()
    elseif char == "[" then
        return self:parse_array()
    elseif char == '"' then
        return self:parse_string()
    elseif char == "-" or char:match("%d") then
        return self:parse_number()
    elseif char == "t" then
        return self:parse_literal("true", true)
    elseif char == "f" then
        return self:parse_literal("false", false)
    elseif char == "n" then
        return self:parse_literal("null", nil)
    end
    fatal("invalid JSON value at byte " .. tostring(self.pos))
end

local function decode_json(text)
    local parser = Json:new(text)
    local value = parser:parse_value()
    parser:skip_ws()
    if parser.pos <= parser.len then
        fatal("unexpected trailing JSON at byte " .. tostring(parser.pos))
    end
    return value
end

local function find_file_by_name(package_dir, name)
    if not name or name == "" then
        return nil
    end
    local path = path_join(package_dir, name)
    if file_exists(path) then
        return path
    end
    return nil
end

local function find_first_matching(files, predicate)
    for _, path in ipairs(files) do
        if predicate(path, basename(path)) then
            return path
        end
    end
    return nil
end

local function sidecar_uri_basename(uri)
    if type(uri) ~= "string" then
        return nil
    end
    local clean = uri:gsub("^file://", ""):gsub("%?.*$", "")
    return basename(clean)
end

local function discover_package(package_dir)
    local files = list_files(package_dir)
    local sidecar_path = find_first_matching(files, function(_, name)
        return ends_with(name, SIDECAR_SUFFIX)
    end)
    if not sidecar_path then
        fatal("missing sidecar (*" .. SIDECAR_SUFFIX .. ") in " .. package_dir)
    end

    local sidecar = decode_json(read_file(sidecar_path))
    if sidecar.kind ~= "filmtone-export-session" then
        fatal("unsupported sidecar kind: " .. tostring(sidecar.kind))
    end
    if sidecar.schema ~= "filmtone-ios-export-session-v1" then
        fatal("unsupported sidecar schema: " .. tostring(sidecar.schema))
    end

    local package_block = sidecar.package or {}
    local package_luts = package_block.luts or {}
    local media_path = find_file_by_name(package_dir, package_block.mediaFilename)
        or find_file_by_name(package_dir, sidecar_uri_basename(sidecar.output and sidecar.output.outputUri))
        or find_first_matching(files, function(_, name)
            local lower = name:lower()
            if ends_with(lower, ".json") or ends_with(lower, ".cube") then
                return false
            end
            if lower:match("^reference%-after%.") or lower:match("^reference%-before%.") then
                return false
            end
            return lower:match("%.mov$")
                or lower:match("%.mp4$")
                or lower:match("%.m4v$")
                or lower:match("%.jpg$")
                or lower:match("%.jpeg$")
                or lower:match("%.png$")
                or lower:match("%.heic$")
                or lower:match("%.tif$")
                or lower:match("%.tiff$")
        end)

    local lut_path = find_file_by_name(package_dir, package_luts.combinedColor)
        or find_file_by_name(package_dir, DEFAULT_LUT_FILENAME)
        or find_first_matching(files, function(_, name)
            return name:lower():match("%.cube$")
        end)

    local reference_path = find_file_by_name(package_dir, package_block.referenceAfterFilename)
        or find_file_by_name(package_dir, DEFAULT_REFERENCE_FILENAME)
        or find_first_matching(files, function(_, name)
            local lower = name:lower()
            return lower:match("^reference%-after%.jpg$")
                or lower:match("^reference%-after%.jpeg$")
                or lower:match("^reference%-after%.png$")
        end)

    if not media_path then
        fatal("missing media file in package")
    end
    if not lut_path then
        fatal("missing combined .cube LUT in package")
    end

    return {
        dir = package_dir,
        files = files,
        sidecar_path = sidecar_path,
        sidecar = sidecar,
        media_path = media_path,
        lut_path = lut_path,
        reference_path = reference_path,
    }
end

local function fmt_value(value, fallback)
    if value == nil then
        return fallback or "unknown"
    end
    return tostring(value)
end

local function active_amount(params, key)
    if type(params) ~= "table" or type(params[key]) ~= "number" then
        return nil
    end
    if math.abs(params[key]) < 0.000001 then
        return nil
    end
    return key .. "=" .. tostring(params[key])
end

local function build_effect_summary(sidecar)
    local params = sidecar.look and sidecar.look.params or {}
    local effects = {}
    local keys = {
        "bloomStrength",
        "bloomRadius",
        "diffusion",
        "halationIntensity",
        "halationSpread",
        "halationRadius",
        "grainIntensity",
        "grainSize",
        "vignette",
        "lensSoftness",
        "rgbShift",
        "shutterAngle",
        "trailIntensity",
    }
    for _, key in ipairs(keys) do
        local summary = active_amount(params, key)
        if summary then
            effects[#effects + 1] = summary
        end
    end
    if #effects == 0 then
        return "none signaled by sidecar params"
    end
    return table.concat(effects, ", ")
end

local function lut_ref_summary(name, ref)
    if type(ref) ~= "table" then
        return name .. "=none"
    end
    return name .. "(size=" .. fmt_value(ref.size, "?") .. ", intensity=" .. fmt_value(ref.intensity, "?") .. ")"
end

local function build_note(package)
    local sidecar = package.sidecar
    local look = sidecar.look or {}
    local output = sidecar.output or {}
    local depth = sidecar.depth or {}
    local mezzanine = sidecar.mezzanine or {}
    local lut_refs = sidecar.lutRefs or {}

    local lines = {
        "Filmtone Connect for DaVinci v0",
        "Package: " .. package.dir,
        "Sidecar: " .. basename(package.sidecar_path),
        "Preset: " .. fmt_value(look.presetName) .. " (" .. fmt_value(look.presetVersion) .. ")",
        "Output: " .. fmt_value(output.outputColorProfile)
            .. " / " .. fmt_value(output.colorPrimaries)
            .. "/" .. fmt_value(output.colorTransfer)
            .. "/" .. fmt_value(output.colorSpace)
            .. " / " .. fmt_value(output.outputWidth) .. "x" .. fmt_value(output.outputHeight)
            .. " " .. fmt_value(output.fps) .. "fps"
            .. " " .. fmt_value(output.codec) .. "." .. fmt_value(output.container),
        "LUT: " .. basename(package.lut_path)
            .. " -> node 1; "
            .. lut_ref_summary("inputLut", lut_refs.inputLut)
            .. "; "
            .. lut_ref_summary("creativeLut", lut_refs.creativeLut),
        "Baked effects: " .. build_effect_summary(sidecar),
        "Depth: used=" .. fmt_value(depth.used, "unknown")
            .. ", source=" .. fmt_value(depth.source, "none")
            .. ", renderer=" .. fmt_value(depth.renderer, "none")
            .. ", framesWithDepth=" .. fmt_value(depth.framesWithDepth, "n/a"),
        "Mezzanine: used=" .. fmt_value(mezzanine.used, "unknown")
            .. ", variant=" .. fmt_value(mezzanine.variant, "none")
            .. ", profileVersion=" .. fmt_value(mezzanine.profileVersion, "none"),
        "Reference: " .. fmt_value(package.reference_path, "none"),
        "Non-claim: LUT does not recreate depth, ray-angle optics, grain, motion blur, or halation spread; those are baked/reference provenance.",
    }
    return table.concat(lines, "\n")
end

local function copy_file(src, dst)
    local command = "mkdir -p " .. shell_quote(dirname(dst)) .. " && cp " .. shell_quote(src) .. " " .. shell_quote(dst)
    local result = os.execute(command)
    return result == true or result == 0
end

local function user_home()
    return os.getenv("HOME") or os.getenv("USERPROFILE") or ""
end

local function stage_lut(package, project)
    local lut_basename = basename(package.lut_path)
    local candidates = {}
    local env_lut_dir = trim(os.getenv("FILMTONE_RESOLVE_LUT_DIR"))
    if env_lut_dir and env_lut_dir ~= "" then
        candidates[#candidates + 1] = env_lut_dir
    end
    candidates[#candidates + 1] = "/Library/Application Support/Blackmagic Design/DaVinci Resolve/LUT/Filmtone Connect"
    if user_home() ~= "" then
        candidates[#candidates + 1] = path_join(user_home(), "Library/Application Support/Blackmagic Design/DaVinci Resolve/LUT/Filmtone Connect")
    end

    local staged = {}
    for _, dir in ipairs(candidates) do
        local staged_path = path_join(dir, lut_basename)
        if copy_file(package.lut_path, staged_path) then
            staged[#staged + 1] = {
                absolute = staged_path,
                relative = "Filmtone Connect/" .. lut_basename,
            }
        end
    end
    project:RefreshLUTList()
    return staged
end

local function import_reference_still(project, media_pool, reference_path)
    if not reference_path then
        log("reference still not present; skipping reference import")
        return false
    end

    local gallery = project:GetGallery()
    if gallery then
        local album = gallery:GetCurrentStillAlbum()
        if not album then
            album = gallery:CreateGalleryStillAlbum()
            if album then
                gallery:SetCurrentStillAlbum(album)
            end
        end
        if album and album:ImportStills({ reference_path }) then
            log("imported reference still into Gallery: " .. reference_path)
            return true
        end
    end

    local imported = media_pool:ImportMedia({ reference_path })
    if first_table_value(imported) then
        log("Gallery import failed; imported reference into Media Pool: " .. reference_path)
        return true
    end

    log("reference still import failed; marker note still includes the path")
    return false
end

local function add_filmtone_marker(timeline_item, media_pool_item, note, sidecar)
    local custom_data = CONNECT_VERSION .. ":" .. fmt_value(sidecar.exportedAtIso, "unknown")
    if timeline_item and timeline_item.AddMarker and timeline_item:AddMarker(1, "Blue", "Filmtone Connect", note, 1, custom_data) then
        log("added Filmtone marker to timeline item")
        return true
    end
    if media_pool_item and media_pool_item.AddMarker and media_pool_item:AddMarker(1, "Blue", "Filmtone Connect", note, 1, custom_data) then
        log("added Filmtone marker to media pool item")
        return true
    end
    log("could not add marker; printing note instead\n" .. note)
    return false
end

local function apply_lut_to_item(project, timeline_item, lut_path)
    local graph = timeline_item and timeline_item:GetNodeGraph()
    if not graph then
        fatal("could not access timeline item node graph")
    end
    local node_count = graph:GetNumNodes()
    if not node_count or node_count < 1 then
        fatal("timeline item has no color nodes; v0 expects Resolve's default node 1")
    end

    project:RefreshLUTList()
    if graph:SetLUT(1, lut_path) then
        log("applied package LUT to node 1: " .. lut_path)
        return true
    end

    local staged_luts = stage_lut({ lut_path = lut_path }, project)
    for _, staged in ipairs(staged_luts) do
        if graph:SetLUT(1, staged.relative) then
            log("applied staged LUT to node 1: " .. staged.relative .. " (" .. staged.absolute .. ")")
            return true
        end
        if graph:SetLUT(1, staged.absolute) then
            log("applied staged absolute LUT to node 1: " .. staged.absolute)
            return true
        end
    end

    fatal("LUT was not discovered by Resolve. Tried package path and staged LUT path for " .. lut_path)
end

local function run_resolve_import(package)
    local resolve = Resolve()
    if not resolve then
        fatal("Resolve scripting object is unavailable. Open DaVinci Resolve first.")
    end
    local project_manager = resolve:GetProjectManager()
    local project = project_manager and project_manager:GetCurrentProject()
    if not project then
        fatal("no DaVinci Resolve project is loaded")
    end
    local media_pool = project:GetMediaPool()
    if not media_pool then
        fatal("could not access Media Pool")
    end

    resolve:OpenPage("media")
    local imported = media_pool:ImportMedia({ package.media_path })
    local media_pool_item = first_table_value(imported)
    if not media_pool_item then
        fatal("media import failed: " .. package.media_path)
    end
    log("imported media: " .. package.media_path)

    local timeline = project:GetCurrentTimeline()
    local timeline_item = nil
    if timeline then
        local appended = media_pool:AppendToTimeline({ media_pool_item })
        timeline_item = first_table_value(appended)
        if not timeline_item then
            fatal("failed to append imported media to current timeline")
        end
    else
        local timeline_name = "Filmtone Connect - " .. without_extension(basename(package.media_path))
        timeline = media_pool:CreateTimelineFromClips(timeline_name, { media_pool_item })
        if not timeline then
            fatal("failed to create timeline for imported media")
        end
        project:SetCurrentTimeline(timeline)
        local items = timeline:GetItemListInTrack("video", 1)
        timeline_item = first_table_value(items)
        if not timeline_item then
            fatal("created timeline but could not find imported timeline item")
        end
    end
    log("timeline item ready")

    resolve:OpenPage("color")
    apply_lut_to_item(project, timeline_item, package.lut_path)

    local note = build_note(package)
    add_filmtone_marker(timeline_item, media_pool_item, note, package.sidecar)
    if media_pool_item and media_pool_item.SetThirdPartyMetadata then
        media_pool_item:SetThirdPartyMetadata("Filmtone Connect", note)
    end

    import_reference_still(project, media_pool, package.reference_path)

    log("done. Verify node 1 LUT, marker note, and reference still visually in Resolve.")
end

local function print_package_summary(package)
    log("package: " .. package.dir)
    log("sidecar: " .. package.sidecar_path)
    log("media: " .. package.media_path)
    log("lut: " .. package.lut_path)
    log("reference: " .. fmt_value(package.reference_path, "none"))
    log("marker note:\n" .. build_note(package))
end

local function main()
    local options = parse_args()
    local package_dir = resolve_package_dir(options)
    local package = discover_package(package_dir)
    print_package_summary(package)
    if options.dry_run then
        log("dry-run complete; Resolve import was not attempted")
        return
    end
    run_resolve_import(package)
end

main()
