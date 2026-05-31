 
return function(self, statement, funcDepth)
 
    local scope = self.activeBlock.scope
 
    local Ast = self.Ast
 
    local toFreeVars = {}
 
    local statScope
 
    repeat
 
        statScope = statScope and statScope.parentScope or statement.scope
 
        for id, _ in ipairs(statScope.variables) do
 
            table.insert(toFreeVars, { scope = statScope, id = id })
 
        end
 
    until statScope == statement.loop.body.scope
 
 
    for _, var in pairs(toFreeVars) do
 
        local varReg = self:getVarRegister(var.scope, var.id, nil, nil)
 
        if self:isUpvalue(var.scope, var.id) then
 
            self:addStatement(self:setUpvalueMember(scope,
 
                self:register(scope, varReg), Ast.NilExpression()), {}, {varReg}, false)
 
        else
 
            self:addStatement(self:setRegister(scope, varReg, Ast.NilExpression()), {varReg}, {}, false)
 
        end
 
    end
 
 
    self:addStatement(self:setPos(scope, statement.loop.__final_block.id), {self.POS_REGISTER}, {}, false)
 
    self.activeBlock.advanceToNextBlock = false
 
end
 
