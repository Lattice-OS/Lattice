-- nanoid.lua
-- Pure Lua NanoID-style ID generator (callable module)
-- NOTE: This implementation is not cryptographically secure, nor is it specification compliant.
-- it is intended only for use in ComputerCraft. This implementation is not suitable for production use.

-- URL-safe alphabet (64 chars)
local ALPHABET = "_-0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
local ALPHABET_LEN = #ALPHABET

local DEFAULT_SIZE = 21

-- Seed math.random once
do
    local seed = os.time()

    if os.clock then
        seed = seed + math.floor(os.clock() * 1e6)
    end

    -- Use table address as extra entropy
    local addr = tostring({})
    local hex = addr:match("0x(%x+)")
    if hex then
        seed = seed + tonumber(hex, 16)
    end

    math.randomseed(seed)

    -- Discard first few values
    for _ = 1, 4 do
        math.random()
    end
end

-- Actual generator function
local function generate(size)
    size = size or DEFAULT_SIZE

    local id = {}

    for i = 1, size do
        local index = math.random(1, ALPHABET_LEN)
        id[i] = ALPHABET:sub(index, index)
    end

    return table.concat(id)
end

-- Public module table
local nanoid = {
    generate = generate,
}

-- Make the module callable
setmetatable(nanoid, {
    __call = function(_, size)
        return generate(size)
    end,
})

return nanoid
