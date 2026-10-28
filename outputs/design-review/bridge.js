'use strict';
const previewKey = 'daftar.layout-review.sample-accounts.v1';
function previewData() {
  const initial=DaftarModel.validate(window.previewFixture);
  try {
    const saved=localStorage.getItem(previewKey);
    if(saved) {
      const data=DaftarModel.validate(JSON.parse(saved));
      for(const p of data.products) {
        const sample=initial.products.find(s=>s.id===p.id&&s.name===p.name);
        if(!p.photo&&sample?.photo)p.photo=sample.photo;
      }
      for(const p of initial.products.filter(p=>p.id.startsWith('preview-extra-'))) {
        if(data.products.some(existing=>existing.id===p.id))continue;
        // Preserve any existing custom preview code instead of causing a collision.
        const product=structuredClone(p);
        if(data.products.some(existing=>existing.code.toLowerCase()===product.code.toLowerCase()))product.code='';
        data.products.push(product);
        data.stockEntries.push(...initial.stockEntries.filter(entry=>entry.productId===p.id));
      }
      return DaftarModel.validate(data);
    }
  } catch {}
  return initial;
}

let previewAccounts = previewData();
window.daftar = {
  load: async () => ({ ok: true, data: structuredClone(previewAccounts), directory: 'Browser design preview · sample data only' }),
  save: async data => { try { const clean = DaftarModel.validate(data); localStorage.setItem(previewKey, JSON.stringify(clean)); previewAccounts = clean; return { ok: true, data: structuredClone(clean) }; } catch(e) { return { ok: false, error: e.message }; } },
  pdf: async () => ({ ok: false, error: 'تصدير PDF متاح من تطبيق دفتر. هذه معاينة للتصميم ببيانات توضيحية.' }),
  export: async () => ({ ok: false, error: 'هذه معاينة للتصميم؛ حسابات المطعم غير متصلة بها.' }),
  import: async () => ({ ok: false, error: 'هذه معاينة للتصميم؛ حسابات المطعم غير متصلة بها.' }),
  folder: async () => ({ ok: false, error: 'هذه معاينة متصفح ببيانات توضيحية.' }),
  onAction: () => {}
};
window.addEventListener('DOMContentLoaded', () => document.querySelector('#navigation [data-view="sales"]')?.click());
