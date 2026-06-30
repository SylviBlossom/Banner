local mod = BANNERMOD

---------------
-- Gameplay
---------------

local orig_SMODS_is_poker_hand_visible = SMODS.is_poker_hand_visible
function SMODS.is_poker_hand_visible(handname, ...)
	if G.GAME and G.GAME.bannermod_disabled and G.GAME.bannermod_disabled[handname] then
		return false
	end
	return orig_SMODS_is_poker_hand_visible(handname, ...)
end

---------------
-- UI
---------------

local orig_Controller_queue_R_cursor_press = Controller.queue_R_cursor_press
function Controller:queue_R_cursor_press(x, y, ...)
	if not mod.config.left_click and mod.handle_collection_right_click() then return end
	orig_Controller_queue_R_cursor_press(self, x, y, ...)
end

local orig_INIT_COLLECTION_CARD_ALERTS = INIT_COLLECTION_CARD_ALERTS
function INIT_COLLECTION_CARD_ALERTS(...)
	orig_INIT_COLLECTION_CARD_ALERTS(...)
	mod.debuff_collection_page()
end

local orig_G_FUNCS_your_collection_blinds_page = G.FUNCS.your_collection_blinds_page
function G.FUNCS.your_collection_blinds_page(args, ...)
	local result = orig_G_FUNCS_your_collection_blinds_page(args, ...)
	mod.debuff_collection_page()
	return result
end

local orig_buildAdditionsTab = buildAdditionsTab
function buildAdditionsTab(_mod, ...)
	local result = orig_buildAdditionsTab(_mod, ...)

	if result and result.tab_definition_function then
		local orig_func = result.tab_definition_function

		result.tab_definition_function = function()
			local t = orig_func()
			if not t then return end

			mod.view_type = "main_mod"
			mod.viewed_mod = _mod
			mod.viewed_collection_pool = nil
			mod.viewed_collection_pool_ref = nil

			t.n = G.UIT.R
			t.config.align = "cm"
			return {n=G.UIT.ROOT, config={align = "tm", padding = 0.1, colour = G.C.CLEAR}, nodes={
				{n=G.UIT.C, config={align = "cm"}, nodes={
					{n=G.UIT.C, config={id="bannermod_sidebar", emboss = 0.05, minh = 1, r = 0.1, minw = 1, align = "cm", padding = 0.2, colour = G.C.BLACK}, nodes=mod.build_collection_sidebar()}
				}},
				{n=G.UIT.C, config={align = "cm"}, nodes={
					t
				}},
			}}
		end
	end

	return result
end

local orig_Card_generate_UIBox_ability_table = Card.generate_UIBox_ability_table
function Card:generate_UIBox_ability_table(vars_only, ...)
	local disabled_debuff = false

	if self.debuff and self.bannermod_no_debuff_tip then
		self.debuff = false
		disabled_debuff = true
	end

	local results = {orig_Card_generate_UIBox_ability_table(self, vars_only, ...)}

	if disabled_debuff then
		self.debuff = true
	end

	return unpack(results)
end

local orig_Tag_generate_UI = Tag.generate_UI
function Tag:generate_UI(_size, ...)
	local tab, sprite = orig_Tag_generate_UI(self, _size, ...)

	local orig_sprite_draw = sprite.draw
	function sprite.draw(_self)
		orig_sprite_draw(_self)

		if _self.bannermod_disabled then
			local tilt_var = _self.role.draw_major or _self

			local send_to_shader = {
				math.min(_self.VT.r*3, 1) + G.TIMERS.REAL/(28) + (_self.juice and _self.juice.r*20 or 0),
				G.TIMERS.REAL
			}

			_self:draw_shader('debuff', nil, send_to_shader)
		end
	end

	local orig_sprite_click = sprite.click
	function sprite.click(_self)
		if mod.config.left_click and mod.handle_collection_click_tag(_self) then
			return
		end

		orig_sprite_click(_self)
	end

	return tab, sprite
end

local orig_create_UIBox_current_hand_row = create_UIBox_current_hand_row
function create_UIBox_current_hand_row(handname, simple, in_collection, ...)
	local result = orig_create_UIBox_current_hand_row(handname, simple, in_collection, ...)

	if in_collection then
		mod.poker_hand_ui_rows = mod.poker_hand_ui_rows or {}
		mod.poker_hand_ui_rows[handname] = result
	end

	return result
end

local orig_SMODS_collection_pool = SMODS.collection_pool
function SMODS.collection_pool(_base_pool)
	local pool = orig_SMODS_collection_pool(_base_pool)
	if mod.config.hide_collection then
		local i = 1
		while pool[i] do
			if mod.config.disabled_keys[pool[i].key] then
				table.remove(pool, i)
			else
				i = i + 1
			end
		end
	end
	return pool
end
