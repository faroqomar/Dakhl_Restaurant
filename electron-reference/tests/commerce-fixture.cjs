const M = require('../app/ui/model.js');
function fixture() {
  const state = M.empty(), date = '2026-10-26';
  const items = [['كباب لحم','المشاوي',12000],['كباب دجاج','المشاوي',8000],['دجاج مشوي','الدجاج',10000],['دليمية دجاج','الدليمية',15000],['تمن أحمر','الإضافات',2000],['صحن مقبلات','الإضافات',3000],['ماء','المشروبات',500],['مشروب غازي','المشروبات',1000]];
  items.forEach(([name,group,price], i) => { state.products.push({ id:'p'+i, name, group, price, code:'1000'+i, photo:M.productPhotos[i], unit:'قطعة', minStock:3, trackStock:true, archived:false }); state.stockEntries.push({ id:'opening'+i, productId:'p'+i, date, quantity:i===6?2:20, kind:'opening', note:'بيانات توضيحية للاختبار فقط', createdAt:date+'T08:00:00Z' }); });
  return state;
}
module.exports = { fixture };
