--!strict
--!native
--!optimize 2

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--  DDDD    AAAAA   TTTTT   AAAAA   TTTTT   Y   Y  PPPP   EEEEE  SSSSS
--  D   D  A     A    T    A     A    T     Y Y   P   P  E      S
--  D   D  AAAAAAA    T    AAAAAAA    T      Y    PPPP   EEEE   SSSS
--  D   D  A     A    T    A     A    T      Y    P      E          S
--  DDDD   A     A    T    A     A    T      Y    P      EEEEE  SSSSS

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


-- A method that can write data of the given type into the given buffer
export type bufferWrite<Y> = (buff : buffer, startIndex : number, valueToWrite : Y, sizeOfValue : number) -> ()

-- A method that can extract the data related to the given type from the given buffer
export type bufferRead<Y> = (buff : buffer, startIndex : number, size : number) -> Y

-- A method that takes in a sample of type and returns the size of the sample
export type findSize<Y> = (sample : Y) -> number

-- A static data type where the size of data is fixed
export type staticDataType<Y> = {
	sample : Y,
	size : number,
	bufferWrite : bufferWrite<Y>,
	bufferRead : bufferRead<Y>,
}

-- A dynamic data type where the size of the data is not know until runtime
export type dynamicDataType<Y> = {
	sample : Y,
	findSize : findSize<Y>,
	bufferWrite : bufferWrite<Y>,
	bufferRead : bufferRead<Y>,
}

local staticTypeCache : {[string] : staticDataType<any>} = {}
local dynamicTypeCache : {[string] : dynamicDataType<any>} = {}

-- A method that produces a unique key for each varying sample of a type
local function hashType(sample : any) : string
	if not sample then return "__null" end
	local t = typeof(sample)
	if t == "number" then
		return "n/"..tostring(sample)
	elseif t == "string" then
		return "s/"..tostring(sample)
	elseif t == "boolean" then
		return "b/"..tostring(sample)
	elseif t == "Vector3" then
		local x = sample.X
		local y = sample.Y
		local z = sample.Z
		return "vec/"..tostring(x + y + z)
	elseif t == "CFrame" then
		local x = sample.X
		local y = sample.Y
		local z = sample.Z
		return "cf/"..tostring(x + y + z)
	elseif t == "Color3" then
		local r = sample.R
		local g = sample.G
		local b = sample.B
		return "co/"..tostring(r + g + b)
	else
		warn(`Sample type not supported assigning null type, sample={sample}`)
		return "__null"
	end
end

-- A method that constructs a staticDataType 
local function createStaticDataType<Y>(sample : Y, size : number, bufferWrite : bufferWrite<Y>, bufferRead : bufferRead<Y>) : Y
	local hash = hashType(sample)
	assert(not staticTypeCache[hash], `You cannont create to static-datatypes using the same sample ie: (sampleA = 1 and sampleB == 1), sample={sample}`)
	
	local dataType : staticDataType<Y>
	
	dataType = {
		sample = sample,
		size = size,
		bufferWrite = bufferWrite,
		bufferRead = bufferRead
	}
	
	staticTypeCache[hash] = dataType
	
	return sample
end

-- A method that constructs a dynamicDataType
local function createDynamicDataType<Y>(sample : Y, findSize : findSize<Y>, bufferWrite : bufferWrite<Y>, bufferRead : bufferRead<Y>) : Y
	local hash = hashType(sample)
	assert(not dynamicTypeCache[hash], `You cannont create to dynamic-datatypes using the same sample ie: (sampleA = 1 and sampleB == 1), sample={sample}`)
	
	local dataType : dynamicDataType<Y>
	
	dataType = {
		sample = sample,
		findSize = findSize,
		bufferWrite = bufferWrite,
		bufferRead = bufferRead
	}
	
	dynamicTypeCache[hash] = dataType

	return sample
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--  BBBBB   U   U  FFFFF  FFFFF  EEEEE  RRRR    SSSSS
--  B    B  U   U  F      F      E      R   R  S
--  BBBBB   U   U  FFFF   FFFF   EEEE   RRRR   SSS
--  B    B  U   U  F      F      E      R  R      S
--  BBBBB   UUUU   F      F      EEEEE  R   R  SSSSS


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

