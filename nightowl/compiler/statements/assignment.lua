 
return function(self, statement, funcDepth)
 
    local scope = self.activeBlock.scope
 
    local Ast = self.Ast
 
    local AstKind = Ast.AstKind
 
    local exprregs = {}
 
    local indexingRegs = {}
 
 
    for i, pe in ipairs(statement.lhs) do
 
        if pe.kind == AstKind.AssignmentIndexing then
 
            indexingRegs[i] = {
 
                base  = self:compileExpression(pe.base,  funcDepth, 1)[1],
 
                index = self:compileExpression(pe.index, funcDepth, 1)[1],
 
            }
 
        end
 
    end
 
 
    for i, expr in ipairs(statement.rhs) do
 
        if i == #statement.rhs and #statement.lhs > #statement.rhs then
 
            local regs = self:compileExpression(expr, funcDepth, #statement.lhs - #statement.rhs + 1)
 
            for _, reg in ipairs(regs) do
 
                if self:isVarRegister(reg) then
 
                    local ro = reg
 
                    reg = self:allocRegister(false)
 
                    self:addStatement(self:copyRegisters(scope, {reg}, {ro}), {reg}, {ro}, false)
 
                end
 
                table.insert(exprregs, reg)
 
            end
 
        else
 
            if statement.lhs[i] or expr.kind == AstKind.FunctionCallExpression or expr.kind == AstKind.PassSelfFunctionCallExpression then
 
                local reg = self:compileExpression(expr, funcDepth, 1)[1]
 
                if self:isVarRegister(reg) then
 
                    local ro = reg
 
                    reg = self:allocRegister(false)
 
                    self:addStatement(self:copyRegisters(scope, {reg}, {ro}), {reg}, {ro}, false)
 
                end
 
                table.insert(exprregs, reg)
 
            end
 
        end
 
    end
 
 
    for i, pe in ipairs(statement.lhs) do
 
        if pe.kind == AstKind.AssignmentVariable then
 
            if pe.scope.isGlobal then
 
                local tmpReg = self:allocRegister(false)
 
                self:addStatement(self:setRegister(scope, tmpReg,
 
                    Ast.StringExpression(pe.scope:getVariableName(pe.id))), {tmpReg}, {}, false)
 
                self:addStatement(Ast.AssignmentStatement(
 
                    { Ast.AssignmentIndexing(self:env(scope), self:register(scope, tmpReg)) },
 
                    { self:register(scope, exprregs[i]) }
 
                ), {}, {tmpReg, exprregs[i]}, true)
 
                self:freeRegister(tmpReg, false)
 
            else
 
                if self.scopeFunctionDepths[pe.scope] == funcDepth then
 
                    if self:isUpvalue(pe.scope, pe.id) then
 
                        local reg = self:getVarRegister(pe.scope, pe.id, funcDepth)
 
                        self:addStatement(self:setUpvalueMember(scope,
 
                            self:register(scope, reg), self:register(scope, exprregs[i])),
 
                            {}, {reg, exprregs[i]}, true)
 
                    else
 
                        local reg = self:getVarRegister(pe.scope, pe.id, funcDepth, exprregs[i])
 
                        if reg ~= exprregs[i] then
 
                            self:addStatement(self:setRegister(scope, reg, self:register(scope, exprregs[i])), {reg}, {exprregs[i]}, false)
 
                        end
 
                    end
 
                else
 
                    local upvalId = self:getUpvalueId(pe.scope, pe.id)
 
                    scope:addReferenceToHigherScope(self.containerFuncScope, self.currentUpvaluesVar)
 
                    self:addStatement(self:setUpvalueMember(scope,
 
                        Ast.IndexExpression(
 
                            Ast.VariableExpression(self.containerFuncScope, self.currentUpvaluesVar),
 
                            Ast.NumberExpression(upvalId)
 
                        ),
 
                        self:register(scope, exprregs[i])),
 
                        {}, {exprregs[i]}, true)
 
                end
 
            end
 
        elseif pe.kind == AstKind.AssignmentIndexing then
 
            local baseReg  = indexingRegs[i].base
 
            local indexReg = indexingRegs[i].index
 
            self:addStatement(Ast.AssignmentStatement(
 
                { Ast.AssignmentIndexing(self:register(scope, baseReg), self:register(scope, indexReg)) },
 
                { self:register(scope, exprregs[i]) }
 
            ), {}, {exprregs[i], baseReg, indexReg}, true)
 
            self:freeRegister(exprregs[i], false)
 
            self:freeRegister(baseReg,     false)
 
            self:freeRegister(indexReg,    false)
 
        end
 
    end
 
end
 
