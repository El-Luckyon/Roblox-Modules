--!strict
--!native
--!optimize 2

local DataTypes = require(game.ReplicatedStorage.Tests.DataTypes)
local Networking = require(game.ReplicatedStorage.Shared.Networking)
local Remotes = game.ReplicatedStorage.Remotes

local testRemote = Networking.init(Remotes.RemoteEvent)

return table.freeze({
	sayHello = Networking.packet(testRemote,{
		clientTime = DataTypes.double,
		secretCode = DataTypes.unsigned_short,
		message = DataTypes.string,
		position = DataTypes.vector3,
		cframe = DataTypes.cframe,
		loaded = DataTypes.boolean,
		testColor = DataTypes.color3,
	}),
})	