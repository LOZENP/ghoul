local util = require("nightowl.util")
local chararray = util.chararray

local Enums = {}
Enums.LuaVersion = { LuaU = "LuaU", Lua51 = "Lua51" }
Enums.Conventions = {
    ["Lua51"] = {
        Keywords = {
            "and","break","do","else","elseif","end","false","for",
            "function","if","in","local","nil","not","or","repeat",
            "return","then","true","until","while"
        },
        SymbolChars     = chararray("+-*/%^#=~<>(){}[];:,."),
        MaxSymbolLength = 3,
        Symbols = {
            "+","-","*","/","%","^","#","==","~=","<=",">=","<",">","=",
            "(",")","[","]","{","}",";",":",",",".","..","...",
        },
        IdentChars        = chararray("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789"),
        NumberChars       = chararray("0123456789"),
        HexNumberChars    = chararray("0123456789abcdefABCDEF"),
        BinaryNumberChars = {"0","1"},
        DecimalExponent   = {"e","E"},
        HexadecimalNums   = {"x","X"},
        BinaryNums        = {"b","B"},
        DecimalSeperators = false,
        EscapeSequences   = {
            ["a"]="\\a",["b"]="\\b",["f"]="\\f",["n"]="\\n",
            ["r"]="\\r",["t"]="\\t",["v"]="\\v",
            ["\\"]="\\",["\""]="\"",["'"]="'",
        },
        NumericalEscapes            = true,
        EscapeZIgnoreNextWhitespace = true,
        HexEscapes                  = true,
        UnicodeEscapes              = true,
    },
    ["LuaU"] = {
        Keywords = {
            "and","break","continue","do","else","elseif","end","false","for",
            "function","if","in","local","nil","not","or","repeat",
            "return","then","true","until","while"
        },
        SymbolChars     = chararray("+-*/%^#=~<>(){}[];:,."),
        MaxSymbolLength = 3,
        Symbols = {
            "+","-","*","/","%","^","#","==","~=","<=",">=","<",">","=",
            "+=","-=","*=","/=","%=","^=","..=",
            "(",")","[","]","{","}",";",":",",",".","..","...",
            "::","->","?","|","&",
        },
        IdentChars        = chararray("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789"),
        NumberChars       = chararray("0123456789"),
        HexNumberChars    = chararray("0123456789abcdefABCDEF"),
        BinaryNumberChars = {"0","1"},
        DecimalExponent   = {"e","E"},
        HexadecimalNums   = {"x","X"},
        BinaryNums        = {"b","B"},
        DecimalSeperators = {"_"},
        EscapeSequences   = {
            ["a"]="\\a",["b"]="\\b",["f"]="\\f",["n"]="\\n",
            ["r"]="\\r",["t"]="\\t",["v"]="\\v",
            ["\\"]="\\",["\""]="\"",["'"]="'",
        },
        NumericalEscapes            = true,
        EscapeZIgnoreNextWhitespace = true,
        HexEscapes                  = true,
        UnicodeEscapes              = true,
    },
}

return Enums
