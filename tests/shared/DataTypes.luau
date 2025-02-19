--!strict
--!native
--!optimize 2

local writef32 = buffer.writef32
local readf32 = buffer.readf32
local readu8 = buffer.readu8
local writeu8 = buffer.writeu8

local function readvec3(buff : buffer, startIndex : number, _sizeOfValue : number) : Vector3
	return Vector3.new(readf32(buff, startIndex), readf32(buff, startIndex + 4), readf32(buff, startIndex + 8))
end

local function writevec3(buff : buffer, startIndex : number, valueToWrite : Vector3, _sizeOfValue : number)
	writef32(buff, startIndex, valueToWrite.X)
	writef32(buff, startIndex + 4, valueToWrite.Y)
	writef32(buff, startIndex + 8, valueToWrite.Z)
end

local function writeBoolean(buff : buffer, startIndex : number, valueToWrite : boolean, _sizeOfValue : number)
	writeu8(buff, startIndex, valueToWrite == true and 1 or 0)
end

local function readBoolean(buff : buffer, startIndex, _size : number) : boolean
	return readu8(buff, startIndex) ~= 0
end

local function writeCFrame(buff : buffer, startIndex : number, valueToWrite : CFrame, _sizeOfValue : number)
	local pos = valueToWrite.Position
	local r = valueToWrite.RightVector
	local u = valueToWrite.UpVector
	local l = valueToWrite.LookVector
	
	writef32(buff, startIndex, pos.X)
	writef32(buff, startIndex + 4, pos.Y)
	writef32(buff, startIndex + 8, pos.Z)
	
	writef32(buff, startIndex + 12, r.X)
	writef32(buff, startIndex + 16, r.Y)
	writef32(buff, startIndex + 20, r.Z)
	
	writef32(buff, startIndex + 24, u.X)
	writef32(buff, startIndex + 28, u.Y)
	writef32(buff, startIndex + 32, u.Z)
	
	writef32(buff, startIndex + 36, l.X)
	writef32(buff, startIndex + 40, l.Y)
	writef32(buff, startIndex + 44, l.Z)
end

local function readCFrame(buff : buffer, startIndex : number, _size : number) : CFrame
	return CFrame.new(
		readf32(buff, startIndex), readf32(buff, startIndex + 4), readf32(buff, startIndex + 8),
		readf32(buff, startIndex + 12), readf32(buff, startIndex + 16), readf32(buff, startIndex + 20),
		readf32(buff, startIndex + 24), readf32(buff, startIndex + 28), readf32(buff, startIndex + 32),
		readf32(buff, startIndex + 36), readf32(buff, startIndex + 40), readf32(buff, startIndex + 44))
end

local function writeColor3(buff : buffer, startIndex : number, valueToWrite : Color3, _sizeOfValue : number)
	writeu8(buff, startIndex, valueToWrite.R * 255)
	writeu8(buff, startIndex + 1, valueToWrite.G * 255)
	writeu8(buff, startIndex + 2, valueToWrite.B * 255)
end

local function readColor3(buff : buffer, startIndex, _size : number) : Color3
	return Color3.fromRGB(readu8(buff, startIndex), readu8(buff, startIndex + 1), readu8(buff, startIndex + 2))
end

local BufferModule = require(game.ReplicatedStorage.Shared.Buffer)

return table.freeze({
	string = BufferModule.dType("", string.len, buffer.writestring, buffer.readstring),
	
	double = BufferModule.sType(640, 8, buffer.writef64, buffer.readf64),
	float = BufferModule.sType(320, 4, buffer.writef32, buffer.readf32),
	
	long = BufferModule.sType(-32, 4, buffer.writei32, buffer.readi32),
	unsigned_long = BufferModule.sType(32, 4, buffer.writeu32, buffer.readu32),
	
	int = BufferModule.sType(-16, 2, buffer.writei16, buffer.readi16),
	unsigned_int = BufferModule.sType(16, 2, buffer.writeu16, buffer.readu16),
	
	short = BufferModule.sType(-8, 1, buffer.writei8, buffer.readi8),
	unsigned_short = BufferModule.sType(8, 1, buffer.writeu8, buffer.readu8),
	
	boolean = BufferModule.sType(false, 1, writeBoolean, readBoolean),
		
	vector3 = BufferModule.sType(Vector3.new(), 12, writevec3, readvec3),
	cframe = BufferModule.sType(CFrame.new(), 48, writeCFrame, readCFrame),
	color3 = BufferModule.sType(Color3.new(), 3, writeColor3, readColor3),
})
	