const fs=require('node:fs');
const path=require('node:path');
const out=__dirname;
const fontRoot=path.resolve(out,'../../../campaigns/CAM-0001/v3/fonts');
const fontBold=path.join(fontRoot,'Tajawal-Bold.ttf');
const fontMedium=path.join(fontRoot,'Tajawal-Medium.ttf');
const data=JSON.parse(fs.readFileSync(path.join(out,'menu-data.json'),'utf8'));
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

rect(0,0,1080,1600,'#0B0B0B');
text('مطعم جنة بغداد',540,65,51,'#F7F4EA','middle');
text('منيو الصالة',540,143,66,'#FFD13B','middle');
text('جميع الأسعار بالدينار العراقي',540,192,24,'#CCC8BA','middle',500);
line(60,220,1020,220,'#4A4638',1);
const section=(s,x,y)=>text(s,x,y,35,'#FFD13B');
function item(i,right,priceX,y,width=455){
 text(i.name,right,y,32,'#F7F4EA');
 if(i.detail)text(i.detail,right,y+32,23,'#D4CEBD','end',500);
 text(number(i.price),priceX,y+4,43,'#FFD13B','middle',700,false);
 line(right-width,y+44,right,y+44,'#302C24',1);
}
section('صواني الدليمية',1005,265);
for(let j=0;j<2;j++)item(data.sections[0].items[j],1005,125,325+j*90,945);
line(60,480,1020,480,'#4A4638',1);
section('كباب لحم ومعلاك',1005,520);
text('لحم عراقي 100%',1005,553,24,'#D4CEBD','end',500);
section('كباب وتكة وكص دجاج',510,520);
line(540,500,540,970,'#37332A',1);
for(let j=0;j<3;j++)item(data.sections[1].items[j],1005,615,610+j*90);
for(let j=0;j<5;j++)item(data.sections[2].items[j],510,115,610+j*78);
line(60,990,1020,990,'#4A4638',1);
section('الدجاج',1005,1030);
for(let j=0;j<3;j++)item(data.sections[3].items[j],1005,615,1100+j*90);
section('السمك',510,1030);
item(data.sections[4].items[0],510,115,1100);
section('الشوربة والمخلمة',510,1210);
for(let j=0;j<2;j++)item(data.sections[5].items[j],510,115,1280+j*90);
section('الإضافات',1005,1390);
item(data.sections[6].items[0],1005,615,1450);
rect(60,1520,960,60,'#FFD13B',8);
text(data.delivery,540,1560,44,'#121210','middle',700,false);
text('للتواصل',950,1559,27,'#121210');
const fontCSS=`@font-face{font-family:Tajawal;font-style:normal;font-weight:700;src:url(data:font/ttf;base64,${fs.readFileSync(fontBold).toString('base64')})}@font-face{font-family:Tajawal;font-style:normal;font-weight:400 500;src:url(data:font/ttf;base64,${fs.readFileSync(fontMedium).toString('base64')})}`;
fs.writeFileSync(out+'/jannat-baghdad-dine-in.html',`<!doctype html><html lang="ar"><head><meta charset="utf-8"><title>مطعم جنة بغداد — منيو الصالة</title><style>${fontCSS}</style></head><body style="margin:0;background:#0B0B0B"><main data-document-role="page" data-label="مطعم جنة بغداد — منيو الصالة" style="position:relative;width:1080px;height:1600px;overflow:hidden">${htmlParts.join('')}</main></body></html>`);
fs.writeFileSync(out+'/jannat-baghdad-dine-in.svg',`<svg xmlns="http://www.w3.org/2000/svg" width="1080" height="1600" viewBox="0 0 1080 1600">${svgParts.join('')}</svg>`);
console.log('Dine-in menu built: '+data.sections.reduce((n,s)=>n+s.items.length,0)+' items');
