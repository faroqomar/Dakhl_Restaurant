(function (root, factory) {
  const numbers = factory();
  if (typeof module === 'object' && module.exports) module.exports = numbers;
  else { root.DaftarNumbers = numbers; numbers.install(root.document); }
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  const separators = /[,٬\s\u200e\u200f\u061c]/g;
  const latin = value => String(value).replace(/[٠-٩]/g, d => String('٠١٢٣٤٥٦٧٨٩'.indexOf(d))).replace(/[۰-۹]/g, d => String('۰۱۲۳۴۵۶۷۸۹'.indexOf(d)));
  function format(value, mode = 'integer') {
    const text = latin(value);
    if (mode === 'digits') return text;
    const normalized = text.replace(/٫/g, '.');
    const raw = normalized.replace(separators, '');
    const pattern = mode === 'decimal' ? /^\d*(?:\.\d*)?$/ : mode === 'signed' ? /^-?\d*$/ : /^\d*$/;
    // Keep invalid characters visible so validation can explain them; never turn 1.5 into 15.
    if (!pattern.test(raw)) return normalized;
    const [integer, fraction] = raw.split('.');
    return integer.replace(/\B(?=(\d{3})+(?!\d))/g, ',') + (fraction === undefined ? '' : '.' + fraction);
  }
  function modeFor(el) {
    if (!el.matches('input[type=text],input:not([type]),input[type=tel],input[type=search],textarea')) return null;
    return el.dataset.numberFormat || (el.inputMode === 'decimal' ? 'decimal' : el.inputMode === 'numeric' ? 'integer' : 'digits');
  }
  function meaningful(text) { return latin(text).replace(separators, '').length; }
  function caretAt(text, count) {
    let i = 0, seen = 0;
    while (i < text.length && seen < count) { if (!text[i].match(separators)) seen++; i++; }
    while (text[i] === ',') i++;
    return i;
  }
  function formatInput(el) {
    const mode = modeFor(el); if (!mode) return;
    const before = el.value, after = format(before, mode); if (before === after) return;
    const start = el.selectionStart, end = el.selectionEnd, direction = el.selectionDirection;
    el.value = after;
    if (start !== null) {
      if (mode === 'digits') el.setSelectionRange(start, end, direction);
      else el.setSelectionRange(caretAt(after, meaningful(before.slice(0, start))), caretAt(after, meaningful(before.slice(0, end))), direction);
    }
  }
  function formatInputs(scope) { scope.querySelectorAll('input,textarea').forEach(formatInput); }
  function install(doc) {
    const normalize = event => { if (!event.isComposing && event.target.matches('input,textarea')) formatInput(event.target); };
    // Capture runs before calculation listeners, so live invoice/funding previews use the same value.
    doc.addEventListener('input', normalize, true);
    doc.addEventListener('change', normalize, true);
    doc.addEventListener('focusout', normalize, true);
    doc.addEventListener('compositionend', event => {
      normalize(event);
      event.target.dispatchEvent(new doc.defaultView.Event('input', { bubbles: true }));
    }, true);
    doc.addEventListener('beforeinput', event => {
      const el = event.target, mode = el.matches('input,textarea') ? modeFor(el) : null;
      if (!mode || mode === 'digits' || event.isComposing || !event.cancelable || el.selectionStart !== el.selectionEnd) return;
      const at = el.selectionStart, backward = event.inputType === 'deleteContentBackward', forward = event.inputType === 'deleteContentForward';
      const from = backward && el.value[at - 1] === ',' ? at - 2 : forward && el.value[at] === ',' ? at : null;
      if (from === null || from < 0) return;
      event.preventDefault();
      el.setRangeText('', from, from + 2, 'start'); formatInput(el);
      el.dispatchEvent(new doc.defaultView.Event('input', { bubbles: true }));
    }, true);
  }
  return { latin, format, formatInput, formatInputs, install };
});
