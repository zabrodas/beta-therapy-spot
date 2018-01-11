dofile("combo_control.cfg")

wifiScanIndex=1
wifiTryIndex=-1
wifiConnectionWatchdog=nil
wifiRetryCounter=-1
modepin=0

numdo=4
domap={1,2,3,5}

smokeTimer=nil
smokePin=6

function smokeOff()
    gpio.mode(smokePin,gpio.OUTPUT)
    gpio.write(smokePin,gpio.LOW)
    if smokeTimer~=nil then
        tmr.stop(smokeTimer)
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
        tmr.register(smokeTimer, dur*1000, tmr.ALARM_SEMI, smokeOff)    
    end
    tmr.interval(smokeTimer,dur*1000)
    tmr.start(smokeTimer)
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
    tmr.start(dmxTimer)
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
    local b="\0"
    for i=1,#str/2 do
        local v=tonumber(string.sub(str,2*i-1,2*i),16)
        b=b..string.char(v)
    end
    dmxNewBuffer=b
    -- print("dxmNewBuffer=",#str,#dmxNewBuffer)
    -- print("dxmNewBuffer=",str,dmxNewBuffer)
end

function onWifiConnected(t)
    print("Wifi connected ",t.SSID)
end

function onWifiDisconnected(t)
    print("Wifi disconnected ",t.SSID," reason ",t.reason)
end

server=nil

function sendBigFile(socket,fd,onDone)
    local s=fd:read()
    if s==nil then
        onDone(socket,fd)
        return
    end
    local next=function()
        sendBigFile(socket,fd,onDone)
    end;
    socket:send(s, next)
end

function sendFile(socket,fn)
    print("Send file",fn)
    local fd=file.open(fn)
    if fd==nil then
        socket:send(serverErr)
        return
    end
    local fs=file.stat(fn).size
--    print("size",fs)
    
    local n,e
    n,e=string.match(fn,"([%w_%-%.]+)%.([%w_%-]+)")
    local mt=mimeTypes[e]
    if mt==nil then mt=mimeDefaultType; end

--    print("mt",mt)

    local t = {FILESIZE=fs, MIMETYPE=mt}
    local h = string.gsub(serverFile, "#(%w+)#", t)

--    print("headers:",h)
    socket:send(h)

    local onDone=function(socket, fd)
        fd:close()
        onRequestCompleted(socket)
    end
    sendBigFile(socket,fd,onDone);
end
    
requestCnt=0
wifiRequestQueue={}

function onRequestCompleted(socket)
    print("onRequestCompleted")
    socket:close()
    requestCnt=requestCnt-1
    nextRequest()
end

function nextRequest()
    if requestCnt>0 then
        print("delay request")
        return
    end
    if #wifiRequestQueue==0 then
        print("no more requests")
        return
    end
    requestCnt=requestCnt+1
    print("start request")
    local r=table.remove(wifiRequestQueue,1)
    local socket=r.socket
    local request=r.request
    onRequest1(socket, request)    
end


function onRequest(socket, request)
    print("new request")
    local r={}
    r.socket=socket
    r.request=request
    table.insert(wifiRequestQueue,r)
    nextRequest()
end


function onRequest1(socket, request)

    --print("onRequest ",request)

    -- op,index,hex=string.match(request,"GET%s+/(%a+)(%d*)(=[0-9A-F]+)*.")
    --- print("/",request,"/")
    local f

    f=string.match(request,"GET%s+(/)%s+")
    if f=="/" then
        socket:send(serverRedirect, function() onRequestCompleted(socket); end)
        return
    end
    
    f=string.match(request,"GET%s+/file/([%w_%-%.]+)")
    if f~=null then
        sendFile(socket,f)
        return;
    end        

    local op,index,eq,hex;
    op,index,eq,hex=string.match(request,"GET%s+/(%a+)(%d*)(=?)(%x*).")
    print("/",op,"/",index,"/",hex,"/")

    if index~="" then
        index=tonumber(index)
    end
    if op=="on" and index>=1 and index<=numdo then
        doCtrl(index,1)
    elseif op=="off" and index>=1 and index<=numdo then
        doCtrl(index,0)
    elseif op=="do" then
        for i=1,numdo do
            doCtrl(i,index%2)
            index=index/2
        end
    elseif op=="smoke" then
        smokeOn(index)
    elseif op=="dmx" then
        dmxCtrl(hex)
    end
    
    socket:send(serverReply,function() onRequestCompleted(socket); end)
end

function onCLientConnected(socket)
    print("onCLientConnected")
    socket:on("receive",onRequest)
end

function startServer()
    print("Start server")
    if server then
        server:close()
        server=nil
    end
    server=net.createServer(net.TCP, 30)
    server:listen(8080,onCLientConnected)
    print("Server started")
end
function onWifiGotIp(t)
    print("Wifi got IP ",t.IP)
    startServer()
end

function wifiInitAP()
            print("WiFi init as AP")
            wifi.setmode(wifi.SOFTAP)
            wifi.setphymode(wifi.PHYMODE_B)
            wifi.ap.config(wifiApConfig.common)
            wifi.ap.setip(wifiApConfig.ip)
            local pool_startip, pool_endip=wifi.ap.dhcp.config(wifiApConfig.dhcp)
            wifi.ap.dhcp.start()
            print("IP=",wifiApConfig.ip.ip," channel=",wifiApConfig.common.channel, "DHCP start=",pool_startip," DHCP stop=",pool_endip);
            startServer()
end

function selectChannelAndStartAP(t)
            local crt={}
            for ssid,v in pairs(t) do
                local authmode, rssi, bssid, channel = string.match(v, "([^,]+),([^,]+),([^,]+),([^,]+)")
                print(string.format("%32s",ssid).."\t"..bssid.."\t  "..rssi.."\t\t"..authmode.."\t\t\t"..channel)
                local cn=tonumber(channel)
                local rn=tonumber(rssi)
--                print("cn=",cn," rn=",rn," crt=",crt[cn])
                if crt[cn]==nil then
                    crt[cn]=rn
                elseif crt[cn]<rn then
                    crt[cn]=rn
                end
            end
            local selchan=-1
            for ch=1,11 do
                --print("ch=",ch," crt=",crt[ch]," localselrssi=",localselrssi," selchan=",selchan)
                if crt[ch]==nil then
                    selchan=ch
                    break
                end
            end
            if selchan<1 then
                local localselrssi=nil
                for ch=1,11 do
                    --print("ch=",ch," crt=",crt[ch]," localselrssi=",localselrssi," selchan=",selchan)
                    if localselrssi==nil or crt[ch]<localselrssi then
                        localselrssi=crt[ch]
                        selchan=ch
                    end
                end
            end
            wifiApConfig.common.channel=selchan
            local t=tmr.create()
            tmr.register(t,500,tmr.ALARM_SINGLE,wifiInitAP)
            tmr.start(t)
end

function wifiInit()
    gpio.mode(modepin,gpio.INPUT,gpio.PULLUP)
    local mode=gpio.read(modepin)
    if mode==0 then
        print("WiFi scan AP to select channel")
--        wifiInitAP();
--        return
        
        wifi.setmode(wifi.STATION)
        wifi.sta.getap(selectChannelAndStartAP)
    else
        print("WiFi init as Station")
        wifi.setmode(wifi.STATION)
        wifi.setphymode(wifi.PHYMODE_B)
        wifiConnectionWatchdogProc()
    end
end



function wifiConnectionWatchdogProc()

    if not wifiConnectionWatchdog then
        wifiConnectionWatchdog=tmr.create()
        tmr.register(wifiConnectionWatchdog,10000,tmr.ALARM_SEMI,wifiConnectionWatchdogProc)
    end

    local s=wifi.sta.status()
    print("Wifi status=",s)
    if s==wifi.STA_GOTIP and wifiTryIndex>0 then
        wifiScanIndex=wifiTryIndex
        wifiRetryCounter=6
        tmr.start(wifiConnectionWatchdog)
        return
    end

    wifiRetryCounter=wifiRetryCounter-1
    if wifiRetryCounter>0 then 
        tmr.start(wifiConnectionWatchdog)
        return;
    end

    print("Scan WiFi")
    wifi.sta.getap(function(wifiList)

        local t1=wifiScanIndex
        while true do
            wifiTryIndex=wifiScanIndex
            wifiScanIndex=wifiScanIndex+1
            if wifiScanIndex>#netList then wifiScanIndex=1; end
            if wifiList[netList[wifiTryIndex][1]] then break; end
            if wifiScanIndex==t1 then
                print("No known WiFi network")
                wifi.setmode(wifi.NULLMODE)
                wifiTryIndex=-1
                wifiRetryCounter=0
                tmr.start(wifiConnectionWatchdog)
                return
            end
        end
        
        print("Connecting to ",netList[wifiTryIndex][1])
        wifiRetryCounter=6

        local cfg={}
        cfg.ssid=netList[wifiTryIndex][1]
        cfg.pwd=netList[wifiTryIndex][2]
        ec=wifi.sta.config(cfg)
        wifi.eventmon.register(wifi.eventmon.STA_CONNECTED,onWifiConnected)
        wifi.eventmon.register(wifi.eventmon.STA_DISCONNECTED,onWifiDisconnected)
        wifi.eventmon.register(wifi.eventmon.STA_GOT_IP,onWifiGotIp)
        wifi.sta.connect()
        tmr.start(wifiConnectionWatchdog)

    end)
        
end

for i=1,numdo do
    doCtrl(i,0)
end
smokeOff()

wifiInit()
dmxTimer=tmr.create()
tmr.register(dmxTimer,10,tmr.ALARM_SEMI,dmxSendFrame)
tmr.start(dmxTimer)

function pp(t)
    for k,v in pairs(t) do
        print(k,"=",v)
    end
end
    
