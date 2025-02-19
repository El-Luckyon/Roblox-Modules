--!strict
--!optimize 2
--!native

local BufferModule = require(game.ReplicatedStorage.Shared.Buffer)
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- A method to be called when a client recievies a packet from the server
export type serverCallback<T> = (player : Player, data : T) -> ()

-- A method to be called when a server recivies a packet from the client
export type clientCallback<T> = (data : T) -> ()

-- The main data type a user interacts with
export type packet<T> = {
	callbacks : {serverCallback<T> | clientCallback<T>},
	buff : BufferModule.bufferObject<T>,
	remote : RemoteEvent,
	send : (packet : packet<T>, data : T) -> (),
	sendTo : (packet : packet<T>, player : Player, data : T) -> (),
	sendToAll : (packet : packet<T>, data : T) -> (),
	sendToList : (packet : packet<T>, playerList : {Player}, data : T) -> (),
	sendToBut : (packet : packet<T>, excludedPlayer : Player, data : T) -> (),
	onSend : (packet : packet<T>, serverCallback<T>) -> (),
	onSendTo : (packet : packet<T>, clientCallback<T>) -> (),
	packetId : number
}

local env : "SERVER" | "CLIENT" = (RunService:IsClient() and "CLIENT") or "SERVER"

-- A method to add a server callback into a packet
local function addServerCallBack<T>(packet : packet<T>, callback : serverCallback<T>)
	table.insert(packet.callbacks, callback)
end

-- A method that is called when attempting to add servercallback from the client
local function invalidAddServerCallback<T>(_packet : packet<T>, _callback : serverCallback<T>)
	error("You cannot use :onSendTo on the client")
end

-- A method to add client callback into a packet
local function addClientCallback<T>(packet : packet<T>, callback : clientCallback<T>)
	table.insert(packet.callbacks, callback)
end

-- A method that is called when attempting to add clientcallback from the server
local function invalidAddClientCallback<T>(_packet : packet<T>, _callback : clientCallback<T>)
	error("You cannot use :onSend on the server")
end

-- A method to send data to the server from client
local function send<T>(packet : packet<T>, data : T) 
	packet.remote:FireServer(packet.packetId, packet.buff:encode(data))
end

-- A method that is called when trying to send data to the server from the server
local function invalidSend<T>(_data : T)
	error("You may not use :send() on the server")
end

-- A method data to specific client from the server
local function sendTo<T>(packet : packet<T>, player : Player, data : T) 
	packet.remote:FireClient(player, packet.packetId, packet.buff:encode(data))
end

-- A method that is called when trying to send data to a client from a client
local function invalidSendTo<T>(_packet : packet<T>, _player : Player, _data : T)
	error("You may not use :sendTo() on the client")
end

-- A method to send data to all clients
local function sendToAll<T>(packet : packet<T>, data : T) 
	packet.remote:FireAllClients(packet.packetId, packet.buff:encode(data))
end

-- A method that is called when trying to send data to all clients from the client
local function invalidSendToAll<T>(_packet : packet<T>, _data : T)
	error("You may not use :sendToAll() on the client")
end

-- A method to send data to all clients except one
local function sendToBut<T>(packet : packet<T>, playerToExclude : Player, data : T) 
	local remote = packet.remote
	local buff = packet.buff:encode(data)
	local id = packet.packetId
	for _, player in Players:GetPlayers() do
		if player == playerToExclude then continue end
		remote:FireClient(player, id, buff)
	end
end

-- A method that is called when trying to send data to all clients except one from the client
local function invalidSendToBut<T>(_packet : packet<T>, _playerToExclude : Player, _data : T)
	error("You may not use :sendToBut() on the client")
end

-- A method to send data to a list of clients
local function sendToList<T>(packet : packet<T>, playerList : {Player}, data : T) 
	local remote = packet.remote
	local buff = packet.buff:encode(data)
	local id = packet.packetId
	for _, player in playerList do
		remote:FireClient(player, id, buff)
	end
end

-- A method that is called when trying to send data to a list of clients from the client
local function invalidSendToList<T>(_packet : packet<T>, _playerList : {Player}, _data : T)
	error("You may not use :sendToList() on the client")
end

local packets : {packet<any>} = {}
local packetCounter = 0

-- A construtor that creates a server-packet by attaching the appropriate methods
local function createServerPacket<T>(remote : RemoteEvent, sample : T) : packet<T>
	local packet : packet<T> = {
		callbacks = {},
		buff = BufferModule.buff(sample),
		remote = remote,
		send = invalidSend,
		sendTo = sendTo,
		sendToAll = sendToAll,
		sendToList = sendToList,
		sendToBut = sendToBut,
		packetId = packetCounter,
		onSendTo = invalidAddClientCallback,
		onSend = addServerCallBack,
	}
	packets[packetCounter] = packet
	packetCounter += 1
	return packet
end

-- A construtor that creates a client-packet by attaching the appropriate methods
local function createClientPacket<T>(remote : RemoteEvent, sample : T) : packet<T>
	local packet : packet<T> = {
		callbacks = {},
		buff = BufferModule.buff(sample),
		remote = remote,
		send = send,
		sendTo = invalidSendTo,
		sendToAll = invalidSendToAll,
		sendToList = invalidSendToList,
		sendToBut = invalidSendToBut,
		packetId = packetCounter,
		onSendTo = addClientCallback,
		onSend = invalidAddServerCallback,
	}
	packets[packetCounter] = packet
	packetCounter += 1
	return packet
end

-- A method that takes a remote and sets it up to work with the module from the client
local function initClientRemote(remote : RemoteEvent) : RemoteEvent
	remote.OnClientEvent:Connect(function(packetId, buff)
		local packet = packets[packetId]
		assert(packet, `packet not found packetId={packetId}`)
		local data = packet.buff:decode(buff)
		for _, callback in packet.callbacks do
			(callback :: clientCallback<any>)(data)
		end		
	end)
	return remote
end

-- A method that takes a remote and setis it up with the module from the server
local function initServerRemote(remote : RemoteEvent) : RemoteEvent
	remote.OnServerEvent:Connect(function(player, packetId, buff)
		local packet = packets[packetId]
		assert(packet, `packet not found packetId={packetId}`)
		local data = packet.buff:decode(buff)
		for _, callback in packet.callbacks do
			(callback :: serverCallback<any>)(player, data)
		end
	end)
	return remote
end

return table.freeze({
	packet = env == "SERVER" and createServerPacket or createClientPacket,
	init =  env == "SERVER" and initServerRemote or initClientRemote,
}) :: {
	packet : <T>(remote : RemoteEvent, data : T) -> packet<T>,
	init : (remote : RemoteEvent) -> RemoteEvent,
}