export type bufferType = "STATIC-SINGLE" | "DYNAMIC-SINGLE" | "COMPLEX" | "STATIC-TABLE" | "DYNAMIC-TABLE"
export type bufferEncode<T> = (bufferObject : bufferObject<T>, valueToWrite : T) -> buffer
export type bufferDecode<T> = (bufferObject : bufferObject<T>, buff : buffer) -> T

-- An object that holds all the details needed to write a given datatype/datatype(s) into buffer or read a datatype/datatype-pack from a buffer
export type bufferObject<T> = {
	_sample : T,
	_staticMeta : {staticDataType<any>} | staticDataType<any> | nil,
	_dynamicMeta : {dynamicDataType<any>} | dynamicDataType<any> | nil,
	_staticSize : number,
	_statickeys : {string},
	_dynamicKeys : {string},
	encode : bufferEncode<T>,
	decode : bufferDecode<T>,
}


-- A method to write the given data into STATIC-SINGLE bufferObject
local function ss_Write<T>(bufferObject : bufferObject<T>, valueToWrite : T) : buffer
	local dataType = bufferObject._staticMeta :: staticDataType<any>
	local buff = buffer.create(dataType.size)
	dataType.bufferWrite(buff, 0, valueToWrite, dataType.size)
	return buff
end

-- A method to write the given data into DYNAMIC-SINGLE bufferObject
local function ds_Write<T>(bufferObject : bufferObject<T>, valueToWrite : T) : buffer
	local dataType = bufferObject._dynamicMeta :: dynamicDataType<any>
	local size = dataType.findSize(valueToWrite)
	local buff = buffer.create(size + 4)
	buffer.writeu32(buff, 0, size)
	dataType.bufferWrite(buff, 4, valueToWrite, size)
	return buff
end

-- A method to write the given data into STATIC-TABLE bufferObject
local function st_Write<T>(bufferObject : bufferObject<T>, valueToWrite : T) : buffer
	local buff = buffer.create(bufferObject._staticSize )
	
	local currentIndex = 0
	local staticMeta = bufferObject._staticMeta :: {staticDataType<any>}
	local keys = bufferObject._statickeys

	--// Static write	
	for i = 1, #staticMeta do
		local dataType = staticMeta[i]
		local key = keys[i]
		local fieldSize = dataType.size
		dataType.bufferWrite(buff, currentIndex, (valueToWrite :: any)[key], fieldSize)
		currentIndex += fieldSize
	end

	return buff
end

-- A method to write the given data into DYNAMIC-TABLE bufferObject
local function dt_Write<T>(bufferObject : bufferObject<T>, valueToWrite : T) : buffer

	local dynamicMeta = bufferObject._dynamicMeta :: {dynamicDataType<any>}
	local dynamicSizes = {}
	local size = 0
	local keys = bufferObject._dynamicKeys

	-- Dynamic size
	for i = 1, #dynamicMeta do
		local dataType = dynamicMeta[i]
		local key = keys[i]
		local dynamicSize = dataType.findSize((valueToWrite :: any)[key])
		dynamicSizes[i] = dynamicSize
		size += dynamicSize + 4
	end

	local buff = buffer.create(size)
	local currentIndex = 0

	-- Dynamic write
	for i = 1, #dynamicMeta do
		local dataType = dynamicMeta[i]
		local key = keys[i]
		local fieldSize = dynamicSizes[i]
		buffer.writeu32(buff, currentIndex, fieldSize)
		currentIndex += 4
		dataType.bufferWrite(buff, currentIndex, (valueToWrite :: any)[key], fieldSize)
		currentIndex += fieldSize
	end
	
	return buff
end

