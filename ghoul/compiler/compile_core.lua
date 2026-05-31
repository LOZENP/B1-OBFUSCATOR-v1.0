return function(Compiler)
    local compileTop = require("nightowl.compiler.compile_top")
    local statementHandlers = require("nightowl.compiler.statements")
    local expressionHandlers = require("nightowl.compiler.expressions")

    compileTop(Compiler)

    function Compiler:compileStatement(statement, funcDepth)
        local handler = statementHandlers[statement.kind]
        if handler then
            handler(self, statement, funcDepth)
            return
        end
        error("[NightOwl Compiler] Not a compilable statement: " .. tostring(statement.kind))
    end

    function Compiler:compileExpression(expression, funcDepth, numReturns)
        local handler = expressionHandlers[expression.kind]
        if handler then
            return handler(self, expression, funcDepth, numReturns)
        end
        error("[NightOwl Compiler] Not a compilable expression: " .. tostring(expression.kind))
    end
end
