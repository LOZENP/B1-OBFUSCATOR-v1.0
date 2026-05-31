-- Simplified upvalue system: plain table, no newproxy/setmetatable/getmetatable
-- Upvalues are stored as upvaluesTable[id] = value
-- No GC, no reference counting. Lua handles cleanup naturally.

return function(Compiler)
    -- allocUpval: just increment currentUpvalId and return it
    function Compiler:createAllocUpvalFunction()
        local Ast = self.Ast
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
