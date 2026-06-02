local parser = {}
parser.__index = parser

function parser.new(file)
	local self = setmetatable({}, parser)
	self.bytecode = tostring(file)
	self.pos = 1
	self.size = #tostring(file)
	self.sizeT = 8
	return self
end

function parser:ReadByte()
	if self.pos > self.size then
		error(("ReadByte: beyond end (pos=%d, size=%d)"):format(self.pos, self.size))
	end
	local b = self.bytecode:byte(self.pos)
	self.pos = self.pos + 1
	return b
end

function parser:ReadBytes(count)
	local bytes = self.bytecode:sub(self.pos, self.pos + count - 1)
	self.pos = self.pos + count
	return bytes
end

function parser:ReadInt32()
	local b1, b2, b3, b4 = self.bytecode:byte(self.pos, self.pos + 3)
	self.pos = self.pos + 4
	return b1 + b2*256 + b3*65536 + b4*16777216
end

function parser:ReadSizeT()
	if self.sizeT == 8 then
		local low = self:ReadInt32()
		self:ReadInt32()
		return low
	else
		return self:ReadInt32()
	end
end

function parser:ReadDouble()
	local bytes = self:ReadBytes(8)
	local b = {bytes:byte(1, 8)}
	local sign = (b[8] >= 128) and -1 or 1
	local exponent = (b[8] % 128) * 16 + math.floor(b[7] / 16)
	local mantissa = b[7] % 16
	for i = 6, 1, -1 do
		mantissa = mantissa * 256 + b[i]
	end
	if exponent == 0 then
		return sign * math.ldexp(mantissa, -1022 - 52)
	elseif exponent == 2047 then
		return mantissa == 0 and sign * (1/0) or 0/0
	else
		return sign * math.ldexp(1 + mantissa / (2^52), exponent - 1023)
	end
end

function parser:ReadString()
	local length = self:ReadSizeT()
	if length == 0 then return nil end
	local str = self:ReadBytes(length - 1)
	self:ReadByte()
	return str
end

return parser
