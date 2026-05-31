local Ast = {}
local AstKind = {
    TopNode="TopNode", Block="Block",
    ContinueStatement="ContinueStatement", BreakStatement="BreakStatement",
    DoStatement="DoStatement", WhileStatement="WhileStatement",
    ReturnStatement="ReturnStatement", RepeatStatement="RepeatStatement",
    ForInStatement="ForInStatement", ForStatement="ForStatement",
    IfStatement="IfStatement", FunctionDeclaration="FunctionDeclaration",
    LocalFunctionDeclaration="LocalFunctionDeclaration",
    LocalVariableDeclaration="LocalVariableDeclaration",
    FunctionCallStatement="FunctionCallStatement",
    PassSelfFunctionCallStatement="PassSelfFunctionCallStatement",
    AssignmentStatement="AssignmentStatement",
    CompoundAddStatement="CompoundAddStatement",
    CompoundSubStatement="CompoundSubStatement",
    CompoundMulStatement="CompoundMulStatement",
    CompoundDivStatement="CompoundDivStatement",
    CompoundModStatement="CompoundModStatement",
    CompoundPowStatement="CompoundPowStatement",
    CompoundConcatStatement="CompoundConcatStatement",
    AssignmentIndexing="AssignmentIndexing",
    AssignmentVariable="AssignmentVariable",
    BooleanExpression="BooleanExpression",
    NumberExpression="NumberExpression",
    StringExpression="StringExpression",
    NilExpression="NilExpression",
    VarargExpression="VarargExpression",
    OrExpression="OrExpression", AndExpression="AndExpression",
    LessThanExpression="LessThanExpression",
    GreaterThanExpression="GreaterThanExpression",
    LessThanOrEqualsExpression="LessThanOrEqualsExpression",
    GreaterThanOrEqualsExpression="GreaterThanOrEqualsExpression",
    NotEqualsExpression="NotEqualsExpression",
    EqualsExpression="EqualsExpression",
    StrCatExpression="StrCatExpression",
    AddExpression="AddExpression", SubExpression="SubExpression",
    MulExpression="MulExpression", DivExpression="DivExpression",
    ModExpression="ModExpression", NotExpression="NotExpression",
    LenExpression="LenExpression", NegateExpression="NegateExpression",
    PowExpression="PowExpression", IndexExpression="IndexExpression",
    FunctionCallExpression="FunctionCallExpression",
    PassSelfFunctionCallExpression="PassSelfFunctionCallExpression",
    VariableExpression="VariableExpression",
    FunctionLiteralExpression="FunctionLiteralExpression",
    TableConstructorExpression="TableConstructorExpression",
    TableEntry="TableEntry", KeyedTableEntry="KeyedTableEntry",
    NopStatement="NopStatement",
    IfElseExpression="IfElseExpression",
}
Ast.AstKind = AstKind

local exprPriority = {
    [AstKind.BooleanExpression]=0,[AstKind.NumberExpression]=0,
    [AstKind.StringExpression]=0,[AstKind.NilExpression]=0,
    [AstKind.VarargExpression]=0,
    [AstKind.OrExpression]=12,[AstKind.AndExpression]=11,
    [AstKind.LessThanExpression]=10,[AstKind.GreaterThanExpression]=10,
    [AstKind.LessThanOrEqualsExpression]=10,[AstKind.GreaterThanOrEqualsExpression]=10,
    [AstKind.NotEqualsExpression]=10,[AstKind.EqualsExpression]=10,
    [AstKind.StrCatExpression]=9,
    [AstKind.AddExpression]=8,[AstKind.SubExpression]=8,
    [AstKind.MulExpression]=7,[AstKind.DivExpression]=7,[AstKind.ModExpression]=7,
    [AstKind.NotExpression]=5,[AstKind.LenExpression]=5,[AstKind.NegateExpression]=5,
    [AstKind.PowExpression]=4,
    [AstKind.IndexExpression]=1,[AstKind.AssignmentIndexing]=1,
    [AstKind.FunctionCallExpression]=2,[AstKind.PassSelfFunctionCallExpression]=2,
    [AstKind.VariableExpression]=0,[AstKind.AssignmentVariable]=0,
    [AstKind.FunctionLiteralExpression]=3,[AstKind.TableConstructorExpression]=3,
}
function Ast.astKindExpressionToNumber(k) return exprPriority[k] or 100 end

