var playlist=[];
var equipment_port=8080;

var equipment_list={

    "COMBO": {
        "gui": "#combo-controls",
        "warning": "#combo-warning",
        "url": ""
    }
}

$.each(equipment_list, function(n,s) {
    s.errCnt=0;
})

function getHighOfMyIp() {
    var a=$("<a></a>");
    a.prop("href",document.location);
    var host=a.prop("hostname");
    var splittedHost=host.split(".",4);
    if (splittedHost.length!=4) { alert("Can't get own IP:"+splittedHost); return null; }
    var myIpHigh=splittedHost[0]+'.'+splittedHost[1]+'.'+splittedHost[2]+'.';
    return [ myIpHigh, Number(splittedHost[3]) ];
}


var equipmentRequestCnt=0;

function doEquipmentRequestByName(equipment,cmd,onOk,onFail) {
    console.info("doEquipmentRequestByName "+equipment+" "+equipment_list[equipment].url);
    doEquipmentRequestByUrl(equipment_list[equipment].url,cmd,onOk,onFail);
}

function doEquipmentRequestByUrl(url,cmd,onOk,onFail) {
    if (url==null) {
        if (onFail!=null) onFail();
        return;
    }

    if (equipmentRequestCnt>1) {
        console.info("Drop request "+url);
        if (onFail!=null) onFail();
        return;
    }

    var settings=
        {
            "cache": false,
            "success": function(data) {
                equipmentRequestCnt--;
                if (onOk!=null) onOk(data);
            },
            "error": function() {
                equipmentRequestCnt--;
                if (onFail!=null) onFail();
            },
            "dataType": "text",
            "timeout": 1000,
            "nextRequest": null
        };

//    console.info("Send request "+url);        
    equipmentRequestCnt++;
    $.ajax(url+"/"+cmd+".", settings);
}

function equipmentTest(equipment) {
    console.info("equipmentTest("+equipment+")");
    doEquipmentRequestByName(
        equipment,
        "test",
        function() {
            console.info("Test "+equipment+" OK");
            equipment_list[equipment].errCnt=0;
            $(equipment_list[equipment].warning).fadeTo(500,0);
            setTimeout(function() { equipmentTest(equipment); },20000);
        },
        function() {
            console.info("Test "+equipment+" Fail. Cnt="+equipment_list[equipment].errCnt);
            $(equipment_list[equipment].warning).fadeTo(500,1);
            if (++equipment_list[equipment].errCnt>10) {
                equipment_list[equipment].url=null;
                scanForEquipment();
            } else {
                setTimeout(function() { equipmentTest(equipment); },5000);
            }
        }
    );
}

function doControl(index,value) {
    cmd= (value!=0 ? "on": "off")+index;
    doEquipmentRequestByName("COMBO",cmd);
}

function smoke(dur) {
    cmd= "smoke"+dur;
    doEquipmentRequestByName("COMBO",cmd);
}


var b2h=[];
for (var i=0; i<16; i++) {
    for (var j=0; j<16; j++) {
        var h="0123456789ABCDEF";
        var hh=h[i]+h[j];
        b2h.push(hh);
    }
}

function hexcolor(c) {
    var rl=Math.round(c[0]*255);
    var gl=Math.round(c[1]*255);
    var bl=Math.round(c[2]*255);
    return "#"+b2h[rl]+b2h[gl]+b2h[bl];
}

function dmxControl(r,g,b) {
    var rl=Math.round(expColor(r)*255);
    var gl=Math.round(expColor(g)*255);
    var bl=Math.round(expColor(b)*255);
//    $("#combo-warning").text(rl+","+gl+","+bl);
    cmd="dmx=ff"+b2h[rl]+b2h[gl]+b2h[bl]+"0000000000";
    doEquipmentRequestByName("COMBO",cmd);
}



var dmxMarkerX=0,dmxMarkerY=0;
var dmxHSV=[0,0,0], dmxRGB=[0,0,0];

function g2(c0,c1) {
    return "linear-gradient(left, "+hexcolor(c0)+" 0%,"+hexcolor(c1)+" 100%);";
}
function g6(c0,c1,c2,c3,c4,c5,c6) {
    return "linear-gradient(left,"+hexcolor(c0)+" 0%,"+hexcolor(c1)+" 17%,"+hexcolor(c2)+" 33%,"+hexcolor(c3)+" 50%,"+hexcolor(c4)+" 67%,"+hexcolor(c5)+" 83%,"+hexcolor(c6)+" 100%);";
}
function gab(g) {
    var s=
        "background: "+g+
        "background: -webkit-"+g+
        "background: -moz-"+g+
        "background: -ms-"+g;
    return s;
}

