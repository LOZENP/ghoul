local logger   = require("nightowl.logger")
local Parser   = require("nightowl.parser")
local Unparser = require("nightowl.unparser")
local Enums    = require("nightowl.enums")
local Scope    = require("nightowl.scope")
local util     = require("nightowl.util")

local EncryptStrings        = require("nightowl.steps.encrypt_strings")
local ConstantArray         = require("nightowl.steps.constant_array")
local NumbersToExpressions  = require("nightowl.steps.numbers_to_expressions")
local WrapInFunction        = require("nightowl.steps.wrap_in_function")
local Compiler              = require("nightowl.compiler.compiler")

local VarDigits      = util.chararray("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
local VarStartDigits = util.chararray("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")

local function mangledName(id,_)
    local name=""
    local d=id%#VarStartDigits
    id=(id-d)/#VarStartDigits
    name=name..VarStartDigits[d+1]
    while id>0 do
        local e=id%#VarDigits
        id=(id-e)/#VarDigits
        name=name..VarDigits[e+1]
    end
    return name
end

local NameGenerator = {
    generateName = mangledName,
    prepare = function(_)
        util.shuffle(VarDigits)
        util.shuffle(VarStartDigits)
    end
}

local function applyPipeline(code, filename, useVM)
    filename = filename or "Anonymous"
    logger:info("Applying pipeline to " .. filename .. " ...")

    local ok, seed = pcall(function()
        local s = io.popen("openssl rand -hex 12"):read("*a"):gsub("\n","")
        local n = 0
        for i = 1, #s do
            local c = s:sub(i,i):lower()
            local d = c:match("%d") and (c:byte()-48) or (c:byte()-87)
            n = n*16+d
        end
        if _VERSION=="Lua 5.1" and not jit then n = n % 9.007199254741e+15 end
        return n
    end)
    if ok then math.randomseed(seed)
    else logger:warn("OpenSSL unavailable, using os.time"); math.randomseed(os.time()) end

    local t0     = os.time()
    local srcLen = #code

    logger:info("Parsing...")
    local parser = Parser:new({LuaVersion="Lua51"})
    local ast    = parser:parse(code)
    logger:info("Parsing done")

    -- VM compile step (optional)
    if useVM then
        logger:info("Compiling to VM bytecode...")
        local compiler = Compiler:new()
        ast = compiler:compile(ast)
        logger:info("VM compile done")
    end

    -- Obfuscation steps
    local steps = {
        EncryptStrings:new({}),
        ConstantArray:new({
            Treshold             = 1,
            StringsOnly          = true,
            Shuffle              = true,
            Rotate               = true,
            Encoding             = "base64",
            LocalWrapperCount    = 0,
            LocalWrapperArgCount = 10,
            MaxWrapperOffset     = 65535,
            LocalWrapperTreshold = 0,
        }),
        NumbersToExpressions:new({
            Threshold                    = 1,
            InternalThreshold            = 0.2,
            NumberRepresentationMutaton  = false,
            AllowedNumberRepresentations = {"hex","scientific","normal"},
        }),
        WrapInFunction:new({Iterations=1}),
    }

    for _, step in ipairs(steps) do
        logger:info("Applying step \"" .. step.Name .. "\" ...")
        local t1     = os.time()
        local newAst = step:apply(ast)
        if type(newAst) == "table" then ast = newAst end
        logger:info("Step \"" .. step.Name .. "\" done in " .. (os.time()-t1) .. " s")
    end

    logger:info("Renaming variables...")
    local t1 = os.time()
    local ng  = NameGenerator
    if type(ng.prepare) == "function" then ng.prepare(ast) end
    local conv = Enums.Conventions["Lua51"]
    ast.globalScope:renameVariables({
        Keywords     = conv.Keywords,
        generateName = ng.generateName,
        prefix       = "",
    })
    logger:info("Rename done in " .. (os.time()-t1) .. " s")

    logger:info("Generating code...")
    t1 = os.time()
    local unparser = Unparser:new({LuaVersion="Lua51", PrettyPrint=false})
    local out      = unparser:unparse(ast)
    logger:info("Code gen done in " .. (os.time()-t1) .. " s")
    logger:info("Done in " .. (os.time()-t0) .. " s | Output is " .. string.format("%.2f",(#out/srcLen)*100) .. "% of source")
    return out
end

return applyPipeline
