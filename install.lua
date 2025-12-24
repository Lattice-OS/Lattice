-- Simple install.lua (The one on the website)
package.path = package.path .. ";/bin/?.lua;/bin/?/?.lua"
if fs.exists("/bin/mesh.lua") then
    print("Deleting old mesh.lua...")
    fs.delete("/bin/mesh.lua")
    os.sleep(1)
end
shell.run("wget", "https://lattice-os.cc/pkg/api/main/package/bin/mesh/mesh.lua", "/bin/mesh.lua")
os.sleep(1)
shell.run("/bin/mesh.lua", "bootstrap", "--debug")

os.sleep(1)

print("\n--- Lattice Network Configuration ---")
write("Enter Grid SSID: ")
local ssid = read()

write("Enter Grid Secret Key (leave blank for random): ")
local key = read("*") -- '*' hides the input
if key == "" then
    -- Reuse your nanoid logic or a simple random string
    key = "lat_" .. math.random(100000, 999999)
end

-- 3. Get Network Port (Channel)
write("Enter Communication Port (1-65535, leave blank for random): ")
local port_input = read()
local port = tonumber(port_input)

if not port or port < 1 or port > 65535 then
    -- Generate a random "High" port to avoid common ones (10000-65000)
    port = math.random(10000, 65000)
    print("Assigned random port: " .. port)
else
    print("Assigned custom port: " .. port)
end

print("Writing network configuration...")

local net_cfg = string.format([[
[network]
ssid = "%s"
key = "%s"
channel = "%s"
]], ssid, key, port)

local f = fs.open("/os/network.toml", "w")
f.write(net_cfg)
f.close()

print("Network configured for Grid: " .. ssid)


local optional_packs = {
    {
        id = "mekanism",
        label = "Mekanism integration drivers",
        packages = {
            "packages.drivers_mekanism"
        },
        autodetect = function()
            return type(rawget(_G, "mekanismEnergyHelper")) == "table"
                or type(rawget(_G, "mekanismFilterHelper")) == "table"
        end,
    }
}

local function yn(prompt, default)
    local suffix = default and " [Y/n] " or " [y/N] "
    while true do
        write(prompt .. suffix)
        local a = read()
        if a == "" then return default end
        a = a:lower()
        if a == "y" or a == "yes" then return true end
        if a == "n" or a == "no" then return false end
    end
end

for _, pack in ipairs(optional_packs) do
    local detected = pack.detect and pack.detect() or false
    local install = yn(
        ("Install %s?%s"):format(
            pack.label,
            detected and " (detected)" or ""
        ),
        detected
    )

    if install then
        -- call mesh install pack.package (however your installer invokes mesh)
        -- e.g. shell.run("mesh", "install", pack.package, "--branch", branch)
        shell.run("/bin/mesh.lua", "install", pack.package, "--debug")
    end
end


os.sleep(10)
os.reboot()
