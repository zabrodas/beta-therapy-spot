print("Startting application with 15 second delay. Send 'tmr.stop(startDelay)' to abort")
startDelay=tmr.create()
tmr.register(startDelay,15000,tmr.ALARM_SINGLE,function(t)
    print("Starting spot_control.lua")
    dofile("spot_control.lua");
end)
tmr.start(startDelay)

    