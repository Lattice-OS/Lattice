-- Author: Arthur Amos
-- Date: 2025-12-23

local log = require("shared.log")

local DRIVER_ID = "computer"
local DRIVER_NAME = "Computer Interface Driver"
local DRIVER_VERSION = "1.0"

local function build_new_driver(peripheral)
    if type(peripheral.getID) ~= "function" then
        error("Peripheral does not support computer interface")
    end

    local driver = {
        id = DRIVER_ID,
        name = DRIVER_NAME,
        version = DRIVER_VERSION,

        peripheral = peripheral,

        last_error = nil,
    }

    function driver:status()
        local id_ok, id = pcall(self.peripheral.getID, self.peripheral)
        return {
            id = self.id,
            name = self.name,
            version = self.version,
            status = self.last_error and "ERROR" or "OK",
            error_message = self.last_error,
            computer_id = id_ok and id or nil,
        }
    end

    function driver:getID()
        local ok, res = pcall(self.peripheral.getID, self.peripheral)
        if not ok then
            self.last_error = res
            return false, res
        end
        self.last_error = nil
        return true, res
    end

    function driver:getLabel()
        if type(self.peripheral.getLabel) ~= "function" then
            return true, nil
        end
        local ok, res =
            pcall(self.peripheral.getLabel, self.peripheral)
        if not ok then
            self.last_error = res
            return false, res
        end
        self.last_error = nil
        return true, res
    end

    function driver:uptime()
        if type(self.peripheral.uptime) ~= "function" then
            return false, "uptime unsupported"
        end
        local ok, res = pcall(self.peripheral.uptime, self.peripheral)
        if not ok then
            self.last_error = res
            return false, res
        end
        self.last_error = nil
        return true, res
    end

    function driver:getDay()
        if type(self.peripheral.getDay) ~= "function" then
            return false, "getDay unsupported"
        end
        local ok, res = pcall(self.peripheral.getDay, self.peripheral)
        if not ok then
            self.last_error = res
            return false, res
        end
        self.last_error = nil
        return true, res
    end

    function driver:getTime()
        if type(self.peripheral.getTime) ~= "function" then
            return false, "getTime unsupported"
        end
        local ok, res = pcall(self.peripheral.getTime, self.peripheral)
        if not ok then
            self.last_error = res
            return false, res
        end
        self.last_error = nil
        return true, res
    end

    driver.redstone = {}

    function driver.redstone:getAnalogInput(side)
        local ok, res = pcall(driver.peripheral.getAnalogInput, driver.peripheral, side)
        if not ok then
            driver.last_error = res
            return false, res
        end
        driver.last_error = nil
        return true, res
    end

    function driver.redstone:getAnalogOutput(side)
        local ok, res =
            pcall(driver.peripheral.getAnalogOutput, driver.peripheral, side)
        if not ok then
            driver.last_error = res
            return false, res
        end
        driver.last_error = nil
        return true, res
    end

    function driver.redstone:setAnalogOutput(side, value)
        local ok, res = pcall(
            driver.peripheral.setAnalogOutput,
            driver.peripheral,
            side,
            value
        )
        if not ok then
            driver.last_error = res
            return false, res
        end
        driver.last_error = nil
        return true
    end

    function driver.redstone:getBundledOutput(side)
        local ok, res = pcall(
            driver.peripheral.getBundledOutput,
            driver.peripheral,
            side
        )
        if not ok then
            driver.last_error = res
            return false, res
        end
        driver.last_error = nil
        return true, res
    end

    function driver.redstone:setBundledOutput(side, value)
        local ok, res = pcall(
            driver.peripheral.setBundledOutput,
            driver.peripheral,
            side,
            value
        )
        if not ok then
            driver.last_error = res
            return false, res
        end
        driver.last_error = nil
        return true
    end

    return driver
end

return {
    id = DRIVER_ID,
    name = DRIVER_NAME,
    version = DRIVER_VERSION,

    init = function(peripheral)
        return build_new_driver(peripheral)
    end,
}
