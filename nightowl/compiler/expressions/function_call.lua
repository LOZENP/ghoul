 
return function(self, expression, funcDepth, numReturns)
 
    local scope = self.activeBlock.scope
 
    local Ast = self.Ast
 
    local AstKind = Ast.AstKind
 
    local baseReg = self:compileExpression(expression.base, funcDepth, 1)[1]
 
    local retRegs = {}
 
    local returnAll = numReturns == self.RETURN_ALL
 
    if returnAll then
 
        retRegs[1] = self:allocRegister(false)
 
    else
 
        for i = 1, numReturns do retRegs[i] = self:allocRegister(false) end
 
    end
 
 
    local regs, args = {}, {}
 
    for i, expr in ipairs(expression.args) do
 
        if i == #expression.args and (
 
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
 
 
    local unpack = table.unpack or unpack
 
 
    if returnAll then
 
        self:addStatement(self:setRegister(scope, retRegs[1],
 
            Ast.TableConstructorExpression({ Ast.TableEntry(
 
                Ast.FunctionCallExpression(self:register(scope, baseReg), args)
 
            )})),
 
            {retRegs[1]}, {baseReg, unpack(regs)}, true)
 
    elseif numReturns > 1 then
 
        local tmpReg = self:allocRegister(false)
 
        self:addStatement(self:setRegister(scope, tmpReg,
 
            Ast.TableConstructorExpression({ Ast.TableEntry(
 
                Ast.FunctionCallExpression(self:register(scope, baseReg), args)
 
            )})),
 
            {tmpReg}, {baseReg, unpack(regs)}, true)
 
        for i, reg in ipairs(retRegs) do
 
            self:addStatement(self:setRegister(scope, reg,
 
                Ast.IndexExpression(self:register(scope, tmpReg), Ast.NumberExpression(i))),
 
                {reg}, {tmpReg}, false)
 
        end
 
        self:freeRegister(tmpReg, false)
 
    else
 
        self:addStatement(self:setRegister(scope, retRegs[1],
 
            Ast.FunctionCallExpression(self:register(scope, baseReg), args)),
 
            {retRegs[1]}, {baseReg, unpack(regs)}, true)
 
    end
 
 
    self:freeRegister(baseReg, false)
 
    for _, reg in ipairs(regs) do self:freeRegister(reg, false) end
 
    return retRegs
 
end
 