function Ast.ConstantNode(v)
    if v == nil      then return Ast.NilExpression() end
    if type(v) == "string"  then return Ast.StringExpression(v) end
    if type(v) == "number"  then return Ast.NumberExpression(v) end
    if type(v) == "boolean" then return Ast.BooleanExpression(v) end
end
function Ast.NopStatement()         return {kind=AstKind.NopStatement} end
function Ast.TopNode(body,gs)       return {kind=AstKind.TopNode,body=body,globalScope=gs} end
function Ast.Block(stmts,scope)     return {kind=AstKind.Block,statements=stmts,scope=scope} end
function Ast.TableEntry(v)          return {kind=AstKind.TableEntry,value=v} end
function Ast.KeyedTableEntry(k,v)   return {kind=AstKind.KeyedTableEntry,key=k,value=v} end
function Ast.TableConstructorExpression(e) return {kind=AstKind.TableConstructorExpression,entries=e} end
function Ast.BreakStatement(loop,scope) return {kind=AstKind.BreakStatement,loop=loop,scope=scope} end
function Ast.ContinueStatement(loop,sc) return {kind=AstKind.ContinueStatement,loop=loop,scope=sc} end
function Ast.DoStatement(body)      return {kind=AstKind.DoStatement,body=body} end
function Ast.ReturnStatement(args)  return {kind=AstKind.ReturnStatement,args=args} end
function Ast.WhileStatement(body,cond,ps) return {kind=AstKind.WhileStatement,body=body,condition=cond,parentScope=ps} end
function Ast.RepeatStatement(cond,body,ps) return {kind=AstKind.RepeatStatement,body=body,condition=cond,parentScope=ps} end
function Ast.ForStatement(scope,id,init,final,inc,body,ps)
    return {kind=AstKind.ForStatement,scope=scope,id=id,initialValue=init,finalValue=final,incrementBy=inc,body=body,parentScope=ps}
end
function Ast.ForInStatement(scope,vars,exprs,body,ps)
    return {kind=AstKind.ForInStatement,scope=scope,ids=vars,vars=vars,expressions=exprs,body=body,parentScope=ps}
end
function Ast.IfStatement(cond,body,elseifs,elsebody)
    return {kind=AstKind.IfStatement,condition=cond,body=body,elseifs=elseifs,elsebody=elsebody}
