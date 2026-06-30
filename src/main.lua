BANNERMOD = {
	base = SMODS.current_mod,
	id = SMODS.current_mod.id,
	config = SMODS.current_mod.config
}

assert(SMODS.load_file("src/overrides.lua"))()
assert(SMODS.load_file("src/ui.lua"))()
assert(SMODS.load_file("src/poker_hand_overrides.lua"))()

SMODS.Atlas({
	key = "modicon",
	path = "modicon.png",
	px = 34,
	py = 34
})

local mod = BANNERMOD

mod.locked_keys = {
	["c_base"] = true,
	["soul"] = true,
	["undiscovered_joker"] = true,
	["undiscovered_tarot"] = true,
	["e_base"] = true,
	["bl_small"] = true,
	["bl_big"] = true,
	["High Card"] = true,
}

function mod.set_disabled(key, value)
	if mod.locked_keys[key] then
		return false
	end

	if not value then
		value = nil
	end

	mod.config.disabled_keys[key] = value

	return true
end

function mod.is_disabled(key)
	return mod.config.disabled_keys[key] or false
end

function mod.update_disabled()
	if not G.GAME then return end

	if G.GAME.bannermod_disabled then
		for k, v in pairs(G.GAME.bannermod_disabled) do
			if v then G.GAME.banned_keys[k] = G.GAME.bannermod_last_banned[k] end
		end
	end

	G.GAME.bannermod_disabled = {}
	G.GAME.bannermod_last_banned = {}

	for k, v in pairs(mod.config.disabled_keys) do
		if v then
			G.GAME.bannermod_disabled[k] = true
			G.GAME.bannermod_last_banned[k] = G.GAME.banned_keys[k]
			G.GAME.banned_keys[k] = true
		end
	end
end

function mod.save_disabled()
	SMODS.save_mod_config(mod.base)
end

function mod.setup_game(new)
	mod.update_disabled()
end

function mod.apply_editions(options)
	if not G.GAME or not G.GAME.bannermod_disabled then
		return options
	end
	local new_options = {}
	for _, v in ipairs(options) do
		local key = type(v) == "table" and v.name or v
		if not G.GAME.bannermod_disabled[key] then
			table.insert(new_options, v)
		end
	end
	return new_options
end

mod.base.config_tab = function()
	return {n = G.UIT.ROOT, config = {r = 0.1, minw = 4, align = "tm", padding = 0.2, colour = G.C.BLACK}, nodes = {
		{n = G.UIT.C, config = {r = 0.1, minw = 4, align = "tc", padding = 0.2, colour = G.C.BLACK}, nodes = {
			{n = G.UIT.R, config = {align = "cm", r = 0.1, padding = 0.2}, nodes = {
				create_toggle({
					label = localize("c_bannermod_left_click"),
					ref_table = mod.config,
					ref_value = 'left_click',
					callback = function() SMODS.save_mod_config(mod.base) end
				}),
				create_toggle({
					label = localize("c_bannermod_limit_poker_hand_scoring"),
					info = localize("c_bannermod_limit_poker_hand_scoring_desc"),
					ref_table = mod.config,
					ref_value = 'limit_poker_hand_scoring',
					callback = function() SMODS.save_mod_config(mod.base) end
				}),
				create_toggle({
					label = localize("c_bannermod_hide_collection"),
					info = localize("c_bannermod_hide_collection_desc"),
					ref_table = mod.config,
					ref_value = 'hide_collection',
					callback = function()
						SMODS.save_mod_config(mod.base)
						set_discover_tallies()
						set_profile_progress()
						-- G:save_progress()
					end
				})
			}},
		}},
	}}
end