function gradR() {
    var c0=[0,dmxRGB[1],dmxRGB[2]];
    var c1=[1,dmxRGB[1],dmxRGB[2]];
    $("#r").val(dmxRGB[0]);
    $("#tr").attr("style",gab(g2(c0,c1)));
}
function gradG() {
    var c0=[dmxRGB[0],0,dmxRGB[2]];
    var c1=[dmxRGB[0],1,dmxRGB[2]];
    $("#g").val(dmxRGB[1]);
    $("#tg").attr("style",gab(g2(c0,c1)));
}
function gradB() {
    var c0=[dmxRGB[0],dmxRGB[1],0];
    var c1=[dmxRGB[0],dmxRGB[1],1];
    $("#b").val(dmxRGB[2]);
    $("#tb").attr("style",gab(g2(c0,c1)));
}
function gradH() {
    var c0=hsv2rgb([0,dmxHSV[1],dmxHSV[2]]);
    var c1=hsv2rgb([60,dmxHSV[1],dmxHSV[2]]);
    var c2=hsv2rgb([120,dmxHSV[1],dmxHSV[2]]);
    var c3=hsv2rgb([180,dmxHSV[1],dmxHSV[2]]);
    var c4=hsv2rgb([240,dmxHSV[1],dmxHSV[2]]);
    var c5=hsv2rgb([300,dmxHSV[1],dmxHSV[2]]);
    $("#h").val(dmxHSV[0]);
    $("#th").attr("style",gab(g6(c0,c1,c2,c3,c4,c5,c0)));
}
function gradS() {
    var c0=hsv2rgb([dmxHSV[0],0,dmxHSV[2]]);
    var c1=hsv2rgb([dmxHSV[0],1,dmxHSV[2]]);
    $("#s").val(dmxHSV[1]);
    $("#ts").attr("style",gab(g2(c0,c1)));
}
function gradV() {
    var c0=hsv2rgb([dmxHSV[0],dmxHSV[1],0]);
    var c1=hsv2rgb([dmxHSV[0],dmxHSV[1],1]);
    $("#v").val(dmxHSV[2]);
    $("#tv").attr("style",gab(g2(c0,c1)));
}
function gradAll() {
    gradR();
    gradG();
    gradB();
    gradH();
    gradS();
    gradV();
}

function dmxOnChangeH(value) {
    dmxHSV[0]=value;
    dmxRGB=hsv2rgb(dmxHSV);
    dmxControl(dmxRGB[0],dmxRGB[1],dmxRGB[2]);
    gradAll();
}
function dmxOnChangeS(value) {
    dmxHSV[1]=value;
    dmxRGB=hsv2rgb(dmxHSV);
    dmxControl(dmxRGB[0],dmxRGB[1],dmxRGB[2]);
    gradAll();
}
function dmxOnChangeV(value) {
    dmxHSV[2]=value;
    dmxRGB=hsv2rgb(dmxHSV);
    dmxControl(dmxRGB[0],dmxRGB[1],dmxRGB[2]);
    gradAll();
}
function dmxOnChangeR(value) {
    dmxRGB[0]=value;
    dmxHSV=rgb2hsv(dmxRGB);
    dmxControl(dmxRGB[0],dmxRGB[1],dmxRGB[2]);
    gradAll();
}
function dmxOnChangeG(value) {
    dmxRGB[1]=value;
    dmxHSV=rgb2hsv(dmxRGB);
    dmxControl(dmxRGB[0],dmxRGB[1],dmxRGB[2]);
    gradAll();
}
function dmxOnChangeB(value) {
    dmxRGB[2]=value;
    dmxHSV=rgb2hsv(dmxRGB);
    dmxControl(dmxRGB[0],dmxRGB[1],dmxRGB[2]);
    gradAll();
}

function onResizeDmxWrapper() {
    var w=$(window).width();
    $(".colorslider").width(w*0.9);
}


$(function() {
    $("input.smoke").click(function() { smoke(this.value); });


    $("#do1").change(function() { doControl(1,$(this).get(0).checked); });
    $("#do2").change(function() { doControl(2,$(this).get(0).checked); });
    $("#do3").change(function() { doControl(3,$(this).get(0).checked); });
    $("#do4").change(function() { doControl(4,$(this).get(0).checked); });

    $(window).resize(onResizeDmxWrapper); onResizeDmxWrapper();

    $("#h").get(0).oninput=function() { dmxOnChangeH(this.value); };
    $("#s").get(0).oninput=function() { dmxOnChangeS(this.value); };
    $("#v").get(0).oninput=function() { dmxOnChangeV(this.value); };
    $("#r").get(0).oninput=function() { dmxOnChangeR(this.value); };
    $("#g").get(0).oninput=function() { dmxOnChangeG(this.value); };
    $("#b").get(0).oninput=function() { dmxOnChangeB(this.value); };
    dmxOnChangeS(1);
    gradAll();
})

