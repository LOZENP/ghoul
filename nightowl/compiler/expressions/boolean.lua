 
return function(self, expression, _, numReturns)
 
    local scope = self.activeBlock.scope
 
    local Ast = self.Ast
 
 
    local expTB = {
 
        Ast.GreaterThanExpression,
 
        Ast.LessThanExpression,
 
        Ast.GreaterThanOrEqualsExpression,
 
        Ast.LessThanOrEqualsExpression,
 
        Ast.NotEqualsExpression,
 
    }
 
    local evals = {
 
        [Ast.GreaterThanExpression]         = function(a,b) return a > b end,
 
        [Ast.LessThanExpression]            = function(a,b) return a < b end,
 
        [Ast.GreaterThanOrEqualsExpression] = function(a,b) return a >= b end,
 
        [Ast.LessThanOrEqualsExpression]    = function(a,b) return a <= b end,
 
        [Ast.NotEqualsExpression]           = function(a,b) return a ~= b end,
 
    }
 
 
    local function makeOpaque(result)
 
        local left, right, boolResult, randomExp
 
        repeat
 
            randomExp = expTB[math.random(1, #expTB)]
 
            left  = Ast.NumberExpression(math.random(1, 2^24))
 
            right = Ast.NumberExpression(math.random(1, 2^24))
 
            boolResult = evals[randomExp](left.value, right.value)
 
        until boolResult == result
 
        return randomExp(left, right, false)
 
    end
 
 
    local regs = {}
 
    for i = 1, numReturns do
 
        regs[i] = self:allocRegister()
 
        if i == 1 then
 
            self:addStatement(self:setRegister(scope, regs[i], makeOpaque(expression.value)), {regs[i]}, {}, false)
 
        else
 
            self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), {regs[i]}, {}, false)
 
        end
 
    end
 
    return regs
 
end
 
