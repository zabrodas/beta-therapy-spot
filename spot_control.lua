netList={
    { "az-theater","internal17" },
    { "gzabrodina","pusya756nadya" }
};

wifiScanIndex=1
wifiTryIndex=-1
wifiConnectionWatchdog=nil
wifiRetryCounter=-1

function lampCtrl(on)
    gpio.mode(1,gpio.OUTPUT)
    if on then
        gpio.write(1,gpio.HIGH)
    else
        gpio.write(1,gpio.LOW)
    end
end

function onWifiConnected(t)
    print("Wifi connected ",t.SSID)
end

function onWifiDisconnected(t)
    print("Wifi disconnected ",t.SSID," reason ",t.reason)
end

server=nil

function onRequest(socket, request)
    print("onRequest ",request)

    local op=string.match(request,"GET%s+/(%w+).")
    if op=="on" then
        lampCtrl(1)
        print("ON")
    elseif op=="off" then
        lampCtrl(0)
        print("OFF")
    end        

    socket:send(
      "HTTP/1.0 200 OK\r\n"..
      "Content-Type: text/plain\r\n"..
      "Access-Control-Allow-Origin: *\r\n"..
      "Content-Length: 5\r\n"..
      "\r\n"..
      "SPOT1\r\n"
    )
end

function onCLientConnected(socket)
    print("onCLientConnected")
    socket:on("receive",onRequest)
end

function onWifiGotIp(t)
    print("Wifi got IP ",t.IP)
    if server then
        server:close()
        server=nil
    end
    server=net.createServer(net.TCP, 30)
    server:listen(2222,onCLientConnected)
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
    wifi.setmode(wifi.STATION)
    wifi.setphymode(wifi.PHYMODE_B)
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

lampCtrl(1)
wifiConnectionWatchdogProc()

