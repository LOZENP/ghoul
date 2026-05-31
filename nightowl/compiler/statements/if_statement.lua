 
return function(self, statement, funcDepth)
 
    local scope = self.activeBlock.scope
 
    local Ast = self.Ast
 
 
    local condReg    = self:compileExpression(statement.condition, funcDepth, 1)[1]
 
    local finalBlock = self:createBlock()
 
    local nextBlock  = (statement.elsebody or #statement.elseifs > 0) and self:createBlock() or finalBlock
 
    local innerBlock = self:createBlock()
 
 
    self:addStatement(self:setRegister(scope, self.POS_REGISTER,
 
        Ast.OrExpression(
 
            Ast.AndExpression(self:register(scope, condReg), Ast.NumberExpression(innerBlock.id)),
 
            Ast.NumberExpression(nextBlock.id)
 
        )),
 
        {self.POS_REGISTER}, {condReg}, false)
 
    self:freeRegister(condReg, false)
 
 
    self:setActiveBlock(innerBlock)
 
    self:compileBlock(statement.body, funcDepth)
 
    self:addStatement(self:setRegister(self.activeBlock.scope, self.POS_REGISTER,
 
        Ast.NumberExpression(finalBlock.id)), {self.POS_REGISTER}, {}, false)
 
 
    for i, eif in ipairs(statement.elseifs) do
 
        self:setActiveBlock(nextBlock)
 
        condReg = self:compileExpression(eif.condition, funcDepth, 1)[1]
 
        local eifInner = self:createBlock()
 
        if statement.elsebody or i < #statement.elseifs then
 
            nextBlock = self:createBlock()
 
        else
 
            nextBlock = finalBlock
 
        end
 
        local sc = self.activeBlock.scope
 
        self:addStatement(self:setRegister(sc, self.POS_REGISTER,
 
            Ast.OrExpression(
 
                Ast.AndExpression(self:register(sc, condReg), Ast.NumberExpression(eifInner.id)),
 
                Ast.NumberExpression(nextBlock.id)
 
            )),
 
            {self.POS_REGISTER}, {condReg}, false)
 
        self:freeRegister(condReg, false)
 
        self:setActiveBlock(eifInner)
 
        self:compileBlock(eif.body, funcDepth)
 
        self:addStatement(self:setRegister(self.activeBlock.scope, self.POS_REGISTER,
 
            Ast.NumberExpression(finalBlock.id)), {self.POS_REGISTER}, {}, false)
 
    end
 
 
    if statement.elsebody then
 
        self:setActiveBlock(nextBlock)
 
        self:compileBlock(statement.elsebody, funcDepth)
 
        self:addStatement(self:setRegister(self.activeBlock.scope, self.POS_REGISTER,
 
            Ast.NumberExpression(finalBlock.id)), {self.POS_REGISTER}, {}, false)
 
    end
 
 
    self:setActiveBlock(finalBlock)
 
end
 
