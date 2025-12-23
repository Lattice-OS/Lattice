-- Lattice Audio Service
-- This service provides audio functionality for Lattice OS.

local log = require("shared.log")
local device_manager = require("os.kernel.device_manager")

local Audio = {
    initialized = false,
    speakers = {},
    busy = false,
}

local DFPWM_CHUNK_SIZE = 16 * 1024

-- Internal helper to refresh the list of speakers
local function refresh_speakers()
    Audio.speakers = {}

    for _, device in ipairs(device_manager.get_devices()) do
        if device.type == "speaker" and device.status == "ok" then
            table.insert(Audio.speakers, device)
        end
    end
end

-- Internal helper: get a usable speaker
local function get_speaker()
    if #Audio.speakers == 0 then
        return nil, "no speakers available"
    end
    return Audio.speakers[1]
end

local function play_dfpwm_handle(handle)
    local speaker, err = get_speaker()
    if not speaker then
        return false, err
    end

    while true do
        local chunk = handle.read(DFPWM_CHUNK_SIZE)
        if not chunk then break end

        while true do
            local ok, result = speaker.driver:play_audio(chunk)
            if not ok then
                return false, result
            end
            if result then
                break
            end
            speaker.driver:wait()
        end
    end

    return true
end

-- Initialize the audio service
-- Called once by the kernel after device_manager.init()
function Audio.init()
    if Audio.initialized then
        log.trace("Audio service already initialized")
        return
    end

    log.trace("Initializing audio service")

    -- Discover speakers that already exist at boot
    refresh_speakers()

    if #Audio.speakers == 0 then
        log.warn("Audio service initialized with no speakers")
    else
        log.info("Audio service found " .. #Audio.speakers .. " speaker(s)")
    end

    -- Subscribe to device hot-swap events
    device_manager.on("attached", function(device)
        if device.type == "speaker" and device.status == "ok" then
            log.info("Audio: speaker attached (" .. device.name .. ")")
            refresh_speakers()
            Audio.ding() -- USB-style notification sound
        end
    end)

    device_manager.on("detached", function(device)
        if device.type == "speaker" then
            log.info("Audio: speaker detached (" .. device.name .. ")")
            refresh_speakers()
        end
    end)

    Audio.initialized = true
end

-- Public API: simple notification sound
-- Safe to call from anywhere
function Audio.ding()
    if not Audio.initialized then
        return false, "audio service not initialized"
    end

    -- Fail fast if another sound is playing
    if Audio.busy then
        return false, "audio busy"
    end

    local speaker, err = get_speaker()
    if not speaker then
        return false, err
    end

    Audio.busy = true

    -- Call into the driver, not the peripheral
    local ok, result = pcall(speaker.driver.beep, speaker.driver)

    Audio.busy = false

    if not ok then
        log.error("Audio ding failed: " .. tostring(result))
        return false, result
    end

    return true
end

-- Optional: more general API if you want it
function Audio.play_note(instrument, volume, pitch)
    if not Audio.initialized then
        return false, "audio service not initialized"
    end

    if Audio.busy then
        return false, "audio busy"
    end

    local speaker, err = get_speaker()
    if not speaker then
        return false, err
    end

    Audio.busy = true

    local ok, result = pcall(
        speaker.driver.play_note,
        speaker.driver,
        instrument,
        pitch,
        volume
    )

    Audio.busy = false

    if not ok then
        log.error("Audio play_note failed: " .. tostring(result))
        return false, result
    end

    return true
end

function Audio.play_dfpwm_file(path)
    if not Audio.initialized then
        return false, "audio service not initialized"
    end

    if Audio.busy then
        return false, "audio busy"
    end

    local f = fs.open(path, "rb")
    if not f then
        return false, "could not open sound file: " .. tostring(path)
    end

    Audio.busy = true
    local ok, err = play_dfpwm_handle(f)
    Audio.busy = false

    f.close()

    if not ok then
        log.error("Audio play_dfpwm_file failed: " .. tostring(err))
        return false, err
    end

    return true
end

function Audio.play_dfpwm_handle(handle)
    if not Audio.initialized then
        return false, "audio service not initialized"
    end

    if Audio.busy then
        return false, "audio busy"
    end

    Audio.busy = true
    local ok, err = play_dfpwm_handle(handle)
    Audio.busy = false

    if not ok then
        log.error("Audio play_dfpwm_handle failed: " .. tostring(err))
        return false, err
    end

    return true
end

return Audio
