-- block.lua

return function(Compiler)
    function Compiler:createBlock()
        local id
        repeat
            id = math.random(0, 2^24)
        until not self.usedBlockIds[id]
        self.usedBlockIds[id] = true
        local scope = self.Scope:new(self.containerFuncScope)
        local block = {
            id = id,
            statements = {},
            scope = scope,
            advanceToNextBlock = true,
        }
        table.insert(self.blocks, block)
        return block
    end

    function Compiler:setActiveBlock(block)
        self.activeBlock = block
    end

    function Compiler:addStatement(statement, writes, reads, usesUpvals)
        if self.activeBlock.advanceToNextBlock then
            local function lookupify(tb)
                local out = {}
                for _, v in ipairs(tb) do out[v] = true end
                return out
            end
            table.insert(self.activeBlock.statements, {
                statement  = statement,
                writes     = lookupify(writes or {}),
                reads      = lookupify(reads or {}),
                usesUpvals = usesUpvals or false,
            })
        end
    end
end
