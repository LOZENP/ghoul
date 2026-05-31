local constants = require("nightowl.compiler.constants")
local MAX_REGS  = constants.MAX_REGS

return function(Compiler)
    local Ast, Scope

    local function hasAnyEntries(tbl)
        return type(tbl) == "table" and next(tbl) ~= nil
    end

    local function unionLookupTables(a, b)
        local out = {}
        for k, v in pairs(a or {}) do out[k] = v end
        for k, v in pairs(b or {}) do out[k] = v end
        return out
    end

    local function canMerge(statA, statB)
        if type(statA) ~= "table" or type(statB) ~= "table" then return false end
        if statA.usesUpvals or statB.usesUpvals then return false end
        local a, b = statA.statement, statB.statement
        if type(a) ~= "table" or type(b) ~= "table" then return false end
        local AstKind = Ast.AstKind
        if a.kind ~= AstKind.AssignmentStatement or b.kind ~= AstKind.AssignmentStatement then return false end
        if #a.lhs ~= #a.rhs or #b.lhs ~= #b.rhs then return false end
        local function hasUnsafeRhs(rhs)
            for _, e in ipairs(rhs) do
                if type(e) ~= "table" then return true end
                local k = e.kind
                if k == AstKind.FunctionCallExpression or k == AstKind.PassSelfFunctionCallExpression or k == AstKind.VarargExpression then
                    return true
                end
            end
            return false
        end
        if hasUnsafeRhs(a.rhs) or hasUnsafeRhs(b.rhs) then return false end
        local aR, aW, bR, bW = statA.reads or {}, statA.writes or {}, statB.reads or {}, statB.writes or {}
        if not hasAnyEntries(aW) and not hasAnyEntries(bW) then return false end
        for r in pairs(aR) do if bW[r] then return false end end
        for r in pairs(aW) do if bW[r] or bR[r] then return false end end
        return true
    end

    local function mergeTwo(statA, statB)
        local lhs, rhs = {}, {}
        for _, v in ipairs(statA.statement.lhs) do table.insert(lhs, v) end
        for _, v in ipairs(statB.statement.lhs) do table.insert(lhs, v) end
        for _, v in ipairs(statA.statement.rhs) do table.insert(rhs, v) end
        for _, v in ipairs(statB.statement.rhs) do table.insert(rhs, v) end
        return {
            statement  = Ast.AssignmentStatement(lhs, rhs),
            writes     = unionLookupTables(statA.writes, statB.writes),
            reads      = unionLookupTables(statA.reads,  statB.reads),
            usesUpvals = statA.usesUpvals or statB.usesUpvals,
        }
    end

    local function mergePass(blockstats)
        local merged = {}
        local i = 1
        while i <= #blockstats do
            local stat = blockstats[i]; i = i + 1
            while i <= #blockstats and canMerge(stat, blockstats[i]) do
                stat = mergeTwo(stat, blockstats[i]); i = i + 1
            end
            table.insert(merged, stat)
        end
        return merged
    end

    function Compiler:emitContainerFuncBody()
        Ast   = self.Ast
        Scope = self.Scope

        local AstKind = Ast.AstKind
        local blocks  = {}

        local shuffled = {}
        for _, b in ipairs(self.blocks) do table.insert(shuffled, b) end
        for i = #shuffled, 2, -1 do
            local j = math.random(i)
            shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
        end

        for i, block in ipairs(shuffled) do
            local id         = block.id
            local blockstats = block.statements

            for idx = 2, #blockstats do
                local stat       = blockstats[idx]
                local reads      = stat.reads
                local writes     = stat.writes
                local maxShift   = 0
                local usesUpvals = stat.usesUpvals
                for shift = 1, idx - 1 do
                    local prev = blockstats[idx - shift]
                    if prev.usesUpvals and usesUpvals then break end
                    local r2, w2 = prev.reads, prev.writes
                    local ok = true
                    for r in pairs(r2) do if writes[r] then ok = false; break end end
                    if ok then
                        for w in pairs(w2) do
                            if writes[w] or reads[w] then ok = false; break end
                        end
                    end
                    if not ok then break end
                    maxShift = shift
                end
                local shift = math.random(0, maxShift)
                for j = 1, shift do
                    blockstats[idx-j], blockstats[idx-j+1] = blockstats[idx-j+1], blockstats[idx-j]
                end
            end

            local merged = blockstats
            for _ = 1, 7 do merged = mergePass(merged) end

            local finalStats = {}
            for _, s in ipairs(merged) do table.insert(finalStats, s.statement) end

            local entry = { id = id, index = i, block = Ast.Block(finalStats, block.scope) }
            table.insert(blocks, entry)
            blocks[id] = entry
        end

        table.sort(blocks, function(a, b) return a.id < b.id end)

        local function buildChain(tb, l, r, pScope)
            if r < l then
                local es = Scope:new(pScope)
                return Ast.Block({}, es)
            end
            local len = r - l + 1
            if len == 1 then
                tb[l].block.scope:setParent(pScope)
                return tb[l].block
            end
            if len <= 4 then
                local ifScope = Scope:new(pScope)
                local elseifs = {}
                tb[l].block.scope:setParent(ifScope)
                local bound     = math.floor((tb[l].id + tb[l+1].id) / 2)
                local firstCond = Ast.LessThanExpression(self:pos(ifScope), Ast.NumberExpression(bound))
                local firstBlock= tb[l].block
                for i = l + 1, r - 1 do
                    tb[i].block.scope:setParent(ifScope)
                    local b2 = math.floor((tb[i].id + tb[i+1].id) / 2)
                    table.insert(elseifs, {
                        condition = Ast.LessThanExpression(self:pos(ifScope), Ast.NumberExpression(b2)),
                        body      = tb[i].block
                    })
                end
                tb[r].block.scope:setParent(ifScope)
                return Ast.Block({ Ast.IfStatement(firstCond, firstBlock, elseifs, tb[r].block) }, ifScope)
            end
            local mid    = l + math.ceil(len / 2)
            local bound  = math.floor((tb[mid-1].id + tb[mid].id) / 2)
            local ifScope= Scope:new(pScope)
            local lBlock = buildChain(tb, l, mid-1, ifScope)
            local rBlock = buildChain(tb, mid, r,   ifScope)
            local condStyle = math.random(1, 3)
            local cond, trueB, falseB
            if condStyle == 1 then
                cond = Ast.LessThanExpression(self:pos(ifScope), Ast.NumberExpression(bound))
                trueB, falseB = lBlock, rBlock
            elseif condStyle == 2 then
                cond = Ast.GreaterThanExpression(Ast.NumberExpression(bound), self:pos(ifScope))
                trueB, falseB = lBlock, rBlock
            else
                cond = Ast.GreaterThanExpression(self:pos(ifScope), Ast.NumberExpression(bound))
                trueB, falseB = rBlock, lBlock
            end
            return Ast.Block({ Ast.IfStatement(cond, trueB, {}, falseB) }, ifScope)
        end

        local whileBody = buildChain(blocks, 1, #blocks, self.containerFuncScope)

        self.whileScope:addReferenceToHigherScope(self.containerFuncScope, self.returnVar, 1)
        self.whileScope:addReferenceToHigherScope(self.containerFuncScope, self.posVar)
        self.containerFuncScope:addReferenceToHigherScope(self.scope, self.unpackVar)

        local declarations = { self.returnVar }
        for i, var in pairs(self.registerVars) do
            if i ~= MAX_REGS then table.insert(declarations, var) end
        end

        for i = #declarations, 2, -1 do
            local j = math.random(i)
            declarations[i], declarations[j] = declarations[j], declarations[i]
        end

        local stats = {}
        if self.maxUsedRegister >= MAX_REGS then
            table.insert(stats, Ast.LocalVariableDeclaration(
                self.containerFuncScope,
                { self.registerVars[MAX_REGS] },
                { Ast.TableConstructorExpression({}) }
            ))
        end

        table.insert(stats, Ast.LocalVariableDeclaration(self.containerFuncScope, declarations, {}))
        table.insert(stats, Ast.WhileStatement(whileBody, Ast.VariableExpression(self.containerFuncScope, self.posVar), self.containerFuncScope))
        table.insert(stats, self:setPos(self.containerFuncScope, nil))
        table.insert(stats, Ast.ReturnStatement({
            Ast.FunctionCallExpression(
                self:unpack(self.containerFuncScope),
                { Ast.VariableExpression(self.containerFuncScope, self.returnVar) }
            )
        }))

        return Ast.Block(stats, self.containerFuncScope)
    end
end
