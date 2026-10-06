const { test } = require('node:test'), assert = require('node:assert/strict');
const { JSDOM } = require('jsdom'), fs = require('node:fs/promises'), os = require('node:os'), path = require('node:path');
const M = require('../app/ui/model.js'), { fixture } = require('./pdf-fixture.cjs');
const { createReport } = require('../app/reports/pdf.cjs'), { renderPDF, writePDF } = require('../app/reports/export.cjs');
function document(report) { return new JSDOM(report.html).window.document; }
test('daily PDF reflects manual totals, actual funding, remainder, chicken and historical cash without mutating accounts', () => {
  const s=fixture(),before=structuredClone(s),report=createReport(s,{kind:'daily',date:'2026-10-04'}),d=document(report),text=d.body.textContent;
  assert.match(text,/350,000/); assert.match(text,/335,250/); assert.match(text,/385,000/); assert.match(text,/693,750/); assert.doesNotMatch(text,/999,999/);
  assert.equal(d.querySelector('table tbody').children.length,M.expenses(s,'2026-10-04').length); assert.match(text,/85 دجاجة/); assert.match(text,/206 دجاجة/);
  assert.match(text,/100,000/); assert.match(text,/21,250/); assert.deepEqual(s,before);
  assert.throws(()=>createReport(s,{kind:'daily',date:'2026-02-30'})); assert.throws(()=>createReport(s,{kind:'daily',date:'2026-10-02'}));
});
test('supplier PDF preserves fractions, identifiers, paid invoice allocation and separate debt/account totals; untrusted strings are escaped', () => {
  const s=fixture(); s.suppliers[0].name='<img src=x onerror=alert(1)>'; s.invoices[0].note='</style><script>alert(1)</script>'; s.invoices[0].number='٠٠١٢/../';
  const report=createReport(s,{kind:'invoice',id:'invoice'}),d=document(report),text=d.body.textContent;
  assert.match(text,/12.5/); assert.match(text,/111,250/); assert.match(text,/121,250/); assert.match(text,/10,000/); assert.match(text,/40,000/); assert.match(text,/قائمة 0012/);
  assert.equal(d.querySelectorAll('script,img').length,0); assert.ok(d.querySelector('meta[http-equiv="Content-Security-Policy"]')); assert.doesNotMatch(report.filename,/[\\/]/);
  assert.throws(()=>createReport(s,{kind:'invoice',id:'missing'})); assert.throws(()=>createReport(s,{kind:'html',html:'anything'}));
});
test('PDF writer replaces atomically and leaves existing files intact if staging fails', async t => {
  const dir=await fs.mkdtemp(path.join(os.tmpdir(),'daftar-pdf-')); t.after(()=>fs.rm(dir,{recursive:true,force:true}));
  const file=path.join(dir,'report.pdf'); await fs.writeFile(file,'old'); await writePDF(file,Buffer.from('%PDF-test')); assert.equal(await fs.readFile(file,'utf8'),'%PDF-test');
  await assert.rejects(writePDF(file,undefined)); assert.equal(await fs.readFile(file,'utf8'),'%PDF-test'); assert.deepEqual(await fs.readdir(dir),['report.pdf']);
});
test('hidden PDF window is destroyed after successful printing or a rendering failure', async () => {
  for (const fail of [false,true]) {
    let destroyed=false;
    class Window { constructor() { this.webContents={setWindowOpenHandler(){},on(){},executeJavaScript:async()=>true,printToPDF:async()=>{if(fail)throw new Error('print failed'); return Buffer.from('%PDF');}}; } async loadURL(url) {assert.match(url,/^data:text\/html/);} isDestroyed(){return destroyed;} destroy(){destroyed=true;} }
    const promise=renderPDF(Window,createReport(fixture(),{kind:'invoice',id:'invoice'}));
    if(fail)await assert.rejects(promise,/print failed/);else assert.equal((await promise).toString(),'%PDF');assert.equal(destroyed,true);
  }
});
