import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const source = await readFile(new URL('../../dist/app.js', import.meta.url), 'utf8');
const {validateBridge, metric, comparison, escapeHtml, runDetails} = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);

test('pairing sends credentials only to the fixed local runner', () => {
  for (const value of ['http://127.0.0.1:18763','http://localhost:18763','http://[::1]:18763']) assert.equal(validateBridge(value), value);
  for (const value of ['https://127.0.0.1:18763','http://127.0.0.1:8000','http://example.com:18763','http://127.0.0.1.example.com:18763','http://127.0.0.1:18763/path','http://127.0.0.1:18763?secret=a','http://user:pass@localhost:18763','javascript:alert(1)']) assert.equal(validateBridge(value), null, value);
});

test('missing, invalid or negative metrics never become fabricated zeroes', () => {
  for (const value of [null,undefined,'0',NaN,Infinity,-1]) assert.equal(metric(value), '—');
  assert.equal(metric(0), '0');
  assert.equal(metric(12.345), '12.3');
});

test('baseline comparison requires valid timing and matching measurement conditions', () => {
  const baseline = {timing:{medianMs:10},platform:'macOS',buildMode:'profile',targetId:'macos',iterations:30,workloadHash:'fixed-workload',hardwareId:'same-machine'};
  assert.equal(comparison({...baseline,timing:{medianMs:8}},baseline).label, '-20.0%');
  assert.equal(comparison({...baseline,platform:'Android'},baseline).label, 'Not comparable');
  assert.equal(comparison({...baseline,iterations:50},baseline).label, 'Not comparable');
  assert.equal(comparison({...baseline,platform:null},{...baseline,platform:null}).label, 'Not comparable');
  assert.equal(comparison({...baseline,workloadHash:null},{...baseline,workloadHash:null}).label, 'Not comparable');
  assert.equal(comparison({...baseline,comparabilityKey:'new'},{...baseline,comparabilityKey:'old'}).label, 'Not comparable');
  assert.equal(comparison({...baseline,resources:{intervalMs:50}},{...baseline,resources:{intervalMs:100}}).label, 'Not comparable');
  assert.equal(comparison({...baseline,timing:{medianMs:0}},baseline).label, '-100.0%');
  assert.equal(comparison(baseline,{...baseline,timing:{medianMs:0}}).label, 'Not measured');
  assert.equal(comparison(baseline,null).label, 'No baseline');
});

test('status and source text cannot inject markup', () => {
  assert.equal(escapeHtml('<img src=x onerror="alert(1)">'), '&lt;img src=x onerror=&quot;alert(1)&quot;&gt;');
  assert.equal(escapeHtml(null), '');
});

test('actual command results expose suite counts, duration and failure safely', () => {
  const html = runDetails({commands:[{label:'App <tests>',exitCode:0,passed:151,elapsedSeconds:12.3},{label:'Engine',exitCode:1,passed:null,elapsedSeconds:2}],results:[],error:'Check failed'});
  assert.match(html, /App &lt;tests&gt;: passed · 151 tests · 12.3s/);
  assert.match(html, /Engine: failed · 2s/);
  assert.match(html, /Check failed/);
  assert.doesNotMatch(html, /null tests/);
});
