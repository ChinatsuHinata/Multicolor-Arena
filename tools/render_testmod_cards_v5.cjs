/* Corrected PSD geometry + original raster ornaments + exact JSON rules.
 * Run with the bundled Node runtime and sharp on NODE_PATH.
 * Source PSD files are never changed. AI illustrations are kept unchanged.
 */
const fs=require('node:fs'),path=require('node:path'),{execFileSync}=require('node:child_process');
const root=path.resolve(__dirname,'..'),assets=path.join(root,'output/testmod-design-v2');
const design=path.resolve(root,process.env.TESTMOD_DESIGN||'output/testmod-typography-v5');
const titleProfilePath=path.join(design,'title-profile.json');
const titleProfile=fs.existsSync(titleProfilePath)?JSON.parse(fs.readFileSync(titleProfilePath,'utf8')):null;
const pack=path.join(root,'examples/testmod'),art=path.resolve(root,process.env.TESTMOD_ART||'output/testmod-design/illustrations');
for(const p of ['layouts','cards','comparisons','font-cache','layers','psd'])fs.mkdirSync(path.join(design,p),{recursive:true});
const fc=path.join(design,'fonts.conf');
fs.writeFileSync(fc,`<?xml version="1.0"?><!DOCTYPE fontconfig SYSTEM "fonts.dtd"><fontconfig><dir>${assets.replaceAll('\\','/')}/fonts</dir><dir>${root.replaceAll('\\','/')}/assets/fonts</dir><dir>C:/Windows/Fonts</dir><cachedir>${design.replaceAll('\\','/')}/font-cache</cachedir></fontconfig>`);
process.env.FONTCONFIG_FILE=fc;
const sharp=require('sharp');
const BODY='MaoKenTangYuan-beta',BRUSH='SlideTownsoul-Regular';
const esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&apos;'}[c]));
const uri=p=>'data:image/png;base64,'+fs.readFileSync(p).toString('base64');
const pixel=(kind,id)=>path.join(assets,'templates',kind,`layer-${String(id).padStart(3,'0')}.png`);
const component=(kind,name)=>path.join(assets,'components',kind,name+'.png');
const img=(file,x,y,w,h,opts='')=>`<image x="${x}" y="${y}" width="${w}" height="${h}" href="${uri(file)}" ${opts}/>`;
const text=(s,x,y,size,opts='')=>`<text x="${x}" y="${y}" font-size="${size}" ${opts}>${esc(s)}</text>`;
const tones={'红':'#f74432','黑':'#30343c','绿':'#77c859','黄':'#edcd52','蓝':'#409ed4'};
const palette={'红':['#f13320','#a32b19'],'黑':['#71777b','#252a30'],'绿':['#60e83b','#2ca21e'],'黄':['#fff52d','#c3af22'],'蓝':['#00bce6','#004b95']};
const references={utsuho:'78.png',blade:'100.png',ten_stars:'100.png',furnace:'169.png',fuel:'164.png',control:'164.png',byakuren:'character-fdf-ex03.jpg',visitor:'character-fdn-042.jpg',recitation:'121.png',sutra:'164.png',resonance:'102.png',ship:'169.png',superhuman:'100.png'};
Object.assign(references,{forbidden_game:'100.png',forbidden_fruits:'100.png',vlad_curse:'121.png',scarlet_meister:'100.png',chanting_youka:'character-fdf-112.jpg',dragon_jewel:'164.png',buddha_diamond:'164.png',salamander_shield:'164.png',life_spring:'164.png',hourai_branch:'121.png',eternal_night:'100.png'});
let serial=0;
let metrics={};
const uid=p=>p+(serial++);
const displayName=c=>c['名称'].replaceAll('【','「').replaceAll('】','」').replaceAll('の','ノ');
function measure(s,size,face='body'){return [...s].reduce((n,c)=>n+(metrics[face]?.[c.codePointAt(0)]??1)*size,0);}
const jinwenVariants=Object.fromEntries([...'热莲诵鸣归戏乡莱红绯诅'].map((c,i)=>[c,[...'熱蓮誦鳴歸戲鄉萊紅緋詛'][i]]));
function inkMetric(ch,face){
 const table=metrics[face+'Ink'];
 const m=table[ch]||table[jinwenVariants[ch]];
 if(!m)throw Error(`Missing native title metrics: ${face} ${ch}`);
 return m;
}
function runInk(s,size,face,tracking){
 let advance=0,left=Infinity,right=-Infinity,bottom=Infinity,top=-Infinity;
 for(const ch of s){
  const m=inkMetric(ch,face),[x0,y0,x1,y1]=m.bounds;
  if(ch.trim()){
   left=Math.min(left,advance+x0*size);right=Math.max(right,advance+x1*size);
   bottom=Math.min(bottom,y0*size);top=Math.max(top,y1*size);
  }
  advance+=(m.advance+tracking/1000)*size;
 }
 return {left,right,bottom,top,advance:advance-tracking/1000*size};
}
function nativeHorizontalTitle(c){
 const p=titleProfile.horizontal,s=displayName(c),b=runInk(s,p.size,'brush',p.tracking);
 const scale=Math.min(1,p.max_ink_width/(b.right-b.left));
 const opts=`data-role="title" data-template="${c['类别']==='道具'?'UI模板 道具.psd:65,66':'教学用 天才教师上白泽慧音.psd:76,77'}" data-title-calibration="native" data-native-effect="unit" data-native-tracking="${p.tracking}" font-family="${BRUSH}" letter-spacing="${p.size*p.tracking/1000}" fill="#fdfdfd" filter="url(#titleGlowUnit)"`;
 return `<g transform="translate(${p.center[0]} ${p.center[1]}) scale(${scale} 1)">${text(s,-(b.left+b.right)/2,(b.bottom+b.top)/2,p.size,opts)}</g>`;
}
function nativeVerticalTitle(c){
 const p=titleProfile.vertical,punct={'「':'﹁','」':'﹂','（':'︵','）':'︶'},s=displayName(c);
 function layout(size){
  let at=0,left=Infinity,right=-Infinity,top=Infinity,bottom=-Infinity;const rows=[];
  for(const token of tokens(s)){
   const t=punct[token]||token,latin=/^[\x20-\x7e]+$/.test(t);
   if(!t.trim()){
    const m=inkMetric(t,'title');at+=(m.verticalAdvance+p.tracking/1000)*size;continue;
   }
   if(latin){
    const b=runInk(t,size,'title',p.tracking),x=-(b.bottom+b.top)/2;
    rows.push({t,x,y:at,latin});
    left=Math.min(left,x+b.bottom);right=Math.max(right,x+b.top);
    top=Math.min(top,at+b.left);bottom=Math.max(bottom,at+b.right);
    at+=b.advance+size*p.tracking/1000;
   }else{
    const m=inkMetric(t,'title'),[x0,y0,x1,y1]=m.bounds,origin=m.verticalOrigin;
    if(origin===undefined)throw Error(`No vmtx origin for ${t}`);
    const y=at+origin*size;
    rows.push({t,x:0,y,latin:false});
    left=Math.min(left,(x0-m.advance/2)*size);right=Math.max(right,(x1-m.advance/2)*size);
    top=Math.min(top,y-y1*size);bottom=Math.max(bottom,y-y0*size);
    at+=(m.verticalAdvance+p.tracking/1000)*size;
   }
  }
  return {rows,left,right,top,bottom};
 }
 const initial=layout(p.max_size),size=p.max_size*Math.min(1,p.max_ink_height/(initial.bottom-initial.top)),l=layout(size);
 const x=p.center[0]-(l.left+l.right)/2,y=p.center[1]-(l.top+l.bottom)/2;
 const opts=`data-role="title" data-template="符卡 四重結界.psd:40" data-title-calibration="native" data-native-effect="spell" data-native-tracking="${p.tracking}" data-native-faux-bold="true" data-embolden="${size*p.faux_bold_ratio}" font-family="DFJinWen-W3-WIN-BF" fill="#070707" filter="url(#titleGlowSpell)"`;
 return `<g transform="translate(${x} ${y})">`+l.rows.map(r=>r.latin?
  `<g transform="translate(${r.x} ${r.y}) rotate(90)">${text(r.t,0,0,size,`${opts} letter-spacing="${size*p.tracking/1000}"`)}</g>`:
  text(r.t,r.x,r.y,size,`${opts} text-anchor="middle"`)).join('')+'</g>';
}
// Native cached PSD glyphs calibrate faux bold to 3% for JinWen and 3.2% for keywords.
const BODY_SIZE=58.33333,SPELL_SIZE=54.16667,TRACKING=-.04,BODY_WEIGHT=0,KEYWORD_WEIGHT=BODY_SIZE*.032;
const ruleTracking=size=>size===SPELL_SIZE?-.05:TRACKING;
const keywordPattern=()=>/限制级符卡|计时(?:[Xx\d]+)|疾行|英勇|支援/gu;
const plainBodyWidth=(s,size)=>measure(s,size)+Math.max(0,[...s].length-1)*size*ruleTracking(size);
function bodyWidth(s,size){
 let width=0,at=0;
 for(const m of s.matchAll(modifierPattern())){
  width+=plainBodyWidth(s.slice(at,m.index),size)+modifierMetrics(m[0],size).width;at=m.index+m[0].length;
 }
 return width+plainBodyWidth(s.slice(at),size);
}
const modifierPattern=()=>/[+-]?(?:\d+|[Xx])\/[+-]?(?:\d+|[Xx])\/[+-]?(?:\d+|[Xx])|[+-](?:\d+|[Xx])\/[+-](?:\d+|[Xx])/gu;
function ruleTokens(s){
 const out=[];let at=0;
 for(const m of s.matchAll(modifierPattern())){
  out.push(...[...s.slice(at,m.index)]);out.push({modifier:m[0]});at=m.index+m[0].length;
 }
 out.push(...[...s.slice(at)]);return out;
}
// The original Byakuren card uses an attack/health capsule AND a spirit seal.
// Preserve the complete source token for auditing; these are presentation only.
function modifierMetrics(value,size){
 const parts=value.split('/'),triple=parts.length===3,token=triple&&!/^[+-]/.test(value);
 return {parts,triple,token,width:size*(triple?(token?4.58:5.58):3.25),height:size*1.1};
}
function modifierDraw(value,x,y,size,vertical=false){
 const {parts,triple,token,width}=modifierMetrics(value,size),w=size*3.25,h=size*.91;
 let o=`<g data-role="rules-symbol" data-source-text="${esc(value)}" data-symbol-style="${token?'token-':''}attack-health${triple?'-and-spirit':''}">`;
 o+=`<rect x="${x}" y="${y-size*.82}" width="${w}" height="${h}" rx="${h/2}" fill="#050505" stroke="url(#modifierRim)" stroke-width="${size*.065}"/>`;
 o+=text(parts.slice(0,2).join('/'),x+w/2,y-size*.09,size*.77,`data-role="symbol-value" text-anchor="middle" font-family="${BODY}" fill="white" data-native-faux-bold="true" data-embolden="${size*.018}"`);
 if(triple){
  const joinStyle=bodyStyle(false,size).replace('data-role="rules"','data-role="symbol-join"');
  if(!token&&vertical){
   // Counter-rotate the Chinese joiner; only the Latin statistics turn sideways.
   o+=`<g transform="translate(${x+w+size*.58} ${y-size*.34}) rotate(-90)">${text('与',0,size*.35,size,`${joinStyle} text-anchor="middle" data-upright="true"`)}</g>`;
  }else if(!token)o+=text('与',x+w+size*.08,y,size,joinStyle);
  const sx=x+size*(token?3.42:4.42),sy=y-size*.91,ss=size*1.08;
  o+=img(path.join(design,'components/modifier-spirit.png'),sx,sy,ss,ss);
  o+=text(parts[2],sx+ss/2,y-size*.04,size*.77,`data-role="symbol-value" text-anchor="middle" font-family="${BODY}" fill="white" stroke="#111" stroke-width="${size*.065}" paint-order="stroke fill" data-native-faux-bold="true" data-embolden="${size*.018}"`);
 }
 return o+'</g>';
}
function keywordRanges(s){return [...s.matchAll(keywordPattern())].map(m=>({start:m.index,end:m.index+m[0].length,text:m[0]}));}
function bodyStyle(keyword=false,size=BODY_SIZE,nativeSize=size){return `font-family="${BODY}" fill="#000000" letter-spacing="${size*ruleTracking(nativeSize)}" data-native-leading="${nativeSize===SPELL_SIZE?65:BODY_SIZE}" data-role="rules" data-embolden="${keyword?size*.032:BODY_WEIGHT}" font-weight="400"${keyword?' data-keyword="true" data-native-faux-bold="true"':''}`;}
function richHorizontal(s,x,y,size){
 if([...s.matchAll(modifierPattern())].length){
  let o='',at=0,xx=x;
  for(const m of s.matchAll(modifierPattern())){
   const before=s.slice(at,m.index);o+=richHorizontal(before,xx,y,size);xx+=bodyWidth(before,size)+size*ruleTracking(size);
   o+=modifierDraw(m[0],xx,y,size);xx+=modifierMetrics(m[0],size).width+size*.08;at=m.index+m[0].length;
  }
  return o+richHorizontal(s.slice(at),xx,y,size);
 }
 let o='',at=0,xx=x;
 const ranges=keywordRanges(s);
 const run=(value,bold)=>{
  if(!value)return;
  const w=bodyWidth(value,size);
  o+=text(value,xx,y,size,bodyStyle(bold,size));
  if(bold)o+=`<path data-role="keyword-underline" d="M${xx} ${y+size*.13}H${xx+w}" fill="none" stroke="#000" stroke-width="${size*.044}"/>`;
  xx+=w+size*ruleTracking(size);
 };
 for(const r of ranges){run(s.slice(at,r.start),false);run(s.slice(r.start,r.end),true);at=r.end;}
 run(s.slice(at),false);return o;
}
function defs(c){
 const cs=c['颜色'].map(x=>tones[x]),a=cs[0],b=cs.at(-1);
 return `<defs>
 <filter id="titleGlowUnit" x="-.3" y="-1" width="1.6" height="3" color-interpolation-filters="sRGB"><feMorphology in="SourceAlpha" operator="dilate" radius="5"/><feGaussianBlur stdDeviation="2.5" result="glowMask"/><feFlood flood-color="#020000" flood-opacity=".75"/><feComposite in2="glowMask" operator="in"/><feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge></filter>
 <filter id="titleGlowSpell" x="-.5" y="-.5" width="2" height="2" color-interpolation-filters="sRGB"><feGaussianBlur in="SourceAlpha" stdDeviation="3.33333" result="blur"/><feFlood flood-color="#fdfdfd"/><feComposite in2="blur" operator="in"/><feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge></filter>
 <linearGradient id="rim" x1="0" y1="0" x2="0" y2="1"><stop stop-color="${a}"/><stop offset=".45" stop-color="${a}"/><stop offset="1" stop-color="${b}"/></linearGradient>
 <linearGradient id="soft" x1="0" y1="0" x2="0" y2="1"><stop stop-color="${a}" stop-opacity=".49"/><stop offset="1" stop-color="${b}" stop-opacity=".46"/></linearGradient>
 <linearGradient id="bevel" x1="0" y1="0" x2=".25" y2="1"><stop stop-color="#fff" stop-opacity=".85"/><stop offset=".35" stop-color="#fff" stop-opacity="0"/><stop offset=".72" stop-color="#000" stop-opacity=".15"/><stop offset="1" stop-color="#000" stop-opacity=".9"/></linearGradient>
 <linearGradient id="modifierRim" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#70c69f"/><stop offset=".5" stop-color="#dce5d9"/><stop offset="1" stop-color="#b6a568"/></linearGradient>
 <filter id="shadow" x="-.1" y="-.1" width="1.2" height="1.3"><feDropShadow dx="3" dy="5" stdDeviation="3" flood-opacity=".85"/></filter>
 <filter id="glyphOutline" x="-.2" y="-.2" width="1.4" height="1.4"><feMorphology in="SourceAlpha" operator="dilate" radius="1.6" result="edge"/><feFlood flood-color="#fff"/><feComposite in2="edge" operator="in"/><feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge></filter>
 <filter id="whiteGlyph"><feFlood flood-color="#fff"/><feComposite in2="SourceAlpha" operator="in"/></filter>
 <filter id="ornamentColor"><feColorMatrix type="hueRotate" values="${c['颜色'].includes('红')?0:55}"/></filter>
 </defs>`;
}
function capsule(x,y,w,h,kind='unit',dark=false){
 const clip=uid('capsule'),radius=dark?Math.min(w,h)/2:(kind==='spell'?55:w>1400?46:Math.min(w,h)/2);
 let o=`<g filter="url(#shadow)"><rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${radius}" fill="${dark?'#050505':'#eee9e4'}" stroke="url(#rim)" stroke-width="9"/>
 <rect x="${x+2}" y="${y+2}" width="${w-4}" height="${h-4}" rx="${radius}" fill="none" stroke="url(#bevel)" stroke-width="5"/></g>`;
 if(!dark){
  o+=`<clipPath id="${clip}"><rect x="${x+5}" y="${y+5}" width="${w-10}" height="${h-10}" rx="${radius-5}"/></clipPath><g clip-path="url(#${clip})">`;
  // Raster patterns are extracted from the actual PSD, clipped to its title geometry.
  if(kind==='spell')o+=img(pixel('spell',14),x,y,w,h,'preserveAspectRatio="none" opacity=".33"');
  else if(w>1400)o+=img(pixel('unit',11),x-2,y-66,1421,315,'preserveAspectRatio="none" opacity=".44"');
  else o+=img(pixel('unit',78),x-166,y-77,1421,315,'preserveAspectRatio="none" opacity=".44"');
  o+=`<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="url(#soft)"/></g>`;
 }
 return o;
}
function costList(c){
 return Object.entries(c['费用']).filter(([,n])=>n>0).map(([color,value])=>({color,value})).concat((c['可变费用']||'').split('+').filter(Boolean).map(color=>({color,value:'X'})));
}
function cost(color,value,x,y,w){
 const id=uid('cost'),ps=color.split('/'),[a,b]=palette[ps[0]],second=ps[1]?palette[ps[1]]:null;
 let o=`<svg x="${x}" y="${y}" width="${w}" height="${w*202/175}" viewBox="0 0 175 202">
 <clipPath id="${id}"><path d="M87 0 175 50 175 151 87 202 0 151 0 50Z"/></clipPath><g clip-path="url(#${id})">`;
 // Native merged preview retains the intricate hex rim/bevel that the PSD
 // compositor cannot reproduce. Its sample digit is fully covered below.
 o+=img(path.join(assets,'components/cost-native.png'),0,0,175,202);
 o+=`<path d="M87 32 147 67 147 137 87 172 27 137 27 67Z" fill="${a}"/><path d="M27 137 147 67 147 137 87 172Z" fill="${b}"/>`;
 if(second)o+=`<path d="M87 32 147 67 147 137 87 172Z" fill="${second[0]}"/><path d="M87 102 147 67 147 137 87 172Z" fill="${second[1]}"/>`;
 o+='</g>';
 const numerals={1:97,2:103,3:91};
 if(numerals[value])o+=img(component('unit',`text-${String(numerals[value]).padStart(3,'0')}`),39,48,97,103,'filter="url(#glyphOutline)"');
 else {
  const formal={4:'肆',5:'伍',6:'陆',7:'柒',8:'捌',9:'玖',10:'拾'};
  o+=text(formal[value]||value,87,137,113,`text-anchor="middle" font-family="${value==='X'?'Slideqiuhong-Regular':formal[value]?BRUSH:BODY}" fill="#090909" stroke="white" stroke-width="3" paint-order="stroke fill"`);
 }
 return o+'</svg>';
}
function badge(kind,x,y,size=59){
 const original=kind==='自'?component('unit','self'):component('unit','main');
 return img(original,x,y,size,size)+text(kind,x+size/2,y+size*.81,size*.83,`font-family="${BODY}" fill="#fff" text-anchor="middle"`);
}
function bodyParagraphs(c){return c['能力文字'].split('\n').map(s=>({kind:s.startsWith('自机能力：')?'自':c['类别']==='符卡'&&c['角色约束']?'角':'主',text:s.replace(/^(自机能力|主要能力)：/,'')}));}
function lines(s,width,size){
 let out=[],run='';
 for(const ch of ruleTokens(s)){
  if(typeof ch==='object'){
   const w=modifierMetrics(ch.modifier,size).width;
   if(run&&bodyWidth(run,size)+w>width){out.push(run);run='';}
   run+=ch.modifier;continue;
  }
  if(ch==='\n'){if(run)out.push(run);run='';continue;}
  if(run&&bodyWidth(run+ch,size)>width&&! '。，、：；！？）】」』'.includes(ch)){out.push(run);run='';}
  run+=ch;
 }
 if(run)out.push(run);return out;
}
function horizontalBody(c,size=BODY_SIZE){
 // Alice FDF-112: circled choices share the rules' left edge, including wraps.
 const rows=bodyParagraphs(c).map(p=>({...p,option:/^[1-9][，,、.．]/u.test(p.text),lines:lines(p.text.replace(/^([1-9])[，,、.．]/u,(_,n)=>String.fromCodePoint(0x2460+Number(n)-1)).replace(/^(疾行|英勇)。(?=.)/u,'$1。\n'),1247,size)}));
 // Both portrait PSDs specify explicit 58.33333 leading. A JSON newline
 // selects a new line, not an extra paragraph margin.
 const lineHeight=size,space=0;
 const height=rows.reduce((n,p)=>n+p.lines.length*lineHeight+space,0)-space;
 return {rows,height,lineHeight,size,paragraphGap:space,left:c['类别']==='道具'?175:170,badgeLeft:c['类别']==='道具'?77:72};
}
function horizontalDraw(body,y){
 let o='',yy=y;const shown=new Set();
 for(const p of body.rows){
  const first=!shown.has(p.kind);shown.add(p.kind);
  if(first)o+=badge(p.kind,body.badgeLeft,yy-57,60);
  if(first)o+=text('：',body.left-37,yy,body.size,bodyStyle(false,body.size));
  p.lines.forEach((s,j)=>o+=`<g data-role="rules-line" data-option="${p.option}" data-baseline="${yy+j*body.lineHeight}">${richHorizontal(s,body.left,yy+j*body.lineHeight,body.size)}</g>`);
  yy+=p.lines.length*body.lineHeight+body.paragraphGap;
 }
 return o;
}
function tokens(s){return s.match(/[+-]?(?:\d+|[Xx])\/[+-]?(?:\d+|[Xx])\/[+-]?(?:\d+|[Xx])|[+-](?:\d+|[Xx])\/[+-](?:\d+|[Xx])|[A-Za-z0-9(). ]+|[^A-Za-z0-9(). ]/gu)||[];}
function verticalLayout(s,size,max,topOffset=0,face='body'){
 const out=[],ranges=keywordRanges(s);let col=0,at=topOffset,offset=0;
 for(const t of tokens(s)){
  const keyword=face==='body'&&ranges.some(r=>offset>=r.start&&offset<r.end);
  offset+=t.length;
  if(t==='\n'){col++;at=0;continue;}
  const latin=/^[\x20-\x7e]+$/.test(t);
  const upright=latin&&(t.length===1||/^\d{1,2}$/.test(t));
  const modifier=face==='body'&&new RegExp('^(?:'+modifierPattern().source+')$','u').test(t);
  const em=size*(face==='title'?1.22:1+ruleTracking(size));
  const extent=modifier?modifierMetrics(t,size).width:latin&&!upright?Math.max(em,face==='body'?bodyWidth(t,size):measure(t,size,face)):em;
  if(at+extent>max){
   // Keep closing punctuation off the top of the next vertical column.
   if('。，、：；！？）】」』'.includes(t)&&out.length&&out.at(-1).col===col){
    const prior=out.pop();col++;prior.col=col;prior.at=0;out.push(prior);at=prior.extent;
   }else{col++;at=0;}
  }
  out.push({t,latin,upright,col,at,extent,keyword,modifier});at+=extent;
 }
 return {out,columns:col+1,extent:col===0?at:max};
}
function verticalDraw(layout,x,y,size,gap,opts='',rules=false){
 let result=layout.out.map(({t,latin,upright,col,at,extent,keyword,modifier})=>{
  const xx=x-col*gap;
  const style=rules?bodyStyle(keyword,size):opts;
  if(modifier)return `<g transform="translate(${xx-size*.34} ${y+at}) rotate(90)">${modifierDraw(t,0,0,size,true)}</g>`;
  if(latin&&!upright)return `<g transform="translate(${xx-size*.34} ${y+at}) rotate(90)">${text(t,0,0,size,style)}</g>`;
  const punct={'「':'﹁','」':'﹂','【':'︻','】':'︼','（':'︵','）':'︶','。':'︒','，':'︐','：':'︓','；':'︔'};
  const glyphSize=upright&&t.length>1?size*Math.min(1,.95/measure(t,1)):size;
  const glyphStyle=rules?bodyStyle(keyword,glyphSize,size):style;
  return text(punct[t]||t,xx,y+at+size*.85,glyphSize,`text-anchor="middle" ${glyphStyle}`);
 }).join('');
 if(rules){
  const spans=[];
  for(const glyph of layout.out){if(!glyph.keyword)continue;const prev=spans.at(-1);
   if(prev&&prev.col===glyph.col&&Math.abs(prev.end-glyph.at)<.01)prev.end=glyph.at+glyph.extent;
   else spans.push({col:glyph.col,start:glyph.at,end:glyph.at+glyph.extent});
  }
  for(const s of spans){const xx=x-s.col*gap-size*.55;result+=`<path data-role="keyword-underline" data-side="left" d="M${xx} ${y+s.start+2}V${y+s.end}" fill="none" stroke="#000" stroke-width="${size*.044}"/>`;}
 }
 return result;
}
function verticalCentered(s,x,y,h,size,opts='',face='body'){
 const layout=verticalLayout(s,size,h,0,face);
 if(layout.columns!==1)throw Error(`Vertical label overflow: ${s}`);
 return verticalDraw(layout,x,y+(h-layout.extent)/2,size,size,opts);
}
function typeLabel(c){
 if(c['类别']==='结界')return '「结界」';
 const p=['符卡'];if(c['角色约束'])p.push('角色');
 if(c['高速'])p.push('高速');
 if(c['符卡类型'].includes('时符'))p.push('时符');
 if(p.length===1)p.push('普通');
 return p.join('·');
}
async function render(c,index){
 serial=0;
 const id=c['卡牌ID'].split('/')[1],landscape=['符卡','结界'].includes(c['类别']),kind=landscape?'spell':c['类别']==='道具'?'item':'unit';
 const [W,H]=landscape?[2079,1488]:[1488,2079],costs=costList(c);
 let o=defs(c),body,bodyBox;
 if(landscape){
  const all=c['能力文字'],size=SPELL_SIZE;
  body=verticalLayout(all,size,1260,0);
  const gap=65,width=body.columns*gap+50,left=1699-width;
  bodyBox=[left,38,width,1419];
  o+=`<rect x="${left}" y="38" width="${width}" height="1419" rx="38" fill="#f1eff0" fill-opacity=".78"/>`;
  o+=badge(c['角色约束']?'角':'主',1609,66,59);
  o+=verticalDraw(body,1638,142,size,gap,'',true);
  o+=capsule(1716,37,228,1418,'spell');
  const titleSize=Math.min(100,1260/verticalLayout(displayName(c),1,10000,0,'title').extent);
  o+=titleProfile?nativeVerticalTitle(c):verticalCentered(displayName(c),1828,95,1300,titleSize,`data-role="title" data-template="符卡 四重結界.psd:40" data-native-tracking="220" data-native-faux-bold="true" data-embolden="${titleSize*.03}" font-family="DFJinWen-W3-WIN-BF" fill="#070707" stroke="#fff" stroke-width="4" paint-order="stroke fill"`,'title');
  const label=typeLabel(c);
  // Database field cards place their sole type capsule around the lower middle.
  const typeY=c['类别']==='结界'?464:872;
  o+=capsule(1911,typeY,101,576,'spell',true);
  o+=verticalCentered(label,1962,typeY+30,516,Math.min(58.33333,516/(label.length*.96)),`font-family="${BRUSH}" fill="white" letter-spacing="-.29166665"`);
  if(c['角色约束']){
   o+=capsule(1909,40,101,576,'spell',true);
   o+=verticalCentered('「'+c['角色约束']+'」',1960,70,516,57,`font-family="${BRUSH}" fill="white"`);
  }
  costs.forEach((p,i)=>o+=cost(p.color,p.value,i===0?67:186+(i-1)*125,i===0?1167:1327,i===0?177:123));
 }else{
  o+=capsule(205,111,1107,122,kind);
  const titleSize=Math.min(75,1002/(measure(displayName(c),1,'brush')-.005*([...displayName(c)].length-1)));
  o+=titleProfile?nativeHorizontalTitle(c):text(displayName(c),784,199,titleSize,`data-role="title" data-template="教学用 天才教师上白泽慧音.psd:76,77" text-anchor="middle" font-family="${BRUSH}" letter-spacing="${titleSize*-.005}" fill="#fdfdfd" stroke="#151313" stroke-width="10" paint-order="stroke fill"`);
  costs.forEach((p,i)=>{const positions=[[92,70,175],[34,232,141],[102,353,143],[34,485,141]];o+=cost(p.color,p.value,...positions[i]);});
  body=horizontalBody(c);
  if(kind==='unit'){
   const leader=c['类别']==='自机',bodyInset=leader?116:78;
   const boxH=Math.max(leader?328:228,body.height+78),y=1776-boxH;
   bodyBox=[33,y,1418,boxH];
   o+=`<rect x="33" y="${y}" width="1418" height="${boxH}" rx="58" fill="#ede9ed" fill-opacity=".79"/>`;
   if(c['类别']==='自机'){
    o+=`<filter id="leaderColor"><feColorMatrix type="hueRotate" values="${c['颜色'].includes('红')?0:55}"/></filter>`;
    o+=img(component('unit','native-leader'),90,y-231,1302,264,'filter="url(#leaderColor)"');
    // Original leader separator alpha is preserved; its color follows the card.
   }
   // Separator reaches y + 33; first native glyph starts below y + 65.
   o+=horizontalDraw(body,y+bodyInset);
   o+=capsule(33,1786,1418,228,'unit');
   const fan=uid('fan');
   o+=`<filter id="${fan}"><feColorMatrix type="hueRotate" values="55"/></filter>`;
   o+=img(component('unit','race'),195,1768,374,164,c['颜色'].includes('红')?'':`filter="url(#${fan})"`);
   const race=c['种族'].join('·'),raceSize=Math.min(84,305/[...race].length);
   o+=text(race,382,1872,raceSize,`text-anchor="middle" font-family="${BRUSH}" fill="#080808" stroke="white" stroke-width="3" paint-order="stroke fill"`);
   o+=capsule(97,1905,576,101,'unit',true);
   o+=text(c['类别']==='自机'?'单位·自机':'单位·普通',385,1979,58.33333,`text-anchor="middle" font-family="${BRUSH}" letter-spacing="-.29166665" fill="white"`);
   o+=capsule(750,1876,427,128,'unit',true);
   o+=text(`${c['攻击力']}/${c['血量']}`,964,1971,105,`text-anchor="middle" font-family="${BRUSH}" fill="white"`);
   o+=img(component('unit','native-spirit'),1194,1794,215,215,'filter="url(#ornamentColor)"');
   o+=text(c['灵力'],1301,1945,113,`text-anchor="middle" font-family="${BRUSH}" fill="white" stroke="#444" stroke-width="5" paint-order="stroke fill"`);
  }else{
   const h=Math.max(375,body.height+161),y=2020-h;
   bodyBox=[21,y,1445,h];
   o+=`<g filter="url(#shadow)"><rect x="21" y="${y}" width="1445" height="${h}" rx="23" fill="url(#rim)"/><rect x="39" y="${y+19}" width="1409" height="${h-39}" rx="12" fill="#e4e1e6" fill-opacity=".84"/><rect x="25" y="${y+4}" width="1437" height="${h-8}" rx="20" fill="none" stroke="url(#bevel)" stroke-width="6"/></g>`;
   o+=capsule(67,y-55,576,101,'item',true);
   o+=text('道具·普通',355,y+19,58.33333,`text-anchor="middle" font-family="${BRUSH}" letter-spacing="-.29166665" fill="white"`);
   // Item template layer 9 starts 89px below the panel's outer top.
   o+=horizontalDraw(body,y+139);
  }
 }
 // Minimal source acknowledgement, outside all rules and statistics.
 o+=text(`TESTMOD-${String(index+1).padStart(2,'0')}  /  Illustration: AI`,landscape?520:55,H-18,20,`font-family="${BODY}" fill="white" stroke="#333" stroke-width="2" paint-order="stroke fill"`);
 o+=`<path d="M1 51 Q1 1 51 1 M${W-51} 1 Q${W-1} 1 ${W-1} 51 M1 ${H-51} Q1 ${H-1} 51 ${H-1} M${W-51} ${H-1} Q${W-1} ${H-1} ${W-1} ${H-51}" fill="none" stroke="#111" stroke-width="3"/>`;
 const overlay=`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" font-family="${BODY}">${o}</svg>`;
 const source=path.join(design,'layouts',id+'.text.svg'),outlined=path.join(design,'layouts',id+'.svg');
 fs.writeFileSync(source,overlay);
 execFileSync(process.env.TESTMOD_PYTHON||'C:/Users/Lenovo/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe',[path.join(root,'tools/outline_testmod_text.py'),source,outlined],{env:{...process.env,PYTHONPATH:path.join(root,'work/psd-python'),PYTHONIOENCODING:'utf-8'}});
 await sharp(path.join(art,id+'.png')).resize(W,H,{fit:'cover'}).composite([{input:fs.readFileSync(outlined)}]).png().toFile(path.join(design,'cards',id+'.png'));
 const bodySize=kind==='spell'?SPELL_SIZE:BODY_SIZE;
 const result={id,name:displayName(c),kind,dimensions:[W,H],reference:references[id],rules:c['能力文字'],costs,type:kind==='spell'?typeLabel(c):c['类别'],bodyBox,bodyLines:body.columns||body.rows.reduce((n,p)=>n+p.lines.length,0),bodyFont:BODY,bodySize,tracking:ruleTracking(bodySize)*1000,leading:kind==='spell'?65:BODY_SIZE,paragraphGap:kind==='spell'?null:0,rulesLeft:kind==='spell'?null:body.left,choiceReference:body.rows?.some(p=>p.option)?'character-fdf-112.jpg':null,bodyEmbolden:BODY_WEIGHT,keywordEmbolden:bodySize*.032,keywords:keywordRanges(c['能力文字']).map(r=>r.text),titleFont:kind==='spell'?'DFJinWen-W3-WIN-BF':BRUSH,titleMaxSize:kind==='spell'?100:75,titleTracking:kind==='spell'?220:-5,modifierTokens:[...c['能力文字'].matchAll(modifierPattern())].map(m=>m[0])};
 if(titleProfile)result.titleCalibration='native-ink-glow-vmtx';
 console.log(id,kind,result.bodyLines);return result;
}
async function comparisons(report){
 const tiles=[];
 for(let i=0;i<report.length;i++){
  const r=report[i],land=r.kind==='spell',w=land?1117:800,h=land?800:1117;
  const actual=await sharp(path.join(design,'cards',r.id+'.png')).resize(w,h).png().toBuffer();
  let ref=sharp(path.join(root,'recourse/数据库',r.reference));
  if(land)ref=ref.rotate(270);
  const reference=await ref.resize(w,h).png().toBuffer();
  const header=Buffer.from(`<svg width="${w*2+48}" height="64"><rect width="100%" height="100%" fill="#17202b"/>${text('新版 testmod · '+r.name,20,42,25,`font-family="${BODY}" fill="white"`)}${text('数据库参考 · '+r.reference,w+34,42,25,`font-family="${BODY}" fill="white"`)}</svg>`);
  await sharp({create:{width:w*2+48,height:h+88,channels:4,background:'#17202b'}}).composite([{input:header,left:0,top:0},{input:actual,left:12,top:64},{input:reference,left:w+36,top:64}]).png().toFile(path.join(design,'comparisons',r.id+'.png'));
  const thumb=await sharp(actual).resize(land?560:402,560,{fit:'inside'}).png().toBuffer();
  const x=i%4*590,y=Math.floor(i/4)*640;
  const metadata=await sharp(thumb).metadata();
  tiles.push({input:thumb,left:x+Math.round((590-metadata.width)/2),top:y+20});
  tiles.push({input:Buffer.from(`<svg width="590" height="60">${text(r.name,295,36,23,`font-family="${BODY}" text-anchor="middle" fill="white"`)}</svg>`),left:x,top:y+580});
 }
 await sharp({create:{width:2360,height:Math.ceil(report.length/4)*640,channels:4,background:'#17202b'}}).composite(tiles).png().toFile(path.join(design,'overview.png'));
 const html=`<!doctype html><meta charset="utf-8"><title>testmod 逐张对照</title><style>body{margin:30px;background:#17202b;color:#eee;font:16px sans-serif}img{width:100%;max-width:1700px}section{margin:40px 0}a{color:#abd9ff}</style><h1>testmod · 正确模板重制逐张对照</h1><p>左：新版成品；右：数据库同类型参考。保留独立插画和牌文，只比较 UI 样式。结界使用符卡 PSD，类型为「结界」。</p>${report.map(r=>`<section><h2>${esc(r.name)}</h2><img src="comparisons/${r.id}.png"><p><a href="cards/${r.id}.png">原尺寸 PNG</a> · ${r.dimensions.join(' × ')} · 参考 ${esc(r.reference)}</p></section>`).join('')}`;
 fs.writeFileSync(path.join(design,'comparison-gallery.html'),html);
}
(async()=>{
 if(process.argv.includes('--comparisons-only')){
  await comparisons(JSON.parse(fs.readFileSync(path.join(design,'render-report.json'),'utf8')));return;
 }
 execFileSync(process.env.TESTMOD_PYTHON||'C:/Users/Lenovo/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe',[path.join(root,'tools/outline_testmod_text.py'),'--metrics','--metrics-output',path.join(design,'font-metrics.json')],{env:{...process.env,PYTHONPATH:path.join(root,'work/psd-python'),PYTHONIOENCODING:'utf-8'}});
 metrics=JSON.parse(fs.readFileSync(path.join(design,'font-metrics.json'),'utf8'));
 const manifest=JSON.parse(fs.readFileSync(path.join(pack,'manifest.json'),'utf8')),report=[],filter=process.argv.slice(2);
 for(let i=0;i<manifest.cards.length;i++){
  const c=JSON.parse(fs.readFileSync(path.join(pack,manifest.cards[i]),'utf8'));
  // Existing native token art is a res:// reference, not an AI illustration.
  if(String(c['图片']).startsWith('res://'))continue;
  if(filter.length&&!filter.includes(c['卡牌ID'].split('/')[1]))continue;
  report.push(await render(c,i));
 }
 const previous=filter.length&&fs.existsSync(path.join(design,'render-report.json'))?JSON.parse(fs.readFileSync(path.join(design,'render-report.json'),'utf8')):[];
 const all=[...previous.filter(card=>!report.some(r=>r.id===card.id)),...report].sort((a,b)=>manifest.cards.indexOf(a.id+'.json')-manifest.cards.indexOf(b.id+'.json'));
 fs.writeFileSync(path.join(design,'render-report.json'),JSON.stringify(all,null,2));
 await comparisons(all);
})().catch(e=>{console.error(e);process.exit(1)});
