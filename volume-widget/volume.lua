-------------------------------------------------
-- The Ultimate Volume Widget for Awesome Window Manager
-- More details could be found here:
-- https://github.com/streetturtle/awesome-wm-widgets/tree/master/volume-widget

-- @author Pavel Makhov
-- @copyright 2020 Pavel Makhov
-------------------------------------------------

local awful = require("awful")
local wibox = require("wibox")
local spawn = require("awful.spawn")
local gears = require("gears")
local beautiful = require("beautiful")
local watch = require("awful.widget.watch")
local utils = require("awesome-wm-widgets.volume-widget.utils")

local LIST_DEVICES_CMD = {
	"python3",
	awful.util.get_configuration_dir() .. "awesome-wm-widgets/volume-widget/list-devices.py",
}
local function GET_VOLUME_CMD(card, device, mixctrl, value_type)
	return "amixer -c " .. card .. " -D " .. device .. " sget " .. mixctrl .. " " .. value_type
end
local function INC_VOLUME_CMD(card, device, mixctrl, value_type, step)
	return "amixer -c "
		.. card
		.. " -D "
		.. device
		.. " sset "
		.. mixctrl
		.. " "
		.. value_type
		.. " "
		.. step
		.. "%+"
end -- luacheck: ignore
local function DEC_VOLUME_CMD(card, device, mixctrl, value_type, step)
	return "amixer -c "
		.. card
		.. " -D "
		.. device
		.. " sset "
		.. mixctrl
		.. " "
		.. value_type
		.. " "
		.. step
		.. "%-"
end -- luacheck: ignore
local function TOG_VOLUME_CMD(card, device, mixctrl)
	return "amixer -c " .. card .. " -D " .. device .. " sset " .. mixctrl .. " toggle"
end -- luacheck: ignore

local widget_types = {
	icon_and_text = require("awesome-wm-widgets.volume-widget.widgets.icon-and-text-widget"),
	icon = require("awesome-wm-widgets.volume-widget.widgets.icon-widget"),
	arc = require("awesome-wm-widgets.volume-widget.widgets.arc-widget"),
	horizontal_bar = require("awesome-wm-widgets.volume-widget.widgets.horizontal-bar-widget"),
	vertical_bar = require("awesome-wm-widgets.volume-widget.widgets.vertical-bar-widget"),
}
local volume = {}

local rows = { layout = wibox.layout.fixed.vertical }
local volume_step = 5

local popup = awful.popup({
	bg = beautiful.bg_normal,
	fg = beautiful.fg_normal,
	ontop = true,
	visible = false,
	shape = gears.shape.rounded_rect,
	border_width = 1,
	border_color = beautiful.bg_focus,
	maximum_width = 350,
	offset = { y = 5 },
	widget = {},
})

local function dismiss_popup()
	if popup.visible then
		popup.visible = false
	end
end

if awful.mouse.append_global_mousebinding then
	awful.mouse.append_global_mousebinding(awful.button({}, 1, dismiss_popup))
end
if awful.mouse.append_client_mousebinding then
	awful.mouse.append_client_mousebinding(awful.button({}, 1, dismiss_popup))
else
	client.connect_signal("button::press", dismiss_popup)
end

local bound_wiboxes = setmetatable({}, { __mode = "k" })
local function bind_wibox_dismissal()
	local wb = mouse.current_wibox
	if wb and wb ~= popup and not bound_wiboxes[wb] then
		wb:buttons(gears.table.join(wb:buttons(), awful.button({}, 1, dismiss_popup)))
		bound_wiboxes[wb] = true
	end
end

local function build_main_line(device)
	if device.active_port ~= nil and device.ports and device.ports[device.active_port] ~= nil then
		return device.properties.device_description .. " · " .. device.ports[device.active_port]
	else
		return device.properties.device_description or device.name
	end
end

