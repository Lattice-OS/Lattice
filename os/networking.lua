local LOG = require("shared.log")

-- The primary discovery port used for locating other devices on the network.
local CAIRO_PORT = 6154

-- The 4 byte signature to prepend to each network packet.
local CAIRO_SIGNATURE = {0x14, 0x15, 0x81, 0x1b}

local network_manager = {
    
}

function network_manager.bind(peripheral_id)
    -- Attempt to bind to the request peripheral_id
    local ok, value = pcall(peripheral.wrap, peripheral_id)

    if not ok then

        return false
    end
end

return network_manager