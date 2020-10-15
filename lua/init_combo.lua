print("Startting application with 15 second delay. Send 'tmr.stop(startDelay)' to abort")
startDelay=tmr.create()
tmr.register(startDelay,15000,tmr.ALARM_SINGLE,function(t)
    print("Starting combo_control.lua")
    dofile("combo_control.lua");
end)
tmr.start(startDelay)

    
