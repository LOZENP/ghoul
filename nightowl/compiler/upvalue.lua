return function(Compiler)
    function Compiler:createAllocUpvalFunction()
        local Ast   = self.Ast
        local scope = self.Scope:new(self.scope)
        scope:addReferenceToHigherScope(self.scope, self.currentUpvalId, 4)
        return Ast.FunctionLiteralExpression({}, Ast.Block({
            Ast.AssignmentStatement(
                { Ast.AssignmentVariable(self.scope, self.currentUpvalId) },
                { Ast.AddExpression(
                    Ast.VariableExpression(self.scope, self.currentUpvalId),
                    Ast.NumberExpression(1)
                )}
            ),
            Ast.ReturnStatement({
                Ast.VariableExpression(self.scope, self.currentUpvalId)
            })
        }, scope))
    end
end
