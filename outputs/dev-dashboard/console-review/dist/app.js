const DEFAULT_BRIDGE = 'http://127.0.0.1:18763';
const STORE_KEY = 'dakhl.dashboard.connection.v1';
const RUNNING = new Set(['running', 'queued', 'starting']);
const $ = (selector) => document.querySelector(selector);
export const escapeHtml = (value) => String(value ?? '').replace(/[&<>"']/g, (char) => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
export function validateBridge(value) {
  try {
    const url = new URL(value);
    if (url.protocol !== 'http:' || !['127.0.0.1', 'localhost', '[::1]'].includes(url.hostname) || url.username || url.password || url.pathname !== '/' || url.search || url.hash || url.port !== '18763') return null;
    return url.origin;
  } catch { return null; }
}
export function metric(value, digits = 1) {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0 ? value.toLocaleString('en', { maximumFractionDigits: digits }) : '—';
}
export function comparison(latest, baseline) {
  if (!latest || !baseline) return { label: 'No baseline', className: '', note: 'Save a measured run to compare.' };
  if (!latest.platform || !baseline.platform || !latest.buildMode || !baseline.buildMode || !latest.workloadHash || !baseline.workloadHash) return { label: 'Not comparable', className: '', note: 'Measurement conditions are incomplete.' };
  const keys = ['platform', 'buildMode', 'targetId', 'hardwareId', 'iterations', 'scenarioVersion', 'workloadHash', 'protocolVersion', 'measurementKind', 'comparabilityKey'];
  if (keys.some((key) => (latest[key] ?? null) !== (baseline[key] ?? null)) || (latest.resources?.intervalMs ?? null) !== (baseline.resources?.intervalMs ?? null) || JSON.stringify(latest.environment ?? null) !== JSON.stringify(baseline.environment ?? null)) return { label: 'Not comparable', className: '', note: 'Measurement conditions differ.' };
  const current = latest.timing?.medianMs;
  const original = baseline.timing?.medianMs;
  if (typeof current !== 'number' || !Number.isFinite(current) || current < 0 || typeof original !== 'number' || !Number.isFinite(original) || original <= 0) return { label: 'Not measured', className: '', note: 'A valid baseline timing is required.' };
  const delta = ((current - original) / original) * 100;
  return { label: `${delta > 0 ? '+' : ''}${delta.toFixed(1)}%`, className: delta < -1 ? 'improved' : delta > 1 ? 'regressed' : '', note: 'Median time vs. baseline' };
}

let data = null;
let connection = null;
let online = false;
let pending = false;
let activeRun = null;
let pollTimer = null;
let view = 'progress';
let message = '';
let lastError = '';
let snapshotLoaded = false;

const short = (value) => value ? String(value).slice(0, 8) : 'unrecorded';
const date = (value) => { const parsed = new Date(value); return value && !Number.isNaN(parsed.getTime()) ? parsed.toLocaleString('en', {month:'short', day:'numeric', hour:'numeric', minute:'2-digit'}) : 'time not recorded'; };
const label = (value) => String(value || 'unknown').replace(/[_-]/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
const status = (value, text) => `<span class="status ${escapeHtml(String(value || '').toLowerCase().split(/[ —]/)[0])}">${escapeHtml(text || label(value))}</span>`;
const sourceLine = (record) => `${record?.appVersion ? `v${escapeHtml(record.appVersion)} · ` : ''}${escapeHtml(short(record?.sourceCommit))}${record?.sourceDirty ? ' + local changes' : ''}${record?.platform ? ` · ${escapeHtml(record.platform)}` : ''}${record?.buildMode ? ` · ${escapeHtml(record.buildMode)}` : ''}`;
const runs = () => Array.isArray(data?.runs) ? data.runs : [];
const operations = () => Array.isArray(data?.operations) ? data.operations : [];
const busy = () => pending || Boolean(data?.runner?.busy) || RUNNING.has(activeRun?.status);
const canRun = () => Boolean(online && connection?.token && !busy());

function rememberConnection(value) {
  connection = value;
  try { value ? sessionStorage.setItem(STORE_KEY, JSON.stringify(value)) : sessionStorage.removeItem(STORE_KEY); } catch { /* An unavailable session store does not block this tab. */ }
}
async function request(path, options = {}) {
  if (!connection?.base) throw new Error('Connect the local runner to continue.');
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 12000);
  try {
    const response = await fetch(`${connection.base}${path}`, { ...options, cache:'no-store', credentials:'omit', redirect:'error', signal:controller.signal, headers:{'Content-Type':'application/json', ...(connection.token ? {Authorization:`Bearer ${connection.token}`} : {}), ...options.headers} });
    const result = await response.json().catch(() => ({}));
    if (!response.ok) {
      if (response.status === 401) { rememberConnection(null); online = false; throw new Error('This connection has expired. Open the local runner to pair again.'); }
      // Server messages must never include tokens; show bounded text, never raw responses.
      const detail = typeof result.error === 'string' ? result.error.slice(0, 240) : result.error?.message;
      throw new Error(detail || `The runner returned an error (${response.status}). Retry or open the local runner.`);
    }
    return result;
  } catch (error) {
    if (error.name === 'AbortError') throw new Error('The local runner took too long to respond. Check that it is running, then retry.');
    if (error instanceof TypeError) throw new Error('Cannot reach the local runner. Start it on your Mac and allow this site to connect to your local network.');
    throw error;
  } finally { clearTimeout(timeout); }
}
function validateStatus(value) {
  if (value?.schemaVersion !== 1 || !value.project || !Array.isArray(value.operations)) throw new Error('The runner returned an unsupported status format. Update the dashboard runner.');
  return value;
}
async function loadSnapshot() {
  if (snapshotLoaded) return;
  snapshotLoaded = true;
  try {
    const response = await fetch('./snapshot.json', {cache:'no-store', credentials:'same-origin'});
    if (!response.ok) throw new Error();
    data = validateStatus(await response.json());
  } catch {
    if (!data) message = 'Project evidence is unavailable. Connect the local runner to load current status.';
  }
}
async function refresh({quiet = false} = {}) {
  if (pending) return;
  pending = true;
  if (!quiet) { message = connection?.token ? 'Reading current local evidence…' : ''; render(); }
  try {
    if (!connection?.token) throw new Error('');
    data = validateStatus(await request('/api/status'));
    online = data.runner?.online !== false;
    message = online ? '' : 'The runner reports offline. Actions are unavailable.';
    lastError = '';
    activeRun = runs().find((run) => run.id === data.runner?.activeRunId) || runs().find((run) => RUNNING.has(run.status)) || null;
  } catch (error) {
    online = false;
    await loadSnapshot();
    if (error.message) message = error.message;
  } finally { pending = false; render(); schedulePoll(); }
}
async function bootstrap() {
  // Scrub pairing secrets before any asynchronous work, rendering or other requests.
  const fragment = new URLSearchParams(location.hash.slice(1));
  const bridge = fragment.get('bridge');
  const code = fragment.get('pair');
  if (location.hash) history.replaceState(null, '', `${location.pathname}${location.search}`);
  try {
    const saved = JSON.parse(sessionStorage.getItem(STORE_KEY) || 'null');
    if (saved && validateBridge(saved.base) && typeof saved.token === 'string' && saved.token) connection = saved;
  } catch { /* A fresh connection is available through the local runner. */ }
  if (code || bridge) {
    const base = validateBridge(bridge || DEFAULT_BRIDGE);
    if (!base || !code || code.length > 512) { lastError = 'This pairing link is invalid. Open the local runner to generate a new link.'; }
    else {
      rememberConnection({base, token:null});
      try {
        const result = await request('/api/pair', {method:'POST', body:JSON.stringify({code})});
        if (typeof result.token !== 'string' || !result.token) throw new Error('Pairing did not return a connection. Generate a new link from the local runner.');
        rememberConnection({base, token:result.token});
      } catch (error) { rememberConnection(null); lastError = error.message; }
    }
  }
  await refresh();
}

function renderProgress() {
  if (!data) return '<h2>Project progress</h2><p class="empty">No project evidence is available yet.</p>';
  const phase = data.phase || {};
  const phases = Array.isArray(data.phases) ? data.phases : [];
  return `<div class="current-phase"><p class="phase-label">Current work · Phase ${escapeHtml(phase.id ?? '—')}</p><div class="current-title"><h2>${escapeHtml(phase.name || 'Status not recorded')}</h2>${status(phase.status)}</div>${phase.blockers?.length ? `<ul class="blockers">${phase.blockers.map((blocker) => `<li>${escapeHtml(typeof blocker === 'string' ? blocker : blocker.label || blocker.reason || blocker.name)}</li>`).join('')}</ul>` : ''}</div><div class="section-heading"><h3>Phase timeline</h3><span class="muted small">${phases.length} phases</span></div><ol class="phase-list">${phases.map((item) => `<li class="phase-row ${String(item.id) === String(phase.id) ? 'current' : ''}"><span class="phase-number">${escapeHtml(item.id)}</span><span class="phase-name">${escapeHtml(item.name)}</span>${status(item.status)}</li>`).join('')}</ol>${versionHistory()}`;
}
function versionHistory() {
  const versions = Array.isArray(data?.versions) ? data.versions : [];
  return `<details class="history"><summary>Source &amp; version history${versions.length ? ` · ${versions.length}` : ''}</summary><p class="provenance">App ${escapeHtml(data?.project?.commit || 'unrecorded')}${data?.project?.dirty ? ' · local changes present' : ''}<br>Engine ${escapeHtml(data?.project?.engineCommit || 'unrecorded')}</p>${versions.length ? `<ol class="history-list">${versions.map((item) => `<li class="history-item"><div class="history-main"><span>${escapeHtml(item.label || item.version || short(item.commit || item.sourceCommit))}</span><span class="muted small">${date(item.recordedAt || item.date || item.createdAt)}</span></div><p class="history-meta">${escapeHtml(item.summary || item.note || '')} · ${escapeHtml(short(item.commit || item.sourceCommit))}</p></li>`).join('')}</ol>` : '<p class="small muted">No version history recorded.</p>'}</details>`;
}
export function runDetails(run) {
  const results = Array.isArray(run.results) ? run.results : [];
  const commands = Array.isArray(run.commands) ? run.commands : [];
  if (!results.length && !commands.length && !run.error) return '';
  const lines = [...commands.map((command) => `${command.label || 'Check'}: ${command.exitCode === 0 ? 'passed' : 'failed'}${typeof command.passed === 'number' ? ` · ${command.passed} tests` : ''}${typeof command.elapsedSeconds === 'number' ? ` · ${command.elapsedSeconds}s` : ''}`), ...results.map((result) => `${result.label || result.operationId || result.suite || result.id || 'Check'}: ${result.status || (result.passed === true ? 'passed' : 'recorded')}${result.summary ? ` — ${result.summary}` : ''}`)].join('\n');
  return `<details class="run-detail"><summary>Run details</summary><pre>${escapeHtml([lines, typeof run.error === 'string' ? run.error : run.error?.message].filter(Boolean).join('\n'))}</pre></details>`;
}
function runHistory(kind) {
  const history = runs().filter((run) => run.kind === kind).slice(0, 15);
  return history.length ? `<div class="history"><h3 class="history-title">Recent runs</h3><ol class="history-list">${history.map((run) => `<li class="history-item"><div class="history-main"><span>${escapeHtml(run.summary || label(run.kind))}</span>${status(run.status)}</div><p class="history-meta">${date(run.startedAt)}${run.finishedAt ? ` · Finished ${date(run.finishedAt)}` : ''}${run.sourceCommit ? ` · ${escapeHtml(short(run.sourceCommit))}` : ''}</p>${runDetails(run)}</li>`).join('')}</ol></div>` : '';
}
function renderChecks() {
  const record = data?.lastChecks;
  const liveRun = activeRun?.kind === 'tests' && RUNNING.has(activeRun.status);
  return `<div class="section-heading"><div><h2>Checks</h2><p>Run the app, engine, or both.</p></div><div class="check-controls"><label class="sr-only" for="test-suite">Test suite</label><select id="test-suite" ${busy() ? 'disabled' : ''}><option value="all">App + engine</option><option value="app">App tests</option><option value="engine">Engine tests</option></select><button class="primary" data-action="tests" ${canRun() ? '' : 'disabled'}>${liveRun ? 'Running tests…' : 'Run tests'}<span aria-hidden="true">↗</span></button></div></div>${liveRun ? `<p class="running-line" role="status">Tests are running on your Mac. Results appear when the run finishes.</p>` : ''}${record ? `<div class="check-record"><div class="record-heading"><div class="check-count">${typeof record.passed === 'number' ? escapeHtml(record.passed) : '—'}<span>passed${record.failed ? ` · ${escapeHtml(record.failed)} failed` : ''}</span></div>${status(record.status, label(record.status))}</div><p class="provenance">${escapeHtml(record.source || 'Recorded check evidence')} · ${date(record.recordedAt)} · ${escapeHtml(short(record.sourceCommit))}</p>${record.historical !== false && !record.runId ? '<p class="muted small">Historical evidence. This is not a new dashboard run.</p>' : ''}</div>` : '<p class="empty">No completed test results recorded. Connect your Mac and run the checks.</p>'}${runHistory('tests')}${!online ? '<p class="small muted">Connect the local runner to start a new run.</p>' : ''}`;
}
function renderPerformance() {
  const ready = operations().filter((op) => op.status === 'ready');
  const liveRun = activeRun?.kind === 'benchmarks' && RUNNING.has(activeRun.status);
  return `<div class="section-heading"><div><h2>Performance</h2><p>Measured operations, with their source and conditions.</p></div><button class="primary" data-action="benchmarks" ${canRun() && ready.length ? '' : 'disabled'}>${liveRun ? 'Running benchmarks…' : 'Run benchmarks'}<span aria-hidden="true">↗</span></button></div>${liveRun ? '<p class="running-line" role="status">Measuring on your Mac. Timing, memory and CPU appear after the run finishes.</p>' : ''}${operations().length ? `<div class="table-wrap"><table><caption class="sr-only">Operation speed, peak memory, CPU use and median timing comparison</caption><thead><tr><th scope="col">Operation</th><th scope="col">Speed · ms</th><th scope="col">RAM · MB</th><th scope="col">CPU · %</th><th scope="col">vs. baseline</th></tr></thead><tbody>${operations().map(operationRow).join('')}</tbody></table></div><p class="table-note">Speed: median (p50) / p95. RAM: sampled process peak. CPU: average / peak; multi-core use may exceed 100%. Missing measurements are shown as —.</p>` : '<p class="empty">No benchmark operations recorded yet.</p>'}${runHistory('benchmarks')}`;
}
function operationRow(op) {
  const current = op.latest;
  const change = comparison(current, op.baseline);
  const hasMeasurement = Boolean(current?.timing);
  const sourceRunId = current?.runId || current?.sourceRunId;
  const isPlanned = op.status === 'planned';
  return `<tr><th scope="row"><div class="op-name">${escapeHtml(op.label || op.id)}</div><div class="op-context">${op.phase != null ? `Phase ${escapeHtml(op.phase)} · ` : ''}${status(op.status)}</div>${!hasMeasurement && op.reason ? `<div class="op-context">${escapeHtml(op.reason)}</div>` : ''}</th><td>${metric(current?.timing?.medianMs)}<div class="metric-secondary">${metric(current?.timing?.p95Ms)} p95</div></td><td>${metric(current?.resources?.ramPeakMb)}<div class="metric-secondary">peak</div></td><td>${metric(current?.resources?.cpuAveragePercent)}<div class="metric-secondary">${metric(current?.resources?.cpuPeakPercent)} peak</div></td><td><div class="change ${change.className}">${isPlanned ? 'Planned' : !hasMeasurement ? 'Not measured' : escapeHtml(change.label)}</div><div class="comparison-note">${hasMeasurement ? escapeHtml(change.note) : 'No recorded values'}</div></td></tr>${current ? `<tr class="measurement-detail"><td colspan="5"><details><summary>${sourceLine(current)} · Measurement details</summary><p>Latest: ${sourceLine(current)} · ${date(current.recordedAt || current.finishedAt)}${current.iterations ? ` · ${escapeHtml(current.iterations)} samples` : ''}${current.targetId ? ` · ${escapeHtml(current.targetId)}` : ''}</p>${current.sourceFingerprint ? `<p>Working source fingerprint: ${escapeHtml(current.sourceFingerprint)}</p>` : ''}${op.baseline ? `<p>Baseline: ${sourceLine(op.baseline)} · ${date(op.baseline.recordedAt || op.baseline.finishedAt)} · ${metric(op.baseline.timing?.medianMs)} ms median</p>` : '<p>No baseline saved.</p>'}${current.limitations ? `<p>${escapeHtml(Array.isArray(current.limitations) ? current.limitations.join(' ') : current.limitations)}</p>` : ''}<button class="quiet" data-baseline="${escapeHtml(op.id)}" data-run="${escapeHtml(sourceRunId || '')}" ${canRun() && sourceRunId ? '' : 'disabled'}>Use this run as baseline</button></details></td></tr>` : ''}`;
}
function render() {
  $('#project-version').textContent = data?.project ? `v${data.project.version || 'unversioned'} · ${short(data.project.commit)}${data.project.dirty ? ' + local changes' : ''}` : 'Project evidence unavailable';
  $('#connection-label').textContent = online ? busy() ? 'Runner busy' : 'Connected to Mac' : pending ? 'Connecting' : 'Runner offline';
  $('#connection-button').className = `connection${online ? busy() ? ' busy' : ' online' : ''}`;
  $('#disconnect').hidden = !connection?.token;
  $('#disconnect').disabled = pending;
  const notice = online ? message : [message, data ? 'Showing saved evidence. Connect your Mac to run checks and update measurements.' : !message ? 'Connect your Mac to load development evidence.' : ''].filter(Boolean).join(' ');
  $('#notice').textContent = notice;
  $('#notice').hidden = !notice;
  $('#action-error').textContent = lastError;
  $('#action-error').hidden = !lastError;
  $('#view-progress').innerHTML = renderProgress();
  $('#view-checks').innerHTML = renderChecks();
  $('#view-performance').innerHTML = renderPerformance();
  $('#evidence-time').textContent = data ? `${online ? 'Local evidence' : 'Saved evidence'} · ${date(data.generatedAt)}` : 'Evidence not loaded';
  $('#refresh').disabled = pending;
}
function schedulePoll() {
  clearTimeout(pollTimer);
  if (online && !document.hidden && activeRun && RUNNING.has(activeRun.status)) pollTimer = setTimeout(pollRun, 1800);
}
async function pollRun() {
  if (document.hidden || !activeRun || !RUNNING.has(activeRun.status) || !online) return;
  try {
    const result = await request(`/api/runs/${encodeURIComponent(activeRun.id)}`);
    activeRun = result.run || result;
    if (!RUNNING.has(activeRun.status)) { await refresh({quiet:true}); return; }
    if (data) data.runs = [activeRun, ...runs().filter((run) => run.id !== activeRun.id)];
    render();
  } catch (error) { online = false; lastError = error.message; render(); }
  schedulePoll();
}
async function startRun(kind) {
  if (!canRun()) return;
  const suite = $('#test-suite')?.value || 'all';
  pending = true; lastError = ''; render();
  try {
    const payload = kind === 'tests' ? {kind, suite} : {kind, caseIds:operations().filter((op) => op.status === 'ready').map((op) => op.id)};
    const result = await request('/api/runs', {method:'POST', body:JSON.stringify(payload)});
    if (!result.runId) throw new Error('The runner did not confirm a run. Refresh before retrying.');
    activeRun = {id:result.runId, kind, status:'running', startedAt:new Date().toISOString(), summary:kind === 'tests' ? 'Test run in progress' : 'Benchmark run in progress'};
    if (data) { data.runs = [activeRun, ...runs()]; data.runner = {...data.runner, busy:true, activeRunId:result.runId}; }
  } catch (error) {
    // A lost POST response does not establish that the job failed to start.
    const failure = error.message;
    pending = false;
    await refresh({quiet:true});
    lastError = failure;
  }
  finally { pending = false; render(); schedulePoll(); }
}
async function saveBaseline(operationId, runId) {
  if (!canRun() || !runId) return;
  pending = true; lastError = ''; render();
  try {
    await request('/api/baseline', {method:'POST', body:JSON.stringify({operationId, runId})});
    pending = false;
    await refresh({quiet:true});
  } catch (error) { lastError = error.message; }
  finally { pending = false; render(); }
}
function initialize() {
  document.addEventListener('click', (event) => {
    const tab = event.target.closest('[data-view]');
    if (tab) {
      view = tab.dataset.view;
      document.querySelectorAll('[data-view]').forEach((item) => { item.classList.toggle('active', item === tab); item === tab ? item.setAttribute('aria-current', 'page') : item.removeAttribute('aria-current'); });
      ['progress','checks','performance'].forEach((name) => { $(`#view-${name}`).hidden = name !== view; });
    }
    const action = event.target.closest('[data-action]');
    if (action && !action.disabled) void startRun(action.dataset.action);
    const baseline = event.target.closest('[data-baseline]');
    if (baseline && !baseline.disabled) void saveBaseline(baseline.dataset.baseline, baseline.dataset.run);
  });
  $('#connection-button').addEventListener('click', () => { const help = $('#connection-help'); help.hidden = !help.hidden; $('#connection-button').setAttribute('aria-expanded', String(!help.hidden)); });
  $('#retry-connection').addEventListener('click', () => void refresh());
  $('#refresh').addEventListener('click', () => void refresh());
  $('#disconnect').addEventListener('click', () => { rememberConnection(null); online = false; activeRun = null; clearTimeout(pollTimer); message = 'Disconnected from the local runner.'; render(); });
  document.addEventListener('visibilitychange', () => { clearTimeout(pollTimer); if (!document.hidden && online && activeRun && RUNNING.has(activeRun.status)) void pollRun(); });
  void bootstrap();
}
if (typeof document !== 'undefined') initialize();
