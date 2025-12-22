-- debug.lua
-- Debug service: shows device status on a monitor

local log = require("shared.log")
local device_manager = require("os.kernel.device_manager")

local Debug = {
    initialized = false,
    display = nil,
    refresh_requested = false,
}

-- Find a monitor driver to use as our display
local function find_display()
    for _, dev in ipairs(device_manager.get_devices()) do
        if dev.type == "monitor" and dev.status == "ok" then
            return dev.driver
        end
    end
    return nil
end

-- Render the device list
local function render()
    if not Debug.display then
        return
    end

    Debug.display.clear()
    Debug.display.write_at(2, 1, "Lattice Debug View")

    local y = 3
    Debug.display.write_at(2, y, "Device List")

    y = y + 1

    for _, dev in ipairs(device_manager.get_devices()) do
        local driver_name = "N/A"
        if dev.driver then
            driver_name = dev.driver.name or "N/A"
        end

        local line =
            string.format(
                "%-8s %-15s %-15s %-7s %s",
                dev.name,
                dev.type,
                driver_name or "N/A",
                dev.status,
                dev.error or "N/A"
            )

        Debug.display.write_at(2, y, line)
        y = y + 1
    end

    --- Lower the cursor by one row
    y = y + 1

    Debug.display.write_at(2, y, "Kernel Services")

    y = y + 1

    --- Display the values from the K_DEBUG_SERVICES global table
    for _, service in ipairs(K_DEBUG_SERVICES) do
        Debug.display.write_at(2, y, service)
        y = y + 1
    end
end

-- Initialize the service
function Debug.init()
    if Debug.initialized then
        return
    end

    log.trace("Initializing debug service")

    Debug.display = find_display()
    if not Debug.display then
        log.warn("Debug service: no monitor available")
        Debug.initialized = true
        return
    end

    Debug.display.set_scale(1)
    render()

    -- Subscribe to hot-swap events
    device_manager.on("attached", function()
        Debug.refresh_requested = true
    end)

    device_manager.on("detached", function()
        Debug.refresh_requested = true
    end)

    Debug.initialized = true
end

-- Run loop (non-blocking, cooperative)
function Debug.run()
    if not Debug.initialized then
        return
    end

    while true do
        -- refresh every 10 seconds
        local timer = os.startTimer(10)

        local event, id = os.pullEvent("timer")

        if id == timer or Debug.refresh_requested then
            Debug.refresh_requested = false
            Debug.display = find_display()
            render()
        end
    end
end

return Debug
