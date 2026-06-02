local pipeline = require("Pipeline")
local settings = require("Input.Settings")

local args = {...}

_G.display = function(msg, color)
	local colors = {
		red="\27[31m", green="\27[32m",
		yellow="\27[33m", cyan="\27[36m",
		reset="\27[0m"
	}
	local c = colors[color] or colors.green
	print(c .. msg .. colors.reset)
end

_G.table.find = _G.table.find or function(t, v)
	for i, x in ipairs(t) do if x == v then return i end end
end

local function isFlag(v) return type(v)=="string" and v:sub(1,2)=="--" end
local function exists(p)
	local f = io.open(p,"r")
	if f then f:close() return true end
	return false
end

if table.find(args,"--help") then
	print("Usage: lua Main.lua <input> <output> [flags]")
	print("  --encryptstrings")
	print("  --controlflowflattening")
	print("  --numexpr")
	print("  --minify")
	print("  --debug")
	os.exit(0)
end

local inputFile  = args[1]
local outputFile = args[2]

if not inputFile or isFlag(inputFile) or not exists(inputFile) then
	print("Error: provide a valid input file")
	os.exit(1)
end
if not outputFile or isFlag(outputFile) then
	print("Error: provide an output file path")
	os.exit(1)
end

settings.EncryptStrings        = table.find(args,"--encryptstrings")        and true or false
settings.ControlFlowFlattening = table.find(args,"--controlflowflattening") and true or false
settings.NumberToExpressions   = table.find(args,"--numexpr")               and true or false
settings.Minify                = table.find(args,"--minify")                and true or false
settings.Debug                 = table.find(args,"--debug")                 and true or false

_G.display("n1 obfuscator starting...", "cyan")
pipeline(inputFile, outputFile)
