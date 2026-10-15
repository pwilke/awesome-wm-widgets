-- Network rates for selected interfaces, with a right-click interface menu.

local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local watch = require("awful.widget.watch")
local wibox = require("wibox")

local net_speed_widget = {}
local legacy_selection_path = gears.filesystem.get_cache_dir() .. "net-speed-interfaces"

local function sorted_keys(values)
	local keys = {}
	for key in pairs(values) do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

local function load_selection(names, interface_filter, selection_path, migrate_legacy)
	local selected = {}
	local file = io.open(selection_path, "r")
	if not file and migrate_legacy then
		file = io.open(legacy_selection_path, "r")
	end
	if file then
		for name in file:lines() do
			selected[name] = true
		end
		file:close()
	else
		for _, name in ipairs(names) do
			if name ~= "lo" and (interface_filter == "*" or name == interface_filter) then
				selected[name] = true
			end
		end
	end
	return selected
end

local function save_selection(selected_interfaces, selection_path)
	local file = io.open(selection_path, "w")
	if not file then
		return
	end
	for _, name in ipairs(sorted_keys(selected_interfaces)) do
		if selected_interfaces[name] then
			file:write(name, "\n")
		end
	end
	file:close()
end

local function format_rate(bytes_per_second)
	local bits = math.max(0, bytes_per_second * 8)
	local units = { "b/s", "kb/s", "Mb/s", "Gb/s", "Tb/s" }
	local unit = 1
	while bits >= 1000 and unit < #units do
		bits = bits / 1000
		unit = unit + 1
	end
	local precision = bits < 10 and unit > 1 and 1 or 0
	local value = precision == 1 and string.format("%.1f", bits) or string.format("%.0f", bits)
	return value .. " " .. units[unit]
end

local function parse_counters(stdout)
	local counters = {}
	for line in stdout:gmatch("[^\r\n]+") do
		local name, rx, tx = line:match("^([^\t]+)\t(%d+)\t(%d+)$")
		if name then
			counters[name] = { rx = tonumber(rx), tx = tonumber(tx) }
		end
	end
	return counters
end

local function selected_rates(current, previous, selected_interfaces)
	local rx, tx = 0, 0
	for name in pairs(selected_interfaces) do
		local now = current[name]
		local before = previous and previous[name]
		if now and before then
			rx = rx + math.max(0, now.rx - before.rx)
			tx = tx + math.max(0, now.tx - before.tx)
		end
	end
	return rx, tx
end

local function make_rate_pair(icon_path, color, id)
	local rate_text = wibox.widget {
		id = id,
		markup = '<span foreground="' .. color .. '">0 b/s</span>',
		align = "left",
		widget = wibox.widget.textbox,
	}
	local pair = wibox.widget {
		{
			image = icon_path,
			forced_width = 12,
			forced_height = 12,
			resize = true,
			widget = wibox.widget.imagebox,
		},
		rate_text,
		spacing = 4,
		layout = wibox.layout.fixed.horizontal,
	}
	return pair, rate_text
end

