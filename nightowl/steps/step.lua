local logger = require("nightowl.logger")
local util   = require("nightowl.util")

local Step = {}
Step.SettingsDescriptor = {}
Step.Name        = "Abstract Step"
Step.Description = "Abstract Step"

function Step:new(settings)
    local instance = {}
    setmetatable(instance,self); self.__index=self
    if type(settings)~="table" then settings={} end
    for key,data in pairs(self.SettingsDescriptor) do
        if settings[key]==nil then
            if data.default==nil then
                logger:error(string.format("Setting \"%s\" not provided for step \"%s\"",key,self.Name))
            end
            instance[key]=data.default
        elseif data.type=="enum" then
            local lk=util.lookupify(data.values)
            if not lk[settings[key]] then
                logger:error(string.format("Invalid value for \"%s\" in step \"%s\"",key,self.Name))
            end
            instance[key]=settings[key]
        elseif data.type=="table" then
            instance[key]=settings[key]
        elseif type(settings[key])~=data.type then
            logger:error(string.format("Invalid type for \"%s\" in step \"%s\"",key,self.Name))
        else
            instance[key]=settings[key]
        end
    end
    instance:init()
    return instance
end

function Step:init()  logger:error("Abstract steps cannot be created") end
function Step:apply() logger:error("Abstract steps cannot be applied") end
function Step:extend()
    local ext={}
    setmetatable(ext,self); self.__index=self
    return ext
end

return Step
