-- Author: Arthur Amos
-- Date: 2025-12-23

local log = require("shared.log")

local DRIVER_ID = "printer"
local DRIVER_NAME = "Printer Driver"
local DRIVER_VERSION = "1.0"

local function build_new_driver(peripheral)
    if type(peripheral.write) ~= "function" or type(peripheral.endPage) ~= "function" then
        error("Peripheral does not support printer interface")
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

    function driver:write(text)
        local ok, res = pcall(self.peripheral.write, self.peripheral, text)
        if not ok then
            self.last_error = res
            return false, res
        end
        self.last_error = nil
        return true
    end

    function driver:setPageTitle(title)
        if type(self.peripheral.setPageTitle) ~= "function" then
            return false, "setPageTitle unsupported"
        end
        local ok, res =
            pcall(self.peripheral.setPageTitle, self.peripheral, title)
        if not ok then
            self.last_error = res
            return false, res
        end
        self.last_error = nil
        return true
    end

    function driver:getPageTitle()
        if type(self.peripheral.getPageTitle) ~= "function" then
            return true, nil
        end
        local ok, res =
            pcall(self.peripheral.getPageTitle, self.peripheral)
        if not ok then
            self.last_error = res
            return false, res
        end
        self.last_error = nil
        return true, res
    end

    function driver:getInkLevel()
        if type(self.peripheral.getInkLevel) ~= "function" then
            return false, "getInkLevel unsupported"
        end
        local ok, res =
            pcall(self.peripheral.getInkLevel, self.peripheral)
        if not ok then
            self.last_error = res
            return false, res
        end
        self.last_error = nil
        return true, res
    end

    function driver:getPaperLevel()
        if type(self.peripheral.getPaperLevel) ~= "function" then
            return false, "getPaperLevel unsupported"
        end
        local ok, res =
            pcall(self.peripheral.getPaperLevel, self.peripheral)
        if not ok then
            self.last_error = res
            return false, res
        end
        self.last_error = nil
        return true, res
    end

    function driver:endPage()
        local ok, res = pcall(self.peripheral.endPage, self.peripheral)
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
