local function requireExpression(name)
    return require("nightowl.compiler.expressions." .. name)
end

local AstKind -- will be set at first use via metatable trick; we just return a factory

return function(Ast)
    local AK = Ast.AstKind
    local handlers = {}

    handlers[AK.StringExpression]       = requireExpression("string")
    handlers[AK.NumberExpression]       = requireExpression("number")
    handlers[AK.BooleanExpression]      = requireExpression("boolean")
    handlers[AK.NilExpression]          = requireExpression("nil")
    handlers[AK.VariableExpression]     = requireExpression("variable")
    handlers[AK.FunctionCallExpression] = requireExpression("function_call")
    handlers[AK.PassSelfFunctionCallExpression] = requireExpression("pass_self_function_call")
    handlers[AK.IndexExpression]        = requireExpression("index")
    handlers[AK.NotExpression]          = requireExpression("not")
    handlers[AK.NegateExpression]       = requireExpression("negate")
    handlers[AK.LenExpression]          = requireExpression("len")
    handlers[AK.OrExpression]           = requireExpression("or")
    handlers[AK.AndExpression]          = requireExpression("and")
    handlers[AK.TableConstructorExpression] = requireExpression("table_constructor")
    handlers[AK.FunctionLiteralExpression]  = requireExpression("function_literal")
    handlers[AK.VarargExpression]       = requireExpression("vararg")

    local binaryHandler = requireExpression("binary")
    handlers[AK.LessThanExpression]             = binaryHandler
    handlers[AK.GreaterThanExpression]          = binaryHandler
    handlers[AK.LessThanOrEqualsExpression]     = binaryHandler
    handlers[AK.GreaterThanOrEqualsExpression]  = binaryHandler
    handlers[AK.NotEqualsExpression]            = binaryHandler
    handlers[AK.EqualsExpression]               = binaryHandler
    handlers[AK.StrCatExpression]               = binaryHandler
    handlers[AK.AddExpression]                  = binaryHandler
    handlers[AK.SubExpression]                  = binaryHandler
    handlers[AK.MulExpression]                  = binaryHandler
    handlers[AK.DivExpression]                  = binaryHandler
    handlers[AK.ModExpression]                  = binaryHandler
    handlers[AK.PowExpression]                  = binaryHandler

    return handlers
end
