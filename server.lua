function gbanHash(...)
    local arg = {...}
    key = table.concat( arg )
    maxInt = 4294967295
    maxPostInt = 2147483647
    hash = os.time() + Config.serverId
    length = string.len(key)
    for i=1, length do
        hash = hash * 31 + string.byte(string.sub(key,i,i))
        if hash > maxInt then
            div = math.floor(hash / (maxInt + 1))
            hash = hash - (div * (maxInt + 1))
        end
    end
    if hash > maxPostInt then
        hash = hash - maxInt - 1
    end
    if hash < 0 then
        hash = hash + maxInt + 1
    end
    return string.format("%x", hash)
end

AddEventHandler('playerConnecting', function(name, setCallback, deferrals)
    deferrals.defer()
    deferrals.update("Checking Player Information. Please Wait.")
    local identifier    
    identifier = json.encode(GetPlayerIdentifiers(source))

    local response = PostData({identifier = identifier})
    if response then
        local data = json.decode(response)
        if data['reason'] then
            deferrals.done("Reason: " .. data['reason'])
        else
            deferrals.done()
        end
    end
end)

RegisterCommand('gban', function(playerId, args, rawCommand)
    if (IsPlayerAceAllowed(playerId, 'command')) then
        staff = GetPlayerIdentifiers(playerId)[1]

        local ban = tonumber(args[1])
        local expires = nil
        
        if tonumber(args[2]) ~= nil then
            expires = args[2]
            table.remove(args, 1)
            table.remove(args, 1)
        else
            table.remove(args, 1)
        end        
        
        reason = table.concat(args, ' ')
        banByPlayerId(ban, reason, expires, staff)
    end
end)

RegisterCommand('gbanlist', function(playerId, args, rawCommand)
    if (IsPlayerAceAllowed(playerId, 'command')) then
        local staff = GetPlayerIdentifiers(playerId)[1]
        local hash = gbanHash(staff)
        local result = nil
        result = PostData({list = staff, hash = hash})
        result = json.decode(result)
        TriggerClientEvent('gban:list', playerId, result.list)
    end
end)

RegisterCommand('gbanident', function(playerId, args, rawCommand)
    if (IsPlayerAceAllowed(playerId, 'command')) then
        staff = GetPlayerIdentifiers(playerId)[1]

        local ban = args[1]
        local expires = nil
        
        if tonumber(args[2]) ~= nil then
            expires = args[2]
            table.remove(args, 1)
            table.remove(args, 1)
        else
            table.remove(args, 1)
        end        
        
        reason = table.concat(args, ' ')
        banByIdentifier(ban, reason, expires, staff)
    end
end)

RegisterServerEvent('gban:selfBan')
AddEventHandler('gban:selfBan', function (reason, time, staff)
    banByPlayerId(source, reason, time, staff)
end)

RegisterServerEvent('gban:playerBan')
AddEventHandler('gban:playerBan', function (playerId, reason, time)
    if (IsPlayerAceAllowed(source, 'command')) then
        local staff = GetPlayerIdentifiers(source)[1]
        banByPlayerId(playerId, reason, time, staff)
    end
end)

RegisterServerEvent('gban:remove')
AddEventHandler('gban:remove', function (hash, staff)
    if (IsPlayerAceAllowed(source, 'command')) then
        local staff = GetPlayerIdentifiers(source)[1]
        gbanRemove(hash, staff)
    end
end)

function banByPlayerId(playerId, reason, expires, staff)
    local identifiers = json.encode(GetPlayerIdentifiers(playerId))
    local reason = reason or Config.DefaultReason
    local staff = staff or Config.projectName
    local hash = gbanHash(identifiers, staff)

    if type(expires) == 'number' and expires < os.time() then
        expires = os.time()+expires 
    end

    if Config.Kick then DropPlayer(playerId, reason) end
    return PostData({ban = identifiers, reason = reason, staff = staff, expires = expires, hash = hash})
end

function banByIdentifier(identifiers, reason, expires, staff)
    if type(identifiers) ~= 'table' then identifiers = {identifiers} end
    identifiers = json.encode(identifiers)
    local reason = reason or Config.DefaultReason
    
    if type(expires) == 'number' and expires < os.time() then
        expires = os.time()+expires 
    end
    
    local staff = staff or Config.projectName
    local hash = gbanHash(identifiers, staff)
    return PostData({ban = identifiers, reason = reason, staff = staff, expires = expires, hash = hash, waktu = Config.serverId+os.time()})
end

function gbanRemove(serial, staff)
    local staff = staff or Config.projectName
    local hash = gbanHash(serial, staff)
    return PostData({remove = serial, staff = staff, hash = hash})
end

function PostData(data)
    local result = nil
    data['serverKey'] = Config.serverKey
    PerformHttpRequest("https://dejavu.gigne.net/fivem/ban-list/", function(err, response, headers)
        if err == 200 then
            result = response
        else
            result = json.encode({error = err, message = response})
        end
    end, 'POST', json.encode(data), { ['Content-Type'] = 'application/json' })
    while result == nil do
        Wait(0)
    end
    return result
end

exports('playerBan', banByPlayerId)
exports('identifierBan', banByIdentifier)
exports('remove', gbanRemove)


AddEventHandler('onResourceStart', function(resourceName)
    Config.locale = GetConvar('locale')
    Config.projectName = GetConvar('sv_projectName')
    if (GetCurrentResourceName() == resourceName) then
        result = PostData({event = 'onResourceStart', locale = Config.locale, projectName = Config.projectName, time = os.time()})
        result = json.decode(result)
        Config.serverId = result['serverId']
        Config.serverKey = result['serverKey']
    end
end)

