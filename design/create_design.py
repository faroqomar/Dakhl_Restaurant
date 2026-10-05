from pathlib import Path
from html import escape
P=Path(__file__).resolve().parent
C={'bg':'#F6F7F2','paper':'#FEFEFA','ink':'#17382D','muted':'#758378','line':'#E2E8DD','green':'#245B42','soft':'#EAF0E4','lime':'#D6E7B8'}
parts=[]
def rect(x,y,w,h,fill,rx=0,stroke=None):
    parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}"'+(f' stroke="{stroke}"' if stroke else '')+'/>')
def text(x,y,s,size=16,color=None,weight=400,anchor='end'):
    parts.append(f'<text x="{x}" y="{y}" font-family="Geeza Pro, Tahoma, sans-serif" font-size="{size}" font-weight="{weight}" fill="{color or C["ink"]}" text-anchor="{anchor}">{escape(s)}</text>')
def line(x1,y1,x2,y2,color=None):
    parts.append(f'<path d="M{x1} {y1}H{x2}" fill="none" stroke="{color or C["line"]}"/>' if y1==y2 else f'<path d="M{x1} {y1}L{x2} {y2}" fill="none" stroke="{color or C["line"]}"/>')
def circle(x,y,r,fill): parts.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}"/>')
def icon(x,y,kind,color=None):
    paths={'ledger':'M3 2h14v18H3z M7 7h6 M7 11h6 M7 15h4','wallet':'M2 5h16v14H2z M3 5V2h12 M13 10h7v5h-7z','supplier':'M2 8h16v12H2z M0 8l3-6h14l3 6 M6 20v-7h8v7','transfer':'M2 6h16 M14 2l4 4-4 4 M18 16H2 M6 12l-4 4 4 4','dots':'M3 10h1 M9 10h1 M15 10h1','calendar':'M3 4h14v15H3z M3 8h14 M7 1v5 M13 1v5','plus':'M10 3v14 M3 10h14','arrow':'M16 10H4 M9 5l-5 5 5 5','check':'M3 10l5 5 9-10'}
    parts.append(f'<g transform="translate({x} {y})" fill="none" stroke="{color or C["muted"]}" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="{paths[kind]}"/></g>')
def btn(x,y,w,h,label,primary=False):
    rect(x,y,w,h,C['green'] if primary else C['paper'],10,None if primary else C['line'])
    text(x+w/2,y+h/2+6,label,16,C['paper'] if primary else C['ink'],600,'middle')
def start():
    global parts
    parts=['<svg xmlns="http://www.w3.org/2000/svg" width="1440" height="1000" viewBox="0 0 1440 1000">']
