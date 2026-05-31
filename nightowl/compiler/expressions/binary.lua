 
return function(self, expression, funcDepth, numReturns)
 
    local scope = self.activeBlock.scope
 
    local Ast = self.Ast
 
    local regs = {}
 
    for i = 1, numReturns do
 
        regs[i] = self:allocRegister()
 
        if i == 1 then
 
            local lhsReg = self:compileExpression(expression.lhs, funcDepth, 1)[1]
 
            local rhsReg = self:compileExpression(expression.rhs, funcDepth, 1)[1]
 
            local binaryExpr = Ast[expression.kind](self:register(scope, lhsReg), self:register(scope, rhsReg))
 
            self:addStatement(self:setRegister(scope, regs[i], binaryExpr), {regs[i]}, {lhsReg, rhsReg}, true)
 
            self:freeRegister(rhsReg, false)
 
            self:freeRegister(lhsReg, false)
 
        else
 
            self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), {regs[i]}, {}, false)
 
        end
 
    end
 
    return regs
 
end
 
