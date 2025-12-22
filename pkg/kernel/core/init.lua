local log = require("shared.log")
local toml = require("shared.toml")
local nanoid = require("shared.nanoid")

local kernel_settings = toml.parse_file("/os/lattice.toml")

log.info("Starting Lattice kernel")

local ID_FILE = "/os/_.cmp.id"

if fs.exists(ID_FILE) then
    -- READ PHASE
    local f = fs.open(ID_FILE, "r")
    if f then
        _G.CMP_ID = f.readAll() -- Fixed: readAll() instead of f.read(path)
        f.close()
        log.info("Computer ID: " .. _G.CMP_ID)
    else
        log.error("Failed to read existing computer ID")
    end
else
    -- GENERATION PHASE
    _G.CMP_ID = nanoid() -- Assumes the callable module pattern we built
    local f = fs.open(ID_FILE, "w")
    if f then
        f.write(_G.CMP_ID)
        f.close()
        log.info("Initialized New Computer ID: " .. _G.CMP_ID)
    else
        log.error("Failed to write new computer ID")
        -- If we can't save the ID, the node identity is volatile.
        -- We should probably halt here.
        error("Kernel Panic: Persistent storage failure")
    end
end

local device_manager = require("os.kernel.device_manager")
device_manager.init()

local STATUS_ENABLED = false
local POWER_LIGHT = 3
local ERROR_LIGHT = 7
local STATUS_FACE = "back"

--- This table holds all of the services which are expected to be running
--- It is assigned dynamically based on the configuration parse_file
--- located at /os/lattice.toml
local services = {}
_G.K_DEBUG_SERVICES = {}


--- Provides a global status light function
function _G.K_STATUS_ERROR(enable)
    --- Return if status lights are disabled
    if not STATUS_ENABLED then return end

    --- Set status light to error or power light
    if enable then
        redstone.setAnalogOutput(STATUS_FACE, ERROR_LIGHT)
    else
        redstone.setAnalogOutput(STATUS_FACE, POWER_LIGHT)
    end
end

--- Provides a global status light controller
if kernel_settings.services.status_lights.enabled then
    STATUS_ENABLED = true
    POWER_LIGHT = kernel_settings.services.status_lights.threshold_power_light
    ERROR_LIGHT = kernel_settings.services.status_lights.threshold_error_light
    STATUS_FACE = kernel_settings.services.status_lights.face
    table.insert(_G.K_DEBUG_SERVICES, "status_lights")

    K_STATUS_ERROR(false)
end

log.info("Welcome to Lattice OS")

for _, dev in ipairs(device_manager.get_devices()) do
    log.info(dev.name .. " (" .. dev.type .. "): " .. dev.status)
end

-- Initial display output
for _, dev in ipairs(device_manager.get_devices()) do
    if dev.type == "monitor" and dev.status == "ok" then
        local d = dev.driver
        d.set_scale(1)
        d.clear()
        d.write_at(2, 2, "Lattice OS")
        d.write_at(2, 4, "Display driver online")
    end
end

-- Init services
local audio = require("os.services.audio")
audio.init()

-- Boot confirmation beep
os.sleep(0.5)
local ok, err = audio.ding()
if not ok then
    K_STATUS_ERROR(true)
    log.error("Failed to play beep sound: " .. err)
end

--- Handle the attaching and detaching of peripherals.
--- This allows the kernel to react to changes in the
--- attached devices which it is trying to manage.
local function device_event_loop()
    while true do
        local event, side = os.pullEvent()

        if event == "peripheral_attach" then
            device_manager.handle_attach(side)
        elseif event == "peripheral_detach" then
            device_manager.handle_detach(side)
        end
    end
end

if kernel_settings.interrupts.peripherals.enabled then
    table.insert(_G.K_DEBUG_SERVICES, "peripherals")
    table.insert(services, device_event_loop)
end

--- Handle redstone events.
--- This allows the kernel to trigger a hard reset when the redstone signal is high.
--- It also allows the kernel to trigger a warning light when an error is detected.
---
local function interrupt_on_redstone()
    log.info("Redstone interrupt service started") -- Add this!
    while true do
        --- Wait for a redstone signal to trigger an interrupt
        local event = os.pullEvent("redstone")
        log.trace("Redstone event detected") -- Add this!

        local faces = {
            front = redstone.getAnalogInput("front"),
            back = redstone.getAnalogInput("back"),
            top = redstone.getAnalogInput("top"),
            bottom = redstone.getAnalogInput("bottom"),
            left = redstone.getAnalogInput("left"),
            right = redstone.getAnalogInput("right")
        }

        if kernel_settings.services.reboot_button.enabled then
            local strength = faces[kernel_settings.services.reboot_button.face]
            if strength then
                if strength >= kernel_settings.services.reboot_button.threshold then
                    -- Trigger a soft reset
                    do return true end
                end
            end
        end

        if kernel_settings.interrupts.redstone.enabled then
            -- TODO: Do stuff to handle redstone levels changing
        end
    end
end

--- Enable the redstone interrupts if they're enabled in the configuration
if kernel_settings.interrupts.redstone.enabled then
    if kernel_settings.services.reboot_button.enabled then
        table.insert(_G.K_DEBUG_SERVICES, "redstone + REBOOT")
    else
        table.insert(_G.K_DEBUG_SERVICES, "redstone")
    end
    table.insert(services, interrupt_on_redstone)
elseif kernel_settings.services.reboot_button.enabled then
    table.insert(_G.K_DEBUG_SERVICES, "redstone (REBOOT)")
    table.insert(services, interrupt_on_redstone)
end

--- Enable the debug service if it is enabled in the configuration
if kernel_settings.services.debug.enabled then
    local debug = require("os.services.debug")
    debug.init()
    table.insert(services, debug.run)
end

--- Begin executing the user space
local reboot = parallel.waitForAny(
    table.unpack(services)
)

K_STATUS_ERROR(true)


log.info("Goodbye!")

os.sleep(5)

if reboot then
    os.reboot()
end
