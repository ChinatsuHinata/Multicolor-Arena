/* Preserve bevels from the PSD merged preview, using extracted UI alpha only. */
const fs=require('fs'),path=require('path'),sharp=require('sharp');
const d=path.resolve(__dirname,'../output/testmod-design-v2');
const uri=b=>'data:image/png;base64,'+b.toString('base64');
(async()=>{
 const manifest=JSON.parse(fs.readFileSync(path.join(d,'templates/unit/manifest.json'),'utf8'));
 await sharp(path.join(d,'templates/unit/composite.png')).extract({left:92,top:70,width:175,height:202}).toFile(path.join(d,'components/cost-native.png'));
 for(const [name,x,y,w,h] of [['spirit',1194,1794,215,215],['leader',90,1209,1302,264]]){
  const flat=fs.readFileSync(path.join(d,'components/unit',name+'.png'));
  const alpha=await sharp(flat).ensureAlpha().extractChannel(3).threshold(180).raw().toBuffer();
  const mask=await sharp({create:{width:w,height:h,channels:3,background:'#fff'}}).joinChannel(alpha,{raw:{width:w,height:h,channels:1}}).png().toBuffer();
  const src=await sharp(path.join(d,'templates/unit/composite.png')).extract({left:x,top:y,width:w,height:h}).png().toBuffer();
  let exclude='';
  if(name==='spirit'){
   const [gx,gy,gx2,gy2]=manifest.layers[84].bbox;
   const glyph=fs.readFileSync(path.join(d,'components/unit/text-084.png'));
   exclude=`<image x="${gx-x}" y="${gy-y}" width="${gx2-gx}" height="${gy2-gy}" filter="url(#eraseGlyph)" href="${uri(glyph)}"/>`;
  }
  const svg=`<svg width="${w}" height="${h}" xmlns="http://www.w3.org/2000/svg"><defs><filter id="grow"><feMorphology operator="dilate" radius="4"/></filter><filter id="eraseGlyph"><feMorphology in="SourceAlpha" operator="dilate" radius="5" result="alpha"/><feFlood flood-color="black"/><feComposite in2="alpha" operator="in"/></filter><mask id="m"><image width="${w}" height="${h}" filter="url(#grow)" href="${uri(mask)}"/>${exclude}</mask></defs><image width="${w}" height="${h}" href="${uri(flat)}"/><image width="${w}" height="${h}" href="${uri(src)}" mask="url(#m)"/></svg>`;
  await sharp(Buffer.from(svg)).png().toFile(path.join(d,'components/unit/native-'+name+'.png'));
 }
})().catch(e=>{console.error(e);process.exit(1)});