def write(name): (P/name).write_text('\n'.join(parts+['</svg>']),encoding='utf-8')
def dashboard():
    rect(0,0,1440,1000,C['bg'])
    parts.append('<g id="Navigation">')
    rect(1196,0,244,1000,'#EFF2E9'); line(1196,0,1196,1000)
    rect(1358,38,42,46,C['green'],11)
    line(1370,51,1388,51,C['lime']);line(1370,59,1388,59,C['lime']);line(1376,67,1388,67,C['lime'])
    text(1340,63,'دفتر',32,weight=700); text(1400,119,'حسابات المطعم',16,C['muted'])
    text(1400,194,'مساحة العمل',12,C['muted'])
    nav=[('المصاريف اليومية','ledger'),('الموردون','supplier'),('التسديدات','transfer'),('القاصة','wallet'),('أخرى','dots')]
    for i,(name,ic) in enumerate(nav):
        yy=216+i*60
        if i==0: rect(1216,yy,204,48,C['green'],10)
        icon(1382,yy+14,ic,C['paper'] if i==0 else C['muted'])
        text(1363,yy+31,name,17,C['paper'] if i==0 else C['ink'],600 if i==0 else 400)
        if i in [1,2]: text(1230,yy+30,'لاحقاً',11,C['muted'],anchor='start')
    line(1224,826,1412,826)
    circle(1391,872,20,'#DCE7D0');text(1391,878,'م',18,C['green'],600,'middle')
    text(1358,870,'حسابات المطعم',15,weight=600);text(1358,893,'مساحة خاصة',12,C['muted'])
    text(1404,959,'بسيط. واضح. كل يوم.',14,C['muted'])
    parts.append('</g><g id="Header">')
    text(1156,51,'المصاريف / سجل اليوم',13,C['muted'])
    text(1156,104,'كل يوم، حسابه واضح.',34,weight=700)
    text(1156,138,'سجّل مصاريفك وتابع القاصة من مكان واحد.',16,C['muted'])
    btn(48,77,166,48,'إضافة مصروف  +',True)
    btn(226,77,228,48,'5 تشرين الأول 2026');icon(422,91,'calendar')
    parts.append('</g><g id="DailySummary">')
    line(48,177,1156,177);line(48,263,1156,263)
    text(1156,208,'مجموع مصاريف اليوم',14,C['muted']);text(1156,246,'351,000',30,weight=600);text(1009,245,'د.ع',13,C['muted'])
    line(800,194,800,246)
    text(755,208,'الرصيد الكلي',14,C['muted']);text(755,245,'—',28);text(718,242,'يُحدّد عند تسجيل الرصيد',13,C['muted'])
    line(441,194,441,246)
    text(397,208,'خانات المصاريف',14,C['muted']);text(397,245,'06',29,weight=600);text(340,243,'خانات مسجّلة لهذا اليوم',13,C['muted'])
    parts.append('</g><g id="DailyExpenseLedger">')
    rect(384,294,772,452,C['paper'],16,C['line'])
    text(1128,336,'تفاصيل المصاريف',23,weight=600);text(412,335,'+ إضافة خانة',14,C['green'],600,'start')
    rect(400,357,740,38,'#F3F5EE',6)
    text(1122,382,'الخانة',13,C['muted']);text(919,382,'المبلغ · د.ع',13,C['muted']);text(752,382,'ملاحظات',13,C['muted']);text(420,382,'تعديل',13,C['muted'],'400','start')
    entries=[('الصمون','113,000','حساب الصمون اليومي'),('الخبز','60,000','—'),('الفلافل','9,000','—'),('الأسواق','41,000','مشتريات السوق'),('الغاز','35,000','خانة إضافية'),('مشروبات غازية','93,000','خانة إضافية')]
    for i,(cat,amount,note) in enumerate(entries):
        yy=424+i*44
        if i>0: line(409,yy-25,1130,yy-25,'#EEF0E9')
        circle(1119,yy-6,3,C['green'] if i<4 else '#ACBC98')
        text(1104,yy,cat,17,weight=600 if i<4 else 400)
        text(919,yy,amount,18,weight=500);text(752,yy,note,14,C['muted'])
        text(422,yy,'···',22,C['muted'],anchor='start')
    line(408,686,1132,686)
    text(1128,722,'مجموع المصاريف',16,weight=600);text(916,724,'351,000',24,C['green'],700);text(777,722,'د.ع',13,C['muted'])
    text(412,721,'تعديل المجموع',13,C['muted'],anchor='start')
    parts.append('</g><g id="ChickenTracking">')
    rect(384,770,772,175,'#EDF2E6',16)
    text(1128,807,'تتبّع الدجاج',21,weight=600);text(1128,831,'أعداد فقط · خارج مجموع المصاريف',13,C['muted'])
    text(1128,908,'85',36,weight=600);text(1056,878,'الدجاج المصروف',15);text(1056,905,'دجاجة',13,C['muted'])
    line(804,863,804,917,'#D8E2CE')
    text(758,908,'206',36,weight=600);text(663,878,'الدجاج المتبقي',15);text(663,905,'دجاجة',13,C['muted'])
    text(412,804,'تعديل الأعداد',13,C['green'],anchor='start')
    parts.append('</g><g id="CashSafe">')
    rect(48,294,308,290,C['green'],16)
    icon(303,319,'wallet',C['lime']);text(285,335,'القاصة الرئيسية',18,C['paper'],600)
    text(326,382,'المبلغ الموجود بالقاصة',13,'#CBDDC8')
    text(326,430,'580,000',38,'#FCFEF5',600);text(326,457,'دينار عراقي',13,'#CBDDC8')
    rect(210,482,116,46,C['lime'],9);text(268,511,'إيداع  +',16,C['ink'],600,'middle')
    rect(78,482,116,46,'#356A51',9,'#6C907B');text(136,511,'سحب  −',16,C['paper'],600,'middle')
    text(326,561,'أنت تحدد مبلغ كل حركة',12,'#CBDDC8')
    parts.append('</g><g id="CashHistory">')
    text(356,628,'آخر حركات القاصة',21,weight=600);text(48,628,'عرض الكل',13,C['green'],anchor='start')
    for i,(label,note,amount,deposit) in enumerate([('إيداع بالقاصة','اليوم · 10:30','+ 100,000',True),('سحب من القاصة','أمس · 19:15','− 60,000',False),('إيداع بالقاصة','أمس · 14:00','+ 40,000',True)]):
        yy=674+i*89
        circle(338,yy+1,16,C['soft']);text(338,yy+7,'+' if deposit else '−',20,C['green'],500,'middle')
        text(309,yy,label,15,weight=600);text(309,yy+23,note,12,C['muted'])
        text(48,yy+5,amount,17,C['green'] if deposit else '#855C44',600,'start')
        line(48,yy+47,356,yy+47)
    text(356,950,'لكل حركة مبلغ وتاريخ وملاحظة.',13,C['muted'])
    parts.append('</g><g id="Footer">')
    text(1156,980,'نموذج تصميم · جميع الأرقام توضيحية',12,C['muted']);text(48,980,'DAFTAR / 01',11,C['muted'],anchor='start')
    parts.append('</g>')
