--[[

local Compiler = require("nightowl.compiler.compiler")

-- inside applyPipeline, after parsing:
local compiler = Compiler:new()
ast = compiler:compile(ast)

]]

local Scope    = require("ghoul.scope")      -- your Scope from nightowl.lua
local Ast      = require("ghoul.ast")        -- your Ast from nightowl.lua
local util     = require("ghoul.util")       -- your util from nightowl.lua
local visitast = require("ghoul.visitast")   -- your visitAst from nightowl.lua

local blockModule      = require("ghoul.compiler.block")
local registerModule   = require("ghoul.compiler.register")
local upvalueModule    = require("ghoul.compiler.upvalue")
local emitModule       = require("ghoul.compiler.emit")
local compileCoreModule= require("ghoul.compiler.compile_core")
local expressionHandlerFactory = require("ghoul.compiler.expressions")
local statementHandlerFactory  = require("ghoul.compiler.statements")

local AstKind = Ast.AstKind
local unpack  = table.unpack or unpack

local Compiler = {}

function Compiler:new()
    local c = {
        blocks         = {},
        registers      = {},
        activeBlock    = nil,
        registersForVar= {},
        usedRegisters  = 0,
        maxUsedRegister= 0,
        registerVars   = {},

        VAR_REGISTER    = newproxy and newproxy(false) or {},
        RETURN_ALL      = newproxy and newproxy(false) or {},
        POS_REGISTER    = newproxy and newproxy(false) or {},
        RETURN_REGISTER = newproxy and newproxy(false) or {},
        UPVALUE         = newproxy and newproxy(false) or {},

        -- inject dependencies so sub-modules can use them
        Ast      = Ast,
        Scope    = Scope,
        visitast = visitast,

        BIN_OPS = (function()
            local out = {}
            local bins = {
                AstKind.LessThanExpression, AstKind.GreaterThanExpression,
                AstKind.LessThanOrEqualsExpression, AstKind.GreaterThanOrEqualsExpression,
                AstKind.NotEqualsExpression, AstKind.EqualsExpression,
                AstKind.StrCatExpression, AstKind.AddExpression, AstKind.SubExpression,
                AstKind.MulExpression, AstKind.DivExpression, AstKind.ModExpression, AstKind.PowExpression,
            }
            for _, v in ipairs(bins) do out[v] = true end
            return out
        end)(),
    }
    setmetatable(c, self); self.__index = self
    return c
end

blockModule(Compiler)
registerModule(Compiler)
upvalueModule(Compiler)
emitModule(Compiler)
compileCoreModule(Compiler)

-- Override expression/statement handlers with factory-built tables
local _exprHandlers = expressionHandlerFactory(Ast)
local _stmtHandlers = statementHandlerFactory(Ast)

function Compiler:compileStatement(statement, funcDepth)
    local handler = _stmtHandlers[statement.kind]
    if handler then handler(self, statement, funcDepth); return end
    error("[NightOwl] Unknown statement: " .. tostring(statement.kind))
end

function Compiler:compileExpression(expression, funcDepth, numReturns)
    local handler = _exprHandlers[expression.kind]
    if handler then return handler(self, expression, funcDepth, numReturns) end
    error("[NightOwl] Unknown expression: " .. tostring(expression.kind))
end

function Compiler:pushRegisterUsageInfo()
    table.insert(self.registerUsageStack, {
        usedRegisters = self.usedRegisters,
        registers     = self.registers,
    })
    self.usedRegisters = 0
    self.registers     = {}
end

function Compiler:popRegisterUsageInfo()
    local info = table.remove(self.registerUsageStack)
    self.usedRegisters = info.usedRegisters
    self.registers     = info.registers
end

