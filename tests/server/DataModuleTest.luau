-- !strict
-- !native
-- !optimize 2

local DataStore = require(game.ServerScriptService.Server.DataStore)
local DataTypes = require(game.ReplicatedStorage.Shared.DataTypes)
local Players = game:GetService("Players")
local defaultPlayerData = {
    z = "zebra",
    tokens = 0,
    coins = 1000,
    gems = 0,
    nick = "null",
    a = "hello",
}

local playerData = DataStore.group("Player-Data-10", defaultPlayerData, {
    coins = DataTypes.unsigned_long,
    gems = DataTypes.unsigned_long,
    tokens = DataTypes.unsigned_long,
    nick = DataTypes.string,
    z = DataTypes.string,
    a = DataTypes.string,
})

Players.PlayerAdded:Connect(function(player)

    local container = playerData:container(player.UserId)
    container.data.coins += 50
    print(container)
end)

Players.PlayerRemoving:Connect(function(player)

    playerData:dump(player.UserId)

end)


game:BindToClose(function()

    task.wait(2)

end)

return 0