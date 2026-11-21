#!/usr/bin/env python3
"""Builds assets/data/beta_cards.json (reference cards of the beta game) from the CSV
table made from the user's screenshots. Run: python tool/make_beta_cards_json.py master.csv out.json
By default the upgraded copies of a car are dropped (see drop_upgraded); add --keep-upgraded to keep every card."""
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
keep_upgraded='--keep-upgraded' in sys.argv[3:]

def hidden_grip(e):
    return 100.0 if 'gh' in e else e.get('g')
def stronger_by(a,b):
    """How much stronger card a is than card b, in 'tolerance' units (the same ones the app's matcher uses:
    8 mph, 0.4 s, 100 weight, 6 grip, 1.5 RQ). Above 0 means a is stronger. Every term is cut at +-3 so one
    misread number (a grip of 41 on a V10) cannot decide alone."""
    total=0.0; n=0
    def term(x,y,tol,sign,weight=1.0):
        nonlocal total,n
        if x is None or y is None: return
        total+=weight*max(-3.0,min(3.0,sign*(x-y)/tol)); n+=1
    term(a.get('s'),b.get('s'),8,1)
    term(a.get('z'),b.get('z'),0.4,-1)
    term(a.get('w'),b.get('w'),100,-1)
    term(hidden_grip(a),hidden_grip(b),6,1)
    term(a.get('r'),b.get('r'),1.5,1,1.2)
    return total if n else 0.0
def drop_upgraded(cards):
    """Cards that are the same car (same name and year) are the stock car and its upgraded versions. The weakest one
    is the stock car and stays, the stronger ones go. A card without a year joins the car of its name when the name
    has only one year. A card whose name is uncertain never counts as the stock car while a sure one exists
    (it is usually a misread copy of that card). Cars of the same name but other years are different cars."""
    by_name={}
    for i,e in enumerate(cards):
        name=e.get('n','').strip().lower()
        if name: by_name.setdefault(name,[]).append(i)
    drop=set(); report=[]
    for name,idxs in by_name.items():
        if len(idxs)<2: continue
        years={cards[i]['y'] for i in idxs if 'y' in cards[i]}
        buckets={}
        for i in idxs:
            y=cards[i].get('y')
            if y is None:
                if len(years)!=1: continue
                y=next(iter(years))
            buckets.setdefault(y,[]).append(i)
        for y,b in buckets.items():
            if len(b)<2: continue
            cands=[i for i in b if 'q' not in cards[i]] or b
            keep=min(cands,key=lambda i: sum(stronger_by(cards[i],cards[j]) for j in b if j!=i))
            gone=[j for j in b if j!=keep]
            drop.update(gone); report.append((name,y,keep,gone))
    return [e for i,e in enumerate(cards) if i not in drop],report
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
if not keep_upgraded:
    before=out
    out,report=drop_upgraded(out)
    for name,y,keep,gone in report:
        print(f'{name} {y}: kept',before[keep],'| removed',[before[j] for j in gone])
json.dump(out,open(dst,'w',encoding='utf-8'),ensure_ascii=False,separators=(',',':'))
print(len(out),'cards')
