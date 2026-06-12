--!strict
-- Pure cross-server session-lock state machine. No Roblox API; `now` (a UTC
-- wall-clock second count, e.g. os.time()) and `jobId` (game.JobId) are injected
-- so acquire/steal/expire are unit-testable. The lock lives inside the stored
-- profile; DataService applies these rules inside an UpdateAsync transform.

local SessionLock = {}

export type Lock = {
	jobId: string,      -- the server (game.JobId) that holds the session
	expiresAt: number,  -- UTC seconds after which the lock is stale and stealable
}

-- A lock is "live" only while held by a server and not past its expiry.
function SessionLock.isExpired(lock: Lock?, now: number): boolean
	if not lock then return true end
	return now >= lock.expiresAt
end

-- May `jobId` take/refresh the lock right now? Yes when there's no lock, the
-- existing lock has expired (steal), or we already hold it. A foreign, unexpired
-- lock is the only case that blocks — that's the live session on another server.
function SessionLock.canAcquire(lock: Lock?, jobId: string, now: number): boolean
	if not lock then return true end
	if now >= lock.expiresAt then return true end
	return lock.jobId == jobId
end

-- A fresh lock for `jobId`, valid for `ttl` seconds from `now`.
function SessionLock.make(jobId: string, now: number, ttl: number): Lock
	return { jobId = jobId, expiresAt = now + ttl }
end

return SessionLock
