local settings = require("Input.Settings")
local OpCodes  = require("Vm.OpCodes")

math.randomseed(os.time())

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

local function serializeString(s)
	local out = {}
	for i = 1, #s do
		local b = s:byte(i)
		if b == 34 then
			out[i] = '\\"'
		elseif b == 92 then
			out[i] = '\\\\'
		elseif b == 10 then
			out[i] = '\\n'
		elseif b == 13 then
			out[i] = '\\r'
		elseif b == 0 then
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
			return '__b64d("'..b64encode(c.Value)..'")'
		end
		return serializeString(c.Value)
	end
	return "nil"
end

local protoFuncs = {}
local protoOrder = {}
local protoIds   = {}
local protoIndex = 0

local function assignIds(proto)
	protoIds[proto] = protoIndex
	protoIndex = protoIndex + 1
	for _, sub in ipairs(proto.Protos) do
		assignIds(sub)
	end
end

local function buildProto(proto)
	local myId = protoIds[proto]
	local np   = proto.NumParams
	local isva = proto.IsVararg

	local kParts = {}
	for i, c in ipairs(proto.Constants) do
		kParts[i] = serializeConst(c)
	end
	local kTable = "{"..table.concat(kParts,",").."}"

	local closureIdx = 0
	local instLines  = {}
	local skipUntil  = 0

	for pc, inst in ipairs(proto.Instructions) do
		if pc <= skipUntil then
			-- skip upvalue pseudo-instructions after CLOSURE

		elseif inst.Opcode == 36 then -- CLOSURE
			closureIdx = closureIdx + 1
			local sub = proto.Protos[closureIdx]
			if sub then
				local pid   = protoIds[sub]
				local snups = sub.NumUpvalues
				local uvParts = {}
				for u = 1, snups do
					local pseudo = proto.Instructions[pc + u]
					if pseudo then
						if pseudo.Opcode == 0 then
							-- MOVE: capture a local register
							uvParts[u] = ("S[%d]"):format(pseudo.B.i)
						elseif pseudo.Opcode == 4 then
							-- GETUPVAL: pass parent upvalue through
							uvParts[u] = ("U[%d]"):format(pseudo.B.i)
						else
							uvParts[u] = "nil"
						end
					else
						uvParts[u] = "nil"
					end
				end
				skipUntil = pc + snups
				local uvTable = "{"..table.concat(uvParts,",").."}"
				local line = ("S[%d]=__proto_%d(Env,%s)"):format(inst.A, pid, uvTable)
				line = line:gsub("[\n\r]"," "):gsub("%s%s+"," ")
				instLines[#instLines+1] = ("[%d]=function() %s end"):format(pc, line)
			else
				instLines[#instLines+1] = ("[%d]=function() S[%d]=function()end end"):format(pc, inst.A)
			end

		else
			local handler = OpCodes[inst.Opcode]
			local line
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
			line = line:gsub("[\n\r]"," "):gsub("%s%s+"," ")
			instLines[#instLines+1] = ("[%d]=function() %s end"):format(pc, line)
		end
	end

	-- build arg loader: put call args into S[0..np-1]
	local argLoads = {}
	for i = 0, np - 1 do
		argLoads[#argLoads+1] = ("S[%d]=_a[%d]"):format(i, i+1)
	end
	local argLoadStr = table.concat(argLoads, " ")

	-- vararg: extra args beyond np go into VA
	local vaStr = ""
	if isva and isva ~= 0 then
		vaStr = ("for _vi=%d,#_a do VA[#VA+1]=_a[_vi] end"):format(np + 1)
	end

	-- D is inside the returned function so S/VA/top are in scope for closures
	local instStr = table.concat(instLines, ",")
	local fnName  = ("__proto_%d"):format(myId)

	local body = ("%s=function(Env,_pU) local _unpack=table.unpack or unpack local U=_pU or {} local K=%s return function(...) local _a={...} local S,VA,top={},{},-1 %s %s local D={%s} local pc=1 while true do local _f=D[pc] if not _f then break end pc=pc+1 _f() end end end"):format(
		fnName, kTable, argLoadStr, vaStr, instStr)

	protoFuncs[myId] = body
	protoOrder[#protoOrder+1] = myId

	for _, sub in ipairs(proto.Protos) do
		buildProto(sub)
	end
end

return function(parsed)
	protoFuncs = {}
	protoOrder = {}
	protoIds   = {}
	protoIndex = 0

	assignIds(parsed)
	buildProto(parsed)

	local parts = {}
	table.sort(protoOrder)

	if settings.EncryptStrings then
		parts[#parts+1] = B64_DECODER
	end

	-- forward declare all protos so cross-references work
	local decls = {}
	for _, id in ipairs(protoOrder) do
		decls[#decls+1] = ("local __proto_%d"):format(id)
	end
	parts[#parts+1] = table.concat(decls, " ")

	for _, id in ipairs(protoOrder) do
		parts[#parts+1] = protoFuncs[id]
	end

	-- main chunk: factory returns the runnable function, call it immediately
	parts[#parts+1] = "__proto_0(_ENV or getfenv(),{})()"

	local output = table.concat(parts, " ")
	output = output:gsub("[\n\r\t]", " "):gsub("%s%s+", " ")
	return output
end
