--wifi.setmode(wifi.STATIONAP)
--wifi.sta.config("<NETWORK>", "<PASS>")
--wifi.sta.connect()

gpio.mode(5, gpio.OUTPUT)
gpio.write(5, gpio.LOW)

function sound_alarm()
    pwm.setup(1, 700, 16)
    pwm.start(1)
    tmr.alarm(1, 500, 0, function() pwm.stop(1) end)
end

tmr.alarm(0, 3000, 1, function ()
  local ip = wifi.sta.getip()
  if ip then
    tmr.stop(0)
    print("IP: "..ip..", memory: "..node.heap())
    st = node.heap()

    dofile("pusher_client.lc")

    print("Loading pusher client takes "..(st - node.heap()).." bytes")

    local pusher_client = pusher.createClient('<APPKEY>', 'http://<WEBSITE>/pusher/auth/')

    pusher_client.on_connection = function(client, socket_id)
        gpio.write(5, gpio.HIGH)
        client:subscribe('private-temperature_channel')
            .bind('client-temperature_reading',
                function(data)
                    for key,value in pairs(data) do print(key,value) end
                    data['humidity'] =  data['humidity'] or 0
                    data['temperature'] =  data['temperature'] or 0
                    if data['humidity'] > 70 or data['temperature'] > 30 then
                        sound_alarm()
                    end
                end)

    end
    pusher_client.on_close = function()
        gpio.write(5, gpio.LOW)
    end
    pusher_client:connect()

  end
end)
