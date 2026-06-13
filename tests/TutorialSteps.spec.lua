--!strict
-- Spec for the TutorialSteps config + its schema validator (P1.2 onboarding).

return function()
	local Shared        = game.ReplicatedStorage.Shared
	local Schema        = require(Shared.Modules.Schema)
	local TutorialSteps = require(Shared.Config.TutorialSteps)
	local Stations      = require(Shared.Config.Stations)
	local Ingredients   = require(Shared.Config.Ingredients)

	describe("shipped TutorialSteps", function()
		it("passes schema validation against real stations/ingredients", function()
			local r = Schema.validateTutorialSteps(TutorialSteps, Stations, Ingredients)
			expect(r.ok).to.equal(true)
		end)

		it("starts with a levelStart-triggered step", function()
			expect(TutorialSteps[1].trigger.kind).to.equal("levelStart")
		end)
	end)

	describe("validateTutorialSteps catches bad content", function()
		it("flags a highlight pointing at an unknown station", function()
			local bad = { {
				id = "x", trigger = { kind = "levelStart" },
				highlight = { kind = "station", id = "does_not_exist" },
				promptText = "p", completeOn = { kind = "serve" },
			} }
			expect(Schema.validateTutorialSteps(bad, Stations, Ingredients).ok).to.equal(false)
		end)

		it("flags a completeOn holding an unknown item", function()
			local bad = { {
				id = "x", trigger = { kind = "levelStart" },
				highlight = { kind = "none" },
				promptText = "p", completeOn = { kind = "hold", item = "not_an_item" },
			} }
			expect(Schema.validateTutorialSteps(bad, Stations, Ingredients).ok).to.equal(false)
		end)

		it("flags an afterStep that references a forward/unknown step", function()
			local bad = { {
				id = "a", trigger = { kind = "afterStep", step = "b" },
				highlight = { kind = "none" },
				promptText = "p", completeOn = { kind = "serve" },
			} }
			expect(Schema.validateTutorialSteps(bad, Stations, Ingredients).ok).to.equal(false)
		end)

		it("flags a duplicate step id", function()
			local bad = {
				{ id = "a", trigger = { kind = "levelStart" }, highlight = { kind = "none" },
					promptText = "p", completeOn = { kind = "serve" } },
				{ id = "a", trigger = { kind = "afterStep", step = "a" }, highlight = { kind = "none" },
					promptText = "p", completeOn = { kind = "serve" } },
			}
			expect(Schema.validateTutorialSteps(bad, Stations, Ingredients).ok).to.equal(false)
		end)
	end)
end