start();dashboard();write('01-daily-expenses.svg')
def drawer(kind):
    start();dashboard();rect(0,0,1196,1000,'#17382D');
    # A light scrim keeps context visible without implying working calculations.
    parts[-1]=parts[-1].replace('fill="#17382D"','fill="#17382D" fill-opacity="0.16"')
    parts.append(f'<g id="{kind}Drawer">')
    rect(0,0,492,1000,C['paper']);line(491,0,491,1000,C['line'])
    text(452,52,'المصاريف اليومية' if kind=='Expense' else 'القاصة الرئيسية',13,C['muted']);text(38,52,'×',28,C['muted'],anchor='start')
    text(452,111,'إضافة مصروف' if kind=='Expense' else 'إيداع بالقاصة',32,weight=700)
    text(452,149,'تفاصيل بسيطة، وسجل مرتب.' if kind=='Expense' else 'حدد المبلغ اللي تريد تضيفه للقاصة.',16,C['muted'])
    if kind=='Expense':
        text(452,214,'الخانة',15,weight=600);rect(40,233,412,58,C['bg'],10,C['line']);text(430,269,'الخبز',18);text(61,269,'⌄',18,C['muted'],anchor='start')
        text(452,323,'+ إضافة خانة جديدة وحفظ اسمها',14,C['green'])
        text(452,386,'المبلغ',15,weight=600);rect(40,405,412,82,C['paper'],10,'#8EAB80');text(430,458,'60,000',32,weight=600);text(62,453,'د.ع',16,C['muted'],anchor='start')
        text(452,534,'التاريخ',15,weight=600);rect(40,553,412,58,C['bg'],10,C['line']);text(430,590,'5 تشرين الأول 2026',17);icon(62,571,'calendar')
        text(452,657,'ملاحظات',15,weight=600);text(374,657,'اختياري',13,C['muted']);rect(40,676,412,130,C['bg'],10,C['line']);text(430,711,'اكتب أي تفاصيل تحب ترجع إلها…',15,C['muted'])
        btn(40,861,412,54,'حفظ المصروف',True);text(246,953,'نموذج إضافة · لا يسجّل بيانات فعلية',12,C['muted'],anchor='middle')
    else:
        rect(40,196,412,100,C['soft'],12);text(430,233,'الموجود بالقاصة',14,C['muted']);text(430,275,'580,000',28,weight=600);text(286,271,'د.ع',14,C['muted'])
        text(452,359,'مبلغ الإيداع',15,weight=600);rect(40,378,412,82,C['paper'],10,'#8EAB80');text(430,431,'100,000',32,weight=600);text(62,426,'د.ع',16,C['muted'],anchor='start')
        text(452,519,'التاريخ',15,weight=600);rect(40,538,412,58,C['bg'],10,C['line']);text(430,575,'5 تشرين الأول 2026',17);icon(62,556,'calendar')
        text(452,657,'ملاحظات',15,weight=600);text(374,657,'اختياري',13,C['muted']);rect(40,676,412,130,C['bg'],10,C['line']);text(430,711,'مثلاً: إضافة نقدية للقاصة',15,C['muted'])
        btn(40,861,412,54,'تسجيل الإيداع',True);text(246,953,'نموذج إيداع · لا ينفّذ حركة مالية',12,C['muted'],anchor='middle')
    parts.append('</g>');write('02-add-expense.svg' if kind=='Expense' else '03-cash-deposit.svg')
drawer('Expense');drawer('Cash')
