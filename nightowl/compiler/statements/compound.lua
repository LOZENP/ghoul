 
return function(self, statement, funcDepth)
 
    local scope = self.activeBlock.scope
 
    local Ast = self.Ast
 
    local AstKind = Ast.AstKind
 
 
    local compoundConstructors = {
 
        [AstKind.CompoundAddStatement]    = Ast.CompoundAddStatement,
 
        [AstKind.CompoundSubStatement]    = Ast.CompoundSubStatement,
 
        [AstKind.CompoundMulStatement]    = Ast.CompoundMulStatement,
 
        [AstKind.CompoundDivStatement]    = Ast.CompoundDivStatement,
 
        [AstKind.CompoundModStatement]    = Ast.CompoundModStatement,
 
        [AstKind.CompoundPowStatement]    = Ast.CompoundPowStatement,
 
        [AstKind.CompoundConcatStatement] = Ast.CompoundConcatStatement,
 
    }
 
 
    local ctor = compoundConstructors[statement.kind]
 
 
    if statement.lhs.kind == AstKind.AssignmentIndexing then
 
        local baseReg  = self:compileExpression(statement.lhs.base,  funcDepth, 1)[1]
 
        local indexReg = self:compileExpression(statement.lhs.index, funcDepth, 1)[1]
 
        local valueReg = self:compileExpression(statement.rhs,       funcDepth, 1)[1]
 
        self:addStatement(ctor(
 
            Ast.AssignmentIndexing(self:register(scope, baseReg), self:register(scope, indexReg)),
 
            self:register(scope, valueReg)
 
        ), {}, {baseReg, indexReg, valueReg}, true)
 
        self:freeRegister(baseReg,  false)
 
        self:freeRegister(indexReg, false)
 
        self:freeRegister(valueReg, false)
 
    else
 
        local valueReg = self:compileExpression(statement.rhs, funcDepth, 1)[1]
 
        local pe = statement.lhs
 
        if pe.scope.isGlobal then
 
            local tmpReg = self:allocRegister(false)
 
            self:addStatement(self:setRegister(scope, tmpReg,
 
                Ast.StringExpression(pe.scope:getVariableName(pe.id))), {tmpReg}, {}, false)
 
            self:addStatement(ctor(
 
                Ast.AssignmentIndexing(self:env(scope), self:register(scope, tmpReg)),
 
                self:register(scope, valueReg)
 
            ), {}, {tmpReg, valueReg}, true)
 
            self:freeRegister(tmpReg,  false)
 
            self:freeRegister(valueReg, false)
 
        else
 
            if self.scopeFunctionDepths[pe.scope] == funcDepth then
 
                if self:isUpvalue(pe.scope, pe.id) then
 
                    local reg = self:getVarRegister(pe.scope, pe.id, funcDepth)
 
                    self:addStatement(self:setUpvalueMember(scope,
 
                        self:register(scope, reg), self:register(scope, valueReg), ctor),
 
                        {}, {reg, valueReg}, true)
 
                else
 
                    local reg = self:getVarRegister(pe.scope, pe.id, funcDepth, valueReg)
 
                    if reg ~= valueReg then
 
                        self:addStatement(self:setRegister(scope, reg, self:register(scope, valueReg), ctor), {reg}, {valueReg}, false)
 
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
 
                    self:register(scope, valueReg), ctor),
 
                    {}, {valueReg}, true)
 
            end
 
            self:freeRegister(valueReg, false)
 
        end
 
    end
 
end
 
