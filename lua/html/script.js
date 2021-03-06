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

function doEquipmentRequestByUrl(url,cmd,onOk,onFail,dataType) {
    dataType=dataType||"text";

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
            "dataType": dataType,
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

function onStatusFail() {
}

var spectrum1,spectrum2;

function onStatusReceived(data) {
    data=eval("("+data+")");
    $("#do1").prop("checked",data.do[0]==1);
    $("#do2").prop("checked",data.do[1]==1);
    $("#do3").prop("checked",data.do[2]==1);
    $("#do4").prop("checked",data.do[3]==1);

    var r=parseInt(data.dmx.substring(2,4),16);
    var g=parseInt(data.dmx.substring(4,6),16);
    var b=parseInt(data.dmx.substring(6,8),16);
    r=Math.round(logColor(r/255)*255);
    g=Math.round(logColor(g/255)*255);
    b=Math.round(logColor(b/255)*255);
    spectrum1.spectrum("set",{r:r,g:g,b:b});
    spectrum1.spectrum("show");

//    x1="ff"+b2h[rl1]+b2h[gl1]+b2h[bl1]+"00 00 00 00 00 00";
//    x2="00 ff 00 ff"+b2h[rl2]+b2h[gl2]+b2h[bl2]+b2h[wl2]+"00 00";

    r=parseInt(data.dmx.substring(28,30),16);
    g=parseInt(data.dmx.substring(30,32),16);
    b=parseInt(data.dmx.substring(32,34),16);
    r=Math.round(logColor(r/255)*255);
    g=Math.round(logColor(g/255)*255);
    b=Math.round(logColor(b/255)*255);
    spectrum2.spectrum("set",{r:r,g:g,b:b});
    spectrum2.spectrum("show");

}

function getStatus() {
    doEquipmentRequestByName("COMBO","state",onStatusReceived,onStatusFail)
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

function dmxControl(r1,g1,b1,r2,g2,b2) {
    var rl1=Math.round(expColor(r1)*255);
    var gl1=Math.round(expColor(g1)*255);
    var bl1=Math.round(expColor(b1)*255);

    var rl2=Math.round(expColor(r2)*255);
    var gl2=Math.round(expColor(g2)*255);
    var bl2=Math.round(expColor(b2)*255);
    var wl2=Math.min(rl2,gl2,bl2)

//    $("#combo-warning").text(rl+","+gl+","+bl);
//    cmd="dmx=ff"+b2h[rl]+b2h[gl]+b2h[bl]+"0000000000";

    x1="ff"+b2h[rl1]+b2h[gl1]+b2h[bl1]+"000000000000";
    x2="00ff00ff"+b2h[rl2]+b2h[gl2]+b2h[bl2]+b2h[wl2]+"0000";
    cmd="dmx="+x1+x2;

    doEquipmentRequestByName("COMBO",cmd);
}

var savedDmx={
    r1:0, b1:0, g1:0,
    r2:0, b2:0, g2:0
};

function onChangeDmx1(c) {
    savedDmx.r1=c._r/255;
    savedDmx.g1=c._g/255;
    savedDmx.b1=c._b/255;
    dmxControl(savedDmx.r1,savedDmx.g1,savedDmx.b1,savedDmx.r2,savedDmx.g2,savedDmx.b2);
}
function onChangeDmx2(c) {
    savedDmx.r2=c._r/255;
    savedDmx.g2=c._g/255;
    savedDmx.b2=c._b/255;
    dmxControl(savedDmx.r1,savedDmx.g1,savedDmx.b1,savedDmx.r2,savedDmx.g2,savedDmx.b2);
}

$(function() {
    $("input.smoke").click(function() { smoke(this.value); });


    $("#do1").change(function() { doControl(1,$(this).get(0).checked); });
    $("#do2").change(function() { doControl(2,$(this).get(0).checked); });
    $("#do3").change(function() { doControl(3,$(this).get(0).checked); });
    $("#do4").change(function() { doControl(4,$(this).get(0).checked); });

    spectrum1=$("#dmx1").spectrum({
        color: "#000",
        flat: true,
        showInput: true,
        showPalette: true,
        showInput: false,
        palette: [
            ["#000","#444","#666","#999","#ccc","#eee","#f3f3f3","#fff"],
            ["#f00","#f90","#ff0","#0f0","#0ff","#00f","#90f","#f0f"],
            ["#f4cccc","#fce5cd","#fff2cc","#d9ead3","#d0e0e3","#cfe2f3","#d9d2e9","#ead1dc"],
            ["#ea9999","#f9cb9c","#ffe599","#b6d7a8","#a2c4c9","#9fc5e8","#b4a7d6","#d5a6bd"],
            ["#e06666","#f6b26b","#ffd966","#93c47d","#76a5af","#6fa8dc","#8e7cc3","#c27ba0"],
            ["#c00","#e69138","#f1c232","#6aa84f","#45818e","#3d85c6","#674ea7","#a64d79"],
            ["#900","#b45f06","#bf9000","#38761d","#134f5c","#0b5394","#351c75","#741b47"],
            ["#600","#783f04","#7f6000","#274e13","#0c343d","#073763","#20124d","#4c1130"]
        ],
        clickoutFiresChange: true,
        showButtons: false,
        move: function(c) { onChangeDmx1(c); },
//        show: function(c) { onChangeDmx1(c); },
        hide: function(c) { onChangeDmx1(c); },
//        beforeShow: function(c) { onChangeDmx1(c); },
    });

    spectrum2=$("#dmx2").spectrum({
        color: "#000",
        flat: true,
        showInput: true,
        showPalette: true,
        showInput: false,
        palette: [
            ["#000","#444","#666","#999","#ccc","#eee","#f3f3f3","#fff"],
            ["#f00","#f90","#ff0","#0f0","#0ff","#00f","#90f","#f0f"],
            ["#f4cccc","#fce5cd","#fff2cc","#d9ead3","#d0e0e3","#cfe2f3","#d9d2e9","#ead1dc"],
            ["#ea9999","#f9cb9c","#ffe599","#b6d7a8","#a2c4c9","#9fc5e8","#b4a7d6","#d5a6bd"],
            ["#e06666","#f6b26b","#ffd966","#93c47d","#76a5af","#6fa8dc","#8e7cc3","#c27ba0"],
            ["#c00","#e69138","#f1c232","#6aa84f","#45818e","#3d85c6","#674ea7","#a64d79"],
            ["#900","#b45f06","#bf9000","#38761d","#134f5c","#0b5394","#351c75","#741b47"],
            ["#600","#783f04","#7f6000","#274e13","#0c343d","#073763","#20124d","#4c1130"]
        ],
        clickoutFiresChange: true,
        showButtons: false,
        move: function(c) { onChangeDmx2(c); },
//        show: function(c) { onChangeDmx2(c); },
        hide: function(c) { onChangeDmx2(c); },
//        beforeShow: function(c) { onChangeDmx2(c); },
    });

    getStatus();

    $(".loading").hide();
    $("#mainContent").show();
})

