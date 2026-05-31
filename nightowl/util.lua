local config = require("nightowl.config")

local util = {}

function util.lookupify(tb)
    local out = {}
    for _, v in ipairs(tb) do out[v] = true end
    return out
end

function util.unlookupify(tb)
    local out = {}
    for v in pairs(tb) do table.insert(out, v) end
    return out
end

function util.escape(str)
    return str:gsub(".", function(c)
        local b = string.byte(c)
        if b >= 32 and b <= 126 and c ~= "\\" and c ~= "\"" and c ~= "\'" then return c end
        if c == "\\" then return "\\\\" end
        if c == "\n" then return "\\n" end
        if c == "\r" then return "\\r" end
        if c == "\"" then return "\\\"" end
        if c == "\'" then return "\\'" end
        return string.format("\\%03d", b)
    end)
end

function util.chararray(str)
    local t = {}
    for i = 1, #str do t[#t+1] = str:sub(i,i) end
    return t
end

function util.keys(tb)
    local ks, n = {}, 0
    for k in pairs(tb) do n=n+1; ks[n]=k end
    return ks
end

function util.shuffle(tb)
    for i = #tb, 2, -1 do
        local j = math.random(i)
        tb[i], tb[j] = tb[j], tb[i]
    end
    return tb
end

function util.utf8char(cp)
    local sc = string.char
    if cp < 128 then return sc(cp) end
    local s = cp % 64; local c4 = 128+s; cp=(cp-s)/64
    if cp < 32 then return sc(192+cp, c4) end
    local s2 = cp % 64; local c3 = 128+s2; cp=(cp-s2)/64
    if cp < 16 then return sc(224+cp, c3, c4) end
    local s3 = cp % 64; cp=(cp-s3)/64
    return sc(240+cp, 128+s3, c3, c4)
end

function util.readonly(obj)
    local r = newproxy(true)
    getmetatable(r).__index = obj
    return r
end

return util
