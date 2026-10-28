const fs=require('node:fs');
const path=require('node:path');
const sharp=require('/Users/eros/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const out=__dirname;
const data=JSON.parse(fs.readFileSync(path.join(out,'../v2/menu-data-v2.json'),'utf8'));
for(const item of data.sections[0].items){if(item.detail)item.oldPrice=({3:8000,4:12000,6:17000})[item.name.match(/[346]/)[0]]+(item.detail.includes('نصف')?6000:12000);}
data.sections[3].items[1].oldPrice=6000;
data.oldPriceCalculation='Owner requested summing old tray price with old chicken 12000; half chicken calculated as 12000/2=6000.';
const fontBold=path.join(out,'../v3/fonts/Tajawal-Bold.ttf');
const fontMedium=path.join(out,'../v3/fonts/Tajawal-Medium.ttf');
const esc=s=>String(s).replace(/100%/g, '\u200E100%\u200E').replace(/[&<>\"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const number=n=>n.toLocaleString('en-US');
const arabic='Tajawal';
let svgParts=[],htmlParts=[],textSpecs=[];
function text(s,x,y,size,color='#F4F1E7',align='end',weight=700,arab=true){
 const family=arab?arabic:'Tajawal';
 textSpecs.push({s,x,y,size,color,align,weight,arab});
 svgParts.push(`<text x="${x}" y="${y}" text-anchor="${arab && align === 'end' ? 'start' : align}" direction="${arab ? 'rtl' : 'ltr'}" unicode-bidi="embed" dominant-baseline="middle" font-family="${family}" font-size="${size}" font-weight="${weight}" fill="${color}">${esc(s)}</text>`);
 const left=align==='middle'?x-220:align==='end'?x-640:x;
 const width=align==='middle'?440:640;
 htmlParts.push(`<div style="position:absolute;left:${left}px;top:${y-size*0.76}px;width:${width}px;height:${size*1.55}px;font-family:${family};font-size:${size}px;font-weight:${weight};line-height:1.5;color:${color};text-align:${align==='middle'?'center':align==='end'?'right':'left'};direction:${arab?'rtl':'ltr'};white-space:nowrap">${esc(s)}</div>`);
}
function rect(x,y,w,h,color,r=0){svgParts.push(`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${r}" fill="${color}"/>`);htmlParts.push(`<div style="position:absolute;left:${x}px;top:${y}px;width:${w}px;height:${h}px;background:${color};border-radius:${r}px"></div>`);}
function line(x1,y1,x2,y2,color,width=1){svgParts.push(`<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${color}" stroke-width="${width}" stroke-linecap="round"/>`); const length=Math.hypot(x2-x1,y2-y1),angle=Math.atan2(y2-y1,x2-x1)*180/Math.PI;htmlParts.push(`<div style="position:absolute;left:${x1}px;top:${y1}px;width:${length}px;height:${width}px;background:${color};transform-origin:left center;transform:rotate(${angle}deg)"></div>`);}
function oldPrice(value,x,y,width=90){
 text(number(value),x,y,26,'#C1BEB2','middle',500,false);
 // Tajawal numeral ink is centered 10 px above the HTML text anchor.
 const crossY=y-10;
 line(x-width/2,crossY-7,x+width/2,crossY+7,'#A7A398',1.5);
 line(x-width/2,crossY+7,x+width/2,crossY-7,'#A7A398',1.5);
}
rect(0,0,1080,1440,'#0B0B0B');
text('مطعم جنة بغداد',540,62,51,'#F7F4EA','middle');
text('الدولار يصعد',540,142,58,'#F7F4EA','middle');
text('وأسعارنا تنزل',540,217,79,'#FFD13B','middle');
text('جميع الأسعار بالدينار العراقي',540,270,24,'#CCC8BA','middle',500);
line(60,296,1020,296,'#4A4638',1);
text('صواني الدليمية',1008,329,36,'#FFD13B');
text('الحجم',1005,382,26,'#C3BFAF');
text('دليمية فقط',710,382,28,'#F7F4EA','middle');
text('مع نصف دجاجة',435,382,28,'#F7F4EA','middle');
text('مع دجاجة',160,382,28,'#F7F4EA','middle');
line(60,405,1020,405,'#5B5541',1.4);
for(const x of [300,570,810])line(x,365,x,692,'#2C2A24',1);
const trays=[
 {size:3,old:8000,plain:6000,half:10000,full:15000},
 {size:4,old:12000,plain:10000,half:15000,full:20000},
 {size:6,old:17000,plain:15000,half:20000,full:25000}
];
for(let i=0;i<3;i++){
 const row=trays[i],y=457+i*100;
 text(row.size+' نفرات',1005,y,34,'#F7F4EA');
 oldPrice(row.old,710,y-31);
 oldPrice(row.old+6000,435,y-31);
 oldPrice(row.old+12000,160,y-31);
 text(number(row.plain),710,y+9,47,'#FFD13B','middle',700,false);
 text(number(row.half),435,y+9,47,'#FFD13B','middle',700,false);
 text(number(row.full),160,y+9,47,'#FFD13B','middle',700,false);
 line(60,y+40,1020,y+40,'#363229',1);
}
text('كباب لحم',1005,745,36,'#FFD13B');
text('لحم عراقي 100%',1005,779,26,'#F0EBDD','end',500);
text('كباب وتكة دجاج',510,745,36,'#FFD13B');
line(540,727,540,1123,'#37332A',1);
const beef=[['كيلو كباب','',25000,20000,844],['نفر كباب','صمون دبل',16000,14000,937],['لفة كباب','صمون دبل',3000,2500,1030]];
const chickenKebab=[['لفة كباب','صمون دبل',2500,2000,844],['لفة تكة','صمون دبل',2500,2000,920],['كيلو كباب','شيش دبل',20000,15000,996],['نفر كباب','شيش دبل',16000,12000,1072]];
for(const [right,now,before,list] of [[1005,610,730,beef],[510,112,230,chickenKebab]]){
 text('قبل',before,806,22,'#C3BFAF','middle',500);
 text('هسه',now,806,24,'#FFD13B','middle');
 for(const [label,detail,old,newPrice,y] of list){
  text(label,right,detail?y-5:y,33,'#F7F4EA');
  if(detail)text(detail,right,y+24,25,'#D4CEBD','end',500);
  oldPrice(old,before,y+2,88);
  text(number(newPrice),now,y+2,43,'#FFD13B','middle',700,false);
  line(right-455,y+43,right,y+43,'#302C24',1);
 }
}
line(60,1140,1020,1140,'#5B5541',1.3);
text('الدجاج',1005,1180,36,'#FFD13B');
text('قدح برياني + مقبلات + صمون',1005,1220,27,'#F0EBDD','end',500);
text('دجاجة كاملة',1005,1280,33,'#F7F4EA');
oldPrice(12000,730,1282,90);text('10,000',610,1282,45,'#FFD13B','middle',700,false);
text('نصف دجاجة',510,1280,33,'#F7F4EA');
oldPrice(6000,230,1282,88);
text('5,000',112,1282,45,'#FFD13B','middle',700,false);
rect(60,1350,960,65,'#FFD13B',8);
text('للتوصيل',920,1391,30,'#121210','end');
text('07710671288',540,1392.5,48,'#121210','middle',700,false);
const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="1080" height="1440" viewBox="0 0 1080 1440">${svgParts.join('')}</svg>`;
fs.writeFileSync(out+'/jannat-baghdad-menu-v5.svg',svg);
const fontCSS=`@font-face{font-family:Tajawal;font-style:normal;font-weight:700;src:url(data:font/ttf;base64,${fs.readFileSync(fontBold).toString('base64')})}@font-face{font-family:Tajawal;font-style:normal;font-weight:400 500;src:url(data:font/ttf;base64,${fs.readFileSync(fontMedium).toString('base64')})}`;
fs.writeFileSync(out+'/jannat-baghdad-menu-v5.html',`<!doctype html><html lang="ar"><head><meta charset="utf-8"><title>مطعم جنة بغداد — المينيو المرتب</title><style>${fontCSS}</style></head><body style="margin:0;background:#0B0B0B"><main data-document-role="page" data-label="مطعم جنة بغداد — المينيو المرتب" style="position:relative;width:1080px;height:1440px;overflow:hidden">${htmlParts.join('')}</main></body></html>`);
fs.writeFileSync(out+'/menu-data-v5.json',JSON.stringify({...data,version:5,layout:'Dulaimiya price matrix with 3 sizes and 3 chicken options; 3 beef kebab, 4 chicken kebab and 2 chicken items',trays,renderedBeef:beef,renderedChickenKebab:chickenKebab},null,2));
(async()=>{
 await sharp({text:{text:'تجربة',fontfile:fontBold,font:'Tajawal Bold 30',rgba:true}}).png().toBuffer();
 await sharp({text:{text:'تجربة',fontfile:fontMedium,font:'Tajawal Medium 30',rgba:true}}).png().toBuffer();
 const shapeOnly=svg.replace(/<text[\s\S]*?<\/text>/g,'');
 const overlays=[];
 for(const t of textSpecs){
  const face=t.weight>=700?'Bold':'Medium';
  const file=t.weight>=700?fontBold:fontMedium;
  const input=await sharp({text:{text:`<span foreground="${t.color}">${esc(t.s)}</span>`,fontfile:file,font:`Tajawal ${face} ${t.size}`,rgba:true,dpi:144}}).png().toBuffer();
  const meta=await sharp(input).metadata();
  const left=Math.round(t.x*2-(t.align==='middle'?meta.width/2:t.align==='end'?meta.width:0));
  const top=Math.round(t.y*2-meta.height/2);
  if(left<0||top<0||left+meta.width>2160||top+meta.height>2880)throw new Error('Text outside poster: '+t.s);
  overlays.push({input,left,top});
 }
 await sharp(Buffer.from(shapeOnly)).resize(2160,2880).composite(overlays).png().toFile(out+'/jannat-baghdad-menu-v5.png');
 fs.writeFileSync(out+'/typography-check.json',JSON.stringify({font:'Tajawal',canvas:[2160,2880],textElements:textSpecs.length,bounds:'all within poster'},null,2));
 console.log(out+'/jannat-baghdad-menu-v5.png');
})();
