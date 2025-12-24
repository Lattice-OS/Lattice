-- mesh.lua
-- Lattice Standalone Package Manager (v0.4.1)
-- Handles multi-file packages and self-seeding hash verification.

-- Update the package path so that lua can find the required libraries
package.path = package.path .. ";/lib/?.lua;/lib/?/init.lua"


--- Section: Runtime Variables

-- Runtime arguments
local args = { ... }

-- Configuration table
local config = {
    api_base = "https://lattice-os.cc/pkg/api/",
    branch = "main",
    skip_hash = false,
    mmv = nil,
    debug = false
}

-- Runtime state
local package_index = nil
local seen_packages = {}
local repo_lock = {}

-- Helper function to load repo lock file
local function load_repo_lock()
    if fs.exists("/var/repo.lock") then
        local f = fs.open("/var/repo.lock", "r")
        local content = f.readAll()
        f.close()
        repo_lock = textutils.unserialize(content) or {}
        if config.debug then
            local count = 0
            for _ in pairs(repo_lock) do count = count + 1 end
            print("Mesh: Loaded repo lock with " .. count .. " packages")
        end
    else
        if config.debug then
            print("Mesh: No repo lock file found, starting fresh")
        end
    end
end

-- Helper function to save repo lock file
local function save_repo_lock()
    if not fs.exists("/var") then
        fs.makeDir("/var")
    end
    local f = fs.open("/var/repo.lock", "w")
    f.write(textutils.serialize(repo_lock))
    f.close()
    if config.debug then
        local count = 0
        for _ in pairs(repo_lock) do count = count + 1 end
        print("Mesh: Saved repo lock with " .. count .. " packages")
    end
end

-- Helper function to check if package needs updating
local function package_needs_update(pkg_name, pkg_data)
    if not repo_lock[pkg_name] then
        if config.debug then
            print("Mesh: " .. pkg_name .. " not in lock file, needs install")
        end
        return true
    end

    for _, file_entry in ipairs(pkg_data.f) do
        local expected_hash = file_entry.s
        local locked_hash = repo_lock[pkg_name][file_entry.n]
        if locked_hash ~= expected_hash then
            if config.debug then
                print("Mesh: " .. pkg_name .. ":" .. file_entry.n .. " hash changed, needs update")
            end
            return true
        end
    end

    if config.debug then
        print("Mesh: " .. pkg_name .. " up to date, skipping")
    end
    return false
end

-- Helper function to update repo lock for a package
local function update_repo_lock(pkg_name, pkg_data)
    repo_lock[pkg_name] = {}
    for _, file_entry in ipairs(pkg_data.f) do
        repo_lock[pkg_name][file_entry.n] = file_entry.s
    end
end


-- Helper function to fetch a URL and save it to a file.
local function fetch(url, path)
    print("Fetching " .. url .. "...")
    local res = http.get(url, { ["Cache-Control"] = "no-cache" })
    if not res then return false, "Connection failed" end
    local f = fs.open(path, "w")
    f.write(res.readAll())
    f.close()
    res.close()
    print("Done")
    return true
end

-- Helper function to fetch the package index and store it once.
local function fetch_index(branch)
    -- If the index exists, return it instead of fetching it again
    if package_index then return package_index end

    -- If the index doesn't exist, fetch it.
    local res = http.get(config.api_base .. config.branch .. "/index?format=lua")
    if not res then error("Could not reach Lattice API") end
    local index_source = res.readAll()
    res.close()

    -- Is this secure?
    -- No, it's not secure. The index is loaded as a Lua script, which can execute arbitrary code.
    -- But, since the lattice-api generates the code on the fly from toml, it __should__ be safer
    -- than just loading arbitrary lua code from an untrusted source.
    package_index = load(index_source)()

    if config.mmv then
        if package_index.repository.version ~= config.mmv then
            print("Mesh: Repository version mismatch")
            print("Mesh: Minimum Version: " .. config.mmv)
            print("Mesh: Current Version: " .. package_index.repository.version)
            error("Mesh: Repository version mismatch")
        end
    end

    return package_index
end

-- Helper function to read the arguments
local function read_args()
    for i, arg in ipairs(args) do
        if arg == "--skip-hash" or arg == "-s" then
            config.skip_hash = true
            table.remove(args, i)
        elseif arg == "--mmv" or arg == "-m" then
            table.remove(args, i)   -- Remove the mmv flag
            config.mmv = tonumber(args[i]) -- Set the mmv value
            table.remove(args, i)   -- Remove the mmv value
        elseif arg == "--branch" or arg == "-b" then
            table.remove(args, i)   -- Remove the branch flag
            config.branch = args[i]        -- Set the branch value
            table.remove(args, i)   -- Remove the branch value
        elseif arg == "--debug" or arg == "-d" then
            config.debug = true
            table.remove(args, i)
        end
    end
end



-- Generates the /os/drivers.lua mapping table from the index
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


