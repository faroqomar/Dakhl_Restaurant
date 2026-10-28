const M = require('../app/ui/model.js');
function fixture(long = false) {
  const s = M.empty(), key = '2026-10-04';
  s.categories.push({ id:'gas',name:'الغاز',type:'additional' });
  s.suppliers.push({ id:'supplier',name:'مورد تجريبي',phone:'07701234567',note:'',categoryId:'market',openingBalance:50000,materials:[{ id:'rice',name:'رز',unit:'كيلو',price:2500,archived:false },{ id:'oil',name:'زيت',unit:'كارتون',price:40000,archived:false }] });
  s.invoices.push({ id:'invoice',supplierId:'supplier',number:'٠٠١٢',date:'2026-10-03',createdAt:'2026-10-03T10:00:00.000Z',note:'تجهيز المطعم\nالأسعار محفوظة وقت تسجيل القائمة.',lines:[{ materialId:'rice',name:'رز بسمتي',unit:'كيلو',quantity:12.5,price:2500 },{ materialId:'oil',name:'زيت طبخ',unit:'كارتون',quantity:2,price:40000 }] });
  s.payments.push({ id:'payment',supplierId:'supplier',invoiceId:'invoice',date:key,createdAt:key+'T11:00:00.000Z',amount:121250,invoiceAmount:111250,debtAmount:10000,categoryId:'market',funding:{ source:'shared',dailyAmount:100000,cashAmount:21250 },note:'القائمة كاملة وجزء من الديون' });
  const entries = [['samoon',115000,''],['bread',14000,''],['falafel',8000,''],['gas',42000,'تبديل قنينة'],['market',35000,'خضار للمطعم']];
  s.days[key] = { ...M.day(s,key),chickenUsed:85,chickenLeft:206,balance:1750000,totalOverride:350000,expenses:entries.map(([categoryId,amount,note],n) => ({ id:'expense-'+n,categoryId,amount,note,funding:{ source:'daily',dailyAmount:amount,cashAmount:0 } })) };
  s.transactions.push({ id:'cash',type:'deposit',date:'2026-10-01',amount:500000,note:'رصيد القاصة',createdAt:'2026-10-01T10:00:00.000Z' },{ id:'future',type:'deposit',date:'2026-10-06',amount:999999,note:'حركة لاحقة لا تدخل بفاتورة اليوم السابق',createdAt:'2026-10-06T10:00:00.000Z' });
  M.recordRemaining(s,key,600000); M.transferRemaining(s,key,215000,'transfer',key+'T20:00:00.000Z');
  if (long) {
    for (let n=0;n<75;n++) s.invoices[0].lines.push({ materialId:'rice',name:`مادة ${n + 3} - تجهيز للمطبخ بكميات يومية محفوظة`,unit:'كيلو',quantity:1.125,price:3000+n*100 });
    s.invoices[0].note = 'ملاحظة طويلة للتأكد من التفاف النص وترتيب الأسطر. '.repeat(18);
  }
  return M.validate(s);
}
module.exports = { fixture };
