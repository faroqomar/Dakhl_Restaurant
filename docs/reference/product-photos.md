# الصور المرجعية لأصناف البيع

الحالة: أصول مولدة ومستخدمة في المصدر ومعاينة التصميم. التاريخ: 2026-10-26. المصدر: طلب المالك إضافة صور مرجعية لبطاقات الأصناف. الأداة: image_gen المدمجة (دون CLI).

الصور في `app/ui/photos/`، ثماني صور PNG محلية. هي أمثلة مرجعية مولدة وليست صوراً لمنتجات المطعم الفعلية أو دليلاً على حجم الحصة. تبقى الشاشة والبيانات محلية ولا تحمل صوراً من شبكة خارجية. أسماء المفاتيح والقائمة المسموحة موثقة في `model.js`؛ اختيار الصورة من نموذج الصنف بالمخزن.

## مجموعة النصوص النهائية للتوليد

كل طلب مستقل يستخدم النص التالي، مع استبدال SUBJECT من الجدول:

> Use case: product-mockup. Asset type: local restaurant POS product thumbnail, square photograph. Primary request: SUBJECT. Style: realistic professional food reference photography, not an actual photograph of the restaurant's products. Single centered subject on a warm light beige tabletop, soft natural daylight, camera at 40 degree angle, appetizing but honest portion, image fills frame, quiet neutral background, crisp recognizable subject at small thumbnail sizes. No text, lettering, logo, watermark, hands, extra dishes or borders.

| الملف | SUBJECT |
| --- | --- |
| `beef-kebab.png` | Iraqi grilled minced beef kebab, three long grilled skewers with char marks, served on a simple ivory ceramic plate with grilled tomato and parsley, no bread covering the meat |
| `chicken-kebab.png` | Iraqi grilled minced chicken kebab, three long pale golden grilled skewers with char marks, served on an ivory ceramic plate with grilled tomato and parsley |
| `grilled-chicken.png` | Iraqi half chicken grilled over charcoal, golden brown crispy skin and subtle char marks, ivory plate with a small lemon wedge |
| `dulaimiya.png` | Iraqi chicken dulaimiya on an ivory platter: aromatic rice over torn flatbread with a clearly visible golden roasted chicken quarter on top |
| `red-rice.png` | a small ivory bowl of Iraqi tomato red rice, fluffy individual grains, a small parsley garnish |
| `appetizers.png` | an ivory small plate of Iraqi fresh salad with cucumber tomato lettuce, plus a small hummus portion and pickled vegetables, neat restaurant appetizer |
| `water.png` | a single clear unbranded plastic water bottle with blue cap and a small transparent tumbler, no printed words or labels |
| `cola.png` | a chilled unbranded dark cola in a clear glass with ice cubes and tiny bubbles, simple small glass beverage photography, no can and no branding |

نسخت كل صورة مولدة إلى المشروع مع إبقاء الأصل، وراجعت الصور وبطاقاتها بصرياً وتحميلها المحلي في تجربة Electron. تفاصيل التحقق في [سجل الجولة الثانية](../log/2026-10-26-sales-layout-review.md).
