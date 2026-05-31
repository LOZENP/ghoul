local function req(name)
    return require("nightowl.compiler.expressions." .. name)
end

return function(Ast)
    local AK       = Ast.AstKind
    local handlers = {}

    handlers[AK.StringExpression]       = req("string")
    handlers[AK.NumberExpression]       = req("number")
    handlers[AK.BooleanExpression]      = req("boolean")
    handlers[AK.NilExpression]          = req("nil")
    handlers[AK.VariableExpression]     = req("variable")
    handlers[AK.FunctionCallExpression] = req("function_call")
    handlers[AK.PassSelfFunctionCallExpression] = req("pass_self_function_call")
    handlers[AK.IndexExpression]        = req("index")
    handlers[AK.NotExpression]          = req("not")
    handlers[AK.NegateExpression]       = req("negate")
    handlers[AK.LenExpression]          = req("len")
    handlers[AK.OrExpression]           = req("or")
    handlers[AK.AndExpression]          = req("and")
    handlers[AK.TableConstructorExpression] = req("table_constructor")
    handlers[AK.FunctionLiteralExpression]  = req("function_literal")
    handlers[AK.VarargExpression]       = req("vararg")

    local binaryHandler = req("binary")
    handlers[AK.LessThanExpression]            = binaryHandler
    handlers[AK.GreaterThanExpression]         = binaryHandler
    handlers[AK.LessThanOrEqualsExpression]    = binaryHandler
    handlers[AK.GreaterThanOrEqualsExpression] = binaryHandler
    handlers[AK.NotEqualsExpression]           = binaryHandler
    handlers[AK.EqualsExpression]              = binaryHandler
    handlers[AK.StrCatExpression]              = binaryHandler
    handlers[AK.AddExpression]                 = binaryHandler
    handlers[AK.SubExpression]                 = binaryHandler
    handlers[AK.MulExpression]                 = binaryHandler
    handlers[AK.DivExpression]                 = binaryHandler
    handlers[AK.ModExpression]                 = binaryHandler
    handlers[AK.PowExpression]                 = binaryHandler

    return handlers
end
