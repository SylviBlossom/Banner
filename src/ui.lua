local mod = BANNERMOD

local function get_key(obj)
	if mod.viewed_collection_pool_ref == G.P_CENTER_POOLS.Seal then
		return obj.seal or "c_base"
	elseif mod.viewed_collection_pool_ref == G.P_BLINDS then
		return obj.config and obj.config.blind and obj.config.blind.key or "c_base"
	elseif mod.viewed_collection_pool_ref == G.P_TAGS then
		return obj.config and obj.config.tag and obj.config.tag.key or "c_base"
	elseif mod.viewed_collection_pool_ref == SMODS.Stickers then
		return "c_base"
	else
		return obj.config and obj.config.center and obj.config.center.key or "c_base"
	end
end

function mod.check_compatibility()
	local list = {}

	if mod.view_type == "blinds" then
		if next(SMODS.find_mod("ADeckCreatorModule")) then
			table.insert(list, "Deck Creator")
		end
	end

	return #list == 0, list
end

function mod.handle_collection_click_card(card)
	if not G.your_collection then
		return false
	end

	if not mod.check_compatibility() then
		return false
	end

	local in_collection = false
	for _, area in ipairs(G.your_collection) do
		if not area.REMOVED and card.area == area then
			in_collection = true
			break
		end
	end
	if not in_collection then
		return false
	end

	card:juice_up(0.3, 0.3)

	local key = get_key(card)

	if mod.is_disabled(key) then
		play_sound('generic1')
		if mod.set_disabled(key, false) then
			card.debuff = false
		end
	else
		play_sound('cancel')
		if mod.set_disabled(key, true) then
			card.debuff = true
			card.bannermod_no_debuff_tip = true
		end
	end

	mod.save_disabled()
	mod.update_disabled()
	mod.rebuild_collection_sidebar()

	return true
end

function mod.handle_collection_click_tag(tag)
	if not tag.bannermod_in_collection then
		return false
	end

	if not mod.check_compatibility() then
		return false
	end

	tag:juice_up(0.3, 0.3)

	local key = get_key(tag)

	if mod.is_disabled(key) then
		play_sound('generic1')
		if mod.set_disabled(key, false) then
			tag.bannermod_disabled = false
		end
	else
		play_sound('cancel')
		if mod.set_disabled(key, true) then
			tag.bannermod_disabled = true
		end
	end

	mod.save_disabled()
	mod.update_disabled()
	mod.rebuild_collection_sidebar()

	return true
end

function mod.handle_collection_click_poker_hand(hover_target)
	if not mod.check_compatibility() then
		return false
	end

	local key = nil

	for handname, ui_definition in pairs(mod.poker_hand_ui_rows) do
		if hover_target.config == ui_definition.config then
			key = handname
			break
		end
	end

	if not key then
		return false
	end

	if mod.is_disabled(key) then
		play_sound('generic1')
		if mod.set_disabled(key, false) then
			mod.update_poker_hand_ref_text(key)
		end
	else
		play_sound('cancel')
		if mod.set_disabled(key, true) then
			mod.update_poker_hand_ref_text(key)
		end
	end

	mod.save_disabled()
	mod.update_disabled()
	mod.rebuild_collection_sidebar()

	return true
end

function mod.handle_collection_toggle(target)
	if G.CONTROLLER.locks.frame or not G.OVERLAY_MENU or G.OVERLAY_MENU.REMOVED then
		return false
	end

	target = target or G.CONTROLLER.cursor_hover.target

	if mod.view_type == "hands" then
		if not target or not target.config then
			return false
		end
		return mod.handle_collection_click_poker_hand(target)

	elseif mod.view_type == "tags" then
		if not target or not target:is(Sprite) then
			return false
		end
		return mod.handle_collection_click_tag(target)

	elseif G.your_collection then
		if not target or not target:is(Card) then
			return false
		end
		return mod.handle_collection_click_card(target)
	end
end