-- Helper function to install a package and all of its dependencies
local function install_package(name, branch, bypass_hash)
    -- Prevent infinite recursion loops
    if seen_packages[name] then return true end
    seen_packages[name] = true

    branch = branch or config.branch
    bypass_hash = bypass_hash or config.skip_hash

    print("Mesh: Resolving " .. name .. "...")
    local index = fetch_index(branch)

    if not index or not index.p then error("Invalid index received from server") end
    print("Mesh: Manifest Updated At: " .. index.repository.updated)

    local pkg = index.p[name]
    if not pkg then error("Package not found in index: " .. name) end

    -- Check if package needs updating
    if not package_needs_update(name, pkg) then
        return true
    end

    -- B. Verify Hash Engine Availability
    local sha2 = nil
    if not bypass_hash and not config.skip_hash then
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

    -- D. Determine the Install Root / Path
    local dest_root = ""
    local override_path = nil
    local override_is_dir = false

    if pkg.m and pkg.m.install_path then
        override_path = pkg.m.install_path

        -- Treat install_path as a directory if it doesn't look like a file path.
        -- e.g. "/lib/shared/sounds" (dir) vs "/startup.lua" (file)
        if override_path:sub(-1) == "/" then
            override_is_dir = true
            override_path = override_path:sub(1, -2) -- trim trailing slash
        else
            local last = fs.getName(override_path)
            override_is_dir = not last:find("%.") -- no extension -> dir
        end

        if override_is_dir then
            dest_root = override_path
        else
            dest_root = fs.getDir(override_path)
        end
    else
        -- Standard logic
        local root = "/os"
        if name:match("^shared%.") then
            root = "/lib"
        elseif name:match("^bin%.") then
            root = ""
        end
        dest_root = root .. "/" .. name:gsub("%.", "/")
    end

    if dest_root ~= "" and not fs.exists(dest_root) then
        fs.makeDir(dest_root)
    end

    -- E. Iterate and Download
    for _, file_entry in ipairs(pkg.f) do
        local filename = file_entry.n
        local expected_hash = file_entry.s

        local dest_path
        if override_path then
            if override_is_dir then
                dest_path = dest_root .. "/" .. filename
            else
                -- File override: install_path is the exact destination (single-file packages)
                dest_path = override_path
            end
        else
            dest_path = dest_root .. "/" .. filename
        end

        local file_url = config.api_base .. branch .. "/package/" .. pkg.p .. "/" .. filename

        print("Mesh: Fetching " .. name .. ":" .. filename)
        local ok, err = fetch(file_url, dest_path)
        if not ok then
            error("Download failed for " .. filename .. ": " .. err)
        end

        -- F. Integrity Check
        if not bypass_hash and sha2 then
            local f = fs.open(dest_path, "r")
            local content = f.readAll()
            f.close()

            if config.debug then
                print("Mesh: Verifying " .. name .. ":" .. filename .. " (size: " .. #content .. ")")
            end
            local actual_hash = sha2.sha256(content)
            if actual_hash ~= expected_hash then
            if config.debug then
                print("Mesh: First 100 bytes of content:")
                print(string.sub(content, 1, 100))
                print("Mesh: Content length: " .. #content)
                -- Check for line ending types
                local crlf_count = 0
                local lf_count = 0
                for i = 1, #content - 1 do
                    if content:sub(i, i+1) == "\r\n" then
                        crlf_count = crlf_count + 1
                    elseif content:sub(i, i) == "\n" then
                        lf_count = lf_count + 1
                    end
                end
                print("Mesh: CRLF sequences: " .. crlf_count .. ", LF sequences: " .. lf_count)
            end
                fs.delete(dest_path)
                error(
                    "\nIntegrity Error: Hash mismatch for "
                    .. name
                    .. ":"
                    .. filename
                    .. "\nExpected: "
                    .. expected_hash
                    .. "\nActual: "
                    .. actual_hash
                )
            end
        end
    end

    -- G. Driver Mapping Hook
    if name:match("^drivers%.") or name:match("^packages%.") then
        generate_driver_map(package_index)
    end

    -- Update repo lock
    update_repo_lock(name, pkg)
    save_repo_lock()

    print("Mesh: Installed " .. name)
    return true
end

--- Section: CLI Entrypoint
-- Read the command line arguments and parse the feature flags
read_args()

-- Load repo lock file
load_repo_lock()

-- Command to execute
local cmd = args[1]
local target = args[2]

print("Mesh: Starting")
if config.debug then
    print("Mesh: Parsing arguments")
    print("Mesh: CMD: " .. cmd)
    print("Mesh: Target: " .. tostring(target))
    print("Mesh: Config: " .. textutils.serialize(config))
end
print("Mesh: Executing command")

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
    print("Lattice Mesh v0.4.1")
    print("Usage: mesh install <pkg> [--skip-hash] [branch]")
end
