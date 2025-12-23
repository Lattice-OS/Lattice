-- Author: Arthur Amos
-- Date: 2025-12-23

local log = require("shared.log")

local DRIVER_ID = "disk_drive"
local DRIVER_NAME = "Disk Drive Driver"
local DRIVER_VERSION = "1.0"

local function build_new_driver(peripheral)
    if type(peripheral.hasData) ~= "function" or type(peripheral.getMountPath) ~= "function" then
        error("Peripheral does not support disk drive interface")
    end

    local driver = {
        id = DRIVER_ID,
        name = DRIVER_NAME,
        version = DRIVER_VERSION,

        peripheral = peripheral,

        last_error = nil,
    }

    function driver:status()
        return {
            id = self.id,
            name = self.name,
            version = self.version,
            status = self.last_error and "ERROR" or "OK",
            error_message = self.last_error,
        }
    end

    function driver:hasData()
        local ok, res = pcall(self.peripheral.hasData, self.peripheral)
        if not ok then
            self.last_error = res
            return false, res
        end
        self.last_error = nil
        return true, res
    end

    function driver:getMountPath()
        local ok, res = pcall(self.peripheral.getMountPath, self.peripheral)
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
        local ok, res = pcall(self.peripheral.getLabel, self.peripheral)
        if not ok then
            self.last_error = res
            return false, res
        end
        self.last_error = nil
        return true, res
    end

    function driver:setLabel(label)
        if type(self.peripheral.setLabel) ~= "function" then
            return false, "setLabel unsupported"
        end
        local ok, res = pcall(self.peripheral.setLabel, self.peripheral, label)
        if not ok then
            self.last_error = res
            return false, res
        end
        self.last_error = nil
        return true
    end

    function driver:hasAudio()
        if type(self.peripheral.hasAudio) ~= "function" then
            return false, "hasAudio unsupported"
        end
        local ok, res = pcall(self.peripheral.hasAudio, self.peripheral)
        if not ok then
            self.last_error = res
            return false, res
        end
        self.last_error = nil
        return true, res
    end

    function driver:playAudio()
        if type(self.peripheral.playAudio) ~= "function" then
            return false, "playAudio unsupported"
        end
        local ok, res = pcall(self.peripheral.playAudio, self.peripheral)
        if not ok then
            self.last_error = res
            return false, res
        end
        self.last_error = nil
        return true
    end

    function driver:ejectDisk()
        if type(self.peripheral.ejectDisk) ~= "function" then
            return false, "ejectDisk unsupported"
        end
        local ok, res = pcall(self.peripheral.ejectDisk, self.peripheral)
        if not ok then
            self.last_error = res
            return false, res
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
