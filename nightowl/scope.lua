local config = require("nightowl.config")

local Scope = {}
local scopeI = 0
local next_name_i = 1

function Scope:new(parent, name)
    scopeI = scopeI + 1
    local s = {
        isGlobal=false, parentScope=parent, variables={},
        variablesLookup={}, referenceCounts={},
        variablesFromHigherScopes={}, skipIdLookup={},
        name=name or ("scope_"..scopeI), children={},
        level=parent.level and (parent.level+1) or 1,
    }
    setmetatable(s,self); self.__index=self
    parent:addChild(s)
    return s
end

function Scope:newGlobal()
    local s = {
        isGlobal=true, parentScope=nil, variables={},
        variablesLookup={}, referenceCounts={},
        skipIdLookup={}, name="global_scope", children={}, level=0,
    }
    setmetatable(s,self); self.__index=self
    return s
end

function Scope:getParent() return self.parentScope end
function Scope:setParent(p)
    self.parentScope:removeChild(self)
    p:addChild(self)
    self.parentScope=p
    self.level=p.level+1
end

function Scope:addVariable(name, token)
    if not name then
        name=string.format("%s%i",config.IdentPrefix,next_name_i)
        next_name_i=next_name_i+1
    end
    table.insert(self.variables,name)
    local id=#self.variables
    self.variablesLookup[name]=id
    return id
end

function Scope:addDisabledVariable(name, token)
    if not name then
        name=string.format("%s%i",config.IdentPrefix,next_name_i)
        next_name_i=next_name_i+1
    end
    table.insert(self.variables,name)
    return #self.variables
end

function Scope:enableVariable(id)
    local name=self.variables[id]
    self.variablesLookup[name]=id
end

function Scope:addIfNotExists(id)
    if not self.variables[id] then
        local name=string.format("%s%i",config.IdentPrefix,next_name_i)
        next_name_i=next_name_i+1
        self.variables[id]=name
        self.variablesLookup[name]=id
    end
    return id
end

function Scope:hasVariable(name)
    if self.isGlobal then
        if self.variablesLookup[name]==nil then self:addVariable(name) end
        return true
    end
    return self.variablesLookup[name]~=nil
end

function Scope:getVariables()      return self.variables end
function Scope:getMaxId()          return #self.variables end
function Scope:getVariableName(id) return self.variables[id] end
function Scope:removeVariable(id)
    local name=self.variables[id]
    self.variables[id]=nil
    self.variablesLookup[name]=nil
    self.skipIdLookup[id]=true
end
function Scope:resetReferences(id) self.referenceCounts[id]=0 end
function Scope:getReferences(id)   return self.referenceCounts[id] or 0 end
function Scope:addReference(id)    self.referenceCounts[id]=(self.referenceCounts[id] or 0)+1 end
function Scope:removeReference(id) self.referenceCounts[id]=(self.referenceCounts[id] or 0)-1 end

function Scope:resolve(name)
    if self:hasVariable(name) then return self, self.variablesLookup[name] end
    assert(self.parentScope)
    local sc,id=self.parentScope:resolve(name)
    self:addReferenceToHigherScope(sc,id,nil,true)
    return sc,id
end

function Scope:resolveGlobal(name)
    if self.isGlobal and self:hasVariable(name) then return self,self.variablesLookup[name] end
    assert(self.parentScope)
    local sc,id=self.parentScope:resolveGlobal(name)
    self:addReferenceToHigherScope(sc,id,nil,true)
    return sc,id
end

function Scope:clearReferences()
    self.referenceCounts={}
    self.variablesFromHigherScopes={}
end

function Scope:addChild(child)
    for sc,ids in pairs(child.variablesFromHigherScopes) do
        for id,cnt in pairs(ids) do
            if cnt and cnt>0 then self:addReferenceToHigherScope(sc,id,cnt) end
        end
    end
    table.insert(self.children,child)
end

function Scope:removeChild(child)
    for i,v in ipairs(self.children) do
        if v==child then
            for sc,ids in pairs(v.variablesFromHigherScopes) do
                for id,cnt in pairs(ids) do
                    if cnt and cnt>0 then self:removeReferenceToHigherScope(sc,id,cnt) end
                end
            end
            return table.remove(self.children,i)
        end
    end
end

function Scope:addReferenceToHigherScope(scope,id,n,b)
    n=n or 1
    if self.isGlobal then return end
    if scope==self then
        self.referenceCounts[id]=(self.referenceCounts[id] or 0)+n
        return
    end
    if not self.variablesFromHigherScopes[scope] then self.variablesFromHigherScopes[scope]={} end
    local sr=self.variablesFromHigherScopes[scope]
    sr[id]=(sr[id] or 0)+n
    if not b then self.parentScope:addReferenceToHigherScope(scope,id,n) end
end

function Scope:removeReferenceToHigherScope(scope,id,n,b)
    n=n or 1
    if self.isGlobal then return end
    if scope==self then
        self.referenceCounts[id]=(self.referenceCounts[id] or 0)-n
        return
    end
    if not self.variablesFromHigherScopes[scope] then self.variablesFromHigherScopes[scope]={} end
    local sr=self.variablesFromHigherScopes[scope]
    sr[id]=(sr[id] or 0)-n
    if not b then self.parentScope:removeReferenceToHigherScope(scope,id,n) end
end

function Scope:renameVariables(settings)
    if not self.isGlobal then
        local prefix=settings.prefix or ""
        local forbidden={}
        for _,kw in pairs(settings.Keywords) do forbidden[kw]=true end
        for sc,ids in pairs(self.variablesFromHigherScopes) do
            for id,cnt in pairs(ids) do
                if cnt and cnt>0 then
                    local n=sc:getVariableName(id)
                    forbidden[n]=true
                end
            end
        end
        self.variablesLookup={}
        local i=0
        for id,origName in pairs(self.variables) do
            if not self.skipIdLookup[id] and (self.referenceCounts[id] or 0)>=0 then
                local name
                repeat
                    name=prefix..settings.generateName(i,self,origName)
                    if name==nil then name=origName end
                    i=i+1
                until not forbidden[name]
                self.variables[id]=name
                self.variablesLookup[name]=id
            end
        end
    end
    for _,child in pairs(self.children) do
        child:renameVariables(settings)
    end
end

return Scope
