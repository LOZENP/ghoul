local Step  = require("nightowl.steps.step")
local Ast   = require("nightowl.ast")
local Scope = require("nightowl.scope")

local WrapInFunction = Step:extend()
WrapInFunction.Name = "Wrap in Function"
WrapInFunction.Description = "Wraps entire script in a function call"
WrapInFunction.SettingsDescriptor = {
    Iterations = {name="Iterations",type="number",default=1,min=1}
}
function WrapInFunction:init() end
function WrapInFunction:apply(ast)
    for i=1,self.Iterations do
        local body=ast.body
        local scope=Scope:new(ast.globalScope)
        body.scope:setParent(scope)
        ast.body=Ast.Block({
            Ast.ReturnStatement({
                Ast.FunctionCallExpression(
                    Ast.FunctionLiteralExpression({Ast.VarargExpression()},body),
                    {Ast.VarargExpression()}
                )
            })
        },scope)
    end
end

return WrapInFunction
