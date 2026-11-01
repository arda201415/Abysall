// Offline analysis of the fingerprint-pinned BARRAGE loader; never runs its game VM.
module.exports = function decodeConstants(raw) {
const tables=raw.tables.map(()=>({}));
const value=v=>v&&typeof v==='object'&&v.ref?tables[v.ref-1]:v;
raw.tables.forEach((entries,i)=>{for(const[k,v]of entries)tables[i][value(k)]=value(v)});
const root=value(raw.root), constants=Object.values(root.Constants);
const strings=constants.filter(entry=>entry[2]==='string').map(entry=>Buffer.from(entry[1],'latin1'));
const counts={};for(const entry of constants)counts[entry[2]]=(counts[entry[2]]||0)+1;
const a=201,b=179;
function decrypt(string){
 const bytes=Buffer.from(string,'latin1');
 if(bytes[0]===0)return bytes.subarray(1,2).toString('latin1');
 let state=bytes[1];const result=[];
 for(let i=2;i<bytes.length;i++){state=(state*a+b)&255;result.push(bytes[i]^state^0x47)}
 return Buffer.from(result).toString('latin1');
}
const decoded=[];
for(const [id,entry]of Object.entries(root.Constants)){
 let v=entry[1];
 if(entry[2]==='number')v=-v;
 else if(entry[2]==='boolean')v=!v;
 else if(entry[2]==='string')v=decrypt(v);
 else if(entry[2]==='table') {throw new Error('Unexpected table constant '+id);}
 for(let i=3;i<=Object.keys(entry).length;i+=3){const proto=entry[i],pc=entry[i+1],field=entry[i+2];proto[field][pc]=v;}
 if(typeof v==='string')decoded.push({id:Number(id),value:Buffer.from(v,'latin1').toString('utf8')});
}
return {tables,root,strings:decoded,constantTypes:counts};
};
