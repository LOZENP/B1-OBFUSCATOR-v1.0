local ops = {}

local function rk(x)
	if x.k then return "K["..(x.i+1).."]" end
	return "S["..(x.i).."]"
end

ops[0] = function(i) -- MOVE
	return ("S[%d]=S[%d]"):format(i.A,i.B.i)
end

ops[1] = function(i) -- LOADK
	return ("S[%d]=K[%d]"):format(i.A,i.Bx+1)
end

ops[2] = function(i) -- LOADBOOL
	local s = ("S[%d]=%s"):format(i.A, i.B.i~=0 and "true" or "false")
	if i.C.i~=0 then s=s.." pc=pc+1" end
	return s
end

ops[3] = function(i) -- LOADNIL
	local t={}
	for r=i.A,i.B.i do t[#t+1]=("S[%d]=nil"):format(r) end
	return table.concat(t," ")
end

ops[4] = function(i) -- GETUPVAL
	return ("S[%d]=U[%d]"):format(i.A,i.B.i)
end

ops[5] = function(i) -- GETGLOBAL
	return ("S[%d]=Env[K[%d]]"):format(i.A,i.Bx+1)
end

ops[6] = function(i) -- GETTABLE
	return ("S[%d]=S[%d][%s]"):format(i.A,i.B.i,rk(i.C))
end

ops[7] = function(i) -- SETGLOBAL
	return ("Env[K[%d]]=S[%d]"):format(i.Bx+1,i.A)
end

ops[8] = function(i) -- SETUPVAL
	return ("U[%d]=S[%d]"):format(i.B.i,i.A)
end

ops[9] = function(i) -- SETTABLE
	return ("S[%d][%s]=%s"):format(i.A,rk(i.B),rk(i.C))
end

ops[10] = function(i) -- NEWTABLE
	return ("S[%d]={}"):format(i.A)
end

ops[11] = function(i) -- SELF
	return ("do S[%d]=S[%d] S[%d]=S[%d][%s] end"):format(i.A+1,i.B.i,i.A,i.B.i,rk(i.C))
end

ops[12] = function(i) return ("S[%d]=%s+%s"):format(i.A,rk(i.B),rk(i.C)) end -- ADD
ops[13] = function(i) return ("S[%d]=%s-%s"):format(i.A,rk(i.B),rk(i.C)) end -- SUB
ops[14] = function(i) return ("S[%d]=%s*%s"):format(i.A,rk(i.B),rk(i.C)) end -- MUL
ops[15] = function(i) return ("S[%d]=%s/%s"):format(i.A,rk(i.B),rk(i.C)) end -- DIV
ops[16] = function(i) return ("S[%d]=%s%%%s"):format(i.A,rk(i.B),rk(i.C)) end -- MOD
ops[17] = function(i) return ("S[%d]=%s^%s"):format(i.A,rk(i.B),rk(i.C)) end -- POW
ops[18] = function(i) return ("S[%d]=-S[%d]"):format(i.A,i.B.i) end -- UNM
ops[19] = function(i) return ("S[%d]=not S[%d]"):format(i.A,i.B.i) end -- NOT
ops[20] = function(i) return ("S[%d]=#S[%d]"):format(i.A,i.B.i) end -- LEN

ops[21] = function(i) -- CONCAT
	local t={}
	for r=i.B.i,i.C.i do t[#t+1]=("S[%d]"):format(r) end
	return ("S[%d]=%s"):format(i.A,table.concat(t,".."))
end

ops[22] = function(i) -- JMP
	return ("pc=pc+%d"):format(i.sBx-1)
end

ops[23] = function(i) -- EQ
	return ("do if((%s==%s)~=(%s))then pc=pc+1 end end"):format(
		rk(i.B),rk(i.C),i.A~=0 and "true" or "false")
end

ops[24] = function(i) -- LT
	return ("do if((%s<%s)~=(%s))then pc=pc+1 end end"):format(
		rk(i.B),rk(i.C),i.A~=0 and "true" or "false")
end

ops[25] = function(i) -- LE
	return ("do if((%s<=%s)~=(%s))then pc=pc+1 end end"):format(
		rk(i.B),rk(i.C),i.A~=0 and "true" or "false")
end

ops[26] = function(i) -- TEST
	return ("do if(not not S[%d])~=(%s)then pc=pc+1 end end"):format(
		i.A,i.C.i~=0 and "true" or "false")
end

ops[27] = function(i) -- TESTSET
	return ("do if(not not S[%d])==(%s)then S[%d]=S[%d] else pc=pc+1 end end"):format(
		i.B.i,i.C.i~=0 and "true" or "false",i.A,i.B.i)
end

ops[28] = function(i) -- CALL
	local a,b,c=i.A,i.B.i,i.C.i
	local argStr
	if b==1 then
		argStr=""
	elseif b==0 then
		argStr=("table.unpack(S,%d,top)"):format(a+1)
	else
		local t={}
		for r=1,b-1 do t[r]=("S[%d]"):format(a+r) end
		argStr=table.concat(t,",")
	end
	if c==0 then
		return ("do local _r={S[%d](%s)} top=%d+#_r-1 for _i=1,#_r do S[%d+_i-1]=_r[_i] end end"):format(a,argStr,a,a)
	elseif c==1 then
		return ("S[%d](%s)"):format(a,argStr)
	elseif c==2 then
		return ("S[%d]=S[%d](%s)"):format(a,a,argStr)
	else
		local t={}
		for r=0,c-2 do t[r+1]=("S[%d]"):format(a+r) end
		return ("do %s=S[%d](%s) end"):format(table.concat(t,","),a,argStr)
	end
end

ops[29] = function(i) -- TAILCALL
	local b=i.B.i
	if b==1 then return ("return S[%d]()"):format(i.A) end
	if b==0 then return ("return S[%d](table.unpack(S,%d,top))"):format(i.A,i.A+1) end
	local t={}
	for r=1,b-1 do t[r]=("S[%d]"):format(i.A+r) end
	return ("return S[%d](%s)"):format(i.A,table.concat(t,","))
end

ops[30] = function(i) -- RETURN
	local a,b=i.A,i.B.i
	if b==1 then return "return" end
	if b==2 then return ("return S[%d]"):format(a) end
	if b==0 then
		return ("do local _r={} for _i=%d,top do _r[#_r+1]=S[_i] end return table.unpack(_r) end"):format(a)
	end
	local t={}
	for r=0,b-2 do t[r+1]=("S[%d]"):format(a+r) end
	return ("return %s"):format(table.concat(t,","))
end

ops[31] = function(i) -- FORLOOP
	return ("do S[%d]=S[%d]+S[%d] if S[%d]<=S[%d] then S[%d]=S[%d] pc=pc+%d end end"):format(
		i.A,i.A,i.A+2,i.A,i.A+1,i.A+3,i.A,i.sBx-1)
end

ops[32] = function(i) -- FORPREP
	return ("do S[%d]=S[%d]-S[%d] pc=pc+%d end"):format(i.A,i.A,i.A+2,i.sBx-1)
end

ops[33] = function(i) -- TFORLOOP
	local c=i.C.i
	local t={}
	for r=1,c do t[r]=("S[%d]"):format(i.A+2+r) end
	return ("do local _r={S[%d](S[%d],S[%d])} %s=table.unpack(_r,1,%d) if S[%d]~=nil then S[%d]=S[%d] else pc=pc+1 end end"):format(
		i.A,i.A+1,i.A+2,table.concat(t,","),c,i.A+3,i.A+2,i.A+3)
end

ops[34] = function(i) -- SETLIST
	local a,b,c=i.A,i.B.i,i.C.i
	if c==0 then c=1 end
	local base=(c-1)*50
	if b==0 then
		return ("do local _n=top-%d for _i=1,_n do S[%d][%d+_i]=S[%d+_i] end end"):format(a,a,base,a)
	end
	local t={}
	for r=1,b do t[r]=("S[%d][%d]=S[%d]"):format(a,base+r,a+r) end
	return table.concat(t," ")
end

ops[35] = function(i) -- CLOSE
	return "do end"
end

ops[37] = function(i) -- VARARG
	local a,b=i.A,i.B.i
	if b==0 then
		return ("do top=%d+#VA-1 for _i=1,#VA do S[%d+_i-1]=VA[_i] end end"):format(a,a)
	end
	local t={}
	for r=0,b-1 do t[r+1]=("S[%d]"):format(a+r) end
	return ("do %s=table.unpack(VA,1,%d) end"):format(table.concat(t,","),b)
end

return ops
