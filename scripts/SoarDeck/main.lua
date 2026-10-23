-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 bliatun-code and SoarDeck contributors.
-- SoarDeck: sailplane instrumentation for FrSky ETHOS.
-- Generated standalone main.lua has no runtime module dependencies.
local VERSION = "2026.10-v1"
local Soar = (function()
    local M = {}
    function M.finite(n) return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge end
    function M.clamp(n,a,b) return math.max(a,math.min(b,n)) end
    function M.now() local ok,n=pcall(os.clock); return ok and M.finite(n) and n or 0 end
    function M.valid(w) return type(w)=="table" and not w.destroyed and type(w.cfg)=="table" and type(w.data)=="table" end
    function M.call(fn,...) if type(fn)=="function" then local ok,a,b=pcall(fn,...); if ok then return a,b end end end
    function M.selected(s)
        if s==nil or s==false or s=="" then return nil end
        local ok,c=pcall(function() return s:category() end)
        if ok and CATEGORY_NONE~=nil and c==CATEGORY_NONE then return nil end
        return (type(s)=="table" or type(s)=="userdata") and s or nil
    end
    function M.restore(s)
        if type(s)=="string" and s~="" then return M.selected(M.call(system.getSource,s)) end
        return M.selected(s)
    end
    function M.modelKey()
        local name=M.call(model.name) or "SoarDeck"
        local path=M.call(model.path)
        local id=M.call(model.id)
        return tostring(path or id or name),tostring(name)
    end
    function M.invalidate() if lcd and type(lcd.invalidate)=="function" then pcall(lcd.invalidate) end end
    function M.dirty() if model and type(model.dirty)=="function" then pcall(model.dirty) end end
    local function unitEquals(u,constant) return constant~=nil and u==constant end
    -- Canonical source units, never the source's translated display name.
    function M.sample(source,kind,maxAge)
        source=M.selected(source); if not source then return nil,"not-selected" end
        local ok,value,unit,state,category=pcall(function()
            return source:value(),source:unit(),source:state(),source:category()
        end)
        if not ok or not M.finite(value) then return nil,"invalid" end
        local telemetry=category==CATEGORY_TELEMETRY_SENSOR
        -- For nontelemetry sources, state describes a condition, not numeric validity.
        if telemetry and state==false then return nil,"inactive" end
        if telemetry then
            -- Source:age() is milliseconds in all three supported ETHOS versions.
            local ageOK,age=pcall(function() return source:age() end)
            if not ageOK or not M.finite(age) or age<0 or age>(maxAge or 3)*1000 then return nil,"stale" end
        end
        local factor
        if kind=="altitude" then
            if unitEquals(unit,UNIT_METER) then factor=1
            elseif unitEquals(unit,UNIT_FOOT) then factor=0.3048
            elseif unitEquals(unit,UNIT_KILOMETER) then factor=1000 end
        elseif kind=="vario" then
            if unitEquals(unit,UNIT_METER_PER_SECOND) then factor=1
            elseif unitEquals(unit,UNIT_METER_PER_MINUTE) then factor=1/60
            elseif unitEquals(unit,UNIT_FOOT_PER_SECOND) then factor=0.3048
            elseif unitEquals(unit,UNIT_FOOT_PER_MINUTE) then factor=0.3048/60 end
        elseif kind=="speed" then
            if unitEquals(unit,UNIT_KILOMETER_PER_HOUR) then factor=1
            elseif unitEquals(unit,UNIT_METER_PER_SECOND) then factor=3.6
            elseif unitEquals(unit,UNIT_MILE_PER_HOUR) then factor=1.609344
            elseif unitEquals(unit,UNIT_KNOT) then factor=1.852 end
        elseif kind=="voltage" then
            if unitEquals(unit,UNIT_VOLT) then factor=1 elseif unitEquals(unit,UNIT_MILLIVOLT) then factor=0.001 end
        elseif kind=="current" then
            if unitEquals(unit,UNIT_AMPERE) then factor=1 elseif unitEquals(unit,UNIT_MILLIAMPERE) then factor=0.001 end
        elseif kind=="capacity" then
            if unitEquals(unit,UNIT_MILLIAMPERE_HOUR) then factor=1 elseif unitEquals(unit,UNIT_AMPERE_HOUR) then factor=1000 end
        elseif kind=="percent" then if unitEquals(unit,UNIT_PERCENT) and value>=0 and value<=100 then factor=1 end
        elseif kind=="rf" then if unitEquals(unit,UNIT_DB) or unitEquals(unit,UNIT_PERCENT) then factor=1 end
        elseif kind=="timer" then if category==CATEGORY_TIMER or unitEquals(unit,UNIT_SECOND) then factor=1 end
        elseif kind=="control" then factor=1 end
        if not factor then return nil,"wrong-unit" end
        value=value*factor
        if not M.finite(value) then return nil,"invalid" end
        if (kind=="voltage" or kind=="capacity" or kind=="speed") and value<0 then return nil,"negative" end
        if kind=="altitude" and math.abs(value)>100000 then return nil,"range" end
        if kind=="vario" and math.abs(value)>200 then return nil,"range" end
        return value,nil,unit
    end
    return M
end)()

