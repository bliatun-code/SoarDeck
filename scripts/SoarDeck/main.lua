-- SPDX-License-Identifier: MIT
-- SoarDeck loader. ETHOS loads every installed main.lua at power-on, so this file
-- stays small. deck.lua holds the instruments. It loads with the first SoarDeck
-- widget of the active model and is released when the model has none. Only a
-- flight count that cannot be saved yet keeps it loaded. Settings, sources and
-- alarms are unchanged.
local VERSION = "2026.11-v4"
local FILE = "SCRIPTS:/SoarDeck/deck.lua"
local active
-- A copy that ETHOS still references is reused instead of compiled again.
local recent = setmetatable({}, {__mode = "v"})
-- Each widget keeps talking to the copy that created it.
local owners = setmetatable({}, {__mode = "k"})
local count = 0
-- ETHOS can keep menu and dialog functions after they close, even after the
-- widget is destroyed. deck.lua hands them out as relays from this file.
-- A relay reaches deck.lua only through its slot, and every slot is
-- emptied when deck.lua is released. Each menu row position keeps one
-- relay; each dialog button gets its own.
local slots, rows = setmetatable({}, {__mode = "k"}), {}

local function relay(action, closed, row)
    local slot = row and rows[row]
    if slot then
        slot[1] = action
        return slot[2]
    end
    slot = {action}
    slots[slot] = true
    slot[2] = function(...)
        local call = slot[1]
        if call then return call(...) end
        return closed
    end
    if row then rows[row] = slot end
    return slot[2]
end

local function load()
    if active then return active end
    active = recent[1]
    if active then return active end
    local chunk, problem = loadfile(FILE)
    if type(chunk) ~= "function" then
        error("SoarDeck: cannot load deck.lua. Reinstall SoarDeck. " .. tostring(problem), 0)
    end
    local module = chunk()
    local registered, shared
    if type(module) == "table" and type(module.init) == "function" then
        module.init(function(spec, state) registered, shared = spec, state end)
    end
    if type(registered) ~= "table" or type(registered.create) ~= "function" then
        error("SoarDeck: deck.lua does not match this loader. Reinstall SoarDeck.", 0)
    end
    -- deck.lua anchors this table in tables that its retained callbacks use.
    if type(shared) ~= "table" then shared = {} end
    shared.spec = registered
    shared.relay = relay
    active, recent[1] = shared, shared
    return shared
end

local function create()
    local module = load()
    local widget = module.spec.create()
    if type(widget) == "table" and not owners[widget] then
        owners[widget] = module
        count = count + 1
    end
    return widget
end

local function handler(widget, name)
    local module = owners[widget] or active
    return module and module.spec[name]
end

local function forward(name)
    return function(widget, ...)
        local call = handler(widget, name)
        if call then return call(widget, ...) end
    end
end

local function destroy(widget, ...)
    local call = handler(widget, "destroy")
    if owners[widget] then
        owners[widget] = nil
        count = count - 1
    end
    if call then call(widget, ...) end
    if count > 0 or not active then return end
    local keep = active.keepLoaded
    if type(keep) == "function" and keep() then return end
    active = nil
    for slot in pairs(slots) do slot[1] = nil end
    collectgarbage()
end

local function init()
    system.registerWidget({
        key = "SoarDk", name = "SoarDeck", create = create,
        paint = forward("paint"), wakeup = forward("wakeup"), configure = forward("configure"),
        read = forward("read"), write = forward("write"), menu = forward("menu"),
        destroy = destroy, event = forward("event"),
        persistent = true, title = false,
    })
end

return {init = init}
