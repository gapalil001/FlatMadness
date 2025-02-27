-- @description FM_4.0_theme_adjuster
-- @author Ed Kashinsky
-- @about Theme adjuster for Flat Madness theme
-- @version 1.1.3
-- @changelog
--   - added support of version 4.2.4
-- @provides
--   [nomain] images/*.png

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
		io.write("reaper.Main_OnCommand(reaper.NamedCommandLookup(\"_RS9d0870d75a3269255f3cc43d51e1870c8d76ac70\"), 0) -- FM_4.0_theme_adjuster \n")
		io.close(file)
	end
end

local Pickle = { clone = function(t) local nt = {} for i, v in pairs(t) do nt[i] = v end return nt end}
function Pickle:pickle_(root) if type(root) ~= "table" then error("can only pickle tables, not ".. type(root).."s") end self._tableToRef = {} self._refToTable = {} local savecount = 0 self:ref_(root) local s = "" while #self._refToTable > savecount do savecount = savecount + 1 local t = self._refToTable[savecount] s = s.."{" for i, v in pairs(t) do s = string.format("%s[%s]=%s,", s, self:value_(i), self:value_(v)) end s = s.."}," end return string.format("{%s}", s) end
function Pickle:value_(v) local vtype = type(v) if vtype == "string" then return string.format("%q", v) elseif vtype == "number" then return v elseif vtype == "boolean" then return tostring(v) elseif vtype == "table" then return "{"..self:ref_(v).."}" elseif vtype == "function" then return "{function}" else error("pickle a "..type(v).." is not supported") end end
function Pickle:ref_(t) local ref = self._tableToRef[t] if not ref then if t == self then error("can't pickle the pickle class") end table.insert(self._refToTable, t) ref = #self._refToTable self._tableToRef[t] = ref end return ref end

local _, _, imGuiVersion = reaper.ImGui_GetVersion()
local function serializeTable(t) return Pickle:clone():pickle_(t) end
local function unserializeTable(s) if s == nil or s == '' then return end if type(s) ~= "string" then error("can't unpickle a "..type(s)..", only strings") end local gentables = load("return " .. s) if gentables then local tables = gentables() if tables then for tnum = 1, #tables do local t = tables[tnum] local tcopy = {} for i, v in pairs(t) do tcopy[i] = v end for i, v in pairs(tcopy) do local ni, nv if type(i) == "table" then ni = tables[i[1]] else ni = i end if type(v) == "table" then nv = tables[v[1]] else nv = v end t[i] = nil t[ni] = nv end end return tables[1] end else end end
local function join(list, delimiter) if type(list) ~= 'table' or #list == 0 then return "" end local startNum = list[0] and 0 or 1 local string = list[startNum] for i = startNum + 1, #list do string = string .. delimiter .. list[i] end return string end
local function in_array(tab, val) for _, value in ipairs(tab) do if value == val then return true end end return false end
local function isEmpty(value) if value == nil then return true end if type(value) == 'boolean' and value == false then return true end if type(value) == 'table' and next(value) == nil then return true end if type(value) == 'number' and value == 0 then return true end if type(value) == 'string' and string.len(value) == 0 then return true end return false end
local function round(number, decimals) if not decimals then decimals = 0 end local power = 10 ^ decimals return math.ceil(number * power) / power end

local ek_log_levels = { Debug = 1 }
local function Log(msg) if type(msg) == 'table' then msg = serializeTable(msg) else msg = tostring(msg) end if msg then reaper.ShowConsoleMsg("[" .. os.date("%H:%M:%S") .. "] ") reaper.ShowConsoleMsg(msg) reaper.ShowConsoleMsg('\n') end end

local ctx = ImGui.CreateContext(SCRIPT_NAME)
local _, FLT_MAX = ImGui.NumericLimits_Float()
local window_visible = false
local window_opened = false
local start_time = 0
local cooldown = 1
local key_ext_prefix = "fm4_adjuster"
local key_ext_prefix_resets = "presets"

local function NeedToUpdateValues()
	local time = reaper.time_precise()
	if time > start_time + cooldown then
		start_time = time
		return true
	else
		return false
	end
end

local adj = {
	cached_images = {},
	cached_fonts = {},
	opened_first_tab = false,
	cached_heights = {},
	config = {
		width = 472,
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
		border = 3,
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
			PanelBackground = 5,
			Layout = 6
		},
		windFlags = ImGui.WindowFlags_NoScrollbar | ImGui.WindowFlags_NoScrollWithMouse,
		childFlags = ImGui.ChildFlags_AlwaysUseWindowPadding | ImGui.ChildFlags_AutoResizeY,
		tableFlags = ImGui.TableFlags_BordersV | ImGui.TableFlags_BordersOuterH | ImGui.TableFlags_RowBg,
		header = { image = nil, src = "images/header.png" }
	},
	presets = {
		current = nil,
		default = {
			{ name = "Bright Pale Ale", values = { mcpdbscales = 2, dbscales = 1, embed_position = 2, pan_type = 2, mcp_solid_color = 3, gencoloring = 2, min_fxlist = 42, mcp_folder_recarms = 1, foldermargin = 1, saturnalpha = 215, tcplabelbrightness = 147, hideall = 2, tcp_saturn_ident = 0, trans_position = 1, tcp_folder_recarms = 1, saturnc = 156, meter_position = 1, saturncmcp = 156, envioswap = 2, longnamestate = 1, tcp_saturn_identmcp = 0, saturnalphamcp = 215, mcp_layout = "Default", tcp_solid_color = 3, tcp_layout = "Default", mixer_folderindent = 2, } },
			{ name = "Dark Night EUI", values = { mcpdbscales = 2, dbscales = 1, embed_position = 2, pan_type = 2, mcp_solid_color = 3, gencoloring = 2, min_fxlist = 1, mcp_folder_recarms = 1, foldermargin = 1, saturnalpha = 255, tcplabelbrightness = 147, hideall = 2, tcp_saturn_ident = 0, trans_position = 1, tcp_folder_recarms = 1, tcp_layout = "Default", mixer_folderindent = 2, tcp_saturn_identmcp = 0, saturncmcp = 80, longnamestate = 1, saturnc = 80, envioswap = 2, mcp_layout = "Default", tcp_solid_color = 3, saturnalphamcp = 255, meter_position = 1, } },
			{ name = "Toxic", values = { mcpdbscales = 2, dbscales = 1, embed_position = 1, pan_type = 2, mcp_solid_color = 3, gencoloring = 2, min_fxlist = 35, mcp_folder_recarms = 1, foldermargin = 1, saturnalpha = 1, tcplabelbrightness = 147, hideall = 2, tcp_saturn_ident = 30, trans_position = 1, tcp_folder_recarms = 1, saturnc = 167, meter_position = 1, saturncmcp = 167, envioswap = 2, longnamestate = 1, tcp_saturn_identmcp = 30, saturnalphamcp = 1, mcp_layout = "Default", tcp_solid_color = 3, tcp_layout = "Default", mixer_folderindent = 2, } },
			{ name = "Meter Freak", values = { mcpdbscales = 2, dbscales = 2, embed_position = 2, pan_type = 2, mcp_solid_color = 3, gencoloring = 2, min_fxlist = 45, mcp_folder_recarms = 1, foldermargin = 1, saturnalpha = 255, tcplabelbrightness = 180, hideall = 2, tcp_saturn_ident = 30, trans_position = 1, tcp_folder_recarms = 1, saturnc = 80, mixer_folderindent = 1, tcp_layout = "Default", envioswap = 2, longnamestate = 1, tcp_saturn_identmcp = 30, saturnalphamcp = 255, mcp_layout = "METERBRIDGE", tcp_solid_color = 3, saturncmcp = 80, meter_position = 2, } },
			{ name = "Sweet candy", values = { mcpdbscales = 2, dbscales = 1, embed_position = 1, pan_type = 2, mcp_solid_color = 3, gencoloring = 2, min_fxlist = 35, mcp_folder_recarms = 1, foldermargin = 1, saturnalpha = 220, tcplabelbrightness = 147, hideall = 2, tcp_saturn_ident = 0, trans_position = 1, tcp_folder_recarms = 1, saturnc = 157, mixer_folderindent = 2, tcp_layout = "Default", envioswap = 2, longnamestate = 1, tcp_saturn_identmcp = 0, saturnalphamcp = 220, mcp_layout = "Default", tcp_solid_color = 3, saturncmcp = 157, meter_position = 1, } },
			{ name = "Colorful Dark", values = { mcpdbscales = 2, dbscales = 1, embed_position = 2, pan_type = 2, mcp_solid_color = 3, gencoloring = 2, min_fxlist = 1, mcp_folder_recarms = 1, foldermargin = 1, saturnalpha = 136, tcplabelbrightness = 147, hideall = 2, tcp_saturn_ident = 0, trans_position = 1, tcp_folder_recarms = 1, tcp_layout = "Default", mixer_folderindent = 2, tcp_saturn_identmcp = 0, saturncmcp = 122, longnamestate = 1, saturnalphamcp = 136, envioswap = 2, mcp_layout = "Default", tcp_solid_color = 3, saturnc = 122, meter_position = 1, } },
			{ name = "I Am Not Pro Tools", values = { mcpdbscales = 2, dbscales = 1, embed_position = 2, pan_type = 2, mcp_solid_color = 3, gencoloring = 2, min_fxlist = 30, mcp_folder_recarms = 1, foldermargin = 1, saturnalpha = 255, tcplabelbrightness = 147, hideall = 2, tcp_saturn_ident = 0, trans_position = 1, tcp_folder_recarms = 1, saturnc = 181, mixer_folderindent = 2, tcp_layout = "Default", envioswap = 2, longnamestate = 1, tcp_saturn_identmcp = 0, saturnalphamcp = 255, mcp_layout = "Default", tcp_solid_color = 3, saturncmcp = 181, meter_position = 4, } },
			{ name = "Toxic meter", values = { mcpdbscales = 2, dbscales = 1, embed_position = 1, pan_type = 2, mcp_solid_color = 3, gencoloring = 2, min_fxlist = 30, mcp_folder_recarms = 1, foldermargin = 1, saturnalpha = 121, tcplabelbrightness = 147, hideall = 2, tcp_saturn_ident = 0, trans_position = 1, tcp_folder_recarms = 1, saturnc = 157, meter_position = 2, saturncmcp = 157, envioswap = 2, longnamestate = 1, tcp_saturn_identmcp = 0, saturnalphamcp = 121, mcp_layout = "METERBRIDGE", tcp_solid_color = 3, tcp_layout = "Default", mixer_folderindent = 2, } },
			{ name = "almost  darkkk", values = { mcpdbscales = 2, dbscales = 1, embed_position = 1, pan_type = 2, mcp_solid_color = 3, gencoloring = 2, min_fxlist = 25, mcp_folder_recarms = 1, foldermargin = 2, saturnalpha = 255, hideall = 2, tcp_saturn_ident = 30, trans_position = 1, tcp_folder_recarms = 1, saturnc = 80, longnamestate = 1, mixer_folderindent = 2, tcp_saturn_identmcp = 10, saturncmcp = 80, tcp_solid_color = 3, saturnalphamcp = 255, meter_position = 1, } },
			{ name = "Pale Ale", values = { mcpdbscales = 2, dbscales = 1, embed_position = 2, pan_type = 2, mcp_solid_color = 3, gencoloring = 2, min_fxlist = 39, mcp_folder_recarms = 1, foldermargin = 1, saturnalpha = 228, tcplabelbrightness = 147, hideall = 2, tcp_saturn_ident = 30, trans_position = 1, tcp_folder_recarms = 1, saturnc = 80, meter_position = 1, saturncmcp = 80, envioswap = 2, longnamestate = 1, tcp_saturn_identmcp = 30, saturnalphamcp = 228, mcp_layout = "Default", tcp_solid_color = 3, tcp_layout = "Default", mixer_folderindent = 2, } },
			{ name = "Dark Night", values = { mcpdbscales = 2, dbscales = 1, embed_position = 1, pan_type = 2, mcp_solid_color = 3, gencoloring = 2, min_fxlist = 34, mcp_folder_recarms = 1, foldermargin = 1, saturnalpha = 255, tcplabelbrightness = 147, hideall = 2, tcp_saturn_ident = 0, trans_position = 1, tcp_folder_recarms = 1, saturnc = 80, mixer_folderindent = 2, tcp_layout = "Default", envioswap = 2, longnamestate = 1, tcp_saturn_identmcp = 0, saturnalphamcp = 255, mcp_layout = "Default", tcp_solid_color = 3, saturncmcp = 80, meter_position = 1, } },
		}
	},
	currentPreset = nil,
}

adj.params = {
	hideall = {
		id = 0,
	},
	meter_position = {
		id = 1,
		name = 'Meter position',
		type = adj.config.param_types.Simple,
		width = 420,
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
		width = 420,
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
		width = 205,
		height = 65,
	},
	embed_position = {
		id = 4,
		name = 'EMBEDDED UI POSITION',
		type = adj.config.param_types.Simple,
		width = 205,
		height = 165,
		colspan = 1,
		values = {
			{ name = "Beside FX", value = 0, image = "images/pref_tcp_embedright.png", borderRad = 5 },
			{ name = "Instead FX**", value = 1, image = "images/pref_tcp_embedinstead.png", borderRad = 5 },
		}
	},
	tcp_folder_recarms = {
		id = 5,
		name = 'Record stuff in Folders',
		type = adj.config.param_types.Checkbox,
		width = 205,
		height = 41,
		values = { 0, 1 }
	},
	mcp_folder_recarms = {
		id = 6,
		name = 'Record stuff in Folders',
		type = adj.config.param_types.Checkbox,
		width = 205,
		height = 41,
		values = { 0, 1 }
	},
	dbscales = {
		id = 7,
		name = 'DB Scales',
		type = adj.config.param_types.Checkbox,
		width = 205,
		height = 41,
		values = { 0, 1 }
	},
	mcpdbscales = {
		id = 8,
		name = 'DB Scales',
		type = adj.config.param_types.Checkbox,
		width = 205,
		height = 41,
		values = { 0, 1 }
	},
	trans_position = {
		id = 9,
		name = 'Transport orientation',
		type = adj.config.param_types.Simple,
		width = 420,
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
		type = adj.config.param_types.PanelBackground,
		width = 420,
		height = 130,
		custom = { "saturnc", "saturnalpha", "tcp_saturn_ident" },
		apply = { title = "Apply to MCP", main_param = "mcp_solid_color", params = {
			saturnc = "saturncmcp",
			saturnalpha = "saturnalphamcp",
			tcp_saturn_ident = "tcp_saturn_identmcp"
		}},
		values = {
			{ name = "Solid", value = 2, image = "images/pref_tcp_greybg.png", borderRad = 15 },
			{ name = "Color", value = 1, image = "images/pref_tcp_colorbg.png", borderRad = 15 },
			{ name = "Custom", value = 3, image = "images/pref_tcp_custom.png", borderRad = 15 },
		}
	},
	mcp_solid_color = {
		id = 11,
		name = 'Panel Background',
		type = adj.config.param_types.PanelBackground,
		width = 420,
		height = 130,
		custom = { "saturncmcp", "saturnalphamcp", "tcp_saturn_identmcp" },
		apply = { title = "Apply to TCP", main_param = "tcp_solid_color", params = {
			saturncmcp = "saturnc",
			saturnalphamcp = "saturnalpha",
			tcp_saturn_identmcp = "tcp_saturn_ident"
		}},
		values = {
			{ name = "Solid", value = 2, image = "images/pref_mcp_greybg.png", borderRad = 15 },
			{ name = "Color", value = 1, image = "images/pref_mcp_colorbg.png", borderRad = 15 },
			{ name = "Custom", value = 3, image = "images/pref_mcp_custom.png", borderRad = 15 },
		}
	},
	mixer_folderindent = {
		id = 12,
		name = 'Record stuff in Folders',
		type = adj.config.param_types.Simple,
		width = 420,
		height = 160,
		values = {
			{ name = "Padding Off", value = 1, image = "images/pref_mcp_paddingoff.png" },
			{ name = "Padding On", value = 2, image = "images/pref_mcp_paddingon.png" },
		}
	},
	saturnc = {
		id = 13,
		name = 'BRIGHTNESS',
		type = adj.config.param_types.Range,
		is_percentage = true,
		width = 205,
		height = 52,
	},
	saturnalpha = {
		id = 14,
		name = 'SATURATION',
		type = adj.config.param_types.Range,
		is_percentage = true,
		is_reverse = true,
		width = 205,
		height = 52,
	},
	tcp_saturn_ident = {
		id = 15,
		name = 'SELECTED TRACK HIGHLIGHT',
		type = adj.config.param_types.Range,
		is_percentage = true,
		width = 205,
		height = 52,
	},
	saturncmcp = {
		id = 16,
		name = 'BRIGHTNESS',
		type = adj.config.param_types.Range,
		is_percentage = true,
		width = 205,
		height = 52,
	},
	saturnalphamcp = {
		id = 17,
		name = 'SATURATION',
		type = adj.config.param_types.Range,
		is_percentage = true,
		is_reverse = true,
		width = 205,
		height = 52,
	},
	tcp_saturn_identmcp = {
		id = 18,
		name = 'SELECTED TRACK HIGHLIGHT',
		type = adj.config.param_types.Range,
		is_percentage = true,
		width = 205,
		height = 52,
	},
	gencoloring = {
		id = 19,
	},
	foldermargin = {
		id = 20,
		name = "Folder Name \nleft orientation",
		type = adj.config.param_types.Checkbox,
		width = 205,
		height = 62,
		values = { 1, 0 }
	},
	longnamestate = {
		id = 20,
	},
	envioswap = {
		id = 21,
	},
	tcplabelbrightness = {
		id = 22,
		name = 'Track name brightness',
		type = adj.config.param_types.Range,
		is_percentage = true,
		width = 205,
		height = 62,
	},
	trans_mixer = {
		id = 24,
		name = 'Mixer',
		type = adj.config.param_types.Checkbox,
		values = { 0, 1 }
	},
	trans_navigator = {
		id = 25,
		name = 'Project Navigator',
		type = adj.config.param_types.Checkbox,
		values = { 0, 1 }
	},
	trans_mediainfolder = {
		id = 26,
		name = 'Open selected file in Explorer',
		type = adj.config.param_types.Checkbox,
		values = { 0, 1 }
	},
	trans_video = {
		id = 27,
		name = 'Video Window',
		type = adj.config.param_types.Checkbox,
		values = { 0, 1 }
	},
	trans_regionman = {
		id = 28,
		name = 'Region/Marker Manager',
		type = adj.config.param_types.Checkbox,
		values = { 0, 1 }
	},
	trans_folder = {
		id = 29,
		name = 'Open Project Path',
		type = adj.config.param_types.Checkbox,
		values = { 0, 1 }
	},
	trans_explorer = {
		id = 30,
		name = 'Media Explorer',
		type = adj.config.param_types.Checkbox,
		values = { 0, 1 }
	},
	tcp_layout = {
		name = 'TCP Global Layout',
		type = adj.config.param_types.Layout,
		width = 420,
		height = 155,
		sizes = { "150", "200" },
		section = "tcp",
		values = {
			{ name = "Default", value = "Default", image = "images/pref_tcp_layout_1.png", borderRad = 15 },
			{ name = "Longname", value = "LONGNAME", image = "images/pref_tcp_layout_2.png", borderRad = 15 },
		},
		getValue = function()
			local _, layout = reaper.ThemeLayout_GetLayout("tcp", -1)
			return { value = not isEmpty(layout) and layout or "Default" }
		end,
		setValue = function(newVal)
			reaper.ThemeLayout_SetLayout("tcp", newVal)
		end
	},
	mcp_layout = {
		name = 'MCP Global Layout',
		type = adj.config.param_types.Layout,
		width = 420,
		height = 155,
		sizes = { "150", "200" },
		section = "mcp",
		values = {
			{ name = "Default", value = "Default", image = "images/pref_mcp_layout_1.png", borderRad = 15 },
			{ name = "Meterbridge", value = "METERBRIDGE", image = "images/pref_mcp_layout_2.png", borderRad = 15 },
		},
		getValue = function()
			local _, layout = reaper.ThemeLayout_GetLayout("mcp", -1)
			return { value = not isEmpty(layout) and layout or "Default" }
		end,
		setValue = function(newVal)
			reaper.ThemeLayout_SetLayout("mcp", newVal)
		end
	}
}

function adj.SetValue(parameter, value)
	parameter.data.value = value

	if parameter.setValue then
		parameter.setValue(value)
	else
		reaper.ThemeLayout_SetParameter(parameter.id, parameter.data.value, true)
		reaper.ThemeLayout_RefreshAll()
	end
end

function adj.GetUserPresets()
	local values = reaper.GetExtState(key_ext_prefix, key_ext_prefix_resets)

	return values and unserializeTable(values) or {}
end

function adj.SaveUserPreset(name)
	local presets = adj.GetUserPresets()
	local new_preset_values = {}

	for key, param in pairs(adj.params) do
		new_preset_values[key] = param.data.value
	end

	presets[name] = new_preset_values

	reaper.SetExtState(key_ext_prefix, key_ext_prefix_resets, serializeTable(presets), true)
end

function adj.DeleteUserPreset(name)
	local presets = adj.GetUserPresets()

	presets[name] = nil

	reaper.SetExtState(key_ext_prefix, key_ext_prefix_resets, serializeTable(presets), true)
end

function adj.Link(text, url)
	if not reaper.CF_ShellExecute then
		ImGui.Text(ctx, text)
		return
	end

	local color = ImGui.GetStyleColor(ctx, ImGui.Col_CheckMark)
	ImGui.TextColored(ctx, color, text)
	if ImGui.IsItemClicked(ctx) then
		reaper.CF_ShellExecute(url)
	elseif ImGui.IsItemHovered(ctx) then
		ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand)
	end
end

function adj.UpdateValues()
	if not NeedToUpdateValues() then return end

	for id, param in pairs(adj.params) do
		if param.getValue then
			adj.params[id].data = param.getValue()
		else
			local ret, name, value, _, minValue, maxValue = reaper.ThemeLayout_GetParameter(param.id)

			if ret then
				adj.params[id].data = { name = name, value = value, min = minValue, max = maxValue }
			end
		end
	end

	if adj.params.hideall.data == nil or not string.find(adj.params.hideall.data.name, "DOES FLAT MADNESS BEST THEME EVER?") then
		window_opened = false
		reaper.MB('Please install the lastest version of Flat Madness theme to be able to customize it', SCRIPT_NAME, 0)
		return false
	end

	return true
end

function adj.GetImage(src)
	local img = adj.cached_images[src]
	if not img then
		img = {}
		adj.cached_images[src] = img
	end

	if not ImGui.ValidatePtr(img.obj, 'ImGui_Image*') then
		if img.obj then adj.cached_images[img.obj] = nil end

		img.obj = ImGui.CreateImage(src)

		--reaper.ShowConsoleMsg('create ' .. src .. '\n')

		local prev = adj.cached_images[img.obj]
		if prev and prev ~= img then
			prev.obj = nil
		end

		adj.cached_images[img.obj] = img
	end

	img.width, img.height = ImGui.Image_GetSize(img.obj)

	return img
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

	local border = settings and settings.border or adj.config.border
	local borderRad = settings and settings.borderRad or adj.config.borderRad.image

	if ImGui.BeginChild(ctx, "img_" .. src, 0, height + border, nil, adj.config.windFlags) then
		local draw_list = ImGui.GetWindowDrawList(ctx)

		local avail_w = ImGui.GetContentRegionAvail(ctx)
		local p_min_x, p_min_y = ImGui.GetItemRectMin(ctx)

		p_min_x = p_min_x + math.max(0, (avail_w - width) // 2)

		ImGui.DrawList_AddRectFilled(draw_list, p_min_x - border, p_min_y, p_min_x + width + border, p_min_y + height + border, settings and settings.borderBg or adj.config.colors.Header, borderRad + border)
	 	ImGui.DrawList_AddImageRounded(draw_list, image.obj, p_min_x, p_min_y + border, p_min_x + width, p_min_y + height, 0, 0, 1, 1, adj.config.colors.White, borderRad)
	 	--ImGui.Dummy(ctx, width, height)
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

	if ImGui.BeginTable(ctx, "table_sub_" .. (parameter.id or "custom"), parameter.colspan or #values) then
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
		ImGui.SetNextItemWidth(ctx, -10)
		ImGui.Unindent(ctx, -10)
		ImGui.PushStyleColor(ctx, ImGui.Col_Text, adj.config.colors.Subheader)

		local min, max, val
		if parameter.is_percentage and parameter.is_reverse then
			min = 0
			max = 100
			val = (parameter.data.max - parameter.data.value) / (parameter.data.max - parameter.data.min)
			val = round(val * 100)
		elseif parameter.is_percentage then
			min = 0
			max = 100
			val = (parameter.data.value - parameter.data.min) / (parameter.data.max - parameter.data.min)
			val = round(val * 100)
		else
			min = parameter.data.min
			max = parameter.data.max
			val = parameter.data.value
		end

		local _, newVal = ImGui.SliderInt(ctx, "##", val, min, max, parameter.is_percentage and "%d%%" or nil)
		if newVal ~= val then
			local set
			if parameter.is_percentage and parameter.is_reverse then
				set = (newVal / 100) * (parameter.data.max - parameter.data.min)
				set = round(parameter.data.max - set)
			elseif parameter.is_percentage then
				set = (newVal / 100) * (parameter.data.max - parameter.data.min)
				set = round(parameter.data.min + set)
			else
				set = newVal
			end

			adj.SetValue(parameter, set)
		end
		ImGui.PopStyleColor(ctx, 1)

		ImGui.EndTable(ctx)
	end
end

function adj.DrawPanelBackground(parameter)
	local values = parameter.values

	ImGui.Dummy(ctx, 0, 5)
	adj.CenterText(parameter.name, adj.config.colors.Subheader)

	if ImGui.BeginTable(ctx, "table_sub_" .. (parameter.id or "custom"), parameter.colspan or #values) then
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

	if not parameter.height_original then
		parameter.height_original = parameter.height
	end

	if parameter.data.value == 3 then
		parameter.height = 265

		if ImGui.BeginTable(ctx, "sep", 2) then
			ImGui.TableNextColumn(ctx)
			adj.ShowParameter(adj.params[parameter.custom[1]])

			ImGui.TableNextColumn(ctx)
			adj.ShowParameter(adj.params[parameter.custom[2]])

			ImGui.TableNextRow(ctx)
			ImGui.TableNextColumn(ctx)
			adj.ShowParameter(adj.params[parameter.custom[3]])

			ImGui.TableNextColumn(ctx)

			ImGui.Dummy(ctx, 0, 20)
			ImGui.Indent(ctx, 50)

			ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, 15, 5)
			ImGui.PushStyleColor(ctx, ImGui.Col_Text, adj.config.colors.White)
			ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, adj.config.colors.Input.Background)
			if ImGui.Button(ctx, parameter.apply.title) then
				adj.SetValue(adj.params[parameter.apply.main_param], parameter.data.value)

				for key, val in pairs(parameter.apply.params) do
					adj.SetValue(adj.params[val], adj.params[key].data.value)
				end
			end
			ImGui.PopStyleColor(ctx, 2)
			ImGui.PopStyleVar(ctx)

			ImGui.EndTable(ctx)
		end
	else
		parameter.height = parameter.height_original
	end
end

function adj.DrawLayoutBlock(parameter)
	local values = parameter.values

	ImGui.Dummy(ctx, 0, 5)
	adj.CenterText(parameter.name, adj.config.colors.Subheader)

	if ImGui.BeginTable(ctx, "table_sub_layout", parameter.colspan or #values) then
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

	ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, 0, 0)

	ImGui.PopStyleVar(ctx)
end

function adj.ShowParameter(parameter)
	ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, adj.config.colors.ParameterBlockBackground)

	if ImGui.BeginChild(ctx, "parameter_" .. (parameter.id or "custom"), parameter.width, parameter.height, nil, adj.config.windFlags) then
		if parameter.type == adj.config.param_types.Simple then
			adj.DrawSimpleInput(parameter)
		elseif parameter.type == adj.config.param_types.Checkbox then
			adj.DrawCheckboxInput(parameter)
		elseif parameter.type == adj.config.param_types.Range then
			adj.DrawRangeInput(parameter)
		elseif parameter.type == adj.config.param_types.PanelBackground then
			adj.DrawPanelBackground(parameter)
		elseif parameter.type == adj.config.param_types.Layout then
			adj.DrawLayoutBlock(parameter)
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

function adj.DrawTransportButtonsPanel()
	ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, adj.config.colors.ParameterBlockBackground)

	if ImGui.BeginChild(ctx, "transport_button_panel", 420, 150, nil, adj.config.windFlags) then
		ImGui.Dummy(ctx, 0, 5)
		adj.CenterText("Custom transport buttons", adj.config.colors.Subheader)

		local columns = 2
		local parameters = {
			adj.params.trans_mixer,
			adj.params.trans_navigator,
			adj.params.trans_mediainfolder,
			adj.params.trans_video,
			adj.params.trans_regionman,
			adj.params.trans_folder,
			adj.params.trans_explorer,
		}

		ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + 15)

		if ImGui.BeginTable(ctx, "transport_button_panel_table", columns, nil, 400) then
			for i, parameter in pairs(parameters) do
				ImGui.TableNextColumn(ctx)

				local _, newVal = ImGui.Checkbox(ctx, parameter.name, parameter.data.value == parameter.values[2])
				local id = newVal and 2 or 1

				if parameter.data.value ~= parameter.values[id] then
					adj.SetValue(parameter, parameter.values[id])
				end

				if i % columns == 0 then
					ImGui.TableNextRow(ctx)
				end
			end

			ImGui.EndTable(ctx)
		end

		ImGui.EndChild(ctx)
	end

	ImGui.Spacing(ctx)

	ImGui.PopStyleColor(ctx, 1)
end

function adj.DrawPresetsSelect()
	local get_presets_list = function()
		local presets = { "No preset" }

		for i = 1, #adj.presets.default do table.insert(presets, adj.presets.default[i].name) end
		for name, _ in pairs(adj.GetUserPresets()) do table.insert(presets, name) end

		return presets
	end

	local presets = get_presets_list()

	table.insert(presets, "Delete preset...")
	table.insert(presets, "Save preset...")

	ImGui.PushItemWidth(ctx, 439)
	ImGui.PushStyleColor(ctx, ImGui.Col_HeaderActive, adj.config.colors.Selected)
	ImGui.PushStyleColor(ctx, ImGui.Col_HeaderHovered, adj.config.colors.Selected)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameRounding, 2)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, 9, 2)
	local _, newVal = ImGui.Combo(ctx, '##Presets', adj.presets.current, join(presets, "\0") .. "\0")
	ImGui.PopStyleVar(ctx, 2)
	ImGui.PopStyleColor(ctx, 2)
	ImGui.PopItemWidth(ctx)

	if newVal ~= adj.presets.current then
		local name = presets[newVal + 1]
		if name == "Save preset..." then
			::preset_enter_name::

			local preset_num = 1

			while in_array(presets, "Preset " .. preset_num) do
				preset_num = preset_num + 1
			end

			local is_done, result = reaper.GetUserInputs("Enter name of preset", 1, "Preset name", "Preset " .. preset_num)
			if is_done then
				if in_array({"Save preset...", "Delete preset..."}, result) or in_array(presets, result) and reaper.MB('Preset with this name is exists already. Are you sure you want to replace it?', "Saving preset...", 4) ~= 6 then
					goto preset_enter_name
				else
					adj.SaveUserPreset(result)

					presets = get_presets_list()
					for i = 1, #presets do
						if presets[i] == result then adj.presets.current = i - 1 end
					end
				end
			end
		elseif name == "Delete preset..." then
			if adj.presets.current and reaper.MB('Are you sure to delete this preset "' .. presets[adj.presets.current + 1] .. '"?', "Delete preset...", 4) == 6 then
				adj.DeleteUserPreset(presets[adj.presets.current + 1])
				adj.presets.current = 0
			end
		elseif newVal > 0 then
			local values = {}

			for i = 1, #adj.presets.default do
				if presets[newVal + 1] == adj.presets.default[i].name then
					values = adj.presets.default[i].values
				end
			end

			for p_name, p_vals in pairs(adj.GetUserPresets()) do
				if presets[newVal + 1] == p_name then
					values = p_vals
				end
			end

			if values then
				adj.presets.current = newVal

				for key, value in pairs(values) do
					adj.SetValue(adj.params[key], value)
				end
			end
		end
	end
end

function adj.GetVersion(scriptName)
	if not adj.versions then adj.versions = {} end

	scriptName = scriptName or ({reaper.get_action_context()})[2]

	if adj.versions[scriptName] == true then
		return nil
	elseif not adj.versions[scriptName] then
		local owner = reaper.ReaPack_GetOwner(scriptName)

		if owner then
			local _, _, _, _, _, _, ver, _, _, _ = reaper.ReaPack_GetEntryInfo(owner)
			reaper.ReaPack_FreeEntry(owner)

			adj.versions[scriptName] = ver
			return ver
		end
	else
		return adj.versions[scriptName]
	end

	adj.versions[scriptName] = true

	return nil
end

function adj.ShowWindow()
	adj.UpdateValues()

	adj.DrawHeader()
	ImGui.Spacing(ctx)
	ImGui.Spacing(ctx)

	adj.DrawPresetsSelect()
	ImGui.Spacing(ctx)

	if not adj.opened_first_tab then
		ImGui.SetNextItemOpen(ctx, true)
		ImGui.SetScrollHereY(ctx, 1.0)
		adj.opened_first_tab = true
	end

	adj.DrawCollapsingHeader('                 TRACK CONTROL PANEL', function()
		adj.ShowParameter(adj.params.tcp_solid_color)
		ImGui.Spacing(ctx)

		if ImGui.BeginTable(ctx, "sep", 2) then
			ImGui.TableNextColumn(ctx)
			adj.ShowParameter(adj.params.tcplabelbrightness)

			ImGui.TableNextColumn(ctx)
			adj.ShowParameter(adj.params.foldermargin)
			ImGui.EndTable(ctx)
		end

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

		adj.ShowParameter(adj.params.tcp_layout)
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
			adj.ShowParameter(adj.params.mcpdbscales)

			ImGui.EndTable(ctx)
		end

		ImGui.Spacing(ctx)

		adj.ShowParameter(adj.params.mcp_layout)
		ImGui.Spacing(ctx)
	end)

	ImGui.Spacing(ctx)

    adj.DrawCollapsingHeader('                              TRANSPORT', function()
		adj.ShowParameter(adj.params.trans_position)
		ImGui.Spacing(ctx)
		adj.DrawTransportButtonsPanel()
	end)

	ImGui.Spacing(ctx)

	adj.DrawCollapsingHeader('                         ABOUT SCRIPT', function()
		ImGui.TextWrapped(ctx, 'FM4 theme is created by Dmytro Hapochka, theme adjuster is designed by Dmytro Hapochka and developed by                        .')
		--ImGui.SameLine(ctx, 300, 30)
		ImGui.SetCursorPos(ctx, 308, 50)
		adj.Link("Ed Kashinsky", "https://github.com/edkashinsky/reaper-reableton-scripts")
		ImGui.Spacing(ctx)
		ImGui.Spacing(ctx)

		if ImGui.BeginTable(ctx, "sep3", 2) then
			ImGui.TableNextColumn(ctx)

			adj.DrawImage(SCRIPT_PATH .. "/images/bmc_qr_hapochka.png", { width = 270, borderRad = 8, border = 2 })
			ImGui.Dummy(ctx, 195, 0)
			adj.CenterText("Support Dmytro Hapochka")

			ImGui.TableNextColumn(ctx)

			adj.DrawImage(SCRIPT_PATH .. "/images/bmc_qr_kashinsky.png", { width = 270, borderRad = 8, border = 2 })
			ImGui.Dummy(ctx, 195, 0)
			adj.CenterText("Support Ed Kashinsky")

			ImGui.EndTable(ctx)
		end

		ImGui.Spacing(ctx)
		ImGui.Spacing(ctx)
		ImGui.Spacing(ctx)
		ImGui.Spacing(ctx)

        local scriptVersion = adj.GetVersion()
		if scriptVersion then
			ImGui.TextWrapped(ctx, 'Script version: ' .. scriptVersion)
		end

        local themeVersion = adj.GetVersion(reaper.GetLastColorThemeFile() .. "Zip")
		if themeVersion then
			ImGui.TextWrapped(ctx, 'Theme version: ' .. themeVersion)
		end

		ImGui.TextWrapped(ctx, "ReaImGui version: " .. imGuiVersion)
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

	ImGui.SetNextWindowSizeConstraints(ctx, -1, 0, -1, FLT_MAX)

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
	ImGui.PushStyleColor(ctx, ImGui.Col_ResizeGrip, adj.config.colors.Header)
	ImGui.PushStyleColor(ctx, ImGui.Col_ResizeGripHovered, adj.config.colors.Selected)
	ImGui.PushStyleColor(ctx, ImGui.Col_ResizeGripActive, adj.config.colors.Selected)
	ImGui.PushStyleColor(ctx, ImGui.Col_SeparatorHovered, adj.config.colors.Selected)
	ImGui.PushStyleColor(ctx, ImGui.Col_SeparatorActive, adj.config.colors.Selected)

	ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowBorderSize, 1);
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, 2, 2)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_CellPadding, 5, 5)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_ChildRounding, adj.config.borderRad.block)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 10, 10)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameRounding, adj.config.borderRad.block)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_GrabRounding, adj.config.borderRad.block)

	window_visible, window_opened = ImGui.Begin(ctx, " ", true, ImGui.WindowFlags_NoCollapse | ImGui.WindowFlags_NoDocking)

	if window_visible then
		adj.ShowWindow()
	end

	ImGui.PopStyleVar(ctx, 7)
	ImGui.PopStyleColor(ctx, 25)
	ImGui.PopFont(ctx)

	ImGui.End(ctx)

  	if window_opened then
    	reaper.defer(adj.loop)
  	end
end

adj.init()