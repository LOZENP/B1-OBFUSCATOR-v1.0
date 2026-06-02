import re

with open("Vm/OpCodes.lua", "r") as f:
    src = f.read()

# Fix rk helper - K[x.i] -> K[x.i+1]
src = src.replace(
    'return "K["..x.i.."]"',
    'return "K["..(x.i + 1).."]"'
)

# Fix LOADK - constMap index to direct Bx+1
src = src.replace(
    'return ("S[%d]=K[%d]"):format(inst.A, constMap[inst.Bx + 1])',
    'return ("S[%d]=K[%d]"):format(inst.A, inst.Bx + 1)'
)

# Fix GETGLOBAL
src = src.replace(
    'return ("S[%d]=Env[K[%d]]"):format(inst.A, constMap[inst.Bx + 1])',
    'return ("S[%d]=Env[K[%d]]"):format(inst.A, inst.Bx + 1)'
)

# Fix SETGLOBAL
src = src.replace(
    'return ("Env[K[%d]]=S[%d]"):format(constMap[inst.Bx + 1], inst.A)',
    'return ("Env[K[%d]]=S[%d]"):format(inst.Bx + 1, inst.A)'
)

# Fix JMP offset (subtract 1 to account for pc already incremented)
src = src.replace(
    'return ("pc=pc+%d"):format(inst.sBx)',
    'return ("pc=pc+%d"):format(inst.sBx - 1)'
)

# Fix EQ
src = src.replace(
    '''ops[23] = function(inst, _, constMap)
\tlocal cond = inst.A ~= 0 and "==" or "~="
\treturn ("if %s%s%s then pc=pc+1 end"):format(
\t\trk(inst.B,constMap), cond, rk(inst.C,constMap))
end''',
    '''ops[23] = function(inst, _, constMap)
\treturn ("if not(%s==%s)==(%s) then pc=pc+1 end"):format(
\t\trk(inst.B,constMap), rk(inst.C,constMap), inst.A ~= 0 and "true" or "false")
end'''
)

# Fix LT
src = src.replace(
    '''ops[24] = function(inst, _, constMap)
\tlocal cond = inst.A ~= 0 and "<" or ">="
\treturn ("if %s%s%s then pc=pc+1 end"):format(
\t\trk(inst.B,constMap), cond, rk(inst.C,constMap))
end''',
    '''ops[24] = function(inst, _, constMap)
\treturn ("if not(%s<%s)==(%s) then pc=pc+1 end"):format(
\t\trk(inst.B,constMap), rk(inst.C,constMap), inst.A ~= 0 and "true" or "false")
end'''
)

# Fix LE
src = src.replace(
    '''ops[25] = function(inst, _, constMap)
\tlocal cond = inst.A ~= 0 and "<=" or ">"
\treturn ("if %s%s%s then pc=pc+1 end"):format(
\t\trk(inst.B,constMap), cond, rk(inst.C,constMap))
end''',
    '''ops[25] = function(inst, _, constMap)
\treturn ("if not(%s<=%s)==(%s) then pc=pc+1 end"):format(
\t\trk(inst.B,constMap), rk(inst.C,constMap), inst.A ~= 0 and "true" or "false")
end'''
)

with open("Vm/OpCodes.lua", "w") as f:
    f.write(src)

print("Done! OpCodes.lua patched.")
