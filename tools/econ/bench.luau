-- @file Big-number money benchmarks: arithmetic cost, profile size, payload size
-- @domain qa
-- @status wip
-- @see [[BigMoney.luau]]
-- `lune run tools/econ/bench` prints per-operation costs at 20 and 303 digits, and the size of a
-- profile's money and a state payload's money as JSON. Desktop-CPU numbers (Lune), for relative
-- cost: Roblox servers and phones run the same Luau VM, typically slower.

local serde = require("@lune/serde")
local B = require("../../src/shared/BigMoney")
local W = require("../../src/shared/Wallet")

local function time(label: string, n: number, fn: () -> ())
	local t0 = os.clock()
	for _ = 1, n do
		fn()
	end
	local us = (os.clock() - t0) / n * 1e6
	print(("%-44s %9.2f us/op"):format(label, us))
	return us
end

local small = "12345678901234567890" -- 20 digits (~12 Qi)
local big = B.MAX -- 303 digits
local big2 = B.sub(B.MAX, "123456789") :: string
print("Arithmetic (Lune, this machine):")
time("compare, 20 digits", 200000, function()
	B.cmp(small, "12345678901234567891")
end)
time("compare, 303 digits", 200000, function()
	B.cmp(big, big2)
end)
time("add, 20 digits", 50000, function()
	B.add(small, small)
end)
time("add, 303 digits", 20000, function()
	B.add(big2, "999")
end)
time("sub, 303 digits", 20000, function()
	B.sub(big, big2)
end)
time("x1.5 (mulFactors), 303 digits", 20000, function()
	B.mulFactors(big2, { 1.5 })
end)
time("x1.5 x2 (two factors), 303 digits", 20000, function()
	B.mulFactors(big2, { 1.5, 2 })
end)
time("mul 151 x 151 digits", 2000, function()
	B.mul(big:sub(1, 151), big:sub(1, 151))
end)
time("parse/validate, 303 digits", 50000, function()
	B.parse(big)
end)
time("compact format, 303 digits", 50000, function()
	B.compact(big)
end)
time("full format (403 chars), 303 digits", 20000, function()
	B.full(big)
end)
local d = { Coins = 0, Stats = { TotalEarned = 0 } }
W.load(d)
W.setCashForTest(d, big2:sub(1, 300))
time("Wallet.earn (sale), 300-digit balance", 20000, function()
	W.earn(d, "1000")
end)
time("Wallet.spend, 300-digit balance", 20000, function()
	W.spend(d, "1000")
end)

print("")
print("Sizes (JSON):")
local function size(v: any): number
	return #serde.encode("json", v)
end
local legacy = { Coins = 1000000000000000, Stats = { TotalEarned = 1000000000000000 } }
local p1 = { Coins = 0, Stats = { TotalEarned = 0 } }
W.load(p1)
W.earn(p1, "1250000000000000000")
local pMax = { Coins = 0, Stats = { TotalEarned = 0 } }
W.load(pMax)
W.earn(pMax, B.MAX)
print(("%-44s %6d bytes"):format("legacy money fields (RC10, at 1 Qa)", size(legacy)))
print(("%-44s %6d bytes"):format("schema 2 money (Wallet + mirror), 1.25 Qi", size(p1)))
print(("%-44s %6d bytes"):format("schema 2 money (Wallet + mirror), MAX", size(pMax)))
print(
	("%-44s %6d bytes"):format(
		"PlayerState money fields at MAX",
		size({ Coins = B.MAX, Lifetime = B.MAX, CarriedValue = B.MAX })
	)
)
print("DataStore value limit: 4,194,304 bytes per key")
