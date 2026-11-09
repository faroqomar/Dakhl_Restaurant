// Frozen-source oracle; synthetic catalog only. Run from repository root.
const fs = require('node:fs');
const vm = require('node:vm');
const crypto = require('node:crypto');
const commerce = fs.readFileSync('electron-reference/app/ui/commerce.js', 'utf8');
const ux = fs.readFileSync('electron-reference/app/ui/ux.js', 'utf8');
const inventoryMatches = ux.split('\n').find(line => line.startsWith('function inventoryMatches('));
const pageItems = ux.split('\n').find(line => line.startsWith('function pageItems('));
const salesFilter = commerce.split('\n').find(line => line.includes('const products = state.products.filter(p => !p.archived &&'));
const inventoryFilter = commerce.split('\n').find(line => line.includes('const products = state.products.filter(p => `${p.name} ${p.code} ${p.group}`'));
if (![inventoryMatches, pageItems, salesFilter, inventoryFilter].every(Boolean)) throw Error('Frozen-source selector changed');
const products = Array.from({length: 85}, (_, i) => ({id:`p${i}`,name:`صنف ${i}`,code:`SKU${i}`,group:i%2===0?'مشاوي':'مشروبات',unit:'قطعة',price:1000,minStock:1.5,trackStock:i!==3,archived:i===2}));
if (process.versions.unicode !== '17.0') throw Error('Oracle requires Unicode17 reference runtime');
for (const [id,name] of [['unicode-dot','İ'],['unicode-sigma','ΟΣ'],['unicode-cyrillic','\u1C89'],['unicode-latin','\uA7CB']]) products.push({id,name,code:'',group:'',unit:'piece',price:0,minStock:0,trackStock:false,archived:false});
const cases = [
 ...['sales','inventory'].flatMap(kind=>['i\u0307','ος','\u1C8A','\u0264'].map(query=>({kind,query,group:'',status:'active',page:1}))),
 {kind:'sales', query:'sKu1',group:'',page:1},
 {kind:'sales', query:'مشاوي',group:'',page:1},
 {kind:'sales', query:'',group:'',page:99},
 {kind:'inventory', query:'',group:'',status:'low',page:1},
 {kind:'inventory', query:'',group:'',status:'archived',page:1},
 {kind:'inventory', query:'',group:'مشروبات',status:'all',page:0},
 {kind:'inventory', query:'absent',group:'',status:'active',page:99},
];
for (const c of cases) {
 const context={state:{products},productSearch:c.query,productGroup:c.group,inventorySearch:c.query,inventoryFilter:{status:c.status,group:c.group},balances:new Map([['p0',1.5],['p1',2]]),pageNumbers:{oracle:c.page},pageCounts:{},pageSizes:{}};
 vm.createContext(context);
 const filter=c.kind==='sales'?salesFilter:inventoryFilter;
 vm.runInContext(`${inventoryMatches}\n${pageItems}\n${filter}\nresult={ids:pageItems(products,'oracle',${c.kind==='sales'?80:50}).map(p=>p.id),total:products.length,page:pageNumbers.oracle};`,context);
 c.expected=context.result;
}
fs.writeFileSync('test/catalog/oracle.json',JSON.stringify({runtime:process.versions,sourceHashes:{commerce:crypto.createHash('sha256').update(commerce).digest('hex'),ux:crypto.createHash('sha256').update(ux).digest('hex')},products,cases},null,2)+'\n');
