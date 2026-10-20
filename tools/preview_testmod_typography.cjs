const fs=require('node:fs'),path=require('node:path'),sharp=require('sharp');
const root=path.resolve(__dirname,'..'),out=path.join(root,'output/testmod-typography-v3'),old=path.join(root,'output/testmod-design-v2');
(async()=>{
 const cards=['utsuho','byakuren'];const layers=[];
 for(let row=0;row<cards.length;row++){
  const id=cards[row];
  for(let col=0;col<2;col++){
   const dir=col?out:old;
   const r=JSON.parse(fs.readFileSync(path.join(dir,'render-report.json'),'utf8')).find(r=>r.id===id);
   const x=Math.floor(r.bodyBox[0]),y=Math.floor(r.bodyBox[1]),w=Math.floor(r.bodyBox[2]),h=Math.ceil(r.bodyBox[3]);
   const img=await sharp(path.join(dir,'cards',id+'.png')).extract({left:x,top:y,width:w,height:h}).resize({width:780}).png().toBuffer();
   layers.push({input:img,left:20+col*810,top:65+row*310});
  }
 }
 const header=Buffer.from('<svg width="1640" height="55"><text x="20" y="35" fill="white" font-size="25" font-family="sans-serif">BEFORE</text><text x="830" y="35" fill="white" font-size="25" font-family="sans-serif">AFTER</text></svg>');
 await sharp({create:{width:1640,height:620,channels:3,background:'#17202b'}}).composite([{input:header,top:0,left:0},...layers]).png().toFile(path.join(out,'typography-detail.png'));
 let html=fs.readFileSync(path.join(out,'comparison-gallery.html'),'utf8');
 html=html.replace('<h1>testmod · 正确模板重制逐张对照</h1>','<h1>核热与魔法 · 字体排版修订 v3</h1><p><a href="使用说明.txt">PSD 编辑说明</a></p><img src="typography-detail.png" alt="左为修改前，右为修改后">');
 html=html.replaceAll(/<a href="cards\/([^"/]+)\.png">原尺寸 PNG<\/a>/g,'<a href="cards/$1.png">原尺寸 PNG</a> · <a href="psd/$1.psd">分层 PSD</a>');
 fs.writeFileSync(path.join(out,'comparison-gallery.html'),html);
})();
