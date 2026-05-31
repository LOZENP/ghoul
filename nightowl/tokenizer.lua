local logger  = require("nightowl.logger")
local util    = require("nightowl.util")
local Enums   = require("nightowl.enums")

local lookupify   = util.lookupify
local unlookupify = util.unlookupify
local escape      = util.escape
local chararray   = util.chararray

local Tokenizer = {}
Tokenizer.EOF_CHAR         = "<EOF>"
Tokenizer.WHITESPACE_CHARS = lookupify{" ","\t","\n","\r"}
Tokenizer.ANNOTATION_CHARS = lookupify(chararray("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"))
Tokenizer.ANNOTATION_START_CHARS = lookupify(chararray("!@"))
Tokenizer.Conventions      = Enums.Conventions
Tokenizer.TokenKind = {
    Eof="Eof", Keyword="Keyword", Symbol="Symbol",
    Ident="Identifier", Number="Number", String="String",
}
Tokenizer.EOF_TOKEN = {kind="Eof",value="<EOF>",startPos=-1,endPos=-1,source="<EOF>"}

local function tkMake(self,startPos,kind,value)
    local line,linePos=self:getPosition(self.index)
    local ann=self.annotations; self.annotations={}
    return {kind=kind,value=value,startPos=startPos,endPos=self.index,
        source=self.source:sub(startPos+1,self.index),line=line,linePos=linePos,annotations=ann}
end

local function tkGenErr(self,msg)
    local l,p=self:getPosition(self.index)
    return "Lex Error at "..l..":"..p..", "..msg
end

