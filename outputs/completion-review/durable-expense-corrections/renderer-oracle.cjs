'use strict';
// Synthetic differential harness. Execute the frozen renderer branch bodies;
// callback substitutes capture persistence/UI boundaries, not financial rules.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../../..');
const modelPath = path.join(root, 'electron-reference/app/ui/model.js');
const rendererPath = path.join(root, 'electron-reference/app/ui/renderer.js');
const M = require(modelPath);
const renderer = fs.readFileSync(rendererPath, 'utf8');
function blockAfter(anchor) {
  const start = renderer.indexOf(anchor);
  if (start < 0 || renderer.indexOf(anchor, start + 1) >= 0) throw Error('ambiguous frozen anchor');
  const brace = start + anchor.length - 1;
  if (renderer[brace] !== '{') throw Error('anchor must end at body');
  let depth = 1, quote = null, escaped = false;
  for (let i = brace + 1; i < renderer.length; i++) {
    const c = renderer[i];
    if (quote) {
      if (escaped) escaped = false;
      else if (c === '\\') escaped = true;
      else if (c === quote) quote = null;
    } else if (c === "'" || c === '"' || c === '`') quote = c;
    else if (c === '{') depth++;
    else if (c === '}' && --depth === 0) return { body: renderer.slice(brace + 1, i), start, end: i + 1 };
  }
  throw Error('unterminated frozen body');
}
const edit = blockAfter("else if (context.kind === 'expense') {");
const deletion = blockAfter("else if (action === 'confirm-delete') {");
const dayHelper = blockAfter('function editableDay(next, key) {');
const sourceHelper = blockAfter('function dExpense(date, id) {');
const runEdit = new Function('state', 'context', 'values', 'M', `
  let message;
  const next = structuredClone(state);
  function editableDay(next,key) {${dayHelper.body}}
  function dExpense(date,id) {${sourceHelper.body}}
  function addCategory() { throw Error('inline category creation outside isolated correction scope'); }
  ${edit.body}
  return M.validate(next);
`);
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const runDelete = new AsyncFunction('state','drawer','M', `
  let saved;
  function editableDay(next,key) {${dayHelper.body}}
  async function commit(next) { saved=M.validate(next); return true; }
  function closeDrawer() {}
  ${deletion.body}
  if (!saved) throw Error('renderer delete did not commit');
  return saved;
`);
const digest = value => crypto.createHash('sha256').update(value).digest('hex');
function summary(state) {
  return {cash:M.cash(state), days:Object.fromEntries(Object.keys(state.days).map(date=>[date,{dailySpent:M.dailySpent(state,date),total:M.total(state,date),remaining:M.remaining(state,date),balance:M.day(state,date).balance}]))};
}
(async () => {
  const request=JSON.parse(fs.readFileSync(0,'utf8'));
  let state=M.validate(request.state);
  const results=[];
  for(const action of request.actions) {
    if(action.type==='edit') {
      const values=new Map(Object.entries(action.values));
      const context={kind:'expense',id:action.id,originalDate:action.originalDate};
      state=runEdit(state,context,values,M);
    } else if(action.type==='delete') state=await runDelete(state,{kind:'expense',id:action.id,originalDate:action.originalDate},M);
    else throw Error('unknown action');
    results.push({account:state,summary:summary(state)});
  }
  process.stdout.write(JSON.stringify({source:{modelSha256:digest(fs.readFileSync(modelPath)),rendererSha256:digest(renderer),editBodySha256:digest(edit.body),deleteBodySha256:digest(deletion.body),editSpan:[edit.start,edit.end],deleteSpan:[deletion.start,deletion.end]},results}));
})().catch(error=>{process.stderr.write(String(error));process.exitCode=1;});
