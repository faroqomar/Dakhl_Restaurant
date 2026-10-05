const { test } = require('node:test');
const assert = require('node:assert/strict');
const { JSDOM } = require('jsdom');
const N = require('../app/ui/numbers.js'), M = require('../app/ui/model.js');
function input(t, mode = 'integer') {
  const dom = new JSDOM(`<input type="text" data-number-format="${mode}">`); t.after(() => dom.window.close()); const w = dom.window, el = w.document.querySelector('input'); N.install(w.document); el.focus();
  function type(value, start = value.length, end = start) { el.value = value; el.setSelectionRange(start, end); el.dispatchEvent(new w.InputEvent('input', { bubbles: true })); }
  function remove(direction, at) { el.setSelectionRange(at, at); el.dispatchEvent(new w.InputEvent('beforeinput', { bubbles: true, cancelable: true, inputType: direction })); }
  return { w, el, type, remove };
}
test('Arabic/Persian numbers format as English grouped strings without rounding, including decimals, negatives and identifiers', () => {
  assert.equal(N.format('٥٠٠٠٠٠'), '500,000'); assert.equal(N.format('۵۰۰٬۰۰۰'), '500,000'); assert.equal(N.format('123456789012345678901'), '123,456,789,012,345,678,901');
  assert.equal(N.format('١٢٣٤٫٥٠٠', 'decimal'), '1,234.500'); assert.equal(M.quantity(N.format('١٢٣٤٫٥٠٠', 'decimal')), 1234.5);
  assert.equal(N.format('-١٢٣٤٥٦', 'signed'), '-123,456'); assert.equal(M.numeric(N.format('-١٢٣٤٥٦', 'signed'), { signed: true }), -123456);
  assert.equal(N.format('٠٧٧٠١٢٣٤٥٦٧', 'digits'), '07701234567'); assert.equal(N.format('A-٠٠١٢', 'digits'), 'A-0012');
  for (const invalid of ['1.5', '2e4', '12x', '-500']) assert.equal(N.format(invalid), invalid);
  assert.equal(N.format('', 'integer'), ''); assert.equal(N.format('-', 'signed'), '-'); assert.equal(N.format('١٢٣٤.', 'decimal'), '1,234.');
});
test('caret and selection stay in the number when typing, replacing, or pasting digits in the middle', t => {
  const { el, type } = input(t); type('٥٠٠٠٠٠'); assert.equal(el.value, '500,000'); assert.equal(el.selectionStart, 7);
  type('129,345', 3); assert.equal(el.value, '129,345'); assert.equal(el.selectionStart, 3);
  type('1234567', 2, 5); assert.equal(el.value, '1,234,567'); assert.equal(el.selectionStart, 3); assert.equal(el.selectionEnd, 7);
  type('٥٠٠٬٠٠٠', 3); assert.equal(el.value, '500,000'); assert.equal(el.selectionStart, 4);
});
test('backspace/delete across thousands separators removes a digit instead of getting stuck on a comma', t => {
  const { el, type, remove } = input(t); type('1234'); remove('deleteContentBackward', 2); assert.equal(el.value, '234'); assert.equal(el.selectionStart, 0);
  type('1234'); remove('deleteContentForward', 1); assert.equal(el.value, '134'); assert.equal(el.selectionStart, 1);
});
test('composition input is left intact until composition completes and decimal editing keeps trailing zeros', t => {
  const { el, w, type } = input(t, 'decimal'); el.value = '١٢٣٤٫٥'; el.dispatchEvent(new w.InputEvent('input', { bubbles: true, isComposing: true })); assert.equal(el.value, '١٢٣٤٫٥');
  el.dispatchEvent(new w.CompositionEvent('compositionend', { bubbles: true })); assert.equal(el.value, '1,234.5');
  type('١٢٣٤٫٥٠٠'); assert.equal(el.value, '1,234.500'); type('1234.'); assert.equal(el.value, '1,234.');
});
