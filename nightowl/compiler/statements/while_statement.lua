 
return function(self, statement, funcDepth)
 
    local scope = self.activeBlock.scope
 
    local Ast = self.Ast
 
 
    local innerBlock = self:createBlock()
 
    local finalBlock = self:createBlock()
 
    local checkBlock = self:createBlock()
 
 
    statement.__start_block = checkBlock
 
    statement.__final_block = finalBlock
 
 
    self:addStatement(self:setPos(scope, checkBlock.id), {self.POS_REGISTER}, {}, false)
 
    self:setActiveBlock(checkBlock)
 
    scope = self.activeBlock.scope
 
    local condReg = self:compileExpression(statement.condition, funcDepth, 1)[1]
 
    self:addStatement(self:setRegister(scope, self.POS_REGISTER,
 
        Ast.OrExpression(
 
            Ast.AndExpression(self:register(scope, condReg), Ast.NumberExpression(innerBlock.id)),
 
            Ast.NumberExpression(finalBlock.id)
 
        )),
 
        {self.POS_REGISTER}, {condReg}, false)
 
    self:freeRegister(condReg, false)
 
 
    self:setActiveBlock(innerBlock)
 
    self:compileBlock(statement.body, funcDepth)
 
    self:addStatement(self:setPos(self.activeBlock.scope, checkBlock.id), {self.POS_REGISTER}, {}, false)
 
    self:setActiveBlock(finalBlock)
 
end
 
