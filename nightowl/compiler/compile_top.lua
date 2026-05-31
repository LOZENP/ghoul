return function(Compiler)
    local function lookupify(tb)
        local out = {}
        for _, v in ipairs(tb) do out[v] = true end
        return out
    end

    function Compiler:compileTopNode(node)
        local Ast     = self.Ast
        local AstKind = Ast.AstKind

        local startBlock = self:createBlock()
        local scope      = startBlock.scope
        self.startBlockId = startBlock.id
        self:setActiveBlock(startBlock)

        local varAccessLookup = lookupify{
            AstKind.AssignmentVariable, AstKind.VariableExpression,
            AstKind.FunctionDeclaration, AstKind.LocalFunctionDeclaration,
        }
        local functionLookup = lookupify{
            AstKind.FunctionDeclaration, AstKind.LocalFunctionDeclaration,
            AstKind.FunctionLiteralExpression, AstKind.TopNode,
        }

        self.visitast(node, function(vnode, data)
            if vnode.kind == AstKind.Block then
                vnode.scope.__depth = data.functionData.depth
            end
            if varAccessLookup[vnode.kind] then
                if not vnode.scope.isGlobal then
                    if vnode.scope.__depth and vnode.scope.__depth < data.functionData.depth then
                        if not self:isUpvalue(vnode.scope, vnode.id) then
                            self:makeUpvalue(vnode.scope, vnode.id)
                        end
                    end
                end
            end
        end, nil, nil)

        self.varargReg = self:allocRegister(true)
        scope:addReferenceToHigherScope(self.containerFuncScope, self.argsVar)
        scope:addReferenceToHigherScope(self.scope, self.selectVar)
        scope:addReferenceToHigherScope(self.scope, self.unpackVar)
        self:addStatement(
            self:setRegister(scope, self.varargReg,
                Ast.VariableExpression(self.containerFuncScope, self.argsVar)),
            { self.varargReg }, {}, false
        )

        self:compileBlock(node.body, 0)

        if self.activeBlock.advanceToNextBlock then
            self:addStatement(self:setPos(self.activeBlock.scope, nil), { self.POS_REGISTER }, {}, false)
            self:addStatement(
                self:setReturn(self.activeBlock.scope, Ast.TableConstructorExpression({})),
                { self.RETURN_REGISTER }, {}, false
            )
            self.activeBlock.advanceToNextBlock = false
        end

        self:resetRegisters()
    end

    function Compiler:compileFunction(node, funcDepth)
        local Ast     = self.Ast
        local AstKind = Ast.AstKind

        funcDepth = funcDepth + 1
        local oldActiveBlock  = self.activeBlock
        local upperVarargReg  = self.varargReg
        self.varargReg = nil

        local upvalueExpressions = {}
        local upvalueIds         = {}
        local usedRegs           = {}

        local oldGetUpvalueId = self.getUpvalueId
        self.getUpvalueId = function(s, scope, id)
            if not upvalueIds[scope] then upvalueIds[scope] = {} end
            if upvalueIds[scope][id] then return upvalueIds[scope][id] end

            local scopeFuncDepth = s.scopeFunctionDepths[scope]
            local expression

            if scopeFuncDepth == funcDepth then
                oldActiveBlock.scope:addReferenceToHigherScope(s.scope, s.allocUpvalFunction)
                expression = Ast.FunctionCallExpression(
                    Ast.VariableExpression(s.scope, s.allocUpvalFunction), {}
                )
            elseif scopeFuncDepth == funcDepth - 1 then
                local varReg = s:getVarRegister(scope, id, scopeFuncDepth, nil)
                expression = s:register(oldActiveBlock.scope, varReg)
                table.insert(usedRegs, varReg)
            else
                local higherId = oldGetUpvalueId(s, scope, id)
                oldActiveBlock.scope:addReferenceToHigherScope(s.containerFuncScope, s.currentUpvaluesVar)
                expression = Ast.IndexExpression(
                    Ast.VariableExpression(s.containerFuncScope, s.currentUpvaluesVar),
                    Ast.NumberExpression(higherId)
                )
            end

            table.insert(upvalueExpressions, Ast.TableEntry(expression))
            local uid = #upvalueExpressions
            upvalueIds[scope][id] = uid
            return uid
        end

        local block = self:createBlock()
        self:setActiveBlock(block)
        local scope = self.activeBlock.scope
        self:pushRegisterUsageInfo()

        for i, arg in ipairs(node.args) do
            if arg.kind == AstKind.VariableExpression then
                if self:isUpvalue(arg.scope, arg.id) then
                    scope:addReferenceToHigherScope(self.scope, self.allocUpvalFunction)
                    local argReg = self:getVarRegister(arg.scope, arg.id, funcDepth, nil)
                    self:addStatement(
                        self:setRegister(scope, argReg,
                            Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.allocUpvalFunction), {})),
                        { argReg }, {}, false
                    )
                    self:addStatement(
                        self:setUpvalueMember(scope,
                            self:register(scope, argReg),
                            Ast.IndexExpression(Ast.VariableExpression(self.containerFuncScope, self.argsVar), Ast.NumberExpression(i))),
                        {}, { argReg }, true
                    )
                else
                    local argReg = self:getVarRegister(arg.scope, arg.id, funcDepth, nil)
                    scope:addReferenceToHigherScope(self.containerFuncScope, self.argsVar)
                    self:addStatement(
                        self:setRegister(scope, argReg,
                            Ast.IndexExpression(Ast.VariableExpression(self.containerFuncScope, self.argsVar), Ast.NumberExpression(i))),
                        { argReg }, {}, false
                    )
                end
            else
                self.varargReg = self:allocRegister(true)
                scope:addReferenceToHigherScope(self.containerFuncScope, self.argsVar)
                scope:addReferenceToHigherScope(self.scope, self.selectVar)
                scope:addReferenceToHigherScope(self.scope, self.unpackVar)
                self:addStatement(
                    self:setRegister(scope, self.varargReg, Ast.TableConstructorExpression({
                        Ast.TableEntry(Ast.FunctionCallExpression(
                            Ast.VariableExpression(self.scope, self.selectVar),
                            {
                                Ast.NumberExpression(i),
                                Ast.FunctionCallExpression(
                                    Ast.VariableExpression(self.scope, self.unpackVar),
                                    { Ast.VariableExpression(self.containerFuncScope, self.argsVar) }
                                )
                            }
                        ))
                    })),
                    { self.varargReg }, {}, false
                )
            end
        end

        self:compileBlock(node.body, funcDepth)

        if self.activeBlock.advanceToNextBlock then
            self:addStatement(self:setPos(self.activeBlock.scope, nil), { self.POS_REGISTER }, {}, false)
            self:addStatement(
                self:setReturn(self.activeBlock.scope, Ast.TableConstructorExpression({})),
                { self.RETURN_REGISTER }, {}, false
            )
            self.activeBlock.advanceToNextBlock = false
        end

        if self.varargReg then self:freeRegister(self.varargReg, true) end
        self.varargReg    = upperVarargReg
        self.getUpvalueId = oldGetUpvalueId

        self:popRegisterUsageInfo()
        self:setActiveBlock(oldActiveBlock)

        local scope2  = self.activeBlock.scope
        local retReg  = self:allocRegister(false)
        local isVararg = #node.args > 0 and node.args[#node.args].kind == AstKind.VarargExpression

        local retrieveExpr
        if isVararg then
            scope2:addReferenceToHigherScope(self.scope, self.createVarargClosureVar)
            retrieveExpr = Ast.FunctionCallExpression(
                Ast.VariableExpression(self.scope, self.createVarargClosureVar),
                { Ast.NumberExpression(block.id), Ast.TableConstructorExpression(upvalueExpressions) }
            )
        else
            local varScope, var = self:getCreateClosureVar(#node.args + math.random(0, 5))
            scope2:addReferenceToHigherScope(varScope, var)
            retrieveExpr = Ast.FunctionCallExpression(
                Ast.VariableExpression(varScope, var),
                { Ast.NumberExpression(block.id), Ast.TableConstructorExpression(upvalueExpressions) }
            )
        end

        self:addStatement(
            self:setRegister(scope2, retReg, retrieveExpr),
            { retReg }, usedRegs, false
        )
        return retReg
    end

    function Compiler:compileBlock(block, funcDepth)
        local Ast = self.Ast
        for _, stat in ipairs(block.statements) do
            self:compileStatement(stat, funcDepth)
        end
        local scope = self.activeBlock.scope
        for id, _ in ipairs(block.scope.variables) do
            local varReg = self:getVarRegister(block.scope, id, funcDepth, nil)
            if self:isUpvalue(block.scope, id) then
                self:addStatement(
                    self:setUpvalueMember(scope, self:register(scope, varReg), Ast.NilExpression()),
                    {}, { varReg }, false
                )
            else
                self:addStatement(
                    self:setRegister(scope, varReg, Ast.NilExpression()),
                    { varReg }, {}, false
                )
            end
            self:freeRegister(varReg, true)
        end
    end
end
