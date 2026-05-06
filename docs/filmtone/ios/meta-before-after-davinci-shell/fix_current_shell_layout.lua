local function first_value(values)
    if type(values) ~= "table" then
        return nil
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

local function set_item_property(item, key, value)
    if item and item.SetProperty then
        pcall(function() item:SetProperty(key, value) end)
    end
end

local resolve = Resolve()
if not resolve then error("Resolve scripting object unavailable", 0) end
local pm = resolve:GetProjectManager()
local project = pm and pm:GetCurrentProject()
if not project then error("no current project", 0) end
local timeline = project:GetCurrentTimeline()
if not timeline then error("no current timeline", 0) end

local before_item = first_value(timeline:GetItemListInTrack("video", 2))
local after_item = first_value(timeline:GetItemListInTrack("video", 3))
if not before_item then error("before item missing on V2", 0) end
if not after_item then error("after item missing on V3", 0) end

set_item_property(before_item, "PositionY", -376)
set_item_property(before_item, "Tilt", 376)
set_item_property(before_item, "ZoomX", 1)
set_item_property(before_item, "ZoomY", 1)
set_item_property(after_item, "PositionY", 376)
set_item_property(after_item, "Tilt", -376)
set_item_property(after_item, "ZoomX", 1)
set_item_property(after_item, "ZoomY", 1)

if pm and pm.SaveProject then
    pcall(function() pm:SaveProject() end)
end

print("fixed_timeline=" .. tostring(timeline:GetName()))
print("before_track=V2 PositionY=-376")
print("after_track=V3 PositionY=376")
local function fmt(value)
    if value == nil then return "nil" end
    return tostring(value)
end
if before_item.GetProperty then
    print("before_PositionY_readback=" .. fmt(before_item:GetProperty("PositionY")))
    print("before_Pan_readback=" .. fmt(before_item:GetProperty("Pan")))
    print("before_Tilt_readback=" .. fmt(before_item:GetProperty("Tilt")))
    print("before_ZoomX_readback=" .. fmt(before_item:GetProperty("ZoomX")))
end
if after_item.GetProperty then
    print("after_PositionY_readback=" .. fmt(after_item:GetProperty("PositionY")))
    print("after_Pan_readback=" .. fmt(after_item:GetProperty("Pan")))
    print("after_Tilt_readback=" .. fmt(after_item:GetProperty("Tilt")))
    print("after_ZoomX_readback=" .. fmt(after_item:GetProperty("ZoomX")))
end