function Tokenizer:getPosition(i)
    local col=self.columnMap[i] or self.columnMap[#self.columnMap]
    return col.id, col.charMap[i]
end

function Tokenizer:prepareGetPosition()
    local columnMap={}
    local column={charMap={},id=1,length=0}
    for idx=1,self.length do
        local c=self.source:sub(idx,idx)
        local cl=column.length+1
        column.length=cl
        column.charMap[idx]=cl
        if c=="\n" then column={charMap={},id=column.id+1,length=0} end
        columnMap[idx]=column
    end
    self.columnMap=columnMap
end

function Tokenizer:new(settings)
    local ver=(settings and (settings.luaVersion or settings.LuaVersion)) or "LuaU"
    local conv=Tokenizer.Conventions[ver]
    if not conv then logger:error("Unknown Lua version: "..ver) end
    local t={
        index=0,length=0,source="",luaVersion=ver,conventions=conv,
        NumberChars=conv.NumberChars,
        NumberCharsLookup=lookupify(conv.NumberChars),
        Keywords=conv.Keywords,
        KeywordsLookup=lookupify(conv.Keywords),
        BinaryNumberChars=conv.BinaryNumberChars,
        BinaryNumberCharsLookup=lookupify(conv.BinaryNumberChars),
        BinaryNums=conv.BinaryNums,
        HexadecimalNums=conv.HexadecimalNums,
        HexNumberChars=conv.HexNumberChars,
        HexNumberCharsLookup=lookupify(conv.HexNumberChars),
        DecimalExponent=conv.DecimalExponent,
        DecimalSeperators=conv.DecimalSeperators,
        IdentChars=conv.IdentChars,
        IdentCharsLookup=lookupify(conv.IdentChars),
        EscapeSequences=conv.EscapeSequences,
        NumericalEscapes=conv.NumericalEscapes,
        EscapeZIgnoreNextWhitespace=conv.EscapeZIgnoreNextWhitespace,
        HexEscapes=conv.HexEscapes,
        UnicodeEscapes=conv.UnicodeEscapes,
        SymbolChars=conv.SymbolChars,
        SymbolCharsLookup=lookupify(conv.SymbolChars),
        MaxSymbolLength=conv.MaxSymbolLength,
        Symbols=conv.Symbols,
        SymbolsLookup=lookupify(conv.Symbols),
        StringStartLookup=lookupify({"\"","'"}),
        annotations={},
    }
    setmetatable(t,self); self.__index=self
    return t
end

function Tokenizer:reset()
    self.index=0; self.length=0; self.source=""; self.annotations={}; self.columnMap={}
end

function Tokenizer:append(code)
    self.source=self.source..code
    self.length=self.length+#code
    self:prepareGetPosition()
end

local function tkPeek(self,n)
    n=n or 0
    local i=self.index+n+1
    if i>self.length then return Tokenizer.EOF_CHAR end
    return self.source:sub(i,i)
end

local function tkGet(self)
    local i=self.index+1
    if i>self.length then logger:error(tkGenErr(self,"Unexpected end of input")) end
    self.index=i
    return self.source:sub(i,i)
end

local function tkExpect(self,charOrLookup)
    if type(charOrLookup)=="string" then charOrLookup={[charOrLookup]=true} end
    local c=tkPeek(self)
    if not charOrLookup[c] then
        local exp=unlookupify(charOrLookup)
        for i,v in ipairs(exp) do exp[i]=escape(v) end
        logger:error(tkGenErr(self,"Unexpected \""..escape(c).."\""))
    end
    self.index=self.index+1
    return c
end

local function tkIs(self,charOrLookup,n)
    local c=tkPeek(self,n)
    if type(charOrLookup)=="string" then return c==charOrLookup end
    return charOrLookup[c]
end

function Tokenizer:parseAnnotation()
    if tkIs(self,Tokenizer.ANNOTATION_START_CHARS) then
        self.index=self.index+1
        local src,len={},0
        while tkIs(self,Tokenizer.ANNOTATION_CHARS) do
            src[len+1]=tkGet(self); len=#src
        end
        if len>0 then self.annotations[string.lower(table.concat(src))]=true end
        return nil
    end
    return tkGet(self)
end

function Tokenizer:skipComment()
    if tkIs(self,"-",0) and tkIs(self,"-",1) then
        self.index=self.index+2
        if tkIs(self,"[") then
            self.index=self.index+1
            local eq=0
            while tkIs(self,"=") do self.index=self.index+1; eq=eq+1 end
            if tkIs(self,"[") then
                while true do
                    if self:parseAnnotation()=="]" then
                        local eq2=0
                        while tkIs(self,"=") do self.index=self.index+1; eq2=eq2+1 end
                        if tkIs(self,"]") and eq2==eq then self.index=self.index+1; return true end
                    end
                end
            end
        end
        while self.index<self.length and self:parseAnnotation()~="\n" do end
        return true
    end
    return false
end

function Tokenizer:skipWhitespaceAndComments()
    while self:skipComment() do end
    while tkIs(self,Tokenizer.WHITESPACE_CHARS) do
        self.index=self.index+1
        while self:skipComment() do end
    end
end

local function tkReadInt(self,chars,seps)
    local buf={}
    while true do
        if tkIs(self,chars) then buf[#buf+1]=tkGet(self)
        elseif seps and tkIs(self,seps) then self.index=self.index+1
        else break end
    end
    return table.concat(buf)
end

function Tokenizer:number()
    local startPos=self.index
    local src=tkExpect(self,setmetatable({["."]=true},{__index=self.NumberCharsLookup}))
    if src=="0" then
        if self.BinaryNums and tkIs(self,lookupify(self.BinaryNums)) then
            self.index=self.index+1
            local s=tkReadInt(self,self.BinaryNumberCharsLookup,self.DecimalSeperators and lookupify(self.DecimalSeperators) or nil)
            return tkMake(self,startPos,Tokenizer.TokenKind.Number,tonumber(s,2))
        end
        if self.HexadecimalNums and tkIs(self,lookupify(self.HexadecimalNums)) then
            self.index=self.index+1
            local s=tkReadInt(self,self.HexNumberCharsLookup,self.DecimalSeperators and lookupify(self.DecimalSeperators) or nil)
            return tkMake(self,startPos,Tokenizer.TokenKind.Number,tonumber(s,16))
        end
    end
    local seps=self.DecimalSeperators and lookupify(self.DecimalSeperators) or nil
    if src=="." then
        src=src..tkReadInt(self,self.NumberCharsLookup,seps)
    else
        src=src..tkReadInt(self,self.NumberCharsLookup,seps)
        if tkIs(self,".") then src=src..tkGet(self)..tkReadInt(self,self.NumberCharsLookup,seps) end
    end
    if self.DecimalExponent and tkIs(self,lookupify(self.DecimalExponent)) then
        src=src..tkGet(self)
        if tkIs(self,lookupify({"+","-"})) then src=src..tkGet(self) end
        local v=tkReadInt(self,self.NumberCharsLookup,seps)
        if #v<1 then logger:error(tkGenErr(self,"Expected valid exponent")) end
        src=src..v
    end
    return tkMake(self,startPos,Tokenizer.TokenKind.Number,tonumber(src))
end

function Tokenizer:ident()
    local startPos=self.index
    local src=tkExpect(self,self.IdentCharsLookup)
    local parts={src}
    while tkIs(self,self.IdentCharsLookup) do parts[#parts+1]=tkGet(self) end
    src=table.concat(parts)
    if self.KeywordsLookup[src] then
        return tkMake(self,startPos,Tokenizer.TokenKind.Keyword,src)
    end
    return tkMake(self,startPos,Tokenizer.TokenKind.Ident,src)
end

function Tokenizer:singleLineString()
    local startPos=self.index
    local startChar=tkExpect(self,self.StringStartLookup)
    local buf={}
    while not tkIs(self,startChar) do
        local c=tkGet(self)
        if c=="\n" then self.index=self.index-1; logger:error(tkGenErr(self,"Unterminated string")) end
        if c=="\\" then
            c=tkGet(self)
            local esc=self.EscapeSequences[c]
            if type(esc)=="string" then
                c=esc
            elseif self.NumericalEscapes and self.NumberCharsLookup[c] then
                local ns=c
                if tkIs(self,self.NumberCharsLookup) then ns=ns..tkGet(self) end
                if tkIs(self,self.NumberCharsLookup) then ns=ns..tkGet(self) end
                c=string.char(tonumber(ns))
            elseif self.UnicodeEscapes and c=="u" then
                tkExpect(self,"{")
                local num=""
                while tkIs(self,self.HexNumberCharsLookup) do num=num..tkGet(self) end
                tkExpect(self,"}")
                c=util.utf8char(tonumber(num,16))
            elseif self.HexEscapes and c=="x" then
                local hex=tkExpect(self,self.HexNumberCharsLookup)..tkExpect(self,self.HexNumberCharsLookup)
                c=string.char(tonumber(hex,16))
            elseif self.EscapeZIgnoreNextWhitespace and c=="z" then
                c=""
                while tkIs(self,Tokenizer.WHITESPACE_CHARS) do self.index=self.index+1 end
            end
        end
        buf[#buf+1]=c
    end
    tkExpect(self,startChar)
    return tkMake(self,startPos,Tokenizer.TokenKind.String,table.concat(buf))
end

function Tokenizer:multiLineString()
    local startPos=self.index
    if tkIs(self,"[") then
        self.index=self.index+1
        local eq=0
        while tkIs(self,"=") do self.index=self.index+1; eq=eq+1 end
        if tkIs(self,"[") then
            self.index=self.index+1
            if tkIs(self,"\n") then self.index=self.index+1 end
            local val=""
            while true do
                local c=tkGet(self)
                if c=="]" then
                    local eq2=0
                    while tkIs(self,"=") do c=c..tkGet(self); eq2=eq2+1 end
                    if tkIs(self,"]") and eq2==eq then
                        self.index=self.index+1
                        return tkMake(self,startPos,Tokenizer.TokenKind.String,val),true
                    end
                end
                val=val..c
            end
        end
    end
    self.index=startPos
    return nil,false
end

function Tokenizer:symbol()
    local startPos=self.index
    for len=self.MaxSymbolLength,1,-1 do
        local str=self.source:sub(self.index+1,self.index+len)
        if self.SymbolsLookup[str] then
            self.index=self.index+len
            return tkMake(self,startPos,Tokenizer.TokenKind.Symbol,str)
        end
    end
    logger:error(tkGenErr(self,"Unknown symbol"))
end

function Tokenizer:next()
    self:skipWhitespaceAndComments()
    local startPos=self.index
    if startPos>=self.length then
        return tkMake(self,startPos,Tokenizer.TokenKind.Eof)
    end
    if tkIs(self,self.NumberCharsLookup) then return self:number() end
    if tkIs(self,self.IdentCharsLookup)  then return self:ident() end
    if tkIs(self,self.StringStartLookup) then return self:singleLineString() end
    if tkIs(self,"[",0) then
        local val,isStr=self:multiLineString()
        if isStr then return val end
    end
    if tkIs(self,".") and tkIs(self,self.NumberCharsLookup,1) then return self:number() end
    if tkIs(self,self.SymbolCharsLookup) then return self:symbol() end
    logger:error(tkGenErr(self,"Unexpected char \""..escape(tkPeek(self)).."\""))
end

function Tokenizer:scanAll()
    local tb={}
    repeat
        local tk=self:next()
        tb[#tb+1]=tk
    until tk.kind==Tokenizer.TokenKind.Eof
    return tb
end

return Tokenizer