function Compiler:getCreateClosureVar(argCount)
    if not self.createClosureVars[argCount] then
        local var = Ast.AssignmentVariable(self.scope, self.scope:addVariable())
        local createClosureScope    = Scope:new(self.scope)
        local createClosureSubScope = Scope:new(createClosureScope)

        local posArg    = createClosureScope:addVariable()
        local upvalsArg = createClosureScope:addVariable()
        local proxyObj  = createClosureScope:addVariable()
        local funcVar   = createClosureScope:addVariable()

        createClosureSubScope:addReferenceToHigherScope(self.scope, self.containerFuncVar)
        createClosureSubScope:addReferenceToHigherScope(createClosureScope, posArg)
        createClosureSubScope:addReferenceToHigherScope(createClosureScope, upvalsArg, 1)
        createClosureSubScope:addReferenceToHigherScope(createClosureScope, proxyObj)

        local argsTb, argsTb2 = {}, {}
        for i = 1, argCount do
            local arg = createClosureSubScope:addVariable()
            argsTb[i]  = Ast.VariableExpression(createClosureSubScope, arg)
            argsTb2[i] = Ast.TableEntry(Ast.VariableExpression(createClosureSubScope, arg))
        end

        local val = Ast.FunctionLiteralExpression({
            Ast.VariableExpression(createClosureScope, posArg),
            Ast.VariableExpression(createClosureScope, upvalsArg),
        }, Ast.Block({
            Ast.LocalVariableDeclaration(createClosureScope, {proxyObj}, {
                Ast.VariableExpression(createClosureScope, upvalsArg)
            }),
            Ast.LocalVariableDeclaration(createClosureScope, {funcVar}, {
                Ast.FunctionLiteralExpression(argsTb, Ast.Block({
                    Ast.ReturnStatement({
                        Ast.FunctionCallExpression(
                            Ast.VariableExpression(self.scope, self.containerFuncVar),
                            {
                                Ast.VariableExpression(createClosureScope, posArg),
                                Ast.TableConstructorExpression(argsTb2),
                                Ast.VariableExpression(createClosureScope, upvalsArg),
                                Ast.VariableExpression(createClosureScope, proxyObj),
                            }
                        )
                    })
                }, createClosureSubScope))
            }),
            Ast.ReturnStatement({ Ast.VariableExpression(createClosureScope, funcVar) })
        }, createClosureScope))

        self.createClosureVars[argCount] = { var = var, val = val }
    end

    local var = self.createClosureVars[argCount].var
    return var.scope, var.id
end

