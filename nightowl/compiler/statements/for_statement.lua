 
return function(self, statement, funcDepth)
 
    local scope = self.activeBlock.scope
 
    local Ast = self.Ast
 
    local unpack = table.unpack or unpack
 
 
    local checkBlock = self:createBlock()
 
    local innerBlock = self:createBlock()
 
    local finalBlock = self:createBlock()
 
 
    statement.__start_block = checkBlock
 
    statement.__final_block = finalBlock
 
 
    local posState = self.registers[self.POS_REGISTER]
 
    self.registers[self.POS_REGISTER] = self.VAR_REGISTER
 
 
    local initialReg     = self:compileExpression(statement.initialValue, funcDepth, 1)[1]
 
    local finalExprReg   = self:compileExpression(statement.finalValue,   funcDepth, 1)[1]
 
    local finalReg       = self:allocRegister(false)
 
    self:addStatement(self:copyRegisters(scope, {finalReg}, {finalExprReg}), {finalReg}, {finalExprReg}, false)
 
    self:freeRegister(finalExprReg)
 
 
    local incrementExprReg = self:compileExpression(statement.incrementBy, funcDepth, 1)[1]
 
    local incrementReg     = self:allocRegister(false)
 
    self:addStatement(self:copyRegisters(scope, {incrementReg}, {incrementExprReg}), {incrementReg}, {incrementExprReg}, false)
 
    self:freeRegister(incrementExprReg)
 
 
    local tmpReg = self:allocRegister(false)
 
    self:addStatement(self:setRegister(scope, tmpReg, Ast.NumberExpression(0)), {tmpReg}, {}, false)
 
    local incrementIsNegReg = self:allocRegister(false)
 
 
    local shouldSwap3 = math.random(1, 2) == 2
 
    local s4 = shouldSwap3 and {incrementReg, tmpReg} or {tmpReg, incrementReg}
 
    self:addStatement(self:setRegister(scope, incrementIsNegReg,
 
        Ast[shouldSwap3 and "LessThanExpression" or "GreaterThanExpression"](
 
            self:register(scope, s4[1]), self:register(scope, s4[2])
 
        )),
 
        {incrementIsNegReg}, {s4[1], s4[2]}, false)
 
    self:freeRegister(tmpReg)
 
 
    local currentReg = self:allocRegister(true)
 
    self:addStatement(self:setRegister(scope, currentReg,
 
        Ast.SubExpression(self:register(scope, initialReg), self:register(scope, incrementReg))),
 
        {currentReg}, {initialReg, incrementReg}, false)
 
    self:freeRegister(initialReg)
 
 
    self:addStatement(self:jmp(scope, Ast.NumberExpression(checkBlock.id)), {self.POS_REGISTER}, {}, false)
 
    self:setActiveBlock(checkBlock)
 
    scope = checkBlock.scope
 
 
    local sr = {currentReg, incrementReg}
 
    for i = #sr, 2, -1 do local j = math.random(i); sr[i], sr[j] = sr[j], sr[i] end
 
    self:addStatement(self:setRegister(scope, currentReg,
 
        Ast.AddExpression(self:register(scope, sr[1]), self:register(scope, sr[2]))),
 
        {currentReg}, {sr[1], sr[2]}, false)
 
 
    local tmpReg1 = self:allocRegister(false)
 
    local tmpReg2 = self:allocRegister(false)
 
    self:addStatement(self:setRegister(scope, tmpReg2,
 
        Ast.NotExpression(self:register(scope, incrementIsNegReg))), {tmpReg2}, {incrementIsNegReg}, false)
 
 
    local sw1 = math.random(1,2)==2
 
    local s2  = sw1 and {currentReg, finalReg} or {finalReg, currentReg}
 
    self:addStatement(self:setRegister(scope, tmpReg1,
 
        Ast[sw1 and "LessThanOrEqualsExpression" or "GreaterThanOrEqualsExpression"](
 
            self:register(scope, s2[1]), self:register(scope, s2[2])
 
        )),
 
        {tmpReg1}, {s2[1], s2[2]}, false)
 
    self:addStatement(self:setRegister(scope, tmpReg1,
 
        Ast.AndExpression(self:register(scope, tmpReg2), self:register(scope, tmpReg1))),
 
        {tmpReg1}, {tmpReg1, tmpReg2}, false)
 
 
    local sw2 = math.random(1,2)==2
 
    local s3  = sw2 and {currentReg, finalReg} or {finalReg, currentReg}
 
    self:addStatement(self:setRegister(scope, tmpReg2,
 
        Ast[sw2 and "GreaterThanOrEqualsExpression" or "LessThanOrEqualsExpression"](
 
            self:register(scope, s3[1]), self:register(scope, s3[2])
 
        )),
 
        {tmpReg2}, {s3[1], s3[2]}, false)
 
    self:addStatement(self:setRegister(scope, tmpReg2,
 
        Ast.AndExpression(self:register(scope, incrementIsNegReg), self:register(scope, tmpReg2))),
 
        {tmpReg2}, {tmpReg2, incrementIsNegReg}, false)
 
    self:addStatement(self:setRegister(scope, tmpReg1,
 
        Ast.OrExpression(self:register(scope, tmpReg2), self:register(scope, tmpReg1))),
 
        {tmpReg1}, {tmpReg1, tmpReg2}, false)
 
    self:freeRegister(tmpReg2)
 
 
    tmpReg2 = self:compileExpression(Ast.NumberExpression(innerBlock.id), funcDepth, 1)[1]
 
    self:addStatement(self:setRegister(scope, self.POS_REGISTER,
 
        Ast.AndExpression(self:register(scope, tmpReg1), self:register(scope, tmpReg2))),
 
        {self.POS_REGISTER}, {tmpReg1, tmpReg2}, false)
 
    self:freeRegister(tmpReg2)
 
    self:freeRegister(tmpReg1)
 
 
    tmpReg2 = self:compileExpression(Ast.NumberExpression(finalBlock.id), funcDepth, 1)[1]
 
    self:addStatement(self:setRegister(scope, self.POS_REGISTER,
 
        Ast.OrExpression(self:register(scope, self.POS_REGISTER), self:register(scope, tmpReg2))),
 
        {self.POS_REGISTER}, {self.POS_REGISTER, tmpReg2}, false)
 
    self:freeRegister(tmpReg2)
 
 
    self:setActiveBlock(innerBlock)
 
    scope = innerBlock.scope
 
    self.registers[self.POS_REGISTER] = posState
 
 
    local varReg = self:getVarRegister(statement.scope, statement.id, funcDepth, nil)
 
    if self:isUpvalue(statement.scope, statement.id) then
 
        scope:addReferenceToHigherScope(self.scope, self.allocUpvalFunction)
 
        self:addStatement(self:setRegister(scope, varReg,
 
            Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.allocUpvalFunction), {})),
 
            {varReg}, {}, false)
 
        self:addStatement(self:setUpvalueMember(scope,
 
            self:register(scope, varReg), self:register(scope, currentReg)),
 
            {}, {varReg, currentReg}, true)
 
    else
 
        self:addStatement(self:setRegister(scope, varReg, self:register(scope, currentReg)), {varReg}, {currentReg}, false)
 
    end
 
 
    self:compileBlock(statement.body, funcDepth)
 
    self:addStatement(self:setRegister(scope, self.POS_REGISTER,
 
        Ast.NumberExpression(checkBlock.id)), {self.POS_REGISTER}, {}, false)
 
 
    self.registers[self.POS_REGISTER] = self.VAR_REGISTER
 
    self:freeRegister(finalReg)
 
    self:freeRegister(incrementIsNegReg)
 
    self:freeRegister(incrementReg)
 
    self:freeRegister(currentReg, true)
 
    self.registers[self.POS_REGISTER] = posState
 
    self:setActiveBlock(finalBlock)
 
end
 
