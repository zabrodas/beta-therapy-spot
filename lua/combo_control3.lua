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
            t.register(t,500,tmr.ALARM_SINGLE,wifiInitAP)
            t.start(t)
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
        wifiConnectionWatchdog.register(wifiConnectionWatchdog,10000,tmr.ALARM_SEMI,wifiConnectionWatchdogProc)
    end

    local s=wifi.sta.status()
    print("Wifi status=",s)
    if s==wifi.STA_GOTIP and wifiTryIndex>0 then
        wifiScanIndex=wifiTryIndex
        wifiRetryCounter=6
        wifiConnectionWatchdog.start(wifiConnectionWatchdog)
        return
    end

    wifiRetryCounter=wifiRetryCounter-1
    if wifiRetryCounter>0 then 
        wifiConnectionWatchdog.start(wifiConnectionWatchdog)
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
                wifiConnectionWatchdog.start(wifiConnectionWatchdog)
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
        wifiConnectionWatchdog.start(wifiConnectionWatchdog)

    end)
        
end
