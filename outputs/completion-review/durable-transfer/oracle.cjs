'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../../..');
const source = path.join(root, 'electron-reference/app/ui/model.js');
const M = require(source);
const date = '2026-01-15';
const stamp = hour => `${date}T${hour}:00:00.000Z`;
const funding = amount => ({source:'daily',dailyAmount:amount,cashAmount:0});
const expense = (id,amount,hour) => ({id,categoryId:'samoon',amount,note:'',funding:funding(amount),createdAt:stamp(hour)});
const transfer = (id,amount,hour) => ({id,date,amount,createdAt:stamp(hour)});
function seed(overrides={}) {
 const {balance=100000,remaining={amount:100000,dailySpent:0,transferred:0,salesTotal:0},expenses=[],products=[],transfers=[]}=overrides;
 return M.validate({...M.empty(),products,transfers,days:{[date]:{expenses,chickenUsed:0,chickenLeft:0,balance,totalOverride:null,remaining}}});
}
function record(state,operation) {
 const before=structuredClone(state);
 state=operation(state)||state;
 state=M.validate(state);
 return {seed:before,account:state,summary:{remaining:M.remaining(state,date),transferred:M.transferred(state,date),balance:M.day(state,date).balance,cash:M.cash(state),dailySpent:M.dailySpent(state,date),salesTotal:M.salesTotal(state,date)}};
}
const scenarios={};
scenarios['1']=record(seed(),s=>{M.transferRemaining(s,date,20000,'t-sc1',stamp('12'));});
scenarios['2']=record(seed(),s=>{M.transferRemaining(s,date,100000,'t-sc2',stamp('12'));});
scenarios['3']=record(seed({balance:null,remaining:{amount:100000,dailySpent:20000,transferred:5000,salesTotal:0},expenses:[expense('e1',20000,'10')],transfers:[transfer('t0',5000,'09')]}),s=>{M.transferRemaining(s,date,30000,'t-sc3',stamp('12'));});
scenarios['4']=record(seed({products:[{id:'prod-1',name:'Kebab',code:'',group:'',unit:'plate',price:10000,minStock:0,trackStock:false,archived:false}],expenses:[expense('e1',20000,'10')],remaining:{amount:100000,dailySpent:20000,transferred:0,salesTotal:0}}),s=>{
 M.transferRemaining(s,date,20000,'t-sc4-1',stamp('11'));
 s=M.completeSale(s,{date,lines:[{productId:'prod-1',quantity:1}],discount:0,orderType:'صالة'},'sale-sc4-1',stamp('12'));
 s.days[date].expenses.push(expense('exp-sc4-2',5000,'13'));
 s=M.returnSale(s,'sale-sc4-1',{date,reason:'return',lines:[{productId:'prod-1',quantity:1,restock:false}]},'ret-sc4-1',stamp('14'));
 M.transferRemaining(s,date,15000,'t-sc4-2',stamp('15'));
 return s;
});
const result={sourcePath:path.relative(root,source),sourceSha256:crypto.createHash('sha256').update(fs.readFileSync(source)).digest('hex'),generatorSha256:crypto.createHash('sha256').update(fs.readFileSync(__filename)).digest('hex'),runtime:process.versions,scenarios};
fs.writeFileSync(path.join(__dirname,'oracle-repaired-1.json'),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({sourceSha256:result.sourceSha256,runtime:{electron:process.versions.electron,node:process.versions.node},scenarios:Object.fromEntries(Object.entries(scenarios).map(([id,s])=>[id,s.summary]))}));
