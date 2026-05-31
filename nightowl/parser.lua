local logger    = require("nightowl.logger")
local Ast       = require("nightowl.ast")
local Scope     = require("nightowl.scope")
local Tokenizer = require("nightowl.tokenizer")
local util      = require("nightowl.util")

local lookupify = util.lookupify
local AstKind   = Ast.AstKind
local TokenKind = Tokenizer.TokenKind

local NO_WARN_LOOKUP = lookupify{
    AstKind.NilExpression,AstKind.FunctionCallExpression,
    AstKind.PassSelfFunctionCallExpression,AstKind.VarargExpression
}
local CALLABLE_LOOKUP = lookupify{
    AstKind.VariableExpression,AstKind.IndexExpression,
    AstKind.FunctionCallExpression,AstKind.PassSelfFunctionCallExpression
}

local Parser = {}

local function pGenErr(self,msg)
    local tk
    if self.index>self.length then tk=self.tokens[self.length]
    elseif self.index<1 then return "Parse Error at 0:0, "..msg
    else tk=self.tokens[self.index] end
    return "Parse Error at "..tk.line..":"..tk.linePos..", "..msg
end

function Parser:new(settings)
    local ver=(settings and (settings.luaVersion or settings.LuaVersion)) or "LuaU"
    local p={
        luaVersion=ver,
        tokenizer=Tokenizer:new({luaVersion=ver}),
        tokens={},length=0,index=0,
    }
    setmetatable(p,self); self.__index=self
    return p
end

local function pPeek(self,n)
    n=n or 0
    local i=self.index+n+1
    if i>self.length then return Tokenizer.EOF_TOKEN end
    return self.tokens[i]
end

local function pGet(self)
    local i=self.index+1
    if i>self.length then error(pGenErr(self,"Unexpected end of input")) end
    self.index=i
    return self.tokens[i]
end

local function pIs(self,kind,srcOrN,n)
    local src
    if type(srcOrN)=="string" then src=srcOrN else n=srcOrN end
    n=n or 0
    local tk=pPeek(self,n)
    if tk.kind==kind then
        if src==nil or tk.source==src then return true end
    end
    return false
end

local function pConsume(self,kind,src)
    if pIs(self,kind,src) then self.index=self.index+1; return true end
    return false
end

local function pExpect(self,kind,src)
    if pIs(self,kind,src,0) then return pGet(self) end
    local tk=pPeek(self)
    if self.disableLog then error() end
    if src then
        logger:error(pGenErr(self,"Expected \""..src.."\" got \""..tk.source.."\""))
    else
        logger:error(pGenErr(self,"Expected "..kind.." got \""..tk.source.."\""))
    end
end

function Parser:parse(code)
    self.tokenizer:reset()
    self.tokenizer:append(code)
    self.tokens=self.tokenizer:scanAll()
    self.length=#self.tokens
    self.index=0
    local globalScope=Scope:newGlobal()
    local body=self:block(globalScope,true)
    return Ast.TopNode(body,globalScope)
end

function Parser:block(parentScope,isGlobal,existingScope)
    local scope=existingScope or (isGlobal and parentScope or Scope:new(parentScope))
    local stmts={}
    while true do
        if pIs(self,TokenKind.Keyword,"end")    then break end
        if pIs(self,TokenKind.Keyword,"else")   then break end
        if pIs(self,TokenKind.Keyword,"elseif") then break end
        if pIs(self,TokenKind.Keyword,"until")  then break end
        if pIs(self,TokenKind.Eof)              then break end
        local stmt=self:statement(scope)
        if stmt then
            table.insert(stmts,stmt)
            if stmt.kind==AstKind.ReturnStatement then break end
        end
        pConsume(self,TokenKind.Symbol,";")
    end
    return Ast.Block(stmts,scope)
end

