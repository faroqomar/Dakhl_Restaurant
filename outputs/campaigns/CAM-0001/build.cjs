const fs=require('node:fs');
const sharp=require('/Users/eros/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const out=__dirname;
const items=[
 ['صينية دليمية — 3 نفرات','',8000,6000,461],
 ['صينية دليمية — 4 نفرات','',12000,10000,535],
 ['صينية دليمية — 6 نفرات','',17000,15000,609],
 ['كيلو كباب لحم','عراقي 100%',25000,20000,755],
 ['نفر كباب لحم','عراقي 100% · صمون دبل',16000,14000,829],
 ['لفة كباب لحم','عراقي 100% · صمون دبل',3000,2500,903],
 ['لفة كباب دجاج','صمون دبل',2500,2000,1049],
 ['لفة تكة دجاج','صمون دبل',2500,2000,1123],
 ['كيلو كباب دجاج','شيش دبل',20000,15000,1197],
 ['نفر كباب دجاج','شيش دبل',16000,12000,1271]
];
const esc=s=>String(s).replace(/100%/g, '\u200E100%\u200E').replace(/[&<>\"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const number=n=>n.toLocaleString('en-US');
const arabic='Arial';
let svgParts=[],htmlParts=[];
function text(s,x,y,size,color='#F4F1E7',align='end',weight=700,arab=true){
 const family=arab?arabic:'Arial';
 svgParts.push(`<text x="${x}" y="${y}" text-anchor="${arab && align === 'end' ? 'start' : align}" direction="${arab ? 'rtl' : 'ltr'}" unicode-bidi="embed" dominant-baseline="middle" font-family="${family}" font-size="${size}" font-weight="${weight}" fill="${color}">${esc(s)}</text>`);
 const left=align==='middle'?x-220:align==='end'?x-640:x;
 const width=align==='middle'?440:640;
 htmlParts.push(`<div style="position:absolute;left:${left}px;top:${y-size*0.76}px;width:${width}px;height:${size*1.55}px;font-family:${family};font-size:${size}px;font-weight:${weight};line-height:1.5;color:${color};text-align:${align==='middle'?'center':align==='end'?'right':'left'};direction:${arab?'rtl':'ltr'};white-space:nowrap">${esc(s)}</div>`);
}
function rect(x,y,w,h,color,r=0){svgParts.push(`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${r}" fill="${color}"/>`);htmlParts.push(`<div style="position:absolute;left:${x}px;top:${y}px;width:${w}px;height:${h}px;background:${color};border-radius:${r}px"></div>`);}
function line(x1,y1,x2,y2,color,width=1){svgParts.push(`<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${color}" stroke-width="${width}" stroke-linecap="round"/>`); const length=Math.hypot(x2-x1,y2-y1),angle=Math.atan2(y2-y1,x2-x1)*180/Math.PI;htmlParts.push(`<div style="position:absolute;left:${x1}px;top:${y1}px;width:${length}px;height:${width}px;background:${color};transform-origin:left center;transform:rotate(${angle}deg)"></div>`);}
rect(0,0,1080,1440,'#0B0B0B');
rect(51,45,6,80,'#FFD13B',3);rect(1023,45,6,80,'#FFD13B',3);
text('مطعم جنة بغداد',540,87,57,'#F7F3E9','middle');
text('الدولار يصعد…',540,187,65,'#F7F3E9','middle');
text('وأسعارنا تنزل',540,272,87,'#FFD13B','middle');
text('جميع الأسعار بالدينار العراقي',540,337,22,'#999991','middle',400);
text('الصنف',1000,384,27,'#A6A69F');text('قبل',350,384,24,'#A6A69F','middle');text('هسه',155,384,26,'#FFD13B','middle');
for(const [label,y] of [['الدليمية',416],['كباب لحم عراقي',708],['كباب وتكة دجاج',1000]]){
 line(60,y+4,760,y+4,'#3C3C36',1);text(label,1000,y,29,'#FFD13B');
}
for(const [label,detail,old,now,y] of items){
 text(label,1000,detail?y-8:y,34,'#F7F3E9');
 if(detail)text(detail,1000,y+23,22,'#AAA99F', 'end',400);
 text(number(old),350,y,31,'#A3A39D','middle',400,false);
 line(291,y-13,409,y+13,'#B8B5AA',2.2);line(291,y+13,409,y-13,'#B8B5AA',2.2);
 text(number(now),155,y,51,'#FFD13B','middle',700,false);
 line(60,y+43,1000,y+43,'#272724',1);
}
rect(60,1349,960,66,'#FFD13B',12);
text('للتوصيل',795,1382,31,'#121210','end');text('07710671288',480,1383,45,'#121210','middle',700,false);
const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="1080" height="1440" viewBox="0 0 1080 1440">${svgParts.join('')}</svg>`;
fs.writeFileSync(out+'/jannat-baghdad-menu.svg',svg);
fs.writeFileSync(out+'/jannat-baghdad-menu.html',`<!doctype html><html lang="ar"><head><meta charset="utf-8"><title>مطعم جنة بغداد — أسعارنا تنزل</title></head><body style="margin:0;background:#0B0B0B"><main data-document-role="page" data-label="مطعم جنة بغداد — قائمة الأسعار الجديدة" style="position:relative;width:1080px;height:1440px;overflow:hidden">${htmlParts.join('')}</main></body></html>`);
fs.writeFileSync(out+'/menu-data.json',JSON.stringify({restaurant:'مطعم جنة بغداد',delivery:'07710671288',currency:'IQD',inference:'20,00 interpreted as 20,000 for kilogram Iraqi beef kebab',items:items.map(([name,detail,oldPrice,newPrice])=>({name,detail,oldPrice,newPrice}))},null,2));
sharp(Buffer.from(svg)).resize(2160,2880).png().toFile(out+'/jannat-baghdad-menu.png').then(()=>console.log(out+'/jannat-baghdad-menu.png'));
