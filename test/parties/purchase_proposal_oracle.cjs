const fs=require('fs'),vm=require('vm'),crypto=require('crypto'),M=require('../../electron-reference/app/ui/model.js');
const source=fs.readFileSync('electron-reference/app/ui/suppliers.js','utf8');
const read=source.slice(source.indexOf('function readInvoiceLines('),source.indexOf('function refreshInvoice()'));
const submit=source.slice(source.indexOf('function supplierSubmit('),source.indexOf('function supplierAction('));
const base=M.empty();base.suppliers=[{id:'s',name:'Supplier',phone:'',note:'',categoryId:'market',openingBalance:100,materials:[]}];
const baseline=M.validate(base);
const cases=[{name:'inline invoice and split immediate payment',context:{kind:'invoice',supplierId:'s',createdAt:'2026-01-01T12:00:00.000Z'},values:{'invoice-number':'١','date':'2026-01-01','note':' x ','amount':'250',paymentSource:'shared',dailyAmount:'150',cashAmount:'100'},lines:[{name:'Rice',unit:'kg',cartons:'0',pieces:'2',cartonPrice:'0',piecePrice:'100'}],ids:['invoice','material','payment']}];
cases.push({name:"debt-only cash payment",context:{kind:"payment"},values:{supplierId:"s",invoiceId:"",categoryId:"market",date:"2026-01-01",amount:"30",paymentSource:"cash",note:" paid "},lines:[],ids:["debt-payment"]});

function run(c){const next=structuredClone(c.baseline||baseline),ids=[...c.ids];const context={M,N:{latin:v=>String(v).replace(/[٠-٩]/g,d=>'٠١٢٣٤٥٦٧٨٩'.indexOf(d)).replace(/[۰-۹]/g,d=>'۰۱۲۳۴۵۶۷۸۹'.indexOf(d))},crypto:{randomUUID:()=>ids.shift()},Date:class extends Date{constructor(){super('2026-01-01T12:00:00.000Z')}},state:next,drawer:c.context};vm.createContext(context);vm.runInContext(read+submit,context);const fields={'.line-name-input':'name','.line-unit':'unit','.line-cartons':'cartons','.line-pieces':'pieces','.line-carton-price':'cartonPrice','.line-piece-price':'piecePrice'};const form={querySelectorAll:()=>c.lines.map(line=>({querySelector:selector=>({value:line[fields[selector]]})}))};try {context.supplierSubmit(next,c.context,new Map(Object.entries(c.values)),form);c.expected=M.validate(next);} catch(error) { c.rejected=true; c.error=error.message; }}
for(const c of cases)run(c);
const paid=structuredClone(cases[0].expected);
paid.suppliers.push({id:'s2',name:'Other',phone:'',note:'',categoryId:'market',openingBalance:1000,materials:[]});
const invoice=paid.invoices[0];
paid.invoices=[{...invoice,id:'before',number:'before'},invoice,{...invoice,id:'after',number:'after'}];
paid.payments=[{...paid.payments[0],id:'p-before',invoiceId:null,amount:5,invoiceAmount:0,debtAmount:5,funding:{source:'daily',dailyAmount:5,cashAmount:0}},paid.payments[0],{...paid.payments[0],id:'p-after',invoiceId:null,amount:5,invoiceAmount:0,debtAmount:5,funding:{source:'daily',dailyAmount:5,cashAmount:0}}];
const editBase=M.validate(paid);
const editInvoice={name:'edit middle invoice preserves snapshots and appends',baseline:editBase,context:{kind:'invoice',id:'invoice',supplierId:'s',createdAt:invoice.createdAt},values:{'invoice-number':'1',date:invoice.date,note:' edited ',amount:'0'},lines:[{name:'Rice',unit:'bag',cartons:'0',pieces:'3',cartonPrice:'0',piecePrice:'100'}],ids:[]};
const editPayment={name:'edit middle payment reallocates and appends',baseline:editBase,context:{kind:'payment',id:'payment'},values:{supplierId:'s',invoiceId:'invoice',categoryId:'market',date:'2026-01-01',amount:'210',paymentSource:'daily',note:' edited '},lines:[],ids:[]};
const changeSupplier={...editPayment,name:'edit payment changes supplier to eligible debt',values:{...editPayment.values,supplierId:'s2',invoiceId:'',amount:'300'}};
const reduced={...editInvoice,name:'reject reducing paid invoice below allocated payment',lines:[{...editInvoice.lines[0],pieces:'1',piecePrice:'1'}]};
const changedInvoiceSupplier={...editInvoice,name:'reject paid invoice supplier change',context:{...editInvoice.context,supplierId:'s2'}};
const materialBase=structuredClone(baseline);materialBase.materials=[{id:'archived',name:'Rice',unit:'old',priceCarton:123,pricePiece:456,archived:true}];
const shared={...cases[0],name:'multiple lines reuse new and archived materials',baseline:M.validate(materialBase),values:{...cases[0].values,amount:'0'},lines:[{name:'Rice',unit:'new',cartons:'0',pieces:'1',cartonPrice:'0',piecePrice:'9'},{name:'Tea',unit:'bag',cartons:'0',pieces:'1',cartonPrice:'0',piecePrice:'10'},{name:'TEA',unit:'box',cartons:'1',pieces:'0',cartonPrice:'20',piecePrice:'0'}],ids:['new-invoice','new-material']};
for(const c of [editInvoice,editPayment,changeSupplier,reduced,changedInvoiceSupplier,shared]){delete c.expected;run(c);cases.push(c);}
console.log(JSON.stringify({baseline,cases,runtime:process.versions,sourceSha256:crypto.createHash('sha256').update(source).digest('hex')}));
