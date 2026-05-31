local function req(name)
    return require("nightowl.compiler.statements." .. name)
end

return function(Ast)
    local AK       = Ast.AstKind
    local handlers = {}

    handlers[AK.ReturnStatement]               = req("return")
    handlers[AK.LocalVariableDeclaration]      = req("local_variable_declaration")
    handlers[AK.FunctionCallStatement]         = req("function_call")
    handlers[AK.PassSelfFunctionCallStatement] = req("pass_self_function_call")
    handlers[AK.LocalFunctionDeclaration]      = req("local_function_declaration")
    handlers[AK.FunctionDeclaration]           = req("function_declaration")
    handlers[AK.AssignmentStatement]           = req("assignment")
    handlers[AK.IfStatement]                   = req("if_statement")
    handlers[AK.DoStatement]                   = req("do_statement")
    handlers[AK.WhileStatement]                = req("while_statement")
    handlers[AK.RepeatStatement]               = req("repeat_statement")
    handlers[AK.ForStatement]                  = req("for_statement")
    handlers[AK.ForInStatement]                = req("for_in_statement")
    handlers[AK.BreakStatement]                = req("break_statement")
    handlers[AK.ContinueStatement]             = req("continue_statement")

    local compoundHandler = req("compound")
    handlers[AK.CompoundAddStatement]    = compoundHandler
    handlers[AK.CompoundSubStatement]    = compoundHandler
    handlers[AK.CompoundMulStatement]    = compoundHandler
    handlers[AK.CompoundDivStatement]    = compoundHandler
    handlers[AK.CompoundModStatement]    = compoundHandler
    handlers[AK.CompoundPowStatement]    = compoundHandler
    handlers[AK.CompoundConcatStatement] = compoundHandler

    return handlers
end
