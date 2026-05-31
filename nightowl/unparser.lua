local logger  = require("nightowl.logger")
local Ast     = require("nightowl.ast")
local Enums   = require("nightowl.enums")
local util    = require("nightowl.util")
local config  = require("nightowl.config")

local AstKind   = Ast.AstKind
local lookupify = util.lookupify

local function escStr(s) return util.escape(s) end
local function join(parts) return table.concat(parts) end

local Unparser = {}
Unparser.SPACE = config.SPACE
Unparser.TAB   = config.TAB

function Unparser:new(settings)
    local ver = settings.LuaVersion or "LuaU"
    local conv = Enums.Conventions[ver]
    local u = {
        luaVersion=ver, conventions=conv,
        identCharsLookup=lookupify(conv.IdentChars),
        numberCharsLookup=lookupify(conv.NumberChars),
        prettyPrint=settings.PrettyPrint or false,
        notIdentPattern="[^"..table.concat(conv.IdentChars,"").."]",
        numberPattern="^["..table.concat(conv.NumberChars,"").."]",
        highlight=settings.Highlight or false,
        keywordsLookup=lookupify(conv.Keywords),
    }
    setmetatable(u,self); self.__index=self
    return u
end

function Unparser:isValidIdentifier(src)
    if string.find(src,self.notIdentPattern) then return false end
    if string.find(src,self.numberPattern)   then return false end
    if self.keywordsLookup[src]              then return false end
    return #src>0
end

function Unparser:tabs(i,ws)    return self.prettyPrint and string.rep(self.TAB,i) or (ws and self.SPACE or "") end
function Unparser:newline(ws)   return self.prettyPrint and "\n" or (ws and self.SPACE or "") end
function Unparser:optionalWhitespace(ws) return self.prettyPrint and (ws or self.SPACE) or "" end
function Unparser:whitespace(ws) return self.SPACE or ws end
function Unparser:whitespaceIfNeeded(following,ws)
    if self.prettyPrint or self.identCharsLookup[string.sub(following,1,1)] then return ws or self.SPACE end
    return ""
