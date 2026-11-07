const M=require('../../electron-reference/app/ui/model.js');
let s=M.empty();s.products=[{id:'a',name:'A',code:'',group:'',unit:'plate',price:101,minStock:0,trackStock:false,archived:false},{id:'b',name:'B',code:'',group:'',unit:'plate',price:99,minStock:0,trackStock:true,archived:false}];
s.stockEntries=[{id:'open',productId:'b',date:'2026-01-01',quantity:10,kind:'opening',note:'',createdAt:'2026-01-01T12:00:00Z'}];
s=M.completeSale(s,{date:'2026-01-01',lines:[{productId:'a',quantity:3},{productId:'b',quantity:2}],discount:100,note:'',orderType:'صالة'},'sale','2026-01-01T12:00:00Z');
const cases=[];
for(const [id,lines] of [['r1',[{productId:'a',quantity:1,restock:false}]],['r2',[{productId:'a',quantity:2,restock:false},{productId:'b',quantity:2,restock:true}]]]){
 const request={date:'2026-01-02',reason:' synthetic return ',lines};const createdAt='2026-01-02T12:00:00Z';const candidate=M.returnSale(s,'sale',request,id,createdAt);cases.push({base:s,request,id,createdAt,candidate});s=candidate;
}
let zero=structuredClone(cases[0].base);zero.sales[0].discount=501;zero.sales[0].paid=0;zero=M.validate(zero);
const request={date:'2026-01-02',reason:'free sale return',lines:[{productId:'a',quantity:3,restock:false},{productId:'b',quantity:2,restock:true}]};
cases.push({base:zero,request,id:'zero',createdAt:'2026-01-02T12:00:00Z',candidate:M.returnSale(zero,'sale',request,'zero','2026-01-02T12:00:00Z')});
console.log(JSON.stringify({cases,net:M.saleTotal(s.sales[0]),refunded:M.saleRefundTotal(s,'sale')}));
