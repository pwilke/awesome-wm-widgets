# Network speed widget

Shows current download and upload rates for the selected network interfaces.
Right-click the widget to open the interface checklist. Selections are shared
by widget instances and saved in Awesome's cache. The default selection includes
all interfaces except loopback.

Give each instance a unique `id` to keep its interface selection independent.
Each widget shows its selected interfaces beside the rates. Selections are saved
per ID in Awesome's cache. The default selection includes all interfaces except
loopback.

Create instances in a screen's wibar:

```lua
local net_speed_widget = require("awesome-wm-widgets.net-speed-widget.net-speed")

-- Give each screen a distinct ID to keep its selection independent:
net_speed_widget({ id = "screen-" .. tostring(s.index) }),
```

Optional arguments:

| Option | Default | Description |
| --- | --- | --- |
| `id` | `"default"` | Unique ID for this instance's saved selection |
| `timeout` | `1` | Poll interval in seconds |
| `interface` | `"*"` | Initial interface, or `"*"` for all except loopback |
| `migrate_legacy_selection` | `false` | Load the old shared interface selection for this instance if it has no saved selection |