function Parser:statement(scope)
    if pConsume(self,TokenKind.Symbol,";") then return Ast.NopStatement() end
    if pIs(self,TokenKind.Keyword,"do") then
        pGet(self)
        local body=self:block(scope,false)
        pExpect(self,TokenKind.Keyword,"end")
        return Ast.DoStatement(body)
    end
    if pIs(self,TokenKind.Keyword,"while") then
        pGet(self)
        local cond=self:expression(scope)
        pExpect(self,TokenKind.Keyword,"do")
        local body=self:block(scope,false)
        pExpect(self,TokenKind.Keyword,"end")
        return Ast.WhileStatement(body,cond,scope)
    end
    if pIs(self,TokenKind.Keyword,"repeat") then
        pGet(self)
        local body=self:block(scope,false)
        pExpect(self,TokenKind.Keyword,"until")
        local cond=self:expression(body.scope)
        return Ast.RepeatStatement(cond,body,scope)
    end
    if pIs(self,TokenKind.Keyword,"if") then
        pGet(self)
        local cond=self:expression(scope)
        pExpect(self,TokenKind.Keyword,"then")
        local body=self:block(scope,false)
        local elseifs={}
        local elsebody=nil
        while pConsume(self,TokenKind.Keyword,"elseif") do
            local ec=self:expression(scope)
            pExpect(self,TokenKind.Keyword,"then")
            local eb=self:block(scope,false)
            table.insert(elseifs,{condition=ec,body=eb})
        end
        if pConsume(self,TokenKind.Keyword,"else") then
            elsebody=self:block(scope,false)
        end
        pExpect(self,TokenKind.Keyword,"end")
        return Ast.IfStatement(cond,body,elseifs,elsebody)
    end
    if pIs(self,TokenKind.Keyword,"for") then
        pGet(self)
        local firstName=pExpect(self,TokenKind.Ident).value
        if pConsume(self,TokenKind.Symbol,"=") then
            local forScope=Scope:new(scope)
            local id=forScope:addVariable(firstName)
            local init=self:expression(scope)
            pExpect(self,TokenKind.Symbol,",")
            local final=self:expression(scope)
            local inc=Ast.NumberExpression(1)
            if pConsume(self,TokenKind.Symbol,",") then inc=self:expression(scope) end
            pExpect(self,TokenKind.Keyword,"do")
            local body=self:block(scope,false,forScope)
            pExpect(self,TokenKind.Keyword,"end")
            return Ast.ForStatement(forScope,id,init,final,inc,body,scope)
        else
            local forScope=Scope:new(scope)
            local ids={forScope:addDisabledVariable(firstName)}
            while pConsume(self,TokenKind.Symbol,",") do
                table.insert(ids,forScope:addDisabledVariable(pExpect(self,TokenKind.Ident).value))
            end
            pExpect(self,TokenKind.Keyword,"in")
            local exprs=self:exprList(scope)
            for _,id in ipairs(ids) do forScope:enableVariable(id) end
            pExpect(self,TokenKind.Keyword,"do")
            local body=self:block(scope,false,forScope)
            pExpect(self,TokenKind.Keyword,"end")
            return Ast.ForInStatement(forScope,ids,exprs,body,scope)
        end
    end
    if pIs(self,TokenKind.Keyword,"return") then
        pGet(self)
        local args={}
        if not pIs(self,TokenKind.Keyword,"end") and not pIs(self,TokenKind.Keyword,"else")
            and not pIs(self,TokenKind.Keyword,"elseif") and not pIs(self,TokenKind.Keyword,"until")
            and not pIs(self,TokenKind.Eof) and not pIs(self,TokenKind.Symbol,";") then
            args=self:exprList(scope)
        end
        pConsume(self,TokenKind.Symbol,";")
        return Ast.ReturnStatement(args)
    end
    if pIs(self,TokenKind.Keyword,"break") then
        pGet(self)
        return Ast.BreakStatement(nil,scope)
    end
    if self.luaVersion=="LuaU" and pIs(self,TokenKind.Keyword,"continue") then
        pGet(self)
        return Ast.ContinueStatement(nil,scope)
    end
    if pIs(self,TokenKind.Keyword,"function") then
        pGet(self)
        local fn=self:funcName(scope)
        local fnScope=Scope:new(scope)
        if fn.passSelf then fnScope:addVariable("self") end
        pExpect(self,TokenKind.Symbol,"(")
        local args=self:functionArgList(fnScope)
        pExpect(self,TokenKind.Symbol,")")
        local body=self:block(nil,false,fnScope)
        pExpect(self,TokenKind.Keyword,"end")
        return Ast.FunctionDeclaration(fn.scope,fn.id,fn.indices,args,body)
    end
    if pIs(self,TokenKind.Keyword,"local") then
        pGet(self)
        if pConsume(self,TokenKind.Keyword,"function") then
            local ident=pExpect(self,TokenKind.Ident)
            local id=scope:addDisabledVariable(ident.value,ident)
            scope:enableVariable(id)
            local fnScope=Scope:new(scope)
            pExpect(self,TokenKind.Symbol,"(")
            local args=self:functionArgList(fnScope)
            pExpect(self,TokenKind.Symbol,")")
            local body=self:block(nil,false,fnScope)
            pExpect(self,TokenKind.Keyword,"end")
            return Ast.LocalFunctionDeclaration(scope,id,args,body)
        end
        local ids=self:nameList(scope)
        local exprs={}
        if pConsume(self,TokenKind.Symbol,"=") then
            exprs=self:exprList(scope)
        end
        self:enableNameList(scope,ids)
        return Ast.LocalVariableDeclaration(scope,ids,exprs)
    end
    local expr=self:primaryExpression(scope)
    if expr then
        if expr.kind==AstKind.FunctionCallExpression then
            return Ast.FunctionCallStatement(expr.base,expr.args)
        end
        if expr.kind==AstKind.PassSelfFunctionCallExpression then
            return Ast.PassSelfFunctionCallStatement(expr.base,expr.passSelfFunctionName,expr.args)
        end
        if expr.kind==AstKind.IndexExpression or expr.kind==AstKind.VariableExpression then
            if expr.kind==AstKind.IndexExpression then expr.kind=AstKind.AssignmentIndexing end
            if expr.kind==AstKind.VariableExpression then expr.kind=AstKind.AssignmentVariable end
            if self.luaVersion=="LuaU" then
                local compoundMap={
                    ["+="]={Ast.CompoundAddStatement},
                    ["-="]={Ast.CompoundSubStatement},
                    ["*="]={Ast.CompoundMulStatement},
                    ["/="]={Ast.CompoundDivStatement},
                    ["%="]={Ast.CompoundModStatement},
                    ["^="]={Ast.CompoundPowStatement},
                    ["..="]={Ast.CompoundConcatStatement},
                }
                for sym,ctor in pairs(compoundMap) do
                    if pConsume(self,TokenKind.Symbol,sym) then
                        return ctor[1](expr,self:expression(scope))
                    end
                end
            end
            local lhs={expr}
            while pConsume(self,TokenKind.Symbol,",") do
                local e=self:primaryExpression(scope)
                if not e then
                    if self.disableLog then error() end
                    logger:error(pGenErr(self,"expected valid lhs"))
                end
                if e.kind==AstKind.IndexExpression then e.kind=AstKind.AssignmentIndexing end
                if e.kind==AstKind.VariableExpression then e.kind=AstKind.AssignmentVariable end
                table.insert(lhs,e)
            end
            pExpect(self,TokenKind.Symbol,"=")
            return Ast.AssignmentStatement(lhs,self:exprList(scope))
        end
        if self.disableLog then error() end
        logger:error(pGenErr(self,"expressions are not valid statements"))
    end
    return nil
