local parser   = require("Bytecode.BytecodeParser")
local treeGen  = require("Vm.TreeGenerator")
local settings = require("Input.Settings")

local function readFile(path)
	local f = io.open(path, "rb")
	local c = f:read("*all")
	f:close()
	return c
end

local function writeFile(path, content)
	local f = io.open(path, "w")
	f:write(content)
	f:close()
end

return function(inputFile, outputFile)
	outputFile = outputFile or "output.lua"

	_G.display("Compiling...", "green")
	local ok = os.execute("luac5.1 -o n1_out.luac "..inputFile)
	if ok ~= 0 and ok ~= true then
		_G.display("Compilation failed!", "red")
		return
	end

	local bytecode = readFile("n1_out.luac")
	if not bytecode or #bytecode == 0 then
		_G.display("No bytecode output!", "red")
		return
	end

	_G.display("Parsing bytecode...", "green")
	local parsed = parser(bytecode)

	_G.display("Generating VM...", "green")
	local output = treeGen(parsed)

	writeFile(outputFile, output)
	_G.display("Done! Output: "..outputFile, "green")
end