end
function Ast.AssignmentStatement(lhs,rhs)
    assert(#lhs >= 1)
    return {kind=AstKind.AssignmentStatement,lhs=lhs,rhs=rhs}
end
function Ast.CompoundAddStatement(l,r)    return {kind=AstKind.CompoundAddStatement,lhs=l,rhs=r} end
function Ast.CompoundSubStatement(l,r)    return {kind=AstKind.CompoundSubStatement,lhs=l,rhs=r} end
function Ast.CompoundMulStatement(l,r)    return {kind=AstKind.CompoundMulStatement,lhs=l,rhs=r} end
function Ast.CompoundDivStatement(l,r)    return {kind=AstKind.CompoundDivStatement,lhs=l,rhs=r} end
function Ast.CompoundModStatement(l,r)    return {kind=AstKind.CompoundModStatement,lhs=l,rhs=r} end
function Ast.CompoundPowStatement(l,r)    return {kind=AstKind.CompoundPowStatement,lhs=l,rhs=r} end
function Ast.CompoundConcatStatement(l,r) return {kind=AstKind.CompoundConcatStatement,lhs=l,rhs=r} end
function Ast.FunctionCallStatement(base,args)
    return {kind=AstKind.FunctionCallStatement,base=base,args=args}
end
function Ast.PassSelfFunctionCallStatement(base,name,args)
    return {kind=AstKind.PassSelfFunctionCallStatement,base=base,passSelfFunctionName=name,args=args}
end
function Ast.FunctionDeclaration(scope,id,indices,args,body)
    return {kind=AstKind.FunctionDeclaration,scope=scope,baseScope=scope,id=id,baseId=id,indices=indices,args=args,body=body,
        getName=function(self) return self.scope:getVariableName(self.id) end}
end
function Ast.LocalFunctionDeclaration(scope,id,args,body)
    return {kind=AstKind.LocalFunctionDeclaration,scope=scope,id=id,args=args,body=body,
        getName=function(self) return self.scope:getVariableName(self.id) end}
end
function Ast.LocalVariableDeclaration(scope,ids,exprs)
    return {kind=AstKind.LocalVariableDeclaration,scope=scope,ids=ids,expressions=exprs}
end
function Ast.VarargExpression()     return {kind=AstKind.VarargExpression,isConstant=false} end
function Ast.NilExpression()        return {kind=AstKind.NilExpression,isConstant=true,value=nil} end
function Ast.BooleanExpression(v)   return {kind=AstKind.BooleanExpression,isConstant=true,value=v} end
function Ast.NumberExpression(v)    return {kind=AstKind.NumberExpression,isConstant=true,value=v} end
function Ast.StringExpression(v)    return {kind=AstKind.StringExpression,isConstant=true,value=v} end

local function binConst(kind,l,r,op)
    if l.isConstant and r.isConstant then
        local ok,v = pcall(op,l.value,r.value)
        if ok then return Ast.ConstantNode(v) end
    end
    return {kind=kind,lhs=l,rhs=r,isConstant=false}
end
function Ast.OrExpression(l,r,s)
    if s then return binConst(AstKind.OrExpression,l,r,function(a,b) return a or b end) end
    return {kind=AstKind.OrExpression,lhs=l,rhs=r,isConstant=false}
end
function Ast.AndExpression(l,r,s)
    if s then return binConst(AstKind.AndExpression,l,r,function(a,b) return a and b end) end
    return {kind=AstKind.AndExpression,lhs=l,rhs=r,isConstant=false}
end
function Ast.LessThanExpression(l,r,s)
    if s then return binConst(AstKind.LessThanExpression,l,r,function(a,b) return a<b end) end
    return {kind=AstKind.LessThanExpression,lhs=l,rhs=r,isConstant=false}
end
function Ast.GreaterThanExpression(l,r,s)
    if s then return binConst(AstKind.GreaterThanExpression,l,r,function(a,b) return a>b end) end
    return {kind=AstKind.GreaterThanExpression,lhs=l,rhs=r,isConstant=false}
end
function Ast.LessThanOrEqualsExpression(l,r,s)
    if s then return binConst(AstKind.LessThanOrEqualsExpression,l,r,function(a,b) return a<=b end) end
    return {kind=AstKind.LessThanOrEqualsExpression,lhs=l,rhs=r,isConstant=false}
end
function Ast.GreaterThanOrEqualsExpression(l,r,s)
    if s then return binConst(AstKind.GreaterThanOrEqualsExpression,l,r,function(a,b) return a>=b end) end
    return {kind=AstKind.GreaterThanOrEqualsExpression,lhs=l,rhs=r,isConstant=false}
end
function Ast.NotEqualsExpression(l,r,s)
    if s then return binConst(AstKind.NotEqualsExpression,l,r,function(a,b) return a~=b end) end
    return {kind=AstKind.NotEqualsExpression,lhs=l,rhs=r,isConstant=false}
end
function Ast.EqualsExpression(l,r,s)
    if s then return binConst(AstKind.EqualsExpression,l,r,function(a,b) return a==b end) end
    return {kind=AstKind.EqualsExpression,lhs=l,rhs=r,isConstant=false}
end
function Ast.StrCatExpression(l,r,s)
    if s then return binConst(AstKind.StrCatExpression,l,r,function(a,b) return a..b end) end
    return {kind=AstKind.StrCatExpression,lhs=l,rhs=r,isConstant=false}
end
function Ast.AddExpression(l,r,s)
    if s then return binConst(AstKind.AddExpression,l,r,function(a,b) return a+b end) end
    return {kind=AstKind.AddExpression,lhs=l,rhs=r,isConstant=false}
end
function Ast.SubExpression(l,r,s)
    if s then return binConst(AstKind.SubExpression,l,r,function(a,b) return a-b end) end
    return {kind=AstKind.SubExpression,lhs=l,rhs=r,isConstant=false}
end
function Ast.MulExpression(l,r,s)
    if s then return binConst(AstKind.MulExpression,l,r,function(a,b) return a*b end) end
    return {kind=AstKind.MulExpression,lhs=l,rhs=r,isConstant=false}
end
function Ast.DivExpression(l,r,s)
    if s and r.value ~= 0 then return binConst(AstKind.DivExpression,l,r,function(a,b) return a/b end) end
    return {kind=AstKind.DivExpression,lhs=l,rhs=r,isConstant=false}
end
function Ast.ModExpression(l,r,s)
    if s then return binConst(AstKind.ModExpression,l,r,function(a,b) return a%b end) end
    return {kind=AstKind.ModExpression,lhs=l,rhs=r,isConstant=false}
end
function Ast.PowExpression(l,r,s)
    if s then return binConst(AstKind.PowExpression,l,r,function(a,b) return a^b end) end
    return {kind=AstKind.PowExpression,lhs=l,rhs=r,isConstant=false}
end
function Ast.NotExpression(r,s)
    if s and r.isConstant then
        local ok,v = pcall(function() return not r.value end)
        if ok then return Ast.ConstantNode(v) end
    end
    return {kind=AstKind.NotExpression,rhs=r,isConstant=false}
end
function Ast.NegateExpression(r,s)
    if s and r.isConstant then
        local ok,v = pcall(function() return -r.value end)
        if ok then return Ast.ConstantNode(v) end
    end
    return {kind=AstKind.NegateExpression,rhs=r,isConstant=false}
end
function Ast.LenExpression(r,s)
    if s and r.isConstant then
        local ok,v = pcall(function() return #r.value end)
        if ok then return Ast.ConstantNode(v) end
    end
    return {kind=AstKind.LenExpression,rhs=r,isConstant=false}
end
function Ast.IndexExpression(base,idx)
    return {kind=AstKind.IndexExpression,base=base,index=idx,isConstant=false}
end
function Ast.AssignmentIndexing(base,idx)
    return {kind=AstKind.AssignmentIndexing,base=base,index=idx,isConstant=false}
end
function Ast.FunctionCallExpression(base,args)
    return {kind=AstKind.FunctionCallExpression,base=base,args=args}
end
function Ast.PassSelfFunctionCallExpression(base,name,args)
    return {kind=AstKind.PassSelfFunctionCallExpression,base=base,passSelfFunctionName=name,args=args}
end
function Ast.FunctionLiteralExpression(args,body)
    return {kind=AstKind.FunctionLiteralExpression,args=args,body=body}
end
function Ast.VariableExpression(scope,id)
    scope:addReference(id)
    return {kind=AstKind.VariableExpression,scope=scope,id=id,
        getName=function(self) return self.scope:getVariableName(self.id) end}
end
function Ast.AssignmentVariable(scope,id)
    scope:addReference(id)
    return {kind=AstKind.AssignmentVariable,scope=scope,id=id,
        getName=function(self) return self.scope:getVariableName(self.id) end}
end
function Ast.IfElseExpression(cond,tv,fv)
    return {kind=AstKind.IfElseExpression,condition=cond,true_value=tv,false_value=fv}
end

return Ast
