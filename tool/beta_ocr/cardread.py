import cv2, numpy as np, json, re, collections
from glyphs import *
from ocr1280 import BOX, crop, white_mask, tess, vote, NUM
stc=np.load('stcent.npy'); stmap={0:'1',12:'1',1:'0',2:'7',3:'4',4:'5',5:'2',6:'6',7:'6',8:'8',9:'.',10:'9',11:'3',13:'3'}
rqc=np.load('rqcent.npy'); rqmap={0:'1',10:'1',1:'5',2:'4',11:'4',3:'7',4:'0',5:'8',6:'9',7:'2',8:'3',9:'6'}
drc=np.load('drivecent.npy'); drmap={0:'R',1:'4',2:'F'}
def classify(g,cent,mp):
    v=norm(g).astype(np.float32).ravel()/255
    d=((cent-v)**2).sum(1); k=int(d.argmin()); return mp[k], float(d[k])
def glyph_field(im,f,floor=150):
    comps,(W,H)=components(crop(im,f),floor=floor)
    comps=[c for c in comps if c[3]>0.2*H or (c[3]>0.05*H and c[2]<0.2*H)]
    out='';worst=0
    for c in comps:
        ch,d=classify(c[4],stc,stmap); out+=ch; worst=max(worst,d)
    return out,worst
def glyph_rq(im):
    comps,(W,H)=components(crop(im,'rq'),floor=170)
    comps=[c for c in comps if c[3]>0.25*H and c[3]<0.9*H]
    out='';worst=0
    for c in comps:
        ch,d=classify(c[4],rqc,rqmap); out+=ch; worst=max(worst,d)
    return out,worst
def glyph_drive(im):
    comps,(W,H)=components(crop(im,'drive'),floor=150)
    comps=[c for c in comps if c[3]>0.3*H]
    if len(comps)!=1: return '',99
    return classify(comps[0][4],drc,drmap)
pat={'speed':r'\d{2,3}','accel':r'\d{1,2}\.\d','weight':r'\d{3,4}','grip':r'\d{2}','year':r'\d{2}','rq':r'\d{1,2}'}
rng={'speed':(50,300),'accel':(1.5,40),'weight':(400,4500),'grip':(20,99),'year':(0,99),'rq':(1,25)}
def ok(f,s):
    if not re.fullmatch(pat[f],s or ''): return False
    v=float(s); a,b=rng[f]; return a<=v<=b
def read_card(im):
    o={}
    bad=0
    for f in ['speed','accel','weight','grip','year']:
        s,w=glyph_field(im,f); o[f]=s if ok(f,s) else ''; o[f+'_d']=round(w,1)
        if not o[f]: bad+=1
    s,w=glyph_rq(im); o['rq']=s if ok('rq',s) else ''; o['rq_d']=round(w,2)
    d,dd=glyph_drive(im); o['drive']=d; o['drive_d']=round(dd,1)
    o['country'],_=tess(white_mask(crop(im,'country')),'--psm 7 -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZ')
    o['name'],o['name_conf']=tess(white_mask(crop(im,'name'),floor=120),'--psm 7 -c preserve_interword_spaces=1')
    o['bad']=bad
    return o
