import cv2, numpy as np, os, json, collections
from ocr1280 import BOX, crop, D
GW,GH=20,32
def components(img, scale=4, floor=150, bias=0):
    """white glyphs on a colored box -> list of (x,y,w,h, binary image) left to right"""
    m=np.min(img,axis=2)
    m=cv2.resize(m,None,fx=scale,fy=scale,interpolation=cv2.INTER_CUBIC)
    t,_=cv2.threshold(m,0,255,cv2.THRESH_BINARY+cv2.THRESH_OTSU)
    t=int(max(floor,min(235,t+bias)))
    _,b=cv2.threshold(m,t,255,cv2.THRESH_BINARY)
    n,lab,stats,_=cv2.connectedComponentsWithStats(b,connectivity=8)
    H,W=b.shape; out=[]
    for i in range(1,n):
        x,y,w,h,a=stats[i]
        if a<12*scale*scale/4: continue
        if (x<=1 or x+w>=W-1) and w<=0.07*W+3: continue     # box edge lines
        if h>0.97*H: continue
        out.append((x,y,w,h,(lab[y:y+h,x:x+w]==i).astype(np.uint8)*255))
    out.sort(key=lambda c:c[0])
    return out,(W,H)
def norm(g):
    """glyph image -> fixed vector: scale to height GH keeping the aspect (max width GW)"""
    h,w=g.shape
    s=GH/h
    nw=max(1,min(GW,int(round(w*s))))
    r=cv2.resize(g,(nw,GH),interpolation=cv2.INTER_AREA)
    canvas=np.zeros((GH,GW),np.uint8)
    x0=(GW-nw)//2
    canvas[:,x0:x0+nw]=r
    return canvas
