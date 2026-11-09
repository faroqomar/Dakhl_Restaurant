'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const root = path.resolve(__dirname, '../../..');
const source = path.join(root, 'electron-reference/app/ui/model.js');
const M = require(source);

const rendererSource = path.join(root, 'electron-reference/app/ui/renderer.js');
const rendererBytes = fs.readFileSync(rendererSource);
const rendererText = rendererBytes.toString('utf8');
const handlerMatch = rendererText.match(/else if \(action === 'confirm-delete'\) \{ ([^\n]+) \}/);
if (!handlerMatch) throw Error('Frozen confirm-delete handler not found');
const handlerBody = handlerMatch[1];
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const actualDeleteHandler = new AsyncFunction('state', 'drawer', 'commit', 'closeDrawer', 'editableDay', handlerBody);
async function deleteTransfer(state, id) {
  let committed, closed = false;
  await actualDeleteHandler(state, {kind: 'transfer', id}, async next => {
    committed = next; return true;
  }, () => { closed = true; }, () => { throw Error('Unexpected expense branch'); });
  if (!committed || !closed) throw Error('Delete handler did not commit and close');
  return committed;
}

async function main() {
const date = '2026-01-15';
const stamp = hour => `${date}T${hour}:00:00.000Z`;
const funding = amount => ({ source: 'daily', dailyAmount: amount, cashAmount: 0 });
const expense = (id, amount, hour) => ({
  id,
  categoryId: 'samoon',
  amount,
  note: '',
  funding: funding(amount),
  createdAt: stamp(hour)
});
const transfer = (id, amount, hour) => ({
  id,
  date,
  amount,
  createdAt: stamp(hour)
});

function seed(overrides = {}) {
  const {
    balance = 100000,
    remaining = { amount: 100000, dailySpent: 0, transferred: 0, salesTotal: 0 },
    expenses = [],
    products = [],
    transfers = []
  } = overrides;
  return M.validate({
    ...M.empty(),
    products,
    transfers,
    days: {
      [date]: {
        expenses,
        chickenUsed: 0,
        chickenLeft: 0,
        balance,
        totalOverride: null,
        remaining
      }
    }
  });
}

function summary(state) {
  return {
    remaining: M.remaining(state, date),
    transferred: M.transferred(state, date),
    balance: M.day(state, date).balance,
    cash: M.cash(state),
    dailySpent: M.dailySpent(state, date),
    salesTotal: M.salesTotal(state, date)
  };
}

const scenarios = {};

// Scenario 1: 20k -> 30k -> delete
{
  const s0 = seed();
  const summary0 = summary(s0);

  // 1. Create transfer 20k
  const s1 = structuredClone(s0);
  M.transferRemaining(s1, date, 20000, 't1', stamp('10'));
  M.validate(s1);
  const summary1 = summary(s1);

  // 2. Edit transfer to 30k
  const s2 = structuredClone(s1);
  M.transferRemaining(s2, date, 30000, 't1', stamp('10'), 't1');
  M.validate(s2);
  const summary2 = summary(s2);

  // 3. Delete transfer (parity with renderer.js confirm-delete handler)
  const s3 = await deleteTransfer(s2, 't1');
  M.validate(s3);
  const summary3 = summary(s3);

  scenarios['1'] = {
    seed: s0,
    summary0,
    afterCreate: { account: s1, summary: summary1 },
    afterEdit: { account: s2, summary: summary2 },
    afterDelete: { account: s3, summary: summary3 }
  };
}

// Scenario 2: Repeated edits (20k -> 40k -> 25k -> 50k)
{
  const s0 = seed();
  const summary0 = summary(s0);

  // Create 20k
  const s1 = structuredClone(s0);
  M.transferRemaining(s1, date, 20000, 't2', stamp('10'));
  M.validate(s1);
  const summary1 = summary(s1);

  // Edit to 40k
  const s2 = structuredClone(s1);
  M.transferRemaining(s2, date, 40000, 't2', stamp('10'), 't2');
  M.validate(s2);
  const summary2 = summary(s2);

  // Edit to 25k
  const s3 = structuredClone(s2);
  M.transferRemaining(s3, date, 25000, 't2', stamp('10'), 't2');
  M.validate(s3);
  const summary3 = summary(s3);

  // Edit to 50k
  const s4 = structuredClone(s3);
  M.transferRemaining(s4, date, 50000, 't2', stamp('10'), 't2');
  M.validate(s4);
  const summary4 = summary(s4);

  scenarios['2'] = {
    seed: s0,
    summary0,
    afterCreate: { account: s1, summary: summary1 },
    afterEdit1: { account: s2, summary: summary2 },
    afterEdit2: { account: s3, summary: summary3 },
    afterEdit3: { account: s4, summary: summary4 }
  };
}

// Scenario 3: Legacy unset-total recovery (balance: null -> edit -> balance recovered -> delete -> balance preserved)
{
  const s0 = seed({
    balance: null,
    remaining: { amount: 100000, dailySpent: 20000, transferred: 5000, salesTotal: 0 },
    expenses: [expense('e1', 20000, '09')],
    transfers: [transfer('t0', 5000, '08')]
  });
  const summary0 = summary(s0);

  // Edit transfer t0 to 15,000
  const s1 = structuredClone(s0);
  M.transferRemaining(s1, date, 15000, 't0', stamp('08'), 't0');
  M.validate(s1);
  const summary1 = summary(s1);

  // Delete transfer t0
  const s2 = await deleteTransfer(s1, 't0');
  M.validate(s2);
  const summary2 = summary(s2);

  scenarios['3'] = {
    seed: s0,
    summary0,
    afterEdit: { account: s1, summary: summary1 },
    afterDelete: { account: s2, summary: summary2 }
  };
}

// Scenario 4: Intervening sales, refunds, expenses between create, edit, and delete
{
  const prod = {
    id: 'prod-1',
    name: 'Kebab',
    code: '',
    group: '',
    unit: 'plate',
    price: 10000,
    minStock: 0,
    trackStock: false,
    archived: false
  };
  const s0 = seed({ products: [prod] });
  const summary0 = summary(s0);

  // 1. Create transfer 20k
  const s1 = structuredClone(s0);
  M.transferRemaining(s1, date, 20000, 't4', stamp('10'));
  M.validate(s1);
  const summary1 = summary(s1);

  // 2. Intervening sale of 10,000
  let s2 = structuredClone(s1);
  s2 = M.completeSale(
    s2,
    { date, lines: [{ productId: 'prod-1', quantity: 1 }], discount: 0, orderType: 'صالة' },
    'sale-1',
    stamp('11')
  );
  M.validate(s2);
  const summary2 = summary(s2);

  // 3. Intervening expense of 5,000
  const s3 = structuredClone(s2);
  s3.days[date].expenses.push(expense('exp-1', 5000, '12'));
  M.validate(s3);
  const summary3 = summary(s3);

  // 4. Intervening refund of 10,000
  let s4 = structuredClone(s3);
  s4 = M.returnSale(
    s4,
    'sale-1',
    { date, reason: 'customer return', lines: [{ productId: 'prod-1', quantity: 1, restock: false }] },
    'ret-1',
    stamp('13')
  );
  M.validate(s4);
  const summary4 = summary(s4);

  // 5. Edit transfer to 35,000
  // Available remaining before edit: 100000 - 20000 + 10000 - 5000 - 10000 = 75000
  // Max allowed: 75000 + 20000 = 95000. 35000 <= 95000.
  const s5 = structuredClone(s4);
  M.transferRemaining(s5, date, 35000, 't4', stamp('10'), 't4');
  M.validate(s5);
  const summary5 = summary(s5);

  // 6. Delete transfer
  const s6 = await deleteTransfer(s5, 't4');
  M.validate(s6);
  const summary6 = summary(s6);

  scenarios['4'] = {
    seed: s0,
    summary0,
    afterCreate: { account: s1, summary: summary1 },
    afterSale: { account: s2, summary: summary2 },
    afterExpense: { account: s3, summary: summary3 },
    afterRefund: { account: s4, summary: summary4 },
    afterEdit: { account: s5, summary: summary5 },
    afterDelete: { account: s6, summary: summary6 }
  };
}

const outputPath = path.join(__dirname, 'oracle-repaired-1.json');
const selfContent = fs.readFileSync(__filename);
const sourceContent = fs.readFileSync(source);

const result = {
  sourcePath: path.relative(root, source),
  rendererPath: path.relative(root, rendererSource),
  rendererSha256: crypto.createHash('sha256').update(rendererBytes).digest('hex'),
  deleteHandlerSha256: crypto.createHash('sha256').update(handlerBody).digest('hex'),
  deleteHandlerMode: 'actual frozen confirm-delete body; transfer branch; synthetic commit/close callbacks',

  sourceSha256: crypto.createHash('sha256').update(sourceContent).digest('hex'),
  generatorSha256: crypto.createHash('sha256').update(selfContent).digest('hex'),
  runtime: process.versions,
  scenarios
};

fs.writeFileSync(outputPath, JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify({
  sourceSha256: result.sourceSha256,
  generatorSha256: result.generatorSha256,
  runtime: { electron: process.versions.electron, node: process.versions.node },
  scenariosCount: Object.keys(scenarios).length
}));

}
main().catch(error => { console.error(error); process.exitCode = 1; });
