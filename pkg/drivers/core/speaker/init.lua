-- Author: Arthur Amos
-- Date: 2025-12-17

local log = require("shared.log")

local DRIVER_ID = "speaker"
local DRIVER_NAME = "Generic Speaker Driver"
local DRIVER_VERSION = "1.0"

local VOLUME_RANGE = {
    min = 0.0,
    default = 1.0,
    max = 3.0
}

local PITCH_RANGE = {
    min = 0.5,
    default = 1.0,
    max = 2.0
}

local VALID_INSTRUMENTS = {
    harp = true,
    basedrum = true,
    snare = true,
    hat = true,
    bass = true,
    flute = true,
    bell = true,
    guitar = true,
    chime = true,
    xylophone = true,
    iron_xylophone = true,
    cow_bell = true,
    didgeridoo = true,
    bit = true,
    banjo = true,
    pling = true
}

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function build_new_driver(peripheral)
    if type(peripheral.playNote) ~= "function" then
        error("Peripheral does not support speaker interface")
    end

    local driver = {
        id = DRIVER_ID,
        name = DRIVER_NAME,
        version = DRIVER_VERSION,

        peripheral = peripheral,

        volume = VOLUME_RANGE.default,
        pitch = PITCH_RANGE.default,
        instrument = "pling",

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

    function driver:setVolume(v)
        self.volume = clamp(v, VOLUME_RANGE.min, VOLUME_RANGE.max)
    end

    function driver:setPitch(p)
        self.pitch = clamp(p, PITCH_RANGE.min, PITCH_RANGE.max)
    end

    function driver:setInstrument(name)
        if not VALID_INSTRUMENTS[name] then
            log.error("Invalid instrument: " .. tostring(name))
            return false, "Invalid instrument: " .. tostring(name)
        end
        self.instrument = name
        return true
    end

    function driver:beep()
        log.trace("Beeping with instrument: " ..
            self.instrument .. " at pitch " .. self.pitch .. " and volume " .. self.volume)
        local ok, err = pcall(
            self.peripheral.playNote,
            self.instrument,
            self.volume,
            self.pitch
        )

        if not ok then
            log.error("Failed to play note: " .. err)
            self.last_error = err
            return false, err
        end

        self.last_error = nil
        return true
    end

    function driver:play_note(instrument, pitch, volume)
        local i = instrument or self.instrument
        local p = pitch or self.pitch
        local v = volume or self.volume

        local ok, err = pcall(
            self.peripheral.playNote,
            i,
            v,
            p
        )

        if not ok then
            log.error("Failed to play note: " .. err)
            self.last_error = err
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
    end
}
