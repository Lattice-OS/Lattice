-- Lattice OS boot entrypoint
-- Stage-1 bootstrap

package.path = package.path .. ";/lib/?.lua;/lib/?/init.lua;/os/?.lua;/os/?/?.lua;/os/?/init.lua"


local monitors = {}


for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "monitor" then
        table.insert(monitors, peripheral.wrap(name))
    end
end

local SPLASH = {
    " ##      #####  ######## ######## ##  ###### ####### ",
    " ##     ##   ##    ##       ##    ## ##      ##      ",
    " ##     #######    ##       ##    ## ##      #####   ",
    " ##     ##   ##    ##       ##    ## ##      ##      ",
    " ###### ##   ##    ##       ##    ##  ###### ####### ",
    "",
    "L A T T I C E   O S",
}
local log = require("shared.log")

local function draw_splash(mon)
    mon.setTextScale(1)
    mon.clear()

    local w, h = mon.getSize()
    local start_y = math.floor((h - #SPLASH) / 2) + 1

    for i, line in ipairs(SPLASH) do
        local x = math.floor((w - #line) / 2) + 1
        mon.setCursorPos(math.max(1, x), start_y + i - 1)
        mon.write(line)
    end
end

-- Draw splash everywhere
for _, mon in ipairs(monitors) do
    draw_splash(mon)
end

log.info("Booting Lattice OS")

-- Load system manifest
local ok, toml = pcall(require, "shared.toml")
if not ok then
    log.error("Failed to load TOML library")
    log.error("Reason: " .. toml)
    return
end


local cfg = toml.parse_file("/os/lattice.toml")

assert(cfg.system, "Missing [system]")
assert(cfg.node, "Missing [node]")

log.info("System: " .. cfg.system.name .. " " .. cfg.system.version)
log.info("Node role: " .. (cfg.node.role or "unknown"))
log.info("Monitors: " .. tostring(#monitors))
log.info("Boot complete")


if not fs.exists("/os/kernel/core/init.lua") then
    log.warn("Lattice is not correctly installed.")
    log.warn("It will now automatically reinstall itself.")
    fs.delete("/install.lua")
    local did_download = shell.run("wget",
        "https://raw.githubusercontent.com/AltriusRS/CCT/refs/heads/main/Lattice/install.lua", "/install.lua")
    if did_download == false then
        log.error("Failed to download Lattice Installer")
        log.error("You will need to download it manually.")
        log.error("Try running the following command")
        log.error(
            "wget https://raw.githubusercontent.com/AltriusRS/CCT/refs/heads/main/Lattice/install.lua /install.lua")
        shell.exit(1)
    end

    log.info("Downloaded installer")
    local did_install = require("install")

    if did_install == false then
        fs.delete("/startup.lua")
        log.error("Failed to reinstall. Please try again manually")
        log.error("This computer has been unenrolled from Lattice")
    end

    log.info("Your system will reboot in 10 seconds")
    os.sleep(10)
    os.reboot()
end

log.info("Passing to kernel")

require "os.kernel.core"
