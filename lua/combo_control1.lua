
wifiScanIndex=1
wifiTryIndex=-1
wifiConnectionWatchdog=nil
wifiRetryCounter=-1
modepin=0

numdo=4
domap={1,2,3,5}

smokeTimer=nil
smokePin=6

lastState={ }
lastState["do"]={0,0,0,0}
lastState.dmx=""

function restoreLastState()
    fd=file.open(lastStateFilename)
    if fd~=nil then
        print("Restore last state")
        for i=1,numdo do
            local s=fd:readline()
            local on;
            if string.sub(s,1,1)=="1" then
                on=1
            else
                on=0
            end
            doCtrl(i,on)
        end
        local s=fd:readline()
        s=string.sub(s,1,#s-1) -- remove newline
        if s~=nil then
            dmxCtrl(s)
        end
        fd.close()
    else
        print("No last state file exists")
    end
end

function saveLastState()
    fd=file.open(lastStateFilename,"w")
    if fd~=nil then
        print "Save last state"
        for i=1,numdo do
            fd:writeline(tostring(lastState["do"][i]))
        end
        fd:writeline(lastState.dmx)
        fd.close()
    else
        print("Can't save last state") 
    end
end


lastStateTimer=tmr.create()
lastStateTimer.register(lastStateTimer,10000,tmr.ALARM_SEMI,saveLastState)

function markChangeLastState()
    lastStateTimer.stop(lastStateTimer)
    lastStateTimer.start(lastStateTimer)
end

function smokeOff()
    gpio.mode(smokePin,gpio.OUTPUT)
    gpio.write(smokePin,gpio.LOW)
    if smokeTimer~=nil then
        smokeTimer.stop(smokeTimer)
    end
    print("smoke off")
end


function smokeOn(dur) 
    gpio.mode(smokePin,gpio.OUTPUT)
    if dur<=0 or dur>30 then
        smokeOff()
        return
    end
    if smokeTimer==nil then
        smokeTimer=tmr.create()
        smokeTimer.register(smokeTimer, dur*1000, tmr.ALARM_SEMI, smokeOff)    
    end
    smokeTimer.interval(smokeTimer,dur*1000)
    smokeTimer.start(smokeTimer)
    gpio.write(smokePin,gpio.HIGH)
    print("smoke on",dur)
end


function doCtrl(i,on)
    local pin=domap[i]
    print("d["..i.."/"..pin.."]="..on)
    gpio.mode(pin,gpio.OUTPUT)
    if on>0 then
        gpio.write(pin,gpio.HIGH)
    else
        gpio.write(pin,gpio.LOW)
    end
    lastState["do"][i]=on
    markChangeLastState()
end

dmxBuffer="\0"
dmxNewBuffer=nil
dmxTimer=nil;

dmxpin=5
dmxbaud=250000
dmxbd=1000000/dmxbaud

dmxsb={}
dmxsbcnt=0
dmxsblb=1;
function dmxsbReset()
    dmxsb={}
    dmxsb[0]=dmxbd
    dmxsbcnt=0
    dmxsbl=1
end
function dmxAppendBit(b)
    if dmxsbl==b then
        dmxsb[dmxsbcnt]=dmxsb[dmxsbcnt]+dmxbd
    else
        dmxsbcnt=dmxsbcnt+1
        dmxsb[dmxsbcnt]=dmxbd
        dmxsbl=b
    end
end
function dmxAppendByte(b)
    dmxAppendBit(0)
    local b1=b
    for i=0,7 do
        dmxAppendBit(b1%2)
        b1=b1/2
    end
    dmxAppendBit(1)
    dmxAppendBit(1)
end
function dmxCreateSb()
    dmxsbReset()
    for i=0,500 do
        dmxAppendBit(0)
    end
    dmxAppendByte(0)
    for i=1,#dmxBuffer do
        local c=string.byte(dmxBuffer,i)
        dmxAppendByte(c)
    end
    dmxAppendBit(0)
end

function dmxSendFrame1() 
    dmxTimer.start(dmxTimer)
end

function dmxSendFrame(buf)
    if dmxNewBuffer~=nil then
        dmxBuffer=dmxNewBuffer
        dmxNewBuffer=nil
--        uart.write(0,"dmxBuffer="..dmxBuffer)
--        dmxCreateSb()
    end
    -- gpio.serout(dmxpin, gpio.HIGH, {1000000,1000000}, 1, dmxSendFrame)
    -- gpio.serout(dmxpin, gpio.HIGH, dmxsb, 1, dmxSendFrame1)
    --local x={}
    --for i=0,#dmxsb do
    --    x[i]=dmxsb[i]
    --end
    --gpio.serout(dmxpin, gpio.HIGH, x)
    --x=nil
    -- dmxSendFrame1()
    uart.setup(1, 80000, 8, uart.PARITY_NONE, uart.STOPBITS_2,0)
    uart.write(1,0)
    uart.setup(1, 256000, 8, uart.PARITY_NONE, uart.STOPBITS_2,0)
    for i=1,#dmxBuffer do
        uart.write(1,string.byte(dmxBuffer,i))
        tmr.delay(500)
    end
    -- uart.write(0,dmxBuffer)
    -- tmr.start(dmxTimer)
    dmxSendFrame1()
end

function dmxCtrl(str)
    print("DMX="..str)
    local b="\0"
    for i=1,#str/2 do
        local v=tonumber(string.sub(str,2*i-1,2*i),16)
        b=b..string.char(v)
    end
    dmxNewBuffer=b
    lastState.dmx=str
    markChangeLastState()
    -- print("dxmNewBuffer=",#str,#dmxNewBuffer)
    -- print("dxmNewBuffer=",str,dmxNewBuffer)
end