end
function Unparser:whitespaceIfNeeded2(leading,ws)
    if self.prettyPrint or self.identCharsLookup[string.sub(leading,#leading,#leading)] then return ws or self.SPACE end
    return ""
end

function Unparser:unparse(ast)
    if ast.kind~=AstKind.TopNode then logger:error("unparse expects TopNode") end
    return self:unparseBlock(ast.body)
end

function Unparser:unparseBlock(block,tabbing)
    if #block.statements<1 then return self:whitespace() end
    local parts={}
    for i,stmt in ipairs(block.statements) do
        if stmt.kind~=AstKind.NopStatement then
            local sc=self:unparseStatement(stmt,tabbing)
            if not self.prettyPrint and #parts>0 and sc:sub(1,1)=="(" then sc=";"..sc end
            local ws=self:whitespaceIfNeeded2(#parts>0 and parts[#parts] or "",self:whitespaceIfNeeded(sc,self:newline(true)))
            if i~=1 then parts[#parts+1]=ws end
            if self.prettyPrint then sc=sc..";" end
            parts[#parts+1]=sc
        end
    end
    return join(parts)
end

function Unparser:unparseStatement(stmt,tabbing)
    tabbing=tabbing and tabbing+1 or 0
    local parts={}
    local function push(...) for i=1,select("#",...) do parts[#parts+1]=select(i,...) end end
    local k=stmt.kind
    if k==AstKind.ContinueStatement then push("continue")
    elseif k==AstKind.BreakStatement then push("break")
    elseif k==AstKind.DoStatement then
        local bc=self:unparseBlock(stmt.body,tabbing)
        push("do",self:whitespaceIfNeeded(bc,self:newline(true)),bc,self:newline(false),
            self:whitespaceIfNeeded2(bc,self:tabs(tabbing,true)),"end")
    elseif k==AstKind.WhileStatement then
        local ec=self:unparseExpression(stmt.condition,tabbing)
        local bc=self:unparseBlock(stmt.body,tabbing)
        push("while",self:whitespaceIfNeeded(ec),ec,self:whitespaceIfNeeded2(ec),
            "do",self:whitespaceIfNeeded(bc,self:newline(true)),
            bc,self:newline(false),self:whitespaceIfNeeded2(bc,self:tabs(tabbing,true)),"end")
    elseif k==AstKind.RepeatStatement then
        local ec=self:unparseExpression(stmt.condition,tabbing)
        local bc=self:unparseBlock(stmt.body,tabbing)
        push("repeat",self:whitespaceIfNeeded(bc,self:newline(true)),bc,
            self:whitespaceIfNeeded2(bc,self:newline()..self:tabs(tabbing,true)),
            "until",self:whitespaceIfNeeded(ec),ec)
    elseif k==AstKind.ForStatement then
        local bc=self:unparseBlock(stmt.body,tabbing)
        push("for",self:whitespace(),stmt.scope:getVariableName(stmt.id),self:optionalWhitespace(),"=")
        push(self:optionalWhitespace(),self:unparseExpression(stmt.initialValue,tabbing),",")
        push(self:optionalWhitespace(),self:unparseExpression(stmt.finalValue,tabbing),",")
        local ic=self:unparseExpression(stmt.incrementBy,tabbing)
        push(self:optionalWhitespace(),ic,self:whitespaceIfNeeded2(ic),
            "do",self:whitespaceIfNeeded(bc,self:newline(true)),
            bc,self:newline(false),self:whitespaceIfNeeded2(bc,self:tabs(tabbing,true)),"end")
    elseif k==AstKind.ForInStatement then
        push("for",self:whitespace())
        for i,id in ipairs(stmt.ids) do
            if i~=1 then push(",",self:optionalWhitespace()) end
            push(stmt.scope:getVariableName(id))
        end
        push(self:whitespace(),"in")
        local ec=self:unparseExpression(stmt.expressions[1],tabbing)
        push(self:whitespaceIfNeeded(ec),ec)
        for i=2,#stmt.expressions do
            ec=self:unparseExpression(stmt.expressions[i],tabbing)
            push(",",self:optionalWhitespace(),ec)
        end
        local bc=self:unparseBlock(stmt.body,tabbing)
        push(self:whitespaceIfNeeded2(#parts>0 and parts[#parts] or ""),
            "do",self:whitespaceIfNeeded(bc,self:newline(true)),
            bc,self:newline(false),self:whitespaceIfNeeded2(bc,self:tabs(tabbing,true)),"end")
    elseif k==AstKind.IfStatement then
        local ec=self:unparseExpression(stmt.condition,tabbing)
        local bc=self:unparseBlock(stmt.body,tabbing)
        push("if",self:whitespaceIfNeeded(ec),ec,self:whitespaceIfNeeded2(ec),"then",
            self:whitespaceIfNeeded(bc,self:newline(true)),bc)
        for _,eif in ipairs(stmt.elseifs) do
            ec=self:unparseExpression(eif.condition,tabbing)
            bc=self:unparseBlock(eif.body,tabbing)
            local lp=#parts>0 and parts[#parts] or ""
            push(self:newline(false),self:whitespaceIfNeeded2(lp,self:tabs(tabbing,true)),
                "elseif",self:whitespaceIfNeeded(ec),ec,self:whitespaceIfNeeded2(ec),
                "then",self:whitespaceIfNeeded(bc,self:newline(true)),bc)
        end
        if stmt.elsebody then
            bc=self:unparseBlock(stmt.elsebody,tabbing)
            local lp=#parts>0 and parts[#parts] or ""
            push(self:newline(false),self:whitespaceIfNeeded2(lp,self:tabs(tabbing,true)),
                "else",self:whitespaceIfNeeded(bc,self:newline(true)),bc)
        end
        push(self:newline(false),self:whitespaceIfNeeded2(bc or "",self:tabs(tabbing,true)),"end")
    elseif k==AstKind.FunctionDeclaration then
        local fn=stmt.scope:getVariableName(stmt.id)
        for _,idx in ipairs(stmt.indices) do fn=fn.."."..idx end
        push("function",self:whitespace(),fn,"(")
        for i,arg in ipairs(stmt.args) do
            if i>1 then push(",",self:optionalWhitespace()) end
            push(arg.kind==AstKind.VarargExpression and "..." or arg.scope:getVariableName(arg.id))
        end
        push(")")
        local bc=self:unparseBlock(stmt.body,tabbing)
        push(self:newline(false),bc,self:newline(false),
            self:whitespaceIfNeeded2(bc,self:tabs(tabbing,true)),"end")
    elseif k==AstKind.LocalFunctionDeclaration then
        local fn=stmt.scope:getVariableName(stmt.id)
        push("local",self:whitespace(),"function",self:whitespace(),fn,"(")
        for i,arg in ipairs(stmt.args) do
            if i>1 then push(",",self:optionalWhitespace()) end
            push(arg.kind==AstKind.VarargExpression and "..." or arg.scope:getVariableName(arg.id))
        end
        push(")")
        local bc=self:unparseBlock(stmt.body,tabbing)
        push(self:newline(false),bc,self:newline(false),
            self:whitespaceIfNeeded2(bc,self:tabs(tabbing,true)),"end")
    elseif k==AstKind.LocalVariableDeclaration then
        push("local",self:whitespace())
        for i,id in ipairs(stmt.ids) do
            if i>1 then push(",",self:optionalWhitespace()) end
            push(stmt.scope:getVariableName(id))
        end
        if #stmt.expressions>0 then
            push(self:optionalWhitespace(),"=",self:optionalWhitespace())
            for i,expr in ipairs(stmt.expressions) do
                if i>1 then push(",",self:optionalWhitespace()) end
                push(self:unparseExpression(expr,tabbing+1))
            end
        end
    elseif k==AstKind.FunctionCallStatement then
        local base=stmt.base
        if not (base.kind==AstKind.IndexExpression or base.kind==AstKind.VariableExpression) then
            push("(",self:unparseExpression(base,tabbing),")")
        else push(self:unparseExpression(base,tabbing)) end
        push("(")
        for i,arg in ipairs(stmt.args) do
            if i>1 then push(",",self:optionalWhitespace()) end
            push(self:unparseExpression(arg,tabbing))
        end
        push(")")
    elseif k==AstKind.PassSelfFunctionCallStatement then
        local base=stmt.base
        if not (base.kind==AstKind.IndexExpression or base.kind==AstKind.VariableExpression) then
            push("(",self:unparseExpression(base,tabbing),")")
        else push(self:unparseExpression(base,tabbing)) end
        push(":",stmt.passSelfFunctionName,"(")
        for i,arg in ipairs(stmt.args) do
            if i>1 then push(",",self:optionalWhitespace()) end
            push(self:unparseExpression(arg,tabbing))
        end
        push(")")
    elseif k==AstKind.AssignmentStatement then
        for i,pe in ipairs(stmt.lhs) do
            if i>1 then push(",",self:optionalWhitespace()) end
            push(self:unparseExpression(pe,tabbing))
        end
        push(self:optionalWhitespace(),"=",self:optionalWhitespace())
        for i,expr in ipairs(stmt.rhs) do
            if i>1 then push(",",self:optionalWhitespace()) end
            push(self:unparseExpression(expr,tabbing+1))
        end
    elseif k==AstKind.ReturnStatement then
        push("return")
        if #stmt.args>0 then
            local ec=self:unparseExpression(stmt.args[1],tabbing)
            push(self:whitespaceIfNeeded(ec),ec)
            for i=2,#stmt.args do
                ec=self:unparseExpression(stmt.args[i],tabbing)
                push(",",self:optionalWhitespace(),ec)
            end
        end
    else
        local compoundOps={
            [AstKind.CompoundAddStatement]="+=",
            [AstKind.CompoundSubStatement]="-=",
            [AstKind.CompoundMulStatement]="*=",
            [AstKind.CompoundDivStatement]="/=",
            [AstKind.CompoundModStatement]="%=",
            [AstKind.CompoundPowStatement]="^=",
            [AstKind.CompoundConcatStatement]="..=",
        }
        local op=compoundOps[k]
        if op then
            push(self:unparseExpression(stmt.lhs,tabbing),self:optionalWhitespace(),
                op,self:optionalWhitespace(),self:unparseExpression(stmt.rhs,tabbing))
        end
    end
    return self:tabs(tabbing,false)..join(parts)
end

function Unparser:unparseExpression(expr,tabbing)
    if expr.isParenthesizedExpression then
        local unwrapped={}
        for k,v in pairs(expr) do unwrapped[k]=v end
        unwrapped.isParenthesizedExpression=nil
        return "("..self:unparseExpression(unwrapped,tabbing)..")"
    end
    local parts={}
    local function push(...) for i=1,select("#",...) do parts[#parts+1]=select(i,...) end end
    local k=expr.kind
    if k==AstKind.BooleanExpression    then return expr.value and "true" or "false" end
    if k==AstKind.NilExpression        then return "nil" end
    if k==AstKind.VarargExpression     then return "..." end
    if k==AstKind.NumberExpression then
        local s=tostring(expr.value)
        if s=="inf"  then return "2e1024"  end
        if s=="-inf" then return "-2e1024" end
        if s:sub(1,2)=="0." then s=s:sub(2) end
        return s
    end
    if k==AstKind.VariableExpression or k==AstKind.AssignmentVariable then
        return expr.scope:getVariableName(expr.id)
    end
    if k==AstKind.StringExpression then return "\""..escStr(expr.value).."\"" end
    if k==AstKind.OrExpression then
        local l=self:unparseExpression(expr.lhs,tabbing)
        local r=self:unparseExpression(expr.rhs,tabbing)
        return l..self:whitespaceIfNeeded2(l).."or"..self:whitespaceIfNeeded(r)..r
    end
    if k==AstKind.AndExpression then
        local l=self:unparseExpression(expr.lhs,tabbing)
        if Ast.astKindExpressionToNumber(expr.lhs.kind)>=Ast.astKindExpressionToNumber(k) then l="("..l..")" end
        local r=self:unparseExpression(expr.rhs,tabbing)
        if Ast.astKindExpressionToNumber(expr.rhs.kind)>=Ast.astKindExpressionToNumber(k) then r="("..r..")" end
        return l..self:whitespaceIfNeeded2(l).."and"..self:whitespaceIfNeeded(r)..r
    end
    local cmpOps={
        [AstKind.LessThanExpression]="<",
        [AstKind.GreaterThanExpression]=">",
        [AstKind.LessThanOrEqualsExpression]="<=",
        [AstKind.GreaterThanOrEqualsExpression]=">=",
        [AstKind.NotEqualsExpression]="~=",
        [AstKind.EqualsExpression]="==",
    }
    local op=cmpOps[k]
    if op then
        local l=self:unparseExpression(expr.lhs,tabbing)
        if Ast.astKindExpressionToNumber(expr.lhs.kind)>=Ast.astKindExpressionToNumber(k) then l="("..l..")" end
        local r=self:unparseExpression(expr.rhs,tabbing)
        if Ast.astKindExpressionToNumber(expr.rhs.kind)>=Ast.astKindExpressionToNumber(k) then r="("..r..")" end
        return l..self:optionalWhitespace()..op..self:optionalWhitespace()..r
    end
    if k==AstKind.StrCatExpression then
        local l=self:unparseExpression(expr.lhs,tabbing)
        if Ast.astKindExpressionToNumber(expr.lhs.kind)>=Ast.astKindExpressionToNumber(k) then l="("..l..")" end
        local r=self:unparseExpression(expr.rhs,tabbing)
        if Ast.astKindExpressionToNumber(expr.rhs.kind)>=Ast.astKindExpressionToNumber(k) then r="("..r..")" end
        if self.numberCharsLookup[l:sub(#l,#l)] then l=l.." " end
        return l..self:optionalWhitespace()..(r:sub(1,1)=="." and ".. " or "..") ..self:optionalWhitespace()..r
    end
    local arithOps={
        [AstKind.AddExpression]="+",
        [AstKind.SubExpression]="-",
        [AstKind.MulExpression]="*",
        [AstKind.DivExpression]="/",
        [AstKind.ModExpression]="%",
        [AstKind.PowExpression]="^",
    }
    op=arithOps[k]
    if op then
        local l=self:unparseExpression(expr.lhs,tabbing)
        if Ast.astKindExpressionToNumber(expr.lhs.kind)>=Ast.astKindExpressionToNumber(k) then l="("..l..")" end
        local r=self:unparseExpression(expr.rhs,tabbing)
        if Ast.astKindExpressionToNumber(expr.rhs.kind)>=Ast.astKindExpressionToNumber(k) then r="("..r..")" end
        if op=="-" and r:sub(1,1)=="-" then r="("..r..")" end
        return l..self:optionalWhitespace()..op..self:optionalWhitespace()..r
    end
    if k==AstKind.NotExpression then
        local r=self:unparseExpression(expr.rhs,tabbing)
        if Ast.astKindExpressionToNumber(expr.rhs.kind)>=Ast.astKindExpressionToNumber(k) then r="("..r..")" end
        return "not"..self:whitespaceIfNeeded(r)..r
    end
    if k==AstKind.NegateExpression then
        local r=self:unparseExpression(expr.rhs,tabbing)
        if Ast.astKindExpressionToNumber(expr.rhs.kind)>=Ast.astKindExpressionToNumber(k) then r="("..r..")" end
        if r:sub(1,1)=="-" then r="("..r..")" end
        return "-"..r
    end
    if k==AstKind.LenExpression then
        local r=self:unparseExpression(expr.rhs,tabbing)
        if Ast.astKindExpressionToNumber(expr.rhs.kind)>=Ast.astKindExpressionToNumber(k) then r="("..r..")" end
        return "#"..r
    end
    if k==AstKind.IndexExpression or k==AstKind.AssignmentIndexing then
        local base=self:unparseExpression(expr.base,tabbing)
        local bk=expr.base.kind
        if bk==AstKind.VarargExpression or Ast.astKindExpressionToNumber(bk)>Ast.astKindExpressionToNumber(k)
            or bk==AstKind.StringExpression or bk==AstKind.NumberExpression or bk==AstKind.NilExpression then
            base="("..base..")"
        end
        if expr.index.kind==AstKind.StringExpression and self:isValidIdentifier(expr.index.value) then
            return base.."."..expr.index.value
        end
        return base.."["..self:unparseExpression(expr.index,tabbing).."]"
    end
    if k==AstKind.FunctionCallExpression then
        local base=expr.base
        if not (base.kind==AstKind.IndexExpression or base.kind==AstKind.VariableExpression) then
            push("(",self:unparseExpression(base,tabbing),")")
        else push(self:unparseExpression(base,tabbing)) end
        push("(")
        for i,arg in ipairs(expr.args) do
            if i>1 then push(",",self:optionalWhitespace()) end
            push(self:unparseExpression(arg,tabbing))
        end
        push(")")
        return join(parts)
    end
    if k==AstKind.PassSelfFunctionCallExpression then
        local base=expr.base
        if not (base.kind==AstKind.IndexExpression or base.kind==AstKind.VariableExpression) then
            push("(",self:unparseExpression(base,tabbing),")")
        else push(self:unparseExpression(base,tabbing)) end
        push(":",expr.passSelfFunctionName,"(")
        for i,arg in ipairs(expr.args) do
            if i>1 then push(",",self:optionalWhitespace()) end
            push(self:unparseExpression(arg,tabbing))
        end
        push(")")
        return join(parts)
    end
    if k==AstKind.FunctionLiteralExpression then
        push("function","(")
        for i,arg in ipairs(expr.args) do
            if i>1 then push(",",self:optionalWhitespace()) end
            push(arg.kind==AstKind.VarargExpression and "..." or arg.scope:getVariableName(arg.id))
        end
        push(")")
        local bc=self:unparseBlock(expr.body,tabbing)
        push(self:newline(false),bc,self:newline(false),
            self:whitespaceIfNeeded2(bc,self:tabs(tabbing,true)),"end")
        return join(parts)
    end
    if k==AstKind.TableConstructorExpression then
        if #expr.entries==0 then return "{}" end
        local inline=#expr.entries<=3
        local tt=tabbing+1
        push("{")
        if inline then push(self:optionalWhitespace())
        else push(self:optionalWhitespace(self:newline()..self:tabs(tt))) end
        local p=false
        for i,entry in ipairs(expr.entries) do
            p=true
            local sep=self.prettyPrint and "," or (math.random(1,2)==1 and "," or ";")
            if i>1 and not inline then push(sep,self:optionalWhitespace(self:newline()..self:tabs(tt)))
            elseif i>1 then push(sep,self:optionalWhitespace()) end
            if entry.kind==AstKind.KeyedTableEntry then
                if entry.key.kind==AstKind.StringExpression and self:isValidIdentifier(entry.key.value) then
                    push(entry.key.value)
                else
                    push("[",self:unparseExpression(entry.key,tt),"]")
                end
                push(self:optionalWhitespace(),"=",self:optionalWhitespace(),self:unparseExpression(entry.value,tt))
            else
                push(self:unparseExpression(entry.value,tt))
            end
        end
        if inline then return join(parts)..self:optionalWhitespace().."}" end
        return join(parts)..self:optionalWhitespace((p and "," or "")..self:newline()..self:tabs(tabbing)).."}"
    end
    if self.luaVersion=="LuaU" and k==AstKind.IfElseExpression then
        push("if ")
        push(self:unparseExpression(expr.condition))
        push(" then ")
        push(self:unparseExpression(expr.true_value))
        push(" else ")
        push(self:unparseExpression(expr.false_value))
        return join(parts)
    end
    logger:error(string.format("\"%s\" is not a valid expression",k))
end

return Unparser
