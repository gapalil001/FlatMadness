local Pickle = {
	clone = function(t)
		local nt = {}

	  	for i, v in pairs(t) do
			nt[i] = v
	  	end

	  	return nt
  	end
}

function Pickle:pickle_(root)
	if type(root) ~= "table" then error("can only pickle tables, not ".. type(root).."s") end

	self._tableToRef = {}
	self._refToTable = {}
	local savecount = 0
	self:ref_(root)
	local s = ""

	while #self._refToTable > savecount do
		savecount = savecount + 1
		local t = self._refToTable[savecount]
		s = s.."{"

		for i, v in pairs(t) do
			s = string.format("%s[%s]=%s,", s, self:value_(i), self:value_(v))
		end
		s = s.."},"
	end

	return string.format("{%s}", s)
end

function Pickle:value_(v)
	local vtype = type(v)

	if vtype == "string" then return string.format("%q", v)
	elseif vtype == "number" then return v
	elseif vtype == "boolean" then return tostring(v)
	elseif vtype == "table" then return "{"..self:ref_(v).."}"
	elseif vtype == "function" then return "{function}"
	else error("pickle a "..type(v).." is not supported") end
end

function Pickle:ref_(t)
	local ref = self._tableToRef[t]

	if not ref then
		if t == self then error("can't pickle the pickle class") end

		table.insert(self._refToTable, t)
		ref = #self._refToTable
		self._tableToRef[t] = ref
	end

	return ref
end

local ek_debug_levels = {
	All = 0,
	Notice = 1,
	Warning = 2,
	Important = 3,
	Off = 4,
	Debug = 5,
}

ek_log_levels = {
	Notice = ek_debug_levels.Notice,
	Warning = ek_debug_levels.Warning,
	Important = ek_debug_levels.Important,
	Debug = ek_debug_levels.Debug,
}

local ek_debug_level = ek_debug_levels.Off

function serializeTable(t)
	return Pickle:clone():pickle_(t)
end

function Log(msg, level, param)
	if not level then level = ek_log_levels.Important end
	if level < ek_debug_level then return end

	if param ~= nil then
		if type(param) == 'boolean' then param = param and 'true' or 'false' end
		if type(param) == 'table' then param = serializeTable(param) end

		msg = string.gsub(msg, "{param}", param)
	else
		if type(msg) == 'table' then msg = serializeTable(msg)
		else msg = tostring(msg) end
	end

	if msg then
		reaper.ShowConsoleMsg("[" .. os.date("%H:%M:%S") .. "] ")
		reaper.ShowConsoleMsg(msg)
		reaper.ShowConsoleMsg('\n')
	end
end

----
----
---
---
---
---

local ImGui = {}
local CONTEXT = ({reaper.get_action_context()})
local SCRIPT_NAME = CONTEXT[2]:match("([^/\\]+)%.lua$")
local SCRIPT_PATH = CONTEXT[2]:match("(.*[/\\])")

if reaper.ImGui_GetVersion == nil or not pcall(function()
	dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua') '0.8'
end) then
	reaper.MB('Please install "ReaImGui: ReaScript binding for Dear ImGui" (minimum v.0.8) library via ReaPack to customize theme. Also you can use default theme adjuster', SCRIPT_NAME, 0)
	reaper.Main_OnCommand(reaper.NamedCommandLookup("_RS1cbf05b0c4f875518496f34a5ce45adefe05cb67"), 0) -- Options: Show theme adjuster
	return
end

for name, func in pairs(reaper) do
	name = name:match('^ImGui_(.+)$')
	if name then ImGui[name] = func end
end

