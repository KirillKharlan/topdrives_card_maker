import cv2, numpy as np, os, re, sys, json, collections
import pytesseract
D=os.environ.get('CARDS_DIR','cards/')   # folder with the 1280x764 screenshots (the open card with PICK / UPGRADE / SELL buttons)
BOX={ 'name':(400,196,830,230), 'year':(836,196,890,230), 'country':(893,196,942,230),
 'speed':(840,240,938,284), 'accel':(840,324,938,368), 'weight':(840,408,938,454),
 'drive':(842,490,884,536), 'grip':(894,490,940,536), 'rq':(338,486,390,540), 'tier':(380,584,900,622)}
def crop(im,k,box=BOX):
    x0,y0,x1,y1=box[k]; return im[y0:y1,x0:x1]
def white_mask(img, scale=3, floor=110, bias=0, clean=True):
    m=np.min(img,axis=2)
    m=cv2.resize(m,None,fx=scale,fy=scale,interpolation=cv2.INTER_CUBIC)
    t,_=cv2.threshold(m,0,255,cv2.THRESH_BINARY+cv2.THRESH_OTSU)
    t=int(max(floor,min(235,t+bias)))
    _,b=cv2.threshold(m,t,255,cv2.THRESH_BINARY)
    if clean:  # drop thin bright lines (box edges) that touch the border
        n,lab,stats,_=cv2.connectedComponentsWithStats(b,connectivity=8)
        h,w=b.shape
        for i in range(1,n):
            x,y,cw,ch,area=stats[i]
            touches=x<=1 or y<=1 or x+cw>=w-1 or y+ch>=h-1
            thin=cw<=max(4,w*0.07) or ch<=max(4,h*0.07)
            if touches and thin and (ch>h*0.5 or cw>w*0.5): b[lab==i]=0
    b=255-b
    return cv2.copyMakeBorder(b,14,14,14,14,cv2.BORDER_CONSTANT,value=255)
def tess(mask,cfg):
    d=pytesseract.image_to_data(mask,config=cfg,output_type=pytesseract.Output.DICT)
    words=[(w,float(c)) for w,c in zip(d['text'],d['conf']) if w.strip() and float(c)>=0]
    return ' '.join(w for w,_ in words).strip(), min([c for _,c in words],default=0)
VARS=[dict(scale=3),dict(scale=4,bias=-10),dict(scale=2,bias=10),dict(scale=3,floor=150),dict(scale=5,bias=-20,floor=100)]
def vote(img,cfg,pattern,variants=VARS,need=2):
    """Run the variants one by one and stop as soon as `need` of them agree."""
    res=[]
    for v in variants:
        t,c=tess(white_mask(img,**v),cfg)
        t=t.replace(' ','')
        if re.fullmatch(pattern,t): res.append(t)
        cnt=collections.Counter(res)
        if cnt and cnt.most_common(1)[0][1]>=need: break
    if not res: return '',0.0
    best,n=collections.Counter(res).most_common(1)[0]
    return best,n/len(variants)
NUM='--psm 7 -c tessedit_char_whitelist=0123456789.'
def read(f):
    im=cv2.imread(D+f)
    o={'file':f}
    o['name'],o['name_conf']=tess(white_mask(crop(im,'name'),floor=120),'--psm 7 -c preserve_interword_spaces=1')
    o['year'],o['year_a']=vote(crop(im,'year'),NUM,r'\d{2}')
    o['country'],o['country_conf']=tess(white_mask(crop(im,'country')),'--psm 7 -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZ')
    o['speed'],o['speed_a']=vote(crop(im,'speed'),NUM,r'\d{2,3}')
    o['accel'],o['accel_a']=vote(crop(im,'accel'),NUM,r'\d{1,2}\.?\d')
    o['weight'],o['weight_a']=vote(crop(im,'weight'),NUM,r'\d{3,4}')
    o['drive'],o['drive_a']=vote(crop(im,'drive'),'--psm 10 -c tessedit_char_whitelist=RF4',r'[RF4]')
    o['grip'],o['grip_a']=vote(crop(im,'grip'),NUM,r'\d{2}')
    o['rq'],o['rq_a']=vote(crop(im,'rq'),NUM,r'\d{1,2}',[dict(scale=3,floor=150),dict(scale=4,floor=150),dict(scale=2,floor=150),dict(scale=3,floor=200),dict(scale=5,floor=170)])
    o['tier'],o['tier_conf']=tess(white_mask(crop(im,'tier'),floor=150),'--psm 7')
    return o
if __name__=='__main__':
    for f in sys.argv[1:]:
        print(read(f))