-- Inlined by the SoarDeck builder; engineering-unit inputs, no sensor/file I/O.
-- Qualification curves and boundaries mirror VoltDeck.lua / shared/core.lua.
local SoarBattery = (function()
    local M = {}
    local SOC = {0, 3, 6, 10, 15, 20, 25, 30, 40, 50, 60, 65, 70, 80, 90, 100}
    local OCV420 = {3300, 3541, 3618, 3658, 3695, 3721, 3747, 3761, 3778, 3802, 3863, 3899, 3929, 3991, 4076, 4176}
    local OCV435 = {3300, 3571, 3651, 3675, 3710, 3743, 3761, 3770, 3790, 3825, 3914, 3953, 3990, 4088, 4197, 4313}
    local TYPES = {
        {full = 4.20, empty = 3.30, curve = OCV420},
        {full = 4.35, empty = 3.40, curve = OCV435},
        {full = 4.20, empty = 3.00, curve = OCV420},
        {full = 3.65, empty = 2.80},
    }
    local CONFIG_KEYS = {"chemistry", "cellCount", "capacityMah", "batteryMethod", "endDelay",
        "modelKey", "sessionKey", "sourceKey", "voltageSource", "currentSource",
        "consumptionSource", "percentSource", "voltageConfigured"}

    local function finite(v) return type(v) == "number" and v == v and v > -math.huge and v < math.huge end
    local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
    local function round(v) return math.floor(v + 0.5) end
    local function positive(v) return finite(v) and v > 0 and v or nil end
    local function nonnegative(v) return finite(v) and v >= 0 and v or nil end
    local function validInteger(v, lo, hi) return finite(v) and v == math.floor(v) and v >= lo and v <= hi end
    local function sameConfig(a, b)
        if not a then return false end
        for _, k in ipairs(CONFIG_KEYS) do if a[k] ~= b[k] then return false end end
        return true
    end
    local function copyConfig(cfg)
        local c = {}
        for _, k in ipairs(CONFIG_KEYS) do c[k] = cfg[k] end
        return c
    end
    local function clearWindow(s, reason)
        if s.idleSince ~= nil then
            s.checkRestartReason = reason or "recheck"
            s.checkRestarts = (s.checkRestarts or 0) + 1
        end
        s.idleSince, s.minimum, s.maximum, s.decision = nil, nil, nil, nil
        s.menuCheck = nil
        s.ready, s.window, s.blocker = false, nil, reason
    end
    local function newCheck(s, reason)
        clearWindow(s, reason)
        s.qualified, s.requiresAcceptance = nil, s.uncertain == true
        s.epoch = (s.epoch or 0) + 1
    end
    local function limit(cfg) return math.min(1.5, 3 * cfg.capacityMah / 20000) end
    local function exceeded(cfg, current) return current > limit(cfg) + 0.000001 end
    local function reference(chemistry, mv)
        local curve = chemistry.curve
        if not curve then return nil end
        if mv <= curve[1] then return 0 end
        for i = 2, #curve do
            if mv <= curve[i] then
                return round((SOC[i - 1] + (mv - curve[i - 1]) * (SOC[i] - SOC[i - 1])
                    / (curve[i] - curve[i - 1])) * 100)
            end
        end
        return 10000
    end
    local function decide(cfg, minimum, maximum, used)
        local chemistry = TYPES[cfg.chemistry]
        local low = round(minimum / cfg.cellCount)
        local high = round(maximum / cfg.cellCount)
        local counter = round(clamp((cfg.capacityMah - used) / cfg.capacityMah, 0, 1) * 10000)
        local refLow, refHigh = reference(chemistry, low), reference(chemistry, high)
        local ref = refLow
        if refLow and math.abs(counter - refHigh) > math.abs(counter - refLow) then ref = refHigh end
        local delta = ref and counter - ref or nil
        local band = "manual"
        if high > round(chemistry.full * 1000) + 150 then band = "cells"
        elseif delta and math.abs(delta) > 2000 then band = "blocked"
        elseif delta and math.abs(delta) <= 1000 then band = "auto" end
        return {counterBP = counter, referenceBP = ref, referenceLowBP = refLow,
            referenceHighBP = refHigh, deltaBP = delta, band = band}
    end
    local function difference(d) return d.deltaBP and math.ceil(math.abs(d.deltaBP) / 10) / 10 or nil end
    local function sameDecision(a, b)
        return a and b and a.band == b.band and difference(a) == difference(b)
            and round(a.counterBP / 10) == round(b.counterBP / 10)
            and (a.referenceLowBP and round(a.referenceLowBP / 10))
                == (b.referenceLowBP and round(b.referenceLowBP / 10))
            and (a.referenceHighBP and round(a.referenceHighBP / 10))
                == (b.referenceHighBP and round(b.referenceHighBP / 10))
            and (a.deltaBP == nil or a.deltaBP >= 0) == (b.deltaBP == nil or b.deltaBP >= 0)
    end
    local function inputs(readings)
        readings = readings or {}
        if readings.live ~= true then return {live = false} end
        return {live = true, voltage = positive(readings.voltage), current = nonnegative(readings.current),
            consumed = nonnegative(readings.consumed), cellMin = positive(readings.cellMin),
            percent = finite(readings.percent) and readings.percent >= 0 and readings.percent <= 100 and readings.percent or nil,
            armOff = readings.armOff == true}
    end
    local function publish(s, cfg, r, now, status, reason, trusted)
        local remaining = trusted ~= nil and positive(cfg.capacityMah)
            and math.max(0, cfg.capacityMah - trusted) or nil
        local percent
        if cfg.batteryMethod == 1 then
            percent = remaining and clamp(remaining * 100 / cfg.capacityMah, 0, 100) or nil
        elseif cfg.batteryMethod == 2 then percent = r.percent
        elseif cfg.batteryMethod == 3 and r.voltage and validInteger(cfg.chemistry, 1, 4)
            and validInteger(cfg.cellCount, 1, 16) then
            local chem = TYPES[cfg.chemistry]
            percent = clamp((r.voltage / cfg.cellCount - chem.empty) * 100 / (chem.full - chem.empty), 0, 100)
        end
        if not r.live or status == "config" or status == "preview" or status == "clock" then
            percent, remaining = nil, nil
        end
        local d = s.decision
        local canAccept = false
        if r.live and cfg.batteryMethod == 1 and s.ready and not s.qualified and d then
            canAccept = r.armOff == true and d.band ~= "cells" and d.band ~= "blocked"
        elseif r.live and cfg.batteryMethod ~= 1 and s.uncertain then
            canAccept = r.armOff and r.consumed ~= nil
                and (not (cfg.voltageSource ~= nil or s.seenVoltage) or r.voltage ~= nil)
            if canAccept and r.voltage and validInteger(cfg.chemistry, 1, 4)
                and validInteger(cfg.cellCount, 1, 16) then
                canAccept = round(r.voltage * 1000 / cfg.cellCount) <= round(TYPES[cfg.chemistry].full * 1000) + 150
            end
        end
        local out = {percent = percent ~= nil and round(percent) or nil, remaining = remaining,
            consumed = r.consumed, voltage = r.voltage, current = r.current, cellMin = r.cellMin,
            valid = percent ~= nil, method = cfg.batteryMethod, status = status, reason = reason,
            canAccept = canAccept, counterReset = s.uncertain == true, estimated = cfg.batteryMethod == 3,
            difference = d and difference(d) or nil,
            referenceLow = d and d.referenceLowBP and d.referenceLowBP / 100 or nil,
            referenceHigh = d and d.referenceHighBP and d.referenceHighBP / 100 or nil,
            checkRemaining = s.idleSince and math.max(0, math.ceil(10 - (now - s.idleSince))) or 10,
            checkRestartReason = s.checkRestartReason, checkRestarts = s.checkRestarts or 0,
            currentLimit = positive(cfg.capacityMah) and limit(cfg) or nil}
        if canAccept then
            out.ticket = {epoch = s.epoch, window = s.window, config = s.config,
                decision = d, uncertain = s.uncertain == true}
        end
        s.result = out
        return out
    end

    function M.new() return {epoch = 0} end
    function M.status(s) return s and s.result or nil end

    -- ETHOS can suspend widget wakeups in its menu. Only an already completed,
    -- actionable check may cross that explicit UI transition, for at most 60 s.
    -- This does not qualify a pack or authorize acceptance. Resume resamples all
    -- battery inputs, and the confirmation retains its ordinary freshness guard.
    function M.holdForMenu(s, cfg, now)
        if not s or not finite(now) or not sameConfig(s.config, cfg or {}) then return end
        if s.menuCheck and now >= s.menuCheck.opened and now <= s.menuCheck.expires then return end
        s.menuCheck = nil
        if cfg.batteryMethod ~= 1 or not s.ready or s.qualified or not s.result
            or not s.result.canAccept or not s.lastClock or now < s.lastClock or now - s.lastClock > 1 then return end
        s.menuCheck = {epoch = s.epoch, window = s.window, config = s.config, opened = now, expires = now + 60}
    end

    function M.resumeFromMenu(s, cfg, readings, now)
        local result = M.update(s, cfg, readings, now)
        s.menuCheck = nil
        return result
    end

    -- The user also needs time to read the confirmation dialog. Bind that
    -- bounded review to its exact ticket; unrelated/older dialogs cannot use it.
    function M.holdForConfirmation(s, cfg, now, ticket)
        if not ticket or ticket.epoch ~= s.epoch or ticket.window ~= s.window
            or ticket.config ~= s.config or ticket.uncertain ~= (s.uncertain == true) then return end
        M.holdForMenu(s, cfg, now)
        if s.menuCheck then s.menuCheck.confirmation = ticket end
    end

    function M.cancelConfirmation(s, ticket)
        if s.menuCheck and s.menuCheck.confirmation == ticket then s.menuCheck = nil end
    end

    function M.update(s, cfg, readings, now)
        cfg = cfg or {}
        local r = inputs(readings)
        if not finite(now) then return publish(s, cfg, {live = false}, 0, "clock", "clock", nil) end
        if cfg.preview then return publish(s, cfg, {live = false}, now, "preview", "preview", nil) end
        local delay = finite(cfg.endDelay) and clamp(cfg.endDelay, 3, 120) or 10
        local menu = s.menuCheck
        local held = menu and finite(now) and now >= menu.opened and now <= menu.expires
            and menu.epoch == s.epoch and menu.window == s.window and menu.config == s.config
            and sameConfig(s.config, cfg) and s.ready and not s.qualified
        if held and (not r.live or not r.armOff or not r.voltage or r.current == nil
            or exceeded(cfg, r.current) or r.consumed == nil
            or not sameDecision(s.decision, decide(cfg, math.min(s.minimum, round(r.voltage * 1000)),
                math.max(s.maximum, round(r.voltage * 1000)), r.consumed))) then
            clearWindow(s, "readings-changed")
            held = false
        end
        if not sameConfig(s.config, cfg) then
            s.config = copyConfig(cfg)
            s.high, s.uncertain, s.lossSince, s.newPack, s.seenVoltage, s.lastClock = nil, nil, nil, nil, nil, nil
            newCheck(s, "setup-changed")
        elseif not held and s.lastClock and (now < s.lastClock or now - s.lastClock >= delay) then
            newCheck(s, now < s.lastClock and "clock-backwards" or "sampling-gap")
        end
        if not held and s.lastClock and now - s.lastClock > 1 then clearWindow(s, "sampling-gap") end
        s.lastClock = now
        if r.voltage then s.seenVoltage = true end
        local voltageExpected = cfg.batteryMethod ~= 2 or cfg.voltageSource ~= nil
            or cfg.voltageConfigured == true or s.seenVoltage
        if voltageExpected and r.voltage == nil then
            if not s.lossSince or now < s.lossSince then s.lossSince = now end
            if now - s.lossSince >= delay then s.newPack, s.qualified = true, nil end
        elseif r.voltage then
            if s.lossSince and now - s.lossSince >= delay then s.newPack = true end
            if s.newPack then
                s.high, s.uncertain, s.newPack = nil, nil, nil
                newCheck(s, "pack-reconnected")
            end
            s.lossSince = nil
        end
        local capacityOK = finite(cfg.capacityMah) and cfg.capacityMah >= 100 and cfg.capacityMah <= 100000
        local trusted
        if r.consumed and capacityOK then
            local tolerance = math.max(1, cfg.capacityMah * 0.001)
            if s.high and r.consumed + tolerance < s.high then s.uncertain = true end
            s.high = math.max(s.high or r.consumed, r.consumed)
            if not s.uncertain then trusted = r.consumed end
        end
        if not validInteger(cfg.batteryMethod, 1, 3) then
            clearWindow(s, "method")
            return publish(s, cfg, r, now, "config", "method", nil)
        end
        if cfg.batteryMethod ~= 1 then
            clearWindow(s)
            if cfg.batteryMethod == 3 and (not validInteger(cfg.chemistry, 1, 4)
                or not validInteger(cfg.cellCount, 1, 16)) then
                return publish(s, cfg, r, now, "config", "configuration", nil)
            end
            local present = cfg.batteryMethod == 2 and r.percent ~= nil or cfg.batteryMethod == 3 and r.voltage ~= nil
            local status = not r.live and "telemetry-lost" or not present and "missing"
                or cfg.batteryMethod == 2 and "percent" or "estimate"
            return publish(s, cfg, r, now, status, s.uncertain and "counter-reset" or nil, trusted)
        end
        if not capacityOK or not validInteger(cfg.chemistry, 1, 4) or not validInteger(cfg.cellCount, 1, 16) then
            clearWindow(s, "configuration")
            return publish(s, cfg, r, now, "config", "configuration", nil)
        end
        if not r.voltage then
            clearWindow(s, "voltage")
            return publish(s, cfg, r, now, not r.live and "telemetry-lost" or "missing", "voltage", nil)
        end
        if s.uncertain and not s.requiresAcceptance then
            s.qualified, s.requiresAcceptance = nil, true
            clearWindow(s, "counter-reset")
        end
        if r.consumed == nil then
            clearWindow(s, "consumption")
            return publish(s, cfg, r, now, "missing", "consumption", nil)
        end
        if s.qualified then return publish(s, cfg, r, now, "accepted", nil, trusted) end
        if r.current == nil or exceeded(cfg, r.current) then
            local reason = r.current and "load" or "current"
            clearWindow(s, reason)
            return publish(s, cfg, r, now, "checking", reason, nil)
        end
        local mv = round(r.voltage * 1000)
        local span = math.max(s.maximum or mv, mv) - math.min(s.minimum or mv, mv)
        if not s.idleSince or span > 200 then
            clearWindow(s, span > 200 and "unstable" or nil)
            s.idleSince, s.minimum, s.maximum, s.window = now, mv, mv, {}
        else s.minimum, s.maximum = math.min(s.minimum, mv), math.max(s.maximum, mv) end
        if now - s.idleSince < 10 then return publish(s, cfg, r, now, "checking", s.blocker or "settling", nil) end
        s.ready, s.decision = true, decide(cfg, s.minimum, s.maximum, r.consumed)
        if s.decision.band == "auto" and not s.requiresAcceptance then
            s.qualified = true
            return publish(s, cfg, r, now, "accepted", nil, trusted)
        end
        local status = s.decision.band == "auto" and "manual" or s.decision.band
        local reason = s.requiresAcceptance and "counter-reset" or s.decision.referenceBP == nil and "profile" or "counter"
        return publish(s, cfg, r, now, status, reason, nil)
    end

    -- Capture update().ticket when opening a confirmation dialog. Passing it back
    -- prevents an old dialog from accepting another setup, window or pack episode.
    function M.accept(s, cfg, readings, now, ticket)
        cfg = cfg or {}
        local r = inputs(readings)
        local function reject(reason, reset)
            if reset then clearWindow(s, reason) end
            return false, reason, M.update(s, cfg, readings, now)
        end
        if cfg.preview then return reject("preview") end
        if not finite(now) or not sameConfig(s.config, cfg) then return reject("setup-changed") end
        if ticket and (ticket.epoch ~= s.epoch or ticket.window ~= s.window
            or ticket.config ~= s.config or ticket.uncertain ~= (s.uncertain == true)) then return reject("stale-confirmation") end
        if not r.live then clearWindow(s, "telemetry-lost"); return false, "telemetry-lost", M.update(s, cfg, readings, now) end
        if not r.armOff then return reject("arm-not-off") end
        if cfg.batteryMethod ~= 1 then
            if not s.uncertain then return reject("no-reset") end
            if r.consumed == nil or (cfg.voltageSource ~= nil or s.seenVoltage) and not r.voltage then return reject("missing") end
            if r.voltage and validInteger(cfg.chemistry, 1, 4) and validInteger(cfg.cellCount, 1, 16)
                and round(r.voltage * 1000 / cfg.cellCount) > round(TYPES[cfg.chemistry].full * 1000) + 150 then return reject("cells") end
            s.high, s.uncertain, s.lossSince, s.newPack = r.consumed, nil, nil, nil
            return true, nil, M.update(s, cfg, readings, now)
        end
        if not positive(cfg.capacityMah) or not validInteger(cfg.chemistry, 1, 4)
            or not validInteger(cfg.cellCount, 1, 16) then return reject("configuration") end
        if not r.voltage or r.consumed == nil or r.current == nil then return reject("missing", true) end
        if exceeded(cfg, r.current) then return reject("load", true) end
        local mv = round(r.voltage * 1000)
        local minimum, maximum = math.min(s.minimum or mv, mv), math.max(s.maximum or mv, mv)
        local d = decide(cfg, minimum, maximum, r.consumed)
        if d.band == "cells" or d.band == "blocked" then return reject(d.band) end
        if s.qualified then return reject("already-accepted") end
        if not s.ready or not s.lastClock or now < s.lastClock or now - s.lastClock > 1
            or maximum - minimum > 200 then return reject("check-expired", true) end
        if not sameDecision(s.decision, d) or ticket and not sameDecision(ticket.decision, d) then
            return reject("readings-changed", true)
        end
        s.high, s.uncertain, s.lossSince, s.newPack = r.consumed, nil, nil, nil
        s.qualified, s.requiresAcceptance = true, nil
        return true, nil, M.update(s, cfg, readings, now)
    end
    function M.confirm(s, cfg, readings, now, ticket)
        local review = s.menuCheck
        if review and review.confirmation == ticket then
            if not finite(now) or now < review.opened or now > review.expires then
                clearWindow(s, "check-expired")
                return false, "check-expired", M.update(s, cfg, readings, now)
            end
            -- Fresh inputs must still match the completed check. Update can
            -- invalidate its window/ticket on loss, load or changed readings.
            M.resumeFromMenu(s, cfg, readings, now)
        end
        return M.accept(s, cfg, readings, now, ticket)
    end
    return M
end)()
-- SPDX-License-Identifier: MIT
-- Native LCD presentation. Source sampling, history, audio and battery decisions
-- belong to the controller; paint never reads a telemetry source or opens a file.
local SoarRender = (function()
    local M = {}
    -- Framework destroy need not be followed by paint/prepare. Release every
    -- renderer-owned root immediately, even when an old form keeps widget alive.
    -- No native API, allocation, or source access is needed for this bounded hook.
    function M.destroy(widget)
        if type(widget)~="table"then return end
        widget._soarRenderPlans,widget._soarTextCache,widget._soarRenderContext=nil,nil,nil
        widget._soarGraphCache,widget._soarGraphInput,widget._soarGraphProjections=nil,nil,nil
        widget._soarDialGeometry,widget._soarDialKey,widget._soarPrepareContext=nil,nil,nil
        widget._soarRenderWidth,widget._soarRenderHeight=nil,nil
        widget._soarRenderFrame=nil
    end
    local pi, sin, cos, floor = math.pi, math.sin, math.cos, math.floor
    local huge, negativeHuge = math.huge, -math.huge
    local palettes = {}
    local recordPrimitive,recordText,recordCircle,recordImage,recordGraph,paintGraph,settleTextFits
    local NATIVE_NAMES={"getWindowSize","RGB","color","font","getTextSize","drawFilledRectangle","drawLine","drawCircle","drawFilledCircle","drawBitmap","drawText"}
    local function resolveNative()
        local functions={}
        for i=1,#NATIVE_NAMES do local name=NATIVE_NAMES[i];local fn=lcd and lcd[name];functions[name]=type(fn)=="function" and fn or false end
        return functions
    end
    local EMPTY_HISTORY = {}
    local function finite(v)
        return type(v) == "number" and v > negativeHuge and v < huge
    end
    local function clamp(v, low, high)
        if v < low then return low end
        if v > high then return high end
        return v
    end
    local function round(v) return floor(v + 0.5) end
    local function native(name, ...)
        local fn=lcd and lcd[name]
        if type(fn)=="function" then return pcall(fn,...) end
        return false
    end
    local function rgb(r, g, b)
        local ok, value = native("RGB", r, g, b)
        return ok and value or r * 65536 + g * 256 + b
    end
    local function palette(light)
        local key = light and 1 or 2
        if palettes[key] then return palettes[key] end
        local p = {
            bg = light and rgb(246, 244, 236) or rgb(0, 0, 0),
            fg = light and rgb(19, 30, 26) or rgb(244, 247, 251),
            muted = light and rgb(84, 99, 91) or rgb(145, 160, 175),
            line = light and rgb(190, 199, 185) or rgb(69, 86, 96),
            grid = light and rgb(220, 224, 212) or rgb(25, 38, 42),
            track = light and rgb(219, 225, 213) or rgb(25, 37, 40),
            climb = light and rgb(16, 99, 58) or rgb(78, 218, 191),
            green = light and rgb(21, 117, 66) or rgb(53, 220, 139),
            yellow = light and rgb(145, 105, 0) or rgb(255, 211, 63),
            orange = light and rgb(167, 88, 13) or rgb(255, 151, 48),
            red = light and rgb(186, 38, 52) or rgb(255, 73, 91),
            motor = light and rgb(239, 225, 185) or rgb(54, 44, 22),
        }
        palettes[key] = p
        return p
    end
    local function fonts(small)
        local result, seen = {}, {}
        local function add(value)
            if value ~= nil and not seen[value] then
                seen[value] = true
                result[#result + 1] = value
            end
        end
        if not small then
            add(FONT_XXL); add(FONT_XL); add(FONT_L_BOLD); add(FONT_L)
            add(FONT_M_BOLD or FONT_STD_BOLD); add(FONT_M or FONT_STD)
        end
        add(FONT_S); add(FONT_XS)
        if #result == 0 then add(FONT_STD or FONT_M or 0) end
        return result
    end
    local fontSet
    local function fontLists()
        local a, b, c, d = FONT_XXL, FONT_XL, FONT_L_BOLD, FONT_L
        local e, f, g, h = FONT_M_BOLD or FONT_STD_BOLD, FONT_M or FONT_STD, FONT_S, FONT_XS
        if not fontSet or fontSet.a ~= a or fontSet.b ~= b or fontSet.c ~= c or fontSet.d ~= d
            or fontSet.e ~= e or fontSet.f ~= f or fontSet.g ~= g or fontSet.h ~= h then
            fontSet = {a=a,b=b,c=c,d=d,e=e,f=f,g=g,h=h,large=fonts(false),small=fonts(true)}
        end
        return fontSet.large, fontSet.small
    end
    local function prefix(value, bytes)
        bytes = math.min(bytes, #value)
        local nextByte = value:byte(bytes + 1)
        while bytes > 0 and nextByte and nextByte >= 128 and nextByte < 192 do
            bytes = bytes - 1
            nextByte = value:byte(bytes + 1)
        end
        return value:sub(1, bytes)
    end
    local function clean(value)
        value = tostring(value or ""):gsub("[%c]", " ")
        return #value > 120 and prefix(value, 120) or value
    end
    local function number(value, decimals, signed)
        if not finite(value) then return "--" end
        if math.abs(value) < 0.5 * 10 ^ -(decimals or 0) then value = 0 end
        return string.format((signed and "%+." or "%.") .. tostring(decimals or 0) .. "f", value)
    end
    local function timer(value)
        if not finite(value) then return "--:--" end
        value = math.max(0, math.floor(value))
        local minutes = math.floor(value / 60)
        if minutes > 99 then return string.format("%dh%02d", math.floor(minutes / 60), minutes % 60) end
        return string.format("%02d:%02d", minutes, value % 60)
    end
    local Context = {}
    Context.__index = Context
    local function context(widget, width, height)
        local cfg = type(widget.cfg) == "table" and widget.cfg or {}
        local data = type(widget.data) == "table" and widget.data or {}
        local cache = widget._soarTextCache
        if type(cache) ~= "table" or type(cache.entries) ~= "table" then
            cache = {entries = {}, keys = {}, cursor = 0, heights = {}, starts = {{}, {}}}
            widget._soarTextCache = cache
        end
        if not cache.heights then cache.heights = {} end
        if not cache.starts or cache.startsHeight ~= height then
            cache.starts, cache.startsHeight = {{}, {}}, height
        end
        local c = widget._soarRenderContext
        if not c then c = setmetatable({}, Context); widget._soarRenderContext = c end
        c.widget, c.cfg, c.data, c.width, c.height = widget, cfg, data, width, height
        c.sx, c.sy, c.small, c.imperial = width / 800, height / 480, width < 600, cfg.unitMode == 2
        c.p, c.cache = palette(cfg.style == 4 or cfg.daylight == true), cache
        c.fontList, c.smallFonts = fontLists()
        c.lastColor, c.lastFont, c.prepareOnly, c.recordPlan = nil, nil, false, nil
        c.api=resolveNative()
        c.altFactor, c.varioFactor, c.speedFactor = c.imperial and 3.28084 or 1,
            c.imperial and 196.8504 or 1, c.imperial and 0.621371 or 1
        c.altUnit, c.varioUnit, c.speedUnit = c.imperial and "ft" or "m",
            c.imperial and "ft/min" or "m/s", c.imperial and "mph" or "km/h"
        return c
    end
    function Context:color(value)
        if self.recordPlan then self.lastColor=value;return end
        if self.lastColor ~= value then if self.api.color then self.api.color(value) end; self.lastColor = value end
    end
    function Context:font(value)
        if self.lastFont ~= value then if self.api.font then self.api.font(value) end; self.lastFont = value end
    end
    function Context:measure(value)
        local ok,w,h
        if self.api.getTextSize then ok,w,h=pcall(self.api.getTextSize,value) end
        if ok and type(w)=="number" and type(h)=="number" and w>=0 and w<huge and h>0 and h<huge then
            if self.lastFont ~= nil then self.cache.heights[self.lastFont] = h end
            return w, h
        end
        return #value * 7, 14
    end
    function Context:rect(x, y, w, h, color)
        local x1, y1 = floor(x * self.sx + 0.5), floor(y * self.sy + 0.5)
        local x2, y2 = floor((x + w) * self.sx + 0.5), floor((y + h) * self.sy + 0.5)
        if x1 < 0 then x1 = 0 elseif x1 > self.width then x1 = self.width end
        if x2 < 0 then x2 = 0 elseif x2 > self.width then x2 = self.width end
        if y1 < 0 then y1 = 0 elseif y1 > self.height then y1 = self.height end
        if y2 < 0 then y2 = 0 elseif y2 > self.height then y2 = self.height end
        if x2 > x1 and y2 > y1 then
            if self.recordPlan then recordPrimitive(self,1,color,x1,y1,x2-x1,y2-y1)
            else self:color(color);if self.api.drawFilledRectangle then self.api.drawFilledRectangle(x1,y1,x2-x1,y2-y1) end end
        end
    end
    function Context:line(x1, y1, x2, y2, color)
        self:color(color)
        local edgeX, edgeY = self.width - 1, self.height - 1
        x1, y1 = floor(x1 * self.sx + 0.5), floor(y1 * self.sy + 0.5)
        x2, y2 = floor(x2 * self.sx + 0.5), floor(y2 * self.sy + 0.5)
        if x1 < 0 then x1 = 0 elseif x1 > edgeX then x1 = edgeX end
        if x2 < 0 then x2 = 0 elseif x2 > edgeX then x2 = edgeX end
        if y1 < 0 then y1 = 0 elseif y1 > edgeY then y1 = edgeY end
        if y2 < 0 then y2 = 0 elseif y2 > edgeY then y2 = edgeY end
        if self.recordPlan then recordPrimitive(self,2,color,x1,y1,x2,y2)
        elseif self.api.drawLine then self.api.drawLine(x1,y1,x2,y2) end
    end
    function Context:circle(x, y, radius, color, filled)
        if self.recordPlan then recordCircle(self,x,y,radius,color,filled);return end
        self:color(color)
        local px, py, r = round(x * self.sx), round(y * self.sy), math.max(1, round(radius * math.min(self.sx, self.sy)))
        if px - r >= 0 and py - r >= 0 and px + r < self.width and py + r < self.height then
            local fn=self.api[filled and "drawFilledCircle" or "drawCircle"]
            local ok=fn and pcall(fn,px,py,r)
            if ok then return end
        end
        -- A polygon outline is also supported by the smallest LCD test/API surface.
        local rx, ry = r / self.sx, r / self.sy
        local oldX, oldY = x + rx, y
        for i = 1, 36 do
            local angle = i * pi / 18
            local nextX, nextY = x + cos(angle) * rx, y + sin(angle) * ry
            self:line(oldX, oldY, nextX, nextY, color)
            oldX, oldY = nextX, nextY
        end
    end
    function Context:text(x, y, value, w, h, color, align, small, spec)
        if self.recordPlan then return recordText(self,x,y,value,w,h,color,align,small,spec) end
        if spec and spec[10]~=nil and spec[14]==self.fontList then
            self:font(spec[10]);self:color(color or self.p.fg)
            if self.api.drawText then self.api.drawText(spec[11],spec[12],spec[13],LEFT or 0) end
            return spec[15],spec[16]
        end
        local api,cache=self.api,self.cache
        local pw,ph
        if spec then value,pw,ph=spec[1],spec[2],spec[3]
        else value=clean(value);pw,ph=math.max(0,math.floor(w*self.sx)),math.max(0,math.floor(h*self.sy)) end
        if pw < 3 or ph < 1 or value == "" then return 0, 0 end
        local key = spec and spec[4] or pw .. "|" .. ph .. "|" .. (small and 1 or 0) .. "|" .. value
        local fitted = cache.entries[key]
        if fitted and fitted[1]~=nil then
            -- Prepared text can lend its flat measured payload to the SAME
            -- bounded cache. General fallback preserves the original format.
            fitted={font=fitted[10],value=fitted[13],w=fitted[17],h=fitted[18]}
            cache.entries[key]=fitted
        end
        if not fitted then
            local candidates = small and self.smallFonts or self.fontList
            local chosen, tw, th
            local starts = cache.starts[small and 2 or 1]
            local index, last = starts[ph] or 1, #candidates
            -- The leading fonts rejected on height for this box remain
            -- rejected for every label of that same height. Cache only the
            -- leading index; each string still has its width checked.
            while index < last and cache.heights[candidates[index]]
                and cache.heights[candidates[index]] > ph do index = index + 1 end
            starts[ph] = index
            while index <= last do
                local font = candidates[index]
                -- A system font has a fixed line height. Once measured in
                -- this widget, do not reselect/measure an oversized font for
                -- every small label in a cold frame. The final fallback is
                -- still measured, and width/actual height are always checked.
                local knownHeight = cache.heights[font]
                if not knownHeight or knownHeight <= ph or index == last then
                    if self.lastFont~=font then if api.font then api.font(font)end;self.lastFont=font end
                    local ok
                    if api.getTextSize then ok,tw,th=pcall(api.getTextSize,value)end
                    if ok and type(tw)=="number" and type(th)=="number" and tw>=0 and tw<huge and th>0 and th<huge then
                        cache.heights[font]=th
                    else tw,th=#value*7,14 end
                    chosen = font
                    if tw <= pw and th <= ph then break end
                end
                index = index + 1
            end
            if tw > pw then
                local suffix = "..."
                local suffixWidth = self:measure(suffix)
                if suffixWidth > pw then value = ""
                else
                    local low, high, best = 0, #value, ""
                    while low <= high do
                        local middle = math.floor((low + high) / 2)
                        local test = prefix(value, middle) .. suffix
                        if self:measure(test) <= pw then best = test; low = middle + 1
                        else high = middle - 1 end
                    end
                    value = best
                end
                tw, th = self:measure(value)
            end
            fitted = {font = chosen, value = value, w = tw, h = th}
            cache.cursor = cache.cursor % 128 + 1
            local old = cache.keys[cache.cursor]
            if old then cache.entries[old] = nil end
            cache.keys[cache.cursor] = key
            cache.entries[key] = fitted
        end
        if fitted.value == "" or fitted.h > self.height then return 0, 0 end
        local px = spec and spec[5] or x * self.sx
        if align == "right" then px = px + pw - fitted.w
        elseif align == "center" then px = px + (pw - fitted.w) / 2 end
        px = clamp(round(px), 0, math.max(0, self.width - fitted.w))
        local py = clamp(round(spec and spec[6] or y * self.sy), 0, math.max(0, self.height - fitted.h))
        if self.lastFont~=fitted.font then if api.font then api.font(fitted.font)end;self.lastFont=fitted.font end
        local tone=color or self.p.fg
        if self.lastColor~=tone then if api.color then api.color(tone)end;self.lastColor=tone end
        if self.api.drawText then self.api.drawText(px,py,fitted.value,LEFT or 0) end
        if spec then
            spec[10],spec[11],spec[12],spec[13],spec[15],spec[16]=fitted.font,px,py,fitted.value,fitted.w/self.sx,fitted.h/self.sy
            spec[14]=self.fontList
        end
        return fitted.w / self.sx, fitted.h / self.sy
    end
    local function converted(value, factor) return finite(value) and value * factor or nil end
    local function signColor(c, value)
        if not finite(value) then return c.p.muted end
        return value < 0 and c.p.yellow or c.p.climb
    end
    local function stat(c, x, y, w, title, value, unit, color, signed)
        c:text(x, y, title, w, 17, c.p.muted, nil, true)
        local decimals = unit == c.varioUnit and not c.imperial and 1 or 0
        c:text(x, y + 23, number(value, decimals, signed) .. (unit and " " .. unit or ""), w, 37, color or c.p.fg)
    end
    local function altitudeLabel(c)
        if c.data.altitudeLabel == "ALT SENSOR" then return "ALT SENSOR" end
        if c.data.altitudeLabel == "ALT REL" then return "ALT REL" end
        return c.cfg.altitudeMode == 2 and "ALT SENSOR" or "ALT REL"
    end
    local function altitude(c, x, y, w, h, centered)
        c:text(x, y, altitudeLabel(c), w, 19, c.p.muted, centered and "center" or nil, true)
        c:text(x, y + 27, number(converted(c.data.altitude, c.altFactor), 0) .. " " .. c.altUnit,
            w, h - 28, c.p.fg, centered and "center" or nil)
    end
    local function varioLabel(c) return c.data.derived and "VARIO (DERIVED)" or "VARIO (BARO)" end
    local function digitalVario(c, x, y, w, h, centered)
        c:text(x, y, varioLabel(c), w, 19, c.p.muted, centered and "center" or nil, true)
        local value = converted(c.data.vario, c.varioFactor)
        local unitHeight = c.imperial and 22 or 25
        c:text(x, y + 27, number(value, c.imperial and 0 or 1, true), w, h - 28 - unitHeight,
            signColor(c, c.data.vario), centered and "center" or nil)
        c:text(x, y + h - unitHeight, c.varioUnit, w, unitHeight, c.p.muted, centered and "center" or nil, true)
    end
    local function varioScale(c)
        local value = c.cfg.varioScale
        return finite(value) and clamp(value, 0.5, 20) or 5
    end
    local function verticalVario(c, x, y, w, h)
        local scale, value = varioScale(c), c.data.vario
        local bx, bw, steps = x + w * 0.33, w * 0.31, 20
        local gap, row = 2, (h - 2) / steps
        for index = 0, steps - 1 do
            local position = 1 - (index + 0.5) * 2 / steps
            local active = finite(value) and ((value >= 0 and position > 0 and position <= value / scale)
                or (value < 0 and position < 0 and position >= value / scale))
            c:rect(bx, y + index * row, bw, math.max(1, row - gap), active and signColor(c, value) or c.p.track)
        end
        c:line(bx - 5, y + h / 2, bx + bw + 5, y + h / 2, c.p.line)
        for index = -2, 2 do
            local displayed = index * scale / 2 * c.varioFactor
            c:text(x + w * 0.68, y + h / 2 - index * h / 4 - 8, w > 55 and number(displayed, c.imperial and 0 or 1, index ~= 0) or number(displayed, 0, index ~= 0),
                w * 0.7, 17, c.p.muted, nil, true)
        end
    end
    local function header(c, motor)
        local d = c.data
        c:text(24, 9, "MODEL", 282, 17, c.p.muted, nil, true)
        c:text(24, 31, d.modelName or c.cfg.modelName or "SoarDeck", 292, 38, c.p.fg)
        local subtitle = motor and "MOTOR GLIDER" or "SAILPLANE"
        if d.preview then subtitle = subtitle .. " / PREVIEW"
        elseif d.live == false then subtitle = subtitle .. " / NO DATA" end
        c:text(24, 78, subtitle, 300, 17, d.live == false and not d.preview and c.p.red or c.p.muted, nil, true)
        c:text(350, 12, "RF", 112, 16, c.p.muted, nil, true)
        local rfUnit = d.rfUnit == "dB" and "dB" or "%"
        c:text(350, 35, number(d.rf, 0) .. rfUnit, 116, 27, finite(d.rf) and c.p.climb or c.p.muted)
        if finite(d.rf) and rfUnit == "%" then
            for i = 1, 4 do
                c:rect(351 + (i - 1) * 11, 91 - i * 5, 7, i * 5,
                    d.rf >= i * 20 and c.p.climb or c.p.track)
            end
        end
        c:text(487, 15, "RX " .. number(d.rxVoltage, 1) .. " V", 133, 27, c.p.fg)
        c:text(487, 61, "TX " .. number(d.txVoltage, 1) .. " V", 133, 25, c.p.muted)
        c:text(640, 18, timer(d.flightTime), 136, 44, c.p.fg, "right")
        c:text(640, 77, "FLIGHT TIME", 136, 17, c.p.muted, "right", true)
        c:line(24, 103, 776, 103, c.p.line)
    end
    local function footer(c)
        c:text(24, 463, "SoarDeck", 112, 14, c.p.muted, nil, true)
        local message = c.data.preview and "SYNTHETIC PREVIEW" or c.data.live == false and "TELEMETRY UNAVAILABLE"
            or c.data.message or c.data.audioMode and "VARIO AUDIO " .. clean(c.data.audioMode) or ""
        local tone = c.data.live == false and not c.data.preview and c.p.red
            or c.data.message and not c.data.preview and c.p.yellow or c.p.muted
        c:text(270, 463, message, 506, 14, tone, "right", true)
    end
    local function modelImage(c, x, y, w, h)
        if c.recordPlan then recordImage(c,x,y,w,h);return end
        local widget = c.widget
        if widget.bitmap then
            local iw = finite(widget.bitmapWidth) and math.max(1, widget.bitmapWidth) or 290
            local ih = finite(widget.bitmapHeight) and math.max(1, widget.bitmapHeight) or 191
            local fit = math.min(w * c.sx / iw, h * c.sy / ih)
            local pw, ph = math.max(1, round(iw * fit)), math.max(1, round(ih * fit))
            local px = clamp(round(x * c.sx + (w * c.sx - pw) / 2), 0, c.width - pw)
            local py = clamp(round(y * c.sy + (h * c.sy - ph) / 2), 0, c.height - ph)
            local ok=c.api.drawBitmap and pcall(c.api.drawBitmap,px,py,widget.bitmap,pw,ph)
            if ok then return end
        end
        c:text(x, y + h * 0.36, "MODEL IMAGE", w, 23, c.p.muted, "center", true)
        c:text(x + 10, y + h * 0.57, widget.imageError or "Choose an image in setup", w - 20, 20, c.p.muted, "center", true)
    end
    local function batteryColor(c, percent)
        if not finite(percent) then return c.p.muted end
        if percent <= 30 then return c.p.red end
        if percent <= 35 then return c.p.orange end
        if percent <= 40 then return c.p.yellow end
        return c.p.green
    end
    local function batteryMethod(b)
        local method = clean(b.method):lower()
        if b.method == 3 or method:find("volt", 1, true) or method == "estimate" then return "VOLTAGE ESTIMATE", true end
        if b.method == 2 or method == "%" or method:find("percent", 1, true) then return "% SENSOR", false end
        return "mAh SENSOR", false
    end
    local function batteryStatus(b)
        local status = clean(b.status)
        local key = status:lower():gsub("[%s_-]", "")
        if key:find("cells", 1, true) then return "CHECK CELLS/TYPE", true end
        if key == "blocked" then return "CHECK PACK/COUNTER", true end
        if b.counterReset == true or b.reason == "counter-reset" then return "COUNTER RESET", true end
        if key == "" or key == "ok" or key == "ready" or key == "valid" or key == "accepted"
            or key == "percent" or key == "estimate" then return nil end
        if key == "checking" or key == "pending" or key == "checkingpack" then return "CHECKING PACK" end
        if key:find("reset", 1, true) then return "COUNTER RESET" end
        if key == "mismatch" or key == "check" or key == "manual" then return "CHECK PACK/COUNTER" end
        if key == "unknown" or key == "unavailable" or key == "offline" or key == "telemetrylost" or key == "missing" then return "NO BATTERY DATA" end
        if key == "config" then return "SETUP BATTERY", true end
        if key == "clock" then return "RECHECK BATTERY" end
        return status:upper()
    end
    local function motorState(c)
        if c.data.motorActive == true then return "MOTOR ON", c.p.yellow end
        if c.data.motorActive == false then return "MOTOR OFF", c.p.muted end
        return "MOTOR --", c.p.muted
    end
    local function batterySegments(c, x, y, w, h, percent, color)
        c:rect(x, y, w, 1, c.p.line); c:rect(x, y + h - 1, w, 1, c.p.line)
        c:rect(x, y, 1, h, c.p.line); c:rect(x + w - 1, y, 1, h, c.p.line)
        c:rect(x + w, y + h * 0.3, 4, h * 0.4, c.p.line)
        local inner = w - 8
        for i = 1, 10 do
            local bx, bw = x + 4 + (i - 1) * inner / 10, inner / 10 - 2
            c:rect(bx, y + 4, bw, h - 8, c.p.track)
            local amount = finite(percent) and clamp(percent / 10 - (i - 1), 0, 1) or 0
            if amount > 0 then c:rect(bx, y + 4, bw * amount, h - 8, color) end
        end
    end
    local function battery(c, x, y, w, h, strip)
        local b = type(c.data.battery) == "table" and c.data.battery or {}
        local percent = finite(b.percent) and b.percent >= 0 and b.percent <= 100 and b.percent or nil
        local color, method, estimated = batteryColor(c, percent), batteryMethod(b)
        local status, critical = batteryStatus(b)
        local statusColor = critical and c.p.red or c.p.orange
        local motor, motorColor = motorState(c)
        if strip then
            c:text(x, y, "MOTOR BATTERY", w * 0.28, 17, c.p.muted, nil, true)
            c:text(x + w * 0.28, y, motor, w * 0.21, 17, motorColor, nil, true)
            c:text(x + w * 0.5, y, status or method, w * 0.5, 17, status and statusColor or c.p.muted, "right", true)
            batterySegments(c, x, y + 28, w * 0.25, 24, percent, color)
            c:text(x + w * 0.28, y + 23, number(percent, 0) .. "%" .. (estimated and " EST" or ""), w * 0.2, 34, color)
            c:text(x + w * 0.5, y + 23, number(b.voltage, 1) .. " V", w * 0.2, 32, c.p.fg)
            local extra = estimated and finite(b.cellMin) and "MIN " .. number(b.cellMin, 2) .. " V"
                or not estimated and number(b.remaining, 0) .. " mAh" or ""
            c:text(x + w * 0.73, y + 26, extra, w * 0.27, 28, c.p.fg, "right")
            return
        end
        c:text(x, y, "MOTOR BATTERY", w, 17, c.p.muted, nil, true)
        batterySegments(c, x, y + 28, w * 0.64, 26, percent, color)
        c:text(x + w * 0.69, y + 21, number(percent, 0) .. "%", w * 0.31, 37, color, "right")
        local rowY = h < 115 and 54 or 63
        c:text(x, y + rowY, number(b.voltage, 1) .. " V", w * 0.49, 26, c.p.fg)
        local extra = estimated and finite(b.cellMin) and number(b.cellMin, 2) .. " V MIN"
            or not estimated and number(b.remaining, 0) .. " mAh" or "ESTIMATE"
        c:text(x + w * 0.5, y + rowY + 1, extra, w * 0.5, 25, c.p.fg, "right")
        if w < 220 then
            if status == "CHECK PACK/COUNTER" then status = "CHECK PACK"
            elseif status == "CHECK CELLS/TYPE" then status = "CHECK CELLS"
            elseif status == "NO BATTERY DATA" then status = "NO DATA" end
        end
        c:text(x, y + h - 17, status or (estimated and "VOLT EST / " .. motor:sub(7) or motor), w, 17,
            status and statusColor or motorColor, nil, true)
    end
    local function staticDial(c,cx,cy,radius,vario,maximum,factor)
        local geometry={lines={},labels={}}
        local sx,sy=c.sx,c.sy
        local scaleX,scaleY=math.min(sx,sy)/sx,math.min(sx,sy)/sy
        local edgeX,edgeY=c.width-1,c.height-1
        local function pixel(value,scale,edge)
            local n=floor(value*scale+0.5)
            return n<0 and 0 or n>edge and edge or n
        end
        local ticks=vario and 20 or 16
        for i=0,ticks do
            local v=vario and -maximum+i*maximum*2/ticks or i*maximum/ticks
            local angle=vario and pi-v/maximum*2.4 or pi*1.25-v/maximum*pi*1.5
            local major=i%(vario and 2 or 4)==0
            local r1,r2=radius-(major and 15 or 9),radius-4
            local tone=vario and v>0 and "climb" or vario and v<0 and "yellow" or "muted"
            local l=geometry.lines
            l[#l+1]=pixel(cx+cos(angle)*r1*scaleX,sx,edgeX)
            l[#l+1]=pixel(cy-sin(angle)*r1*scaleY,sy,edgeY)
            l[#l+1]=pixel(cx+cos(angle)*r2*scaleX,sx,edgeX)
            l[#l+1]=pixel(cy-sin(angle)*r2*scaleY,sy,edgeY)
            l[#l+1]=tone
            if major and(not(c.small and c.imperial and vario)or i==0 or i==ticks/2 or i==ticks)then
                local displayed=v*factor
                local decimals=vario and not c.imperial and math.abs(displayed-round(displayed))>0.001 and 1 or 0
                local x=cx+cos(angle)*(radius-32)*scaleX-28
                local y=cy-sin(angle)*(radius-32)*scaleY-8
                local text=number(displayed,decimals,vario and v~=0)
                local pw,ph=math.max(0,floor(56*sx)),math.max(0,floor(17*sy))
                geometry.labels[i]={text,pw,ph,pw.."|"..ph.."|1|"..text,x*sx,y*sy}
            end
        end
        return geometry
    end
    local function dialStaticKey(c,cx,cy,radius,kind,maximum,factor)
        return c.width.."/"..c.height.."/"..cx.."/"..cy.."/"..radius.."/"..kind.."/"..maximum.."/"..factor
    end
    local function dial(c, cx, cy, radius, kind)
        local vario = kind == "vario"
        local value = vario and c.data.vario or kind == "airspeed" and c.data.airspeed or c.data.altitude
        local factor = vario and c.varioFactor or kind == "airspeed" and c.speedFactor or c.altFactor
        local unit = vario and c.varioUnit or kind == "airspeed" and c.speedUnit or c.altUnit
        local label = vario and "VARIO / " .. unit or kind == "airspeed" and "AIRSPEED (IAS)" or altitudeLabel(c)
        local maximum = vario and varioScale(c) or kind == "airspeed" and 160 or 1000
        local scaleX, scaleY = math.min(c.sx, c.sy) / c.sx, math.min(c.sx, c.sy) / c.sy
        local rx, ry = radius * scaleX, radius * scaleY
        c:circle(cx, cy, radius, c.p.line)
        local ticks = vario and 20 or 16
        local geometry=c.widget._soarDialGeometry
        geometry=geometry and geometry[dialStaticKey(c,cx,cy,radius,kind,maximum,factor)]
        for i = 0, ticks do
            if geometry then
                local at=i*5+1;local l=geometry.lines
                if c.recordPlan then recordPrimitive(c,2,l[at+4],l[at],l[at+1],l[at+2],l[at+3])
                else c:color(c.p[l[at+4]])
                    if c.api.drawLine then c.api.drawLine(l[at],l[at+1],l[at+2],l[at+3]) end
                end
                local spec=geometry.labels[i]
                if spec then c:text(0,0,spec[1],0,0,c.p.muted,"center",true,spec) end
            else
            local v = vario and -maximum + i * maximum * 2 / ticks or i * maximum / ticks
            local angle = vario and pi - v / maximum * 2.4 or pi * 1.25 - v / maximum * pi * 1.5
            local major = i % (vario and 2 or 4) == 0
            local r1, r2 = radius - (major and 15 or 9), radius - 4
            local tone = vario and v > 0 and c.p.climb or vario and v < 0 and c.p.yellow or c.p.muted
            c:line(cx + cos(angle) * r1 * scaleX, cy - sin(angle) * r1 * scaleY,
                cx + cos(angle) * r2 * scaleX, cy - sin(angle) * r2 * scaleY, tone)
            local labelTick = major and (not (c.small and c.imperial and vario) or i == 0 or i == ticks / 2 or i == ticks)
            if labelTick then
                local displayed = v * factor
                local decimals = vario and not c.imperial and math.abs(displayed - round(displayed)) > 0.001 and 1 or 0
                c:text(cx + cos(angle) * (radius - 32) * scaleX - 28, cy - sin(angle) * (radius - 32) * scaleY - 8,
                    number(displayed, decimals, vario and v ~= 0), 56, 17, c.p.muted, "center", true)
            end
            end
        end
        if finite(value) then
            local clamped = vario and clamp(value, -maximum, maximum) or clamp(value, 0, maximum)
            local angle = vario and pi - clamped / maximum * 2.4 or pi * 1.25 - clamped / maximum * pi * 1.5
            c:line(cx, cy, cx + cos(angle) * rx * 0.68, cy - sin(angle) * ry * 0.68,
                vario and signColor(c, value) or c.p.fg)
            c:circle(cx, cy, 5, c.p.line, true)
        end
        local labelWidth = vario and rx * 1.64 or rx * 1.3
        c:text(cx - labelWidth / 2, cy + ry * 0.12, label, labelWidth, 18, c.p.muted, "center", true)
        c:text(cx - rx * 0.82, cy + ry * 0.31, number(converted(value, factor), vario and not c.imperial and 1 or 0, vario),
            rx * 1.64, ry * (c.small and c.imperial and 0.29 or 0.36), vario and signColor(c, value) or c.p.fg, "center")
        if not vario then c:text(cx - rx * 0.7, cy + ry * 0.68, unit, rx * 1.4, 18, c.p.muted, "center", true) end
        if vario and c.data.derived then
            c:text(cx - rx * 0.6, cy - ry * 0.37, "DERIVED", rx * 1.2, 17, c.p.muted, "center", true)
        end
    end
    local function niceStep(range)
        if range <= 0 then return 1 end
        local power = 10 ^ math.floor(math.log(range) / math.log(10))
        local fraction = range / power
        return (fraction <= 1 and 1 or fraction <= 2 and 2 or fraction <= 5 and 5 or 10) * power
    end
    local function historySpan(cfg)
        return finite(cfg.historySeconds) and clamp(cfg.historySeconds, 15, 600) or 120
    end
    -- Logical bins do not depend on LCD dimensions. The controller can prepare
    -- the maximum 100-bin view before the widget is first revealed. A narrower
    -- actual viewport is always rebinned using its measured width in paint.
    local function historyMatches(cached,widget,kind,factor,span,count)
        if not cached then return false end
        local history=type(widget.history)=="table" and widget.history or EMPTY_HISTORY
        local tail=type(history[#history])=="table" and history[#history] or EMPTY_HISTORY
        return cached.history==history and cached.length==#history and cached.time==tail.x
            and cached.altitude==tail.altitude and cached.vario==tail.vario and cached.motor==tail.motor
            and cached.revision==widget.historyRevision and cached.kind==kind and cached.factor==factor
            and cached.span==span and cached.count==count
    end
    local function historyInput(widget, kind, factor, span, count)
        local history = type(widget.history) == "table" and widget.history or EMPTY_HISTORY
        local length = #history
        local tail = type(history[length]) == "table" and history[length] or EMPTY_HISTORY
        local cached = widget._soarGraphInput
        local sameSamples = cached and cached.history == history and cached.length == length
            and cached.time == tail.x and cached.altitude == tail.altitude and cached.vario == tail.vario
            and cached.motor == tail.motor and cached.revision == widget.historyRevision
            and cached.kind == kind and cached.factor == factor and cached.span == span
        if sameSamples and cached.count == count then return cached end
        local first, finish, minValue, maxValue, minInterval, start, samples, maxGap
        if sameSamples then
            start, samples, minValue, maxValue, maxGap = cached.start, cached.samples, cached.minValue, cached.maxValue, cached.maxGap
        else
        first, samples = math.max(1, length - 599), {}
        for i = length, first, -1 do
            local point = history[i]
            if type(point) == "table" and finite(point.x) then finish = point.x; break end
        end
        finish = finish or 0
        start = finish - span
        local previousTime, sampleCount = nil, 0
        for i = first, length do
            local point = history[i]
            if type(point) == "table" and finite(point.x) and point.x >= start and point.x <= finish then
                if previousTime and point.x > previousTime then
                    local interval = point.x - previousTime
                    if not minInterval or interval < minInterval then minInterval = interval end
                end
                previousTime = point.x
                local value = point[kind]
                if finite(value) then
                    value = value * factor
                    if not minValue or value < minValue then minValue = value end
                    if not maxValue or value > maxValue then maxValue = value end
                else
                    value = false
                end
                samples[sampleCount + 1], samples[sampleCount + 2], samples[sampleCount + 3] = point.x, value, point.motor == true
                sampleCount = sampleCount + 3
            end
        end
        maxGap = math.max(3, (minInterval or 1) * 2.5)
        end
        local bins = {}
        for i = 1, #samples, 3 do
            local time, value = samples[i], samples[i + 1]
            local index = floor((time - start) / span * (count - 1)) + 1
            if index < 1 then index = 1 elseif index > count then index = count end
            if value then
                local previousBin = bins[index]
                if previousBin then
                    previousBin.value, previousBin.time, previousBin.motor = value, time, samples[i + 2]
                else
                    bins[index] = {value=value,time=time,motor=samples[i + 2],gapBefore=previousBin == false or nil}
                end
            else
                -- False marks an explicit reception gap without allocating an
                -- object for every missing sample during a hidden interval.
                bins[index] = false
            end
        end
        cached = {history=history,length=length,time=tail.x,altitude=tail.altitude,vario=tail.vario,motor=tail.motor,
            revision=widget.historyRevision,kind=kind,factor=factor,span=span,count=count,bins=bins,
            start=start,minValue=minValue,maxValue=maxValue,maxGap=maxGap,samples=samples}
        widget._soarGraphInput = cached
        return cached
    end
    local function graph(c, x, y, w, h, requestedKind)
        if c.recordPlan then recordGraph(c,x,y,w,h,requestedKind);return end
        local kind = requestedKind or (c.cfg.historyKind == 2 and "vario" or "altitude")
        local factor = kind == "vario" and c.varioFactor or c.altFactor
        local unit = kind == "vario" and c.varioUnit or c.altUnit
        local title = kind == "vario" and "VARIO HISTORY" or altitudeLabel(c) == "ALT SENSOR"
            and "ALTITUDE HISTORY (SENSOR)" or "ALTITUDE HISTORY (REL)"
        local span = historySpan(c.cfg)
        local px, py, pw, ph = x + 43, y + 27, math.max(20, w - 48), math.max(18, h - 49)
        local count = math.max(8, math.min(100, floor(pw * c.sx / 3)))
        local projections=c.widget._soarGraphProjections
        local projected=projections and projections[c.width.."/"..c.height]
        local input
        if projected and historyMatches(projected.input,c.widget,kind,factor,span,count) then input=projected.input
        else input=historyInput(c.widget,kind,factor,span,count);projected=nil end
        local prepared = projected or c.widget._soarGraphCache
        if not prepared or prepared.input ~= input or prepared.width ~= c.width or prepared.height ~= c.height
            or prepared.x ~= x or prepared.y ~= y or prepared.w ~= w or prepared.h ~= h
            or prepared.altitudeLabel ~= altitudeLabel(c) or prepared.varioScale ~= varioScale(c) then
        local bins, start, minValue, maxValue, maxGap = input.bins, input.start, input.minValue, input.maxValue, input.maxGap
        if kind == "vario" then
            local scale = varioScale(c) * factor
            maxValue = math.max(scale, math.abs(minValue or 0), math.abs(maxValue or 0))
            minValue = -maxValue
        else
            minValue, maxValue = minValue or 0, maxValue or 0
            local minimumRange = 20 * factor
            if maxValue - minValue < minimumRange then
                local middle = (minValue + maxValue) / 2
                minValue, maxValue = middle - minimumRange / 2, middle + minimumRange / 2
            end
            local step = niceStep((maxValue - minValue) / 3)
            minValue, maxValue = math.floor(minValue / step) * step, math.ceil(maxValue / step) * step
        end
        local range = math.max(0.0001, maxValue - minValue)
        local function pointY(value) return py + ph - clamp((value - minValue) / range, 0, 1) * ph end
        prepared = {input=input,width=c.width,height=c.height,x=x,y=y,w=w,h=h,
            altitudeLabel=altitudeLabel(c),varioScale=varioScale(c),bands = {}, grid = {}, axes = {}, trace = {},
            px = px, py = py, pw = pw, ph = ph, title = title .. " / " .. number(span, 0) .. " s"}
        local sx, sy, edgeX, edgeY = c.sx, c.sy, c.width - 1, c.height - 1
        local function pixelX(value)
            local pixel = floor(value * sx + 0.5)
            if pixel < 0 then return 0 end
            if pixel > edgeX then return edgeX end
            return pixel
        end
        local function pixelY(value)
            local pixel = floor(value * sy + 0.5)
            if pixel < 0 then return 0 end
            if pixel > edgeY then return edgeY end
            return pixel
        end
        local function line(target, x1, y1, x2, y2, color)
            target[#target + 1] = {pixelX(x1), pixelY(y1), pixelX(x2), pixelY(y2), color}
        end
        local function rectangle(target, rx, ry, rw, rh)
            local left, top = clamp(round(rx * c.sx), 0, c.width), clamp(round(ry * c.sy), 0, c.height)
            local right, bottom = clamp(round((rx + rw) * c.sx), 0, c.width), clamp(round((ry + rh) * c.sy), 0, c.height)
            if right > left and bottom > top then
                -- Only graph motor bands use this helper. They are opaque,
                -- same-colored rectangles painted in one block before the grid.
                -- Join only touching/overlapping integer intervals of identical
                -- vertical extent; preserve every real pixel gap and ordering.
                local last=target[#target]
                if last and last[2]==top and last[4]==bottom-top
                    and left>=last[1] and left<=last[1]+last[3] then
                    if right>last[1]+last[3] then last[3]=right-last[1]end
                else target[#target + 1] = {left, top, right - left, bottom - top}end
            end
        end
        for i = 0, 3 do
            local value = minValue + range * i / 3
            local yy = py + ph - i * ph / 3
            line(prepared.grid, px, yy, px + pw, yy)
            prepared.axes[#prepared.axes + 1] = {yy - 8, number(value, kind == "vario" and not c.imperial and 1 or 0)}
        end
        for i = 0, 4 do line(prepared.grid, px + i * pw / 4, py, px + i * pw / 4, py + ph) end
        if minValue <= 0 and maxValue >= 0 then
            prepared.zero = {}
            line(prepared.zero, px, pointY(0), px + pw, pointY(0))
        end
        local previousTime, previousX, previousY, hasValue
        for index = 1, count do
            local point = bins[index]
            if point and point.motor then
                rectangle(prepared.bands, px + (index - 1) / (count - 1) * pw, py, math.max(1, pw / (count - 1)), ph)
            end
            if point == false then previousTime = nil
            elseif point then
                -- A later valid sample in this bin must not erase a reception gap.
                if point.gapBefore then previousTime = nil end
                hasValue = true
                local xx, yy = px + (point.time - start) / span * pw, pointY(point.value)
                local pixelXX, pixelYY = pixelX(xx), pixelY(yy)
                if previousTime and point.time - previousTime <= maxGap then
                    prepared.trace[#prepared.trace + 1] = {previousX, previousY, pixelXX, pixelYY,
                        kind == "vario" and point.value < 0 and "yellow" or "climb"}
                else
                    -- A zero-length stroke is a visible point without inventing a connection.
                    prepared.trace[#prepared.trace + 1] = {pixelXX, pixelYY, pixelX(xx + 1), pixelYY, "climb"}
                end
                previousTime, previousX, previousY = point.time, pixelXX, pixelYY
            end
        end
        prepared.hasValue = hasValue
        c.widget._soarGraphCache = prepared
        end
        c.widget._soarGraphCache=prepared
        if c.prepareOnly then return end
        paintGraph(c,prepared,x,y,w,h,unit,span)
    end
    paintGraph=function(c,prepared,x,y,w,h,unit,span)
        c:text(x, y, prepared.title, w, 17, c.p.muted, nil, true)
        c:color(c.p.motor)
        for _, r in ipairs(prepared.bands) do if c.api.drawFilledRectangle then c.api.drawFilledRectangle(r[1],r[2],r[3],r[4]) end end
        c:color(c.p.grid)
        for _, l in ipairs(prepared.grid) do if c.api.drawLine then c.api.drawLine(l[1],l[2],l[3],l[4]) end end
        if prepared.zero then
            c:color(c.p.line)
            local l = prepared.zero[1]; if c.api.drawLine then c.api.drawLine(l[1],l[2],l[3],l[4]) end
        end
        local axisHeight = c.cache.heights[c.smallFonts[#c.smallFonts]] or 14
        local compactAxes = prepared.ph * c.sy < 3 * (axisHeight + 2)
        for index, axis in ipairs(prepared.axes) do
            if not compactAxes or index == 1 or index == #prepared.axes then
                local axisY = axis[1]
                -- The fixed native XS font does not shrink with a short,
                -- wide widget. Keep the bottom tick clear of its unit label;
                -- full-height plots already have sufficient separation.
                local unitY = prepared.py + prepared.ph + 7
                if index == 1 and (unitY - axisY) * c.sy < axisHeight then
                    axisY = unitY - (axisHeight + 2) / c.sy
                end
                c:text(x, axisY, axis[2], 36, 17, c.p.muted, "right", true)
            end
        end
        for _, l in ipairs(prepared.trace) do
            c:color(c.p[l[5]]); if c.api.drawLine then c.api.drawLine(l[1],l[2],l[3],l[4]) end
        end
        local px, py, pw, ph = prepared.px, prepared.py, prepared.pw, prepared.ph
        if not prepared.hasValue then c:text(px, py + ph / 2 - 10, "NO HISTORY", pw, 21, c.p.muted, "center", true) end
        c:text(x, py + ph + 7, unit, 36, 17, c.p.muted, nil, true)
        c:text(px, py + ph + 7, "-" .. number(span, 0) .. " s", 90, 17, c.p.muted, nil, true)
        c:text(px + pw - 70, py + ph + 7, "0 s", 70, 17, c.p.muted, "right", true)
    end
    local function average(c, x, y, w)
        local seconds = finite(c.cfg.avgSeconds) and clamp(c.cfg.avgSeconds, 1, 60) or 10
        stat(c, x, y, w, "AVG " .. number(seconds, 0) .. " s", converted(c.data.average, c.varioFactor),
            c.varioUnit, signColor(c, c.data.average), true)
    end
    local function maximum(c, x, y, w)
        stat(c, x, y, w, "MAX HEIGHT", converted(c.data.maxAltitude, c.altFactor), c.altUnit)
    end
    local function deck(c, motor, photo)
        if photo then
            modelImage(c, 24, 120, 292, 191)
            altitude(c, 345, 126, 221, 104)
            digitalVario(c, 590, 126, 154, 134)
            verticalVario(c, 715, motor and 235 or 245, 42, 85)
            if motor then
                average(c, 24, 351, 206); maximum(c, 251, 351, 220)
                battery(c, 514, 329, 262, 119)
            else
                average(c, 345, 260, 221)
                graph(c, 24, 343, 641, 105, "altitude")
                maximum(c, 682, 368, 94)
            end
        elseif motor then
            altitude(c, 24, 122, 307, 123)
            digitalVario(c, 354, 122, 347, 123)
            verticalVario(c, 710, 125, 43, 150)
            average(c, 275, 252, 223)
            graph(c, 24, 326, 474, 121, "altitude")
            maximum(c, 24, 252, 220)
            battery(c, 532, 331, 244, 117)
        else
            altitude(c, 24, 124, 326, 130)
            digitalVario(c, 445, 124, 331, 130)
            verticalVario(c, 363, 123, 49, 145)
            graph(c, 24, 294, 578, 154, "altitude")
            average(c, 631, 300, 145); maximum(c, 631, 385, 145)
        end
    end
    local function classic(c, motor, photo)
        if photo then
            modelImage(c, 24, 118, 349, 151)
            altitude(c, 24, motor and 270 or 280, 335, motor and 78 or 107)
            dial(c, 590, motor and 250 or 252, motor and 135 or 143, "vario")
            if motor then
                c:text(24, 355, "AVG " .. number(converted(c.data.average, c.varioFactor), c.imperial and 0 or 1, true)
                    .. " " .. c.varioUnit, 230, 31, signColor(c, c.data.average))
                c:text(265, 355, "MAX " .. number(converted(c.data.maxAltitude, c.altFactor), 0)
                    .. " " .. c.altUnit, 255, 31, c.p.fg)
                battery(c, 24, 401, 752, 58, true)
            else
                average(c, 24, 400, 233); maximum(c, 283, 400, 230)
                stat(c, 548, 400, 228, "FLIGHT GAIN", converted(c.data.gain, c.altFactor), c.altUnit, c.p.climb, true)
            end
        elseif c.cfg.showAirspeed == true then
            if motor then
                dial(c, 166, 253, 129, "vario")
                altitude(c, 318, 133, 184, 116, true); maximum(c, 325, 281, 177)
                dial(c, 650, 248, 117, "airspeed")
                average(c, 24, 391, 229)
                battery(c, 300, 388, 476, 62, true)
            else
                dial(c, 149, 254, 116, "airspeed")
                dial(c, 400, 251, 133, "vario")
                dial(c, 655, 254, 116, "altitude")
                average(c, 24, 397, 229); maximum(c, 283, 397, 230)
                stat(c, 548, 397, 228, "FLIGHT GAIN", converted(c.data.gain, c.altFactor), c.altUnit, c.p.climb, true)
            end
        else
            altitude(c, 35, 136, 337, 136)
            dial(c, 586, 254, 140, "vario")
            if motor then
                average(c, 35, 291, 315); maximum(c, 35, 365, 315)
                battery(c, 392, 394, 384, 62, true)
            else
                average(c, 35, 302, 337)
                maximum(c, 35, 389, 337)
                stat(c, 454, 397, 322, "FLIGHT GAIN", converted(c.data.gain, c.altFactor), c.altUnit, c.p.climb, true)
            end
        end
    end
    local function thermal(c, motor, photo)
        if photo then
            modelImage(c, 24, 117, 303, 140)
            altitude(c, 349, 127, 200, 100)
            digitalVario(c, 574, 127, 202, 105)
            average(c, 349, 235, 200)
            maximum(c, 574, 235, 202)
            if motor then
                graph(c, 24, 313, 548, 136)
                battery(c, 598, 317, 178, c.cfg.showGroundspeed == true and 105 or 131)
                if c.cfg.showGroundspeed == true then
                    c:text(598, 428, "GPS GND " .. number(converted(c.data.groundspeed, c.speedFactor), 0) .. " " .. c.speedUnit,
                        178, 24, c.p.fg)
                end
            else graph(c, 24, 313, 752, 136) end
        elseif motor then
            altitude(c, 24, 122, 282, 115)
            digitalVario(c, 331, 122, 260, 115)
            battery(c, 612, 123, 164, 124)
            graph(c, 24, 265, 752, 136)
            local b = type(c.data.battery) == "table" and c.data.battery or {}
            local _, estimated = batteryMethod(b)
            if c.small then
                c:text(24, 425, "AVG " .. number(converted(c.data.average, c.varioFactor), c.imperial and 0 or 1, true)
                    .. " " .. c.varioUnit, 260, 23, signColor(c, c.data.average))
                c:text(310, 425, "MOTOR " .. timer(c.data.motorTime), 217, 23, c.p.fg)
                c:text(553, 425, not estimated and number(b.remaining, 0) .. " mAh"
                    or "MAX " .. number(converted(c.data.maxAltitude, c.altFactor), 0) .. " " .. c.altUnit, 223, 23, c.p.fg)
            else
                average(c, 24, 405, 250)
                c:text(310, 405, "MOTOR TIME", 217, 17, c.p.muted, nil, true)
                c:text(310, 428, timer(c.data.motorTime), 217, 35, c.p.fg)
                if not estimated then stat(c, 553, 405, 223, "REMAINING", b.remaining, "mAh")
                else maximum(c, 553, 405, 223) end
            end
        else
            altitude(c, 24, 121, 282, 117)
            average(c, 329, 134, 200)
            digitalVario(c, 553, 121, 223, 117)
            graph(c, 24, 265, 752, 184, c.cfg.historyKind == 1 and "altitude" or "vario")
        end
    end
    local function daylight(c, motor, photo)
        if photo then
            modelImage(c, 24, 125, 318, motor and 206 or 245)
            altitude(c, 372, 123, 404, 119)
            digitalVario(c, 372, 264, 404, 116)
            if motor then battery(c, 24, 397, 752, 61, true)
            else
                average(c, 24, 398, 338); maximum(c, 402, 398, 374)
            end
        else
            altitude(c, 24, 125, 348, 175)
            digitalVario(c, 413, 125, 363, 175)
            c:line(395, 122, 395, 321, c.p.line)
            c:line(24, 339, 776, 339, c.p.line)
            if motor then
                average(c, 24, 366, 224)
                if c.cfg.showAirspeed == true then
                    stat(c, 277, 366, 220, "AIRSPEED (IAS)", converted(c.data.airspeed, c.speedFactor), c.speedUnit)
                else maximum(c, 277, 366, 220) end
                battery(c, 531, 354, 245, 95)
            else
                average(c, 24, 373, 240); maximum(c, 294, 373, 205)
                graph(c, 526, 354, 250, 95, "altitude")
            end
        end
    end
    -- Optional controller hook: prepare bounded history geometry after a history
    -- update, outside paint. No LCD drawing or telemetry access occurs here.
    function M.prepare(widget, width, height)
        if type(widget) ~= "table" or widget.destroyed then return end
        local cfg = type(widget.cfg) == "table" and widget.cfg or {}
        local motor, photo, style = cfg.modelType == 2, cfg.imageMode ~= 3, cfg.style
        if style == 2 or (style == 4 and (photo or motor)) or (style ~= 3 and photo and motor) then return end
        width, height = width or widget._soarRenderWidth, height or widget._soarRenderHeight
        if not finite(width) or not finite(height) or width < 1 or height < 1 then
            local kind = style == 3 and cfg.historyKind == 2 and "vario" or "altitude"
            local factor = cfg.unitMode == 2 and (kind == "vario" and 196.8504 or 3.28084) or 1
            historyInput(widget, kind, factor, historySpan(cfg), 100)
            return
        end
        -- This context needs no palette, fonts or LCD API. In particular RGB,
        -- getWindowSize and getTextSize are never called from the wakeup hook.
        local c = widget._soarPrepareContext
        if not c then c = {}; widget._soarPrepareContext = c end
        c.widget, c.cfg, c.data, c.width, c.height = widget, cfg, widget.data or {}, floor(width), floor(height)
        c.sx, c.sy, c.prepareOnly, c.imperial = c.width / 800, c.height / 480, true, cfg.unitMode == 2
        c.altFactor, c.varioFactor = cfg.unitMode == 2 and 3.28084 or 1, cfg.unitMode == 2 and 196.8504 or 1
        c.altUnit, c.varioUnit = cfg.unitMode == 2 and "ft" or "m", cfg.unitMode == 2 and "ft/min" or "m/s"
        if style == 3 then
            if photo then graph(c, 24, 313, motor and 548 or 752, 136)
            elseif motor then graph(c, 24, 265, 752, 136)
            else graph(c, 24, 265, 752, 184, c.cfg.historyKind == 1 and "altitude" or "vario") end
        elseif style == 4 then
            if not photo and not motor then graph(c, 526, 354, 250, 95, "altitude") end
        elseif style ~= 2 then
            if photo and not motor then graph(c, 24, 343, 641, 105, "altitude")
            elseif not photo and motor then graph(c, 24, 326, 474, 121, "altitude")
            elseif not photo then graph(c, 24, 294, 578, 154, "altitude") end
        end
    end
    function M.paint(widget)
        if type(widget) ~= "table" or widget.destroyed then return end
        local ok, width, height = native("getWindowSize")
        if not ok or not finite(width) or not finite(height) or width < 1 or height < 1 then return end
        widget._soarRenderWidth, widget._soarRenderHeight = math.floor(width), math.floor(height)
        local c = context(widget, math.floor(width), math.floor(height))
        local motor, photo = c.cfg.modelType == 2, c.cfg.imageMode ~= 3
        c:rect(0, 0, 800, 480, c.p.bg)
        header(c, motor)
        if c.cfg.style == 2 then classic(c, motor, photo)
        elseif c.cfg.style == 3 then thermal(c, motor, photo)
        elseif c.cfg.style == 4 then daylight(c, motor, photo)
        else deck(c, motor, photo) end
        footer(c)
    end

    local originalPrepare=M.prepare
    local function prepareDial(widget,width,height)
        local cfg=widget.cfg or {}
        local c={width=width,height=height,sx=width/800,sy=height/480,small=width<600,imperial=cfg.unitMode==2}
        local static={}
        local maximum=finite(cfg.varioScale) and clamp(cfg.varioScale,0.5,20) or 5
        local function add(cx,cy,r,kind)
            local max=kind=="vario" and maximum or kind=="airspeed" and 160 or 1000
            local factor=cfg.unitMode==2 and(kind=="vario" and 196.8504 or kind=="airspeed" and 0.621371 or 3.28084)or 1
            static[dialStaticKey(c,cx,cy,r,kind,max,factor)]=staticDial(c,cx,cy,r,kind=="vario",max,factor)
        end
        local motor,photo=cfg.modelType==2,cfg.imageMode~=3
        if photo then add(590,motor and 250 or 252,motor and 135 or 143,"vario")
        elseif cfg.showAirspeed==true then
            if motor then add(166,253,129,"vario");add(650,248,117,"airspeed")
            else add(149,254,116,"airspeed");add(400,251,133,"vario");add(655,254,116,"altitude") end
        else add(586,254,140,"vario") end
        return static
    end
    -- PRIVATE synchronous finite projection preparation. Native ETHOS may
    -- preempt/resume wakeup; every temporary and cache belongs to this instance.
    -- Each source history scan remains bounded to the newest 600 rows/100 bins.
    -- Live data/timers never participate in cache matching or get captured here.
    local PREPARE_KEYS={"style","modelType","imageMode","unitMode","varioScale","historySeconds","historyKind","altitudeMode","showAirspeed"}
    local function configSnapshot(widget)
        local result={}
        for i=1,#PREPARE_KEYS do local k=PREPARE_KEYS[i];result[k]=(widget.cfg or {})[k] end
        return result
    end
    local function configMatches(cfg,widget)
        if widget.destroyed then return false end
        for i=1,#PREPARE_KEYS do local k=PREPARE_KEYS[i];if cfg[k]~=(widget.cfg or {})[k]then return false end end
        return true
    end
    local function graphProfile(cfg)
        local motor,photo,style=cfg.modelType==2,cfg.imageMode~=3,cfg.style
        if style==2 or(style==4 and(photo or motor))or(style~=3 and photo and motor)then return nil end
        if style==3 then
            if photo then return 24,313,motor and 548 or 752,136 end
            if motor then return 24,265,752,136 end
            return 24,265,752,184,cfg.historyKind==1 and "altitude" or "vario"
        elseif style==4 then return 526,354,250,95,"altitude"
        elseif photo then return 24,343,641,105,"altitude"
        elseif motor then return 24,326,474,121,"altitude"
        else return 24,294,578,154,"altitude" end
    end
    local function projection(widget,cfg,width,height,prior,seed,label)
        local x,y,w,h,requestedKind=graphProfile(cfg)
        if not x then return nil end
        local kind=requestedKind or(cfg.historyKind==2 and "vario" or "altitude")
        local factor=cfg.unitMode==2 and(kind=="vario" and 196.8504 or 3.28084)or 1
        local span=historySpan(cfg)
        if not(seed and historyMatches(seed,widget,kind,factor,span,seed.count))then
            seed=prior and prior.input
            if not(seed and historyMatches(seed,widget,kind,factor,span,seed.count))then seed=nil end
        end
        local proxy={cfg=cfg,data={altitudeLabel=label},history=widget.history,historyRevision=widget.historyRevision,
            _soarGraphInput=seed,_soarGraphCache=prior}
        originalPrepare(proxy,width,height)
        local prepared=proxy._soarGraphCache
        if not prepared then return nil end
        -- Check the actual live instance after any wakeup preemption. A mixed
        -- configuration/history cannot become a published completed projection.
        if not configMatches(cfg,widget)or(widget.data or {}).altitudeLabel~=label
            or not historyMatches(prepared.input,widget,kind,factor,span,prepared.input.count)then return nil end
        return prepared
    end
    local function prepareViewports(widget,width,height)
        local known=finite(width)and finite(height)and width>0 and height>0
        local w,h=known and floor(width)or 800,known and floor(height)or 480
        local sw,sh=w==480 and h==320 and 800 or 480,w==480 and h==320 and 480 or 320
        return w,h,sw,sh
    end
    function M.prepare(widget,width,height)
        if type(widget)~="table"then return end
        if widget.destroyed then M.destroy(widget);return end
        local cfg=configSnapshot(widget)
        width,height=width or widget._soarRenderWidth,height or widget._soarRenderHeight
        local w,h,sw,sh=prepareViewports(widget,width,height)
        if cfg.style==2 then
            local scale=finite(cfg.varioScale)and clamp(cfg.varioScale,0.5,20)or 5
            local key=table.concat({cfg.modelType or 1,cfg.imageMode or 1,cfg.unitMode or 1,
                cfg.showAirspeed==true and 1 or 0,scale,w,h,sw,sh},"/")
            if widget._soarDialKey~=key then
                local a=prepareDial({cfg=cfg},w,h)
                local b=prepareDial({cfg=cfg},sw,sh)
                for k,v in pairs(b)do a[k]=v end
                if configMatches(cfg,widget)then widget._soarDialGeometry,widget._soarDialKey=a,key end
            end
            widget._soarGraphProjections=nil;return
        end
        widget._soarDialGeometry,widget._soarDialKey=nil,nil
        if not graphProfile(cfg)then widget._soarGraphProjections=nil;return end
        local prior=widget._soarGraphProjections or{}
        local first,second=w.."/"..h,sw.."/"..sh
        local label=(widget.data or{}).altitudeLabel
        local a=projection(widget,cfg,w,h,prior[first],widget._soarGraphInput,label)
        if not a then return end
        local b=projection(widget,cfg,sw,sh,prior[second],a.input,label)
        if not b then return end
        -- Both exact viewports publish together only after the full finite job.
        -- Paint still rechecks actual window/config/history before using either.
        if configMatches(cfg,widget)and(widget.data or{}).altitudeLabel==label
            and historyMatches(a.input,widget,a.input.kind,a.input.factor,a.input.span,a.input.count)
            and historyMatches(b.input,widget,b.input.kind,b.input.factor,b.input.span,b.input.count)then
            widget._soarGraphProjections={[first]=a,[second]=b}
            widget._soarGraphInput,widget._soarGraphCache=a.input,a
        end
    end

    -- PRIVATE complete finite plans. Recording is a property of one explicit
    -- private Context, never a native/global interceptor. Live fields are frozen
    -- only for the completed preparation; paint rejects every changed field.
    local PLAN_CFG={"style","modelType","imageMode","unitMode","showAirspeed","showGroundspeed","altitudeMode","varioScale","avgSeconds","historyKind","historySeconds","daylight","modelName"}
    local PLAN_DATA={"modelName","altitude","altitudeLabel","vario","average","maxAltitude","gain","flightTime","motorTime","motorActive","rxVoltage","txVoltage","rf","rfUnit","airspeed","groundspeed","live","preview","derived","message","audioMode"}
    local PLAN_BATTERY={"percent","remaining","voltage","cellMin","method","status","counterReset","reason"}
    local PLAN_COLORS={}
    for _,key in ipairs({"bg","fg","muted","line","grid","track","climb","green","yellow","orange","red","motor"})do PLAN_COLORS[key]=key end
    local function same(a,b)return a==b or(type(a)=="number"and type(b)=="number"and a~=a and b~=b)end
    local function copyFields(source,keys)
        local target={}
        for i=1,#keys do local key=keys[i];target[key]=source[key]end
        return target
    end
    local function matchFields(a,b,keys)
        for i=1,#keys do local key=keys[i];local av,bv=a[key],b[key];if av~=bv and not same(av,bv)then return false end end
        return true
    end
    local function renderSnapshot(widget)
        local cfg=type(widget.cfg)=="table"and widget.cfg or EMPTY_HISTORY
        local data=type(widget.data)=="table"and widget.data or EMPTY_HISTORY
        local history=type(widget.history)=="table"and widget.history or EMPTY_HISTORY
        local tail=type(history[#history])=="table"and history[#history]or EMPTY_HISTORY
        local frozenData=copyFields(data,PLAN_DATA)
        frozenData.battery=copyFields(type(data.battery)=="table"and data.battery or EMPTY_HISTORY,PLAN_BATTERY)
        return{cfg=copyFields(cfg,PLAN_CFG),data=frozenData,history=history,length=#history,revision=widget.historyRevision,
            time=tail.x,altitude=tail.altitude,vario=tail.vario,motor=tail.motor,
            bitmap=setmetatable({widget.bitmap},{__mode="v"}),bitmapWidth=widget.bitmapWidth,bitmapHeight=widget.bitmapHeight,imageError=widget.imageError}
    end
    local function renderMatches(snapshot,widget)
        if widget.destroyed then return false end
        local cfg=type(widget.cfg)=="table"and widget.cfg or EMPTY_HISTORY
        local data=type(widget.data)=="table"and widget.data or EMPTY_HISTORY
        local history=type(widget.history)=="table"and widget.history or EMPTY_HISTORY
        local tail=type(history[#history])=="table"and history[#history]or EMPTY_HISTORY
        return matchFields(snapshot.cfg,cfg,PLAN_CFG)and matchFields(snapshot.data,data,PLAN_DATA)
            and matchFields(snapshot.data.battery,type(data.battery)=="table"and data.battery or EMPTY_HISTORY,PLAN_BATTERY)
            and snapshot.history==history and snapshot.length==#history and snapshot.revision==widget.historyRevision
            and same(snapshot.time,tail.x)and same(snapshot.altitude,tail.altitude)and same(snapshot.vario,tail.vario)and same(snapshot.motor,tail.motor)
            and snapshot.bitmap[1]==widget.bitmap and snapshot.bitmapWidth==widget.bitmapWidth and snapshot.bitmapHeight==widget.bitmapHeight and snapshot.imageError==widget.imageError
    end
    local function append(plan,count)
        plan.lastPrimitiveAt=nil
        plan.count=plan.count+1
        assert(plan.count<=512,"Prepared drawing plan exceeds512 operations")
        local at=plan.n+1;plan.n=plan.n+count
        return plan.ops,at
    end
    recordPrimitive=function(c,kind,color,x1,y1,x2,y2)
        local plan=c.recordPlan
        local ops,previous=plan.ops,plan.lastPrimitiveAt
        if previous and ops[previous+1]==color and(ops[previous]==kind or ops[previous]==kind+6)then
            -- Logical drawing commands retain the original512 cap. A batch is
            -- just fewer Lua dispatches; every original native primitive runs.
            plan.count=plan.count+1
            assert(plan.count<=512,"Prepared drawing plan exceeds512 operations")
            local at
            if ops[previous]==kind then
                -- Keep isolated primitives at their original6 slots; the first
                -- adjacent match becomes a3-slot header plus four coords each.
                ops[previous+6]=ops[previous+5];ops[previous+5]=ops[previous+4]
                ops[previous+4]=ops[previous+3];ops[previous+3]=ops[previous+2]
                ops[previous],ops[previous+2]=kind+6,2
                at=plan.n+2;plan.n=plan.n+5
            else
                ops[previous+2]=ops[previous+2]+1
                at=plan.n+1;plan.n=plan.n+4
            end
            ops[at],ops[at+1],ops[at+2],ops[at+3]=x1,y1,x2,y2
        else
            local at;ops,at=append(plan,6)
            ops[at],ops[at+1],ops[at+2],ops[at+3],ops[at+4],ops[at+5]=kind,color,x1,y1,x2,y2
            plan.lastPrimitiveAt=at
        end
    end
    local function preparedTextSpec(c,x,y,value,w,h,color,align,small,geometry)
        if geometry then
            return {geometry[1],geometry[2],geometry[3],geometry[4],geometry[5],geometry[6],color,align or false,small==true}
        end
        value=clean(value)
        local pw,ph=math.max(0,floor(w*c.sx)),math.max(0,floor(h*c.sy))
        if pw<3 or ph<1 or value==""then return end
        return {value,pw,ph,pw.."|"..ph.."|"..(small and 1 or 0).."|"..value,x*c.sx,y*c.sy,color,align or false,small==true}
    end
    recordText=function(c,x,y,value,w,h,color,align,small,geometry)
        local spec=preparedTextSpec(c,x,y,value,w,h,color,align,small,geometry)
        if not spec then return 0,0 end
        local plan=c.recordPlan
        local prior=plan.prior
        local old=prior and prior.ops[plan.n+2]
        if type(old)=="table"and prior.ops[plan.n+1]==3 and old[1]==spec[1]and old[2]==spec[2]and old[3]==spec[3]
            and old[5]==spec[5]and old[6]==spec[6]and old[8]==spec[8]and old[9]==spec[9]then
            for i=10,18 do spec[i]=old[i]end
        end
        local ops,at=append(plan,2);ops[at],ops[at+1]=3,spec
        return 0,0
    end
    recordCircle=function(c,x,y,radius,color,filled)
        local ops,at=append(c.recordPlan,6)
        ops[at],ops[at+1],ops[at+2],ops[at+3],ops[at+4],ops[at+5]=4,x,y,radius,color,filled==true
    end
    recordImage=function(c,x,y,w,h)
        local ops,at=append(c.recordPlan,5)
        ops[at],ops[at+1],ops[at+2],ops[at+3],ops[at+4]=5,x,y,w,h
    end
    recordGraph=function(c,x,y,w,h,kind)
        -- No native metrics are read here. Static graph labels and pixel
        -- primitives are already projected; only metric-dependent axis layout
        -- remains in paint. Existing projection arrays are shared, not copied.
        local plan=c.recordPlan
        c.recordPlan,c.prepareOnly=nil,true
        graph(c,x,y,w,h,kind)
        c.recordPlan,c.prepareOnly=plan,false
        local prepared=c.widget._soarGraphCache
        local prior=plan.prior
        local old=prior and prior.ops[plan.n+2]
        local spec
        if prior and prior.ops[plan.n+1]==6 and type(old)=="table"and old.prepared==prepared then spec=old
        else
            local resolved=kind or(c.cfg.historyKind==2 and"vario"or"altitude")
            local unit=resolved=="vario"and c.varioUnit or c.altUnit
            local span=historySpan(c.cfg)
            local px,py,pw,ph=prepared.px,prepared.py,prepared.pw,prepared.ph
            local unitY=py+ph+7
            spec={prepared=prepared,axes={},unitY=unitY,bottomBase=prepared.axes[1][1]}
            -- Altitude trace primitives are defined as climb-colored. A vario
            -- projection may also be uniform; prove that using its immutable
            -- projected rows here, never by skipping per-point color semantics.
            local trace=prepared.trace
            local tone=resolved=="altitude"and"climb"or(trace[1]and trace[1][5])
            if resolved~="altitude"then for i=2,#trace do if trace[i][5]~=tone then tone=nil;break end end end
            spec.traceColor=tone
            spec.title=preparedTextSpec(c,x,y,prepared.title,w,17,"muted",nil,true)
            for i=1,#prepared.axes do local axis=prepared.axes[i]
                spec.axes[i]=preparedTextSpec(c,x,axis[1],axis[2],36,17,"muted","right",true)
            end
            if not prepared.hasValue then spec.empty=preparedTextSpec(c,px,py+ph/2-10,"NO HISTORY",pw,21,"muted","center",true)end
            spec.unit=preparedTextSpec(c,x,unitY,unit,36,17,"muted",nil,true)
            spec.span=preparedTextSpec(c,px,unitY,"-"..number(span,0).." s",90,17,"muted",nil,true)
            spec.zero=preparedTextSpec(c,px+pw-70,unitY,"0 s",70,17,"muted","right",true)
        end
        local ops,at=append(plan,2);ops[at],ops[at+1]=6,spec
    end
    local function buildRenderPlan(widget,snapshot,width,height,prior)
        local cfg,data=snapshot.cfg,snapshot.data
        local plan={ops={},n=0,count=0,width=width,height=height,prior=prior}
        local proxy={cfg=cfg,data=data,history=snapshot.history,historyRevision=snapshot.revision,
            _soarDialGeometry=widget._soarDialGeometry,_soarGraphProjections=widget._soarGraphProjections,
            _soarGraphInput=widget._soarGraphInput,_soarGraphCache=widget._soarGraphCache}
        local c=setmetatable({widget=proxy,cfg=cfg,data=data,width=width,height=height,sx=width/800,sy=height/480,
            small=width<600,imperial=cfg.unitMode==2,p=PLAN_COLORS,recordPlan=plan,lastFont=nil,lastColor=nil},Context)
        c.altFactor,c.varioFactor,c.speedFactor=c.imperial and 3.28084 or 1,c.imperial and 196.8504 or 1,c.imperial and 0.621371 or 1
        c.altUnit,c.varioUnit,c.speedUnit=c.imperial and"ft"or"m",c.imperial and"ft/min"or"m/s",c.imperial and"mph"or"km/h"
        local motor,photo=cfg.modelType==2,cfg.imageMode~=3
        c:rect(0,0,800,480,c.p.bg);header(c,motor)
        if cfg.style==2 then classic(c,motor,photo)
        elseif cfg.style==3 then thermal(c,motor,photo)
        elseif cfg.style==4 then daylight(c,motor,photo)
        else deck(c,motor,photo)end
        footer(c);plan.prior=nil
        return plan
    end
    local geometryPrepare=M.prepare
    function M.prepare(widget,width,height)
        if type(widget)~="table"then return end
        if widget.destroyed then M.destroy(widget);return end
        settleTextFits(widget)
        geometryPrepare(widget,width,height)
        if widget.destroyed then M.destroy(widget);return end
        width,height=width or widget._soarRenderWidth,height or widget._soarRenderHeight
        local initial=not(finite(width)and finite(height)and width>0 and height>0)
        local w,h,sw,sh=prepareViewports(widget,width,height)
        local first,second=w.."/"..h,sw.."/"..sh
        local prior=widget._soarRenderPlans
        if prior and prior[first]and prior[second]and prior.initial==initial
            and(not initial or prior["784/316"])and renderMatches(prior.snapshot,widget)then return end
        local snapshot=renderSnapshot(widget)
        local a=buildRenderPlan(widget,snapshot,w,h,prior and prior[first])
        local b=buildRenderPlan(widget,snapshot,sw,sh,prior and prior[second])
        -- The third INITIAL plan covers the ordinary Home window actually
        -- observed on ETHOS/X20 in this project. Once paint reports its actual
        -- window, retain only that exact viewport plus the compact design view.
        -- Other windows always use the correct measured fallback.
        local home=initial and buildRenderPlan(widget,snapshot,784,316,prior and prior["784/316"])or nil
        if renderMatches(snapshot,widget)then
            widget._soarRenderPlans={snapshot=snapshot,initial=initial,primary=a,[first]=a,[second]=b}
            if home then widget._soarRenderPlans["784/316"]=home end
        elseif widget.destroyed then M.destroy(widget)end
    end
    -- A borrowed cache payload references only a flat text spec: never its
    -- parent plan, widget, graph/history or bitmap. Normalize before replacing
    -- plans so obsolete specs cannot add retained fields to the128-entry cache.
    settleTextFits=function(widget)
        local cache=widget._soarTextCache
        if not cache or not cache.entries or not cache.keys then return end
        local entries,keys=cache.entries,cache.keys
        for i=1,#keys do
            local key=keys[i];local fit=entries[key]
            if fit and fit[1]~=nil then entries[key]={font=fit[10],value=fit[13],w=fit[17],h=fit[18]}end
        end
    end
    -- Bind the current native functions and fixed frame values once per real
    -- paint. These two closures are frame-local and never stored on a widget.
    -- All native metrics, font selection and truncation still happen in paint.
    local function textDrawer(c)
        local api,cache=c.api,c.cache
        local fontFn,colorFn,textFn,metricFn=api.font,api.color,api.drawText,api.getTextSize
        local entries,keys,heights,starts=cache.entries,cache.keys,cache.heights,cache.starts
        local fontList,smallFonts,p,width,height=c.fontList,c.smallFonts,c.p,c.width,c.height
        local protected=pcall
        local function measured(value)
            local ok,w,h
            if metricFn then ok,w,h=protected(metricFn,value)end
            if ok and type(w)=="number"and type(h)=="number"and w>=0 and w<huge and h>0 and h<huge then
                if c.lastFont~=nil then heights[c.lastFont]=h end
                return w,h,true
            end
            return #value*7,14,false
        end
        return function(spec)
            local tone=p[spec[7]]
            if spec[10]~=nil and spec[14]==fontList then
                local font=spec[10]
                if c.lastFont~=font then if fontFn then fontFn(font)end;c.lastFont=font end
                if c.lastColor~=tone then if colorFn then colorFn(tone)end;c.lastColor=tone end
                if textFn then textFn(spec[11],spec[12],spec[13],LEFT or 0)end
                return
            end
            local value,pw,ph=spec[1],spec[2],spec[3]
            if pw<3 or ph<1 or value==""then return end
            local key=spec[4]
            local fitted=entries[key]
            local selected,tw,th
            if fitted then
                if fitted[1]~=nil then selected,value,tw,th=fitted[10],fitted[13],fitted[17],fitted[18]
                else selected,value,tw,th=fitted.font,fitted.value,fitted.w,fitted.h end
            else
                local candidates=spec[9]and smallFonts or fontList
                local indices=starts[spec[9]and 2 or 1]
                local index,last=indices[ph]or 1,#candidates
                while index<last and heights[candidates[index]]and heights[candidates[index]]>ph do index=index+1 end
                indices[ph]=index
                while index<=last do
                    local font=candidates[index]
                    local knownHeight=heights[font]
                    if not knownHeight or knownHeight<=ph or index==last then
                        if c.lastFont~=font then if fontFn then fontFn(font)end;c.lastFont=font end
                        local ok
                        if metricFn then ok,tw,th=protected(metricFn,value)end
                        if ok and type(tw)=="number"and type(th)=="number"and tw>=0 and tw<huge and th>0 and th<huge then heights[font]=th
                        else tw,th=#value*7,14 end
                        selected=font
                        if tw<=pw and th<=ph then break end
                    end
                    index=index+1
                end
                if tw>pw then
                    local suffix="..."
                    local suffixWidth,suffixHeight,suffixValid=measured(suffix)
                    local bestWidth,bestHeight,bestValid
                    if suffixWidth>pw then value=""
                    else
                        local low,high,best=0,#value,""
                        while low<=high do
                            local middle=floor((low+high)/2)
                            local test=prefix(value,middle)..suffix
                            local testWidth,testHeight,testValid
                            -- The native font is unchanged throughout ONE
                            -- search. Reuse only successful metrics already
                            -- measured for its identical suffix/candidate.
                            if test==suffix and suffixValid then testWidth,testHeight,testValid=suffixWidth,suffixHeight,true
                            else testWidth,testHeight,testValid=measured(test)end
                            if testWidth<=pw then best= test;bestWidth,bestHeight,bestValid=testWidth,testHeight,testValid;low=middle+1
                            else high=middle-1 end
                        end
                        value=best
                    end
                    if bestValid then tw,th=bestWidth,bestHeight
                    else tw,th=measured(value)end
                end
                -- Reuse this existing flat spec instead of allocating an
                -- additional fitted table during the first cold frame.
                spec[10],spec[13],spec[17],spec[18]=selected,value,tw,th
                local cursor=cache.cursor%128+1;cache.cursor=cursor
                local old=keys[cursor];if old then entries[old]=nil end
                keys[cursor]=key
                entries[key]=spec
            end
            if value==""or th>height then return end
            local px,align=spec[5],spec[8]
            if align=="right"then px=px+pw-tw elseif align=="center"then px=px+(pw-tw)/2 end
            local xmax=width-tw;if xmax<0 then xmax=0 end
            px=floor(px+0.5);if px<0 then px=0 elseif px>xmax then px=xmax end
            local py=floor(spec[6]+0.5);local ymax=height-th
            if py<0 then py=0 elseif py>ymax then py=ymax end
            if c.lastFont~=selected then if fontFn then fontFn(selected)end;c.lastFont=selected end
            if c.lastColor~=tone then if colorFn then colorFn(tone)end;c.lastColor=tone end
            if textFn then textFn(px,py,value,LEFT or 0)end
            spec[10],spec[11],spec[12],spec[13],spec[17],spec[18]=selected,px,py,value,tw,th
            spec[14]=fontList
        end
    end
    local function preparedGraph(c,spec,drawText)
        local prepared,api,p=spec.prepared,c.api,c.p
        local colorFn,rectFn,lineFn=api.color,api.drawFilledRectangle,api.drawLine
        local protected=pcall
        if spec.title then drawText(spec.title)end
        local tone=p.motor
        if c.lastColor~=tone then if colorFn then colorFn(tone)end;c.lastColor=tone end
        local bands=prepared.bands
        if rectFn then for i=1,#bands do local r=bands[i];rectFn(r[1],r[2],r[3],r[4])end end
        tone=p.grid
        if c.lastColor~=tone then if colorFn then colorFn(tone)end;c.lastColor=tone end
        local grid=prepared.grid
        if lineFn then for i=1,#grid do local l=grid[i];lineFn(l[1],l[2],l[3],l[4])end end
        if prepared.zero then
            tone=p.line
            if c.lastColor~=tone then if colorFn then colorFn(tone)end;c.lastColor=tone end
            local l=prepared.zero[1];if lineFn then lineFn(l[1],l[2],l[3],l[4])end
        end
        local axisHeight=c.cache.heights[c.smallFonts[#c.smallFonts]]or 14
        local compactAxes=prepared.ph*c.sy<3*(axisHeight+2)
        local axes=spec.axes
        for i=1,#axes do
            if not compactAxes or i==1 or i==#axes then
                local axis=axes[i]
                if axis then
                    if i==1 then
                        local y=spec.bottomBase
                        if(spec.unitY-y)*c.sy<axisHeight then y=spec.unitY-(axisHeight+2)/c.sy end
                        local py=y*(c.graphSy or c.sy)
                        if axis[6]~=py then axis[6],axis[14]=py,nil end
                    end
                    drawText(axis)
                end
            end
        end
        local trace=prepared.trace
        if spec.traceColor then
            if #trace>0 then
                tone=p[spec.traceColor]
                if c.lastColor~=tone then if colorFn then colorFn(tone)end;c.lastColor=tone end
                if lineFn then for i=1,#trace do local l=trace[i];lineFn(l[1],l[2],l[3],l[4])end end
            end
        else
            for i=1,#trace do local l=trace[i]
                tone=p[l[5]]
                if c.lastColor~=tone then if colorFn then colorFn(tone)end;c.lastColor=tone end
                if lineFn then lineFn(l[1],l[2],l[3],l[4])end
            end
        end
        if spec.empty then drawText(spec.empty)end
        if spec.unit then drawText(spec.unit)end
        if spec.span then drawText(spec.span)end
        if spec.zero then drawText(spec.zero)end
    end
    local function replay(c,plan)
        local ops,i,n=plan.ops,1,plan.n
        local api,p=c.api,c.p
        local colorFn,rectFn,lineFn=api.color,api.drawFilledRectangle,api.drawLine
        local protected=pcall
        local drawText=textDrawer(c)
        if c.transitionX then
            local actualText=drawText
            drawText=function(spec)
                local pw,ph=floor(spec[2]*c.transitionX),floor(spec[3]*c.transitionY)
                -- A fit already measured in the identical native font remains
                -- valid when it fits the new box. Reposition it for this one
                -- transitional frame; normal preparation restores optimal size.
                local tw,th=spec[17],spec[18]
                if spec[10]~=nil and spec[14]==c.fontList and tw<=pw and th<=ph then
                    local x,y=spec[5]*c.transitionX,spec[6]*c.transitionY
                    if spec[8]=="right"then x=x+pw-tw elseif spec[8]=="center"then x=x+(pw-tw)/2 end
                    x=clamp(floor(x+0.5),0,c.width-tw);y=clamp(floor(y+0.5),0,c.height-th)
                    local font,tone=spec[10],p[spec[7]]
                    if c.lastFont~=font then if api.font then api.font(font)end;c.lastFont=font end
                    if c.lastColor~=tone then if colorFn then colorFn(tone)end;c.lastColor=tone end
                    if api.drawText then api.drawText(x,y,spec[13],LEFT or 0)end
                    return
                end
                -- The published spec's fitted font/position belong to its old
                -- viewport. Fit a flat temporary spec against actual metrics;
                -- the bounded text cache still reuses identical new-size fits.
                actualText({spec[1],pw,ph,pw.."|"..ph.."|"..(spec[9]and 1 or 0).."|"..spec[1],
                    spec[5]*c.transitionX,spec[6]*c.transitionY,spec[7],spec[8],spec[9]})
            end
        end
        while i<=n do
            local kind=ops[i]
            if kind==1 then
                local tone=p[ops[i+1]]
                if c.lastColor~=tone then if colorFn then colorFn(tone)end;c.lastColor=tone end
                if rectFn then rectFn(ops[i+2],ops[i+3],ops[i+4],ops[i+5])end
                i=i+6
            elseif kind==2 then
                local tone=p[ops[i+1]]
                if c.lastColor~=tone then if colorFn then colorFn(tone)end;c.lastColor=tone end
                if lineFn then lineFn(ops[i+2],ops[i+3],ops[i+4],ops[i+5])end
                i=i+6
            elseif kind==7 or kind==8 then
                local tone=p[ops[i+1]]
                if c.lastColor~=tone then if colorFn then colorFn(tone)end;c.lastColor=tone end
                local fn;if kind==7 then fn=rectFn else fn=lineFn end
                local finish=i+3+4*ops[i+2]
                if fn then for at=i+3,finish-1,4 do fn(ops[at],ops[at+1],ops[at+2],ops[at+3])end end
                i=finish
            elseif kind==3 then drawText(ops[i+1]);i=i+2
            elseif kind==4 then
                local projected=c.api;c.api=c.actualApi or projected
                c:circle(ops[i+1],ops[i+2],ops[i+3],p[ops[i+4]],ops[i+5]);c.api=projected;i=i+6
            elseif kind==5 then
                local projected=c.api;c.api=c.actualApi or projected
                modelImage(c,ops[i+1],ops[i+2],ops[i+3],ops[i+4]);c.api=projected;i=i+5
            elseif kind==6 then
                preparedGraph(c,ops[i+1],drawText);i=i+2
            else error("Invalid prepared drawing operation")end
        end
    end
    -- A complete plan is the presentation boundary: publishing a new one in
    -- wakeup replaces all readings/layout/history together. Paint can run
    -- between polling and that publication, including while ETHOS opens focus
    -- or power/telemetry dialogs. Keep presenting the last complete frame then.
    -- A previously unseen viewport projects only its bounded drawing commands;
    -- it never scans history, polls a source or rebuilds layout during paint.
    local function presentedContext(widget,plans,plan,width,height)
        local snapshot=plans.snapshot
        local frame=widget._soarRenderFrame
        if not frame then frame={};widget._soarRenderFrame=frame end
        frame.cfg,frame.data=snapshot.cfg,snapshot.data
        frame.bitmap,frame.bitmapWidth,frame.bitmapHeight=snapshot.bitmap[1],snapshot.bitmapWidth,snapshot.bitmapHeight
        frame.imageError=snapshot.imageError
        frame._soarTextCache,frame._soarRenderContext=widget._soarTextCache,widget._soarRenderContext
        local c=context(frame,width,height)
        widget._soarTextCache,widget._soarRenderContext=frame._soarTextCache,frame._soarRenderContext
        c.transitionX,c.transitionY,c.graphSy,c.actualApi=nil,nil,nil,nil
        if plan.width~=width or plan.height~=height then
            local sx,sy=width/plan.width,height/plan.height
            local actual=c.api
            local projected={}
            for k,v in pairs(actual)do projected[k]=v end
            local xmax,ymax=width-1,height-1
            if actual.drawLine then
                projected.drawLine=function(x1,y1,x2,y2)
                    x1,y1,x2,y2=floor(x1*sx+0.5),floor(y1*sy+0.5),floor(x2*sx+0.5),floor(y2*sy+0.5)
                    if x1<0 then x1=0 elseif x1>xmax then x1=xmax end
                    if x2<0 then x2=0 elseif x2>xmax then x2=xmax end
                    if y1<0 then y1=0 elseif y1>ymax then y1=ymax end
                    if y2<0 then y2=0 elseif y2>ymax then y2=ymax end
                    actual.drawLine(x1,y1,x2,y2)
                end
            end
            if actual.drawFilledRectangle then
                projected.drawFilledRectangle=function(x,y,w,h)
                    local x1,y1=floor(x*sx+0.5),floor(y*sy+0.5)
                    local x2,y2=floor((x+w)*sx+0.5),floor((y+h)*sy+0.5)
                    if x1<0 then x1=0 elseif x1>width then x1=width end
                    if x2<0 then x2=0 elseif x2>width then x2=width end
                    if y1<0 then y1=0 elseif y1>height then y1=height end
                    if y2<0 then y2=0 elseif y2>height then y2=height end
                    if x2>x1 and y2>y1 then actual.drawFilledRectangle(x1,y1,x2-x1,y2-y1)end
                end
            end
            c.api,c.actualApi=projected,actual
            c.transitionX,c.transitionY,c.graphSy=sx,sy,plan.height/480
        end
        return c
    end
    -- Only a cold start without a published frame needs a bounded placeholder.
    -- Once prepared, focus/configuration transitions retain a complete frame.
    local function pendingLine(api,text,y,width,height,tone)
        local tw,th=#text*7,14
        if api.getTextSize then
            local w,h=api.getTextSize(text)
            if finite(w)and finite(h)and w>=0 and h>0 then tw,th=w,h end
        end
        if tw>width-16 or th>height-y then return end
        if api.color then api.color(tone)end
        if api.drawText then api.drawText(8,y,text,LEFT or 0)end
    end
    local function pendingFrame(widget,width,height)
        local cfg=type(widget.cfg)=="table"and widget.cfg or{}
        local p=palette(cfg.style==4 or cfg.daylight==true)
        local api=resolveNative()
        if api.color then api.color(p.bg)end
        if api.drawFilledRectangle then api.drawFilledRectangle(0,0,width,height)end
        if width<16 or height<16 then return end
        if api.font then api.font(FONT_S or FONT_XS or FONT_M or FONT_STD or 0)end
        pendingLine(api,"SoarDeck",8,width,height,p.fg)
        pendingLine(api,"Loading instruments",32,width,height,p.muted)
    end
    function M.paint(widget)
        if type(widget)~="table"then return end
        if widget.destroyed then M.destroy(widget);return end
        local ok,width,height=native("getWindowSize")
        if not ok or not finite(width)or not finite(height)or width<1 or height<1 then return end
        width,height=floor(width),floor(height)
        widget._soarRenderWidth,widget._soarRenderHeight=width,height
        local plans=widget._soarRenderPlans
        local plan=plans and(plans[width.."/"..height]or plans.primary)
        if plan then
            replay(presentedContext(widget,plans,plan,width,height),plan)
        else pendingFrame(widget,width,height)end
    end

    return M
end)()

local DEFAULTS = {
    {"style",1,1,4},{"modelType",1,1,2},{"imageMode",1,1,3},{"imageName",""},
    {"unitMode",1,1,2},{"showAirspeed",false},{"showGroundspeed",false},
    {"altitudeMode",1,1,2},{"derivedVario",false},{"varioScale",5,1,20},
    {"damping",1.5,0,5},{"avgSeconds",20,1,60},{"historyKind",1,1,2},
    {"historySeconds",120,30,300},{"freshSeconds",3,1,10},
    {"chemistry",1,1,4},{"cellCount",6,1,16},{"capacityMah",3300,100,100000},
    {"batteryMethod",1,1,3},{"endDelay",10,3,120},
    {"motorThreshold",0,-2048,2048},{"motorCurrent",2,0.1,100},
    {"heightAlarm",false},{"heightLimit",120,10,10000},{"batteryAlarm",false},
    {"batteryReserve",30,1,90},{"alertInterval",15,5,600},
    {"zeroReady",false},{"zeroOffset",0,-100000,100000},{"preview",false},
    {"timerMode",1,1,2},{"modelName",""},
}
local SOURCE_DEFS = {
    {"altitudeSource","Altitude","altitude"},{"varioSource","VSpeed","vario"},
    {"rxSource","RX voltage","voltage"},{"txSource","TX voltage","voltage"},
    {"rfSource","Link / Rx VFR","rf"},{"airspeedSource","Pitot airspeed","speed"},
    {"groundspeedSource","GPS ground speed","speed"},{"timerSource","ETHOS timer","timer"},
    {"flightSource","Flight active switch","control"},{"motorSource","Motor active switch","control"},
    {"resetSource","Zero altitude switch","control"},{"voltageSource","Motor pack voltage","voltage"},
    {"currentSource","Motor current","current"},{"consumptionSource","Consumed mAh","capacity"},
    {"percentSource","Battery % source","percent"},{"cellMinSource","Lowest cell voltage","voltage"},
}
local IMAGE_CACHE=setmetatable({},{__mode="v"})
local AUDIO_OWNER
local function normalise(cfg)
    for _,d in ipairs(DEFAULTS) do
        local v=cfg[d[1]]
        if type(v)~=type(d[2]) or (type(v)=="number" and not Soar.finite(v)) then v=d[2] end
        if d[3] then v=Soar.clamp(v,d[3],d[4]) end
        if type(v)=="string" then v=v:sub(1,256) end
        cfg[d[1]]=v
    end
    for _,key in ipairs({"style","modelType","imageMode","unitMode","altitudeMode","historyKind","chemistry","cellCount","capacityMah","batteryMethod","timerMode"}) do cfg[key]=math.floor(cfg[key]) end
end
local function resetSamples(w)
    w.filter=nil; w.altSample=nil; w.averageSamples={};w.history={};w.lastHistory=nil
    w.data.vario,w.data.average=nil,nil
end
local function changed(w,kind)
    if not Soar.valid(w) then return end
    normalise(w.cfg);w.generation=w.generation+1;w.nextPoll=0;w.refresh=true
    if kind=="altitude" or kind=="reference" then
        if kind=="altitude" then w.cfg.zeroReady=false end
        w.data.altitude=nil;w.data.maxAltitude=nil;w.data.gain=nil;w.session.startAltitude=nil;resetSamples(w)
    elseif kind=="vario" then resetSamples(w)
    elseif kind=="preview" then
        resetSamples(w);w.batteryState=SoarBattery.new();w.session={flightTime=0,motorTime=0};w.data={};w.lastPoll=nil
    elseif kind=="image" then w.loadedImagePath=nil;w.bitmap=nil end
    Soar.dirty();Soar.invalidate()
end
local function create()
    local key,name=Soar.modelKey()
    local w={cfg={},sources={},data={modelName=name,flightTime=0,motorTime=0},history={},averageSamples={},
        generation=1,configGeneration=0,nextPoll=0,nextImage=0,refresh=true,modelKey=key,
        batteryState=SoarBattery.new(),session={flightTime=0,motorTime=0},alerts={},sourceErrors={}}
    normalise(w.cfg)
    if CATEGORY_SYSTEM and (MAIN_VOLTAGE or SYSTEM_MAIN_VOLTAGE) then
        w.sources.txSource=Soar.selected(Soar.call(system.getSource,{category=CATEGORY_SYSTEM,member=MAIN_VOLTAGE or SYSTEM_MAIN_VOLTAGE}))
    end
    return w
end
local function read(w)
    if not Soar.valid(w) then return end
    local schema=Soar.call(storage.read,"schema")
    if schema~=nil and schema~=1 then w.configError="Unsupported settings version";w.readOnly=true;return end
    for _,d in ipairs(DEFAULTS) do local v=Soar.call(storage.read,d[1]);if v~=nil then w.cfg[d[1]]=v end end
    normalise(w.cfg)
    for _,d in ipairs(SOURCE_DEFS) do local v=Soar.call(storage.read,d[1]);if v~=nil then w.sources[d[1]]=Soar.restore(v) end end
    changed(w,"read")
end
local function write(w)
    if not Soar.valid(w) or w.readOnly then return end
    normalise(w.cfg)
    storage.write("schema",1)
    for _,d in ipairs(DEFAULTS) do storage.write(d[1],w.cfg[d[1]]) end
    for _,d in ipairs(SOURCE_DEFS) do storage.write(d[1],w.sources[d[1]]) end
end
local function imagePath(name)
    if type(name)~="string" then return "" end
    name=name:gsub("\\","/"):gsub("^BITMAPS:/","/bitmaps/")
    if name=="" or name:sub(-1)=="/" or name:find("..",1,true) then return "" end
    if not name:find("/",1,true) and not name:find(":",1,true) then name="/bitmaps/models/"..name end
    return name
end
local function imageDimensions(bytes)
    local function n(at,count,little)
        if type(bytes)~="string" or at+count-1>#bytes then return nil end
        local v=0;for i=0,count-1 do v=v*256+bytes:byte(little and at+count-1-i or at+i) end;return v
    end
    if type(bytes)~="string" then return nil,nil,"Image file unavailable" end
    if bytes:sub(1,8)=="\137PNG\r\n\26\n" and bytes:sub(13,16)=="IHDR" then
        if bytes:byte(25)~=8 or (bytes:byte(26)~=2 and bytes:byte(26)~=6) then return nil,nil,"Use 8-bit RGB/RGBA PNG" end
        return n(17,4),n(21,4)
    elseif bytes:sub(1,2)=="BM" then
        local h=n(23,4,true);if h and h>=2147483648 then return nil,nil,"Use PNG instead of top-down BMP" end
        return n(19,4,true),h
    elseif bytes:sub(1,2)=="\255\216" then
        local at=3
        while at+8<=#bytes do
            if bytes:byte(at)~=255 then break end
            local marker=bytes:byte(at+1)
            if marker==255 then at=at+1
            elseif marker==216 or marker==1 or (marker>=208 and marker<=215) then at=at+2
            else
                local length=n(at+2,2);if not length or length<2 then break end
                if marker>=192 and marker<=207 and marker~=196 and marker~=200 and marker~=204 then return n(at+7,2),n(at+5,2) end
                if marker==218 or marker==217 then break end;at=at+length+2
            end
        end
    end
    return nil,nil,"Unsupported image header"
end
local function updateImage(w,now)
    if now<w.nextImage then return end;w.nextImage=now+1
    local requested=w.cfg.imageMode==1 and Soar.call(model.bitmap) or w.cfg.imageName
    if w.cfg.imageMode==3 then requested="" end
    local path=imagePath(requested)
    if path==w.loadedImagePath then return end
    w.loadedImagePath=path;w.bitmap=nil;w.bitmapWidth=nil;w.bitmapHeight=nil;w.imageError=nil
    if path=="" then return end
    local h=Soar.call(io.open,path,"r");local bytes
    if h then bytes=Soar.call(io.read,h,4096);pcall(io.close,h) end
    local width,height,problem=imageDimensions(bytes)
    if not width or not height or width<1 or height<1 then w.imageError=problem or "Invalid image"
    elseif width>800 or height>480 or width*height>160000 then w.imageError="Image too large: max 160k pixels"
    else
        local usage=Soar.call(system.getMemoryUsage) or {}
        local free=usage.luaBitmapsRamAvailable
        if Soar.finite(free) and free<width*height*4+65536 then w.imageError="Not enough bitmap memory"
        else
            local bitmap=IMAGE_CACHE[path] or Soar.call(lcd.loadBitmap,path,false)
            if bitmap then w.bitmap=bitmap;IMAGE_CACHE[path]=bitmap;w.bitmapWidth=width;w.bitmapHeight=height
            else w.imageError="Image could not be decoded" end
        end
    end
end
local function batteryConfig(w)
    local cfg={};for k,v in pairs(w.cfg) do cfg[k]=v end
    cfg.modelKey=w.modelKey
    for _,key in ipairs({"voltageSource","currentSource","consumptionSource","percentSource"}) do cfg[key]=w.sources[key] end
    return cfg
end
local function groundSafe(w)
    if w.cfg.preview then return false,"Turn off synthetic preview first." end
    local generation=w.generation
    if w.session.manual and not w.sources.flightSource then return false,"End the flight before resetting altitude." end
    if w.sources.flightSource then
        local flight=Soar.sample(w.sources.flightSource,"control",w.cfg.freshSeconds)
        if flight==nil then return false,"Flight switch state is unknown." end
        if flight>0 then return false,"End the flight before resetting altitude." end
    end
    if w.cfg.modelType==2 then
        if w.sources.motorSource then
            local motor=Soar.sample(w.sources.motorSource,"control",w.cfg.freshSeconds)
            if motor==nil then return false,"Motor state is unknown." end
            if motor>w.cfg.motorThreshold then return false,"Stop the motor first." end
        elseif w.sources.currentSource then
            local current=Soar.sample(w.sources.currentSource,"current",w.cfg.freshSeconds)
            if current==nil then return false,"Motor current is unknown." end
            if current>=w.cfg.motorCurrent then return false,"Stop the motor first." end
        end
    end
    if not Soar.valid(w) or w.generation~=generation or Soar.modelKey()~=w.modelKey then return false,"Model or configuration changed." end
    return true
end
local function zeroAltitude(w)
    if not Soar.valid(w) then return false,"Widget unavailable." end
    local safe,problem=groundSafe(w);if not safe then return false,problem end
    local generation=w.generation
    local altitude=Soar.sample(w.sources.altitudeSource,"altitude",w.cfg.freshSeconds)
    if not Soar.valid(w) or w.generation~=generation then return false,"Configuration changed." end
    if not Soar.finite(altitude) then return false,"Select a live altitude source in metres or feet." end
    w.cfg.zeroOffset=altitude;w.cfg.zeroReady=true
    if w.cfg.altitudeMode==1 then
        resetSamples(w)
        w.data.altitude=0;w.data.maxAltitude=0;w.data.gain=0;w.session.startAltitude=0
    end
    changed(w,"zero");return true
end
local function newFlight(w)
    if not Soar.valid(w) then return false,"Widget unavailable." end
    local safe,problem=groundSafe(w);if not safe then return false,problem end
    w.session={flightTime=0,motorTime=0};w.data.flightTime=0;w.data.motorTime=0
    w.data.maxAltitude=nil;w.data.gain=nil;resetSamples(w)
    changed(w,"session");return true
end
local function showMessage(message)
    if form and type(form.openDialog)=="function" then
        form.openDialog({title="SoarDeck",message=message,buttons={{label="OK",action=function() return true end}}})
    end
end
local function confirmAction(w,title,message,action,onCancel)
    if not Soar.valid(w) then return end
    local key,generation=w.modelKey,w.generation
    if type(form.openDialog)~="function" then return end
    form.openDialog({title=title,message=message,buttons={{label="Cancel",action=function()
        if onCancel then onCancel() end
        return true
    end},
        {label="Confirm",action=function()
            local currentKey=Soar.modelKey()
            if not Soar.valid(w) or w.generation~=generation or currentKey~=key then return true end
            local ok,problem=action(w)
            if not ok and Soar.valid(w) then w.actionProblem=problem or "Action could not be completed." end
            Soar.invalidate();return true
        end}}})
end
local function batteryCheckMessage(result, problem)
    result=result or {}
    local explanations={
        ["arm-not-off"]="Stop/disarm the motor before accepting.",
        ["telemetry-lost"]="Battery telemetry is unavailable.",
        ["voltage"]="Select a live motor-battery voltage source.",
        ["current"]="Select a live motor-current source.",
        ["consumption"]="Select a live consumed-mAh source.",
        ["missing"]="Battery voltage, current or consumed mAh is missing.",
        ["configuration"]="Check battery type, cell count and capacity.",
        ["method"]="Select a valid battery measurement method.",
        ["cells"]="Voltage does not match the selected cells/type.",
        ["blocked"]="Voltage and ESC counter disagree by more than 20 pp.",
        ["check-expired"]="Battery check expired; wait for a new check.",
        ["readings-changed"]="Battery readings changed; wait for a new check.",
        ["stale-confirmation"]="Battery check changed; open Accept again.",
        ["setup-changed"]="Battery setup changed; wait for a new check.",
        ["already-accepted"]="This battery counter is already accepted.",
        ["no-reset"]="There is no battery-counter reset to accept.",
        ["preview"]="Turn off synthetic preview before accepting.",
    }
    if problem and explanations[problem] then return explanations[problem] end
    if result.status=="checking" then
        local seconds=Soar.finite(result.checkRemaining) and math.max(0,math.ceil(result.checkRemaining)) or 10
        local limit=Soar.finite(result.currentLimit) and string.format("%.2f",result.currentLimit) or "--"
        local function number(value,format) return Soar.finite(value) and string.format(format,value) or "--" end
        local reason=({["sampling-gap"]="sampling gap",["clock-backwards"]="clock changed",
            ["pack-reconnected"]="pack reconnected",["setup-changed"]="setup changed",
            voltage="voltage missing",current="current missing",consumption="mAh missing",
            load="current too high",unstable="voltage changed",["counter-reset"]="counter decreased",
            ["check-expired"]="check expired",["readings-changed"]="readings changed",recheck="new check"})[result.checkRestartReason]
        local message="Checking pack: "..seconds.." s left.\n10 s at <= "..limit.." A; voltage span <= 0.20 V.\nNow: "
            ..number(result.voltage,"%.2f").." V / "..number(result.current,"%.2f").." A / "..number(result.consumed,"%.0f").." mAh."
        if reason then message=message.."\nRestart: "..reason.." ("..(result.checkRestarts or 0)..")." end
        return message
    end
    if result.status=="blocked" then return explanations.blocked end
    if result.status=="manual" and not result.canAccept then return explanations["arm-not-off"] end
    return explanations[result.reason] or explanations[result.status] or "Wait for the battery check; keep the motor off."
end
local function sampleBatteryForAction(current)
        local generation=current.generation
        local sources=current.sources
        local r={}
        for _,entry in ipairs({{"voltage","voltageSource","voltage"},{"current","currentSource","current"},
            {"consumed","consumptionSource","capacity"},{"percent","percentSource","percent"},{"cellMin","cellMinSource","voltage"}}) do
            r[entry[1]]=Soar.sample(sources[entry[2]],entry[3],current.cfg.freshSeconds)
            if not Soar.valid(current) or current.generation~=generation then return false,"Configuration changed." end
        end
        r.live=r.voltage~=nil or r.consumed~=nil or r.percent~=nil
        if sources.motorSource then
            local motor=Soar.sample(sources.motorSource,"control",current.cfg.freshSeconds)
            r.armOff=motor~=nil and motor<=current.cfg.motorThreshold
        else r.armOff=r.current~=nil and r.current<current.cfg.motorCurrent end
        if not Soar.valid(current) or current.generation~=generation or Soar.modelKey()~=current.modelKey then return false,"Model or configuration changed." end
        return r
end
local function acceptBattery(w)
    if not Soar.valid(w) or w.cfg.preview then return end
    local readings,problem=sampleBatteryForAction(w)
    if not readings then showMessage(problem);return end
    local result=SoarBattery.resumeFromMenu(w.batteryState,batteryConfig(w),readings,Soar.now())
    w.data.battery=result
    if not result.canAccept then showMessage(batteryCheckMessage(result));return end
    local ticket=result.ticket
    local state=w.batteryState
    SoarBattery.holdForConfirmation(state,batteryConfig(w),Soar.now(),ticket)
    confirmAction(w,"Accept battery?","Check actual charge, capacity and consumed mAh.",function(current)
        local r,problem=sampleBatteryForAction(current)
        if not r then return false,problem end
        local ok,problem,checked=SoarBattery.confirm(current.batteryState,batteryConfig(current),r,Soar.now(),ticket)
        if not ok then return false,batteryCheckMessage(checked,problem) end
        return true
    end,function() SoarBattery.cancelConfirmation(state,ticket) end)
end
local function poll(w,now)
    local generation=w.generation
    local key,name=Soar.modelKey()
    if not Soar.valid(w) then return end
    if key~=w.modelKey then
        -- A reused callback must not carry another model's source selections/session.
        w.modelKey=key;w.sources={};w.cfg={};normalise(w.cfg)
        w.batteryState=SoarBattery.new();w.session={flightTime=0,motorTime=0};resetSamples(w)
        w.data={modelName=name};w.generation=w.generation+1;return
    end
    local values,errors,units={},{},{}
    for _,d in ipairs(SOURCE_DEFS) do
        values[d[1]],errors[d[1]],units[d[1]]=Soar.sample(w.sources[d[1]],d[3],w.cfg.freshSeconds)
        if not Soar.valid(w) or w.generation~=generation then return end
    end
    local dt=w.lastPoll and now-w.lastPoll or 0
    if dt<0 or dt>w.cfg.freshSeconds then
        if dt<0 then w.history={};w.lastHistory=nil
        elseif w.lastPoll then
            local gapTime=w.lastPoll+math.min(1,dt/2)
            w.history[#w.history+1]={x=gapTime,time=gapTime,valid=false,motor=false}
        end
        dt=0;w.altSample=nil;w.filter=nil;w.averageSamples={}
    end
    w.lastPoll=now
    local cfg=w.cfg
    local rawAltitude=values.altitudeSource
    local rawVario=values.varioSource
    if cfg.derivedVario then
        rawVario=nil
        local previous=w.altSample
        if rawAltitude and previous and now>previous.time and now-previous.time<=cfg.freshSeconds then
            local slope=(rawAltitude-previous.altitude)/(now-previous.time)
            if Soar.finite(slope) and math.abs(slope)<=100 then rawVario=slope end
        end
        w.altSample=rawAltitude and {altitude=rawAltitude,time=now} or nil
    else w.altSample=nil end
    if rawVario then
        local alpha=cfg.damping<=0 and 1 or (dt>0 and dt/(cfg.damping+dt) or 1)
        w.filter=w.filter and w.filter+(rawVario-w.filter)*alpha or rawVario
    else w.filter=nil end
    local data={modelName=cfg.modelName~="" and cfg.modelName or name,live=rawAltitude~=nil or rawVario~=nil,
        rawAltitude=rawAltitude,vario=w.filter,derived=cfg.derivedVario,preview=false,
        rxVoltage=values.rxSource,txVoltage=values.txSource,rf=values.rfSource,
        rfUnit=units.rfSource==UNIT_PERCENT and "%" or "dB",airspeed=values.airspeedSource,groundspeed=values.groundspeedSource,
        maxAltitude=w.data.maxAltitude,gain=w.data.gain,audioMode="ETHOS"}
    if rawAltitude~=nil and (cfg.altitudeMode==2 or cfg.zeroReady) then
        data.altitude=rawAltitude-(cfg.altitudeMode==1 and cfg.zeroOffset or 0)
        data.maxAltitude=math.max(data.maxAltitude or data.altitude,data.altitude)
        if not w.session.startAltitude then w.session.startAltitude=data.altitude end
        data.gain=data.altitude-w.session.startAltitude
    end
    data.altitudeLabel=cfg.altitudeMode==1 and "ALT REL" or "ALT SENSOR"
    if rawAltitude and cfg.altitudeMode==1 and not cfg.zeroReady then data.message="ZERO ALTITUDE BEFORE FLIGHT" end
    local motor=values.motorSource
    data.motorKnown=cfg.modelType==1 or motor~=nil or (not w.sources.motorSource and values.currentSource~=nil)
    data.motorActive=cfg.modelType==2 and ((motor~=nil and motor>cfg.motorThreshold)
        or (not w.sources.motorSource and values.currentSource~=nil and values.currentSource>=cfg.motorCurrent)) or false
    local flight=values.flightSource
    data.flightKnown=not w.sources.flightSource or flight~=nil
    local active=w.sources.flightSource and flight~=nil and flight>0 or (not w.sources.flightSource and w.session.manual==true)
    w.session.active=active
    if active and data.live and dt>0 then w.session.flightTime=w.session.flightTime+dt end
    if active and data.live and data.motorActive and dt>0 then w.session.motorTime=w.session.motorTime+dt end
    data.flightTime=cfg.timerMode==2 and values.timerSource or w.session.flightTime
    data.motorTime=w.session.motorTime
    local avg=w.averageSamples
    if data.vario then avg[#avg+1]={time=now,value=data.vario} else avg={};w.averageSamples=avg end
    while #avg>0 and (now-avg[1].time>cfg.avgSeconds or #avg>601) do table.remove(avg,1) end
    -- Time-weighted integration, no averaging across a telemetry gap.
    local integral,duration=0,0
    for i=2,#avg do local span=avg[i].time-avg[i-1].time;if span>0 and span<=cfg.freshSeconds then integral=integral+(avg[i].value+avg[i-1].value)*0.5*span;duration=duration+span end end
    if duration>0 then data.average=integral/duration end
    if not w.lastHistory or now<w.lastHistory or now-w.lastHistory>=1 then
        w.history[#w.history+1]={x=now,time=now,altitude=data.altitude,vario=data.vario,motor=data.motorActive,valid=data.live}
        w.lastHistory=now
    end
    while #w.history>301 or (#w.history>0 and now-w.history[1].x>300) do table.remove(w.history,1) end
    if cfg.modelType==2 then
        local readings={voltage=values.voltageSource,current=values.currentSource,consumed=values.consumptionSource,
            percent=values.percentSource,cellMin=values.cellMinSource,live=values.voltageSource~=nil or values.consumptionSource~=nil or values.percentSource~=nil,
            armOff=data.motorKnown and not data.motorActive}
        w.batteryReadings=readings
        data.battery=SoarBattery.update(w.batteryState,batteryConfig(w),readings,now)
    else data.battery={status="not-fitted"};w.batteryReadings=nil end
    if not Soar.valid(w) or w.generation~=generation then return end
    w.data=data;w.sourceErrors=errors
    local reset=values.resetSource
    if reset~=nil then
        if reset>0 and w.resetWasOff==true then zeroAltitude(w) end
        w.resetWasOff=reset<=0
    else w.resetWasOff=nil end
end
local function preview(w,now)
    local phase=now%60
    w.data={modelName=w.cfg.modelName~="" and w.cfg.modelName or "Duo Discus",altitude=312,vario=1.8,average=1.2,
        maxAltitude=428,gain=82,flightTime=522,motorTime=48,motorActive=false,motorKnown=true,
        rxVoltage=7.6,txVoltage=7.9,rf=98,rfUnit="%",airspeed=w.cfg.showAirspeed and 64 or nil,
        groundspeed=w.cfg.showGroundspeed and 58 or nil,live=true,derived=w.cfg.derivedVario,preview=true,audioMode="OFF",
        altitudeLabel="ALT REL",battery={percent=68,remaining=2244,consumed=1056,voltage=22.8,current=0,cellMin=3.78,
            method=w.cfg.batteryMethod,status=w.cfg.batteryMethod==3 and "estimate" or "accepted",valid=true}}
    if #w.history==0 then
        for i=0,120 do local t=now-120+i;w.history[#w.history+1]={x=t,time=t,altitude=150+i*1.35+12*math.sin(i/14),vario=1.2+0.7*math.sin(i/7),motor=i>15 and i<35,valid=true} end
    end
    w.lastPoll=now
end
local function alarms(w,now)
    if w.cfg.preview then return end
    if AUDIO_OWNER and (not Soar.valid(AUDIO_OWNER) or now<(AUDIO_OWNER.audioOwnerAt or 0)
        or now>=(AUDIO_OWNER.audioUntil or 0)) then AUDIO_OWNER=nil end
    if AUDIO_OWNER and AUDIO_OWNER~=w then return end
    local battery=w.data.battery or {}
    local candidates={
        {key="height",enabled=w.cfg.heightAlarm,value=w.data.altitude,threshold=w.cfg.heightLimit,high=true,tone=1700},
        {key="battery",enabled=w.cfg.modelType==2 and w.cfg.batteryAlarm,value=battery.percent,threshold=w.cfg.batteryReserve,tone=1100},
    }
    for _,a in ipairs(candidates) do
        local value=a.value
        local state=w.alerts[a.key] or {};w.alerts[a.key]=state
        if Soar.finite(value) then
            local crossed=a.high and value>=a.threshold or (not a.high and value<=a.threshold)
            if crossed then state.active=true
            elseif (a.high and value<a.threshold-2) or (not a.high and value>a.threshold+2) then state.active=false end
            if a.enabled and crossed and now>=(state.nextDue or 0) and now>=(w.audioUntil or 0) then
                -- One short queued warning; native ETHOS remains the vario audio engine.
                if type(system.playTone)=="function" then
                    local ok=pcall(system.playTone,a.tone,180,0)
                    if ok then
                        state.nextDue=now+w.cfg.alertInterval;w.audioUntil=now+0.7
                        -- Share only the actual tone's cooldown. An idle/disabled
                        -- instance must not reserve audio on every wakeup.
                        AUDIO_OWNER=w;w.audioOwnerAt=now
                    end
                end
            end
        end
    end
end
local function wakeup(w)
    if not Soar.valid(w) then return end
    local now=Soar.now()
    if now<w.nextPoll and (not w.lastClock or now>=w.lastClock) then return end
    w.lastClock=now;w.nextPoll=now+0.1
    if w.cfg.preview then preview(w,now) else poll(w,now) end
    if not Soar.valid(w) then return end
    updateImage(w,now);alarms(w,now)
    if type(SoarRender.prepare)=="function" then SoarRender.prepare(w) end
    if w.actionProblem then local problem=w.actionProblem;w.actionProblem=nil;showMessage(problem) end
    local visible=Soar.call(lcd.isVisible)
    if visible~=false and (not w.lastRedraw or now<w.lastRedraw or now-w.lastRedraw>=0.2 or w.refresh) then
        w.lastRedraw=now;w.refresh=false;Soar.invalidate()
    end
end
local function paint(w)
    if not Soar.valid(w) then return end
    SoarRender.paint(w)
end
local function configure(w)
    if not Soar.valid(w) then return end
    SoarBattery.holdForMenu(w.batteryState,batteryConfig(w),Soar.now())
    w.configGeneration=w.configGeneration+1
    local formGeneration=w.configGeneration
    local function current() return Soar.valid(w) and w.configGeneration==formGeneration and not w.readOnly end
    local panel
    local bindings={}
    local function refresh()
        for _,b in ipairs(bindings) do if current() and b.field and type(b.field.enable)=="function" then b.field:enable(b.enabled()) end end
    end
    local function group(label)
        if type(form.addExpansionPanel)=="function" then panel=form.addExpansionPanel(label);if panel and type(panel.open)=="function" then panel:open(false) end end
    end
    local function line(label) return form.addLine(label,panel) end
    local function note(message)
        if type(form.addStaticText)=="function" then local width=Soar.call(form.width) or 800;form.addStaticText(line(""),{x=10,y=0,w=math.max(30,width-20),h=30},message) end
    end
    local function bind(field,enabled) if enabled then bindings[#bindings+1]={field=field,enabled=enabled} end;return field end
    local function choose(label,key,choices,kind,enabled)
        -- Native choice IDs are integers, even when the engineering value is 2.5.
        local nativeChoices={};for index,choice in ipairs(choices) do nativeChoices[index]={choice[1],index} end
        return bind(form.addChoiceField(line(label),nil,nativeChoices,function()
            for index,choice in ipairs(choices) do if choice[2]==w.cfg[key] then return index end end
            return 1
        end,function(index)
            if current() and choices[index] and (not enabled or enabled()) then w.cfg[key]=choices[index][2];changed(w,kind);refresh() end
        end),enabled)
    end
    local function number(label,key,minimum,maximum,suffix,step,kind,enabled)
        local scale=(minimum%1~=0 or maximum%1~=0 or (step and step%1~=0)) and 10 or 1
        local function rounded(n) return math.floor(n*scale+0.5) end
        local f=form.addNumberField(line(label),nil,rounded(minimum),rounded(maximum),function() return rounded(w.cfg[key]) end,function(v) if current() and (not enabled or enabled()) then w.cfg[key]=v/scale;changed(w,kind) end end)
        if suffix and f and type(f.suffix)=="function" then f:suffix(suffix) end
        if step and f and type(f.step)=="function" then f:step(rounded(step)) end
        if scale==10 and f and type(f.decimals)=="function" then f:decimals(1) end
        return bind(f,enabled)
    end
    local function boolean(label,key,kind)
        return form.addBooleanField(line(label),nil,function() return w.cfg[key] end,function(v) if current() then w.cfg[key]=v;changed(w,kind);refresh() end end)
    end
    local function source(key,label,kind,enabled)
        return bind(form.addSourceField(line(label),nil,function() return w.sources[key] end,function(v)
            if current() and (not enabled or enabled()) then
                w.sources[key]=Soar.selected(v)
                if not current() then return end
                changed(w,kind);refresh()
            end
        end),enabled)
    end
    local function button(label,text,action)
        form.addButton(line(label),nil,{text=text,press=function() if current() then action() end end})
    end
    form.addLine("SoarDeck "..VERSION)
    if w.configError then note(w.configError);return end
    group("Model / appearance")
    choose("Model type","modelType",{{"Sailplane",1},{"Motor glider",2}})
    choose("Display style","style",{{"Deck",1},{"Classic",2},{"Thermal",3},{"Daylight",4}})
    choose("Units","unitMode",{{"Metric",1},{"Imperial",2}})
    choose("Model image","imageMode",{{"Selected model",1},{"Image file",2},{"Hidden",3}},"image")
    if type(form.addFileField)=="function" then
        bind(form.addFileField(line("Image file"),nil,"/bitmaps/models","image+ext",function() return w.cfg.imageName end,function(v) if current() then w.cfg.imageName=type(v)=="string" and v or "";changed(w,"image") end end),function() return w.cfg.imageMode==2 end)
    end
    group("Altitude / vario")
    source("altitudeSource","Altitude source","altitude")
    source("varioSource","VSpeed source","vario",function() return not w.cfg.derivedVario end)
    boolean("Derive vario from alt","derivedVario","vario")
    choose("Altitude reference","altitudeMode",{{"Relative to zero",1},{"Sensor altitude",2}},"reference")
    button("Zero altitude","Zero...",function() confirmAction(w,"Zero altitude?","Set the current altitude as launch reference on the ground.",zeroAltitude) end)
    source("resetSource","Zero altitude switch")
    choose("Vario scale","varioScale",{{"+/- 2.5 m/s",2.5},{"+/- 5 m/s",5},{"+/- 10 m/s",10}})
    choose("Display damping","damping",{{"Fast (0.5 s)",0.5},{"Normal (1.5 s)",1.5},{"Calm (3 s)",3}},"vario")
    choose("Average period","avgSeconds",{{"5 seconds",5},{"10 seconds",10},{"20 seconds",20},{"30 seconds",30}},"vario")
    number("Data timeout","freshSeconds",1,10,"s",1)
    group("History / extra fields")
    choose("History plot","historyKind",{{"Altitude",1},{"Vario",2}})
    choose("History window","historySeconds",{{"30 seconds",30},{"60 seconds",60},{"2 minutes",120},{"5 minutes",300}})
    source("airspeedSource","Pitot airspeed")
    boolean("Show pitot airspeed","showAirspeed")
    source("groundspeedSource","GPS ground speed")
    boolean("Show GPS ground speed","showGroundspeed")
    note("GPS ground speed is not pitot airspeed.")
    group("RX / link")
    source("rxSource","RX voltage");source("txSource","TX voltage");source("rfSource","Link / Rx VFR")
    group("Motor battery")
    local function motor() return w.cfg.modelType==2 end
    choose("Remaining from","batteryMethod",{{"Consumed mAh",1},{"Percent sensor",2},{"Voltage estimate",3}},nil,motor)
    choose("Chemistry","chemistry",{{"LiPo",1},{"LiHV",2},{"Li-ion",3},{"LiFe",4}},nil,motor)
    number("Capacity","capacityMah",100,100000,"mAh",50,nil,motor)
    number("Cells","cellCount",1,16,nil,1,nil,motor)
    source("voltageSource","Pack voltage",nil,motor)
    source("currentSource","Current",nil,motor)
    source("consumptionSource","Consumed mAh",nil,function() return motor() and w.cfg.batteryMethod==1 end)
    source("percentSource","Percent source",nil,function() return motor() and w.cfg.batteryMethod==2 end)
    source("cellMinSource","Lowest cell voltage",nil,motor)
    button("Battery counter","Accept...",function() if motor() then acceptBattery(w) end end)
    note("Voltage estimate is approximate. Check a new battery.")
    group("Flight / motor")
    choose("Flight timer from","timerMode",{{"Flight switch / manual",1},{"ETHOS timer",2}})
    source("timerSource","ETHOS timer",nil,function() return w.cfg.timerMode==2 end)
    source("flightSource","Flight active switch")
    source("motorSource","Motor active switch",nil,motor)
    number("Motor ON above","motorThreshold",-2048,2048,nil,1,nil,motor)
    number("Motor current gate","motorCurrent",0.1,100,"A",0.1,nil,motor)
    number("Pack loss delay","endDelay",3,120,"s",1)
    button("New flight","Reset...",function() confirmAction(w,"New flight?","Clear flight/motor timers, peaks and plot. Battery consumption is kept.",newFlight) end)
    note("Motor OFF does not end a sailplane flight.")
    group("Audio / alerts")
    note("ETHOS Special functions: Play vario -> VSpeed.")
    note("Choose the same VSpeed source. Set a switch and silent centre.")
    note("Native vario audio runs independently of this screen.")
    boolean("Height alert","heightAlarm")
    number("Height limit","heightLimit",10,10000,"m",10)
    boolean("Low motor battery","batteryAlarm")
    number("Battery reserve","batteryReserve",1,90,"%",1)
    number("Alert repeat","alertInterval",5,600,"s",1)
    group("Preview")
    boolean("Synthetic preview","preview","preview")
    note("Preview has no alarms, flight counting or real battery acceptance.")
    refresh()
end
local function menu(w)
    if not Soar.valid(w) then return {} end
    SoarBattery.holdForMenu(w.batteryState,batteryConfig(w),Soar.now())
    return {
        {"Zero altitude...",function() confirmAction(w,"Zero altitude?","Set launch reference while on the ground.",zeroAltitude) end},
        {w.session.manual and "End flight" or "Start flight",function()
            if not Soar.valid(w) or w.cfg.preview or w.sources.flightSource then return end
            w.session.manual=not w.session.manual;w.session.active=w.session.manual;w.lastPoll=Soar.now()
            Soar.invalidate()
        end},
        {"New flight...",function() confirmAction(w,"New flight?","Clear flight/motor timers and plot; keep battery consumption.",newFlight) end},
        {"Accept battery...",function() acceptBattery(w) end},
    }
end
local function destroy(w)
    if not Soar.valid(w) then return end
    if AUDIO_OWNER==w then AUDIO_OWNER=nil end
    w.destroyed=true
    SoarRender.destroy(w)
    w.bitmap=nil;w.history={};w.averageSamples={};w.batteryState=nil
    w.configGeneration=w.configGeneration+1
end
local function event(w) if not Soar.valid(w) then return false end;return false end
local function init()
    system.registerWidget({key="SoarDk",name="SoarDeck",create=create,read=read,write=write,
        configure=configure,wakeup=wakeup,paint=paint,menu=menu,event=event,destroy=destroy,persistent=true,title=false})
end
return {init=init}