function Compiler:compile(ast)
    self.blocks          = {}
    self.registers       = {}
    self.activeBlock     = nil
    self.registersForVar = {}
    self.scopeFunctionDepths = {}
    self.maxUsedRegister = 0
    self.usedRegisters   = 0
    self.registerVars    = {}
    self.usedBlockIds    = {}
    self.upvalVars       = {}
    self.registerUsageStack = {}
    self.createClosureVars  = {}

    local newGlobalScope = Scope:newGlobal()
    local psc = Scope:new(newGlobalScope, nil)

    local _, getfenvVar  = newGlobalScope:resolve("getfenv")
    local _, tableVar    = newGlobalScope:resolve("table")
    local _, unpackVar   = newGlobalScope:resolve("unpack")
    local _, envVar      = newGlobalScope:resolve("_ENV")
    local _, selectVar   = newGlobalScope:resolve("select")

    psc:addReferenceToHigherScope(newGlobalScope, getfenvVar, 2)
    psc:addReferenceToHigherScope(newGlobalScope, tableVar)
    psc:addReferenceToHigherScope(newGlobalScope, unpackVar)
    psc:addReferenceToHigherScope(newGlobalScope, envVar)

    self.scope = Scope:new(psc)
    self.envVar            = self.scope:addVariable()
    self.containerFuncVar  = self.scope:addVariable()
    self.unpackVar         = self.scope:addVariable()
    self.selectVar         = self.scope:addVariable()

    local argVar = self.scope:addVariable()

    self.containerFuncScope = Scope:new(self.scope)
    self.whileScope         = Scope:new(self.containerFuncScope)

    self.posVar              = self.containerFuncScope:addVariable()
    self.argsVar             = self.containerFuncScope:addVariable()
    self.currentUpvaluesVar  = self.containerFuncScope:addVariable()
    self.returnVar           = self.containerFuncScope:addVariable()

    -- Simplified upvalue table: plain {}
    self.upvaluesTable   = self.scope:addVariable()
    self.allocUpvalFunction = self.scope:addVariable()
    self.currentUpvalId  = self.scope:addVariable()

    self.createVarargClosureVar = self.scope:addVariable()

    local createClosureScope    = Scope:new(self.scope)
    local createClosurePosArg   = createClosureScope:addVariable()
    local createClosureUpvalsArg= createClosureScope:addVariable()
    local createClosureProxyObj = createClosureScope:addVariable()
    local createClosureFuncVar  = createClosureScope:addVariable()
    local createClosureSubScope = Scope:new(createClosureScope)

    local upvalEntries = {}
    local upvalueIds   = {}
    self.getUpvalueId = function(s, scope, id)
        local scopeFuncDepth = s.scopeFunctionDepths[scope]
        if scopeFuncDepth == 0 then
            if upvalueIds[id] then return upvalueIds[id] end
            local expression = Ast.FunctionCallExpression(
                Ast.VariableExpression(s.scope, s.allocUpvalFunction), {}
            )
            table.insert(upvalEntries, Ast.TableEntry(expression))
            local uid = #upvalEntries
            upvalueIds[id] = uid
            return uid
        else
            error("[NightOwl Compiler] Unresolved upvalue")
        end
    end

    createClosureSubScope:addReferenceToHigherScope(self.scope, self.containerFuncVar)
    createClosureSubScope:addReferenceToHigherScope(createClosureScope, createClosurePosArg)
    createClosureSubScope:addReferenceToHigherScope(createClosureScope, createClosureUpvalsArg, 1)
    createClosureSubScope:addReferenceToHigherScope(createClosureScope, createClosureProxyObj)

    self:compileTopNode(ast)

    -- Build function node assignments (shuffled)
    local functionNodeAssignments = {
        {
            var = Ast.AssignmentVariable(self.scope, self.containerFuncVar),
            val = Ast.FunctionLiteralExpression({
                Ast.VariableExpression(self.containerFuncScope, self.posVar),
                Ast.VariableExpression(self.containerFuncScope, self.argsVar),
                Ast.VariableExpression(self.containerFuncScope, self.currentUpvaluesVar),
            }, self:emitContainerFuncBody()),
        },
        {
            var = Ast.AssignmentVariable(self.scope, self.createVarargClosureVar),
            val = Ast.FunctionLiteralExpression({
                Ast.VariableExpression(createClosureScope, createClosurePosArg),
                Ast.VariableExpression(createClosureScope, createClosureUpvalsArg),
            }, Ast.Block({
                Ast.LocalVariableDeclaration(createClosureScope, {createClosureProxyObj}, {
                    Ast.VariableExpression(createClosureScope, createClosureUpvalsArg)
                }),
                Ast.LocalVariableDeclaration(createClosureScope, {createClosureFuncVar}, {
                    Ast.FunctionLiteralExpression({ Ast.VarargExpression() }, Ast.Block({
                        Ast.ReturnStatement({
                            Ast.FunctionCallExpression(
                                Ast.VariableExpression(self.scope, self.containerFuncVar),
                                {
                                    Ast.VariableExpression(createClosureScope, createClosurePosArg),
                                    Ast.TableConstructorExpression({ Ast.TableEntry(Ast.VarargExpression()) }),
                                    Ast.VariableExpression(createClosureScope, createClosureUpvalsArg),
                                    Ast.VariableExpression(createClosureScope, createClosureProxyObj),
                                }
                            )
                        })
                    }, createClosureSubScope))
                }),
                Ast.ReturnStatement({ Ast.VariableExpression(createClosureScope, createClosureFuncVar) })
            }, createClosureScope)),
        },
        {
            var = Ast.AssignmentVariable(self.scope, self.upvaluesTable),
            val = Ast.TableConstructorExpression({}),
        },
        {
            var = Ast.AssignmentVariable(self.scope, self.allocUpvalFunction),
            val = self:createAllocUpvalFunction(),
        },
        {
            var = Ast.AssignmentVariable(self.scope, self.currentUpvalId),
            val = Ast.NumberExpression(0),
        },
    }

    local tbl = {
        Ast.VariableExpression(self.scope, self.containerFuncVar),
        Ast.VariableExpression(self.scope, self.createVarargClosureVar),
        Ast.VariableExpression(self.scope, self.upvaluesTable),
        Ast.VariableExpression(self.scope, self.allocUpvalFunction),
        Ast.VariableExpression(self.scope, self.currentUpvalId),
    }

    for _, entry in pairs(self.createClosureVars) do
        table.insert(functionNodeAssignments, entry)
        table.insert(tbl, Ast.VariableExpression(entry.var.scope, entry.var.id))
    end

    util.shuffle(functionNodeAssignments)
    local lhs, rhs = {}, {}
    for i, v in ipairs(functionNodeAssignments) do
        lhs[i] = v.var
        rhs[i] = v.val
    end

    util.shuffle(tbl)

    -- Shuffle the env/unpack/select/argVar init order
    local ids = {}
    for i = 1, 4 do ids[i] = i end
    util.shuffle(ids)

    local items = {
        Ast.VariableExpression(self.scope, self.envVar),
        Ast.VariableExpression(self.scope, self.unpackVar),
        Ast.VariableExpression(self.scope, self.selectVar),
        Ast.VariableExpression(self.scope, argVar),
    }
    local astItems = {
        Ast.OrExpression(
            Ast.AndExpression(
                Ast.VariableExpression(newGlobalScope, getfenvVar),
                Ast.FunctionCallExpression(Ast.VariableExpression(newGlobalScope, getfenvVar), {})
            ),
            Ast.VariableExpression(newGlobalScope, envVar)
        ),
        Ast.OrExpression(
            Ast.VariableExpression(newGlobalScope, unpackVar),
            Ast.IndexExpression(Ast.VariableExpression(newGlobalScope, tableVar), Ast.StringExpression("unpack"))
        ),
        Ast.VariableExpression(newGlobalScope, selectVar),
        Ast.TableConstructorExpression({ Ast.TableEntry(Ast.VarargExpression()) }),
    }

    local funcArgs = {}
    for _, i in ipairs(ids) do table.insert(funcArgs, items[i]) end
    for _, v in ipairs(tbl) do table.insert(funcArgs, v) end

    local funcCallArgs = {}
    for _, i in ipairs(ids) do table.insert(funcCallArgs, astItems[i]) end

    local functionNode = Ast.FunctionLiteralExpression(funcArgs,
        Ast.Block({
            Ast.AssignmentStatement(lhs, rhs),
            Ast.ReturnStatement({
                Ast.FunctionCallExpression(
                    Ast.FunctionCallExpression(
                        Ast.VariableExpression(self.scope, self.createVarargClosureVar),
                        {
                            Ast.NumberExpression(self.startBlockId),
                            Ast.TableConstructorExpression(upvalEntries),
                        }
                    ),
                    {
                        Ast.FunctionCallExpression(
                            Ast.VariableExpression(self.scope, self.unpackVar),
                            { Ast.VariableExpression(self.scope, argVar) }
                        )
                    }
                )
            })
        }, self.scope)
    )

    return Ast.TopNode(Ast.Block({
        Ast.ReturnStatement({
            Ast.FunctionCallExpression(functionNode, funcCallArgs)
        })
    }, psc), newGlobalScope)
end

return Compiler
