-------------------------------------------------
-- CPU frequency widget for Awesome Window Manager
-- Shows average, min and max frequency across all cores,
-- read from /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq.
-- Turns red when every core is stuck at the minimum (firmware throttling).
-------------------------------------------------

local gears = require("gears")
local wibox = require("wibox")

local CPU_DIR = "/sys/devices/system/cpu/"

local function list_freq_files()
    local files = {}
    local i = 0
    while true do
        local path = CPU_DIR .. "cpu" .. i .. "/cpufreq/scaling_cur_freq"
        local f = io.open(path, "r")
        if not f then break end
        f:close()
        table.insert(files, path)
        i = i + 1
    end
    return files
end

local function read_khz(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local v = tonumber(f:read("*l"))
    f:close()
    return v
end

local function read_min_khz()
    return read_khz(CPU_DIR .. "cpu0/cpufreq/cpuinfo_min_freq") or 0
end

local function ghz(khz)
    return string.format("%.1f", khz / 1e6)
end

local widgets = {}
local timer

local function update(files, min_khz)
    local sum, n, lo, hi = 0, 0, math.huge, 0
    for _, path in ipairs(files) do
        local v = read_khz(path)
        if v then
            sum = sum + v
            n = n + 1
            if v < lo then lo = v end
            if v > hi then hi = v end
        end
    end
    if n == 0 then return end

    local text = string.format(" %s GHz (%s–%s) ", ghz(sum / n), ghz(lo), ghz(hi))
    -- Every core pinned at the hardware minimum: almost certainly throttled.
    if hi <= min_khz * 1.05 then
        text = '<span foreground="#ff5555">' .. text .. '</span>'
    end
    for _, w in ipairs(widgets) do
        w:set_markup(text)
    end
end

local function worker(user_args)
    local args = user_args or {}
    local timeout = args.timeout or 2

    local w = wibox.widget {
        widget = wibox.widget.textbox,
        markup = " -- GHz ",
    }
    table.insert(widgets, w)

    -- One shared timer feeds every instance (one per screen).
    if not timer then
        local files = list_freq_files()
        local min_khz = read_min_khz()
        timer = gears.timer {
            timeout = timeout,
            autostart = true,
            call_now = true,
            callback = function() update(files, min_khz) end,
        }
    else
        timer:emit_signal("timeout")
    end

    return w
end

return setmetatable({}, { __call = function(_, ...) return worker(...) end })
