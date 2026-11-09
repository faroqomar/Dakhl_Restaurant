// Synthetic, non-UI execution of frozen public model and exact handler extracts.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../../..');
const M = require(path.join(root, 'electron-reference/app/ui/model.js'));
const renderer = fs.readFileSync(path.join(root, 'electron-reference/app/ui/renderer.js'), 'utf8');
const suppliers = fs.readFileSync(path.join(root, 'electron-reference/app/ui/suppliers.js'), 'utf8');
const ux = fs.readFileSync(path.join(root, 'electron-reference/app/ui/ux.js'), 'utf8');
const D0 = '2026-11-02', D1 = '2026-11-03', T0 = '2026-11-02T10:00:00.000Z';
const checks = [];
function check(name, fn) { fn(); checks.push(name); }
function reject(fn) { assert.throws(fn); }
function expenseState() {
  const s = M.empty();
  s.days[D0] = { ...M.day(s, D0), expenses: [{ id: 'expense-01', categoryId: 'market', amount: 30000, note: 'original', createdAt: T0, funding: { source: 'shared', dailyAmount: 20000, cashAmount: 10000 } }] };
  return M.validate(s);
}
function partyState() {
  const s = M.empty();
  s.suppliers = [{ id: 'supplier-01', name: 'Synthetic supplier', phone: '', note: '', categoryId: 'market', openingBalance: 7500, materials: [{ id: 'material-01', name: 'Synthetic material', unit: 'piece', price: 12500, archived: false }] }];
  s.invoices = [{ id: 'invoice-01', supplierId: 'supplier-01', number: 'SYN-01', date: D0, createdAt: T0, note: '', lines: [{ materialId: 'material-01', name: 'Synthetic material', unit: 'piece', quantity: 1, price: 12500 }] }];
  s.payments = [{ id: 'payment-01', supplierId: 'supplier-01', invoiceId: 'invoice-01', categoryId: 'market', date: D0, amount: 20000, invoiceAmount: 12500, debtAmount: 7500, funding: { source: 'shared', dailyAmount: 15000, cashAmount: 5000 }, note: 'original', createdAt: T0 }];
  return M.validate(s);
}
const editExpenseBody = renderer.split("} else if (context.kind === 'expense') {")[1].split("} else if (['deposit'")[0];
function editExpense(state, date = D0, amount = 32000, dailyAmount = 22000) {
  const next = structuredClone(state), context = { id: 'expense-01', originalDate: D0 };
  const values = new Map(Object.entries({ date, category: 'market', amount, paymentSource: 'shared', dailyAmount, cashAmount: 10000, note: ' replacement ' }));
  vm.runInNewContext(`(function(){${editExpenseBody}})()`, { M, next, context, values, crypto: require('node:crypto'), dExpense: (date,id) => M.day(state,date).expenses.find(e=>e.id===id), editableDay: (s,d) => s.days[d] || (s.days[d] = structuredClone(M.day(s,d))) });
  return M.validate(next);
}
const paymentBody = suppliers.split("  const old = next.payments.find(p => p.id === context.id), amount = M.numeric(values.get('amount'), { positive: true });")[1].split('\n}')[0];
assert(paymentBody && paymentBody.includes('M.splitPayment'));
function editPayment(state, date = D0) {
  const next = structuredClone(state), context = { id: 'payment-01' };
  const values = new Map(Object.entries({ date, amount: 18000, supplierId: 'supplier-01', invoiceId: 'invoice-01', categoryId: 'market', note: 'replacement' }));
  const code = `const old=next.payments.find(p=>p.id===context.id),amount=M.numeric(values.get('amount'),{positive:true});${paymentBody}`;
  vm.runInNewContext(`(function(){${code}})()`, { M, next, context, values, now: T0, crypto: require('node:crypto'), readPaymentFunding: () => M.allocation(18000, { source: 'shared', dailyAmount: 13000, cashAmount: 5000 }) });
  return M.validate(next);
}
function withSale(s, date = D0) {
  s.products = [{ id:'product-01',name:'Synthetic product',code:'',unit:'piece',price:1000,group:'',minStock:0,trackStock:false,archived:false }];
  return M.completeSale(M.validate(s), { date, discount:0, lines:[{productId:'product-01',quantity:1}] }, 'sale-01', T0);
}
async function main() {
  check('expense exact-handler edit retains ID/timestamp, trims note, changes funding once', () => {
    const before=expenseState(), after=editExpense(before), row=after.days[D0].expenses[0];
    assert.equal(row.id,'expense-01'); assert.equal(row.createdAt,T0); assert.equal(row.note,'replacement');
    assert.equal(M.dailySpent(after,D0)-M.dailySpent(before,D0),2000); assert.equal(M.cash(after)-M.cash(before),0);
  });
  check('expense exact-handler date edit removes old row and appends same ID on target date', () => {
    const s=editExpense(expenseState(),D1); assert.equal(s.days[D0].expenses.length,0); assert.equal(s.days[D1].expenses[0].id,'expense-01');
  });
  check('expense exact-handler mismatched funding is rejected', () => reject(()=>editExpense(expenseState(),D0,32000,21000)));
  check('payment exact-handler edit excludes old payment from split and retains identity', () => {
    const s=editPayment(partyState()), p=s.payments[0];
    assert.equal(p.id,'payment-01'); assert.equal(p.createdAt,T0); assert.equal(p.invoiceAmount,12500); assert.equal(p.debtAmount,5500);
    assert.equal(M.supplierBalance(s,'supplier-01'),2000); assert.equal(M.dailySpent(s,D0),13000); assert.equal(M.cash(s),-5000);
  });
  check('payment edit preceding linked invoice is rejected', () => reject(()=>editPayment(partyState(),'2026-11-01')));
  check('payment deletion projection restores invoice/debt allocations and funding exactly once', () => {
    const s=partyState(), next=structuredClone(s); next.payments=next.payments.filter(p=>p.id!=='payment-01');
    const after=M.validate(next); assert.equal(M.invoiceDue(after,'invoice-01'),12500); assert.equal(M.supplierBalance(after,'supplier-01'),20000);
    assert.equal(M.openingDue(after,'supplier-01'),7500); assert.equal(M.dailySpent(after,D0),0); assert.equal(M.cash(after),0);
  });
  check('reducing a paid invoice below its saved payment is rejected by frozen validation', () => {
    const s=partyState(); s.invoices[0].lines[0].price=12000; reject(()=>M.validate(s));
  });
  check('day shift moves expense/payment/transfer but preserves invoice/debt/sale dates and remaining', () => {
    let s=partyState(); s.days[D0]={...M.day(s,D0),expenses:expenseState().days[D0].expenses,corrections:[{field:'balance',date:D0,before:null,after:80000,reason:'synthetic',createdAt:T0}]};
    s=withSale(s); M.recordRemaining(s,D0,50000); s.transfers=[{id:'transfer-01',date:D0,amount:10000,createdAt:T0}]; s=M.validate(s);
    const before=M.remaining(s,D0), after=M.correctDayDates(s,D0,D1);
    assert.equal(before,40000); assert.equal(M.remaining(after,D1),before); assert.equal(after.days[D1].remaining.salesTotal,0);
    assert.equal(after.payments[0].date,D1); assert.equal(after.transfers[0].date,D1); assert.equal(after.invoices[0].date,D0); assert.equal(after.sales[0].date,D0);
    assert.equal(after.days[D1].corrections[0].date,D0); assert.equal(after.days[D1].balance,s.days[D0].balance);
  });
  check('day shift collision and payment-before-invoice target are rejected atomically', () => {
    const s=partyState(); s.days[D1]={...M.day(s,D1),balance:1}; reject(()=>M.correctDayDates(s,D0,D1)); reject(()=>M.correctDayDates(partyState(),D0,'2026-11-01'));
  });
  check('adjacent range day shift preserves both day objects instead of overwriting', () => {
    const s=expenseState(); s.days[D0].balance=11; s.days[D1]={...M.day(s,D1),balance:22};
    const after=M.correctDayDates(s,D0,D1,D1); assert.equal(after.days[D1].balance,11); assert.equal(after.days['2026-11-04'].balance,22);
  });
  // Exact source functions; DOM, persistence and confirmation are bounded synthetic adapters.
  const commit=renderer.slice(renderer.indexOf('async function commit('),renderer.indexOf('\nfunction editableDay('));
  const undo=renderer.slice(renderer.indexOf('async function undo()'),renderer.indexOf('\nasync function backup('));
  const trail=ux.slice(ux.indexOf('function preserveCorrectionTrail('),ux.indexOf('\nfunction replaceRecord('));
  const deletion=renderer.split('\n').find(l=>l.includes("action === 'confirm-delete'") && l.includes('structuredClone(state)')).replace(/^\s*else /,'');
  const noop=()=>{};
  const ctx={M,state:expenseState(),history:[],busy:false,drawer:null,retrySave:null,settingsBaseline:'',lastSaleId:null,structuredClone,JSON,Date,allowLeave:()=>true,closeDrawer:noop,openDrawer:(...args)=>ctx.opened=args,status:noop,render:noop,toast:noop,formError:noop,formSignature:()=>'',host:{querySelector:()=>null},main:{querySelector:()=>null},document:{body:{classList:{add:noop,remove:noop}},querySelector:()=>true,activeElement:null},window:{daftar:{save:async clean=>({ok:!ctx.failSave,error:'synthetic write failure',data:clean})}},editableDay:(s,d)=>s.days[d]||(s.days[d]=structuredClone(M.day(s,d)))};
  vm.createContext(ctx); vm.runInContext(`${commit}\n${trail}\n${undo}`,ctx);
  assert.equal(await ctx.commit(editExpense(ctx.state),'edit'),true); assert.equal(ctx.history.length,1);
  ctx.failSave=true; await ctx.undo(); assert.equal(ctx.history.length,1); assert.equal(ctx.state.days[D0].expenses[0].amount,32000); assert(ctx.retrySave);
  ctx.failSave=false; await ctx.undo(); assert.equal(ctx.history.length,0); assert.equal(ctx.state.days[D0].expenses[0].amount,30000); checks.push('actual commit/undo keeps state/history on failed save and pops only on confirmed success');
  ctx.drawer={kind:'expense',id:'expense-01',originalDate:D0};ctx.action='confirm-delete';
  await vm.runInContext(`(async function(){${deletion}})()`,ctx); assert.equal(ctx.state.days[D0].expenses.length,0); await ctx.undo(); assert.equal(ctx.state.days[D0].expenses[0].id,'expense-01'); checks.push('actual expense-delete handler removes current row; session undo restores it');
  ctx.drawer=null;
  for(let i=0;i<31;i++) await ctx.commit(structuredClone(ctx.state),'');
  assert.equal(ctx.history.length,30); checks.push('actual commit caps session undo stack at 30 snapshots');
  const old=M.empty(); old.days[D0]={...M.day(old,D0),balance:80};
  ctx.state=structuredClone(old);ctx.state.days[D0].balance=100;ctx.state.days[D0].corrections=[{field:'balance',date:D0,before:80,after:100,reason:'original reason',createdAt:T0}];ctx.history=[old];
  await ctx.undo(); assert.equal(ctx.state.days[D0].balance,80); assert.equal(ctx.state.days[D0].corrections.length,2); assert.equal(ctx.state.days[D0].corrections[1].before,100); assert.equal(ctx.state.days[D0].corrections[1].after,80); checks.push('actual undo preserves manual correction trail and appends compensating source-history event');
  ctx.state=M.empty();ctx.history=[M.empty()]; const sale=withSale(M.empty()); await ctx.commit(sale,''); assert.equal(ctx.history.length,0);ctx.lastSaleId='sale-01';await ctx.undo();assert.equal(ctx.opened[0],'sale-void');checks.push('actual sales commit clears generic undo; empty-stack undo opens eligible sale void');
  const receipt={scope:'synthetic frozen source only; no browser, filesystem store or runtime activation',checksPassed:checks.length,checks,limits:['DOM/save adapters are synthetic; no OS/process crash or file-write proof','Payment deletion probe applies the handler source filter and actual model validation, not supplier UI event execution','No durable expense/payment/date-shift/session-undo implementation is claimed']};
  fs.writeFileSync(path.join(__dirname,'source-probe-result.json'),JSON.stringify(receipt,null,2)+'\n');
  console.log(JSON.stringify({checksPassed:checks.length,receipt:'source-probe-result.json'}));
}
main().catch(e=>{console.error(e.stack);process.exitCode=1;});