local function build_rows(devices, on_checkbox_click, device_type, wheel_step)
	local device_rows = { layout = wibox.layout.fixed.vertical }
	for _, device in pairs(devices) do
		local checkbox = wibox.widget({
			checked = device.is_default,
			color = beautiful.fg_normal,
			paddings = 2,
			shape = gears.shape.circle,
			forced_width = 20,
			forced_height = 20,
			check_color = beautiful.fg_normal,
			widget = wibox.widget.checkbox,
		})

		checkbox:connect_signal("button::press", function()
			spawn.easy_async(
				{ "pactl", "set-default-" .. device_type, device.name },
				function()
					on_checkbox_click()
				end
			)
		end)

		local current_volume = math.max(0, math.min(150, device.volume or 0))
		local volume_text = wibox.widget {
			text = string.format("%d%%", current_volume),
			align = "right",
			forced_width = 34,
			widget = wibox.widget.textbox,
		}
		local volume_slider = wibox.widget {
			value = current_volume,
			minimum = 0,
			maximum = 150,
			forced_width = 95,
			forced_height = 18,
			bar_height = 3,
			handle_width = 8,
			widget = wibox.widget.slider,
		}
		local volume_update_timer
		volume_slider:connect_signal("property::value", function()
			local percent = math.floor(volume_slider:get_value() + 0.5)
			volume_text:set_text(string.format("%d%%", percent))
			if volume_update_timer then
				volume_update_timer:stop()
			end
			volume_update_timer = gears.timer.start_new(0.12, function()
				spawn.easy_async({
					"pactl",
					"set-" .. device_type .. "-volume",
					device.name,
					percent .. "%",
				}, function() end)
				volume_update_timer = nil
				return false
			end)
		end)

		local row = wibox.widget({
			{
				{
					{
						checkbox,
						valign = "center",
						layout = wibox.container.place,
					},
					{
						{
							text = build_main_line(device),
							align = "left",
							forced_width = 150,
							widget = wibox.widget.textbox,
						},
						left = 10,
						layout = wibox.container.margin,
					},
					volume_slider,
					volume_text,
					spacing = 8,
					layout = wibox.layout.fixed.horizontal,
				},
				margins = 4,
				layout = wibox.container.margin,
			},
			bg = beautiful.bg_normal,
			fg = beautiful.fg_normal,
			widget = wibox.container.background,
		})

		row:connect_signal("mouse::enter", function(c)
			checkbox:set_color(beautiful.fg_focus)
			checkbox:set_check_color(beautiful.fg_focus)
			c:set_fg(beautiful.fg_focus)
			c:set_bg(beautiful.bg_focus)
		end)
		row:connect_signal("mouse::leave", function(c)
			checkbox:set_color(beautiful.fg_normal)
			checkbox:set_check_color(beautiful.fg_normal)
			c:set_fg(beautiful.fg_normal)
			c:set_bg(beautiful.bg_normal)
		end)

		local old_cursor, old_wibox
		row:connect_signal("mouse::enter", function()
			local wb = mouse.current_wibox
			old_cursor, old_wibox = wb.cursor, wb
			wb.cursor = "hand1"
		end)
		row:connect_signal("mouse::leave", function()
			if old_wibox then
				old_wibox.cursor = old_cursor
				old_wibox = nil
			end
		end)

		row:buttons(awful.util.table.join(
			awful.button({}, 4, function()
				spawn.easy_async({
					"pactl",
					"set-" .. device_type .. "-volume",
					device.name,
					"+" .. wheel_step .. "%",
				}, function(_, _, _, exit_code)
					if exit_code == 0 then on_checkbox_click() end
				end)
			end),
			awful.button({}, 5, function()
				spawn.easy_async({
					"pactl",
					"set-" .. device_type .. "-volume",
					device.name,
					"-" .. wheel_step .. "%",
				}, function(_, _, _, exit_code)
					if exit_code == 0 then on_checkbox_click() end
				end)
			end)
		))

		table.insert(device_rows, row)
	end

	return device_rows
end

