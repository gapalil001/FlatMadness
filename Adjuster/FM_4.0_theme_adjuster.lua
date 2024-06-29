-- @description FM_4.0_theme_adjuster
-- @author Ed Kashinsky
-- @about Theme adjuster for Flat Maddness theme
-- @version 1.0.0
-- @provides
--   images/*.png

local ImGui
local CONTEXT = ({reaper.get_action_context()})
local SCRIPT_NAME = CONTEXT[2]:match("([^/\\]+)%.lua$")
local SCRIPT_PATH = CONTEXT[2]:match("(.*[/\\])")

if reaper.ImGui_GetBuiltinPath == nil or not pcall(function()
	package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
	ImGui = require 'imgui' '0.9'
end) then
	reaper.MB('Please install "ReaImGui: ReaScript binding for Dear ImGui" (minimum v.0.9) library via ReaPack to customize theme. Also you can use default theme adjuster', SCRIPT_NAME, 0)
	reaper.Main_OnCommand(reaper.NamedCommandLookup("_RS1cbf05b0c4f875518496f34a5ce45adefe05cb67"), 0) -- Options: Show theme adjuster
	return
end

-- Create entry point for default adjuster if needed
local path = (reaper.GetResourcePath() .. '/Scripts/Cockos/FM_4.0_theme_adjuster.lua'):gsub('\\','/')
if not reaper.file_exists(path) then
	local file = io.open(path,"w+")
	if file then
		io.output(file)
		io.write("reaper.Main_OnCommand(reaper.NamedCommandLookup(\"_RS41f817f7ffd55d2ee0d9e54d1d04fe978ac0450c\"), 0) -- FM_4.0_theme_adjuster \n")
		io.close(file)
	end
end

local adj = {
	cached_images = {},
	cached_fonts = {},
	opened_first_tab = false,
	cached_heights = {},
	config = {
		width = 453,
		height = 650,
		font_name = 'Arial',
		font_size = 14,
		font_size_header = 18,
		font_types = {
			None = ImGui.FontFlags_None,
			Italic = ImGui.FontFlags_Italic,
			Bold = ImGui.FontFlags_Bold,
		},
		borderRad = {
			image = 20,
			block = 15
		},
		colors = {
			White = 0xffffffff,
			Background = 0x414141ff,
			SectionBackground = 0x929292ff,
			ParameterBlockBackground = 0x7d7d7dff,
			Header = 0x252525ff,
			Subheader = 0xd4d4d4ff,
			Selected = 0xf89202ff,
			Text = 0x171717ff,
			Label = 0x575757ff,
			Input = {
				Header = 0x686868ff,
				Background = 0x686868ff,
				Hover = 0x686868bb,
				Text = 0xe9e9e9ff,
				Label = 0xffffffff,
			},
		},
		param_types = {
			Simple = 1,
			OneImage = 2,
			Checkbox = 3,
			Range = 4,
		},
		windFlags = ImGui.WindowFlags_NoScrollbar | ImGui.WindowFlags_NoScrollWithMouse,
		childFlags = ImGui.ChildFlags_AlwaysUseWindowPadding | ImGui.ChildFlags_AutoResizeY,
		tableFlags = ImGui.TableFlags_BordersV | ImGui.TableFlags_BordersOuterH | ImGui.TableFlags_RowBg,
		header = { image = nil, src = "images/header.png" }
	}
}

adj.params = {
	meter_position = {
		id = 1,
		name = 'Meter position',
		type = adj.config.param_types.Simple,
		width = 400,
		height = 165,
		colspan = 2,
		values = {
			{ name = "Left", value = 1, image = "images/pref_tcp_meterleft.png", borderRad = 5 },
			{ name = "Meterbridge", value = 2, image = "images/pref_tcp_meterbridge.png", borderRad = 5 },
			{ name = "Right", value = 3, image = "images/pref_tcp_meterright.png", borderRad = 5 },
			{ name = "Almost Right", value = 4, image = "images/pref_tcp_meterrightedge.png", borderRad = 5 },
		}
	},
	pan_type = {
		id = 2,
		name = 'Pan/Width Visualization',
		type = adj.config.param_types.Simple,
		width = 400,
		height = 155,
		values = {
			{ name = "Knob", value = 2, image = "images/pref_tcp_knob.png" },
			{ name = "Slider*", value = 1, image = "images/pref_tcp_slider.png" },
		}
	},
	min_fxlist = {
		id = 3,
		name = 'FX SLOT MINIMAL WIDTH',
		type = adj.config.param_types.Range,
		width = 195,
		height = 65,
	},
	embed_position = {
		id = 4,
		name = 'EMBEDDED UI POSITION',
		type = adj.config.param_types.Simple,
		width = 195,
		height = 165,
		colspan = 1,
		values = {
			{ name = "Beside FX", value = 1, image = "images/pref_tcp_embedright.png", borderRad = 5 },
			{ name = "Instead FX**", value = 2, image = "images/pref_tcp_embedinstead.png", borderRad = 5 },
		}
	},
	tcp_folder_recarms = {
		id = 5,
		name = 'Record stuff in Folders',
		type = adj.config.param_types.Checkbox,
		width = 195,
		height = 41,
		values = { 1, 2 }
	},
	mcp_folder_recarms = {
		id = 6,
		name = 'Record stuff in Folders',
		type = adj.config.param_types.Checkbox,
		width = 195,
		height = 41,
		values = { 1, 2 }
	},
	dbscales = {
		id = 7,
		name = 'DB Scales',
		type = adj.config.param_types.Checkbox,
		width = 195,
		height = 41,
		values = { 1, 2 }
	},
	mcp_dbscales = {
		id = 8,
		name = 'DB Scales',
		type = adj.config.param_types.Checkbox,
		width = 195,
		height = 41,
		values = { 1, 2 }
	},
	trans_position = {
		id = 9,
		name = 'Transport orientation',
		type = adj.config.param_types.Simple,
		width = 400,
		height = 95,
		--colspan = 2,
		values = {
			{ name = "Left", value = 1, image = "images/pref_trans_position_left.png" },
			{ name = "Center", value = 2, image = "images/pref_trans_position_center.png" },
			{ name = "Right", value = 3, image = "images/pref_trans_position_right.png" },
		}
	},
	tcp_solid_color = {
		id = 10,
		name = 'Panel Background',
		type = adj.config.param_types.Simple,
		width = 400,
		height = 160,
		values = {
			{ name = "Solid", value = 2, image = "images/pref_tcp_greybg.png" },
			{ name = "Color", value = 1, image = "images/pref_tcp_colorbg.png" },
		}
	},
	mcp_solid_color = {
		id = 11,
		name = 'Panel Background',
		type = adj.config.param_types.Simple,
		width = 400,
		height = 160,
		values = {
			{ name = "Solid", value = 2, image = "images/pref_mcp_greybg.png" },
			{ name = "Color", value = 1, image = "images/pref_mcp_colorbg.png" },
		}
	},
	mixer_folderindent = {
		id = 12,
		name = 'Record stuff in Folders',
		type = adj.config.param_types.Simple,
		width = 400,
		height = 160,
		values = {
			{ name = "Padding Off", value = 1, image = "images/pref_mcp_paddingoff.png" },
			{ name = "Padding On", value = 2, image = "images/pref_mcp_paddingon.png" },
		}
	},
	hideall = {
		id = 13,
	}
}

local ctx = ImGui.CreateContext(SCRIPT_NAME)
local window_visible = false
local window_opened = false
local start_time = 0
local cooldown = 1
local function NeedToUpdateValues()
	local time = reaper.time_precise()
	if time > start_time + cooldown then
		start_time = time
		return true
	else
		return false
	end
end

function adj.SetValue(parameter, value)
	parameter.data.value = value
	reaper.ThemeLayout_SetParameter(parameter.id, parameter.data.value, true)
	reaper.ThemeLayout_RefreshAll()
end

function adj.UpdateValues()
	if not NeedToUpdateValues() then return end

	local i = 0
	local ret = true
	local name, value, defValue, minValue, maxValue
	while ret do
		ret, name, value, defValue, minValue, maxValue = reaper.ThemeLayout_GetParameter(i)

		if ret then
			for id, param in pairs(adj.params) do
				if param.id == i then
					adj.params[id].data = { name = name, value = value, min = minValue, max = maxValue }
				end
			end
		end
		i = i + 1
	end

	if adj.params.hideall.data == nil or not string.find(adj.params.hideall.data.name, "DOES FLAT MADNESS BEST THEME EVER?") then
		window_opened = false
		reaper.MB('Please install the Flat Madness theme to be able to customize it', SCRIPT_NAME, 0)
		return false
	end

	return true
end

function adj.GetImage(src)
	if adj.cached_images[src] == nil or not ImGui.ValidatePtr(adj.cached_images[src].obj, 'ImGui_Image*') then
		local img = ImGui.CreateImage(src)
		local w, h = ImGui.Image_GetSize(img)
		adj.cached_images[src] = { obj = img, width = w, height = h }
	end

	return adj.cached_images[src]
end

function adj.DrawHeader()
	local image = adj.GetImage(SCRIPT_PATH .. adj.config.header.src)
	local width = image.width / 2
	local height = image.height / 2

	if ImGui.BeginChild(ctx, "header", 0, height, nil, adj.config.windFlags) then
		local draw_list = ImGui.GetWindowDrawList(ctx)
		local avail_w = ImGui.GetContentRegionAvail(ctx)
		local p_min_x, p_min_y = ImGui.GetItemRectMin(ctx)

		p_min_x = p_min_x + math.max(0, (avail_w - width) // 2)

		ImGui.DrawList_AddImage(draw_list, image.obj, p_min_x, p_min_y, p_min_x + width, p_min_y + height, 0, 0, 1, 1, adj.config.colors.White)
	 	ImGui.EndChild(ctx)
	end
end

function adj.DrawImage(src, settings)
	local image = adj.GetImage(src)
	local width = image.width
	local height = image.height

	if settings then
		if settings.width and not settings.height then
			height = (height * settings.width) / width
			width = settings.width
		elseif settings.height and not settings.width then
			width = (width * settings.height) / height
			height = settings.height
		elseif  settings.width and settings.height then
			width = settings.width
			height = settings.height
		end
	end

	width = width / 2
	height = height / 2

	local border = 3
	local borderRad = settings.borderRad or adj.config.borderRad.image

	if ImGui.BeginChild(ctx, "img_" .. src, 0, height + border, nil, adj.config.windFlags) then
		local draw_list = ImGui.GetWindowDrawList(ctx)

		local avail_w = ImGui.GetContentRegionAvail(ctx)
		local p_min_x, p_min_y = ImGui.GetItemRectMin(ctx)

		p_min_x = p_min_x + math.max(0, (avail_w - width) // 2)

		ImGui.DrawList_AddRectFilled(draw_list, p_min_x - border, p_min_y, p_min_x + width + border, p_min_y + height + border, settings.borderBg or adj.config.colors.Header, borderRad + border)
	 	ImGui.DrawList_AddImageRounded(draw_list, image.obj, p_min_x, p_min_y + border, p_min_x + width, p_min_y + height, 0, 0, 1, 1, adj.config.colors.White, borderRad)
	 	--ImGui.Dummy(ctx, p_min_x, p_min_y)
		ImGui.EndChild(ctx)
	end
end

function adj.CenterText(text, color)
	local avail_w = ImGui.GetContentRegionAvail(ctx)
	local text_w  = ImGui.CalcTextSize(ctx, text)

	ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) +
	math.max(0, (avail_w - text_w) // 2))

	if color then ImGui.PushStyleColor(ctx, ImGui.Col_Text, color) end
		ImGui.TextWrapped(ctx, text)
	if color then ImGui.PopStyleColor(ctx) end
end

function adj.DrawSimpleInput(parameter)
	local values = parameter.values

	ImGui.Dummy(ctx, 0, 5)
	adj.CenterText(parameter.name, adj.config.colors.Subheader)

	if ImGui.BeginTable(ctx, "table_sub_" .. parameter.id, parameter.colspan or #values) then
		local curCol = 0

		for _, val in pairs(values) do
			ImGui.TableNextColumn(ctx)

			local selColor = val.value == parameter.data.value and adj.config.colors.Selected or adj.config.colors.Header
			adj.DrawImage(SCRIPT_PATH .. val.image, { borderBg = selColor, borderRad = val.borderRad })

			if ImGui.IsItemClicked(ctx) then
				adj.SetValue(parameter, val.value)
			end

			adj.CenterText(val.name, selColor)

			if ImGui.IsItemClicked(ctx) then
				adj.SetValue(parameter, val.value)
			end

			curCol = curCol + 1

			if parameter.colspan ~= nil and curCol >= parameter.colspan then
				curCol = 0
				ImGui.TableNextRow(ctx)
			end
		end

		ImGui.EndTable(ctx)
	end
end

function adj.DrawCheckboxInput(parameter)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, 0, 0)

	if ImGui.BeginTable(ctx, "sep", 2, nil, parameter.width, parameter.height) then
		ImGui.TableSetupColumn(ctx, 'Name', ImGui.TableColumnFlags_NoHide)
      	ImGui.TableSetupColumn(ctx, 'Size', ImGui.TableColumnFlags_WidthFixed, 30)

		ImGui.TableNextColumn(ctx)
		ImGui.Dummy(ctx, 0, 3)
		adj.CenterText(parameter.name, adj.config.colors.Subheader)

		ImGui.TableNextColumn(ctx)
		ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, 0, 0)
		ImGui.Dummy(ctx, 0, 3)
		local _, newVal = ImGui.Checkbox(ctx, ' ', parameter.data.value == parameter.values[2])
		local id = newVal and 2 or 1
		if parameter.data.value ~= parameter.values[id] then
			adj.SetValue(parameter, parameter.values[id])
		end
		ImGui.PopStyleVar(ctx, 1)

		ImGui.EndTable(ctx)
	end

	ImGui.PopStyleVar(ctx)
end

function adj.DrawRangeInput(parameter)
	if ImGui.BeginTable(ctx, "sep", 1, nil, parameter.width, parameter.height) then
		ImGui.TableNextRow(ctx)
		ImGui.TableSetColumnIndex(ctx, 0)

		ImGui.Dummy(ctx, 0, 1)
		adj.CenterText(parameter.name, adj.config.colors.Subheader)

		ImGui.TableNextRow(ctx)
		ImGui.TableSetColumnIndex(ctx, 0)
		--local FLT_MIN, FLT_MAX = ImGui.NumericLimits_Float()
		ImGui.SetNextItemWidth(ctx, -10)
		ImGui.Unindent(ctx, -10)
		ImGui.PushStyleColor(ctx, ImGui.Col_Text, adj.config.colors.Subheader)
		local _, newVal = ImGui.SliderInt(ctx, "##", parameter.data.value, parameter.data.min, parameter.data.max)
		if newVal ~= parameter.data.value then
			adj.SetValue(parameter, newVal)
		end
		ImGui.PopStyleColor(ctx, 1)

		ImGui.EndTable(ctx)
	end
end

function adj.ShowParameter(parameter)
	ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, adj.config.colors.ParameterBlockBackground)

	if ImGui.BeginChild(ctx, "parameter_" .. parameter.id, parameter.width, parameter.height, nil, adj.config.windFlags) then
		if parameter.type == adj.config.param_types.Simple then
			adj.DrawSimpleInput(parameter)
		elseif parameter.type == adj.config.param_types.Checkbox then
			adj.DrawCheckboxInput(parameter)
		elseif parameter.type == adj.config.param_types.Range then
			adj.DrawRangeInput(parameter)
		end

		ImGui.EndChild(ctx)
	end

	ImGui.Spacing(ctx)

	ImGui.PopStyleColor(ctx, 1)
end

function adj.DrawCollapsingHeader(header, innerContent)
	ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, adj.config.colors.SectionBackground)
	ImGui.PushStyleColor(ctx, ImGui.Col_Text, adj.config.colors.Header)

	if ImGui.BeginChild(ctx, 'collapsible_' .. header, 0, 0, adj.config.childFlags) then
		ImGui.PushFont(ctx, adj.getFont(adj.config.font_types.Bold, adj.config.font_size_header))

		if ImGui.CollapsingHeader(ctx, header) then
			ImGui.PopFont(ctx)
			innerContent()
		else
			ImGui.PopFont(ctx)
		end
		ImGui.EndChild(ctx)
	end

	ImGui.PopStyleColor(ctx, 2)
end

function adj.ShowWindow()
	adj.UpdateValues()

	adj.DrawHeader()
	ImGui.Spacing(ctx)
	ImGui.Spacing(ctx)

	if not adj.opened_first_tab then
		ImGui.SetNextItemOpen(ctx, true)
		ImGui.SetScrollHereY(ctx, 1.0)
		adj.opened_first_tab = true
	end

	adj.DrawCollapsingHeader('                 TRACK CONTROL PANEL', function()
		adj.ShowParameter(adj.params.tcp_solid_color)
		ImGui.Spacing(ctx)
		adj.ShowParameter(adj.params.pan_type)
		ImGui.Spacing(ctx)

		if ImGui.BeginTable(ctx, "sep", 2) then
			ImGui.TableNextColumn(ctx)
			adj.ShowParameter(adj.params.embed_position)

			ImGui.TableNextColumn(ctx)
			adj.ShowParameter(adj.params.dbscales)
			adj.ShowParameter(adj.params.tcp_folder_recarms)
			adj.ShowParameter(adj.params.min_fxlist)

			ImGui.EndTable(ctx)
		end

		ImGui.Spacing(ctx)
		adj.ShowParameter(adj.params.meter_position)
		ImGui.Spacing(ctx)

		ImGui.Spacing(ctx)
		ImGui.Spacing(ctx)
		ImGui.Spacing(ctx)

		ImGui.TextWrapped(ctx, "*in TCP, all pan/width controls are knobs technically, Even that it looks like slider, it works the same as knob")

		ImGui.Spacing(ctx)
		ImGui.Spacing(ctx)

		ImGui.TextWrapped(ctx, "**Embedded Ul will be shown instead of FX slots only it the option enabled")
	end)

	ImGui.Spacing(ctx)

	adj.DrawCollapsingHeader('                           MIXER PANEL', function()
		adj.ShowParameter(adj.params.mcp_solid_color)
		ImGui.Spacing(ctx)
		adj.ShowParameter(adj.params.mixer_folderindent)
		ImGui.Spacing(ctx)

		if ImGui.BeginTable(ctx, "sep2", 2) then
			ImGui.TableNextColumn(ctx)
			adj.ShowParameter(adj.params.mcp_folder_recarms)

			ImGui.TableNextColumn(ctx)
			adj.ShowParameter(adj.params.mcp_dbscales)

			ImGui.EndTable(ctx)
		end

		ImGui.Spacing(ctx)
	end)

	ImGui.Spacing(ctx)

    adj.DrawCollapsingHeader('                              COMMON', function()
		adj.ShowParameter(adj.params.trans_position)
		ImGui.Spacing(ctx)
	end)

	ImGui.Spacing(ctx)

	adj.DrawCollapsingHeader('                         ABOUT SCRIPT', function()
		 ImGui.TextWrapped(ctx, 'FM4 theme is created by Dmytro Hapochka, theme adjuster is designed by Dmytro Hapochka and developed by Ed Kashinsky.')
	end)


	return true
end

function adj.getFont(font_type, font_size)
	if not font_size then font_size = adj.config.font_size end

	return adj.cached_fonts[font_type][font_size]
end

function adj.init()
	if not adj.UpdateValues() then return end

	for _, flag in pairs(adj.config.font_types) do
		adj.cached_fonts[flag] = {}

		adj.cached_fonts[flag][adj.config.font_size] = ImGui.CreateFont(adj.config.font_name, adj.config.font_size, flag)
		ImGui.Attach(ctx, adj.cached_fonts[flag][adj.config.font_size])

		adj.cached_fonts[flag][adj.config.font_size_header] = ImGui.CreateFont(adj.config.font_name, adj.config.font_size_header, flag)
		ImGui.Attach(ctx, adj.cached_fonts[flag][adj.config.font_size_header])
	end

	ImGui.SetNextWindowSize(ctx, adj.config.width, adj.config.height)

	reaper.defer(adj.loop)
end

function adj.loop()
	--ImGui.SetConfigVar(ctx, ImGui.ConfigVar_ViewportsNoDecoration(), 0)

	ImGui.PushFont(ctx, adj.getFont(adj.config.font_types.Bold))

	ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg, adj.config.colors.Background)
	ImGui.PushStyleColor(ctx, ImGui.Col_TitleBg, adj.config.colors.Background)
	ImGui.PushStyleColor(ctx, ImGui.Col_TitleBgActive, adj.config.colors.Background)
	ImGui.PushStyleColor(ctx, ImGui.Col_TitleBgCollapsed, adj.config.colors.Background)
	ImGui.PushStyleColor(ctx, ImGui.Col_Separator, adj.config.colors.Background)
	ImGui.PushStyleColor(ctx, ImGui.Col_Header, 0)
	ImGui.PushStyleColor(ctx, ImGui.Col_HeaderActive, 0)
	ImGui.PushStyleColor(ctx, ImGui.Col_HeaderHovered, 0)
	ImGui.PushStyleColor(ctx, ImGui.Col_Text, adj.config.colors.White)
	ImGui.PushStyleColor(ctx, ImGui.Col_Border, adj.config.colors.SectionBackground)
	ImGui.PushStyleColor(ctx, ImGui.Col_TabHovered, adj.config.colors.White)
	ImGui.PushStyleColor(ctx, ImGui.Col_CheckMark, adj.config.colors.Selected)
	ImGui.PushStyleColor(ctx, ImGui.Col_SliderGrab, adj.config.colors.Selected)
	ImGui.PushStyleColor(ctx, ImGui.Col_SliderGrabActive, adj.config.colors.Selected)
	ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, adj.config.colors.Header)
	ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgHovered, adj.config.colors.Header)
	ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgActive, adj.config.colors.Header)
	ImGui.PushStyleColor(ctx, ImGui.Col_Button, adj.config.colors.Selected)
	ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, adj.config.colors.Selected)
	ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, adj.config.colors.Selected)

	ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowBorderSize, 1);
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, 2, 2)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_CellPadding, 5, 5)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_ChildRounding, adj.config.borderRad.block)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 10, 10)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameRounding, adj.config.borderRad.block)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_GrabRounding, adj.config.borderRad.block)

	window_visible, window_opened = ImGui.Begin(ctx, " ", true, ImGui.WindowFlags_NoCollapse | ImGui.WindowFlags_TopMost | ImGui.ChildFlags_ResizeY)

	if window_visible then
		adj.ShowWindow()
	end

	ImGui.PopStyleVar(ctx, 7)
	ImGui.PopStyleColor(ctx, 20)
	ImGui.PopFont(ctx)

	ImGui.End(ctx)

  	if window_opened then
    	reaper.defer(adj.loop)
  	end
end

adj.init()