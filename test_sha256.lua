-- SHA256 Test Script for ComputerCraft
-- Run this to test the SHA256 implementation

package.path = package.path .. ";/lib/?.lua;/lib/?/init.lua"
local sha2 = require("shared.sha2")

print("Testing SHA256 implementation...")

local tests = {
    { "",                                            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" },
    { "abc",                                         "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" },
    { "hello",                                       "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824" },
    { "The quick brown fox jumps over the lazy dog", "d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592" },
}

local stats = {
    passed = 0,
    failed = 0,
}



for i, test in ipairs(tests) do
    local input, expected = test[1], test[2]
    local actual = sha2.sha256(input)

    if actual == expected then
        stats.passed = stats.passed + 1
        print(string.format("Test %d: '%s' passed", i, input))
    else
        stats.failed = stats.failed + 1
        print(string.format("Test %d: '%s' failed", i, input))
        print(string.format("Expected: %s", expected))
        print(string.format("Actual:   %s", actual))
        print("Match:    NO")
    end
    print("")
end

print("")

print("If any tests fail, there may be an issue with the SHA256 implementation.")
print("Results:")
print(string.format("Passed: %d", stats.passed))
print(string.format("Failed: %d", stats.failed))