end

function Parser:primaryExpression(scope)
    local i=self.index
    self.disableLog=true
    local ok,val=pcall(self.expressionFunctionCall,self,scope)
    self.disableLog=false
    if ok then return val end
    self.index=i
    return nil
end

function Parser:exprList(scope)
    local exprs={self:expression(scope)}
    while pConsume(self,TokenKind.Symbol,",") do
        table.insert(exprs,self:expression(scope))
    end
    return exprs
end

function Parser:nameList(scope)
    local ids={}
    local ident=pExpect(self,TokenKind.Ident)
    table.insert(ids,scope:addDisabledVariable(ident.value,ident))
    while pConsume(self,TokenKind.Symbol,",") do
        ident=pExpect(self,TokenKind.Ident)
        table.insert(ids,scope:addDisabledVariable(ident.value,ident))
    end
    return ids
end

function Parser:enableNameList(scope,list)
    for _,id in ipairs(list) do scope:enableVariable(id) end
end

function Parser:funcName(scope)
    local ident=pExpect(self,TokenKind.Ident)
    local baseName=ident.value
    local bscope,bid=scope:resolve(baseName)
    local indices,passSelf={},false
    while pConsume(self,TokenKind.Symbol,".") do
        table.insert(indices,pExpect(self,TokenKind.Ident).value)
    end
    if pConsume(self,TokenKind.Symbol,":") then
        table.insert(indices,pExpect(self,TokenKind.Ident).value)
        passSelf=true
    end
    return {scope=bscope,id=bid,indices=indices,passSelf=passSelf,token=ident}
