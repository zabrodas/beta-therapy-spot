function rgb2hsv(rgb) {
    var r=rgb[0], g=rgb[1], b=rgb[2];
    var h,s,v,m,d;
    v=Math.max(r,g,b);
    m=Math.min(r,g,b);
    d=v-m;
    s= v==0 ? 0 : 1-m/v;
    if (v==m) h=0;
    else if (v==r && g<b) h=60*(g-b)/d+360;
    else if (v==g) h=60*(b-r)/d+120;
    else if (v==b) h=60*(r-g)/d+240;
    else if (v==r && g>=b) h=60*(g-b)/d+0;
    else h=0;
    return [h,s,v];
}

function hsv2rgb(hsv) {
    var h=hsv[0], s=hsv[1], v=hsv[2];
    var r,g,b,hi,f,p,q,t;
    hi=Math.floor(h/60);
    f=h/60-hi; if (hi>=6) h-=6;
    p=v*(1-s);
    q=v*(1-f*s);
    t=v*(1-(1-f)*s);
    switch(hi) {
        case 0: r=v; g=t; b=p; break;
        case 1: r=q; g=v; b=p; break;
        case 2: r=p; g=v; b=t; break;
        case 3: r=p; g=q; b=v; break;
        case 4: r=t; g=p; b=v; break;
        case 5: r=v; g=p; b=q; break;
    }
    return [r,g,b];
}

function expColor(x) {
    return (Math.exp(x*4.498717586511349)-1)*0.01124837046372007;
}

