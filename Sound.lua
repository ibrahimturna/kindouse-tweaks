-- Kindouse Tweaks: sound

local ADDON, ns = ...

----------------------------------------------------------------------
-- spell fizzle: the "whoosh" played when a cast fails (not ready, no target,
-- out of range...). Same method as Leatrix Plus' mute list: MuteSoundFile on
-- the five fizzle sound files, one per spell school.
----------------------------------------------------------------------
local FIZZLE = {
	569772, -- sound/spells/fizzle/fizzleholya.ogg
	569773, -- sound/spells/fizzle/fizzlefirea.ogg
	569774, -- sound/spells/fizzle/fizzlenaturea.ogg
	569775, -- sound/spells/fizzle/fizzlefrosta.ogg
	569776, -- sound/spells/fizzle/fizzleshadowa.ogg
}

ns.Register({
	key = "muteFizzle",
	category = "Sound",
	label = "Mute spell fizzle sound",
	tooltip = "Silences the whoosh/fizzle sound played when a spell cast fails.",
	default = true,
	apply = function(enabled)
		-- mutes last until the client is closed, so they are redone every login
		local fn = enabled and MuteSoundFile or UnmuteSoundFile
		if not fn then return end
		for _, id in ipairs(FIZZLE) do pcall(fn, id) end
	end,
})

----------------------------------------------------------------------
-- error speech: "I can't do that yet", "Not enough mana"...
----------------------------------------------------------------------
ns.Register({
	key = "noErrorSpeech",
	category = "Sound",
	label = "Disable error speech",
	tooltip = "Stops your character saying things like \"I can't do that yet\". Same as the game's own Error Speech sound option, kept switched off for you.",
	default = true,
	apply = function(enabled, isLogin)
		-- when the tweak is off, leave the game's own option alone at login
		if isLogin and not enabled then return end
		local set = (C_CVar and C_CVar.SetCVar) or SetCVar
		if set then pcall(set, "Sound_EnableErrorSpeech", enabled and "0" or "1") end
	end,
})
