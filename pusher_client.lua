
node.stripdebug(3)
node.compile("ws_client.lua")
dofile("ws_client.lc")

do
local pusher = {}
_G.pusher = pusher

function pusher.createClient(appKey, authServerPath)
    local client = {
        ws_client = websocket.createClient(),

        socket_id = nil,
        authServerPath = authServerPath,

        on_connected = nil,     -- on_conected(client, socket_id)

        on_close = nil,         -- on_close(client)

        global_bindings = {},        -- 1d table:          [event type] = handler
        subscriptions_bindings = {}, -- 2d table: [channel][event type] = handler
        
        isConnected = function(self)
            return self.socket_id ~= nil and self.ws_client.isConnected
        end,

        bind = function(self, channel_name, event_type, handler)
            if channel_name then
                self.subscriptions_bindings[channel_name] = self.subscriptions_bindings[channel_name] or {}
                self.subscriptions_bindings[channel_name][event_type] = handler                
            else
                self.global_bindings[event_type] = handler
            end
        end,

        unbind = function(self, channel_name, event_type)
            if channel_name then
                self.subscriptions_bindings[channel_name] = self.subscriptions_bindings[channel_name] or {}
                self.subscriptions_bindings[channel_name][event_type] = nil                
            else
                self.global_bindings[event_type] = nil
            end
        end,

        subscribe = function (self, name)
            if name == nil or self.socket_id == nil then
                print("Not connected or channel name is empty.")
                return
            end
            self.subscriptions_bindings[name] = self.subscriptions_bindings[name] or {}
            
            local subscription = {
                bind = function(event_type, handler)
                    self.subscriptions_bindings[name][event_type] = handler
                end,
                unbind = function(event_type)
                    self.subscriptions_bindings[name][event_type] = nil
                end
            }

            if string.sub(name, 1, 8) == 'private-' then
                http.post(authServerPath,
                    'Content-Type: application/x-www-form-urlencoded\r\n',
                    'channel_name='..name..'&socket_id='..self.socket_id,
                    function(code, data)
                        if (code ~= 200) then
                            print("Failed to subscribe to channel " .. name)
                        else
                          local dataDecoded = nil
                          pcall(function() dataDecoded = cjson.decode(data) end)
                          if dataDecoded then
                              self.ws_client:send('{"event":"pusher:subscribe","data":{"channel":"'..name..'", "auth":"'..dataDecoded['auth']..'"}}')
                          else
                              print("Failed to subscribe to channel " .. name)
                          end
                        end
                    end)
                print("Attempting post to " .. authServerPath)
            else
                self.ws_client:send('{"event":"pusher:subscribe","data":{"channel":"'..name..'"}}')
            end
            
            return subscription
        end,
        
        trigger = function (self, channel, event_type, data)
            local dataEncoded = cjson.encode(data)
            self.ws_client:send(cjson.encode({event= 'client-'..event_type, channel = channel, data = dataEncoded}))
        end,

        receive = function (self, payload)
            local payloadDecoded = nil
            local validJson, _ = pcall(function() payloadDecoded = cjson.decode(payload) end)

            if not validJson then
                print("Invalid json: " .. payload)
                return
            end

            if payloadDecoded['event'] == 'pusher:connection_established' then
                self.socket_id = cjson.decode(payloadDecoded['data'])['socket_id']
                if self.on_connected then
                    print("[pusher] Connected with socket id: " .. self.socket_id)
                    self.on_connected(self, self.socket_id)
                end
                return
            end

            -- find subscribers
            local channel_name = payloadDecoded['channel'] or ''
            local bindings = self.subscriptions_bindings[channel_name] or self.global_bindings or nil
            if bindings then
                local handler = bindings[payloadDecoded['event'] or '']
                if handler then
                    local dataDecoded = nil
                    local validJson, _ = pcall(function() dataDecoded = cjson.decode(payloadDecoded['data']) end)
                    if validJson then
                        handler(dataDecoded)
                    end
                end
            end 
        end,

        ping = function (self)
            self.ws_client:ping()
        end,

        connect = function (self)
            local connection_string = "ws://ws.pusherapp.com/app/"..appKey.."?client=js&version=3.1&protocol=5"

            self.ws_client.on_receive = function(c, payload) self.receive(self, payload) end
            
            self.ws_client:connect(connection_string)
        end,

        close = function (self)
            if self.ws_client then
                self.ws_client:close()
            end
            self.ws_client = websocket.createClient()
            if self.on_close then
                self.on_close(self)
            end
        end
    }
    return client
end

end
