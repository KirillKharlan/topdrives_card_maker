#!/usr/bin/env python3
"""Builds assets/data/beta_cards.json (reference cards of the beta game) from the CSV
table made from the user's screenshots. Run: python tool/make_beta_cards_json.py master.csv out.json"""
import csv, json, re, sys
def pretty(n): return re.sub(r'\s+',' ',n.replace('_',' ')).strip()
def cls(r):
    if r is None: return ''
    return 'D' if r<=5 else 'C' if r<=7 else 'B' if r<=10 else 'A' if r<=15 else 'S'
def to_int(s):
    try: return int(s)
    except: return None
def to_float(s):
    try: return float(s)
    except: return None
def year(s):
    v=to_int(s)
    if v is None: return None
    return v if v>=100 else (2000+v if v<=30 else 1900+v)
# Names read directly from the screenshots (key: top speed, 0-60). They override the automatic guess.
FIX={(217,2.1):('Audi R8 Coupe V10 Plus',2015,'DE'),(174,4.5):('Mercedes-AMG SLK Black',2007,'DE'),
 (155,5.8):('Mercedes-Benz E 500',1994,'DE'),(159,3.4):('Audi RS3 Sportback',2015,'DE'),
 (237,2.7):('Ford GT90',1995,'US'),(155,5.1):('Jaguar XF S',2016,'GB'),
 (140,5.6):('Volvo XC90 T8 Twin Engine',2016,'SE'),(195,3.9):('TVR Tuscan S',2005,'GB'),
 (155,4.3):('Mercedes-AMG S 63',2009,'DE'),(155,4.9):('BMW M135i',2016,'DE'),
 (155,5.5):('Audi S1',2014,'DE'),(138,7.3):('BMW 325i (E30)',1982,'DE'),
 (155,5.0):('Mercedes-AMG SLK 32',2004,'DE'),(178,3.1):('Audi RS6 Avant',2013,'DE'),
 (174,4.4):('Audi RS6 Plus',2004,'DE'),(208,2.5):('Audi R8 Coupe V10 Plus',2015,'DE')}
src,dst=sys.argv[1],sys.argv[2]
out=[]
for r in csv.DictReader(open(src,encoding='utf-8-sig')):
    s,z,w=to_float(r['top_speed']),to_float(r['zero_60']),to_float(r['weight'])
    if s is None or z is None: continue
    name=pretty(r['name']) if r['name'] else ''
    unsure=(not name) or ('проверить название' in r['check'])
    fx=FIX.get((int(s),z))
    yr,cn=year(r['year']),r['country']
    if fx: name,yr,cn=fx[0],fx[1],fx[2]; unsure=False
    elif not name: name=''
    if w is not None and not 500<=w<=4500: w=None            # obvious misreads (7100 ...)
    if yr is not None and not 1955<=yr<=2018: yr=None
    g=to_int(r['grip_shown']); hidden=g is not None and g<30
    if g is not None and g>130: g=None
    rating=to_int(r['rating'])
    d={'4':'4WD','R':'RWD','F':'FWD'}.get(r['drive'],'')
    e={'n':name,'y':yr,'c':cn,'r':rating,'s':s,'z':z,'w':w,'d':d,'g':None if hidden else g,'cls':cls(rating)}
    if unsure: e['q']=1
    if hidden: e['gh']=1
    out.append({k:v for k,v in e.items() if v not in (None,'')})
json.dump(out,open(dst,'w',encoding='utf-8'),ensure_ascii=False,separators=(',',':'))
print(len(out),'cards')
