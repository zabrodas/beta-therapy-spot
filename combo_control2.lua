function onWifiConnected(t)
    print("Wifi connected ",t.SSID)
end

function onWifiDisconnected(t)
    print("Wifi disconnected ",t.SSID," reason ",t.reason)
end


server=nil
SEND_CHUNK_SIZE=1000

function sendBigFile(socket,fd,onDone)
    local fm=node.heap()
    local bs=fm-10000
    if bs<0 then bs=SEND_CHUNK_SIZE; end
    if bs>=fm then bs=fm/2; end;
    local s=fd:read(bs)
    if s==nil then
        onDone(socket,fd)
        return
    end
    local next=function(ok)
        if ok then
            sendBigFile(socket,fd,onDone)
        else
            onDone(socket,fd)
        end
    end;
    socket.send(s, next)
end

function sendFile(socket,fn)
    print("Send file",fn)

    local fd=file.open(fn)
    if fd==nil then
        socket.send(serverErr, function(ok) onRequestCompleted(socket); end)
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

    local onDone=function(socket, fd)
        fd:close()
        onRequestCompleted(socket)
    end
    socket.send(h, function(ok) sendBigFile(socket,fd,onDone); end)
    
end
    
requestCnt=0
wifiRequestQueue={}

function onRequestCompleted(socket)
    print("onRequestCompleted")
    socket.close();
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
        socket.send(serverRedirect, function(ok) onRequestCompleted(socket); end)
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

    local reply=serverReply
    
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
    elseif op=="state" then
        local t = {
            DO1=lastState["do"][1],
            DO2=lastState["do"][2],
            DO3=lastState["do"][3],
            DO4=lastState["do"][4],
            DMX=lastState.dmx,
        }
        reply = string.gsub(serverState, "#(%w+)#", t)
    end

    socket.send(reply,function(ok) onRequestCompleted(socket); end)
end

function mySocktNotify(mySocket)
    if mySocket.sendCallback~=nil then
        local f=mySocket.sendCallback
        mySocket.sendCallback=nil
        f(mySocket.socket~=nil)
    end
end

function delayedCallTmo(f,tmo)
    local t=tmr.create()
    tmr.register(t,tmo,tmr.ALARM_SINGLE,f)
    tmr.start(t)
end    
function delayedCall(f)
    delayedCallTmo(f,1)
end
function onCLientConnected(socket)
    print("onCLientConnected")
    local mySocket={
        socket=socket,
        sendCallback=nil
    }
    mySocket.close=function()
            if mySocket.socket~=nil then
                local ss=mySocket.socket
                mySocket.socket=nil
                local f=function() ss:close(); end;
                pcall(f)
            end
            if mySocket.sendCallback~=nil then
                print("Close socket while sending")
            end
            mySocktNotify(mySocket)
    end
    mySocket.send=function(d,cb)
            if mySocket.sendCallback~=nil then
                print("Prev send is not completed")
                delayedCall(function() cb(false); end)
                return
            end
            if mySocket.socket==nil then
                print("Connection closed")
                delayedCall(function() cb(false); end)
                return
            end
            mySocket.sendCallback=cb
            local ss=function()
                mySocket.socket:send(d, function() mySocktNotify(mySocket); end)
            end
            pcall(ss)
    end
    mySocket.socket:on("receive",function(s,r) onRequest(mySocket,r); end )
    mySocket.socket:on("disconnection", 
        function(s,m)
            print("On disconnect socket") 
            if mySocket.sendCallback~=nil then
                delayedCallTmo(mySocket.close,100)
            else
                mySocket.close()
            end
        end
    )
end
