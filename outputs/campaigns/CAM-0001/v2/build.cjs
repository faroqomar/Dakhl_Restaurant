const fs=require('node:fs');
const sharp=require('/Users/eros/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const out=__dirname;
const sections=[
 {title:'صواني الدليمية',x:1005,header:425,price:615,before:725,items:[
 ['دليمية — 3 نفرات','',8000,6000,480],
 ['دليمية — 4 نفرات','',12000,10000,565],
 ['دليمية — 6 نفرات','',17000,15000,650],
 ['دليمية — 3 نفرات','+ نصف دجاجة',null,10000,735],
 ['دليمية — 3 نفرات','+ دجاجة',null,15000,820],
 ['دليمية — 4 نفرات','+ نصف دجاجة',null,15000,905],
 ['دليمية — 4 نفرات','+ دجاجة',null,20000,990],
 ['دليمية — 6 نفرات','+ نصف دجاجة',null,20000,1075],
 ['دليمية — 6 نفرات','+ دجاجة',null,25000,1160]]},
 {title:'كباب لحم عراقي',x:510,header:425,price:112,before:225,items:[
 ['كيلو كباب لحم','عراقي 100%',25000,20000,480],
 ['نفر كباب لحم','عراقي 100% · صمون دبل',16000,14000,565],
 ['لفة كباب لحم','عراقي 100% · صمون دبل',3000,2500,650]]},
 {title:'كباب وتكة دجاج',x:510,header:721,price:112,before:225,items:[
 ['لفة كباب دجاج','صمون دبل',2500,2000,770],
 ['لفة تكة دجاج','صمون دبل',2500,2000,842],
 ['كيلو كباب دجاج','شيش دبل',20000,15000,914],
 ['نفر كباب دجاج','شيش دبل',16000,12000,986]]},
 {title:'الدجاج',subtitle:'قدح برياني + مقبلات + صمون',x:510,header:1065,price:112,before:225,items:[
 ['دجاجة كاملة','',12000,10000,1160],
 ['نصف دجاجة','',null,5000,1245]]}
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
rect(52,45,5,70,'#FFD13B',2);rect(1023,45,5,70,'#FFD13B',2);
text('مطعم جنة بغداد',540,80,56,'#F7F3E9','middle');
text('الدولار يصعد…',540,170,59,'#F7F3E9','middle');
text('وأسعارنا تنزل',540,248,80,'#FFD13B','middle');
text('جميع الأسعار بالدينار العراقي',540,312,22,'#999991','middle',400);
line(540,354,540,1305,'#37372E',1.4);
for(const [right,old,now] of [[510,225,112],[1005,725,615]]){
 text('الصنف',right,373,23,'#A6A69F');text('قبل',old,373,22,'#A6A69F','middle');text('هسه',now,373,24,'#FFD13B','middle');
}
for(const section of sections){
 const {x,header,price,before,items,title}=section;
 text(title,x,header,31,'#FFD13B');
 if(section.subtitle)text(section.subtitle,x,header+37,22,'#C8C7BB','end',400);
 for(const [label,detail,old,now,y] of items){
  text(label,x,detail?y-8:y,28,'#F7F3E9');
  if(detail)text(detail,x,y+21,20,'#BBBAB0','end',400);
  if(old!==null){
   text(number(old),before,y,23,'#A3A39D','middle',400,false);
   line(before-42,y-10,before+42,y+10,'#B8B5AA',1.8);
   line(before-42,y+10,before+42,y-10,'#B8B5AA',1.8);
  }
  text(number(now),price,y,38,'#FFD13B','middle',700,false);
  line(x-454,y+43,x,y+43,'#292924',1);
 }
}
rect(60,1350,960,65,'#FFD13B',12);
text('للتوصيل',795,1382,31,'#121210','end');text('07710671288',480,1383,45,'#121210','middle',700,false);
const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="1080" height="1440" viewBox="0 0 1080 1440">${svgParts.join('')}</svg>`;
fs.writeFileSync(out+'/jannat-baghdad-menu-v2.svg',svg);
fs.writeFileSync(out+'/jannat-baghdad-menu-v2.html',`<!doctype html><html lang="ar"><head><meta charset="utf-8"><title>مطعم جنة بغداد — الدليمية والدجاج</title></head><body style="margin:0;background:#0B0B0B"><main data-document-role="page" data-label="مطعم جنة بغداد — المينيو المحدث" style="position:relative;width:1080px;height:1440px;overflow:hidden">${htmlParts.join('')}</main></body></html>`);
fs.writeFileSync(out+'/menu-data-v2.json',JSON.stringify({restaurant:'مطعم جنة بغداد',delivery:'07710671288',currency:'IQD',date:'2026-10-17',chickenIncludes:'قدح برياني + مقبلات + صمون',inference:'20,00 interpreted as 20,000 for kilogram Iraqi beef kebab in v1',sections:sections.map(s=>({title:s.title,subtitle:s.subtitle,items:s.items.map(([name,detail,oldPrice,newPrice])=>({name,detail,oldPrice,newPrice}))}))},null,2));
sharp(Buffer.from(svg)).resize(2160,2880).png().toFile(out+'/jannat-baghdad-menu-v2.png').then(()=>console.log(out+'/jannat-baghdad-menu-v2.png'));
