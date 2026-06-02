local settings = require("Input.Settings")
local OpCodes  = require("Vm.OpCodes")

math.randomseed(os.time())

-- base64 encoder
local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function b64encode(s)
	local out = {}
	local n = #s % 3
	local padded = s
	local pad = ""
	if n == 1 then padded = s.."\0\0" pad = "==" end
	if n == 2 then padded = s.."\0"   pad = "="  end
	for i = 1, #padded, 3 do
		local a,b2,c = padded:byte(i, i+2)
		local v = a*65536 + b2*256 + c
		out[#out+1] = b64chars:sub(math.floor(v/262144)%64+1, math.floor(v/262144)%64+1)
		out[#out+1] = b64chars:sub(math.floor(v/4096)%64+1,   math.floor(v/4096)%64+1)
		out[#out+1] = b64chars:sub(math.floor(v/64)%64+1,     math.floor(v/64)%64+1)
		out[#out+1] = b64chars:sub(v%64+1, v%64+1)
	end
	local result = table.concat(out)
	return result:sub(1, #result - #pad)..pad
end

local B64_DECODER = [[local function __b64d(s) local b="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/" local t={} s=s:gsub("[^"..b.."=]","") for i=1,#s,4 do local c1,c2,c3,c4=s:byte(i,i+3) local function v(x) if x==61 then return 0 end return b:find(string.char(x))-1 end local n=v(c1)*262144+v(c2)*4096+v(c3)*64+v(c4) t[#t+1]=string.char(math.floor(n/65536)%256) if c3~=61 then t[#t+1]=string.char(math.floor(n/256)%256) end if c4~=61 then t[#t+1]=string.char(n%256) end end return table.concat(t) end]]

-- safe string serializer for Lua 5.1
-- no %q because it produces \' and "\ " which are invalid in 5.1
local function serializeString(s)
	local out = {}
	for i = 1, #s do
		local b = s:byte(i)
		if b == 34 then      -- "
			out[i] = '\\"'
		elseif b == 92 then  -- \
			out[i] = '\\\\'
		elseif b == 10 then  -- newline
			out[i] = '\\n'
		elseif b == 13 then  -- carriage return
			out[i] = '\\r'
		elseif b == 0 then   -- null
			out[i] = '\\0'
		elseif b < 32 or b > 126 then
			out[i] = '\\'..tostring(b)
		else
			out[i] = string.char(b)
		end
	end
	return '"'..table.concat(out)..'"'
end

local function serializeConst(c)
	if c.Type == "nil"     then return "nil" end
	if c.Type == "boolean" then return tostring(c.Value) end
	if c.Type == "number"  then return tostring(c.Value) end
	if c.Type == "string"  then
		if settings.EncryptStrings and c.Value and #c.Value > 0 then
			return ('__b64d("'..b64encode(c.Value)..'")'):format()
		end
		return serializeString(c.Value)
	end
	return "nil"
end

local protoFuncs = {}
local protoOrder = {}
local protoIndex = 0

local function buildProto(proto, depth)
	local myId = protoIndex
	protoIndex = protoIndex + 1

	local kParts = {}
	for i, c in ipairs(proto.Constants) do
		kParts[i] = serializeConst(c)
	end
	local kTable = "{"..table.concat(kParts,",").."}"

	local nestedIds = {}
	local savedIndex = protoIndex
	for i = 1, #proto.Protos do
		nestedIds[i] = protoIndex
		protoIndex = protoIndex + 1
	end
	local afterNested = protoIndex
	protoIndex = savedIndex

	for i, subProto in ipairs(proto.Protos) do
		protoIndex = nestedIds[i]
		buildProto(subProto, depth+1)
	end
	protoIndex = afterNested

	local closureIdx = 0
	local instLines  = {}

	for pc, inst in ipairs(proto.Instructions) do
		local line

		if inst.Opcode == 36 then -- CLOSURE
			closureIdx = closureIdx + 1
			local pid = nestedIds[closureIdx]
			if pid then
				line = ("S[%d]=__proto_%d(Env,U)"):format(inst.A, pid)
			else
				line = ("S[%d]=function()end"):format(inst.A)
			end
		else
			local handler = OpCodes[inst.Opcode]
			if handler then
				local ok, result = pcall(handler, inst)
				if ok and result then
					line = result
				else
					line = ("error('n1:op%d err')"):format(inst.Opcode)
				end
			else
				line = ("error('n1:unhandled op %d pc %d')"):format(inst.Opcode, pc)
			end
		end

		line = line:gsub("[\n\r]"," "):gsub("%s%s+"," ")
		instLines[#instLines+1] = ("[%d]=function() %s end"):format(pc, line)
	end

	local D = "{"..table.concat(instLines,",").."}"
	local fnName = ("__proto_%d"):format(myId)
	local body = ("local function %s(Env,_pU) local K=%s local S,U,VA,top={},{},{},-1 local pc=1 local D=%s while true do local _f=D[pc] if not _f then break end pc=pc+1 _f() end end"):format(
		fnName, kTable, D)

	protoFuncs[myId] = body
	protoOrder[#protoOrder+1] = myId
end

return function(parsed)
	protoFuncs = {}
	protoOrder = {}
	protoIndex = 0

	buildProto(parsed, 0)

	local parts = {}
	table.sort(protoOrder)

	if settings.EncryptStrings then
		parts[#parts+1] = B64_DECODER
	end

	for _, id in ipairs(protoOrder) do
		parts[#parts+1] = protoFuncs[id]
	end
	parts[#parts+1] = "__proto_0(_ENV or getfenv())"

	local output = table.concat(parts," ")
	output = output:gsub("[\n\r\t]"," "):gsub("%s%s+"," ")
	return output
end
