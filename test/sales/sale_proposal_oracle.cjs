const fs=require('node:fs'),crypto=require('node:crypto');
const path='electron-reference/app/ui/model.js',M=require('../../'+path);
const state=M.empty();
state.products=[{id:'p',name:'صنف',unit:'قطعة',price:1000,code:'',group:'',minStock:0,trackStock:true,archived:false}];
state.stockEntries=[{id:'opening',productId:'p',date:'2026-01-02',kind:'opening',quantity:5,note:'',createdAt:'2026-01-02T00:00:00Z'}];
const base=M.validate(state),draft={date:'2026-01-03',discount:100,lines:[{productId:'p',quantity:2}]};
const cases=[{name:'default',draft},{name:'override',draft:{...draft,paid:3000,note:'memo',lines:[{productId:'p',quantity:1.5,price:1500}]}},{name:'empty',draft:{...draft,lines:[]}},{name:'backdated',draft:{...draft,date:'2026-01-01'}},{name:'overstock',draft:{...draft,lines:[{productId:'p',quantity:6}]}},{name:'duplicate-line',draft:{...draft,lines:[{productId:'p',quantity:1},{productId:'p',quantity:1}]}},{name:'underpaid',draft:{...draft,paid:1}},{name:'bad-type',draft:{...draft,orderType:'missing'}}];
for(const c of cases){c.state=base;c.saleId='sale-new';c.createdAt='2026-01-03T12:00:00Z';try{c.expected=M.completeSale(c.state,c.draft,c.saleId,c.createdAt);c.ok=true}catch(e){c.ok=false}}
const duplicate={name:'duplicate-id',state:cases[0].expected,draft,saleId:'sale-new',createdAt:'2026-01-03T12:00:00Z',ok:false};cases.push(duplicate);
for(const number of ['S-9007199254740991','S-9007199254740992','S-9007199254740993','S-1000000000000000000000']) {
 const state=JSON.parse(JSON.stringify(cases[0].expected));state.sales[0].number=number;
 const c={name:'legacy-number-'+number,state:M.validate(state),draft:{...draft,lines:[{productId:'p',quantity:1}]},saleId:'next',createdAt:'2026-01-04T12:00:00Z'};
 try {c.expected=M.completeSale(c.state,c.draft,c.saleId,c.createdAt);c.ok=true;} catch(e){c.ok=false;}
 cases.push(c);
}
fs.writeFileSync('test/sales/sale_proposal_oracle.json',JSON.stringify({sourceSha256:crypto.createHash('sha256').update(fs.readFileSync(path)).digest('hex'),cases},null,2)+'\n');
