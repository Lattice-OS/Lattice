-- Author: Arthur Amos
-- Date: 2025-12-23

local log = require("shared.log")

local DRIVER_ID = "modem"
local DRIVER_NAME = "Generic Modem Driver"
local DRIVER_VERSION = "1.0" -- internal only, not in manifest

local function build_new_driver(peripheral)
    if type(peripheral.open) ~= "function"
        or type(peripheral.close) ~= "function"
        or type(peripheral.transmit) ~= "function"
    then
        error("Peripheral does not support modem interface")
    end

    local driver = {
        id = DRIVER_ID,
        name = DRIVER_NAME,
        version = DRIVER_VERSION,

        peripheral = peripheral,

        last_error = nil,
        open_channels = {}, -- [channel] = true
        wireless = nil,
    }

    -- Determine wireless if available (wired modems may still expose this)
    if type(peripheral.isWireless) == "function" then
        local ok, res = pcall(peripheral.isWireless, peripheral)
        if ok then
            driver.wireless = res == true
        end
    end

    function driver:status()
        local count = 0
        for _ in pairs(self.open_channels) do
            count = count + 1
        end

        return {
            id = self.id,
            name = self.name,
            version = self.version,
            status = self.last_error and "ERROR" or "OK",
            error_message = self.last_error,
            wireless = self.wireless,
            open_channels = count,
        }
    end

    function driver:isWireless()
        return self.wireless == true
    end

    function driver:open(channel)
        if type(channel) ~= "number" then
            return false, "channel must be a number"
        end

        local ok, err = pcall(self.peripheral.open, self.peripheral, channel)
        if not ok then
            self.last_error = err
            log.error("Modem open failed: " .. tostring(err))
            return false, err
        end

        self.open_channels[channel] = true
        self.last_error = nil
        return true
    end

    function driver:close(channel)
        if type(channel) ~= "number" then
            return false, "channel must be a number"
        end

        local ok, err = pcall(self.peripheral.close, self.peripheral, channel)
        if not ok then
            self.last_error = err
            log.error("Modem close failed: " .. tostring(err))
            return false, err
        end

        self.open_channels[channel] = nil
        self.last_error = nil
        return true
    end

    function driver:closeAll()
        local ok, err = pcall(self.peripheral.closeAll, self.peripheral)
        if not ok then
            self.last_error = err
            log.error("Modem closeAll failed: " .. tostring(err))
            return false, err
        end

        self.open_channels = {}
        self.last_error = nil
        return true
    end

    function driver:isOpen(channel)
        if type(channel) ~= "number" then
            return false, "channel must be a number"
        end

        if type(self.peripheral.isOpen) ~= "function" then
            return self.open_channels[channel] == true
        end

        local ok, res = pcall(self.peripheral.isOpen, self.peripheral, channel)
        if not ok then
            self.last_error = res
            log.error("Modem isOpen failed: " .. tostring(res))
            return false, res
        end

        self.last_error = nil
        return res
    end

    function driver:transmit(channel, reply_channel, msg)
        if type(channel) ~= "number" then
            return false, "channel must be a number"
        end

        reply_channel = reply_channel or channel
        if type(reply_channel) ~= "number" then
            return false, "reply_channel must be a number"
        end

        local ok, err = pcall(
            self.peripheral.transmit,
            self.peripheral,
            channel,
            reply_channel,
            msg
        )

        if not ok then
            self.last_error = err
            log.error("Modem transmit failed: " .. tostring(err))
            return false, err
        end

        self.last_error = nil
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
