dofile("combo_control.cfg")
dofile("combo_control1.lc")
dofile("combo_control2.lc")
dofile("combo_control3.lc")

for i=1,numdo do
    doCtrl(i,0)
end
smokeOff()
restoreLastState()

wifiInit()
dmxTimer=tmr.create()
tmr.register(dmxTimer,10,tmr.ALARM_SEMI,dmxSendFrame)
tmr.start(dmxTimer)

function pp(t)
    for k,v in pairs(t) do
        print(k,"=",v)
    end
end
    

