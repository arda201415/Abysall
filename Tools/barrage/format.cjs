// Offline analysis of the fingerprint-pinned BARRAGE loader; never runs its game VM.
module.exports = function createFormatter(source) {
const d={source};
function expr(n){
 if(!n)return'';switch(n.type){
 case'Identifier':return n.name;case'NumericLiteral':case'BooleanLiteral':return String(n.value);case'NilLiteral':return'nil';
 case'StringLiteral':return n.value.length>250?'"<DATA '+n.value.length+' bytes>"':JSON.stringify(n.value);
 case'VarargLiteral':return'...';case'UnaryExpression':return n.operator+' '+expr(n.argument);
 case'BinaryExpression':case'LogicalExpression':return'('+expr(n.left)+' '+n.operator+' '+expr(n.right)+')';
 case'IndexExpression':return expr(n.base)+'['+expr(n.index)+']';case'MemberExpression':return expr(n.base)+n.indexer+n.identifier.name;
 case'CallExpression':return expr(n.base)+'('+n.arguments.map(expr).join(', ')+')';
 case'TableCallExpression':return expr(n.base)+'('+expr(n.arguments)+')';
 case'TableConstructorExpression':return'{'+n.fields.map(f=>f.type==='TableValue'?expr(f.value):'['+(f.type==='TableKeyString'?JSON.stringify(f.key.name):expr(f.key))+']='+expr(f.value)).join(', ')+'}';
 case'FunctionDeclaration':return'function('+n.parameters.map(expr).join(', ')+')\n'+body(n.body,1)+'\nend';
 default:return d.source.slice(...n.range);
 }
}
function body(nodes,depth=0){return nodes.map(n=>stmt(n,depth)).join('\n');}
function stmt(n,i){const p='  '.repeat(i);switch(n.type){
 case'LocalStatement':case'AssignmentStatement':return p+(n.type==='LocalStatement'?'local ':'')+n.variables.map(expr).join(', ')+' = '+n.init.map(expr).join(', ');
 case'CallStatement':return p+expr(n.expression);case'ReturnStatement':return p+'return '+n.arguments.map(expr).join(', ');case'BreakStatement':return p+'break';
 case'IfStatement':return n.clauses.map((c,j)=>p+(j===0?'if '+expr(c.condition)+' then':c.condition?'elseif '+expr(c.condition)+' then':'else')+'\n'+body(c.body,i+1)).join('\n')+'\n'+p+'end';
 case'WhileStatement':return p+'while '+expr(n.condition)+' do\n'+body(n.body,i+1)+'\n'+p+'end';
 case'RepeatStatement':return p+'repeat\n'+body(n.body,i+1)+'\n'+p+'until '+expr(n.condition);
 case'ForNumericStatement':return p+'for '+expr(n.variable)+' = '+expr(n.start)+', '+expr(n.end)+(n.step?', '+expr(n.step):'')+' do\n'+body(n.body,i+1)+'\n'+p+'end';
 case'ForGenericStatement':return p+'for '+n.variables.map(expr).join(', ')+' in '+n.iterators.map(expr).join(', ')+' do\n'+body(n.body,i+1)+'\n'+p+'end';
 case'DoStatement':return p+'do\n'+body(n.body,i+1)+'\n'+p+'end';
 default:return p+expr(n);
}}
return {expr,body};
};
