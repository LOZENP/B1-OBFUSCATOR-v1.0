local function requireStatement(name)
    return require("nightowl.compiler.statements." .. name)
end

return function(Ast)
    local AK = Ast.AstKind
    local handlers = {}

    handlers[AK.ReturnStatement]               = requireStatement("return")
    handlers[AK.LocalVariableDeclaration]      = requireStatement("local_variable_declaration")
    handlers[AK.FunctionCallStatement]         = requireStatement("function_call")
    handlers[AK.PassSelfFunctionCallStatement] = requireStatement("pass_self_function_call")
    handlers[AK.LocalFunctionDeclaration]      = requireStatement("local_function_declaration")
    handlers[AK.FunctionDeclaration]           = requireStatement("function_declaration")
    handlers[AK.AssignmentStatement]           = requireStatement("assignment")
    handlers[AK.IfStatement]                   = requireStatement("if_statement")
    handlers[AK.DoStatement]                   = requireStatement("do_statement")
    handlers[AK.WhileStatement]                = requireStatement("while_statement")
    handlers[AK.RepeatStatement]               = requireStatement("repeat_statement")
    handlers[AK.ForStatement]                  = requireStatement("for_statement")
    handlers[AK.ForInStatement]                = requireStatement("for_in_statement")
    handlers[AK.BreakStatement]                = requireStatement("break_statement")
    handlers[AK.ContinueStatement]             = requireStatement("continue_statement")

    local compoundHandler = requireStatement("compound")
    handlers[AK.CompoundAddStatement]    = compoundHandler
    handlers[AK.CompoundSubStatement]    = compoundHandler
    handlers[AK.CompoundMulStatement]    = compoundHandler
    handlers[AK.CompoundDivStatement]    = compoundHandler
    handlers[AK.CompoundModStatement]    = compoundHandler
    handlers[AK.CompoundPowStatement]    = compoundHandler
    handlers[AK.CompoundConcatStatement] = compoundHandler

    return handlers
end