local function build_header_row(text)
	return wibox.widget({
		{
			markup = "<b>" .. text .. "</b>",
			align = "center",
			widget = wibox.widget.textbox,
		},
		bg = beautiful.bg_normal,
		fg = beautiful.fg_normal,
		widget = wibox.container.background,
	})
end

local function rebuild_popup()
	spawn.easy_async(LIST_DEVICES_CMD, function(stdout)
		local sinks, sources = utils.extract_sinks_and_sources(stdout)

		for i = 0, #rows do
			rows[i] = nil
		end

		table.insert(rows, build_header_row("SINKS"))
		table.insert(
			rows,
			build_rows(sinks, function()
				rebuild_popup()
			end, "sink", volume_step)
		)
		table.insert(rows, build_header_row("SOURCES"))
		table.insert(
			rows,
			build_rows(sources, function()
				rebuild_popup()
			end, "source", volume_step)
		)

		popup:setup(rows)
	end)
end

local function worker(user_args)
	local args = user_args or {}

	local mixer_cmd = args.mixer_cmd or "pavucontrol"
	local widget_type = args.widget_type
	local refresh_rate = args.refresh_rate or 1
	local step = args.step or 5
	volume_step = step
	local card = args.card or 0
	local device = args.device or "pulse"
	local mixctrl = args.mixctrl or "Master"
	local value_type = args.value_type or "-M"
	local toggle_cmd = args.toggle_cmd or nil

	if widget_types[widget_type] == nil then
		volume.widget = widget_types["icon_and_text"].get_widget(args.icon_and_text_args)
	else
		volume.widget = widget_types[widget_type].get_widget(args)
	end

	local function update_graphic(widget, stdout)
		local mute = string.match(stdout, "%[(o%D%D?)%]") -- \[(o\D\D?)\] - [on] or [off]
		if mute == "off" then
			widget:mute()
		elseif mute == "on" then
			widget:unmute()
		end
		local volume_level = string.match(stdout, "(%d?%d?%d)%%") -- (\d?\d?\d)\%)
		volume_level = string.format("% 3d", volume_level)
		widget:set_volume_level(volume_level)
	end

	function volume:inc(s)
		spawn.easy_async(INC_VOLUME_CMD(card, device, mixctrl, value_type, s or step), function(stdout)
			update_graphic(volume.widget, stdout)
		end)
	end

	function volume:dec(s)
		spawn.easy_async(DEC_VOLUME_CMD(card, device, mixctrl, value_type, s or step), function(stdout)
			update_graphic(volume.widget, stdout)
		end)
	end

	function volume:toggle()
		if toggle_cmd == nil then
			spawn.easy_async(TOG_VOLUME_CMD(card, device, mixctrl), function(stdout)
				update_graphic(volume.widget, stdout)
			end)
		else
			spawn.easy_async(toggle_cmd, function(_stdout)
				spawn.easy_async(GET_VOLUME_CMD(card, device, mixctrl, value_type), function(stdout)
					update_graphic(volume.widget, stdout)
				end)
			end)
		end
	end

	function volume:mixer()
		if mixer_cmd then
			spawn.easy_async(mixer_cmd)
		end
	end

	volume.widget:buttons(awful.util.table.join(
		awful.button({}, 3, function()
			if popup.visible then
				popup.visible = not popup.visible
			else
				rebuild_popup()
				bind_wibox_dismissal()
				popup:move_next_to(mouse.current_widget_geometry)
			end
		end),
		awful.button({}, 4, function()
			volume:inc()
		end),
		awful.button({}, 5, function()
			volume:dec()
		end),
		awful.button({}, 2, function()
			volume:mixer()
		end),
		awful.button({}, 1, function()
			volume:toggle()
		end)
	))

	watch(GET_VOLUME_CMD(card, device, mixctrl, value_type), refresh_rate, update_graphic, volume.widget)

	return volume.widget
end

return setmetatable(volume, {
	__call = function(_, ...)
		return worker(...)
	end,
})