-- A method to write the given data into COMBINED bufferObject
local function c_Write<T>(bufferObject : bufferObject<T>, valueToWrite : T) : buffer

	local dynamicMeta = bufferObject._dynamicMeta :: {dynamicDataType<any>}
	local staticMeta = bufferObject._staticMeta :: {staticDataType<any>}
	local currentIndex = 0

	local dynamicSizes = {}
	local size = bufferObject._staticSize
	local dkeys = bufferObject._dynamicKeys
	local skeys = bufferObject._statickeys
	
	-- Dynamic size
	for i = 1, #dynamicMeta do
		local dataType = dynamicMeta[i]
		local key = dkeys[i]
		local dynamicSize = dataType.findSize((valueToWrite :: any)[key])
		dynamicSizes[i] = dynamicSize
		size += dynamicSize + 4
	end

	local buff = buffer.create(size)

	--// Static write	
	for i = 1, #staticMeta do
		local dataType = staticMeta[i]
		local key = skeys[i]
		local fieldSize = dataType.size
		dataType.bufferWrite(buff, currentIndex, (valueToWrite :: any)[key], fieldSize)
		currentIndex += fieldSize
	end

	-- Dynamic write
	for i = 1, #dynamicMeta do
		local dataType = dynamicMeta[i]
		local key = dkeys[i]
		local fieldSize = dynamicSizes[i]
		buffer.writeu32(buff, currentIndex, fieldSize)
		currentIndex += 4
		dataType.bufferWrite(buff, currentIndex, (valueToWrite :: any)[key], fieldSize)
		currentIndex += fieldSize
	end
	
	return buff
end


-- A method to read the given buffer using STATIC-SINGLE bufferObject
local function ss_Read<T>(bufferObject : bufferObject<T>, buff : buffer) : T
	local dataType = bufferObject._staticMeta :: staticDataType<any>
	return dataType.bufferRead(buff, 0, dataType.size)
end

-- A method to read the given buffer using DYNAMIC-SINGLE bufferObject
local function ds_Read<T>(bufferObject : bufferObject<T>, buff : buffer) : T
	return (bufferObject._dynamicMeta :: dynamicDataType<any>).bufferRead(buff, 4, buffer.readu32(buff, 0))
end

-- A method to read the given buffer using STATIC-TABLE bufferObject
local function st_Read<T>(bufferObject : bufferObject<T>, buff : buffer) : T
	local currentIndex = 0
	local decoded : T = {} :: any
	local staticMeta = bufferObject._staticMeta :: {staticDataType<T>}
	local staticKeys = bufferObject._statickeys
	
	for i = 1, #staticMeta do
		local dataType = staticMeta[i]
		local key = staticKeys[i]
		local size = dataType.size
		;(decoded :: any)[key] = dataType.bufferRead(buff, currentIndex, size)
		currentIndex += size				
	end

	return decoded :: T
end

-- A method to read the given buffer using DYNAMIC-TABLE bufferObject
local function dt_Read<T>(bufferObject : bufferObject<T>, buff : buffer) : T
	local currentIndex = 0
	local decoded : T = {} :: any

	local dynamicMeta = bufferObject._dynamicMeta :: {dynamicDataType<T>}
	local dynamicKeys = bufferObject._dynamicKeys

	for i = 1, #dynamicMeta do
		local dataType = dynamicMeta[i]
		local key = dynamicKeys[i]
		local size = buffer.readu32(buff, currentIndex)
		currentIndex += 4
		(decoded :: any)[key] = dataType.bufferRead(buff, currentIndex, size)
		currentIndex += size				
	end

	return decoded
end

-- A method to read the given buffer using COMBINED bufferObject
local function c_Read<T>(bufferObject : bufferObject<T>, buff : buffer) : T
	local currentIndex = 0
	local decoded : T = {} :: any
	
	local staticMeta = bufferObject._staticMeta :: {staticDataType<T>}
	local staticKeys = bufferObject._statickeys
	local dynamicMeta = bufferObject._dynamicMeta :: {dynamicDataType<T>}
	local dynamicKeys = bufferObject._dynamicKeys
	
	for i = 1, #staticMeta do
		local dataType = staticMeta[i]
		local key = staticKeys[i]
		local size = dataType.size
		;(decoded :: any)[key] = dataType.bufferRead(buff, currentIndex, size)
		currentIndex += size				
	end
	
	for i = 1, #dynamicMeta do
		local dataType = dynamicMeta[i]
		local key = dynamicKeys[i]
		local size = buffer.readu32(buff, currentIndex)
		currentIndex += 4
		;(decoded :: any)[key] = dataType.bufferRead(buff, currentIndex, size)
		currentIndex += size				
	end
	
	return decoded
