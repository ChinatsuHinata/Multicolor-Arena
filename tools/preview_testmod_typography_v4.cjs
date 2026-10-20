const fs=require('fs'),path=require('path'),sharp=require('sharp');
const root=path.resolve(__dirname,'..'),out=path.join(root,'output/testmod-typography-v4'),old=path.join(root,'output/testmod-typography-v3');
(async()=>{
 const specs=[['utsuho','title'],['byakuren','body'],['blade','underline']];
 const layers=[];
 for(let row=0;row<specs.length;row++){
  const [id,kind]=specs[row];
  for(let col=0;col<2;col++){
   const dir=col?out:old,card=JSON.parse(fs.readFileSync(path.join(dir,'render-report.json'),'utf8')).find(c=>c.id===id);
   let crop=kind==='title'?{left:270,top:112,width:1010,height:125}:kind==='body'?{left:52,top:Math.floor(card.bodyBox[1]-110),width:1360,height:Math.ceil(card.bodyBox[3]+118)}:{left:1536,top:139,width:142,height:300};
   const img=await sharp(path.join(dir,'cards',id+'.png')).extract(crop).resize({width:780,height:kind==='underline'?365:kind==='title'?120:365,fit:'contain',background:'#17202b'}).png().toBuffer();
   layers.push({input:img,left:20+col*810,top:65+row*405});
  }
 }
 const header=Buffer.from('<svg width="1640" height="55"><text x="20" y="35" fill="white" font-size="25" font-family="sans-serif">BEFORE (1.0.3)</text><text x="830" y="35" fill="white" font-size="25" font-family="sans-serif">AFTER (1.0.4)</text></svg>');
 await sharp({create:{width:1640,height:1280,channels:3,background:'#17202b'}}).composite([{input:header,top:0,left:0},...layers]).png().toFile(path.join(out,'typography-detail.png'));
 let html=fs.readFileSync(path.join(out,'comparison-gallery.html'),'utf8');
 html=html.replace('<h1>testmod · 正确模板重制逐张对照</h1>','<h1>核热与魔法 · 原版字体与间距修订 v4</h1><p>恢复原模板字体与字号；校准额外加粗；单位正文避开分割花纹；竖排下划线移至文字左侧。</p><p><a href="使用说明.txt">PSD 编辑说明</a></p><img src="typography-detail.png" alt="左为1.0.3，右为1.0.4：标题、分割线间距、竖排左侧下划线">');
 html=html.replaceAll(/<a href="cards\/([^"/]+)\.png">原尺寸 PNG<\/a>/g,'<a href="cards/$1.png">原尺寸 PNG</a> · <a href="psd/$1.psd">分层 PSD</a>');
 fs.writeFileSync(path.join(out,'comparison-gallery.html'),html);
})();
