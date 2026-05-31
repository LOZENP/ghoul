 
return function(self, statement, funcDepth)
 
    local scope = self.activeBlock.scope
 
    local Ast = self.Ast
 
 
    local innerBlock = self:createBlock()
 
    local finalBlock = self:createBlock()
 
    statement.__start_block = innerBlock
 
    statement.__final_block = finalBlock
 
 
    self:addStatement(self:setRegister(scope, self.POS_REGISTER,
 
        Ast.NumberExpression(innerBlock.id)), {self.POS_REGISTER}, {}, false)
 
    self:setActiveBlock(innerBlock)
 
 
    for _, stat in ipairs(statement.body.statements) do
 
        self:compileStatement(stat, funcDepth)
 
    end
 
 
    local sc = self.activeBlock.scope
 
    local condReg = self:compileExpression(statement.condition, funcDepth, 1)[1]
 
    self:addStatement(self:setRegister(sc, self.POS_REGISTER,
 
        Ast.OrExpression(
 
            Ast.AndExpression(self:register(sc, condReg), Ast.NumberExpression(finalBlock.id)),
 
            Ast.NumberExpression(innerBlock.id)
 
        )),
 
        {self.POS_REGISTER}, {condReg}, false)
 
    self:freeRegister(condReg, false)
 
 
    for id, _ in ipairs(statement.body.scope.variables) do
 
        local varReg = self:getVarRegister(statement.body.scope, id, funcDepth, nil)
 
        if self:isUpvalue(statement.body.scope, id) then
 
            self:addStatement(self:setUpvalueMember(sc,
 
                self:register(sc, varReg), Ast.NilExpression()), {}, {varReg}, false)
 
        else
 
            self:addStatement(self:setRegister(sc, varReg, Ast.NilExpression()), {varReg}, {}, false)
 
        end
 
        self:freeRegister(varReg, true)
 
    end
 
 
    self:setActiveBlock(finalBlock)
 
end
 
