# NodeMCU Pusher Client

An experimental Pusher client. Supports its most features, mainly missing the presence channel.
Additional work is still required for better connectivety, error handling and attempt to further lower RAM usage.

## Usage

To start, create a new pusher client instance, as shown below.
```lua
dofile("pusher_client.lua")
local pusher_client = pusher.createClient('<APPKEY>', 'http://<WEBSITE>/pusher/auth/', '<APPCLUSTER>')
```
Note that the second argument is optional and it's only required for private channels.

Now you can register the `on_connection` and `on_close` hooks. For example:
```lua
pusher_client.on_connection = function(client, socket_id)
    gpio.write(5, gpio.HIGH) -- turn on a led
end
pusher_client.on_close = function()
    gpio.write(5, gpio.LOW) -- turn off a led
end
```

After the hooks are setup, it's safe to call connect:
```lua
pusher_client:connect()
```

When connected, you can subscribe to channels and then bind/unbind a handler to a given event type:
```lua
pusher_client:subscribe('private-temperature_channel')
    .bind('client-temperature_reading', function(data) print(data) end)

-- a bind can also be channel-independent:
pusher_client:bind('my-event-type', function(data) print(data) end)

-- to unbind:
pusher_client:unbind('my-event-type')

-- or:
local subscription = pusher_client:subscribe('private-temperature_channel')
subscription.bind('some-event', function() subscription.unbind('some-event') end)
```

Lastly, for private channels it's possible to trigger messages, i.e.:
```lua
pusher_client:trigger('private-test-channel', 'event-type', {data = "table"})
```

## Required firmware modules
* cjson or sjson
* crypto
* file
* http
* net
* node
* websocket
* wifi

Consider building your own image using [this](http://nodemcu-build.com) service. You can use [esptool](https://github.com/themadinventor/esptool) to flash your NodeMCU firmware.

## Installing the library

Copy all files of this project to the NodeMCU. You can accomplish this using [ESPlorer](http://esp8266.ru/esplorer/) or [nodemcu-tool](https://www.npmjs.com/package/nodemcu-tool).

Alternatively, you can run this one line to install it:

```lua
http.get("https://raw.githubusercontent.com/pusher-community/pusher-nodemcu-client/master/pusher_client.lua", nil, function(_, c) local f = file.open("pusher_client.lua", "w+") if f then f:write(c) f:close() print("Latest client installed.") end end)
```
