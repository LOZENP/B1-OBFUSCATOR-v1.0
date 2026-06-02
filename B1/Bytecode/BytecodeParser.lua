local Enums  = require("Bytecode.Enums")
local BcUtils = require("Bytecode.BcUtils")

local function decodeRK(x)
	if x >= 256 then return {k=true,  i=x-256} end
	return          {k=false, i=x}
end

local function decodeInstruction(raw)
	local opcode = raw % 64
	local a      = math.floor(raw / 64) % 256
	local enum   = Enums[opcode]
	if not enum then error("Unknown opcode: "..tostring(opcode)) end
	local inst = {Opcode=opcode, OpcodeName=enum.Mnemonic, A=a, Raw=raw}
	local mode = enum.Type
	if mode == "iABC" then
		inst.B = decodeRK(math.floor(raw / 8388608) % 512)
		inst.C = decodeRK(math.floor(raw / 16384)   % 512)
	elseif mode == "iABx" then
		inst.Bx = math.floor(raw / 16384)
	elseif mode == "iAsBx" then
		inst.sBx = math.floor(raw / 16384) - 131071
	end
	return inst
end

local function readHeader(p)
	local sig = p:ReadBytes(4)
	if sig ~= "\27Lua" then error("Invalid Lua signature") end
	local ver = p:ReadByte()
	if ver ~= 0x51 then error("Expected Lua 5.1 bytecode") end
	p:ReadByte() -- format
	p:ReadByte() -- endianness
	local intSize  = p:ReadByte()
	local sizeTSz  = p:ReadByte()
	p:ReadByte()   -- instruction size
	p:ReadByte()   -- lua number size
	p:ReadByte()   -- integral flag
	p.sizeT = sizeTSz
end

local function readProto(p)
	local proto = {
		Source         = p:ReadString(),
		LineDefined    = p:ReadInt32(),
		LastLineDefined= p:ReadInt32(),
		NumUpvalues    = p:ReadByte(),
		NumParams      = p:ReadByte(),
		IsVararg       = p:ReadByte(),
		MaxStackSize   = p:ReadByte(),
		Instructions   = {},
		Constants      = {},
		Protos         = {},
	}

	-- instructions
	local iCount = p:ReadInt32()
	for i = 1, iCount do
		proto.Instructions[i] = decodeInstruction(p:ReadInt32())
	end

	-- constants
	local kCount = p:ReadInt32()
	for i = 1, kCount do
		local t = p:ReadByte()
		if t == 0 then
			proto.Constants[i] = {Type="nil",    Value=nil}
		elseif t == 1 then
			proto.Constants[i] = {Type="boolean", Value=p:ReadByte() ~= 0}
		elseif t == 3 then
			proto.Constants[i] = {Type="number",  Value=p:ReadDouble()}
		elseif t == 4 then
			proto.Constants[i] = {Type="string",  Value=p:ReadString()}
		end
	end

	-- nested protos
	local pCount = p:ReadInt32()
	for i = 1, pCount do
		proto.Protos[i] = readProto(p)
	end

	-- skip source lines, locals, upvalue names
	local linesN = p:ReadInt32()
	for i = 1, linesN do p:ReadInt32() end
	local localsN = p:ReadInt32()
	for i = 1, localsN do p:ReadString(); p:ReadInt32(); p:ReadInt32() end
	local upvalsN = p:ReadInt32()
	for i = 1, upvalsN do p:ReadString() end

	return proto
end

return function(bytecode)
	local p = BcUtils.new(bytecode)
	readHeader(p)
	local main = readProto(p)
	return main
end
