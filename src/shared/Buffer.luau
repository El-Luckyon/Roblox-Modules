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
		return "n"..tostring(sample)
	elseif t == "string" then
		return "s"..tostring(sample)
	elseif t == "boolean" then
		return "b"..tostring(sample)
	elseif t == "Vector3" then
		local x = sample.X
		local y = sample.Y
		local z = sample.Z
		return "vec"..tostring(x + y + z)
	elseif t == "CFrame" then
		local x = sample.X
		local y = sample.Y
		local z = sample.Z
		return "cf"..tostring(x + y + z)
	elseif t == "Color3" then
		local r = sample.R
		local g = sample.G
		local b = sample.B
		return "co"..tostring(r + g + b)
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
	_staticMeta : {[any] : staticDataType<any>} | staticDataType<any> | nil,
	_dynamicMeta : {[any] : dynamicDataType<any>} | dynamicDataType<any> | nil,
	_bufferType : bufferType,
	_staticSize : number,
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
	local buff = buffer.create(size + 2)
	buffer.writeu16(buff, 0, size)
	dataType.bufferWrite(buff, 2, valueToWrite, size)
	return buff
end

-- A method to write the given data into STATIC-TABLE bufferObject
local function st_Write<T>(bufferObject : bufferObject<T>, valueToWrite : T) : buffer
	local buff = buffer.create(bufferObject._staticSize)
	
	local currentIndex = 0
	
	for key, dataType in bufferObject._staticMeta :: {[any] : staticDataType<any>} do
		local size = dataType.size
		dataType.bufferWrite(buff, currentIndex, (valueToWrite :: any)[key], size)
		currentIndex += size
	end
	
	return buff
end

-- A method to write the given data into DYNAMIC-TABLE bufferObject
local function dt_Write<T>(bufferObject : bufferObject<T>, valueToWrite : T) : buffer

	local dynamicMeta = bufferObject._dynamicMeta
	local dynamicSizes = {}
	local size = 0

	-- Dynamic size
	for key, dataType in dynamicMeta :: {[any] : dynamicDataType<any>} do
		local dynamicSize = dataType.findSize((valueToWrite :: any)[key])
		table.insert(dynamicSizes, dynamicSize)
		size += dynamicSize + 2
	end

	local buff = buffer.create(size)
	local currentIndex = 0
	local i = 0

	-- Dynamic write
	for key, dataType in dynamicMeta :: {[any] : dynamicDataType<any>} do
		i += 1
		local dynamicSize = dynamicSizes[i]
		buffer.writeu16(buff, currentIndex, dynamicSize)
		currentIndex += 2
		dataType.bufferWrite(buff, currentIndex, (valueToWrite :: any)[key], dynamicSize)
		currentIndex += dynamicSize
	end
	
	return buff
end

-- A method to write the given data into COMBINED bufferObject
local function c_Write<T>(bufferObject : bufferObject<T>, valueToWrite : T) : buffer

	local dynamicMeta = bufferObject._dynamicMeta
	local staticMeta = bufferObject._staticMeta
	local currentIndex = 0

	local dynamicSizes = {}
	local size = bufferObject._staticSize
	
	-- Dynamic size
	for key, dataType in dynamicMeta :: {[any] : dynamicDataType<any>} do
		local dynamicSize = dataType.findSize((valueToWrite :: any)[key])
		table.insert(dynamicSizes, dynamicSize)
		size += dynamicSize + 2
	end

	local buff = buffer.create(size)
	--// Static write
	
	for key, dataType in staticMeta :: {[any] : staticDataType<any>} do
		size = dataType.size
		dataType.bufferWrite(buff, currentIndex, (valueToWrite :: any)[key], size)
		currentIndex += size
	end
	
	local i = 0

	--// Dynamic write
	for key, dataType in dynamicMeta :: {[any] : dynamicDataType<any>} do
		i += 1
		local dynamicSize = dynamicSizes[i]
		buffer.writeu16(buff, currentIndex, dynamicSize)
		currentIndex += 2
		dataType.bufferWrite(buff, currentIndex, (valueToWrite :: any)[key], dynamicSize)
		currentIndex += dynamicSize
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
	return (bufferObject._dynamicMeta :: dynamicDataType<any>).bufferRead(buff, 2, buffer.readu16(buff, 0))
end

-- A method to read the given buffer using STATIC-TABLE bufferObject
local function st_Read<T>(bufferObject : bufferObject<T>, buff : buffer) : T
	local currentIndex = 0
	local decoded : T = {} :: any
	for key, dataType in bufferObject._staticMeta :: {[any] : staticDataType<any>} do
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
	for key, dataType in bufferObject._dynamicMeta :: {[any] : dynamicDataType<any>} do
		local size = buffer.readu16(buff, currentIndex)
		currentIndex += 2
		;(decoded :: any)[key] = dataType.bufferRead(buff, currentIndex, size)
		currentIndex += size				
	end
	return decoded
end

-- A method to read the given buffer using COMBINED bufferObject
local function c_Read<T>(bufferObject : bufferObject<T>, buff : buffer) : T
	local currentIndex = 0
	local decoded : T = {} :: any
	
	for key, dataType in bufferObject._staticMeta :: {[any] : staticDataType<any>} do
		local size = dataType.size
		;(decoded :: any)[key] = dataType.bufferRead(buff, currentIndex, size)
		currentIndex += size				
	end
	
	for key, dataType in bufferObject._dynamicMeta :: {[any] : dynamicDataType<any>} do
		local size = buffer.readu16(buff, currentIndex)
		currentIndex += 2
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
	local staticMeta = bufferObject._staticMeta
	local dynamicMeta = bufferObject._dynamicMeta
	local bufferType : bufferType = bufferObject._bufferType
	
	if typeof(sample) == "table" then
		
		-- If a table then iterate through each element and create static and/or dynamic table-meta
		local staticSize = 0
		local dynamicCount = 0
		staticMeta = {}
		dynamicMeta = {}
		
		for key, dataSample : Y in sample do
			local hash = hashType(dataSample)
			
			local dataType : staticDataType<Y> | dynamicDataType<Y> = staticTypeCache[hash]
			if dataType then 
				(staticMeta :: {[any] : staticDataType<Y>})[key] = dataType :: staticDataType<Y>
				staticSize += (dataType :: staticDataType<Y>).size
				continue
			end
			
			dataType = dynamicTypeCache[hash]
			assert(dataType, `Could not find a valid datatype for the given sample, sample={sample}, key={key}`)
			dynamicCount += 1
			
			(dynamicMeta :: {[any] : dynamicDataType<Y>})[key] = dataType :: dynamicDataType<Y> 
		end
		
		-- Assign bufferType based on static-size and dynamic-count
		bufferType = (dynamicCount == 0 and "STATIC-TABLE") or (staticSize == 0 and "DYNAMIC-TABLE") or "COMPLEX"
		bufferObject._staticSize = staticSize
		
		-- If static then set dynamic-meta to nil else-if dynamic then set static meta to nil
		if bufferType == "STATIC-TABLE" then 
            dynamicMeta = nil 
        elseif bufferType == "DYNAMIC-TABLE" then 
            staticMeta = nil 
        end
		
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
		
		bufferType = (not dynamicMeta and "STATIC-SINGLE") or (not staticMeta and "DYNAMIC-SINGLE") or "COMPLEX"
	end
	
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
		_bufferType = "STATIC-SINGLE",
		_staticSize = 0,
		encode = ss_Write,
		decode = ss_Read,
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

