-- !strict
-- !native
-- !optimize 2

-- local DataStore = require(game.ServerScriptService.Server.DataStore)
-- local DataTypes = require(game.ReplicatedStorage.Shared.DataTypes)

-- local schema = buffer.create(4)
-- local totalAppends = 660000
-- local batchSize = 5000

-- for i = 1, totalAppends, batchSize do
--     local batchEnd = math.min(i + batchSize - 1, totalAppends)
--     for j = i, batchEnd do
--         schema = DataStore.append(schema, {
--             index = 9,
--             size = 200,
--             action = 2,
--         })
--     end
--     print("Processed batch from", i, "to", batchEnd)
--     task.wait()
-- end

-- print("Final schema length:", buffer.len(schema))

-- local st = os.clock()
-- DataStore.build(schema)
-- print("Build done in:", os.clock() - st)

-- return 0
