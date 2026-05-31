-- NightOwl Obfuscator - Modular Entry Point
-- Usage:
--   lua main.lua --in input.lua --out output.lua
--   lua main.lua --in input.lua --out output.lua --vm   (enables VM obfuscation)

if not pcall(function() return math.random(1, 2^40) end) then
    local old = math.random
    math.random = function(a, b)
        if not a and not b then return old() end
        if not b then return math.random(1, a) end
        if a > b then a, b = b, a end
        local d = b - a
        if d > 2^31 - 1 then return math.floor(old() * d + a) end
        return old(a, b)
    end
end

_G.newproxy = _G.newproxy or function(arg)
    if arg then return setmetatable({}, {}) end
    return {}
end

local applyPipeline = require("nightowl.pipeline")

local args       = arg or {}
local inputFile  = nil
local outputFile = nil
local useVM      = false
local i = 1
while i <= #args do
    if     args[i] == "--in"  then inputFile  = args[i+1]; i = i+2
    elseif args[i] == "--out" then outputFile = args[i+1]; i = i+2
    elseif args[i] == "--vm"  then useVM = true;           i = i+1
    else i = i+1 end
end

if not inputFile then
    print("Usage: lua main.lua --in <input.lua> --out <output.lua> [--vm]")
    os.exit(1)
end

local f = io.open(inputFile, "r")
if not f then print("Cannot open: " .. inputFile); os.exit(1) end
local code = f:read("*a"); f:close()

local result = applyPipeline(code, inputFile, useVM)

local out = outputFile and io.open(outputFile, "w") or io.stdout
out:write(result)
if outputFile then out:close() end
print("Done! -> " .. (outputFile or "stdout"))
