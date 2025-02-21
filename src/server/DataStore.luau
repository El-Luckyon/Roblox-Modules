--!strict
--!native
--!optimize 2

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local ReplicatedStorage = game:GetService("ReplicatedStorage").Shared
local BufferModule = require(ReplicatedStorage.Buffer)
local DataTypes = require(ReplicatedStorage.DataTypes)

export type metaData = {
    sessionId : string,
    version : number,
    size : number
}

export type container<T> = {
    data : T,
    meta : metaData,
    id : string,
}

export type LOAD_STATUS = "SUCCESS" | "ANOTHER_ACTIVE_SESSION" | "ALREADY_OPEN" | "DATASTORE_FAILED" | "UNKNOWN"
export type SAVE_STATUS = "SUCCESS" | "SESSION_NO_MATCH" | "OUTDATED_VERSION" | "NO_PREV_DATA" | "DATASTORE_FAILED" | "UNKNOWN"

export type dataGroup<T> = {
    _sample : T,
    _buffer : BufferModule.bufferObject<T>,
    _dataStore : DataStore,
    _containers : {[string] : container<T>},
    defaultData : T,
    name : string,
    container : (dataGroup : dataGroup<T>, id : string | number) -> container<T>,
    dump : (dataGroup : dataGroup<T>, id : string | number) -> (),
}

local RELEASED_SESSION = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

local metaBuffer = BufferModule.buff({
    sessionId = DataTypes.staticString("xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"),
    version = DataTypes.unsigned_long,
    size = DataTypes.unsigned_long,
} :: metaData)

local metaSize = metaBuffer._staticSize

local function pack(metaData : metaData, data : buffer) : buffer
    local dataSize = buffer.len(data)
    metaData.size = dataSize
    local meta = metaBuffer:encode(metaData)
    local package = buffer.create(metaSize + dataSize)
    buffer.copy(package, 0, meta)
    buffer.copy(package, metaSize, data)
    return package
end

local function unpack(package) : (metaData, buffer)
   local meta = buffer.fromstring(buffer.readstring(package, 0, metaSize))
   local metaData = metaBuffer:decode(meta)
   
   local data = buffer.fromstring(buffer.readstring(package, metaSize, metaData.size))
   return metaData, data
end

local function fetch<T>(group : dataGroup<T>, container : container<T>) : LOAD_STATUS
    
    local activeMetaData = container.meta
    local status : LOAD_STATUS = "UNKNOWN"

    local success, err = pcall(function()
        return group._dataStore:UpdateAsync(container.id, function(oldPackage)
            
            if not oldPackage then
                status = "SUCCESS"
                return pack(activeMetaData, group._buffer:encode(container.data))
            end

            local metaData, data = unpack(oldPackage)

            if metaData.sessionId ~= RELEASED_SESSION then
                if metaData.sessionId == activeMetaData.sessionId then
                    status = "ALREADY_OPEN"
                else
                    status = "ANOTHER_ACTIVE_SESSION"
                end              
                return oldPackage
            end            

            local decoded = group._buffer:decode(data)

            container.data = decoded
            activeMetaData.version = metaData.version
            activeMetaData.size = metaData.size
        
            status = "SUCCESS"
            return pack(activeMetaData, data)
        end)
    end)

    if not success then
        status = "DATASTORE_FAILED"
        warn("[DATASTORE][ERROR]", err)
    end

    return status
end

local function save<T>(group : dataGroup<T>, container : container<T>, shouldRelease : boolean?) : SAVE_STATUS
    
    local activeMetaData = container.meta
    local status : SAVE_STATUS = "UNKNOWN"

    local success, err = pcall(function()
        return group._dataStore:UpdateAsync(container.id, function(oldPackage)
            
            if not oldPackage then
                status = "NO_PREV_DATA"
                return oldPackage
            end

            local metaData, _data = unpack(oldPackage)

            if metaData.sessionId ~= activeMetaData.sessionId then
                status = "SESSION_NO_MATCH"
                return oldPackage
            end

            if metaData.version > activeMetaData.version then
                status = "OUTDATED_VERSION"
                return oldPackage
            end

            if shouldRelease then
                activeMetaData.sessionId = RELEASED_SESSION
            end

            activeMetaData.version += 1
            status = "SUCCESS"
            return pack(activeMetaData, group._buffer:encode(container.data))
        end)
    end)

    if not success then
        status = "DATASTORE_FAILED"
        warn("[DATASTORE][ERROR]", err)
    end

    return status
end

local function createContainer<T>(dataGroup : dataGroup<T>, id : string | number) : container<T>
    id = tostring(id)
    assert(id, "You must provide a valid id to create container.")
    
    local containers = dataGroup._containers
    assert(not containers[id :: string], "A container with similar id already exsists in the data group")

    local container : container<T>

    container = {
        id = id :: string,
        data = dataGroup.defaultData,
        name = string,
        meta = {version = 0, sessionId = HttpService:GenerateGUID(false), size = 0}
    }

    local status : LOAD_STATUS =  fetch(dataGroup, container)

    if status == "SUCCESS" and typeof(dataGroup.defaultData) == "table" then
        local data = container.data :: any
        local default = dataGroup.defaultData
        for key, value in default do
            if data[key] then continue end
            data[key] = value
        end
        for key, _ in data do
            if default[key] then continue end
            data[key] = nil
        end
    else
        warn("[DATASTORE][ERROR] failed to create container, STATUS=", status)
    end

    containers[id :: string] = container

    return table.freeze(container)
end

local function deleteContainer<T>(dataGroup : dataGroup<T>, id : string | number)
    id = tostring(id)
    assert(id, "You must provide a valid id to create container.")
    
    local containers = dataGroup._containers
    local container = containers[id :: string]
    if not container then 
        warn("[DATASTORE][WARN] Attempted to delete non-exsistent container, safely aborted deletion, id=", id) 
        return 
    end

    local status : SAVE_STATUS = save(dataGroup, container, true)

    if status ~= "SUCCESS" then
        warn("[DATASTORE][ERROR] failed to delete container, STATUS=", status)
        return
    end

    containers[id :: string] = nil
end

local function createDataGroup<T>(name : string, defaultData : T, sample : T) : dataGroup<T>
    local dataGroup : dataGroup<T>
    dataGroup = {
        _sample = sample,
        _buffer = BufferModule.buff(sample),
        _dataStore = DataStoreService:GetDataStore(name),
        name = name,
        _containers = {},
        defaultData = defaultData,
        container = createContainer,
        dump = deleteContainer,
    }
    print(dataGroup._buffer)
    return table.freeze(dataGroup)
end

return table.freeze({
    group = createDataGroup,
})