function mod.handle_collection_right_click()
	return mod.handle_collection_toggle()
end

function mod.debuff_collection_page()
	if not mod.check_compatibility() then
		return
	end

	if mod.view_type == "cards" or mod.view_type == "blinds" then
		for i = 1, #G.your_collection do
			for _, v in ipairs(G.your_collection[i].cards) do
				if mod.is_disabled(get_key(v)) then
					v.debuff = true
					v.bannermod_no_debuff_tip = true
				end
			end
		end

	elseif mod.view_type == "tags" then
		for _, v in pairs(G.I.SPRITE) do
			if v.config and v.config.tag and v.bannermod_in_collection then
				if mod.is_disabled(get_key(v)) then
					v.bannermod_disabled = true
				end
			end
		end
	end
end

function mod.create_poker_hand_ref_table(handname, default)
	mod.poker_hand_ui_ref_tables = mod.poker_hand_ui_ref_tables or {}

	local ref_table = {text = default, default = default}

	mod.poker_hand_ui_ref_tables[handname] = ref_table

	mod.update_poker_hand_ref_text(handname)

	return ref_table
end

function mod.update_poker_hand_ref_text(handname)
	mod.poker_hand_ui_ref_tables = mod.poker_hand_ui_ref_tables or {}

	local ref_table = mod.poker_hand_ui_ref_tables[handname]

	if ref_table == nil then
		return
	end

	if mod.is_disabled(handname) then
		ref_table.text = "Banned"
	else
		ref_table.text = ref_table.default
	end
end

function mod.get_directions_key()
	if G.CONTROLLER.HID.touch then
		return mod.config.left_click and 'k_bannermod_directions_touch_left' or 'k_bannermod_directions_touch'
	elseif G.CONTROLLER.HID.controller then
		if mod.config.left_click then
			return 'k_bannermod_directions_controller_left'
		elseif mod.config.controller_double_press then
			return 'k_bannermod_directions_controller'
		end
		return 'k_bannermod_directions_controller_y'
	end

	return mod.config.left_click and 'k_bannermod_directions_left' or 'k_bannermod_directions_right'
end

function mod.collection_toggle_all(enable)
	play_sound(enable and 'tarot1' or 'cancel')

	if mod.view_type == "cards" or mod.view_type == "blinds" then
		for k, v in ipairs(mod.viewed_collection_pool) do
			if not v.no_collection then
				mod.set_disabled(v.key, not enable)
			end
		end

		for _, area in ipairs(G.your_collection) do
			if not area.REMOVED and area.states.visible then
				for _, card in ipairs(area.cards) do
					if card.debuff ~= mod.is_disabled(get_key(card)) then
						card:juice_up(0.3, 0.3)
						card.debuff = not enable
						card.bannermod_no_debuff_tip = not enable
					end
				end
			end
		end

	elseif mod.view_type == "tags" then
		for k, v in ipairs(mod.viewed_collection_pool) do
			if not v.no_collection then
				mod.set_disabled(v.key, not enable)
			end
		end

		for _, v in pairs(G.I.SPRITE) do
			if v.config and v.config.tag and v.bannermod_in_collection then
				if v.bannermod_disabled ~= mod.is_disabled(get_key(v)) then
					v:juice_up(0.3, 0.3)
					v.bannermod_disabled = not enable
				end
			end
		end

	elseif mod.view_type == "hands" then
		for k, v in ipairs(mod.viewed_collection_pool) do
			if not v.no_collection then
				mod.set_disabled(v.key, not enable)
				mod.update_poker_hand_ref_text(v.key)
			end
		end

	elseif mod.view_type == "main_mod" or (mod.view_type == "main" and not enable) then
		local mod_check = mod.view_type == "main_mod"

		for k, v in pairs(G.P_CENTERS) do
			if not v.no_collection and (not mod_check or (v.mod and v.mod.id == mod.viewed_mod.id)) then
				mod.set_disabled(v.key, not enable)
			end
		end
		for k, v in pairs(G.P_SEALS) do
			if not v.no_collection and (not mod_check or (v.mod and v.mod.id == mod.viewed_mod.id)) then
				mod.set_disabled(v.key, not enable)
			end
		end
		for k, v in pairs(G.P_BLINDS) do
			if not v.no_collection and (not mod_check or (v.mod and v.mod.id == mod.viewed_mod.id)) then
				mod.set_disabled(v.key, not enable)
			end
		end
		for k, v in pairs(G.P_TAGS) do
			if not v.no_collection and (not mod_check or (v.mod and v.mod.id == mod.viewed_mod.id)) then
				mod.set_disabled(v.key, not enable)
			end
		end
		for k, v in pairs(SMODS.PokerHands) do
			if not v.no_collection and (not mod_check or (v.mod and v.mod.id == mod.viewed_mod.id)) then
				mod.set_disabled(v.key, not enable)
			end
		end

	elseif mod.view_type == "main" and enable then
		mod.config.disabled_keys = {}
	end

	mod.save_disabled()
	mod.update_disabled()
	mod.rebuild_collection_sidebar()