local adj = {
	cached_images = {},
	cached_fonts = {},
	opened_first_tab = false,
	config = {
		width = 428,
		height = 650,
		font_name = 'Arial',
		font_size = 14,
		font_types = {
			None = ImGui.FontFlags_None(),
			Italic = ImGui.FontFlags_Italic(),
			Bold = ImGui.FontFlags_Bold(),
		},
		borderRad = 20,
		colors = {
			White = 0xffffffff,
			Background = 0x414141ff,
			SectionBackground = 0x929292ff,
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
		windFlags = ImGui.WindowFlags_NoScrollbar() | ImGui.WindowFlags_NoScrollWithMouse(),
		header = { image = nil, src = "images/header.png" }
	}
}

adj.params = {
	meter_position = {
		id = 1,
		type = adj.config.param_types.Simple,
		width = 400,
		height = 182,
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
		type = adj.config.param_types.Simple,
		width = 400,
		height = 160,
		values = {
			{ name = "Knob", value = 2, image = "images/pref_tcp_knob.png" },
			{ name = "Slider*", value = 1, image = "images/pref_tcp_slider.png" },
		}
	},
	min_fxlist = {
		id = 3,
	},
	embed_position = {
		id = 4,
		type = adj.config.param_types.Simple,
		width = 400,
		height = 160,
		values = {
			{ name = "Beside FX", value = 2, image = "images/pref_tcp_embedright.png" },
			{ name = "Instead FX**", value = 1, image = "images/pref_tcp_embedinstead.png" },
		}
	},
	tcp_folder_recarms = {
		id = 5,
		type = adj.config.param_types.Checkbox,
		width = 195,
		height = 35,
		values = { 1, 2 }
	},
	mcp_folder_recarms = {
		id = 6,
		type = adj.config.param_types.Checkbox,
		width = 195,
		height = 35,
		values = { 1, 2 }
	},
	dbscales = {
		id = 7,
		type = adj.config.param_types.Checkbox,
		width = 195,
		height = 35,
		values = { 1, 2 }
	},
	mcp_dbscales = {
		id = 8,
		type = adj.config.param_types.Checkbox,
		width = 195,
		height = 35,
		values = { 1, 2 }
	},
	trans_position = {
		id = 9,
		type = adj.config.param_types.Simple,
		width = 400,
		height = 182,
		values = {
			{ name = "Left", value = 1, image = "images/pref_trans_position_left.png" },
			{ name = "Center", value = 2, image = "images/pref_trans_position_center.png" },
			{ name = "Right", value = 3, image = "images/pref_trans_position_right.png" },
		}
	},
	tcp_solid_color = {
		id = 10,
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
local cooldown = 0.5
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

	local border = 2
	local borderRad = settings.borderRad or adj.config.borderRad

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

	if color then ImGui.PushStyleColor(ctx, ImGui.Col_Text(), color) end
		ImGui.TextWrapped(ctx, text)
	if color then ImGui.PopStyleColor(ctx) end
end

function adj.ShowParameter(parameter)
	if ImGui.BeginChild(ctx, "parameter_" .. parameter.id, parameter.width, parameter.height, nil, adj.config.windFlags) then
		local draw_list = ImGui.GetWindowDrawList(ctx)
		local p_min_x, p_min_y = ImGui.GetItemRectMin(ctx)

		ImGui.DrawList_AddRectFilled(draw_list, p_min_x, p_min_y, p_min_x + parameter.width, p_min_y + parameter.height, adj.config.colors.SectionBackground, 20)

		ImGui.Spacing(ctx)
		ImGui.Spacing(ctx)

		if parameter.type == adj.config.param_types.Simple then
			adj.DrawSimpleInput(parameter)
		elseif parameter.type == adj.config.param_types.Checkbox then
			adj.DrawCheckboxInput(parameter)
		elseif parameter.type == adj.config.param_types.Range then
			adj.DrawRangenput(parameter)
		end

		ImGui.EndChild(ctx)
	end
end

function adj.DrawSimpleInput(parameter)
	local values = parameter.values

	adj.CenterText(parameter.data.name, adj.config.colors.Subheader)

	if ImGui.BeginTable(ctx, "table_sub_" .. parameter.id, parameter.colspan or #values) then
		local curCol = 0

		for _, param in pairs(values) do
			ImGui.TableNextColumn(ctx)

			local selColor = param.value == parameter.data.value and adj.config.colors.Selected or adj.config.colors.Header

			adj.DrawImage(SCRIPT_PATH .. param.image, { borderBg = selColor, borderRad = param.borderRad })

			if ImGui.IsItemClicked(ctx) then
				adj.SetValue(parameter, param.value)
			end

			adj.CenterText(param.name, selColor)

			if ImGui.IsItemClicked(ctx) then
				adj.SetValue(parameter, param.value)
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
	ImGui.SameLine(ctx, 20)

	if ImGui.BeginChild(ctx, "checkbox_" .. parameter.id, -40, parameter.height, nil, adj.config.windFlags) then
		adj.CenterText(parameter.data.name)
		ImGui.EndChild(ctx)
	end

	ImGui.SameLine(ctx)

	if ImGui.BeginChild(ctx, "checkbox2_" .. parameter.id, 20, parameter.height, nil, adj.config.windFlags) then
		local _, newVal = ImGui.Checkbox(ctx, ' ', parameter.data.value == parameter.values[2])
		local id = newVal and 2 or 1
		if parameter.data.value ~= parameter.values[id] then
			adj.SetValue(parameter, parameter.values[id])
		end
		ImGui.EndChild(ctx)
	end
end

function adj.DrawRangeInput(parameter)

end

function adj.ShowWindow()
	adj.UpdateValues()

	adj.DrawHeader()
	ImGui.Spacing(ctx)

	if not adj.opened_first_tab then
		ImGui.SetNextItemOpen(ctx, true)
		ImGui.SetScrollHereY(ctx, 1.0)
		adj.opened_first_tab = true
	end

	if ImGui.CollapsingHeader(ctx, 'TRACK CONTROL PANEL') then
		adj.ShowParameter(adj.params.tcp_solid_color)
		ImGui.Spacing(ctx)
		adj.ShowParameter(adj.params.pan_type)
		ImGui.Spacing(ctx)
		adj.ShowParameter(adj.params.embed_position)
		ImGui.Spacing(ctx)
		adj.ShowParameter(adj.params.meter_position)
		ImGui.Spacing(ctx)

		adj.ShowParameter(adj.params.tcp_folder_recarms)
		ImGui.SameLine(ctx)
		adj.ShowParameter(adj.params.dbscales)
		ImGui.Spacing(ctx)

		ImGui.Spacing(ctx)
		ImGui.Spacing(ctx)
		ImGui.Spacing(ctx)

		if ImGui.BeginChild(ctx, "tcp_notes", adj.config.width - 10, 80, nil, adj.config.windFlags) then
			 ImGui.PushStyleColor(ctx, ImGui.Col_Text(), adj.config.colors.Label)
			 ImGui.TextWrapped(ctx, "*in TCP, all pan/width controls are knobs technically, Even that it looks like slider, it works the same as knob")

			 ImGui.Spacing(ctx)
			 ImGui.Spacing(ctx)

			 ImGui.TextWrapped(ctx, "**Embedded Ul will be shown instead of FX slots only it the option enabled")
			 ImGui.PopStyleColor(ctx)

			 ImGui.EndChild(ctx)
		end
	end

    if ImGui.CollapsingHeader(ctx, 'MIXER PANEL') then
		adj.ShowParameter(adj.params.mcp_solid_color)
		ImGui.Spacing(ctx)
		adj.ShowParameter(adj.params.mixer_folderindent)
		ImGui.Spacing(ctx)

		adj.ShowParameter(adj.params.mcp_folder_recarms)
		ImGui.SameLine(ctx)
		adj.ShowParameter(adj.params.mcp_dbscales)
		ImGui.Spacing(ctx)
	end

	if ImGui.CollapsingHeader(ctx, 'COMMON') then
		adj.ShowParameter(adj.params.trans_position)
		ImGui.Spacing(ctx)
	end

	if ImGui.CollapsingHeader(ctx, 'ABOUT SCRIPT') then
		 ImGui.Text(ctx, 'Hello, world!')

		 ImGui.Text(ctx, "Meter Position:")
	end

	return true
end

function adj.getFont(font_type)
	return adj.cached_fonts[font_type]
end

function adj.init()
	if not adj.UpdateValues() then return end

	for _, flag in pairs(adj.config.font_types) do
		adj.cached_fonts[flag] = ImGui.CreateFont(adj.config.font_name, adj.config.font_size, flag)
		 ImGui.Attach(ctx, adj.cached_fonts[flag])
	end

	ImGui.SetNextWindowSize(ctx, adj.config.width, adj.config.height)

	reaper.defer(adj.loop)
end

function adj.loop()
	ImGui.SetConfigVar(ctx, ImGui.ConfigVar_ViewportsNoDecoration(), 0)

	ImGui.PushFont(ctx, adj.getFont(adj.config.font_types.Bold))
	ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg(), adj.config.colors.Background)
	ImGui.PushStyleColor(ctx, ImGui.Col_Separator(), adj.config.colors.Background)
	ImGui.PushStyleColor(ctx, ImGui.Col_Header(), adj.config.colors.Background)
	ImGui.PushStyleColor(ctx, ImGui.Col_HeaderActive(), adj.config.colors.Background)
	ImGui.PushStyleColor(ctx, ImGui.Col_HeaderHovered(), adj.config.colors.Background)
	ImGui.PushStyleColor(ctx, ImGui.Col_Text(), adj.config.colors.Text)
	ImGui.PushStyleColor(ctx, ImGui.Col_Border(), adj.config.colors.Background)
	--ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg(), 0xffffffff)

	ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding(), 0, 0)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_CellPadding(), 0, 10)

	window_visible, window_opened = ImGui.Begin(ctx, SCRIPT_NAME, true, ImGui.WindowFlags_NoCollapse() |
			 ImGui.WindowFlags_NoResize() | ImGui.WindowFlags_TopMost())

	if window_visible then
		adj.ShowWindow()
	end

	ImGui.PopStyleVar(ctx, 2)
	ImGui.PopStyleColor(ctx, 7)
	ImGui.PopFont(ctx)

	ImGui.End(ctx)

  	if window_opened then
    	reaper.defer(adj.loop)
	else
		reaper.ImGui_DestroyContext(ctx)
  	end
end

adj.init()