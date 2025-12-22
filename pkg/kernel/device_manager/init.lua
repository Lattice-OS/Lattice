local log = require("shared.log")

local DeviceManager = {
    initialized = false,
    devices = {},
    listeners = {
        attached = {},
        detached = {}
    }
}

-- Private: Emit a semantic event to registered listeners
local function emit(event, payload)
    local handlers = DeviceManager.listeners[event]
    if not handlers then return end

    for _, handler in ipairs(handlers) do
        -- Use pcall so a crashing service doesn't kill the device manager
        local ok, err = pcall(handler, payload)
        if not ok then
            log.error("Event handler error (" .. event .. "): " .. tostring(err))
        end
    end
end

-- Private: Bind a specific device to its driver
local function bind_device(device, driver_map)
    local package_name = driver_map[device.type]

    if not package_name then
        device.status = "error"
        device.error = "No driver registered for type: " .. device.type
        return
    end

    local ok, driver_def = pcall(require, package_name)
    if not ok then
        device.status = "error"
        device.error = "Failed to load driver package: " .. package_name
        log.error(device.error)
        log.error(driver_def)
        return
    end

    local ok2, instance = pcall(driver_def.init, device.peripheral)
    if not ok2 then
        device.status = "error"
        device.error = "Driver init failed: " .. tostring(instance)
        log.error(device.error)
        return
    end

    device.driver = instance
    device.status = "ok"
    log.trace("Device '" .. device.name .. "' bound to '" .. package_name .. "'")
end

-- Public API: Register for events
function DeviceManager.on(event, handler)
    if not DeviceManager.listeners[event] then
        log.warn("Attempted to register for unknown event: " .. tostring(event))
        return
    end
    table.insert(DeviceManager.listeners[event], handler)
end

function DeviceManager.init()
    if DeviceManager.initialized then return end
    log.trace("Initializing device manager")

    local map_path = "/os/drivers.lua"
    if not fs.exists(map_path) then
        log.error("Driver map missing at " .. map_path)
        return
    end
    local driver_map = loadfile(map_path)()

    DeviceManager.devices = {}
    for _, name in ipairs(peripheral.getNames()) do
        local ok, wrapped = pcall(peripheral.wrap, name)
        if ok then
            local device = {
                name = name,
                type = peripheral.getType(name),
                peripheral = wrapped,
                status = "unbound"
            }
            bind_device(device, driver_map)
            table.insert(DeviceManager.devices, device)
        end
    end

    DeviceManager.initialized = true
    log.trace("Device manager initialized")
end

function DeviceManager.get_devices()
    return DeviceManager.devices
end

-- Event Handlers for hot-swap (Called by Kernel Event Loop)
function DeviceManager.handle_attach(name)
    local map_path = "/os/drivers.lua"
    if not fs.exists(map_path) then return end
    local driver_map = loadfile(map_path)()

    local ok, wrapped = pcall(peripheral.wrap, name)
    if ok then
        local device = {
            name = name,
            type = peripheral.getType(name),
            peripheral = wrapped,
            status = "unbound"
        }
        bind_device(device, driver_map)
        table.insert(DeviceManager.devices, device)

        -- Trigger listeners
        emit("attached", device)
        return device
    end
end

function DeviceManager.handle_detach(name)
    for i, device in ipairs(DeviceManager.devices) do
        if device.name == name then
            local removed = table.remove(DeviceManager.devices, i)

            -- Trigger listeners
            emit("detached", removed)
            return removed
        end
    end
end

return DeviceManager
