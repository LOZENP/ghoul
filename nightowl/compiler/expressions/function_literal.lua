 
return function(self, expression, funcDepth, numReturns)
 
    local scope = self.activeBlock.scope
 
    local Ast = self.Ast
 
    local regs = {}
 
    for i = 1, numReturns do
 
        if i == 1 then
 
            regs[i] = self:compileFunction(expression, funcDepth)
 
        else
 
            regs[i] = self:allocRegister()
 
            self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), {regs[i]}, {}, false)
 
        end
 
    end
 
    return regs
 
end
 
