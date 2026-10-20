/* Compose generated art with PSD components and exact card JSON typography.
 * npm dependency: sharp. Run from the project root after extract_testmod_psd.py.
 */
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const design = path.join(root, 'output/testmod-design');
const pack = path.join(root, 'examples/testmod');
fs.mkdirSync(path.join(design, 'font-cache'), {recursive:true});
const fc=path.join(design,'fonts.conf');
fs.writeFileSync(fc, `<?xml version="1.0"?><!DOCTYPE fontconfig SYSTEM "fonts.dtd"><fontconfig><dir>${path.join(root,'assets/fonts').replaceAll('\\','/')}</dir><dir>C:/Windows/Fonts</dir><cachedir>${path.join(design,'font-cache').replaceAll('\\','/')}</cachedir></fontconfig>`);
process.env.FONTCONFIG_FILE=fc;
const sharp = require('sharp');
const manifest = JSON.parse(fs.readFileSync(path.join(pack,'manifest.json'),'utf8'));
const esc = s => String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&apos;'}[c]));
const uri = file => 'data:image/png;base64,'+fs.readFileSync(file).toString('base64');
const layer = id => path.join(design,`template/layer-${String(id).padStart(3,'0')}.png`);
const colors={'红':110,'蓝':104,'绿':112,'黄':108,'黑':106};
const tones={'红':'#9f3324','蓝':'#247eaa','绿':'#336b51','黄':'#aa8238','黑':'#48424f'};
const report=[];
const text=(s,x,y,size,opts='')=>`<text x="${x}" y="${y}" font-size="${size}" ${opts}>${esc(s)}</text>`;
const rect=(x,y,w,h,fill,stroke='#baab80',radius=20)=>`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${radius}" fill="${fill}" stroke="${stroke}" stroke-width="3"/>`;
function measure(s,size) { return [...s].reduce((n,c)=>n+(/[\x00-\x7f]/.test(c)?0.56:1)*size,0); }
function horizontal(s,x,y,maxWidth,size,lineHeight) {
 let out='',line='',lines=0;
 const flush=()=>{out+=text(line,x,y+lines*lineHeight,size);line='';lines++;};
 for(const ch of s) {
  if(ch==='\n'){flush();continue;}
  if(line && measure(line+ch,size)>maxWidth && !'。，、：；！？）】」』'.includes(ch)) flush();
  line+=ch;
 }
 if(line)flush();
 return {svg:out,lines,height:lines*lineHeight};
}
function vertical(s,x,y,maxHeight,size,gap) {
 const tokens=s.match(/[A-Za-z0-9+\-/ .]+|[^A-Za-z0-9+\-/ .]/gu)||[];
 let out='',col=0,offset=0;
 for(const token of tokens) {
  if(token==='\n'){col++;offset=0;continue;}
  const latin=/^[\x20-\x7e]+$/.test(token);
  const extent=latin?Math.max(size,measure(token,size)):size*1.14;
  if(offset+extent>maxHeight && !'。，、：；！？）】」』'.includes(token)){col++;offset=0;}
  const xx=x-col*gap;
  if(latin && token.length>1)out+=`<g transform="translate(${xx-size*.32} ${y+offset}) rotate(90)">${text(token,0,0,size)}</g>`;
  else out+=text(token,xx,y+offset+size*.87,size,'text-anchor="middle"');
  offset+=extent;
 }
 return {svg:out,columns:col+1,width:(col+1)*gap};
}
function costs(c){
 const out=Object.entries(c['费用']).filter(([,v])=>v>0).map(([color,value])=>({color,value}));
 for(const color of (c['可变费用']||'').split('+').filter(Boolean)) out.push({color,value:'X'});
 return out;
}
function hex(color,value,x,y,w=150) {
 const h=Math.round(w*207/179),parts=color.split('/');
 let svg=`<image x="${x}" y="${y}" width="${w}" height="${h}" href="${uri(layer(colors[parts[0]]))}"/>`;
 if(parts.length>1) {
  const cid=`hybrid-${x}-${y}`;
  svg+=`<clipPath id="${cid}"><rect x="${x+w/2}" y="${y}" width="${w/2}" height="${h}"/></clipPath><image x="${x}" y="${y}" width="${w}" height="${h}" href="${uri(layer(colors[parts[1]]))}" clip-path="url(#${cid})"/>`;
 }
 svg+=text(value,x+w/2,y+h*.67,w*.5,'text-anchor="middle" font-weight="800" fill="#171b1e" stroke="#fff9e9" stroke-width="5" paint-order="stroke fill"');
 return svg;
}
function typeLabel(c) {
 if(c['类别']!=='符卡')return c['类别']+(c['种族']?.length?' · '+c['种族'].join(' / '):'');
 const tags=[];
 if(c['符卡类型'].includes('时符'))tags.push('时符');
 tags.push(c['角色约束']?'角色符卡':'符卡');
 if(c['高速'])tags.push('高速');
 if(c['关键词'].includes('限制级'))tags.push('限制级');
 return tags.join(' · ');
}
function headerPattern(x,y,w,h) {
 const transform=w>h?`transform="translate(${w} 0) rotate(90)"`:'';
 return `<svg x="${x}" y="${y}" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}"><image ${transform} width="${w>h?h:w}" height="${w>h?w:h}" preserveAspectRatio="none" opacity=".13" href="${uri(layer(25))}"/></svg>`;
}
async function render(c,index) {
 const id=c['卡牌ID'].split('/')[1],landscape=['符卡','结界'].includes(c['类别']);
 const [W,H]=landscape?[2079,1488]:[1488,2079];
 const tone=tones[c['颜色'][0]],title=c['名称'];
 let o=`<defs><linearGradient id="banner"><stop stop-color="${tone}"/><stop offset="1" stop-color="#15181f"/></linearGradient><linearGradient id="shade" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#080c13" stop-opacity="0"/><stop offset="1" stop-color="#080c13" stop-opacity=".95"/></linearGradient></defs>`;
 o+=rect(17,17,W-34,H-34,'none','#d8cba3',25);
 let body;
 if(landscape) {
  o+=rect(1284,65,410,1352,'#f6f1e7ed','#bdb393',25);
  o+=rect(1714,40,230,1408,'url(#banner)','#d4c49d',68)+headerPattern(1726,52,206,1384);
  o+=rect(1740,67,177,1354,'none','#c6b58d',49);
  const titleSize=id==='blade'?66:72;
  const titleRun=vertical(title,1828,125,1210,titleSize,80);
  if(titleRun.columns!==1)throw Error(`Title overflow ${id}`);
  o+=`<g font-family="KaiTi, Noto Sans SC" font-weight="700" fill="#fff4d9" stroke="#17191e" stroke-width="4" paint-order="stroke fill">${titleRun.svg}</g>`;
  body=vertical(c['能力文字'],1645,200,1124,43,60);
  if(body.columns>6)throw Error(`Rule overflow ${id}`);
  o+=`<g fill="#20262b">${body.svg}</g>`;
  o+=text(c['角色约束']||'核热与魔法',1646,141,30,'text-anchor="end" fill="#68583a"');
  o+=`<path d="M1316 164 H1660" stroke="#b39c6a" stroke-width="3"/>`;
  o+=rect(1922,700,104,717,'#10151df5','#bbac83',47);
  o+=`<g fill="#fff0cf">${vertical(typeLabel(c).replaceAll(' · ','・'),1974,750,620,38,42).svg}</g>`;
  costs(c).forEach((v,i)=>o+=hex(v.color,v.value,65+i*180,1240,166));
  o+=text(`${String(index+1).padStart(2,'0')} / 13    TESTMOD  ·  AI Illustration`,70,1460,24,'fill="#fff6df" stroke="#141821" stroke-width="3" paint-order="stroke fill"');
 } else {
  o+=`<rect x="20" y="1280" width="1448" height="780" fill="url(#shade)"/>`;
  o+=rect(59,57,1370,170,'url(#banner)','#cbbb91',42)+headerPattern(73,69,1340,146);
  const sz=Math.min(66,Math.floor(1250/([...title].length+.5)));
  o+=text(title,744,165,sz,'text-anchor="middle" font-family="KaiTi, Noto Sans SC" font-weight="700" fill="#fff4d9" stroke="#17191e" stroke-width="3" paint-order="stroke fill"');
  costs(c).forEach((v,i)=>o+=hex(v.color,v.value,75+i*168,256,148));
  o+=rect(65,1400,1358,565,'#f6f1e7ee','#cbbb91',25);
  o+=rect(78,1335,1332,96,'url(#banner)','#cbbb91',25);
  o+=text(typeLabel(c),120,1400,43,'fill="#fff1cc" font-weight="600"');
  body=horizontal(c['能力文字'],112,1504,1215,43,62);
  if(body.height>440)throw Error(`Rule overflow ${id}: ${body.lines} lines`);
  o+=`<g fill="#20262b">${body.svg}</g>`;
  if(['单位','自机'].includes(c['类别'])) {
   o+=rect(822,1240,588,106,'#111922ee','#d9c799',22);
   o+=text(`攻 ${c['攻击力']}   血 ${c['血量']}   灵 ${c['灵力']}`,1116,1314,51,'text-anchor="middle" fill="#fff0cb" font-weight="700"');
  }
  o+=text(`${String(index+1).padStart(2,'0')} / 13    TESTMOD  ·  AI Illustration`,77,2025,28,'fill="#ffefd1"');
 }
 const overlay=`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" font-family="Noto Sans SC, Microsoft YaHei" fill="#fff">${o}</svg>`;
 fs.mkdirSync(path.join(design,'layouts'),{recursive:true});
 fs.writeFileSync(path.join(design,'layouts',id+'.svg'),overlay);
 const dest=path.join(pack,'art',id+'.png');
 await sharp(path.join(design,'illustrations',id+'.png')).resize(W,H,{fit:'cover'}).composite([{input:Buffer.from(overlay)}]).png().toFile(dest);
 report.push({id:c['卡牌ID'],name:title,dimensions:[W,H],landscape,costs:costs(c),rules:c['能力文字'],ruleLines:body.lines||body.columns,file:`art/${id}.png`});
 console.log(`${id}: ${W}x${H}`);
}
async function overview() {
 const cols=4,cw=520,ch=760,tiles=[];
 for(let i=0;i<report.length;i++) {
  const r=report[i],x=i%cols*cw,y=Math.floor(i/cols)*ch;
  const png=await sharp(path.join(pack,r.file)).resize(490,670,{fit:'contain',background:'#111923'}).png().toBuffer();
  tiles.push({input:png,left:x+15,top:y+15});
  tiles.push({input:Buffer.from(`<svg width="520" height="66"><text x="260" y="38" text-anchor="middle" font-family="Noto Sans SC" font-size="21" fill="#f4e8ce">${esc(r.name)}</text></svg>`),left:x,top:y+685});
 }
 await sharp({create:{width:cols*cw,height:Math.ceil(report.length/cols)*ch,channels:4,background:'#111923'}}).composite(tiles).png().toFile(path.join(design,'overview.png'));
}
(async()=>{
 fs.mkdirSync(path.join(pack,'art'),{recursive:true});
 const filter=process.argv.slice(2);
 for(let i=0;i<manifest.cards.length;i++) {
  const c=JSON.parse(fs.readFileSync(path.join(pack,manifest.cards[i]),'utf8'));
  if(filter.length && !filter.includes(c['卡牌ID'].split('/')[1]))continue;
  await render(c,i);
 }
 fs.writeFileSync(path.join(design,'render-report.json'),JSON.stringify(report,null,2));
 await overview();
})().catch(e=>{console.error(e);process.exit(1);});
