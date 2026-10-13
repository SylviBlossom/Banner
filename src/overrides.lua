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

-- Quick double tap on touch toggles bans
local orig_Controller_L_cursor_press = Controller.L_cursor_press
function Controller:L_cursor_press(x, y, ...)
	orig_Controller_L_cursor_press(self, x, y, ...)

	if self.HID.touch then
		mod.touch_press_uptime = G.TIMERS.UPTIME
	end
end

local orig_Controller_L_cursor_release = Controller.L_cursor_release
function Controller:L_cursor_release(x, y, ...)
	orig_Controller_L_cursor_release(self, x, y, ...)

	local press_uptime = mod.touch_press_uptime
	mod.touch_press_uptime = nil

	if not self.HID.touch or mod.config.left_click then
		mod.last_tap = nil
		return
	end

	if self.cursor_up.handled then
		mod.last_tap = nil
		return
	end

	local target = self.cursor_hover.target

	local quick_tap = target and target ~= G.ROOM
		and Vector_Dist(self.cursor_down.T, self.cursor_up.T) < G.MIN_CLICK_DIST
		and G.TIMERS.UPTIME - (press_uptime or G.TIMERS.UPTIME) < mod.DOUBLE_TAP_TIME

	if not quick_tap then
		mod.last_tap = nil
		return
	end

	local time = G.TIMERS.UPTIME

	if mod.last_tap and mod.last_tap.target == target and time - mod.last_tap.time <= mod.DOUBLE_TAP_TIME then
		mod.last_tap = nil
		mod.handle_collection_toggle(target)
	else
		mod.last_tap = {target = target, time = time}
	end
end

-- Controller: double-press A to toggle bans, Y to toggle a focused item
local orig_Controller_button_press_update = Controller.button_press_update
function Controller:button_press_update(button, dt)
	if self.HID.controller then
		local target = self.focused.target or self.cursor_hover.target

		if button == 'y' then
			if mod.handle_collection_toggle(target) then
				mod.last_controller_press = nil
				return
			end
		elseif button == 'a' and not mod.config.left_click and mod.config.controller_double_press then
			local time = G.TIMERS.UPTIME

			if mod.last_controller_press
				and mod.last_controller_press.target == target
				and time - mod.last_controller_press.time <= mod.DOUBLE_TAP_TIME then
				mod.last_controller_press = nil
				if mod.handle_collection_toggle(target) then
					return
				end
			else
				mod.last_controller_press = {target = target, time = time}
			end
		end
	end

	orig_Controller_button_press_update(self, button, dt)
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
