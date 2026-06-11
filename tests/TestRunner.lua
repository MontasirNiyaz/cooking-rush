--!nonstrict
-- Minimal TestEZ-compatible runner for the specs in this folder.
--
-- Why not real TestEZ: the specs use the bare `describe`/`it`/`expect` DSL that
-- TestEZ injects via `setfenv`. Rather than vendor the whole library, this runner
-- provides the same surface the specs actually use (`describe`, `it`,
-- `expect(x).to.equal(y)`, `expect(x).to.be.ok()`) and injects it with `setfenv`
-- (verified to work in Studio). Tests run eagerly — the specs here are pure and
-- have no beforeEach/afterEach ordering needs.
--
-- Run from the command bar / execute_luau (Server datamodel):
--   require(game.ServerStorage.Tests.TestRunner).runAll()

local TestRunner = {}

-- Build the `expect(value)` matcher chain.
local function expect(value: any)
	local function fail(msg: string)
		error(msg, 3)
	end

	local toBe = {
		ok = function()
			if value == nil or value == false then
				fail(string.format("expected value to be ok, got %s", tostring(value)))
			end
		end,
	}

	local to = {
		be = toBe,
		equal = function(expected: any)
			if value ~= expected then
				fail(string.format("expected %s, got %s", tostring(expected), tostring(value)))
			end
		end,
	}

	return { to = to }
end

-- Run a list of spec ModuleScripts (each returns a function()).
function TestRunner.run(specs: { ModuleScript })
	local passed, failed = 0, 0
	local failures: { string } = {}
	local nameStack: { string } = {}

	local function describe(name: string, fn: () -> ())
		table.insert(nameStack, name)
		local ok, err = pcall(fn)
		if not ok then
			-- A describe body that throws (not inside an `it`) is a hard failure.
			failed += 1
			table.insert(failures, table.concat(nameStack, " › ") .. " — describe error: " .. tostring(err))
		end
		table.remove(nameStack)
	end

	local function it(name: string, fn: () -> ())
		table.insert(nameStack, name)
		local label = table.concat(nameStack, " › ")
		table.remove(nameStack)

		local ok, err = pcall(fn)
		if ok then
			passed += 1
		else
			failed += 1
			table.insert(failures, label .. "  —  " .. tostring(err))
		end
	end

	local env = setmetatable({
		describe = describe,
		it = it,
		expect = expect,
	}, { __index = getfenv(1) })

	for _, spec in ipairs(specs) do
		local label = spec.Name:gsub("%.spec$", "")
		local specFn = require(spec)
		if type(specFn) ~= "function" then
			failed += 1
			table.insert(failures, label .. " — spec did not return a function")
		else
			table.insert(nameStack, label)
			setfenv(specFn, env)
			local ok, err = pcall(specFn)
			if not ok then
				failed += 1
				table.insert(failures, label .. " — load error: " .. tostring(err))
			end
			table.remove(nameStack)
		end
	end

	print(string.format("[Tests] %d passed, %d failed", passed, failed))
	for _, f in ipairs(failures) do
		warn("[Tests] FAIL: " .. f)
	end

	return { passed = passed, failed = failed, failures = failures }
end

-- Discover and run every sibling `*.spec` ModuleScript.
function TestRunner.runAll()
	local specs: { ModuleScript } = {}
	for _, child in ipairs(script.Parent:GetChildren()) do
		if child:IsA("ModuleScript") and child.Name:match("%.spec$") then
			table.insert(specs, child)
		end
	end
	table.sort(specs, function(a, b)
		return a.Name < b.Name
	end)
	return TestRunner.run(specs)
end

return TestRunner
