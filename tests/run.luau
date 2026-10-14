-- @file Unit test runner (Lune)
-- @domain qa
-- @status stable
-- Unit test runner (Lune): `lune run tests/run`. Each spec returns { [name] = fn }.
local specs = {
	require("./economy.spec"),
	require("./environment.spec"),
	require("./progression.spec"),
	require("./detector.spec"),
	require("./pursuit.spec"),
	require("./salvagelog.spec"),
	require("./moverules.spec"),
	require("./money.spec"),
	require("./titles.spec"),
}
local passed, failed = 0, 0
for _, spec in specs do
	for name, fn in spec do
		local ok, err = pcall(fn)
		if ok then
			passed += 1
		else
			failed += 1
			print(("FAIL  %s\n      %s"):format(name, tostring(err)))
		end
	end
end
print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then
	error("unit tests failed")
end
