--!strict
--!native
--!optimize 2

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local ReplicatedStorage = game:GetService("ReplicatedStorage").Shared
local BufferModule = require(ReplicatedStorage.Buffer)
local DataTypes = require(ReplicatedStorage.DataTypes)

local schemaStore = DataStoreService:GetDataStore("___Schema_Store___")

export type key = string
export type keySet = {key}

export type change = {
    index : number,
    key : key,
    action : number,
    size : number,
}

export type changeLog = {change}

export type schema = {
    baseKeys : keySet,
    currentKeys : keySet,
    changeLog : changeLog,
    version : number,
}

export type data<T> = {
    sample : T,
    bufferObj : BufferModule.bufferObject<T>,
    schema : schema,
}

local HEADER_SIZE = 1 + 2

local writeu8 = buffer.writeu8
local readu8  = buffer.readu8
local writeString = buffer.writestring
local readString = buffer.readstring

local function findSizeOfKeySet(sample : keySet) : number
    local size = #sample
    for _, key in sample do
        size += #key
    end
    return size
end

local function readKeySet(buff : buffer, startIndex : number, size : number) : keySet
    
    local typeRegion = startIndex + size
    local keySet = {}

    while startIndex < typeRegion do
        local size = readu8(buff, startIndex)
        startIndex += 1
        table.insert(keySet, readString(buff, startIndex, size))
        startIndex += size
    end

    return keySet
end

local function writeKeySet(buff : buffer, startIndex : number, valueToWrite : keySet, size : number)
    
    for _, key in valueToWrite do        
        local keySize = #key
        writeu8(buff, startIndex, keySize)
        startIndex += 1
        writeString(buff, startIndex, key, size)
        startIndex += keySize
    end
end

local typeKeySet = BufferModule.dType({} :: keySet, findSizeOfKeySet, writeKeySet, readKeySet)

local headerBufferObject = BufferModule.buff(
    {
        nextPage = DataTypes.boolean,
        latestVersion = DataTypes.unsigned_int,
        baseKeys = typeKeySet,
    }
)

local changeBufferObject = BufferModule.buff({
    key = DataTypes.string,
    index = DataTypes.unsigned_int,
    size = DataTypes.unsigned_long,
    action = DataTypes.unsigned_short
} :: change)

-- Handles loading for schema from database
local function getSchemaFile(id : string) : buffer?
    local success, result = pcall(function()
        return schemaStore:GetAsync(id)
    end)

    if not success then
        warn(result)
        error("Schema loading failed, roblox data store failed, id="..id)
    end

    return result
end

-- Handles saving schema file to data base
local function setSchemaFile(id : string, schemaFile : buffer)
    local success, result = pcall(function()
        return schemaStore:SetAsync(id, schemaFile)
    end)

    if not success then
        warn(result)
        error("Schema saving failed, roblox data store failed, id="..id)
    end
end

-- Appends a give list of changes to a schema file
local function appendChanges(changes : changeLog, schemaFile : buffer) : buffer

    local sizeOfSchema = buffer.len(schemaFile)
    
    for _, change in changes do
        
        local buff = changeBufferObject:encode(change)
        local size = buffer.len(buff)

        local newBuffSize = sizeOfSchema + size
        local newBuff = buffer.create(newBuffSize)
        buffer.copy(newBuff, 0, schemaFile, 0, sizeOfSchema)
        buffer.copy(newBuff, sizeOfSchema, buff, 0, size)
        
        sizeOfSchema = newBuffSize
    end

    return schemaFile
end

-- Compares to sets of keys to find the changes and where those changes were made
local function compareKeys(setOne : keySet, setTwo : keySet) : changeLog
    
end


local function buildLatestKeySet(baseKeys : keySet, changes : changeLog) : keySet
    
end

local function createSchema(id : string, currentKeys : keySet) : schema

    local schemaFile = getSchemaFile(id)

    local version, baseKeys

    local changes = {}

    local placeVersion = game.PlaceVersion

    if not schemaFile then
        baseKeys = currentKeys
        version = placeVersion
    else
        local headerSize = HEADER_SIZE + buffer.readu32(schemaFile, 3) -- size of keyset written by buffermodule
        local headerBuffer = buffer.create(headerSize)
        buffer.copy(headerBuffer, 0, schemaFile, 0, headerSize)
        local header = headerBufferObject:decode(headerBuffer)

        version = header.latestVersion
        changes = compareKeys(currentKeys, header.baseKeys)

        if #changes > 0 then            
            if version < placeVersion then
                currentKeys = buildLatestKeySet(baseKeys, changes)
            elseif version > placeVersion then
                schemaFile = appendChanges(changes, schemaFile)
                setSchemaFile(id, schemaFile)
            else
                error("Schema failed, version conflict, In studio press ctrl + s")
            end
        end
    end   

    local schema : schema = {
        baseKeys = baseKeys,
        currentKeys = currentKeys,
        changeLog = changes,
        version = version,
    }

    return schema
end

local function createData<T>(id : string, sample : T)
    
    local bufferObj = BufferModule.buff(sample)
    
    local data : data<T> = {
        sample = sample,
        bufferObj = bufferObj,
        schema = createSchema(id, bufferObj._sortedKeys)
    }

    return table.freeze(data)
end

return table.freeze({
    data = createData,
})


