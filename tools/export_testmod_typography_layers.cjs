/* Export exact outlined text caches and their editable text descriptions. */
const fs=require('node:fs'),path=require('node:path');
const sharp=require('sharp'),xml=require('xml-js');
const root=path.resolve(__dirname,'..'),out=path.join(root,process.env.TESTMOD_OUTPUT||'output/testmod-typography-v4');
const serialize=e=>xml.js2xml({elements:[e]},{compact:false});
function texts(node,ancestors=[],result=[]){
 if(node.name==='text')result.push({node,ancestors});
 for(const child of node.elements||[])texts(child,[...ancestors,node],result);
 return result;
}
function outlined(node,result=[]){
 if(node.attributes?.['data-text-id']!==undefined)result[+node.attributes['data-text-id']]=node;
 for(const child of node.elements||[])outlined(child,result);
 return result;
}
function strip(node,underlines=false){
 if(node.attributes?.['data-text-id']!==undefined)return null;
 if(node.attributes?.['data-role']==='rules-symbol')return null;
 if(node.attributes?.['data-role']==='keyword-underline')return underlines?node:null;
 if(underlines&&node.name!=='svg'&&node.name!=='g'&&node.name!=='defs')return null;
 return {...node,elements:(node.elements||[]).map(n=>strip(n,underlines)).filter(Boolean)};
}
function symbolNodes(node,ancestors=[],result=[]){
 if(node.attributes?.['data-role']==='rules-symbol')result.push({node,ancestors});
 else for(const child of node.elements||[])symbolNodes(child,[...ancestors,node],result);
 return result;
}
function removeText(node){
 if(node.attributes?.['data-text-id']!==undefined)return null;
 return {...node,elements:(node.elements||[]).map(removeText).filter(Boolean)};
}
function withoutTitleGlow(node){
 const attributes={...node.attributes};
 if(attributes['data-title-calibration']==='native')delete attributes.filter;
 return {...node,attributes,elements:(node.elements||[]).map(withoutTitleGlow)};
}
function multiply(a,b){return [a[0]*b[0]+a[2]*b[1],a[1]*b[0]+a[3]*b[1],a[0]*b[2]+a[2]*b[3],a[1]*b[2]+a[3]*b[3],a[0]*b[4]+a[2]*b[5]+a[4],a[1]*b[4]+a[3]*b[5]+a[5]];}
function matrix(value=''){
 let m=[1,0,0,1,0,0];
 for(const match of value.matchAll(/(translate|rotate|scale)\(([^)]+)\)/g)){
  const v=match[2].trim().split(/[ ,]+/).map(Number);let n;
  if(match[1]==='translate')n=[1,0,0,1,v[0],v[1]||0];
  else if(match[1]==='rotate'){const r=v[0]*Math.PI/180;n=[Math.cos(r),Math.sin(r),-Math.sin(r),Math.cos(r),0,0];}
  else n=[v[0],0,0,v[1]??v[0],0,0];
  m=multiply(m,n);
 }
 return m;
}
async function main(){
 const report=JSON.parse(fs.readFileSync(path.join(out,'render-report.json'),'utf8'));
 const filter=process.argv.slice(2);
 for(const card of report){
  if(filter.length&&!filter.includes(card.id))continue;
  const dir=path.join(out,'layers',card.id);fs.mkdirSync(dir,{recursive:true});
  const source=xml.xml2js(fs.readFileSync(path.join(out,'layouts',card.id+'.text.svg'),'utf8'),{compact:false}).elements.find(n=>n.name==='svg');
  const curves=xml.xml2js(fs.readFileSync(path.join(out,'layouts',card.id+'.svg'),'utf8'),{compact:false}).elements.find(n=>n.name==='svg');
  const sourceTexts=texts(source),paths=outlined(curves),records=[];
  await sharp(Buffer.from(serialize(strip(curves)))).png().toFile(path.join(dir,'ui.png'));
  await sharp(Buffer.from(serialize(strip(curves,true)))).png().toFile(path.join(dir,'underlines.png'));
  const symbols=[];
  for(const {node,ancestors} of symbolNodes(curves)){
   let fragment=removeText(node);
   for(const parent of ancestors.slice(1).reverse())fragment={...parent,elements:[fragment]};
   const doc={...curves,elements:[...curves.elements.filter(n=>n.name==='defs'),fragment]},file=`symbol-${symbols.length}.png`;
   await sharp(Buffer.from(serialize(doc))).png().toFile(path.join(dir,file));
   symbols.push({file,name:'攻防与灵力升降 '+node.attributes['data-source-text'],source:node.attributes['data-source-text']});
  }
  fs.writeFileSync(path.join(dir,'symbols.json'),JSON.stringify(symbols,null,2));
  await sharp(path.resolve(root,process.env.TESTMOD_ART||'output/testmod-design/illustrations',card.id+'.png')).resize(...card.dimensions,{fit:'cover'}).png().toFile(path.join(dir,'illustration.png'));
  for(let i=0;i<sourceTexts.length;i++){
   const {node,ancestors}=sourceTexts[i],a=node.attributes||{};
   let fragment=paths[i],transform=[1,0,0,1,0,0];
   for(const parent of ancestors){if(parent.attributes?.transform)transform=multiply(transform,matrix(parent.attributes.transform));}
   for(const parent of ancestors.slice(1).reverse())fragment={...parent,elements:[fragment]};
   const doc={...source,elements:[...source.elements.filter(n=>n.name==='defs'),fragment]};
   const file=`text-${String(i).padStart(3,'0')}.png`;
   const info=await sharp(Buffer.from(serialize(doc))).trim({threshold:0}).png().toFile(path.join(dir,file));
   let nativeCache;
   if(a['data-title-calibration']==='native'){
    const rawFile=`text-${String(i).padStart(3,'0')}.raw.png`;
    const raw=await sharp(Buffer.from(serialize(withoutTitleGlow(doc)))).trim({threshold:0}).png().toFile(path.join(dir,rawFile));
    nativeCache={file:rawFile,left:-(raw.trimOffsetLeft||0),top:-(raw.trimOffsetTop||0),width:raw.width,height:raw.height};
   }
   records.push({id:i,text:(node.elements||[]).filter(e=>e.type==='text').map(e=>e.text).join(''),attrs:a,transform,file,left:-(info.trimOffsetLeft||0),top:-(info.trimOffsetTop||0),width:info.width,height:info.height,...(nativeCache?{nativeCache}: {})});
  }
  fs.writeFileSync(path.join(dir,'text-layers.json'),JSON.stringify(records,null,2));
  console.log(card.id,records.length,'text layers');
 }
}
main().catch(e=>{console.error(e);process.exit(1)});
