 
return function(self, expression, funcDepth, numReturns)
 
    local scope = self.activeBlock.scope
 
    local Ast = self.Ast
 
    local AstKind = Ast.AstKind
 
    local regs = {}
 
    for i = 1, numReturns do
 
        regs[i] = self:allocRegister()
 
        if i == 1 then
 
            local entries, entryRegs = {}, {}
 
            for j, entry in ipairs(expression.entries) do
 
                if entry.kind == AstKind.TableEntry then
 
                    local val = entry.value
 
                    if j == #expression.entries and (
 
                        val.kind == AstKind.FunctionCallExpression or
 
                        val.kind == AstKind.PassSelfFunctionCallExpression or
 
                        val.kind == AstKind.VarargExpression
 
                    ) then
 
                        local reg = self:compileExpression(val, funcDepth, self.RETURN_ALL)[1]
 
                        table.insert(entries, Ast.TableEntry(
 
                            Ast.FunctionCallExpression(self:unpack(scope), { self:register(scope, reg) })
 
                        ))
 
                        table.insert(entryRegs, reg)
 
                    else
 
                        local reg = self:compileExpression(val, funcDepth, 1)[1]
 
                        table.insert(entries, Ast.TableEntry(self:register(scope, reg)))
 
                        table.insert(entryRegs, reg)
 
                    end
 
                else
 
                    local keyReg = self:compileExpression(entry.key, funcDepth, 1)[1]
 
                    local valReg = self:compileExpression(entry.value, funcDepth, 1)[1]
 
                    table.insert(entries, Ast.KeyedTableEntry(self:register(scope, keyReg), self:register(scope, valReg)))
 
                    table.insert(entryRegs, valReg)
 
                    table.insert(entryRegs, keyReg)
 
                end
 
            end
 
            self:addStatement(self:setRegister(scope, regs[i],
 
                Ast.TableConstructorExpression(entries)), {regs[i]}, entryRegs, false)
 
            for _, reg in ipairs(entryRegs) do self:freeRegister(reg, false) end
 
        else
 
            self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), {regs[i]}, {}, false)
 
        end
 
    end
 
    return regs
 
end
 
