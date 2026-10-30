#!/usr/bin/env node
// Synthetic corpus only. Executes the unchanged frozen validator, not installed data.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
const source = path.join(root, 'electron-reference/app/ui/model.js');
const M = require(source);
const clone = x => structuredClone(x);
const cases = [];
function add(name, input) {
  let accepted = false, expected;
  try { expected = M.validate(JSON.parse(JSON.stringify(input))); accepted = true; } catch (_) {}
  cases.push({ name, input, accepted, ...(accepted ? { expected } : {}) });
}
const date = '2024-02-29', stamp = `${date}T12:00:00.000Z`;
function rich() {
  const s = M.empty();
  s.categories.push({id:'extra',name:'اختبار فقط',type:'additional',archived:true});
  s.days[date] = {expenses:[{id:'expense',categoryId:'bread',amount:3000,note:'fixture',funding:{source:'shared',dailyAmount:2000,cashAmount:1000},createdAt:stamp}],chickenUsed:2,chickenLeft:3,balance:30000,totalOverride:null,remaining:{amount:25000,dailySpent:2000,transferred:0,salesTotal:0},corrections:[{field:'balance',date,before:null,after:30000,reason:'fixture',createdAt:stamp}]};
  s.transactions.push({id:'deposit',date,type:'deposit',amount:100000,note:'fixture',createdAt:stamp});
  s.transfers.push({id:'transfer',date,amount:1000,createdAt:stamp});
  s.suppliers.push({id:'supplier',name:'مورد اختبار',phone:'',note:'fixture',categoryId:'market',openingBalance:10000,archived:true,materials:[{id:'legacy-material',name:'مادة قديمة',unit:'قطعة',price:3000,archived:false}]});
  s.materials.push({id:'material',name:'مادة اختبار',unit:'قطعة',priceCarton:10000,pricePiece:2000,archived:false});
  s.invoices.push({id:'invoice',supplierId:'supplier',number:'A-١',date,lines:[{materialId:'material',name:'الاسم التاريخي',unit:'قطعة',quantityCartons:'١',quantityPieces:'۲٫۵',priceCarton:10000,pricePiece:2000}],note:'fixture',createdAt:stamp});
  s.debts.push({id:'debt',supplierId:'supplier',date,amount:5000,note:'fixture',createdAt:stamp});
  s.payments.push({id:'payment',supplierId:'supplier',invoiceId:'invoice',invoiceAmount:3000,debtAmount:1000,categoryId:'market',date,amount:4000,funding:{source:'shared',dailyAmount:2000,cashAmount:2000},note:'fixture',createdAt:stamp});
  s.workers.push({id:'worker',name:'عامل اختبار',amount:5000,frequency:'monthly',startDate:'2024-01-31',archived:true,note:'compatibility only'});
  s.savingsEntries.push({id:'contribution',workerId:'worker',type:'contribution',date,amount:3000,periodStart:date,periodEnd:'2024-03-30',dueAmount:5000,note:'fixture',createdAt:stamp},{id:'receipt',workerId:'worker',type:'receipt',date,amount:1000,note:'fixture',createdAt:stamp});
  s.products.push({id:'product',name:'الاسم الحالي',code:'P1',unit:'قطعة',price:3000,group:'اختبار',minStock:'٠٫٥',trackStock:true,archived:false,photo:'water'});
  s.stockEntries.push({id:'opening',productId:'product',date,quantity:20,kind:'opening',note:'fixture',createdAt:stamp},{id:'adjust',productId:'product',date,quantity:1,kind:'adjustment',note:'fixture',createdAt:stamp},{id:'reverse',productId:'product',date,quantity:-1,kind:'adjustment',note:'reason',createdAt:stamp,reversesId:'adjust'});
  const sale = {id:'sale',number:'S1',date,status:'completed',lines:[{productId:'product',name:'الاسم التاريخي',unit:'قطعة',quantity:2,price:3000,trackStock:true}],discount:101,paid:5899,note:'fixture',createdAt:stamp,orderType:'صالة قديمة'};
  s.sales.push(sale,{...clone(sale),id:'void',number:'S2',status:'void',voidReason:'fixture',voidedAt:stamp});
  s.saleReturns.push({id:'return',saleId:'sale',date,reason:'fixture',createdAt:stamp,...M.returnQuote(s,'sale',[{productId:'product',quantity:0.5,restock:true}])});
  s.preferences={shortcuts:['sales','savings','','expenses','cash','settings'],orderTypes:[' صالة ','توصيل'],disabledOrderTypes:['سفري'],restaurant:{name:'اختبار',contact:'',footer:'fixture'}};
  return s;
}
for (let version=1; version<=11; version++) {
  const s=M.empty(); s.version=version;
  if(version<7) delete s.materials;
  if(version<8) for(const field of ['products','stockEntries','sales','preferences']) delete s[field];
  if(version<11) delete s.saleReturns;
  for(const c of s.categories) delete c.type;
  s.days[date]={expenses:[{id:'legacy-expense',categoryId:'bread',amount:1000,note:''}],chickenUsed:1,chickenLeft:0,balance:null,totalOverride:null,remaining:{amount:5000,dailySpent:1000,transferred:0}};
  add(`schema-${version}`,s);
}
const base=rich(); add('all-entities-history',base);
const legacy=clone(base); legacy.version=6; delete legacy.materials; legacy.invoices[0].lines=[{materialId:'legacy-material',name:'مادة قديمة',unit:'قطعة',quantity:2.5,price:3000}]; legacy.payments[0].invoiceAmount=3000; add('legacy-catalog-and-line',legacy);
for(let version=1;version<=11;version++) {const s=clone(legacy);s.version=version;add(`schema-${version}-rich-history`,s);}
for(const [name,stamp] of Object.entries({'year-only':'2000','US-date':'2/29/2024','RFC-date':'Thu, 29 Feb 2024 12:00:00 GMT','overflow-hour':'2024-02-29T25:00:00Z','hour24':'2024-02-29T24:00:00Z','overflow-minute':'2024-02-29T12:60:00Z','overflow-day':'2024-02-30T12:00:00Z','timestamp-zero':'0','timestamp-year-zero':'0000-01-01T00:00:00Z','invalid-date':'2024-13-01T00:00:00Z'})){const s=clone(base);s.sales[0].createdAt=stamp;add(name,s);}
// Independent review regressions: execute the actual frozen validator first.
for(const [name,stamp] of Object.entries({'timeclip-english':'31 Dec 275760','timeclip-numeric-december':'275760/12/31','timeclip-numeric-september':'275760/09/14','timestamp-EST':'Thu, 01 Jan 1970 00:00:00 EST','timestamp-date-Z':'2026-10-30Z'})){const s=clone(base);s.sales[0].createdAt=stamp;add(name,s);}
const maxSafeRemainder=M.empty();
maxSafeRemainder.days['2026-10-30']={expenses:[],chickenUsed:0,chickenLeft:0,balance:null,totalOverride:null,remaining:{amount:1,dailySpent:Number.MAX_SAFE_INTEGER,transferred:0}};
maxSafeRemainder.transfers=[{id:'t',date:'2026-10-30',amount:1,createdAt:'2026-10-30T12:00:00Z'}];
add('remaining-final-safe-after-unsafe-prefix',maxSafeRemainder);
for(const amount of [0,2,3,4]){const s=clone(maxSafeRemainder);s.days['2026-10-30'].remaining.amount=amount;add(`remaining-binary64-adjacent-${amount}`,s);}
const mutations={
 'future-version':s=>s.version=12,'missing-version':s=>delete s.version,'string-version':s=>s.version='11','duplicate-category':s=>s.categories.push(clone(s.categories[0])),'wrong-core-name':s=>s.categories[0].name='wrong','duplicate-expense':s=>s.days[date].expenses.push(clone(s.days[date].expenses[0])),
 'fraction-money':s=>s.days[date].expenses[0].amount=1.5,'negative-money':s=>s.days[date].expenses[0].amount=-1,'money-limit':s=>s.products[0].price=1000000000001,'wrong-funding':s=>s.days[date].expenses[0].funding.cashAmount++,
 'orphan-invoice':s=>s.invoices[0].supplierId='missing','orphan-material':s=>s.invoices[0].lines[0].materialId='missing','overpayment':s=>s.payments[0].invoiceAmount=100000,'payment-before-invoice':s=>s.payments[0].date='2024-02-28','bad-allocation':s=>s.payments[0].debtAmount=0,
 'invalid-leap-date':s=>s.sales[0].date='2023-02-29','year-zero':s=>s.sales[0].date='0000-02-29','year-0099':s=>s.sales[0].date='0099-02-28','year-0100':s=>s.sales[0].date='0100-02-28','invalid-timestamp':s=>s.sales[0].createdAt='nonsense',
 'timestamp-date-only':s=>s.sales[0].createdAt='2024-02-29','timestamp-offset':s=>s.sales[0].createdAt='2024-02-29T12:00:00+03:00','bad-stock':s=>s.stockEntries[0].quantity=0,'stock-shortage':s=>s.stockEntries[0].quantity=0.001,'bad-reversal':s=>s.stockEntries[2].quantity=-2,'changed-tracking':s=>s.sales[0].lines[0].trackStock=false,'duplicate-sale-line':s=>s.sales[0].lines.push(clone(s.sales[0].lines[0])),
 'invalid-return-amount':s=>s.saleReturns[0].amount++,'excess-return':s=>s.saleReturns[0].lines[0].quantity=3,'bad-return-date':s=>s.saleReturns[0].date='2024-02-28','bad-savings-period':s=>s.savingsEntries[0].periodStart='2024-02-28','savings-over-receipt':s=>s.savingsEntries[1].amount=4000,
 'empty-order-types':s=>s.preferences.orderTypes=[],'duplicate-disabled-type':s=>s.preferences.disabledOrderTypes=['صالة'],'invalid-shortcuts':s=>s.preferences.shortcuts=['sales'],'unsafe-product':s=>{s.sales[0].lines[0].quantity=1000000000;s.sales[0].lines[0].price=1000000000000;},'decimal-four-places':s=>s.products[0].minStock='1.0001','quantity-exponent-string':s=>s.products[0].minStock='1e2',
 'numeric-exponent-value':s=>s.products[0].minStock=1e2,'negative-zero':s=>s.products[0].price=-0,'unicode-identifier':s=>s.products[0].id='١','unknown-keys':s=>{s.unknown='ignored';s.products[0].unknown=true;},'nullable-remaining':s=>s.days[date].remaining=null,
};
for(const [name,mutate] of Object.entries(mutations)){const s=clone(base);mutate(s);add(name,s);}
let seed=0x02002610;
const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed;};
for(let n=0;n<180;n++) {const s=clone(base);s.products[0].price=random()%1000000;s.products[0].minStock=(random()%100000)/1000;s.days[date].balance=(random()%200000)-100000;s.preferences.restaurant.footer=`seed-02002610-${n}`; if(n%5===0)s.days[date].expenses[0].funding.dailyAmount++;add(`seed-02002610-${n}`,s);}
const output={format:1,provenance:{source:'electron-reference/app/ui/model.js',sha256:crypto.createHash('sha256').update(fs.readFileSync(source)).digest('hex'),node:process.version,timezone:process.env.TZ||Intl.DateTimeFormat().resolvedOptions().timeZone,seed:'0x02002610',synthetic:true,releasedArtifactClaim:false},cases};
const file=path.join(root,'test/fixtures/accounts/oracle.json'); const body=JSON.stringify(output,null,2)+'\n';
if(process.argv.includes('--check')) {const saved=JSON.parse(fs.readFileSync(file,'utf8'));if(saved.provenance.sha256!==output.provenance.sha256||JSON.stringify(saved.cases)!==JSON.stringify(output.cases))throw Error('Corpus differs; inspect source changes before regeneration.');} else fs.writeFileSync(file,body);
console.log(JSON.stringify({cases:cases.length,accepted:cases.filter(x=>x.accepted).length,rejected:cases.filter(x=>!x.accepted).length,sha256:output.provenance.sha256}));
