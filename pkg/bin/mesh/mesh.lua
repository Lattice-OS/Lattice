-- mesh.lua
-- Lattice Standalone Package Manager (v0.4.0)
-- Handles multi-file packages and self-seeding hash verification.

package.path = package.path .. ";/lib/?.lua;/lib/?/init.lua"

local args = { ... }
local API_BASE = "https://lattice-os.cc/pkg/api/"


-- 1. Helper: Raw HTTP Download
local function fetch(url, path)
    local res = http.get(url, { ["Cache-Control"] = "no-cache" })
    if not res then return false, "Connection failed" end
    local f = fs.open(path, "w")
    f.write(res.readAll())
    f.close()
    res.close()
    return true
end

-- 2. Local State / CLI Flags
local skip_hash_flag = false
for i, arg in ipairs(args) do
    if arg == "--skip-hash" or arg == "-s" then
        skip_hash_flag = true
        table.remove(args, i)
    end
end

-- 3. Dependency Tracker (prevents infinite recursion loops)
local seen_packages = {}

-- Helper: Generates the /os/drivers.lua mapping table from the index
local function generate_driver_map(index)
    print("Mesh: Regenerating driver map...")
    local mapping = {}

    for pkg_name, pkg_data in pairs(index.p) do
        if pkg_data.t then -- 't' is our supported_types array
            for _, device_type in ipairs(pkg_data.t) do
                mapping[device_type] = pkg_name
            end
        end
    end

    local f = fs.open("/os/drivers.lua", "w")
    f.write("return " .. textutils.serialize(mapping))
    f.close()
    print("Mesh: Driver map updated.")
end

-- 4. Core Install Logic
local function install_package(name, branch, bypass_hash)
    -- Prevent infinite recursion loops
    if seen_packages[name] then return true end
    seen_packages[name] = true

    branch = branch or "main"
    bypass_hash = bypass_hash or skip_hash_flag

    print("Mesh: Resolving " .. name .. "...")

    -- A. Fetch index as Lua Table
    local res = http.get(API_BASE .. branch .. "/index?format=lua")
    if not res then error("Could not reach Lattice API") end
    local index_source = res.readAll()
    res.close()

    local index = load(index_source)()
    if not index or not index.p then error("Invalid index received from server") end
    print("Mesh: Manifest Updated At: " .. index.repository.updated)

    local pkg = index.p[name]
    if not pkg then error("Package not found in index: " .. name) end

    -- B. Verify Hash Engine Availability
    local sha2 = nil
    if not bypass_hash then
        local ok, lib = pcall(require, "shared.sha2")
        if ok then
            sha2 = lib
        else
            print("Mesh: Hash engine missing. Self-seeding sha2...")
            -- Recurse specifically for sha2 with bypass enabled
            install_package("shared.sha2", branch, true)
            sha2 = require("shared.sha2")
        end
    end

    -- C. Recursive Dependencies
    if pkg.d then
        for _, dep_name in ipairs(pkg.d) do
            install_package(dep_name, branch, bypass_hash)
        end
    end

    -- D. Determine the Install Root
    -- D. Determine the Install Root / Path
    local dest_root = ""
    local is_override = false

    -- Check for Metadata Override first
    if pkg.m and pkg.m.install_path then
        dest_root = fs.getDir(pkg.m.install_path)
        is_override = true
    else
        -- Standard Logic
        local root = "/os"
        if name:match("^shared%.") then
            root = "/lib"
        elseif name:match("^bin%.") then
            root = ""
        end
        local pkg_dir_path = name:gsub("%.", "/")
        dest_root = root .. "/" .. pkg_dir_path
    end

    if not fs.exists(dest_root) and dest_root ~= "" then
        fs.makeDir(dest_root)
    end

    -- E. Iterate and Download
    for _, file_entry in ipairs(pkg.f) do
        local filename = file_entry.n
        local expected_hash = file_entry.s
        local dest_path = ""

        if is_override then
            -- Use the exact path provided in metadata
            dest_path = pkg.m.install_path
        else
            dest_path = dest_root .. "/" .. filename
        end

        local file_url = API_BASE .. branch .. "/package/" .. pkg.p .. "/" .. filename

        print("Mesh: Fetching " .. name .. ":" .. filename)
        local ok, err = fetch(file_url, dest_path)

        if not ok then
            error("Download failed for " .. filename .. ": " .. err)
        end

        -- F. Integrity Check
        -- Can be skipped by setting the --skip-hash flag
        if not bypass_hash and sha2 then
            local f = fs.open(dest_path, "r")
            local content = f.readAll()
            f.close()

            local actual_hash = sha2.sha256(content)
            if actual_hash ~= expected_hash then
                fs.delete(dest_path)
                error("\nIntegrity Error: Hash mismatch for " ..
                    name .. ":" .. filename .. "\nExpected: " .. expected_hash .. "\nActual: " .. actual_hash)
            end
        end
    end

    -- G. Driver Mapping Hook
    -- If this was a driver or we are doing a major bootstrap, regenerate the lookup table
    if name:match("^drivers%.") or name:match("^packages%.") then
        generate_driver_map(index)
    end

    print("Mesh: Installed " .. name)
    return true
end

-- 5. CLI Entrypoint
local cmd = args[1]
local target = args[2]
local branch = args[3] or "main"

if cmd == "install" then
    if not target then error("Usage: mesh install <package>") end
    install_package(target, branch)
elseif cmd == "bootstrap" then
    -- High-level groups required for Lattice OS
    install_package("packages.shared", branch)
    install_package("packages.boot", branch)
    install_package("packages.kernel", branch)
    install_package("packages.core_drivers", branch)
    install_package("bin.mesh", branch)
    print("\nMesh: Lattice OS Bootstrap Complete.")
else
    print("Lattice Mesh v0.4.0")
    print("Usage: mesh install <pkg> [--skip-hash] [branch]")
end
