import math
a=6378245.0; ee=0.00669342162296594323
def _tl(x,y):
    r=-100.0+2.0*x+3.0*y+0.2*y*y+0.1*x*y+0.2*math.sqrt(abs(x))
    r+=(20.0*math.sin(6.0*x*math.pi)+20.0*math.sin(2.0*x*math.pi))*2.0/3.0
    r+=(20.0*math.sin(y*math.pi)+40.0*math.sin(y/3.0*math.pi))*2.0/3.0
    r+=(160.0*math.sin(y/12.0*math.pi)+320*math.sin(y*math.pi/30.0))*2.0/3.0
    return r
def _tn(x,y):
    r=300.0+x+2.0*y+0.1*x*x+0.1*x*y+0.1*math.sqrt(abs(x))
    r+=(20.0*math.sin(6.0*x*math.pi)+20.0*math.sin(2.0*x*math.pi))*2.0/3.0
    r+=(20.0*math.sin(x*math.pi)+40.0*math.sin(x/3.0*math.pi))*2.0/3.0
    r+=(150.0*math.sin(x/12.0*math.pi)+300.0*math.sin(x/30.0*math.pi))*2.0/3.0
    return r
def wgs2gcj(lat,lon):
    dlat=_tl(lon-105.0,lat-35.0); dlon=_tn(lon-105.0,lat-35.0)
    rl=lat/180.0*math.pi; m=math.sin(rl); m=1-ee*m*m; sm=math.sqrt(m)
    dlat=(dlat*180.0)/((a*(1-ee))/(m*sm)*math.pi); dlon=(dlon*180.0)/(a/sm*math.cos(rl)*math.pi)
    return lat+dlat, lon+dlon
def gcj2wgs(lat,lon):  # iterative inverse, sub-metre
    w=(lat,lon)
    for _ in range(10):
        g=wgs2gcj(*w); w=(w[0]-(g[0]-lat), w[1]-(g[1]-lon))
    return w
def dist(a,b,c,d):
    R=6371000;p1,p2=math.radians(a),math.radians(c);h=math.sin((p2-p1)/2)**2+math.cos(p1)*math.cos(p2)*math.sin(math.radians(d-b)/2)**2;return round(2*R*math.asin(math.sqrt(h)))