end

function Parser:expression(scope)  return self:expressionOr(scope) end

function Parser:expressionOr(scope)
    local lhs=self:expressionAnd(scope)
    if pConsume(self,TokenKind.Keyword,"or") then
        return Ast.OrExpression(lhs,self:expressionOr(scope),true)
    end
    return lhs
end

function Parser:expressionAnd(scope)
    local lhs=self:expressionComparision(scope)
    if pConsume(self,TokenKind.Keyword,"and") then
        return Ast.AndExpression(lhs,self:expressionAnd(scope),true)
    end
    return lhs
end

function Parser:expressionComparision(scope)
    local curr=self:expressionStrCat(scope)
    local cmpMap={
        ["<"]={Ast.LessThanExpression},
        [">"]={Ast.GreaterThanExpression},
        ["<="]={Ast.LessThanOrEqualsExpression},
        [">="]={Ast.GreaterThanOrEqualsExpression},
        ["~="]={Ast.NotEqualsExpression},
        ["=="]={Ast.EqualsExpression},
    }
    repeat
        local found=false
        for sym,ctor in pairs(cmpMap) do
            if pConsume(self,TokenKind.Symbol,sym) then
                curr=ctor[1](curr,self:expressionStrCat(scope),true)
                found=true; break
            end
        end
    until not found
    return curr
end

function Parser:expressionStrCat(scope)
    local lhs=self:expressionAddSub(scope)
    if pConsume(self,TokenKind.Symbol,"..") then
        return Ast.StrCatExpression(lhs,self:expressionStrCat(scope),true)
    end
    return lhs
end

function Parser:expressionAddSub(scope)
    local curr=self:expressionMulDivMod(scope)
    repeat
        local found=false
        if pConsume(self,TokenKind.Symbol,"+") then
            curr=Ast.AddExpression(curr,self:expressionMulDivMod(scope),true); found=true
        end
        if pConsume(self,TokenKind.Symbol,"-") then
            curr=Ast.SubExpression(curr,self:expressionMulDivMod(scope),true); found=true
        end
    until not found
    return curr
end

function Parser:expressionMulDivMod(scope)
    local curr=self:expressionUnary(scope)
    repeat
        local found=false
        if pConsume(self,TokenKind.Symbol,"*") then
            curr=Ast.MulExpression(curr,self:expressionUnary(scope),true); found=true
        end
        if pConsume(self,TokenKind.Symbol,"/") then
            curr=Ast.DivExpression(curr,self:expressionUnary(scope),true); found=true
        end
        if pConsume(self,TokenKind.Symbol,"%") then
            curr=Ast.ModExpression(curr,self:expressionUnary(scope),true); found=true
        end
    until not found
    return curr
end

function Parser:expressionUnary(scope)
    if pConsume(self,TokenKind.Keyword,"not") then return Ast.NotExpression(self:expressionUnary(scope),true) end
    if pConsume(self,TokenKind.Symbol,"#")   then return Ast.LenExpression(self:expressionUnary(scope),true) end
    if pConsume(self,TokenKind.Symbol,"-")   then return Ast.NegateExpression(self:expressionUnary(scope),true) end
    return self:expressionPow(scope)
