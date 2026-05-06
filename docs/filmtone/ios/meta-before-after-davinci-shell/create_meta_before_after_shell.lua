local asset_dir = arg[1]
if not asset_dir or asset_dir == "" then
    error("asset_dir argument is required", 0)
end

local function path_join(a, b)
    if a:sub(-1) == "/" then return a .. b end
    return a .. "/" .. b
end

local function first_value(values)
    if type(values) ~= "table" then
        return values
    end
    for key, value in pairs(values) do
        if type(key) == "number" and value ~= nil then
            return value
        end
    end
    for _, value in pairs(values) do
        if value ~= nil then
            return value
        end
    end
    return nil
end

local function set_setting(target, key, value)
    if target and target.SetSetting then
        pcall(function() target:SetSetting(key, tostring(value)) end)
    end
end

local function unique_timeline_name(project, base)
    local existing = {}
    local count = project:GetTimelineCount() or 0
    for i = 1, count do
        local timeline = project:GetTimelineByIndex(i)
        if timeline then
            existing[timeline:GetName()] = true
        end
    end
    if not existing[base] then return base end
    for i = 2, 99 do
        local name = base:gsub("_v001$", string.format("_v%03d", i))
        if not existing[name] then return name end
    end
    return base .. "_" .. tostring(os.time())
end

local function ensure_bin(media_pool, root, name)
    if root and root.GetSubFolderList then
        local folders = root:GetSubFolderList() or {}
        for _, folder in ipairs(folders) do
            if folder and folder.GetName and folder:GetName() == name then
                return folder
            end
        end
    end
    if media_pool and media_pool.AddSubFolder then
        local created = media_pool:AddSubFolder(root, name)
        if created then return created end
    end
    return root
end

local function import_one(media_pool, folder, path)
    if media_pool.SetCurrentFolder and folder then
        media_pool:SetCurrentFolder(folder)
    end
    local imported = media_pool:ImportMedia({ path })
    local item = first_value(imported)
    if not item then
        error("failed to import media: " .. tostring(path), 0)
    end
    return item
end

local function set_item_property(item, key, value)
    if item and item.SetProperty then
        local ok = pcall(function() return item:SetProperty(key, value) end)
        return ok
    end
    return false
end

local function set_clip_vertical_position(item, tilt_value)
    set_item_property(item, "PositionY", -tilt_value)
    set_item_property(item, "Tilt", tilt_value)
end

local resolve = Resolve()
if not resolve then error("Resolve scripting object unavailable", 0) end
local project_manager = resolve:GetProjectManager()
if not project_manager then error("ProjectManager unavailable", 0) end
local project = project_manager:GetCurrentProject()
if not project then
    project = project_manager:CreateProject("Filmtone Meta BeforeAfter 2026-05")
end
if not project then error("no Resolve project available", 0) end

set_setting(project, "timelineFrameRate", "30")
set_setting(project, "timelinePlaybackFrameRate", "30")
set_setting(project, "timelineResolutionWidth", "1080")
set_setting(project, "timelineResolutionHeight", "1920")
set_setting(project, "timelineOutputResolutionWidth", "1080")
set_setting(project, "timelineOutputResolutionHeight", "1920")

local media_pool = project:GetMediaPool()
if not media_pool then error("MediaPool unavailable", 0) end
local root = media_pool:GetRootFolder()

local bins = {
    before = ensure_bin(media_pool, root, "01_before"),
    after = ensure_bin(media_pool, root, "02_after"),
    ui = ensure_bin(media_pool, root, "03_ui_or_screen_recording"),
    audio = ensure_bin(media_pool, root, "04_audio"),
    graphics = ensure_bin(media_pool, root, "05_graphics_logo"),
    timelines = ensure_bin(media_pool, root, "06_timelines"),
    exports = ensure_bin(media_pool, root, "07_exports"),
}

local bg = import_one(media_pool, bins.graphics, path_join(asset_dir, "layout_background_9x16_15s.mp4"))
local before = import_one(media_pool, bins.before, path_join(asset_dir, "before_horizontal_placeholder_15s.mp4"))
local after = import_one(media_pool, bins.after, path_join(asset_dir, "after_horizontal_placeholder_15s.mp4"))

if media_pool.SetCurrentFolder and bins.timelines then
    media_pool:SetCurrentFolder(bins.timelines)
end

local base_name = "META_9x16_15s_STACKED_BEFORE_AFTER_v001"
local timeline_name = unique_timeline_name(project, base_name)
local timeline = media_pool:CreateEmptyTimeline(timeline_name)
if not timeline then error("failed to create timeline: " .. timeline_name, 0) end
project:SetCurrentTimeline(timeline)

set_setting(timeline, "timelineFrameRate", "30")
set_setting(timeline, "timelinePlaybackFrameRate", "30")
set_setting(timeline, "timelineResolutionWidth", "1080")
set_setting(timeline, "timelineResolutionHeight", "1920")
set_setting(timeline, "timelineOutputResolutionWidth", "1080")
set_setting(timeline, "timelineOutputResolutionHeight", "1920")

if timeline.AddTrack then
    pcall(function() timeline:AddTrack("video") end)
    pcall(function() timeline:AddTrack("video") end)
    pcall(function() timeline:AddTrack("video") end)
end

local record_frame = 0
if timeline.GetStartFrame then
    local ok, value = pcall(function() return timeline:GetStartFrame() end)
    if ok and value then
        record_frame = value
    end
end

local clips = {
    { mediaPoolItem = bg, startFrame = 0, endFrame = 449, recordFrame = record_frame, mediaType = 1, trackIndex = 1 },
    { mediaPoolItem = before, startFrame = 0, endFrame = 449, recordFrame = record_frame, mediaType = 1, trackIndex = 2 },
    { mediaPoolItem = after, startFrame = 0, endFrame = 449, recordFrame = record_frame, mediaType = 1, trackIndex = 3 },
}
local appended = media_pool:AppendToTimeline(clips)
if not appended then error("failed to append placeholder clips", 0) end

local before_items = timeline.GetItemListInTrack and timeline:GetItemListInTrack("video", 2) or {}
local after_items = timeline.GetItemListInTrack and timeline:GetItemListInTrack("video", 3) or {}
local before_item = first_value(before_items)
local after_item = first_value(after_items)

if before_item then
    set_clip_vertical_position(before_item, 376)
    set_item_property(before_item, "ZoomX", 1)
    set_item_property(before_item, "ZoomY", 1)
end
if after_item then
    set_clip_vertical_position(after_item, -376)
    set_item_property(after_item, "ZoomX", 1)
    set_item_property(after_item, "ZoomY", 1)
end

if timeline.AddMarker then
    timeline:AddMarker(0, "Blue", "00 setup", "Top text + stacked Before/After shell", 1)
    timeline:AddMarker(60, "Green", "02 reveal", "Replace placeholders with aligned Before/After media", 1)
    timeline:AddMarker(360, "Yellow", "12 CTA", "Use user-provided text only", 1)
end

if project_manager.SaveProject then
    pcall(function() project_manager:SaveProject() end)
end

print("created_project=" .. tostring(project:GetName()))
print("created_timeline=" .. tostring(timeline_name))
print("asset_dir=" .. tostring(asset_dir))
