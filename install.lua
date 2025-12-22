-- Simple install.lua (The one on the website)
package.path = package.path .. ";/bin/?.lua;/bin/?/?.lua"
if fs.exists("/bin/mesh.lua") then
    print("Deleting old mesh.lua...")
    fs.delete("/bin/mesh.lua")
    os.sleep(1)
end
shell.run("wget", "https://lattice-os.cc/pkg/api/main/package/bin/mesh/mesh.lua", "/bin/mesh.lua")
os.sleep(1)
shell.run("/bin/mesh.lua", "bootstrap")

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

os.sleep(10)
os.reboot()
