local Ast     = require("nightowl.ast")
local util    = require("nightowl.util")

local AstKind = Ast.AstKind
local lookupify = util.lookupify

local visitAst, visitBlock, visitStatement, visitExpression

local compoundStats = lookupify{
    AstKind.CompoundAddStatement, AstKind.CompoundSubStatement,
    AstKind.CompoundMulStatement, AstKind.CompoundDivStatement,
    AstKind.CompoundModStatement, AstKind.CompoundPowStatement,
    AstKind.CompoundConcatStatement,
}

local binaryExprs = lookupify{
    AstKind.OrExpression, AstKind.AndExpression,
    AstKind.LessThanExpression, AstKind.GreaterThanExpression,
    AstKind.LessThanOrEqualsExpression, AstKind.GreaterThanOrEqualsExpression,
    AstKind.NotEqualsExpression, AstKind.EqualsExpression,
    AstKind.StrCatExpression,
    AstKind.AddExpression, AstKind.SubExpression,
    AstKind.MulExpression, AstKind.DivExpression,
    AstKind.ModExpression, AstKind.PowExpression,
}

function visitAst(ast,pre,post,data)
    ast.isAst=true
    data=data or {}
    data.scopeStack={}
    data.functionData={depth=0,scope=ast.body.scope,node=ast}
    data.scope=ast.globalScope
    data.globalScope=ast.globalScope
    if type(pre)=="function" then
        local node,skip=pre(ast,data)
        ast=node or ast
        if skip then return ast end
    end
    visitBlock(ast.body,pre,post,data,true)
    if type(post)=="function" then ast=post(ast,data) or ast end
    return ast
end

function visitBlock(block,pre,post,data,isFunctionBlock)
    block.isBlock=true
    block.isFunctionBlock=isFunctionBlock or false
    data.scope=block.scope
    local parentBlockData=data.blockData
    data.blockData={}
    table.insert(data.scopeStack,block.scope)
    if type(pre)=="function" then
        local node,skip=pre(block,data)
        block=node or block
        if skip then
            data.scope=table.remove(data.scopeStack)
            return block
        end
    end
    local i=1
    while i<=#block.statements do
        local stmt=table.remove(block.statements,i)
        i=i-1
        local returned={visitStatement(stmt,pre,post,data)}
        for _,s in ipairs(returned) do
            i=i+1
            table.insert(block.statements,i,s)
        end
        i=i+1
    end
    if type(post)=="function" then block=post(block,data) or block end
    data.scope=table.remove(data.scopeStack)
    data.blockData=parentBlockData
    return block
end

