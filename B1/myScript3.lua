-- test.lua
local function add(a, b)
    return a + b
end

local function greet(name)
    print("Hello, " .. name .. "!")
    print("2 + 3 = " .. add(2, 3))
end

greet("World")