local function worker(user_args)
	local args = user_args or {}
	local timeout = args.timeout or 1
	local interface_filter = args.interface or "*"
	local instance_id = tostring(args.id or "default"):gsub("[^%w_-]", "_")
	local selection_path = gears.filesystem.get_cache_dir() .. "net-speed-interfaces-" .. instance_id
	local migrate_legacy = args.migrate_legacy_selection == true or instance_id == "default"
	local interfaces = {}
	local selected_interfaces
	local selection_revision = 0
	local menu
	local build_menu
	local rx_pair, rx_widget = make_rate_pair(awful.util.get_configuration_dir() .. "awesome-wm-widgets/net-speed-widget/icons/down.svg", "#83a598", "rx_speed")
	local tx_pair, tx_widget = make_rate_pair(awful.util.get_configuration_dir() .. "awesome-wm-widgets/net-speed-widget/icons/up.svg", "#fabd2f", "tx_speed")
	local interface_text = wibox.widget {
		markup = '<span foreground="#a89984">(none)</span>',
		align = "left",
		widget = wibox.widget.textbox,
	}
	local widget = wibox.widget {
		{
			rx_pair,
			tx_pair,
			interface_text,
			spacing = 8,
			layout = wibox.layout.fixed.horizontal,
		},
		left = 5,
		right = 5,
		widget = wibox.container.margin,
	}

	local previous
	local seen_revision = selection_revision

	local function refresh_interface_text()
		local chosen = {}
		for _, name in ipairs(interfaces) do
			if selected_interfaces and selected_interfaces[name] then
				table.insert(chosen, name)
			end
		end
		local label = #chosen > 0 and table.concat(chosen, ", ") or "(none)"
		interface_text:set_markup('<span foreground="#a89984">' .. label .. "</span>")
	end

	local function toggle_interface(name)
		if selected_interfaces[name] then
			selected_interfaces[name] = nil
		else
			selected_interfaces[name] = true
		end
		selection_revision = selection_revision + 1
		save_selection(selected_interfaces, selection_path)
		refresh_interface_text()
	end

	menu = awful.popup {
		bg = beautiful and beautiful.bg_normal or "#282828",
		fg = beautiful and beautiful.fg_normal or "#ebdbb2",
		ontop = true,
		visible = false,
		border_width = 1,
		border_color = "#665c54",
		maximum_width = 260,
		offset = { y = 4 },
		widget = {},
	}

	build_menu = function()
		local rows = { layout = wibox.layout.fixed.vertical }
		local active_count = 0
		for _, interface in ipairs(interfaces) do
			if selected_interfaces and selected_interfaces[interface] then active_count = active_count + 1 end
		end
		table.insert(rows, wibox.widget {
			markup = string.format("<b>NETWORK INTERFACES</b> · %d active", active_count),
			align = "center",
			widget = wibox.widget.textbox,
		})
		for _, interface in ipairs(interfaces) do
			local selected_name = interface
			local checkbox = wibox.widget {
				checked = selected_interfaces and selected_interfaces[selected_name] == true or false,
				forced_width = 18,
				forced_height = 18,
				widget = wibox.widget.checkbox,
			}
			local label = wibox.widget {
				text = selected_name,
				align = "left",
				widget = wibox.widget.textbox,
			}
			local function toggle()
				toggle_interface(selected_name)
				build_menu()
			end
			checkbox:connect_signal("button::press", toggle)
			label:connect_signal("button::press", toggle)
			table.insert(rows, wibox.widget {
				{ checkbox, label, spacing = 8, layout = wibox.layout.fixed.horizontal },
				left = 8,
				right = 8,
				top = 3,
				bottom = 3,
				layout = wibox.container.margin,
			})
		end
		menu:setup(rows)
	end

	local function toggle_menu()
		if menu.visible then
			menu.visible = false
			return
		end
		build_menu()
		menu:move_next_to(mouse.current_widget_geometry or widget)
	end

	widget:buttons(gears.table.join(
		awful.button({}, 3, toggle_menu)
	))

	local command = {
		"python3",
		awful.util.get_configuration_dir() .. "awesome-wm-widgets/net-speed-widget/read-stats.py",
	}
	watch(command, timeout, function(_, stdout)
		local ok, callback_error = xpcall(function()
			local current = parse_counters(stdout)
			local names = sorted_keys(current)
			if #names == 0 then
				return
			end
			interfaces = names
			if not selected_interfaces then
				selected_interfaces = load_selection(names, interface_filter, selection_path, migrate_legacy)
				refresh_interface_text()
			end

			if seen_revision ~= selection_revision then
				previous = nil
				seen_revision = selection_revision
			end

			local rx_rate, tx_rate = 0, 0
			if previous then
				local rx_delta, tx_delta = selected_rates(current, previous, selected_interfaces)
				rx_rate, tx_rate = rx_delta / timeout, tx_delta / timeout
			end

			rx_widget:set_markup('<span foreground="#83a598">' .. format_rate(rx_rate) .. "</span>")
			tx_widget:set_markup('<span foreground="#fabd2f">' .. format_rate(tx_rate) .. "</span>")
			refresh_interface_text()
			previous = current
		end, debug.traceback)
		if not ok then gears.debug.print_error(callback_error) end
	end, widget)

	return widget
end

return setmetatable(net_speed_widget, { __call = function(_, ...) return worker(...) end })