end

local function tally_disabled()
	local total = 0
	local count = 0

	if mod.view_type == "cards" or mod.view_type == "blinds" or mod.view_type == "tags" or mod.view_type == "hands" then
		for k, v in ipairs(mod.viewed_collection_pool) do
			if not v.no_collection and not mod.locked_keys[v.key] then
				total = total + 1
				if not mod.is_disabled(v.key) then
					count = count + 1
				end
			end
		end

	elseif mod.view_type == "main" or mod.view_type == "main_mod" then
		local mod_check = mod.view_type == "main_mod"

		local function tally_in_pool(pool)
			for k, v in pairs(pool) do
				if not v.no_collection and not mod.locked_keys[v.key] and (not mod_check or (v.mod and v.mod.id == mod.viewed_mod.id)) then
					total = total + 1
					if not mod.is_disabled(v.key) then
						count = count + 1
					end
				end
			end
		end

		tally_in_pool(G.P_CENTERS)
		tally_in_pool(G.P_SEALS)
		tally_in_pool(G.P_BLINDS)
		tally_in_pool(G.P_TAGS)
		tally_in_pool(SMODS.PokerHands)
	end

	return count, total
end

G.FUNCS.bannermod_enable_all = function()
	mod.collection_toggle_all(true)
end

G.FUNCS.bannermod_disable_all = function()
	mod.collection_toggle_all(false)
end

function mod.rebuild_collection_sidebar()
	if not mod.view_sidebar_tally then
		return
	end

	local count, total = tally_disabled()

	mod.view_sidebar_tally.text = count..' / '..total
end

function mod.build_collection_sidebar()
	local compatibile, incompatible_list = mod.check_compatibility()

	if compatibile then
		local count, total = tally_disabled()

		mod.view_sidebar_tally = {text = count..' / '..total}

		local directions_key = mod.get_directions_key()

		return {
			simple_text_container('k_bannermod_name', {colour = G.C.UI.TEXT_LIGHT, scale = 0.4}),
			simple_text_container(directions_key, {colour = G.C.JOKER_GREY}),
			{n=G.UIT.R, config={align = "cm", minh = 0.4}, nodes={
				{n=G.UIT.T, config={ref_table = mod.view_sidebar_tally, ref_value = 'text', scale = 0.35, colour = G.C.UI.TEXT_LIGHT, no_recalc = true}}
			}},
			UIBox_button({button = 'bannermod_enable_all', label = localize('b_bannermod_enable_all'), scale = 0.35, minw = 1.5, minh = 0.45, colour = G.C.GREEN}),
			UIBox_button({button = 'bannermod_disable_all', label = localize('b_bannermod_disable_all'), scale = 0.35, minw = 1.5, minh = 0.45, colour = G.C.RED}),
		}
	else
		local name_nodes = {
			{n=G.UIT.R, config={align = "cm", padding = 0}, nodes={
				{n=G.UIT.T, config={text = localize('k_bannermod_incompatible'), scale = 0.35, colour = G.C.JOKER_GREY}}
			}}
		}
		for _, v in ipairs(incompatible_list) do
			table.insert(name_nodes, {n=G.UIT.R, config={align = "cm", padding = 0}, nodes={
				{n=G.UIT.T, config={text = v, scale = 0.35, colour = G.C.JOKER_GREY}}
			}})
		end

		return {
			simple_text_container('k_bannermod_name', {colour = G.C.UI.TEXT_LIGHT, scale = 0.4}),
			{n=G.UIT.R, config={align = "cm", padding = 0.03, minh = 0.4}, nodes=name_nodes}
		}
	end