function visitStatement(stmt,pre,post,data)
    stmt.isStatement=true
    if type(pre)=="function" then
        local node,skip=pre(stmt,data)
        stmt=node or stmt
        if skip then return stmt end
    end
    local k=stmt.kind
    if k==AstKind.ReturnStatement then
        for i,e in ipairs(stmt.args) do stmt.args[i]=visitExpression(e,pre,post,data) end
    elseif k==AstKind.FunctionCallStatement or k==AstKind.PassSelfFunctionCallStatement then
        stmt.base=visitExpression(stmt.base,pre,post,data)
        for i,e in ipairs(stmt.args) do stmt.args[i]=visitExpression(e,pre,post,data) end
    elseif k==AstKind.AssignmentStatement then
        for i,e in ipairs(stmt.lhs) do stmt.lhs[i]=visitExpression(e,pre,post,data) end
        for i,e in ipairs(stmt.rhs) do stmt.rhs[i]=visitExpression(e,pre,post,data) end
    elseif k==AstKind.FunctionDeclaration or k==AstKind.LocalFunctionDeclaration then
        local pfd=data.functionData
        data.functionData={depth=pfd.depth+1,scope=stmt.body.scope,node=stmt}
        stmt.body=visitBlock(stmt.body,pre,post,data,true)
        data.functionData=pfd
    elseif k==AstKind.DoStatement then
        stmt.body=visitBlock(stmt.body,pre,post,data,false)
    elseif k==AstKind.WhileStatement then
        stmt.condition=visitExpression(stmt.condition,pre,post,data)
        stmt.body=visitBlock(stmt.body,pre,post,data,false)
    elseif k==AstKind.RepeatStatement then
        stmt.body=visitBlock(stmt.body,pre,post,data)
        stmt.condition=visitExpression(stmt.condition,pre,post,data)
    elseif k==AstKind.ForStatement then
        stmt.initialValue=visitExpression(stmt.initialValue,pre,post,data)
        stmt.finalValue=visitExpression(stmt.finalValue,pre,post,data)
        stmt.incrementBy=visitExpression(stmt.incrementBy,pre,post,data)
        stmt.body=visitBlock(stmt.body,pre,post,data,false)
    elseif k==AstKind.ForInStatement then
        for i,e in ipairs(stmt.expressions) do stmt.expressions[i]=visitExpression(e,pre,post,data) end
        visitBlock(stmt.body,pre,post,data,false)
    elseif k==AstKind.IfStatement then
        stmt.condition=visitExpression(stmt.condition,pre,post,data)
        stmt.body=visitBlock(stmt.body,pre,post,data,false)
        for _,eif in ipairs(stmt.elseifs) do
            eif.condition=visitExpression(eif.condition,pre,post,data)
            eif.body=visitBlock(eif.body,pre,post,data,false)
        end
        if stmt.elsebody then stmt.elsebody=visitBlock(stmt.elsebody,pre,post,data,false) end
    elseif k==AstKind.LocalVariableDeclaration then
        for i,e in ipairs(stmt.expressions) do stmt.expressions[i]=visitExpression(e,pre,post,data) end
    elseif compoundStats[k] then
        stmt.lhs=visitExpression(stmt.lhs,pre,post,data)
        stmt.rhs=visitExpression(stmt.rhs,pre,post,data)
    end
    if type(post)=="function" then
        local stmts={post(stmt,data)}
        if #stmts>0 then return table.unpack(stmts) end
    end
    return stmt
end

function visitExpression(expr,pre,post,data)
    expr.isExpression=true
    if type(pre)=="function" then
        local node,skip=pre(expr,data)
        expr=node or expr
        if skip then return expr end
    end
    local k=expr.kind
    if binaryExprs[k] then
        expr.lhs=visitExpression(expr.lhs,pre,post,data)
        expr.rhs=visitExpression(expr.rhs,pre,post,data)
    end
    if k==AstKind.NotExpression or k==AstKind.NegateExpression or k==AstKind.LenExpression then
        expr.rhs=visitExpression(expr.rhs,pre,post,data)
    end
    if k==AstKind.FunctionCallExpression or k==AstKind.PassSelfFunctionCallExpression then
        expr.base=visitExpression(expr.base,pre,post,data)
        for i,a in ipairs(expr.args) do expr.args[i]=visitExpression(a,pre,post,data) end
    end
    if k==AstKind.FunctionLiteralExpression then
        local pfd=data.functionData
        data.functionData={depth=pfd.depth+1,scope=expr.body.scope,node=expr}
        expr.body=visitBlock(expr.body,pre,post,data,true)
        data.functionData=pfd
    end
    if k==AstKind.TableConstructorExpression then
        for _,entry in ipairs(expr.entries) do
            if entry.kind==AstKind.KeyedTableEntry then
                entry.key=visitExpression(entry.key,pre,post,data)
            end
            entry.value=visitExpression(entry.value,pre,post,data)
        end
    end
    if k==AstKind.IndexExpression or k==AstKind.AssignmentIndexing then
        expr.base=visitExpression(expr.base,pre,post,data)
        expr.index=visitExpression(expr.index,pre,post,data)
    end
    if k==AstKind.IfElseExpression then
        expr.condition=visitExpression(expr.condition,pre,post,data)
        expr.true_value=visitExpression(expr.true_value,pre,post,data)
        expr.false_value=visitExpression(expr.false_value,pre,post,data)
    end
    if type(post)=="function" then expr=post(expr,data) or expr end
    return expr
end

return visitAst
