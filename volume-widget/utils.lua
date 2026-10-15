

local utils = {}

function utils.extract_sinks_and_sources(device_output)
    local sinks = {}
    local sources = {}
    local destination
    for line in device_output:gmatch("[^\r\n]+") do
        if line == "SINKS" then
            destination = sinks
        elseif line == "SOURCES" then
            destination = sources
        elseif destination then
            local name, description, is_default, volume = line:match("^([^\t]*)\t([^\t]*)\t([01])\t(%d+)$")
            if name then
                table.insert(destination, {
                    name = name,
                    is_default = is_default == "1",
                    volume = tonumber(volume),
                    properties = { device_description = description },
                })
            end
        end
    end
    return sinks, sources
end

return utils
