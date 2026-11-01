// Offline analysis of the fingerprint-pinned BARRAGE loader; never runs its game VM.
module.exports = function disassemble({source,methods}, root, tables, allPrototypes) {
const {expr,body}=require("./format.cjs")(source);
function walk(n,fn){if(!n||typeof n!=='object')return;fn(n);for(const [k,v]of Object.entries(n))if(k!=='range'){if(Array.isArray(v))v.forEach(x=>walk(x,fn));else if(typeof v==='object')walk(v,fn);}}
let constructor;walk(methods.c3,n=>{if(n.type==='AssignmentStatement'&&n.variables[0]?.index?.value===54)constructor=n.init[0]});
let vm;walk(constructor,n=>{if(n.type==='AssignmentStatement'&&n.variables[0]?.name==='p'&&n.init[0]?.type==='FunctionDeclaration')vm=n.init[0]});
const loop=vm.body.find(n=>n.type==='WhileStatement');
const unknown=Symbol();
function fixed(n,b){if(!n)return unknown;switch(n.type){
 case'NumericLiteral':case'BooleanLiteral':case'StringLiteral':return n.value;
 case'Identifier':return n.name==='B'?b:unknown;
 case'UnaryExpression':{const a=fixed(n.argument,b);return a===unknown?unknown:n.operator==='not'?!a:n.operator==='-'?-a:unknown;}
 case'BinaryExpression':case'LogicalExpression':{const a=fixed(n.left,b),c=fixed(n.right,b);if(a===unknown||c===unknown)return unknown;switch(n.operator){case'<':return a<c;case'>':return a>c;case'<=':return a<=c;case'>=':return a>=c;case'==':return a===c;case'~=':return a!==c;case'+':return a+c;case'-':return a-c;case'and':return a&&c;case'or':return a||c;}return unknown;}
 default:return unknown;
}}
function simplify(nodes,b){return nodes.flatMap(n=>{
 if(n.type==='IfStatement'){
  const clauses=[];
  for(const c of n.clauses){const x=c.condition?fixed(c.condition,b):true;if(x===false)continue;if(x===true){if(!clauses.length)return simplify(c.body,b);clauses.push({...c,type:'ElseClause',condition:undefined,body:simplify(c.body,b)});break;}clauses.push({...c,body:simplify(c.body,b)});}
  return clauses.length?[{...n,clauses}]:[];
 }return[n];
});}
const ids=new Map(),protos=[];
function isproto(v){return v&&typeof v==='object'&&typeof v[8]==='number'&&v[1]&&v[2]&&v[3]&&v[4]&&v[5]&&v[6]&&v[10];}
function visit(p){if(ids.has(p))return ids.get(p);const id=protos.length;ids.set(p,id);protos.push(p);for(const v of Object.values(p[4]))if(isproto(v))visit(v);return id;}
visit(root);
for(const proto of Object.values(allPrototypes||{}))if(isproto(proto))visit(proto);
function literal(v){if(isproto(v))return'PROTO_'+ids.get(v);if(v&&typeof v==='object')return'TABLE_'+(tables.indexOf(v)+1);if(typeof v==='string')return JSON.stringify(Buffer.from(v,'latin1').toString('utf8'));return String(v);}
function transform(n,b,pc,p){if(!n||typeof n!=='object')return n;
 if(n.type==='IndexExpression'&&n.index.type==='Identifier'&&n.index.name==='d'&&n.base.type==='Identifier'){
  const field={F:1,C:2,K:3,l:4,j:5,X:6,k:10}[n.base.name];
  if(field){const value=p[field][pc];return{type:'Identifier',name:literal(value)};}
 }
 if(n.type==='Identifier'&&n.name==='B')return{type:'NumericLiteral',value:b};
 const o={...n};for(const [k,v]of Object.entries(o))if(k!=='range'){if(Array.isArray(v))o[k]=v.map(x=>transform(x,b,pc,p));else if(v&&typeof v==='object')o[k]=transform(v,b,pc,p);}return o;
}
const out=["ANALYSIS LISTING: recovered VM instructions, not an executable replacement.\nW=registers; i=environment; L=upvalues; Z=VM support state.\nOpaque mutation handlers and unreachable padding remain visible.\n"];
for(let id=0;id<protos.length;id++){
 const p=protos[id],count=Object.keys(p[2]).length;
 out.push(`\n======== PROTO_${id} regs=${p[8]} instructions=${count} upvalues=${JSON.stringify(p[9])} ========`);
 for(let pc=1;pc<=count;pc++){
  const opcode=p[2][pc];const nodes=simplify(loop.body.filter((n,i)=>i>0&&i<loop.body.length-1),opcode);
  out.push(`L${String(pc).padStart(5,'0')} [${opcode}] `+body(nodes.map(n=>transform(n,opcode,pc,p))).replace(/\n/g,' | '));
 }
}
const ops=[];for(let b=0;b<228;b++)ops.push("OPCODE "+b+"\n"+body(simplify(loop.body.filter((n,i)=>i>0&&i<loop.body.length-1),b)));
return {output:out.join("\n"),opcodes:ops.join("\n\n"),prototypes:protos.length,instructions:protos.reduce((n,p)=>n+Object.keys(p[2]).length,0),index:protos.map((p,id)=>({id,registers:p[8],instructions:Object.keys(p[2]).length,strings:[...new Set([4,5,10].flatMap(field=>Object.values(p[field]).filter(v=>typeof v==='string').map(v=>Buffer.from(v,'latin1').toString('utf8'))))]}))};
};
