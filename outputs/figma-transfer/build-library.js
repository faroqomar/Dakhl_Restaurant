const page=await figma.getNodeByIdAsync('0:1');await figma.setCurrentPageAsync(page);
const created=[],components={},styles=Object.fromEntries((await figma.getLocalTextStylesAsync()).map(s=>[s.name.split('/')[1],s]));
const vars=Object.fromEntries((await figma.variables.getLocalVariablesAsync()).map(v=>[v.name,v]));
for(const style of ['Regular','Bold'])await figma.loadFontAsync({family:'Noto Sans Arabic',style});
const paint=(name)=>figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:0,g:0,b:0}},'color',vars['color/'+name]);
function bind(n,field,key){n.setBoundVariable(field,vars[key]);}
async function txt(parent,content,style='Body',color='ink',width){const t=figma.createText();created.push(t.id);t.fontName=styles[style].fontName;t.characters=content;await t.setTextStyleIdAsync(styles[style].id);t.fills=[paint(color)];t.textAlignHorizontal='RIGHT';parent.appendChild(t);if(width){t.textAutoResize='HEIGHT';t.resize(width,t.height)}return t;}
function box(parent,name,dir='VERTICAL',w=300){const n=figma.createAutoLayout(dir,{name,itemSpacing:8});created.push(n.id);n.fills=[];n.resize(w,40);parent.appendChild(n);n.layoutSizingVertical='HUG';bind(n,'itemSpacing','space');return n;}
function component(name,w=300,h=60,dir='HORIZONTAL',fill='paper'){const c=figma.createComponent();created.push(c.id);c.name=name;c.resize(w,h);c.layoutMode=dir;c.primaryAxisSizingMode='FIXED';c.counterAxisSizingMode='FIXED';c.counterAxisAlignItems='CENTER';c.primaryAxisAlignItems='CENTER';c.fills=[paint(fill)];c.strokes=[paint('line')];c.cornerRadius=10;bind(c,'cornerRadius','radius');c.itemSpacing=8;page.appendChild(c);return c;}
function set(name,variants,columns=3){const s=figma.combineAsVariants(variants,page);created.push(s.id);s.name=name;s.description='Source-aligned Daftar component. Arabic RTL, local restaurant workflow. Source: app/ui/styles.css, ux.css, commerce.css.';variants.forEach((v,i)=>{v.x=24+(i%columns)*350;v.y=40+Math.floor(i/columns)*160});s.resize(columns*350+24,Math.ceil(variants.length/columns)*160+40);components[name]={id:s.id,variants:variants.map(v=>({id:v.id,name:v.name}))};return s;}
const sets=[];
for(const family of ['Button','Field','Badge','Tab','Checkbox','Quantity','Alert']){
 const vs=[];const defs=family==='Button'?['Primary/Default','Primary/Hover','Primary/Disabled','Secondary/Default','Secondary/Hover','Secondary/Disabled','Ghost/Default','Danger/Default']:family==='Field'?['Text','Search','Select','Date','Textarea','Error','Disabled']:family==='Badge'?['Available','Low stock','Paid','Returned','Void']:family==='Tab'?['Default','Selected']:family==='Checkbox'?['Unchecked','Checked']:family==='Quantity'?['Default','Minimum','Disabled']:['Info','Success','Error'];
 for(const value of defs){const w=family==='Button'?160:family==='Badge'?130:family==='Tab'?180:300,h=family==='Field'&&value==='Textarea'?86:family==='Alert'?70:42;
 const primary=value.startsWith('Primary'),danger=value.startsWith('Danger')||value==='Error',c=component('State='+value.replaceAll('/',' · '),w,h,'HORIZONTAL',primary?'green':family==='Badge'||value==='Selected'?'soft':'paper');
 if(value.includes('Disabled'))c.opacity=.45;if(value.includes('Hover'))c.fills=[paint(primary?'ink':'soft')];if(danger)c.strokes=[paint('red')];
 const labels={Button:danger?'حذف':'حفظ التغيير',Field:value==='Search'?'ابحث بالاسم أو الرمز…':value==='Select'?'الكل  ⌄':value==='Date'?'2026/10/27':value==='Error'?'راجع القيمة المطلوبة':'اكتب القيمة',Badge:({Available:'متوفر','Low stock':'مخزون قليل',Paid:'مدفوع نقداً',Returned:'مرتجع',Void:'ملغاة'})[value],Tab:'المبيعات',Checkbox:(value==='Checked'?'☑':'☐')+'  إعادة للمخزن',Quantity:'−      1      +',Alert:value==='Error'?'تعذّر الحفظ. حاول مرة ثانية.':value==='Success'?'تم حفظ التغييرات':'المبلغ يحسب مرة واحدة من مصدره'};
 const t=await txt(c,labels[family],family==='Button'?'Strong':'Label',primary?'paper':danger?'red':'ink');const label=c.addComponentProperty('Label','TEXT',labels[family]);t.componentPropertyReferences={characters:label};vs.push(c);
 }sets.push(set(family,vs,family==='Button'?4:3));
}
for(const [name,w,h,dir]of [['Product Card',180,260,'VERTICAL'],['Cart Line',340,88,'VERTICAL'],['Held Order',540,100,'HORIZONTAL'],['Summary',240,90,'VERTICAL'],['Table Row',900,64,'HORIZONTAL'],['Table Header',900,44,'HORIZONTAL'],['Empty State',420,150,'VERTICAL'],['Dialog Shell',620,260,'VERTICAL'],['Navigation Item',220,44,'HORIZONTAL']]){
 const c=component(name,w,h,dir);c.paddingLeft=c.paddingRight=16;c.paddingTop=c.paddingBottom=12;bind(c,'paddingLeft','space');bind(c,'paddingRight','space');
 if(name==='Product Card'){const media=box(c,'Photo slot','VERTICAL',148);media.resize(148,110);media.layoutSizingVertical='FIXED';media.fills=[paint('soft')];await txt(media,'صورة الصنف','Caption','muted');await txt(c,'كباب لحم','Strong');await txt(c,'12,000 د.ع','Strong','green');await txt(c,'بالمخزن 18 قطعة','Caption','muted');}
 else if(name==='Cart Line'){await txt(c,'كباب لحم   × 2','Strong');await txt(c,'−      2      +             24,000 د.ع','Label');}
 else if(name==='Held Order'){await txt(c,'طاولة 3 · صالة · صنفان','Strong');await txt(c,'استرجاع الطلب      حذف','Label','green');}
 else if(name.includes('Table')){for(const t of ['الصنف / التفاصيل','المبلغ · د.ع','الحالة','الإدارة'])await txt(c,t,'Label');}
 else if(name==='Summary'){await txt(c,'مصروف اليومي','Label','muted');await txt(c,'40,000 د.ع','Amount','green');}
 else if(name==='Empty State'){await txt(c,'ماكو نتائج بعد','Section');await txt(c,'أضف أول سجل أو غيّر اختيارات التصفية.','Body','muted',350);}
 else if(name==='Dialog Shell'){await txt(c,'عنوان النافذة      ×','Section');await txt(c,'حقول النموذج وتفاصيل الإجراء','Body','muted');await txt(c,'حفظ التغيير      إلغاء','Strong','green');}
 else await txt(c,'المصاريف اليومية','Strong');
 c.description='Reusable editable '+name+'. Source: app/ui/commerce.js and renderer.js; shared styles ux.css.';components[name]={id:c.id,variants:[]};sets.push(c);
}
let y=1850;for(const s of sets){s.x=80;s.y=y;y+=s.height+100}
const guide=box(page,'Start here · ابدأ هنا','VERTICAL',1120);guide.x=80;guide.y=80;guide.paddingTop=guide.paddingBottom=guide.paddingLeft=guide.paddingRight=32;guide.fills=[paint('paper')];guide.itemSpacing=16;
await txt(guide,'دفتر / نظام التصميم والواجهات','Page');await txt(guide,'Editable source transfer · 2026-10-27 · App 1.12.0 / schema 11','Body','muted');
await txt(guide,'01 النظام والمكونات · 02 الشاشات والمقاسات · 03 النوافذ والحالات','Section');
await txt(guide,'المصدر: واجهات التطبيق الحالية. كل البيانات توضيحية ومعزولة. الأولوية للعربية RTL، الأخضر الهادئ، التحكم المدمج، وهوامش 24px. لا تصف الأرصدة بأنها ربح.','Body','ink',1040);
await txt(guide,'الخط: Geeza Pro / Tahoma في التطبيق. غير متاحين في محرر Figma البعيد؛ يستخدم هذا الملف Noto Sans Arabic بديلاً عربياً قابلاً للتحرير. هذا فرق موثق وليس تغييراً معتمداً لخط التطبيق.','Body','muted',1040);
await txt(guide,'مؤجل بنص المالك: إعداد الاستخدام الأول وتذكيرات النسخ. الطباعة تفتح حوار النظام، ولا يشمل النقل محاكاة واجهة macOS الأصلية أو اختبار طابعة فعلية.','Body','muted',1040);
const foundation=box(page,'Foundations · الألوان والمقاييس','VERTICAL',1120);foundation.x=80;foundation.y=700;foundation.itemSpacing=16;await txt(foundation,'الألوان / Source tokens','Section');
const swatches=box(foundation,'Colors','HORIZONTAL',1100);swatches.layoutWrap='WRAP';swatches.counterAxisSizingMode='FIXED';
for(const name of ['bg','paper','ink','muted','line','green','soft','lime','red','focus']){const card=box(swatches,name,'VERTICAL',190);card.resize(190,95);card.layoutSizingVertical='FIXED';card.fills=[paint(name)];await txt(card,name,'Strong',['ink','muted','green','red','focus'].includes(name)?'paper':'ink');}
await txt(foundation,'42px controls · 24px page gutter · 20px panel padding · 16px spacing · 10px radius','Body');await txt(foundation,'Typography / 12 · 13 · 15 · 20 · 28 · 30','Section');
for(const style of ['Caption','Label','Body','Strong','Section','Amount','Page'])await txt(foundation,'دفتر · تفاصيل واضحة 12,000 — '+style,style);
return {createdNodeIds:created,mutatedNodeIds:[],components,guide:guide.id,foundation:foundation.id,componentCount:Object.keys(components).length};