end

function Parser:expressionPow(scope)
    local lhs=self:tableOrFunctionLiteral(scope)
    if pConsume(self,TokenKind.Symbol,"^") then
        return Ast.PowExpression(lhs,self:expressionUnary(scope),true)
    end
    return lhs
end

function Parser:tableOrFunctionLiteral(scope)
    if pIs(self,TokenKind.Symbol,"{")         then return self:tableConstructor(scope) end
    if pIs(self,TokenKind.Keyword,"function") then return self:expressionFunctionLiteral(scope) end
    return self:expressionFunctionCall(scope)
end

function Parser:expressionFunctionLiteral(parentScope)
    local scope=Scope:new(parentScope)
    pExpect(self,TokenKind.Keyword,"function")
    pExpect(self,TokenKind.Symbol,"(")
    local args=self:functionArgList(scope)
    pExpect(self,TokenKind.Symbol,")")
    local body=self:block(nil,false,scope)
    pExpect(self,TokenKind.Keyword,"end")
    return Ast.FunctionLiteralExpression(args,body)
end

function Parser:functionArgList(scope)
    local args={}
    if pConsume(self,TokenKind.Symbol,"...") then
        table.insert(args,Ast.VarargExpression()); return args
    end
    if pIs(self,TokenKind.Ident) then
        local ident=pGet(self)
        local id=scope:addVariable(ident.value,ident)
        table.insert(args,Ast.VariableExpression(scope,id))
        while pConsume(self,TokenKind.Symbol,",") do
            if pConsume(self,TokenKind.Symbol,"...") then
                table.insert(args,Ast.VarargExpression()); return args
            end
            ident=pGet(self)
            id=scope:addVariable(ident.value,ident)
            table.insert(args,Ast.VariableExpression(scope,id))
        end
    end
    return args
end

function Parser:expressionFunctionCall(scope,base)
    base=base or self:expressionIndex(scope)
    if not (base and (CALLABLE_LOOKUP[base.kind] or base.isParenthesizedExpression)) then
        return base
    end
    local args={}
    if pIs(self,TokenKind.String) then
        args={Ast.StringExpression(pGet(self).value)}
    elseif pIs(self,TokenKind.Symbol,"{") then
        args={self:tableConstructor(scope)}
    elseif pConsume(self,TokenKind.Symbol,"(") then
        if not pIs(self,TokenKind.Symbol,")") then args=self:exprList(scope) end
        pExpect(self,TokenKind.Symbol,")")
    else
        return base
    end
    local node=Ast.FunctionCallExpression(base,args)
    if pIs(self,TokenKind.Symbol,".") or pIs(self,TokenKind.Symbol,"[") or pIs(self,TokenKind.Symbol,":") then
        return self:expressionIndex(scope,node)
    end
    if pIs(self,TokenKind.Symbol,"(") or pIs(self,TokenKind.Symbol,"{") or pIs(self,TokenKind.String) then
        return self:expressionFunctionCall(scope,node)
    end
    return node
end

