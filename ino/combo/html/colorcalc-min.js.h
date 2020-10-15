R"EOF(

function rgb2hsv(r){var a,e,t,n,o,c=r[0],s=r[1],h=r[2];return t=Math.max(c,s,h),n=Math.min(c,s,h),o=t-n,e=0==t?0:1-n/t,a=t==n?0:t==c&&s<h?60*(s-h)/o+360:t==s?60*(h-c)/o+120:t==h?60*(c-s)/o+240:t==c&&s>=h?60*(s-h)/o+0:0,[a,e,t]}function hsv2rgb(r){var a,e,t,n,o,c,s,h,u=r[0],b=r[1],i=r[2];switch(n=Math.floor(u/60),o=u/60-n,n>=6&&(u-=6),c=i*(1-b),s=i*(1-o*b),h=i*(1-(1-o)*b),n){case 0:a=i,e=h,t=c;break;case 1:a=s,e=i,t=c;break;case 2:a=c,e=i,t=h;break;case 3:a=c,e=s,t=i;break;case 4:a=h,e=c,t=i;break;case 5:a=i,e=c,t=s}return[a,e,t]}function expColor(r){return.01124837046372007*(Math.exp(4.498717586511349*r)-1)}function logColor(r){return Math.log(r/.01124837046372007+1)/4.498717586511349}

)EOF"