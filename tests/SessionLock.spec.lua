--!strict
-- TestEZ spec for the pure SessionLock state machine (P0.3 / ISSUES #11),
-- including a simulated two-server race against a mock store.

return function()
	local SessionLock = require(game.ReplicatedStorage.Shared.Modules.SessionLock)

	local TTL = 600

	describe("isExpired", function()
		it("treats a missing lock as expired", function()
			expect(SessionLock.isExpired(nil, 0)).to.equal(true)
		end)
		it("is false before expiry", function()
			expect(SessionLock.isExpired({ jobId = "A", expiresAt = 100 }, 50)).to.equal(false)
		end)
		it("is true at/after expiry", function()
			expect(SessionLock.isExpired({ jobId = "A", expiresAt = 100 }, 100)).to.equal(true)
		end)
	end)

	describe("canAcquire", function()
		it("acquires when there is no lock", function()
			expect(SessionLock.canAcquire(nil, "A", 0)).to.equal(true)
		end)
		it("is blocked by a foreign, unexpired lock", function()
			expect(SessionLock.canAcquire({ jobId = "A", expiresAt = 100 }, "B", 50)).to.equal(false)
		end)
		it("steals a foreign expired lock", function()
			expect(SessionLock.canAcquire({ jobId = "A", expiresAt = 100 }, "B", 100)).to.equal(true)
		end)
		it("re-acquires its own lock", function()
			expect(SessionLock.canAcquire({ jobId = "A", expiresAt = 100 }, "A", 50)).to.equal(true)
		end)
	end)

	describe("make", function()
		it("sets expiresAt to now + ttl", function()
			local lock = SessionLock.make("A", 1000, TTL)
			expect(lock.jobId).to.equal("A")
			expect(lock.expiresAt).to.equal(1000 + TTL)
		end)
	end)

	describe("two-server race (mock store) never loses the newer write", function()
		-- Minimal store: a transform that returns non-nil writes, nil cancels.
		local function makeStore()
			local stored: any = nil
			return {
				update = function(transform: (any) -> any)
					local result = transform(stored)
					if result ~= nil then stored = result end
				end,
				peek = function() return stored end,
			}
		end

		-- Lock-aware load/save mirroring DataService's transforms.
		local function load(store: any, jobId: string, now: number): boolean
			local acquired = false
			store.update(function(old: any)
				if type(old) == "table" and not SessionLock.canAcquire(old.sessionLock, jobId, now) then
					return nil
				end
				local data = old or { value = 0 }
				data.sessionLock = SessionLock.make(jobId, now, TTL)
				acquired = true
				return data
			end)
			return acquired
		end

		local function save(store: any, jobId: string, now: number, value: number, release: boolean?): boolean
			local wrote = false
			store.update(function(old: any)
				if type(old) == "table" and not SessionLock.canAcquire(old.sessionLock, jobId, now) then
					return nil
				end
				local data = old or { value = 0 }
				data.value = value
				data.sessionLock = if release then nil else SessionLock.make(jobId, now, TTL)
				wrote = true
				return data
			end)
			return wrote
		end

		it("blocks the second server and preserves the active server's newer data", function()
			local store = makeStore()

			-- Server A loads + writes value 1.
			expect(load(store, "A", 0)).to.equal(true)
			expect(save(store, "A", 5, 1)).to.equal(true)

			-- Server B tries to load 10s later, within A's TTL → refused.
			expect(load(store, "B", 10)).to.equal(false)
			-- A B-side write attempt must NOT clobber A's data.
			expect(save(store, "B", 12, 999)).to.equal(false)
			expect(store.peek().value).to.equal(1)

			-- A keeps playing and writes a newer value; it still owns the lock.
			expect(save(store, "A", 20, 2)).to.equal(true)
			expect(store.peek().value).to.equal(2)

			-- A leaves and releases the lock.
			expect(save(store, "A", 30, 2, true)).to.equal(true)

			-- Now B can take over cleanly; A's last value is intact.
			expect(load(store, "B", 40)).to.equal(true)
			expect(store.peek().sessionLock.jobId).to.equal("B")
			expect(store.peek().value).to.equal(2)
		end)

		it("lets a server steal an expired lock after a crash (no release)", function()
			local store = makeStore()
			expect(load(store, "A", 0)).to.equal(true)
			expect(save(store, "A", 5, 7)).to.equal(true)
			-- A crashes (never releases). B waits past the TTL, then steals.
			expect(load(store, "B", 5 + TTL)).to.equal(true)
			expect(store.peek().sessionLock.jobId).to.equal("B")
			expect(store.peek().value).to.equal(7)  -- last persisted data survives
		end)
	end)
end
