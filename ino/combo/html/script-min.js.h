R"EOF(

var playlist=[],equipment_port=8080,equipment_list={COMBO:{gui:"#combo-controls",warning:"#combo-warning",url:""}};function getHighOfMyIp(){var e=$("<a></a>");e.prop("href",document.location);var t=e.prop("hostname").split(".",4);return 4!=t.length?(alert("Can't get own IP:"+t),null):[t[0]+"."+t[1]+"."+t[2]+".",Number(t[3])]}$.each(equipment_list,function(e,t){t.errCnt=0});var equipmentRequestCnt=0,spectrum1,spectrum2;function doEquipmentRequestByName(e,t,n,o){console.info("doEquipmentRequestByName "+e+" "+equipment_list[e].url),doEquipmentRequestByUrl(equipment_list[e].url,t,n,o)}function doEquipmentRequestByUrl(e,t,n,o,a){if(a=a||"text",null!=e){if(1<equipmentRequestCnt)return console.info("Drop request "+e),void(null!=o&&o());var c={cache:!1,success:function(e){equipmentRequestCnt--,null!=n&&n(e)},error:function(){equipmentRequestCnt--,null!=o&&o()},dataType:a,timeout:1e3,nextRequest:null};equipmentRequestCnt++,$.ajax(e+"/"+t+".",c)}else null!=o&&o()}function equipmentTest(e){console.info("equipmentTest("+e+")"),doEquipmentRequestByName(e,"test",function(){console.info("Test "+e+" OK"),equipment_list[e].errCnt=0,$(equipment_list[e].warning).fadeTo(500,0),setTimeout(function(){equipmentTest(e)},2e4)},function(){console.info("Test "+e+" Fail. Cnt="+equipment_list[e].errCnt),$(equipment_list[e].warning).fadeTo(500,1),10<++equipment_list[e].errCnt?(equipment_list[e].url=null,scanForEquipment()):setTimeout(function(){equipmentTest(e)},5e3)})}function doControl(e,t){cmd=(0!=t?"on":"off")+e,doEquipmentRequestByName("COMBO",cmd)}function smoke(e){cmd="smoke"+e,doEquipmentRequestByName("COMBO",cmd)}function onStatusFail(){}function onStatusReceived(data){data=eval("("+data+")"),$("#do1").prop("checked",1==data.do[0]),$("#do2").prop("checked",1==data.do[1]),$("#do3").prop("checked",1==data.do[2]),$("#do4").prop("checked",1==data.do[3]);var r=parseInt(data.dmx.substring(2,4),16),g=parseInt(data.dmx.substring(4,6),16),b=parseInt(data.dmx.substring(6,8),16),r=Math.round(255*logColor(r/255)),g=Math.round(255*logColor(g/255)),b=Math.round(255*logColor(b/255));spectrum1.spectrum("set",{r:r,g:g,b:b}),spectrum1.spectrum("show"),r=parseInt(data.dmx.substring(28,30),16),g=parseInt(data.dmx.substring(30,32),16),b=parseInt(data.dmx.substring(32,34),16),r=Math.round(255*logColor(r/255)),g=Math.round(255*logColor(g/255)),b=Math.round(255*logColor(b/255)),spectrum2.spectrum("set",{r:r,g:g,b:b}),spectrum2.spectrum("show")}function getStatus(){doEquipmentRequestByName("COMBO","state",onStatusReceived,onStatusFail)}for(var b2h=[],i=0;i<16;i++)for(var j=0;j<16;j++){var h="0123456789ABCDEF",hh=h[i]+h[j];b2h.push(hh)}function hexcolor(e){var t=Math.round(255*e[0]),n=Math.round(255*e[1]),o=Math.round(255*e[2]);return"#"+b2h[t]+b2h[n]+b2h[o]}function dmxControl(e,t,n,o,a,c){var d=Math.round(255*expColor(e)),u=Math.round(255*expColor(t)),r=Math.round(255*expColor(n)),f=Math.round(255*expColor(o)),s=Math.round(255*expColor(a)),i=Math.round(255*expColor(c)),m=Math.min(f,s,i);x1="ff"+b2h[d]+b2h[u]+b2h[r]+"000000000000",x2="00ff00ff"+b2h[f]+b2h[s]+b2h[i]+b2h[m]+"0000",cmd="dmx="+x1+x2,doEquipmentRequestByName("COMBO",cmd)}var savedDmx={r1:0,b1:0,g1:0,r2:0,b2:0,g2:0};function onChangeDmx1(e){savedDmx.r1=e._r/255,savedDmx.g1=e._g/255,savedDmx.b1=e._b/255,dmxControl(savedDmx.r1,savedDmx.g1,savedDmx.b1,savedDmx.r2,savedDmx.g2,savedDmx.b2)}function onChangeDmx2(e){savedDmx.r2=e._r/255,savedDmx.g2=e._g/255,savedDmx.b2=e._b/255,dmxControl(savedDmx.r1,savedDmx.g1,savedDmx.b1,savedDmx.r2,savedDmx.g2,savedDmx.b2)}$(function(){$("input.smoke").click(function(){smoke(this.value)}),$("#do1").change(function(){doControl(1,$(this).get(0).checked)}),$("#do2").change(function(){doControl(2,$(this).get(0).checked)}),$("#do3").change(function(){doControl(3,$(this).get(0).checked)}),$("#do4").change(function(){doControl(4,$(this).get(0).checked)}),spectrum1=$("#dmx1").spectrum({color:"#000",flat:!0,showInput:!1,showPalette:!0,palette:[["#000","#444","#666","#999","#ccc","#eee","#f3f3f3","#fff"],["#f00","#f90","#ff0","#0f0","#0ff","#00f","#90f","#f0f"],["#f4cccc","#fce5cd","#fff2cc","#d9ead3","#d0e0e3","#cfe2f3","#d9d2e9","#ead1dc"],["#ea9999","#f9cb9c","#ffe599","#b6d7a8","#a2c4c9","#9fc5e8","#b4a7d6","#d5a6bd"],["#e06666","#f6b26b","#ffd966","#93c47d","#76a5af","#6fa8dc","#8e7cc3","#c27ba0"],["#c00","#e69138","#f1c232","#6aa84f","#45818e","#3d85c6","#674ea7","#a64d79"],["#900","#b45f06","#bf9000","#38761d","#134f5c","#0b5394","#351c75","#741b47"],["#600","#783f04","#7f6000","#274e13","#0c343d","#073763","#20124d","#4c1130"]],clickoutFiresChange:!0,showButtons:!1,move:function(e){onChangeDmx1(e)},hide:function(e){onChangeDmx1(e)}}),spectrum2=$("#dmx2").spectrum({color:"#000",flat:!0,showInput:!1,showPalette:!0,palette:[["#000","#444","#666","#999","#ccc","#eee","#f3f3f3","#fff"],["#f00","#f90","#ff0","#0f0","#0ff","#00f","#90f","#f0f"],["#f4cccc","#fce5cd","#fff2cc","#d9ead3","#d0e0e3","#cfe2f3","#d9d2e9","#ead1dc"],["#ea9999","#f9cb9c","#ffe599","#b6d7a8","#a2c4c9","#9fc5e8","#b4a7d6","#d5a6bd"],["#e06666","#f6b26b","#ffd966","#93c47d","#76a5af","#6fa8dc","#8e7cc3","#c27ba0"],["#c00","#e69138","#f1c232","#6aa84f","#45818e","#3d85c6","#674ea7","#a64d79"],["#900","#b45f06","#bf9000","#38761d","#134f5c","#0b5394","#351c75","#741b47"],["#600","#783f04","#7f6000","#274e13","#0c343d","#073763","#20124d","#4c1130"]],clickoutFiresChange:!0,showButtons:!1,move:function(e){onChangeDmx2(e)},hide:function(e){onChangeDmx2(e)}}),getStatus(),$(".loading").hide(),$("#mainContent").show()});

)EOF"