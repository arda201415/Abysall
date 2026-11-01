// Offline analysis of the fingerprint-pinned BARRAGE loader; never runs its game VM.
module.exports = function parse(input, lp) {
const tokens=[];
function str(s){return '"'+[...Buffer.from(s,'utf8')].map(b=>'\\'+String(b).padStart(3,'0')).join('')+'"';}
for(let i=0;i<input.length;){
 const start=i,c=input[i];
 if(/\s/.test(c)){i++;continue;}
 if(c==='-'&&input[i+1]==='-'){
  const m=input.slice(i+2).match(/^\[(=*)\[/);
  if(m){const end=input.indexOf(']'+m[1]+']',i+2+m[0].length);i=end+2+m[1].length;}
  else {const end=input.indexOf('\n',i);i=end<0?input.length:end+1;}continue;
 }
 if(c==='['){const m=input.slice(i).match(/^\[(=*)\[/);if(m){const end=input.indexOf(']'+m[1]+']',i+m[0].length);tokens.push(input.slice(i,end+2+m[1].length));i=end+2+m[1].length;continue;}}
 if(c==='"'||c==="'"){
  const bytes=[];i++;
  while(i<input.length&&input[i]!==c){
   let v=input[i++];
   if(v!=='\\'){bytes.push(...Buffer.from(v,'utf8'));continue;}
   v=input[i++];const map={a:7,b:8,f:12,n:10,r:13,t:9,v:11};
   if(map[v]!==undefined)bytes.push(map[v]);
   else if(v==='x'){bytes.push(parseInt(input.slice(i,i+2),16));i+=2;}
   else if(v==='u'&&input[i]==='{'){const end=input.indexOf('}',i);bytes.push(...Buffer.from(String.fromCodePoint(parseInt(input.slice(i+1,end),16)),'utf8'));i=end+1;}
   else if(v==='z'){while(/\s/.test(input[i]||''))i++;}
   else if(/[0-9]/.test(v)){let s=v;while(s.length<3&&/[0-9]/.test(input[i]||''))s+=input[i++];bytes.push(Number(s));}
   else bytes.push(...Buffer.from(v,'utf8'));
  }
  i++;tokens.push('"'+bytes.map(b=>'\\'+String(b).padStart(3,'0')).join('')+'"');continue;
 }
 const num=input.slice(i).match(/^(?:0[xX][0-9a-fA-F_]+|0[bB][01_]+|[0-9]+(?:\.[0-9]*)?(?:[eE][+-]?[0-9]+)?)/);
 if(num){const raw=num[0].replaceAll('_','');tokens.push(String(/^0b/i.test(raw)?parseInt(raw.slice(2),2):Number(raw)));i+=num[0].length;continue;}
 const id=input.slice(i).match(/^[A-Za-z_][A-Za-z_0-9]*/);
 if(id){tokens.push(id[0]==='continue'?'CONTINUE()':id[0]);i+=id[0].length;continue;}
 const op=['...','//','..=','+=','-=','*=','/=','%=','^=','==','~=','<=','>=','..','::'].find(x=>input.startsWith(x,i));
 tokens.push(op||c);i+=(op||c).length;
}
for(let i=1;i<tokens.length;i++)if(['+=','-=','*=','/=','%=','^=','..='].includes(tokens[i])){
 if(!/^[A-Za-z_][A-Za-z_0-9]*$/.test(tokens[i-1]))throw Error('Complex compound assignment near '+tokens.slice(i-5,i+5).join(' '));
 tokens.splice(i,1,'=',tokens[i-1],tokens[i].slice(0,-1));i+=2;
}
const source=tokens.join(" ");
const ast=lp.parse(source,{ranges:true,encodingMode:'pseudo-latin1',luaVersion:'5.3'});
const objects=[];function walk(n){if(!n||typeof n!=='object')return;if(n.type==='TableConstructorExpression'&&n.fields.length>20)objects.push(n);for(const [k,v]of Object.entries(n))if(k!=='range'){if(Array.isArray(v))v.forEach(walk);else if(typeof v==='object')walk(v);}}walk(ast);
const table=objects.sort((a,b)=>b.fields.length-a.fields.length)[0];
const methods={};for(const f of table.fields)if(f.type==='TableKeyString')methods[f.key.name]=f.value;
return {source,ast,methods,table};
};