end

local function hook_your_collection(f, tf, view_type)
	view_type = view_type or "cards"
	return function(...)
		local pool = ...
		mod.view_type = view_type
		if mod.view_type == "cards" and pool == SMODS.Stickers then
			mod.view_type = ""
		end
		if mod.view_type == "cards" then
			mod.viewed_collection_pool = SMODS.collection_pool(pool)
			mod.viewed_collection_pool_ref = pool
		elseif mod.view_type == "blinds" then
			mod.viewed_collection_pool = SMODS.collection_pool(G.P_BLINDS)
			mod.viewed_collection_pool_ref = G.P_BLINDS
		elseif mod.view_type == "tags" then
			mod.viewed_collection_pool = SMODS.collection_pool(G.P_TAGS)
			mod.viewed_collection_pool_ref = G.P_TAGS
		elseif mod.view_type == "hands" then
		    mod.viewed_collection_pool = SMODS.collection_pool(SMODS.PokerHands)
			mod.viewed_collection_pool_ref = SMODS.PokerHands
		else
			mod.viewed_collection_pool = nil
			mod.viewed_collection_pool_ref = nil
		end
		local t = f(...)
		if mod.view_type == "blinds" or mod.view_type == "tags" then
			mod.debuff_collection_page()
		end
		if t and t.nodes and mod.view_type ~= "" then
			tf(t, function(box)
				return {n=G.UIT.R, config={align = "cm", padding = 0.1}, nodes={
					{n=G.UIT.C, config={align = "cm"}, nodes={
						{n=G.UIT.R, config={align = "cm", minh = 1,r = 0.3, padding = 0.07, minw = 1, colour = G.C.JOKER_GREY, emboss = 0.1}, nodes={
							{n=G.UIT.C, config={id="bannermod_sidebar", align = "cm", minh = 1,r = 0.2, padding = 0.2, minw = 1, colour = G.C.L_BLACK}, nodes=mod.build_collection_sidebar()},
						}},
					}},
					{n=G.UIT.C, config={align = "cm"}, nodes={
						box
					}},
				}}
			end)
		end
		return t
	end
end

local basic_hooks = {
	{"create_UIBox_your_collection",                "main"},
	{"create_UIBox_your_collection_blinds",         "blinds"},
	{"create_UIBox_your_collection_tarots",         ""},
	{"create_UIBox_your_collection_planets",        ""},
	{"create_UIBox_your_collection_spectrals",      ""},
	{"create_UIBox_your_collection_decks",          ""},
	{"create_UIBox_your_collection_tags_content",   "tags"},
	{"create_UIBox_your_collection_consumables",    ""},
	{"create_UIBox_your_collection_poker_hands",    "hands"},
	{"create_UIBox_Other_GameObjects",              ""},
}
for _, v in ipairs(basic_hooks) do
	_G[v[1]] = hook_your_collection(_G[v[1]], function(t, f)
		if t.nodes[1] then
			t.nodes[1] = f(t.nodes[1])
		end
	end, v[2])
end

SMODS.card_collection_UIBox = hook_your_collection(SMODS.card_collection_UIBox, function(t, f)
	if t.nodes[1] then
		t.nodes[1] = f(t.nodes[1])
	end
end)
