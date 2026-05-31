 
return function(self, expression, funcDepth, numReturns)
 
    local scope = self.activeBlock.scope
 
    local Ast = self.Ast
 
    local regs = {}
 
    for i = 1, numReturns do
 
        regs[i] = self:allocRegister()
 
        self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), {regs[i]}, {}, false)
 
    end
 
    return regs
 
end
 
