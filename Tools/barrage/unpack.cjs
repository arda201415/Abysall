// Offline analysis of the fingerprint-pinned BARRAGE loader; never runs its game VM.
module.exports = function buildUnpacker({source,ast}) {
const objects=[];
function walk(n,fn){if(!n||typeof n!=='object')return;fn(n);for(const [k,v]of Object.entries(n))if(k!=='range'){if(Array.isArray(v))v.forEach(x=>walk(x,fn));else if(typeof v==='object')walk(v,fn);}}
walk(ast,n=>{if(n.type==='TableConstructorExpression')objects.push(n)});
const obj=objects.sort((a,b)=>b.fields.length-a.fields.length)[0];
const patches=[];
walk(obj,n=>{
 if(n.type!=='AssignmentStatement')return;
 n.variables.forEach((v,i)=>{
  if(v.type==='IndexExpression'&&v.index.value===54&&n.init[i]?.type==='FunctionDeclaration'){
   patches.push({range:n.init[i].range,value:'function(proto, upvalues) return {CapturedProto=proto, CapturedUpvalues=upvalues, CapturedState=Z} end'});
  }
 });
});
if(patches.length!==1)throw Error('Expected exactly one VM constructor, got '+patches.length);
let tableSource=source.slice(...obj.range);
for(const p of patches.sort((a,b)=>b.range[0]-a.range[0]))tableSource=tableSource.slice(0,p.range[0]-obj.range[0])+p.value+tableSource.slice(p.range[1]-obj.range[0]);
tableSource=tableSource.replace(/CONTINUE\(\)/g,'continue');
const harness=`-- Pure deserializer only. VM constructor replaced statically; no payload entry can run.
local safeTable=table.clone(table)
safeTable.create=function(count,value) assert(count>=0 and count<=300000,"Allocation limit");return table.create(count,value) end
local environment = {assert=assert,error=error,ipairs=ipairs,pairs=pairs,next=next,type=type,typeof=typeof,tonumber=tonumber,tostring=tostring,select=select,unpack=unpack,rawget=rawget,rawset=rawset,setmetatable=setmetatable,getmetatable=getmetatable,table=safeTable,string=string,math=math,bit32=bit32,buffer=buffer,coroutine=coroutine,pcall=pcall,xpcall=xpcall,utf8=utf8,getfenv=function() return {} end}
local factory = function() return ${tableSource} end
setfenv(factory, environment)
local decoder = factory()
local capture = decoder:Z()
assert(type(capture)=="table" and capture.CapturedProto, "Expected captured prototype")
local state=capture.CapturedState
local start,length=69411,200871
assert(bit32.bxor(buffer.readu32(state[36],start-4),0x46636b55)==length,"Unexpected second-stage frame")
local key={0xe3,0x36,0x18,0x5b,0x27,0x4b,0x6e,0x3d}
for offset=0,length-1 do
 buffer.writeu8(state[36],start+offset,bit32.bxor(buffer.readu8(state[36],start+offset),key[offset%8+1]))
end
state[34]=start
state[9]=nil;state[19]={};state[2]={}
local second=state[3][16]()
assert(state[34]==270282,"Unexpected end of second-stage data")
assert(#state[3][9]==2627,"Unexpected locked constant count")
capture={First=capture.CapturedProto,Second=second,Constants=state[3][9],Prototypes=state[3][14],End=state[34]}

local seen = {}
local count = 0
local function dump(value, path)
 if type(value)=="table" then
  if seen[value] then return end
  seen[value]=true
  for k,v in pairs(value) do dump(v,path.."["..tostring(k).."]") end
 elseif type(value)=="string" then
  count+=1
  print(path.." = "..string.format("%q",value))
 elseif type(value)=="number" and value>=100000000 then
  print(path.." = "..string.format("%.17g",value))
 end
end
local ids, nodes = {}, {}
local function quoted(s)
 local chars = {}
 for i=1,#s do
  local b=string.byte(s,i)
  if b>=32 and b<=126 and b~=34 and b~=92 then chars[i]=string.char(b)
  else chars[i]=string.char(92)..string.format("u%04x",b) end
 end
 return '"'..table.concat(chars)..'"'
end
local function value(v)
 local kind=type(v)
 if kind=="table" then
  if not ids[v] then ids[v]=#nodes+1; nodes[ids[v]]=v end
  return '{"ref":'..ids[v]..'}'
 elseif kind=="string" then return quoted(v)
 elseif kind=="number" then
  if v~=v then return '"NaN"' end
  if v==math.huge then return '"Infinity"' end
  if v==-math.huge then return '"-Infinity"' end
  return string.format("%.17g",v)
 elseif kind=="boolean" then return tostring(v)
 elseif kind=="buffer" then
  local bytes={}
  for offset=0,buffer.len(v)-1 do bytes[offset+1]=string.format("%02x",buffer.readu8(v,offset)) end
  return '{"bufferHex":'..quoted(table.concat(bytes))..'}'
 else return "null" end
end
local root=value(capture)
local output={}
local i=1
while i<=#nodes do
 local entries={}
 for k,v in pairs(nodes[i]) do table.insert(entries,'['..value(k)..','..value(v)..']') end
 table.insert(output,'['..table.concat(entries,',')..']')
 i+=1
end
print('{"root":'..root..',"tables":['..table.concat(output,',')..']}')
`;
return harness;
};
