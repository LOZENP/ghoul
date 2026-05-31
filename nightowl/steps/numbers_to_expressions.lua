local Step     = require("nightowl.steps.step")
local Ast      = require("nightowl.ast")
local visitAst = require("nightowl.visitast")
local util     = require("nightowl.util")

local AstKind = Ast.AstKind

local NumbersToExpressions = Step:extend()
NumbersToExpressions.Name = "Numbers To Expressions"
NumbersToExpressions.Description = "Converts number literals to arithmetic expressions"
NumbersToExpressions.SettingsDescriptor = {
    Threshold                    = {type="number",default=1,min=0,max=1},
    InternalThreshold            = {type="number",default=0.2,min=0,max=0.8},
    NumberRepresentationMutaton  = {type="boolean",default=false},
    AllowedNumberRepresentations = {type="table",default={"hex","scientific","normal"}},
}

local function genMod(n)
    local rhs=n+math.random(1,2^24)
    local mul=math.random(1,2^8)
    return n+(mul*rhs),rhs
end

function NumbersToExpressions:init()
    self.ExpressionGenerators={
        function(val,depth)
            local v2=math.random(-2^20,2^20)
            local diff=val-v2
            if tonumber(tostring(diff))+tonumber(tostring(v2))~=val then return false end
            return Ast.AddExpression(self:CreateNumberExpression(v2,depth),self:CreateNumberExpression(diff,depth),false)
        end,
        function(val,depth)
            local v2=math.random(-2^20,2^20)
            local diff=val+v2
            if tonumber(tostring(diff))-tonumber(tostring(v2))~=val then return false end
            return Ast.SubExpression(self:CreateNumberExpression(diff,depth),self:CreateNumberExpression(v2,depth),false)
        end,
        function(val,depth)
            local lhs,rhs=genMod(val)
            if tonumber(tostring(lhs))%tonumber(tostring(rhs))~=val then return false end
            return Ast.ModExpression(self:CreateNumberExpression(lhs,depth),self:CreateNumberExpression(rhs,depth),false)
        end,
    }
end

function NumbersToExpressions:CreateNumberExpression(val,depth)
    if depth>0 and math.random()>=self.InternalThreshold or depth>15 then
        local fmt=self.AllowedNumberRepresentations[math.random(#self.AllowedNumberRepresentations)]
        if not self.NumberRepresentationMutaton then return Ast.NumberExpression(val) end
        if fmt=="hex" then
            if val~=math.floor(val) or val<0 then return Ast.NumberExpression(val) end
            local s=string.format("0x%X",val)
            local r=""
            for i=1,#s do
                local c=s:sub(i,i)
                r=r..(math.random()>0.5 and c:upper() or c:lower())
            end
            return Ast.NumberExpression(r)
        end
        if fmt=="scientific" then
            if val==0 then return Ast.NumberExpression(val) end
            local exp=math.floor(math.log10(math.abs(val)))
            local man=val/(10^exp)
            return Ast.NumberExpression(string.format("%.15ge%d",man,exp))
        end
        return Ast.NumberExpression(val)
    end
    local gens=util.shuffle({table.unpack(self.ExpressionGenerators)})
    for _,gen in ipairs(gens) do
        local n=gen(val,depth+1)
        if n then return n end
    end
    return Ast.NumberExpression(val)
end

function NumbersToExpressions:apply(ast)
    visitAst(ast,nil,function(node)
        if node.kind==AstKind.NumberExpression then
            if math.random()<=self.Threshold then
                return self:CreateNumberExpression(node.value,0)
            end
        end
    end)
end

return NumbersToExpressions
