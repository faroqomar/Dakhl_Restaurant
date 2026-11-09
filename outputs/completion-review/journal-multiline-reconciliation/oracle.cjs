'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const source = path.resolve('electron-reference/app/ui/model.js');
const M = require(source);
const date = n => `2026-02-${String(n).padStart(2,'0')}`;
const stamp = n => `${date(n)}T12:00:00.000Z`;
let state=M.validate({...M.empty(),products:[
 {id:'a',name:'Item A',code:'A',unit:'piece',price:1001,group:'food',minStock:0,trackStock:true,archived:false},
 {id:'b',name:'Item B',code:'B',unit:'piece',price:799,group:'food',minStock:0,trackStock:true,archived:false}
],stockEntries:[
 {id:'open-a',productId:'a',date:date(1),quantity:10,kind:'opening',note:'Synthetic opening',createdAt:stamp(1)},
 {id:'open-b',productId:'b',date:date(1),quantity:8,kind:'opening',note:'Synthetic opening',createdAt:stamp(1)}
],transactions:[{id:'cashbox-opening',date:date(1),type:'deposit',amount:20000,note:'Synthetic opening',createdAt:stamp(1)}],suppliers:[{id:'s',name:'Supplier S',phone:'',note:'',categoryId:'samoon',openingBalance:500}]});
const seed=structuredClone(state);
state=M.completeSale(state,{date:date(2),discount:101,note:'Multi-line discounted',lines:[{productId:'a',quantity:2.5},{productId:'b',quantity:1.75}]},'shared',stamp(2));
const refundProof=[];
function refund(id,day,lines){const quote=M.returnQuote(state,'shared',lines);refundProof.push({id,date:date(day),...quote});state=M.returnSale(state,'shared',{date:date(day),reason:'Staged refund',lines},id,stamp(day));}
refund('r1',3,[{productId:'a',quantity:.75,restock:true},{productId:'b',quantity:.5,restock:false}]);
state=M.completeSale(state,{date:date(3),discount:1,note:'Void later',lines:[{productId:'a',quantity:.4},{productId:'b',quantity:.125}]},'void-sale',stamp(3));
refund('r2',4,[{productId:'a',quantity:.5,restock:false},{productId:'b',quantity:.25,restock:true}]);
refund('r3',5,[{productId:'a',quantity:1.25,restock:true},{productId:'b',quantity:1,restock:true}]);
state=M.voidSale(state,'void-sale','Original-date correction',stamp(6));
state=M.completeSale(state,{date:date(6),discount:0,note:'Retained sale',lines:[{productId:'a',quantity:.125},{productId:'b',quantity:.25}]},'kept',stamp(6));
state=M.validate({...state,days:{...state.days,[date(4)]:{expenses:[{id:'shared',categoryId:'samoon',amount:90,note:'Mixed expense',funding:{source:'shared',dailyAmount:60,cashAmount:30},createdAt:stamp(4)}],chickenUsed:0,chickenLeft:0,totalOverride:null,balance:null,remaining:null,corrections:[]}}});
state=M.validate({...state,materials:[{id:'m',name:'Flour',unit:'bag',priceCarton:2000,pricePiece:400,archived:false}],invoices:[{id:'shared',supplierId:'s',number:'ML-1',date:date(5),createdAt:stamp(5),note:'Mixed purchase',lines:[{materialId:'m',name:'Flour',unit:'bag',quantityCartons:.5,quantityPieces:1.25,priceCarton:2000,pricePiece:400}]}]});
function payment(id,amount,day,dailyAmount,cashAmount,note){const split=M.splitPayment(state,'s','shared',amount,date(day));state=M.validate({...state,payments:[...state.payments,{id,supplierId:'s',invoiceId:'shared',categoryId:'samoon',date:date(day),amount,...split,funding:{source:'shared',dailyAmount,cashAmount},note,createdAt:stamp(day)}]});}
// Frozen suppliers.js immediate invoice payment deliberately saves an empty note.
payment('initial',600,5,400,200,'');
payment('shared',1000,6,700,300,'Settle invoice and opening');
const sourceRecords={};for(const key of Object.keys(state))sourceRecords[key]=state[key];
const result={sourceSha256:crypto.createHash('sha256').update(fs.readFileSync(source)).digest('hex'),runtime:process.versions,seed,refundProof,sourceRecords,dated:Array.from({length:6},(_,i)=>({day:i+1,netSales:M.salesTotal(state,date(i+1)),stockA:M.stock(state,'a',date(i+1)),stockB:M.stock(state,'b',date(i+1))})),invoiceTotal:M.invoiceTotal(state.invoices[0]),supplierBalance:M.supplierBalance(state,'s'),cashbox:M.cash(state)};
fs.writeFileSync(path.join(__dirname,'oracle.json'),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({refundProof,dated:result.dated,invoiceTotal:result.invoiceTotal,supplierBalance:result.supplierBalance,cashbox:result.cashbox}));