function Parser:expressionIndex(scope,base)
    base=base or self:expressionLiteral(scope)
    while pConsume(self,TokenKind.Symbol,"[") do
        local expr=self:expression(scope)
        pExpect(self,TokenKind.Symbol,"]")
        base=Ast.IndexExpression(base,expr)
    end
    while pConsume(self,TokenKind.Symbol,".") do
        local ident=pExpect(self,TokenKind.Ident)
        base=Ast.IndexExpression(base,Ast.StringExpression(ident.value))
        while pConsume(self,TokenKind.Symbol,"[") do
            local expr=self:expression(scope)
            pExpect(self,TokenKind.Symbol,"]")
            base=Ast.IndexExpression(base,expr)
        end
    end
    if pConsume(self,TokenKind.Symbol,":") then
        local name=pExpect(self,TokenKind.Ident).value
        local args={}
        if pIs(self,TokenKind.String) then
            args={Ast.StringExpression(pGet(self).value)}
        elseif pIs(self,TokenKind.Symbol,"{") then
            args={self:tableConstructor(scope)}
        else
            pExpect(self,TokenKind.Symbol,"(")
            if not pIs(self,TokenKind.Symbol,")") then args=self:exprList(scope) end
            pExpect(self,TokenKind.Symbol,")")
        end
        local node=Ast.PassSelfFunctionCallExpression(base,name,args)
        if pIs(self,TokenKind.Symbol,".") or pIs(self,TokenKind.Symbol,"[") or pIs(self,TokenKind.Symbol,":") then
            return self:expressionIndex(scope,node)
        end
        if pIs(self,TokenKind.Symbol,"(") or pIs(self,TokenKind.Symbol,"{") or pIs(self,TokenKind.String) then
            return self:expressionFunctionCall(scope,node)
        end
        return node
    end
    if pIs(self,TokenKind.Symbol,"(") or pIs(self,TokenKind.Symbol,"{") or pIs(self,TokenKind.String) then
        return self:expressionFunctionCall(scope,base)
    end
    return base
end

function Parser:expressionLiteral(scope)
    if pConsume(self,TokenKind.Symbol,"(") then
        local expr=self:expression(scope)
        pExpect(self,TokenKind.Symbol,")")
        if expr then expr.isParenthesizedExpression=true end
        return expr
    end
    if pIs(self,TokenKind.String)          then return Ast.StringExpression(pGet(self).value) end
    if pIs(self,TokenKind.Number)          then return Ast.NumberExpression(pGet(self).value) end
    if pConsume(self,TokenKind.Keyword,"true")  then return Ast.BooleanExpression(true) end
    if pConsume(self,TokenKind.Keyword,"false") then return Ast.BooleanExpression(false) end
    if pConsume(self,TokenKind.Keyword,"nil")   then return Ast.NilExpression() end
    if pConsume(self,TokenKind.Symbol,"...")    then return Ast.VarargExpression() end
    if pIs(self,TokenKind.Ident) then
        local ident=pGet(self)
        local sc,id=scope:resolve(ident.value)
        return Ast.VariableExpression(sc,id)
    end
    if self.luaVersion=="LuaU" then
        if pConsume(self,TokenKind.Keyword,"if") then
            local cond=self:expression(scope)
            pExpect(self,TokenKind.Keyword,"then")
            local tv=self:expression(scope)
            pExpect(self,TokenKind.Keyword,"else")
            local fv=self:expression(scope)
            return Ast.IfElseExpression(cond,tv,fv)
        end
    end
    if self.disableLog then error() end
    logger:error(pGenErr(self,"Unexpected token \""..pPeek(self).source.."\""))
end

function Parser:tableConstructor(scope)
    local entries={}
    pExpect(self,TokenKind.Symbol,"{")
    while not pConsume(self,TokenKind.Symbol,"}") do
        if pConsume(self,TokenKind.Symbol,"[") then
            local key=self:expression(scope)
            pExpect(self,TokenKind.Symbol,"]")
            pExpect(self,TokenKind.Symbol,"=")
            local val=self:expression(scope)
            table.insert(entries,Ast.KeyedTableEntry(key,val))
        elseif pIs(self,TokenKind.Ident,0) and pIs(self,TokenKind.Symbol,"=",1) then
            local key=Ast.StringExpression(pGet(self).value)
            pExpect(self,TokenKind.Symbol,"=")
            local val=self:expression(scope)
            table.insert(entries,Ast.KeyedTableEntry(key,val))
        else
            table.insert(entries,Ast.TableEntry(self:expression(scope)))
        end
        if not pConsume(self,TokenKind.Symbol,";") and not pConsume(self,TokenKind.Symbol,",") and not pIs(self,TokenKind.Symbol,"}") then
            if self.disableLog then error() end
            logger:error(pGenErr(self,"expected \";\" or \",\""))
        end
    end
    return Ast.TableConstructorExpression(entries)
end

return Parser
