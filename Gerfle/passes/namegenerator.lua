local util = require("core.util")
local shuffle = util.shuffle
local chararray = util.chararray

local VarDigits      = chararray("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
local VarStartDigits = chararray("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")

local function mangledName(id,_)
    local name=""
    local d=id%#VarStartDigits
    id=(id-d)/#VarStartDigits
    name=name..VarStartDigits[d+1]
    while id>0 do
        local e=id%#VarDigits
        id=(id-e)/#VarDigits
        name=name..VarDigits[e+1]
    end
    return name
end

local NameGenerator = {
    generateName = mangledName,
    prepare = function(_)
        shuffle(VarDigits)
        shuffle(VarStartDigits)
    end
}

return NameGenerator
