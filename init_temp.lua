--wifi.setmode(wifi.STATIONAP)
--wifi.sta.config("<NETWORK>", "<PASS>")
--wifi.sta.connect()

gpio.mode(5, gpio.OUTPUT)
gpio.write(5, gpio.LOW)

tmr.alarm(0, 3000, 1, function ()
  local ip = wifi.sta.getip()
  if ip then
    tmr.stop(0)
    print("IP: "..ip..", memory: "..node.heap())
    st = node.heap()

    dofile("pusher_client.lua")

    print("Loading pusher client takes "..(st - node.heap()).." bytes")

    local pusher_client = pusher.createClient('<APPKEY>', 'http://<WEBSITE>/pusher/auth/')

    pusher_client.on_connection = function(client, socket_id)
        gpio.write(5, gpio.HIGH)
        local sub = client:subscribe('private-temperature_channel')

        tmr.alarm(1, 3000, 1, function()
            local code, temperature, humidity = dht.read(2)
            if code == 0 then
                local data = { temperature = temperature, humidity = humidity }
                client:trigger('private-temperature_channel', 'temperature_reading', data)
            end
        end)

    end
    pusher_client.on_close = function()
        gpio.write(5, gpio.LOW)
        tmr.stop(1)
    end
    pusher_client:connect()

  end
end)
