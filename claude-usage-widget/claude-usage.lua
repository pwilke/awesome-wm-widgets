local awful = require("awful")
local gears = require("gears")
local naughty = require("naughty")
local wibox = require("wibox")

local usage = wibox.widget {
    text = "Claude …",
    widget = wibox.widget.textbox,
}

local widget = wibox.widget {
    {
        {
            image = awful.util.get_configuration_dir() .. "awesome-wm-widgets/claude-usage-widget/claude.svg",
            resize = true,
            forced_width = 14,
            forced_height = 14,
            widget = wibox.widget.imagebox,
        },
        valign = "center",
        widget = wibox.container.place,
    },
    usage,
    spacing = 4,
    layout = wibox.layout.fixed.horizontal,
}

local function color_for(remaining)
    if remaining == "--" then return "#888888" end
    local value = tonumber(remaining) or 0
    if value < 20 then return "#fb4934" end
    if value < 50 then return "#fabd2f" end
    return "#b8bb26"
end

local function window_markup(label, remaining)
    local color = color_for(remaining)
    return string.format(
        '<span foreground="#a89984">%s</span> <span foreground="%s" weight="bold">%s%%</span>',
        label,
        color,
        remaining
    )
end

local tooltip = awful.tooltip {
    objects = { widget },
    text = "Loading Claude usage…",
}

local function refresh(show_debug)
    awful.spawn.easy_async({
        "python3",
        awful.util.get_configuration_dir() .. "awesome-wm-widgets/claude-usage-widget/claude-usage.py",
    }, function(stdout, stderr, reason, exit_code)
        local five_hour, five_reset, weekly, weekly_reset, age = stdout:match("([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\r\n]*)")
        if five_hour and weekly then
            usage:set_markup(window_markup("5h", five_hour) .. '  <span foreground="#665c54">│</span>  ' .. window_markup("wk", weekly))
            tooltip:set_text(string.format(
                "Claude\n5-hour limit: %s%% remaining · resets %s\nWeekly limit: %s%% remaining · resets %s\nUpdated %s (from Claude Code statusline)",
                five_hour, five_reset, weekly, weekly_reset, age
            ))
        else
            local error_text = stdout:gsub("[%s\r\n]+$", "")
            usage:set_markup('<span foreground="#fb4934">Claude usage unavailable</span>')
            tooltip:set_text(error_text ~= "" and error_text or "Claude usage unavailable")
        end

        if show_debug then
            local raw = string.format(
                "stdout:\n%s\nstderr:\n%s\nprocess: %s, exit code: %s",
                stdout ~= "" and stdout or "(empty)",
                stderr ~= "" and stderr or "(empty)",
                tostring(reason),
                tostring(exit_code)
            )
            naughty.notify({
                title = "Claude usage refresh",
                text = raw,
                timeout = 0,
                width = 500,
            })
        end
    end)
end

widget:buttons(gears.table.join(
    awful.button({}, 1, function()
        refresh(true)
    end)
))

gears.timer {
    timeout = 60,
    call_now = true,
    autostart = true,
    callback = function()
        refresh(false)
    end,
}

--usage:connect_signal("mouse::enter", function()
--    usage:set_text("Claude usage: 5h and weekly remaining")
--end)

--usage:connect_signal("mouse::leave", function()
--    refresh()
--end)

return widget
