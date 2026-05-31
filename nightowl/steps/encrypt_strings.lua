local Step     = require("nightowl.steps.step")
local Ast      = require("nightowl.ast")
local Scope    = require("nightowl.scope")
local Parser   = require("nightowl.parser")
local visitAst = require("nightowl.visitast")
local util     = require("nightowl.util")

local AstKind = Ast.AstKind

local EncryptStrings = Step:extend()
EncryptStrings.Name = "Encrypt Strings"
EncryptStrings.Description = "Encrypts all string literals"
EncryptStrings.SettingsDescriptor = {}
function EncryptStrings:init() end

function EncryptStrings:CreateEncryptionService()
    local usedSeeds={}
    local sk6=math.random(0,63)
    local sk7=math.random(0,127)
    local sk44=math.random(0,17592186044415)
    local sk8=math.random(0,255)
    local floor=math.floor
    local function proot257(idx)
        local g,m,d=1,128,2*idx+1
        repeat g,m,d=g*g*(d>=m and 3 or 1)%257,m/2,d%m until m<1
        return g
    end
    local pm8=proot257(sk7)
    local pm45=sk6*4+1
    local pa45=sk44*2+1
    local s45=0; local s8=2; local prevVals={}
    local function setSeed(seed)
        s45=seed%35184372088832; s8=seed%255+2; prevVals={}
    end
    local function genSeed()
        local s
        repeat s=math.random(0,35184372088832) until not usedSeeds[s]
        usedSeeds[s]=true; return s
    end
    local function getRand32()
        s45=(s45*pm45+pa45)%35184372088832
        repeat s8=s8*pm8%257 until s8~=1
        local r=s8%32
        local n=floor(s45/2^(13-(s8-r)/32))%2^32/2^r
        return floor(n%1*2^32)+floor(n)
    end
    local function nextByte()
        if #prevVals==0 then
            local rnd=getRand32()
            local lo=rnd%65536; local hi=(rnd-lo)/65536
            local b1=lo%256; local b2=(lo-b1)/256
            local b3=hi%256; local b4=(hi-b3)/256
            prevVals={b1,b2,b3,b4}
        end
        return table.remove(prevVals)
    end
    local function encrypt(str)
        local seed=genSeed(); setSeed(seed)
        local len=#str; local out={}; local prev=sk8
        for i=1,len do
            local b=string.byte(str,i)
            out[i]=string.char((b-(nextByte()+prev))%256)
            prev=b
        end
        return table.concat(out),seed
    end
    local function genCode()
        local c=""
        c=c.."do\n"
        c=c.."local floor=math.floor\n"
        c=c.."local remove=table.remove\n"
        c=c.."local char=string.char\n"
        c=c.."local state_45=0\n"
        c=c.."local state_8=2\n"
        c=c.."local charmap={}\n"
        c=c.."local nums={}\n"
        c=c.."for i=1,256 do\n"
        c=c.."    nums[i]=i\n"
        c=c.."end\n"
        c=c.."repeat\n"
        c=c.."    local idx=math.random(1,#nums)\n"
        c=c.."    local n=remove(nums,idx)\n"
        c=c.."    charmap[n]=char(n-1)\n"
        c=c.."until #nums==0\n"
        c=c.."local prev_values={}\n"
        c=c.."local function get_next()\n"
        c=c.."    if #prev_values==0 then\n"
        c=c.."        state_45=(state_45*"..tostring(pm45).."+"..tostring(pa45)..")%35184372088832\n"
        c=c.."        repeat\n"
        c=c.."            state_8=state_8*"..tostring(pm8).."%257\n"
        c=c.."        until state_8~=1\n"
        c=c.."        local r=state_8%32\n"
        c=c.."        local shift=13-(state_8-r)/32\n"
        c=c.."        local n=floor(state_45/2^shift)%4294967296/2^r\n"
        c=c.."        local rnd=floor(n%1*4294967296)+floor(n)\n"
        c=c.."        local lo=rnd%65536\n"
        c=c.."        local hi=(rnd-lo)/65536\n"
        c=c.."        prev_values={lo%256,(lo-lo%256)/256,hi%256,(hi-hi%256)/256}\n"
        c=c.."    end\n"
        c=c.."    local pv=#prev_values\n"
        c=c.."    local v=prev_values[pv]\n"
        c=c.."    prev_values[pv]=nil\n"
        c=c.."    return v\n"
        c=c.."end\n"
        c=c.."local realStrings={}\n"
        c=c.."STRINGS=setmetatable({},{__index=realStrings,__metatable=nil})\n"
        c=c.."function DECRYPT(str,seed)\n"
        c=c.."    local rs=realStrings\n"
        c=c.."    if rs[seed] then\n"
        c=c.."        return seed\n"
        c=c.."    else\n"
        c=c.."        prev_values={}\n"
        c=c.."        local chars=charmap\n"
        c=c.."        state_45=seed%35184372088832\n"
        c=c.."        state_8=seed%255+2\n"
        c=c.."        local len=#str\n"
        c=c.."        rs[seed]=''\n"
        c=c.."        local prev="..tostring(sk8).."\n"
        c=c.."        local s=''\n"
        c=c.."        for i=1,len do\n"
        c=c.."            prev=(string.byte(str,i)+get_next()+prev)%256\n"
        c=c.."            s=s..chars[prev+1]\n"
        c=c.."        end\n"
        c=c.."        rs[seed]=s\n"
        c=c.."    end\n"
        c=c.."    return seed\n"
        c=c.."end\n"
        c=c.."end\n"
        return c
    end
    return {encrypt=encrypt,genCode=genCode}
end

function EncryptStrings:apply(ast)
    local enc=self:CreateEncryptionService()
    local code=enc.genCode()
    local parser=Parser:new({LuaVersion="Lua51"})
    local newAst=parser:parse(code)
    local doStat=newAst.body.statements[1]
    local scope=ast.body.scope
    local decryptVar=scope:addVariable()
    local stringsVar=scope:addVariable()
    doStat.body.scope:setParent(ast.body.scope)
    visitAst(newAst,nil,function(node,data)
        if node.kind==AstKind.FunctionDeclaration then
            if node.scope:getVariableName(node.id)=="DECRYPT" then
                data.scope:removeReferenceToHigherScope(node.scope,node.id)
                data.scope:addReferenceToHigherScope(scope,decryptVar)
                node.scope=scope; node.id=decryptVar
            end
        end
        if node.kind==AstKind.AssignmentVariable or node.kind==AstKind.VariableExpression then
            if node.scope:getVariableName(node.id)=="STRINGS" then
                data.scope:removeReferenceToHigherScope(node.scope,node.id)
                data.scope:addReferenceToHigherScope(scope,stringsVar)
                node.scope=scope; node.id=stringsVar
            end
        end
    end)
    visitAst(ast,nil,function(node,data)
        if node.kind==AstKind.StringExpression then
            data.scope:addReferenceToHigherScope(scope,stringsVar)
            data.scope:addReferenceToHigherScope(scope,decryptVar)
            local encrypted,seed=enc.encrypt(node.value)
            return Ast.IndexExpression(
                Ast.VariableExpression(scope,stringsVar),
                Ast.FunctionCallExpression(Ast.VariableExpression(scope,decryptVar),{
                    Ast.StringExpression(encrypted),
                    Ast.NumberExpression(seed),
                })
            )
        end
    end)
    table.insert(ast.body.statements,1,doStat)
    table.insert(ast.body.statements,1,
        Ast.LocalVariableDeclaration(scope,util.shuffle{decryptVar,stringsVar},{}))
    return ast
end

return EncryptStrings
