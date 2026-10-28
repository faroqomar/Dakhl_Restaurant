// Extra catalog entries are used by the browser design preview only.
const { fixture } = require('../tests/commerce-fixture.cjs');
function previewFixture() {
  const state=fixture(),date='2026-10-26';
  const samples=[
    ['كباب لحم دبل','المشاوي',22000,'beef-kebab'],
    ['كباب دجاج دبل','المشاوي',15000,'chicken-kebab'],
    ['نفر مشاوي مشكل','المشاوي',18000,'beef-kebab'],
    ['تكة لحم','المشاوي',14000,'beef-kebab'],
    ['تكة دجاج','المشاوي',10000,'chicken-kebab'],
    ['نصف دجاج مشوي','الدجاج',6000,'grilled-chicken'],
    ['دجاج مشوي عائلي','الدجاج',20000,'grilled-chicken'],
    ['وجبة دجاج وتمن','الدجاج',12000,'grilled-chicken'],
    ['دجاج مشوي حار','الدجاج',11000,'grilled-chicken'],
    ['دليمية لحم','الدليمية',20000,'dulaimiya'],
    ['دليمية دجاج عائلية','الدليمية',28000,'dulaimiya'],
    ['دليمية لحم عائلية','الدليمية',35000,'dulaimiya'],
    ['تمن أبيض','الإضافات',1500,'red-rice'],
    ['تمن أحمر عائلي','الإضافات',5000,'red-rice'],
    ['مقبلات عائلية','الإضافات',6000,'appetizers'],
    ['سلطة خضراء','الإضافات',2500,'appetizers'],
    ['حمص بالطحينة','الإضافات',2000,'appetizers'],
    ['تبولة','الإضافات',2500,'appetizers'],
    ['خبز إضافي','الإضافات',500,null],
    ['طرشي','الإضافات',1000,'appetizers'],
    ['ماء كبير','المشروبات',1000,'water'],
    ['مشروب غازي عائلي','المشروبات',2500,'cola'],
    ['عصير برتقال','المشروبات',2000,null],
    ['لبن','المشروبات',1500,null],
    ['شاي','المشروبات',500,null]
  ];
  samples.forEach(([name,group,price,photo],i)=>{
    const id='preview-extra-'+(i+1);
    state.products.push({id,name,group,price,code:'DEMO-'+(i+1),...(photo?{photo}:{}),unit:'قطعة',minStock:3,trackStock:true,archived:false});
    state.stockEntries.push({id:'opening-'+id,productId:id,date,quantity:i%9===0?3:30+i,kind:'opening',note:'بيانات توضيحية للمعاينة فقط',createdAt:date+'T08:00:00Z'});
  });
  return state;
}
module.exports={previewFixture};
