 
return function(self, statement, funcDepth)
 
    local scope = self.activeBlock.scope
 
    local Ast = self.Ast
 
    local AstKind = Ast.AstKind
 
    local unpack = table.unpack or unpack
 
 
    local baseReg = self:compileExpression(statement.base, funcDepth, 1)[1]
 
    local retReg  = self:allocRegister(false)
 
    local regs, args = {}, {}
 
 
    for i, expr in ipairs(statement.args) do
 
        if i == #statement.args and (
 
            expr.kind == AstKind.FunctionCallExpression or
 
            expr.kind == AstKind.PassSelfFunctionCallExpression or
 
            expr.kind == AstKind.VarargExpression
 
        ) then
 
            local reg = self:compileExpression(expr, funcDepth, self.RETURN_ALL)[1]
 
            table.insert(args, Ast.FunctionCallExpression(self:unpack(scope), { self:register(scope, reg) }))
 
            table.insert(regs, reg)
 
        else
 
            local reg = self:compileExpression(expr, funcDepth, 1)[1]
 
            table.insert(args, self:register(scope, reg))
 
            table.insert(regs, reg)
 
        end
 
    end
 
 
    self:addStatement(self:setRegister(scope, retReg,
 
        Ast.FunctionCallExpression(self:register(scope, baseReg), args)),
 
        {retReg}, {baseReg, unpack(regs)}, true)
 
    self:freeRegister(baseReg, false)
 
    self:freeRegister(retReg,  false)
 
    for _, reg in ipairs(regs) do self:freeRegister(reg, false) end
 
end
 
