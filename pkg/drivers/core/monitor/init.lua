-- os/drivers/core/display.lua

local DRIVER_ID = "monitor"
local DRIVER_NAME = "Generic Display Driver"
local DRIVER_VERSION = "1.0"

return {
    id = DRIVER_ID,
    name = DRIVER_NAME,
    version = DRIVER_VERSION,

    init = function(monitor)
        -- sanity check
        if type(monitor.write) ~= "function" then
            error("Peripheral does not support monitor interface")
        end

        local driver = {
            id = DRIVER_ID,
            name = DRIVER_NAME,
            version = DRIVER_VERSION,
        }

        -- cache some state
        local width, height = monitor.getSize()

        function driver.get_size()
            return width, height
        end

        function driver.clear()
            monitor.clear()
            monitor.setCursorPos(1, 1)
        end

        function driver.set_scale(scale)
            monitor.setTextScale(scale)
            width, height = monitor.getSize()
        end

        function driver.write_at(x, y, text)
            monitor.setCursorPos(x, y)
            monitor.write(text)
        end

        function driver.write_line(y, text)
            monitor.setCursorPos(1, y)
            monitor.write(text)
        end

        function driver.status()
            return {
                id = DRIVER_ID,
                name = DRIVER_NAME,
                version = DRIVER_VERSION,
                status = "OK",
                width = width,
                height = height,
            }
        end

        return driver
    end
}