end


local typeToWrite = {
	["STATIC-SINGLE"] = ss_Write,
	["DYNAMIC-SINGLE"] = ds_Write,
	["STATIC-TABLE"] = st_Write,
	["DYNAMIC-TABLE"] = dt_Write,
	["COMPLEX"] = c_Write,
}

local typeToRead = {
	["STATIC-SINGLE"] = ss_Read,
	["DYNAMIC-SINGLE"] = ds_Read,
	["STATIC-TABLE"] = st_Read,
	["DYNAMIC-TABLE"] = dt_Read,
	["COMPLEX"] = c_Read,
}

-- A method that returns a meta data linking the sample to its datatype also determines the bufferObject type
local function buildMeta<T, Y>(bufferObject : bufferObject<T>)
	
	local sample = bufferObject._sample
	local staticMeta
	local dynamicMeta
	local bufferType : bufferType = "STATIC-SINGLE"
	
	if typeof(sample) == "table" then
		
		-- If a table then iterate through each element and create static and/or dynamic table-meta
		local staticSize = 0
		local staticCount = 0
		local dynamicCount = 0

		staticMeta = {}
		dynamicMeta = {}

		local keys = {}
		local hashes = {}
		local dynamicKeys = {}
		local staticKeys = {}

		for k, v in sample do
			table.insert(keys, k)
			hashes[k] = hashType(v)
		end

		table.sort(keys)
		
		for i = 1, #keys do
			local key = keys[i]
			local hash = hashes[key]
			local dataType : staticDataType<Y> | dynamicDataType<Y> = staticTypeCache[hash]
			if dataType then
				staticCount += 1
				staticSize += (dataType ::  staticDataType<Y>).size
				staticKeys[staticCount] = key
				;(staticMeta :: {staticDataType<Y>})[staticCount] = dataType :: any
			else
				dataType = dynamicTypeCache[hash]
				assert(dataType, `Could not find a valid datatype for the given sample, sample={sample[key]}, key={key}`)
				dynamicCount += 1
				dynamicKeys[dynamicCount] = key
				;(dynamicMeta :: {dynamicDataType<Y>})[dynamicCount] = dataType :: any
			end			
		end

		bufferObject._staticSize = staticSize
		bufferObject._staticMeta = staticCount ~= 0 and staticMeta or nil
		bufferObject._dynamicMeta = dynamicCount ~= 0 and dynamicMeta or nil	
		bufferObject._statickeys = staticKeys
		bufferObject._dynamicKeys = dynamicKeys

	else
		-- If not a table then create single static or dynamic meta
		local hash = hashType(sample)
		
		local dataType : staticDataType<Y> | dynamicDataType<Y> = staticTypeCache[hash]
		
		if dataType then 
			staticMeta = dataType :: staticDataType<Y>
		else
			dataType = dynamicTypeCache[hash]
			assert(dataType, `Could not find a valid datatype for the given sample, sample={sample}`)
			dynamicMeta = dataType :: dynamicDataType<Y>
		end
		
	end

	bufferType = (not dynamicMeta and "STATIC-SINGLE") or (not staticMeta and "DYNAMIC-SINGLE") or "COMPLEX"
	
	bufferObject._staticMeta = staticMeta
	bufferObject._dynamicMeta = dynamicMeta
	bufferObject.encode = typeToWrite[bufferType]
	bufferObject.decode = typeToRead[bufferType]
end

-- Creates a bufferObject of the type of the sample-provided
local function createBufferObject<T>(sample : T)	
	local bufferObject : bufferObject<T>
	
	bufferObject = {
		_sample = sample,
		_staticSize = 0,
		encode = ss_Write,
		decode = ss_Read,
	 	_statickeys = {},
		_dynamicKeys = {}
	}
	
	buildMeta(bufferObject)
	return bufferObject
end

return table.freeze({
	sType = createStaticDataType,
	dType = createDynamicDataType,
	hash = hashType,
	buff = createBufferObject,
})

