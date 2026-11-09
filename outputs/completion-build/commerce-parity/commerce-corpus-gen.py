import random,json
r=random.Random(73133)
a=[]
for i in range(200):
 lines=[{'u':r.randint(1,1000000),'p':r.randint(0,1000000)} for _ in range(3)]
 # sale discount uses zero to avoid source subtotal dependency in generator; later allocate nonzero bounded discount1.
 gross=sum((x['u']*x['p']+500)//1000 for x in lines)
 sold=lines[0]['u'];prior=r.randint(0,sold-1);additional=r.randint(1,sold-prior)
 amount=r.randint(1,1000000);daily=r.randint(0,amount)
 a.append({'lines':lines,'discount':r.randint(0,gross),'prior':prior,'additional':additional,'amount':amount,'daily':daily,'due':r.randint(0,amount),'debt':amount,'snap':r.randint(0,1000000),'spent0':r.randint(0,1000000),'spent1':r.randint(0,1000000),'trans0':r.randint(0,1000000),'trans1':r.randint(0,1000000),'sales0':r.randint(-1000000,1000000),'sales1':r.randint(-1000000,1000000)})
json.dump(a,open('/tmp/commerce-corpus.json','w'))
