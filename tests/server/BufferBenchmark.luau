-- --!strict
-- --!optimize 2
-- --!native

-- local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- local BufferModule = require(ReplicatedStorage.Shared.Buffer)

-- -- Utility functions for Vector3 serialization (unused in these benchmarks)
-- local function readvec3(buff : buffer, startIndex : number, sizeOfValue : number) : Vector3
-- 	return Vector3.new(buffer.readf32(buff, startIndex), buffer.readf32(buff, startIndex + 4), buffer.readf32(buff, startIndex + 8))
-- end

-- local function writevec3(buff : buffer, startIndex : number, valueToWrite : Vector3, sizeOfValue : number)
-- 	buffer.writef32(buff, startIndex, valueToWrite.X)
-- 	buffer.writef32(buff, startIndex + 4, valueToWrite.Y)
-- 	buffer.writef32(buff, startIndex + 8, valueToWrite.Z)
-- end

-- -- Data types
-- local str = BufferModule.dType("", string.len, buffer.writestring, buffer.readstring)
-- local f64 = BufferModule.sType(640, 8, buffer.writef64, buffer.readf64)
-- local u8 = BufferModule.sType(16, 1, buffer.writeu8, buffer.readu8)

-- -- Benchmark function that runs the given function 'iterations' times,
-- -- stores each iteration’s elapsed time in an array,
-- -- and returns the average time along with the times array.
-- local function benchmarkMulti(func : (...any) -> (...any), iterations : number) : number
-- 	local times = {} :: {number}
-- 	for i = 1, iterations do
-- 		local startTime = os.clock()
-- 		func()
-- 		local elapsed = os.clock() - startTime
-- 		table.insert(times, elapsed)
-- 		if i % 100_000 == 0 then
-- 			task.wait()
-- 		end
-- 	end
	
-- 	local totalTime = 0
-- 	for _, t in ipairs(times) do
-- 		totalTime += t
-- 	end
-- 	local avgTime = totalTime / iterations
-- 	return avgTime
-- end

-- local iterations = 1_000_000

-- -- Benchmark buffer creation (only average times printed)
-- local avg_ss = benchmarkMulti(function() return BufferModule.buff(f64) end, iterations)
-- local avg_ds = benchmarkMulti(function() return BufferModule.buff(str) end, iterations)
-- local avg_sa = benchmarkMulti(function() return BufferModule.buff({f64, u8, u8}) end, iterations)
-- local avg_sh = benchmarkMulti(function() return BufferModule.buff({ float = f64, small_int = u8, small_int2 = u8 }) end, iterations)
-- local avg_da = benchmarkMulti(function() return BufferModule.buff({str, str, str}) end, iterations)
-- local avg_dh = benchmarkMulti(function() return BufferModule.buff({ str1 = str, str2 = str, str3 = str }) end, iterations)
-- local avg_ca = benchmarkMulti(function() return BufferModule.buff({ str, u8, u8 }) end, iterations)
-- local avg_ch = benchmarkMulti(function() return BufferModule.buff({ str1 = str, small_int = u8, small_int2 = u8 }) end, iterations)

-- print("Static-Single buffer creation avg:", string.format("%.15f", avg_ss))
-- print("Dynamic-Single buffer creation avg:", string.format("%.15f", avg_ds))
-- print("Static-Array buffer creation avg:", string.format("%.15f", avg_sa))
-- print("Static-Hash buffer creation avg:", string.format("%.15f", avg_sh))
-- print("Dynamic-Array buffer creation avg:", string.format("%.15f", avg_da))
-- print("Dynamic-Hash buffer creation avg:", string.format("%.15f", avg_dh))
-- print("Complex-Array buffer creation avg:", string.format("%.15f", avg_ca))
-- print("Complex-Hash buffer creation avg:", string.format("%.15f", avg_ch))

-- -- Benchmark encode/decode; returns average encode and decode times
-- local function benchmark_encode_decode(buff, value, iterations : number)
-- 	local avg_encode = benchmarkMulti(function() return buff:encode(value) end, iterations)
-- 	local encoded = buff:encode(value)
-- 	local avg_decode = benchmarkMulti(function() return buff:decode(encoded) end, iterations)
-- 	return avg_encode, avg_decode
-- end

-- local avg_encode_ss, avg_decode_ss = benchmark_encode_decode(BufferModule.buff(f64), 640.0, iterations)
-- local avg_encode_ds, avg_decode_ds = benchmark_encode_decode(BufferModule.buff(str), "Hello, world!", iterations)
-- local avg_encode_sa, avg_decode_sa = benchmark_encode_decode(BufferModule.buff({f64, u8, u8}), {640.0, 16, 32}, iterations)
-- local avg_encode_sh, avg_decode_sh = benchmark_encode_decode(BufferModule.buff({ float = f64, small_int = u8, small_int2 = u8 }), {float = 640.0, small_int = 16, small_int2 = 32}, iterations)
-- local avg_encode_da, avg_decode_da = benchmark_encode_decode(BufferModule.buff({str, str, str}), {"Hello", "World", "!"}, iterations)
-- local avg_encode_dh, avg_decode_dh = benchmark_encode_decode(BufferModule.buff({ str1 = str, str2 = str, str3 = str }), {str1 = "Hello", str2 = "World", str3 = "!"}, iterations)
-- local avg_encode_ca, avg_decode_ca = benchmark_encode_decode(BufferModule.buff({ str, u8, u8 }), {"Hello", 16, 32}, iterations)
-- local avg_encode_ch, avg_decode_ch = benchmark_encode_decode(BufferModule.buff({ str1 = str, small_int = u8, small_int2 = u8 }), {str1 = "Hello", small_int = 16, small_int2 = 32}, iterations)

-- print("Static-Single buffer encode avg:", string.format("%.15f", avg_encode_ss))
-- print("Static-Single buffer decode avg:", string.format("%.15f", avg_decode_ss))
-- print("Dynamic-Single buffer encode avg:", string.format("%.15f", avg_encode_ds))
-- print("Dynamic-Single buffer decode avg:", string.format("%.15f", avg_decode_ds))
-- print("Static-Array buffer encode avg:", string.format("%.15f", avg_encode_sa))
-- print("Static-Array buffer decode avg:", string.format("%.15f", avg_decode_sa))
-- print("Static-Hash buffer encode avg:", string.format("%.15f", avg_encode_sh))
-- print("Static-Hash buffer decode avg:", string.format("%.15f", avg_decode_sh))
-- print("Dynamic-Array buffer encode avg:", string.format("%.15f", avg_encode_da))
-- print("Dynamic-Array buffer decode avg:", string.format("%.15f", avg_decode_da))
-- print("Dynamic-Hash buffer encode avg:", string.format("%.15f", avg_encode_dh))
-- print("Dynamic-Hash buffer decode avg:", string.format("%.15f", avg_decode_dh))
-- print("Complex-Array buffer encode avg:", string.format("%.15f", avg_encode_ca))
-- print("Complex-Array buffer decode avg:", string.format("%.15f", avg_decode_ca))
-- print("Complex-Hash buffer encode avg:", string.format("%.15f", avg_encode_ch))
-- print("Complex-Hash buffer decode avg:", string.format("%.15f", avg_decode_ch))

-- return 0
