local logger              = require("core.logger")
local Enums               = require("core.enums")
local Parser              = require("parser.parser")
local Unparser            = require("unparser.unparser")
local NameGenerator       = require("passes.namegenerator")
local WrapInFunction      = require("passes.WrapInFunction")
local EncryptStrings      = require("passes.EncryptStrings")
local NumbersToExpressions= require("passes.NumbersToExpressions")
local ConstantArray       = require("passes.ConstantArray")

local function gettime() return os.time() end

local function applyPipeline(code, filename)
    filename=filename or "Anonymous"
    logger:info("Applying pipeline to "..filename.." ...")

    local ok,seed=pcall(function()
        local s=io.popen("openssl rand -hex 12"):read("*a"):gsub("\n","")
        local n=0
        for i=1,#s do
            local c=s:sub(i,i):lower()
            local d=c:match("%d") and (c:byte()-48) or (c:byte()-87)
            n=n*16+d
        end
        if _VERSION=="Lua 5.1" and not jit then n=n%9.007199254741e+15 end
        return n
    end)
    if ok then math.randomseed(seed)
    else logger:warn("OpenSSL unavailable, using os.time"); math.randomseed(os.time()) end

    local t0=gettime()
    local srcLen=#code

    logger:info("Parsing...")
    local parser=Parser:new({LuaVersion="Lua51"})
    local ast=parser:parse(code)
    logger:info("Parsing done")

    local steps={
        ConstantArray:new({
            Treshold=1,
            StringsOnly=true,
            Shuffle=true,
            Rotate=true,
            Encoding="base64",
            LocalWrapperCount=0,
            LocalWrapperArgCount=10,
            MaxWrapperOffset=65535,
            LocalWrapperTreshold=0,
        }),
        EncryptStrings:new({}),
        NumbersToExpressions:new({
            Threshold=1,
            InternalThreshold=0.2,
            NumberRepresentationMutaton=false,
            AllowedNumberRepresentations={"hex","scientific","normal"},
        }),
        WrapInFunction:new({Iterations=1}),
    }

    for _,step in ipairs(steps) do
        logger:info("Applying step \""..step.Name.."\" ...")
        local t1=gettime()
        local newAst=step:apply(ast)
        if type(newAst)=="table" then ast=newAst end
        logger:info("Step \""..step.Name.."\" done in "..(gettime()-t1).." s")
    end

    logger:info("Renaming variables...")
    local t1=gettime()
    local ng=NameGenerator
    if type(ng.prepare)=="function" then ng.prepare(ast) end
    local gf=ng.generateName
    local conv=Enums.Conventions["Lua51"]
    ast.globalScope:renameVariables({
        Keywords=conv.Keywords,
        generateName=gf,
        prefix="",
    })
    logger:info("Rename done in "..(gettime()-t1).." s")

    logger:info("Generating code...")
    t1=gettime()
    local unparser=Unparser:new({LuaVersion="Lua51",PrettyPrint=false})
    local out=unparser:unparse(ast)
    logger:info("Code gen done in "..(gettime()-t1).." s")
    logger:info("Done in "..(gettime()-t0).." s | Output is "..string.format("%.2f",(#out/srcLen)*100).."% of source")
    return out
end

local args=arg or {}
local inputFile,outputFile=nil,nil
local i=1
while i<=#args do
    if args[i]=="--in"  then inputFile=args[i+1];  i=i+2
    elseif args[i]=="--out" then outputFile=args[i+1]; i=i+2
    else i=i+1 end
end

if not inputFile then
    print("Usage: lua main.lua --in <input.lua> --out <output.lua>")
    os.exit(1)
end

local f=io.open(inputFile,"r")
if not f then print("Cannot open: "..inputFile); os.exit(1) end
local code=f:read("*a"); f:close()

local result=applyPipeline(code,inputFile)

local out=outputFile and io.open(outputFile,"w") or io.stdout
out:write(result)
if outputFile then out:close() end
print("Done! -> "..(outputFile or "stdout"))
