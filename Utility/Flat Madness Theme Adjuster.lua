-- @description Flat Madness Theme Adjuster
-- @author Ed Kashinsky
-- @about Theme adjuster for Flat Madness theme
-- @version 5.2.1.1
-- @changelog
--   * Presets works now!
-- @provides
--   [main] theme/*.lua
--   [nomain] img/*.png

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
local ek_log_levels = { Debug = 1 }
local function Log(msg) if type(msg) == 'table' then msg = serializeTable(msg) else msg = tostring(msg) end if msg then reaper.ShowConsoleMsg("[" .. os.date("%H:%M:%S") .. "] ") reaper.ShowConsoleMsg(msg) reaper.ShowConsoleMsg('\n') end end

local _, _, imGuiVersion = reaper.ImGui_GetVersion()
local function serializeTable(t) return Pickle:clone():pickle_(t) end
local function unserializeTable(s) if s == nil or s == '' then return end if type(s) ~= "string" then error("can't unpickle a "..type(s)..", only strings") end local gentables = load("return " .. s) if gentables then local tables = gentables() if tables then for tnum = 1, #tables do local t = tables[tnum] local tcopy = {} for i, v in pairs(t) do tcopy[i] = v end for i, v in pairs(tcopy) do local ni, nv if type(i) == "table" then ni = tables[i[1]] else ni = i end if type(v) == "table" then nv = tables[v[1]] else nv = v end t[i] = nil t[ni] = nv end end return tables[1] end else end end
local function join(list, delimiter) if type(list) ~= 'table' or #list == 0 then return "" end local startNum = list[0] and 0 or 1 local string = list[startNum] for i = startNum + 1, #list do string = string .. delimiter .. list[i] end return string end
local function in_array(tab, val) for _, value in ipairs(tab) do if value == val then return true end end return false end
local function isEmpty(value) if value == nil then return true end if type(value) == 'boolean' and value == false then return true end if type(value) == 'table' and next(value) == nil then return true end if type(value) == 'number' and value == 0 then return true end if type(value) == 'string' and string.len(value) == 0 then return true end return false end
local function round(number, decimals) if not decimals then decimals = 0 end local power = 10 ^ decimals return math.ceil(number * power) / power end
local function clamp(value, min, max) return math.max(tonumber(min) or 0, math.min(tonumber(value) or 0, tonumber(max) or 0)) end
local function ThemeLayoutSetParameter(id, val, param)
	--Log("SET " .. id .. " = " .. val .. " " ..  clamp(val, param.data.min, param.data.max), ek_log_levels.Important)
	reaper.ThemeLayout_SetParameter(id, clamp(val, param.data.min, param.data.max), true)
end


local ctx = ImGui.CreateContext(SCRIPT_NAME)
local _, FLT_MAX = ImGui.NumericLimits_Float()
local window_visible = false
local window_opened = false
local start_time = 0
local cooldown = 1
local key_ext_prefix = "fm4_adjuster"
local key_ext_prefix_resets = "presets"
local need_to_update_values = false

local function NeedToUpdateValues()
	if need_to_update_values then
		need_to_update_values = false
		return true
	end

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
			SectionBackground = 0x656565ff,
			ParameterBlockBackground = 0x555555ff,
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
			Layout = 6,
			ColorPicker = 7
		},
		value_types = {
			Theme = 1,
			ThemeLayout = 2,
			Layout = 3,
			ColorFader = 4,
		},
		windFlags = ImGui.WindowFlags_NoScrollbar | ImGui.WindowFlags_NoScrollWithMouse,
		childFlags = ImGui.ChildFlags_AlwaysUseWindowPadding | ImGui.ChildFlags_AutoResizeY,
		tableFlags = ImGui.TableFlags_BordersV | ImGui.TableFlags_BordersOuterH | ImGui.TableFlags_RowBg,
		header = { image = nil, src = "img/header.png" },
		layouts = {
			value = 1, values = { "A", "B", "C" },
		}
	},
	presets = {
		current = nil,
		default = {
			{ name = "I See The Folder", values = { trans_mediainfolder = 1, saturncmcp = 180, tinymode = 2, tcplabelbrightness = 180, foldermargin = 1, trans_navigator = 1, mcpdbscales = 1, longnamestate = 1, min_fxlist = 65, tcp_saturn_ident = 10, saturnfolder = 1, trans_folder = 1, mcpsaturnfolder = 1, trans_regionman = 1, saturnc = 80, trans_video = 1, lnstatemd = 2, tcp_saturn_identmcp = 10, trans_explorer = 1, tcp_folder_recarms = 1, mcp_folder_recarms = 0, tcp_solid_color = 3, hideall = 2, mcp_solid_color = 3, saturnalphamcp = 217, gencoloring = 2, embed_position = 1, gloss = 1, envioswap = 1, fxsidead = 1, meter_position = 3, saturnalpha = 255, trans_mixer = 1, dbscales = 0, mixer_folderindent = 2, trans_position = 1,  } },
			{ name = "Toxic", values = { saturnfolder = 1, envioswap = 1, gencoloring = 2, longnamestate = 1, mcp_solid_color = 3, mixer_folderindent = 2, saturnc = 100, fxsidead = 0, foldermargin = 1, trans_position = 1, dbscales = 0, tinymode = 2, tcp_saturn_ident = 10, hideall = 2, mcpsaturnfolder = 120, trans_folder = 1, tcplabelbrightness = 180, gloss = 1, trans_explorer = 1, saturnalphamcp = 255, meter_position = 1, trans_regionman = 1, tcp_solid_color = 3, trans_video = 1, trans_mediainfolder = 1, tcp_folder_recarms = 0, trans_navigator = 1, tcp_saturn_identmcp = 10, trans_mixer = 1, mcpdbscales = 1, min_fxlist = 65, saturnalpha = 1, lnstatemd = 2, saturncmcp = 120, mcp_folder_recarms = 0, embed_position = 1,  } },
			{ name = "Meter Freak", values = { saturnfolder = 1, envioswap = 1, gencoloring = 2, longnamestate = 1, mcp_solid_color = 3, mixer_folderindent = 2, saturnc = 100, fxsidead = 0, foldermargin = 1, trans_position = 1, dbscales = 1, tinymode = 2, tcp_saturn_ident = 10, hideall = 2, mcpsaturnfolder = 120, trans_folder = 1, tcplabelbrightness = 180, gloss = 1, trans_explorer = 1, saturnalphamcp = 255, meter_position = 2, trans_regionman = 1, tcp_solid_color = 3, trans_video = 1, trans_mediainfolder = 1, tcp_folder_recarms = 0, trans_navigator = 1, tcp_saturn_identmcp = 10, trans_mixer = 1, mcpdbscales = 1, min_fxlist = 65, saturnalpha = 255, lnstatemd = 2, saturncmcp = 120, mcp_folder_recarms = 0, embed_position = 1,  } },
			{ name = "Sweet candy", values = { tcp_saturn_ident = 10, trans_mediainfolder = 1, trans_video = 1, trans_navigator = 1, mcp_solid_color = 3, embed_position = 1, min_fxlist = 65, tcp_saturn_identmcp = 10, tcp_solid_color = 3, tcp_folder_recarms = 0, saturnalphamcp = 172, tinymode = 2, lnstatemd = 2, mcp_folder_recarms = 0, mixer_folderindent = 2, trans_folder = 1, saturnc = 180, saturncmcp = 180, foldermargin = 1, trans_position = 1, envioswap = 1, trans_mixer = 1, saturnalpha = 172, meter_position = 1, dbscales = 0, saturnfolder = 1, mcpsaturnfolder = 1, trans_regionman = 1, mcpdbscales = 1, gloss = 1, fxsidead = 0, trans_explorer = 1, tcplabelbrightness = 180, hideall = 2, longnamestate = 1, gencoloring = 2,  } },
			{ name = "Yeah, it's flat", values = { tcp_saturn_ident = 10, trans_mediainfolder = 1, trans_video = 1, trans_navigator = 1, mcp_solid_color = 3, embed_position = 1, min_fxlist = 65, tcp_saturn_identmcp = 10, tcp_solid_color = 3, tcp_folder_recarms = 1, saturnalphamcp = 255, tinymode = 2, lnstatemd = 2, mcp_folder_recarms = 0, mixer_folderindent = 2, trans_folder = 1, saturnc = 100, saturncmcp = 120, foldermargin = 1, trans_position = 1, envioswap = 1, trans_mixer = 1, saturnalpha = 255, meter_position = 1, dbscales = 0, saturnfolder = 101, mcpsaturnfolder = 1, trans_regionman = 1, mcpdbscales = 1, gloss = 0, fxsidead = 1, trans_explorer = 1, tcplabelbrightness = 180, hideall = 2, longnamestate = 1, gencoloring = 2,  } },
			{ name = "I Am Not Pro Tools", values = { tcp_saturn_ident = 10, trans_mediainfolder = 1, trans_video = 1, trans_navigator = 1, mcp_solid_color = 2, embed_position = 1, min_fxlist = 65, tcp_saturn_identmcp = 10, tcp_solid_color = 2, tcp_folder_recarms = 0, saturnalphamcp = 255, tinymode = 2, lnstatemd = 2, mcp_folder_recarms = 0, mixer_folderindent = 2, trans_folder = 1, saturnc = 100, saturncmcp = 120, foldermargin = 1, trans_position = 1, envioswap = 1, trans_mixer = 1, saturnalpha = 1, meter_position = 4, dbscales = 0, saturnfolder = 1, mcpsaturnfolder = 120, trans_regionman = 1, mcpdbscales = 1, gloss = 1, fxsidead = 1, trans_explorer = 1, tcplabelbrightness = 180, hideall = 2, longnamestate = 1, gencoloring = 2,  } },
			{ name = "Dark Night", values = { tcp_saturn_ident = 21, trans_mediainfolder = 1, trans_video = 1, trans_navigator = 1, mcp_solid_color = 3, embed_position = 1, min_fxlist = 65, tcp_saturn_identmcp = 21, tcp_solid_color = 3, tcp_folder_recarms = 0, saturnalphamcp = 255, tinymode = 2, lnstatemd = 2, mcp_folder_recarms = 0, mixer_folderindent = 2, trans_folder = 1, saturnc = 100, saturncmcp = 100, foldermargin = 1, trans_position = 1, envioswap = 1, trans_mixer = 1, saturnalpha = 255, meter_position = 1, dbscales = 0, saturnfolder = 179, mcpsaturnfolder = 179, trans_regionman = 1, mcpdbscales = 1, gloss = 1, fxsidead = 1, trans_explorer = 1, tcplabelbrightness = 180, hideall = 2, longnamestate = 1, gencoloring = 2,  } },
			{ name = "This Preset is a bug", values = { mcpdbscales = 2, dbscales = 1, embed_position = 2, pan_type = 2, mcp_solid_color = 3, gencoloring = 2, min_fxlist = 42, mcp_folder_recarms = 1, foldermargin = 1, saturnalpha = 215, tcplabelbrightness = 147, hideall = 2, tcp_saturn_ident = 0, trans_position = 1, tcp_folder_recarms = 1, saturnc = 156, meter_position = 1, saturncmcp = 156, envioswap = 2, longnamestate = 1, tcp_saturn_identmcp = 0, saturnalphamcp = 215, mcp_layout = "Default", tcp_solid_color = 3, tcp_layout = "Default", mixer_folderindent = 2, } },
		}
	},
	currentPreset = nil,
}

adj.params = {
	hideall = {
		id = 0,
	},
	meter_position = {
		id = { 1, 47, 79 },
		name = 'Meter position',
		type = adj.config.param_types.Simple,
		value_type = adj.config.value_types.ThemeLayout,
		width = 420,
		height = 165,
		colspan = 2,
		values = {
			{ name = "Left", value = 1, image = "img/pref_tcp_meterleft.png", borderRad = 5 },
			{ name = "Meterbridge", value = 2, image = "img/pref_tcp_meterbridge.png", borderRad = 5 },
			{ name = "Right", value = 3, image = "img/pref_tcp_meterright.png", borderRad = 5 },
			{ name = "Almost Right", value = 4, image = "img/pref_tcp_meterrightedge.png", borderRad = 5 },
		}
	},
	lnstatemd = {
		id = { 2, 48, 80 },
		name = 'Track Label Scheme',
		type = adj.config.param_types.Simple,
		value_type = adj.config.value_types.ThemeLayout,
		width = 420, height = 155,
		values = {
			{ name = "Default", value = 0, image = "img/pref_tcp_layout_1.png" },
			{ name = "Longname", value = 1, image = "img/pref_tcp_layout_2.png" },
		}
	},
	min_fxlist = {
		id = { 3, 49, 81 },
		name = 'FX/SEND SLOT MIN WIDTH',
		type = adj.config.param_types.Range,
		value_type = adj.config.value_types.ThemeLayout,
		width = 205, height = 65,
	},
	embed_position = {
		id = { 4, 50, 82 },
		name = 'EMBEDDED UI POSITION',
		type = adj.config.param_types.Simple,
		value_type = adj.config.value_types.ThemeLayout,
		width = 205, height = 165,
		colspan = 1,
		values = {
			{ name = "Beside FX", value = 0, image = "img/pref_tcp_embedright.png", borderRad = 5 },
			{ name = "Instead FX**", value = 1, image = "img/pref_tcp_embedinstead.png", borderRad = 5 },
		}
	},
	tcp_folder_recarms = {
		id = { 5, 51, 83 },
		name = 'Record stuff in Folders',
		type = adj.config.param_types.Checkbox,
		value_type = adj.config.value_types.ThemeLayout,
		width = 205, height = 41,
		values = { 0, 1 }
	},
	mcp_folder_recarms = {
		id = { 6, 52, 84 },
		name = 'Record stuff in Folders',
		type = adj.config.param_types.Checkbox,
		value_type = adj.config.value_types.ThemeLayout,
		width = 205, height = 41,
		values = { 0, 1 }
	},
	dbscales = {
		id = { 7, 53, 85 },
		name = 'DB Scales',
		type = adj.config.param_types.Checkbox,
		value_type = adj.config.value_types.ThemeLayout,
		width = 205, height = 41,
		values = { 0, 1 }
	},
	mcpdbscales = {
		id = { 8, 54, 86 },
		name = 'DB Scales',
		type = adj.config.param_types.Checkbox,
		value_type = adj.config.value_types.ThemeLayout,
		width = 205, height = 41,
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
			{ name = "Left", value = 1, image = "img/pref_trans_position_left.png" },
			{ name = "Center", value = 2, image = "img/pref_trans_position_center.png" },
			{ name = "Right", value = 3, image = "img/pref_trans_position_right.png" },
		}
	},
	tcp_solid_color = {
		id = { 10, 55, 87 },
		name = 'Panel Background',
		type = adj.config.param_types.PanelBackground,
		value_type = adj.config.value_types.ThemeLayout,
		width = 420,
		height = 130,
		custom = { "saturnc", "saturnalpha", "tcp_saturn_ident", "saturnfolder" },
		apply = { title = "Apply to MCP", main_param = "mcp_solid_color", params = {
			saturnc = "saturncmcp",
			saturnalpha = "saturnalphamcp",
			tcp_saturn_ident = "tcp_saturn_identmcp",
			saturnfolder = "mcpsaturnfolder"
		}},
		values = {
			{ name = "Solid", value = 2, image = "img/pref_tcp_greybg.png", borderRad = 15 },
			{ name = "Color", value = 1, image = "img/pref_tcp_colorbg.png", borderRad = 15 },
			{ name = "Custom", value = 3, image = "img/pref_tcp_custom.png", borderRad = 15 },
		}
	},
	mcp_solid_color = {
		id = { 11, 55, 91 },
		name = 'Panel Background',
		type = adj.config.param_types.PanelBackground,
		value_type = adj.config.value_types.ThemeLayout,
		width = 420,
		height = 130,
		custom = { "saturncmcp", "saturnalphamcp", "tcp_saturn_identmcp", "mcpsaturnfolder" },
		apply = { title = "Apply to TCP", main_param = "tcp_solid_color", params = {
			saturncmcp = "saturnc",
			saturnalphamcp = "saturnalpha",
			tcp_saturn_identmcp = "tcp_saturn_ident",
			mcpsaturnfolder = "saturnfolder"
		}},
		values = {
			{ name = "Solid", value = 2, image = "img/pref_mcp_greybg.png", borderRad = 15 },
			{ name = "Color", value = 1, image = "img/pref_mcp_colorbg.png", borderRad = 15 },
			{ name = "Custom", value = 3, image = "img/pref_mcp_custom.png", borderRad = 15 },
		}
	},
	mixer_folderindent = {
		id = 12,
		name = 'Folder padding (all layouts)',
		type = adj.config.param_types.Simple,
		width = 420,
		height = 160,
		values = {
			{ name = "Padding Off", value = 1, image = "img/pref_mcp_paddingoff.png" },
			{ name = "Padding On", value = 2, image = "img/pref_mcp_paddingon.png" },
		}
	},
	saturnc = {
		id = { 13, 57, 89 },
		name = 'Brightness',
		type = adj.config.param_types.Range,
		value_type = adj.config.value_types.ThemeLayout,
		is_percentage = true,
		width = 205, height = 57,
	},
	saturnalpha = {
		id = { 14, 58, 90 },
		name = 'Saturation',
		type = adj.config.param_types.Range,
		value_type = adj.config.value_types.ThemeLayout,
		is_percentage = true,
		is_reverse = true,
		width = 205, height = 57,
	},
	tcp_saturn_ident = {
		id = { 15, 59, 91 },
		name = 'Sel Track Highlight',
		type = adj.config.param_types.Range,
		value_type = adj.config.value_types.ThemeLayout,
		is_percentage = true,
		width = 205, height = 57,
	},
	saturncmcp = {
		id = { 16, 60, 92 },
		name = 'Brightness',
		type = adj.config.param_types.Range,
		value_type = adj.config.value_types.ThemeLayout,
		is_percentage = true,
		width = 205, height = 57,
	},
	saturnalphamcp = {
		id = { 17, 61, 93 },
		name = 'Saturation',
		type = adj.config.param_types.Range,
		value_type = adj.config.value_types.ThemeLayout,
		is_percentage = true,
		is_reverse = true,
		width = 205, height = 57,
	},
	tcp_saturn_identmcp = {
		id = { 18, 62, 94 },
		name = 'Sel Track Highlight',
		type = adj.config.param_types.Range,
		value_type = adj.config.value_types.ThemeLayout,
		is_percentage = true,
		width = 205, height = 57,
	},
	gencoloring = {
		id = 19,
	},
	foldermargin = {
		id = { 20, 63, 95 },
		name = "Folder Name \nleft orientation",
		type = adj.config.param_types.Checkbox,
		value_type = adj.config.value_types.ThemeLayout,
		width = 205, height = 62,
		values = { 1, 0 }
	},
	envioswap = {
		id = 21,
	},
    tcplabelbrightness = {
		id = { 22, 64, 96 },
		name = 'Track name brightness',
		type = adj.config.param_types.Range,
		value_type = adj.config.value_types.ThemeLayout,
		is_percentage = true,
		width = 205, height = 62,
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
	saturnfolder = {
		id = { 32, 66, 98 },
		name = 'Folder Saturation',
		type = adj.config.param_types.Range,
		value_type = adj.config.value_types.ThemeLayout,
		is_percentage = true,
		width = 205,
		height = 57,
	},
	fxsidead = {
		id = { 33, 67, 99 },
		name = "FX List Position",
		type = adj.config.param_types.Simple,
		value_type = adj.config.value_types.ThemeLayout,
		width = 420, height = 160,
		values = {
			{ name = "Center", value = 0, image = "img/pref_tcp_fxcenter.png" },
			{ name = "Right", value = 1, image = "img/pref_tcp_fxside.png" },
		}
	},
	gloss = {
		id = 34,
		name = 'Gloss effect',
		type = adj.config.param_types.Checkbox,
		width = 205,
		height = 43,
		values = { 0, 1 }
	},
	tinymode = {
		id = { 35, 68, 100 },
		name = 'Scheme for small track height',
		type = adj.config.param_types.Simple,
		value_type = adj.config.value_types.ThemeLayout,
		width = 420, height = 210,
		colspan = 1,
		values = {
			{ name = "Effects", value = 1, image = "img/pref_tcp_tiny1.png", borderRad = 2 },
			{ name = "Meterbridge", value = 2, image = "img/pref_tcp_tiny2.png", borderRad = 2 },
			{ name = "Longname", value = 3, image = "img/pref_tcp_tiny3.png", borderRad = 2 },
		}
	},
	mcpsaturnfolder = {
		id = { 36, 69, 101 },
		name = 'Folder Saturation',
		type = adj.config.param_types.Range,
		value_type = adj.config.value_types.ThemeLayout,
		is_percentage = true,
		width = 205, height = 57,
	},
	dividercolor = {
		id = 37,
		name = 'track divider intensity',
		type = adj.config.param_types.Range,
		is_percentage = true,
		width = 205,
		height = 65,
	},
	sendlist = {
		id = { 38, 70, 102 },
		name = 'Separate Sendlist***',
		type = adj.config.param_types.Checkbox,
		value_type = adj.config.value_types.ThemeLayout,
		width = 205, height = 65,
		values = { 0, 1 }
	},
	min_fxlist_sep = {
		id = { 39, 71, 103 },
		name = 'FX LIST MINIMAL WIDTH',
		type = adj.config.param_types.Range,
		value_type = adj.config.value_types.ThemeLayout,
		width = 205, height = 65,
	},
	mcppanslider = {
		id = { 40, 72, 104 },
		name = 'PAN TYPE',
		type = adj.config.param_types.Simple,
		value_type = adj.config.value_types.ThemeLayout,
		width = 420, height = 160,
		values = {
			{ name = "KNOB", value = 0, image = "img/pref_tcp_knob.png" },
			{ name = "SLIDER", value = 1, image = "img/pref_tcp_slider.png" },
		}
	},
	fxheight = {
		id = { 41, 73, 105 },
		name = 'FX LIST SLOT HEIGHT',
		type = adj.config.param_types.Range,
		value_type = adj.config.value_types.ThemeLayout,
		width = 205, height = 65,
	},
	volumeadj = {
		id = { 46, 78, 110 },
		name = 'show volume buttons +-0.1db',
		type = adj.config.param_types.Checkbox,
		value_type = adj.config.value_types.ThemeLayout,
		width = 420, height = 41,
		values = { 0, 1 }
	},
	tcp_layout = {
		name = 'TCP Pan/Width mode',
		type = adj.config.param_types.Layout,
		value_type = adj.config.value_types.Layout,
		is_global = false,
		width = 420,
		height = 155,
		sizes = { "150", "200" },
		section = "tcp",
		track_section = "P_TCP_LAYOUT",
		values = {
			{ name = "Knob", value = { "A", "B", "C" }, image = "img/pref_tcp_knob.png", borderRad = 15 },
			{ name = "Slider", value = { "PAN_SLIDER A", "PAN_SLIDER B", "PAN_SLIDER C" }, image = "img/pref_tcp_slider.png", borderRad = 15, is_layout = true },
		},
	},
	mcp_layout = {
		name = 'MCP Global Layout',
		type = adj.config.param_types.Layout,
		value_type = adj.config.value_types.Layout,
		is_global = false,
		width = 420,
		height = 155,
		sizes = { "150", "200" },
		section = "mcp",
		track_section = "P_MCP_LAYOUT",
		values = {
			{ name = "Default", value = { "A", "B", "C" }, image = "img/pref_mcp_layout_1.png", borderRad = 15 },
			{ name = "Meterbridge", value = { "METERBRIDGE A", "METERBRIDGE B", "METERBRIDGE C" }, image = "img/pref_mcp_layout_2.png", borderRad = 15, is_layout = true },
		},
	},
	fader_color_a = {
		id = { 42, 43, 44, 45 },
		name = 'FADER A',
		type = adj.config.param_types.ColorPicker,
		value_type = adj.config.value_types.ColorFader,
		width = 80,
		height = 22,
		default_palette = { 0xFF0000FF, 0x00FF00FF, 0x0000FFFF, 0xFFFF00FF, 0xFF00FFFF, 0xFFFFFFFF, 0x444444FF, 0x000000FF }
	},
	fader_color_b = {
		id = { 74, 75, 76, 77 },
		name = 'FADER B',
		type = adj.config.param_types.ColorPicker,
		value_type = adj.config.value_types.ColorFader,
		width = 80,
		height = 22,
		default_palette = { 0xFF0000FF, 0x00FF00FF, 0x0000FFFF, 0xFFFF00FF, 0xFF00FFFF, 0xFFFFFFFF, 0x444444FF, 0x000000FF }
	},
	fader_color_c = {
		id = { 106, 107, 108, 109 },
		name = 'FADER C',
		type = adj.config.param_types.ColorPicker,
		value_type = adj.config.value_types.ColorFader,
		width = 80,
		height = 22,
		default_palette = { 0xFF0000FF, 0x00FF00FF, 0x0000FFFF, 0xFFFF00FF, 0xFF00FFFF, 0xFFFFFFFF, 0x444444FF, 0x000000FF }
	},
}

function adj.GetValue(param, id)
	if param.value_type == adj.config.value_types.Layout then
		if not param.cached_layout or param.cached_layout ~= adj.config.layouts.value then
			local _, globalLayout = reaper.ThemeLayout_GetLayout(param.section, -1)
			local layout = adj.config.layouts.value
			local value

			globalLayout = not isEmpty(globalLayout) and globalLayout or "Default"

			if param.is_global then
				for j = 1, #param.values do
					if param.values[j].value[layout] == globalLayout then
						value = j
						break
					end
				end
			else
				for i = 0, reaper.CountTracks(0) - 1 do
					local tr = reaper.GetTrack(0, i)
					local _, trackLayout = reaper.GetSetMediaTrackInfo_String(tr, param.track_section, "", false)

					if isEmpty(trackLayout) or trackLayout == "Default" then trackLayout = globalLayout end

					for j = 1, #param.values do
						if param.values[j].value[layout] == trackLayout then
							value = j
							break
						end
					end

					if value then break end
				end
			end

			adj.params[id].cached_layout = adj.config.layouts.value

			return { value = value or 1 }
		end
	elseif param.value_type == adj.config.value_types.ThemeLayout then
		local layout = adj.config.layouts.value
		local ret, name, value, _, minValue, maxValue = reaper.ThemeLayout_GetParameter(param.id[layout])

		if ret then
			return { name = name, value = value, min = minValue, max = maxValue }
		end
	elseif param.value_type == adj.config.value_types.ColorFader then
		local ret, name, cur_r, _, minValue, maxValue = reaper.ThemeLayout_GetParameter(param.id[1])
		local _, _, cur_g = reaper.ThemeLayout_GetParameter(param.id[2])
		local _, _, cur_b = reaper.ThemeLayout_GetParameter(param.id[3])
		local _, _, cur_a = reaper.ThemeLayout_GetParameter(param.id[4])
		local value = ((cur_r & 0xFF) << 24) | ((cur_g & 0xFF) << 16) | ((cur_b & 0xFF) << 8) | (cur_a & 0xFF)

		if ret then
			return { name = name, value = value, min = minValue, max = maxValue }
		end
	else
		local ret, name, value, _, minValue, maxValue = reaper.ThemeLayout_GetParameter(param.id)

		if ret then
			return { name = name, value = value, min = minValue, max = maxValue }
		end
	end

	return param.data
end

function adj.SetValue(param, value)
	if param.value_type == adj.config.value_types.Layout then
		local layout = adj.config.layouts.value
		local layoutValue = param.values[value] and param.values[value].value[layout] or "Default"

		if param.is_global then
			reaper.ThemeLayout_SetLayout(param.section, layoutValue)
		else
			local _, globalLayout = reaper.ThemeLayout_GetLayout(param.section, -1)
			globalLayout = not isEmpty(globalLayout) and globalLayout or "Default"

			for i = 0, reaper.CountTracks(0) - 1 do
				local tr = reaper.GetTrack(0, i)
				local _, trackLayout = reaper.GetSetMediaTrackInfo_String(tr, param.track_section, "", false)
				local needToChange = false

				if isEmpty(trackLayout) or trackLayout == "Default" then trackLayout = globalLayout end

				for j = 1, #param.values do
					if param.values[j].value[layout] == trackLayout or (trackLayout == "Default" and layout == 1 and j == 1) then
						needToChange = true
						break
					end
				end

				if needToChange then
					reaper.GetSetMediaTrackInfo_String(tr, param.track_section, layoutValue, true)
				end
			end
		end
	elseif param.value_type == adj.config.value_types.ThemeLayout then
		local layout = adj.config.layouts.value
		ThemeLayoutSetParameter(param.id[layout], value, param)
		reaper.ThemeLayout_RefreshAll()
	elseif param.value_type == adj.config.value_types.ColorFader then
		ThemeLayoutSetParameter(param.id[1], (value >> 24) & 0xFF, param)
		ThemeLayoutSetParameter(param.id[2], (value >> 16) & 0xFF, param)
		ThemeLayoutSetParameter(param.id[3], (value >> 8) & 0xFF, param)
		ThemeLayoutSetParameter(param.id[4], value & 0xFF, param)

		reaper.ThemeLayout_RefreshAll()
	else
		ThemeLayoutSetParameter(param.id, value, param)
		reaper.ThemeLayout_RefreshAll()
	end

	param.data.value = value
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
		adj.params[id].data = adj.GetValue(param, id)
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

        --reaper.ShowConsoleMsg('create ' .. src .. '\n')

		img.obj = ImGui.CreateImage(src)

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

	if ImGui.BeginTable(ctx, "table_sub_" .. (tostring(parameter.name) or "custom"), parameter.colspan or #values) then
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

	if ImGui.BeginTable(ctx, "table_sub_" .. (tostring(parameter.name) or "custom"), parameter.colspan or #values) then
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
		parameter.height = 325

		if ImGui.BeginTable(ctx, "sep", 2) then
			ImGui.TableNextColumn(ctx)
			adj.ShowParameter(adj.params[parameter.custom[1]])

			ImGui.TableNextColumn(ctx)
			adj.ShowParameter(adj.params[parameter.custom[2]])

			ImGui.TableNextRow(ctx)
			ImGui.TableNextColumn(ctx)
			adj.ShowParameter(adj.params[parameter.custom[3]])

			ImGui.TableNextColumn(ctx)
			adj.ShowParameter(adj.params[parameter.custom[4]])

			ImGui.EndTable(ctx)

			ImGui.Dummy(ctx, 0, 5)

			local avail_w = ImGui.GetContentRegionAvail(ctx)
			local text_w  = ImGui.CalcTextSize(ctx, parameter.apply.title)

			ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + math.max(0, (avail_w - text_w) // 2))

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

		for key, val in pairs(values) do
			ImGui.TableNextColumn(ctx)

			local selColor = parameter.data.value == key and adj.config.colors.Selected or adj.config.colors.Header
			adj.DrawImage(SCRIPT_PATH .. val.image, { borderBg = selColor, borderRad = val.borderRad })

			if ImGui.IsItemClicked(ctx) then
				adj.SetValue(parameter, key)
			end

			adj.CenterText(val.name, selColor)

			if ImGui.IsItemClicked(ctx) then
				adj.SetValue(parameter, key)
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

function adj.DrawColorPicker(parameter)
    local x, y = ImGui.GetCursorScreenPos(ctx)

    -- 3. Рисуем кнопку-полоску
    if ImGui.ColorButton(ctx, "##btn_" .. parameter.name, parameter.data.value, 0, parameter.width, parameter.height) then
        ImGui.OpenPopup(ctx, "Popup_" .. parameter.name)
    end

	if ImGui.IsItemHovered(ctx) then
		ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand)
	end

    -- Текст внутри кнопки (75% прозрачности)
    local draw_list = ImGui.GetWindowDrawList(ctx)
    local text_w, text_h = ImGui.CalcTextSize(ctx, parameter.name)
    ImGui.DrawList_AddText(draw_list, x + (parameter.width - text_w) / 2, y + (parameter.height - text_h) / 2, 0x000000FF, parameter.name)

    -- 5. Всплывающее окно
    if ImGui.BeginPopup(ctx, "Popup_" .. parameter.name) then
        ImGui.TextColored(ctx, parameter.data.value, "FADER COLOR SETTINGS: LAYOUT " .. parameter.name)
        ImGui.Separator(ctx)
        ImGui.Spacing(ctx)

        local flags = ImGui.ColorEditFlags_AlphaBar
        local changed, new_color = ImGui.ColorPicker4(ctx, "##pk_" .. parameter.name, parameter.data.value, flags)

        if changed then
			adj.SetValue(parameter, new_color)
        end

        ImGui.Spacing(ctx)
        ImGui.Separator(ctx)

        -- РИСУЕМ ПАЛИТРУ
        local btn_sz = 20 -- размер квадратика
        for i, col in ipairs(parameter.default_palette) do
            if ImGui.ColorButton(ctx, "##pal_" .. parameter.name .. i, col, 0, btn_sz, btn_sz) then
				adj.SetValue(parameter, col)
            end
            -- Сетка по 8 элементов
            if i % 8 ~= 0 then ImGui.SameLine(ctx) end
        end

        -- КНОПКА ПЛЮС (+)
        -- Если элементов 8, 16 и т.д., переходим на новую строку, иначе - в ряд
        if #parameter.default_palette % 8 ~= 0 then ImGui.SameLine(ctx) end

        if ImGui.Button(ctx, "+##add_" .. parameter.name, btn_sz, btn_sz) then
            -- Добавляем текущий цвет в таблицу
            table.insert(parameter.default_palette, parameter.data.value)
        end

        -- Подсказка при наведении на плюс
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Add current color to palette")
        end

        ImGui.EndPopup(ctx)
    end
end

function adj.ShowParameter(parameter)
	ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, adj.config.colors.ParameterBlockBackground)

	if ImGui.BeginChild(ctx, "parameter_" .. (tostring(parameter.name) or "custom"), parameter.width, parameter.height, nil, adj.config.windFlags) then
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
		elseif parameter.type == adj.config.param_types.ColorPicker then
			adj.DrawColorPicker(parameter)
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

function adj.DrawLayoutsButtons()
    local values = adj.config.layouts.values
    local avail_w = ImGui.GetContentRegionAvail(ctx)
    local draw_list = ImGui.GetWindowDrawList(ctx)
    local cur_x, cur_y = ImGui.GetCursorScreenPos(ctx)

    local header_h = 56
    ImGui.DrawList_AddRectFilled(draw_list, cur_x - 10, cur_y, cur_x + avail_w + 10, cur_y + header_h, 0x414141ff)

    local vertical_margin = 0
    local button_width = 30
    local button_height = 30
    local button_spacing = 8
    local total_width = (#values * button_width) + ((#values - 1) * button_spacing)

    ImGui.Dummy(ctx, 0, vertical_margin)
    ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + math.max(0, (avail_w - total_width) / 2))

    -- Защита: берем значение из конфига, если его нет — ставим 7
    local rounding = (adj.config and adj.config.borderRad and adj.config.borderRad.element) or 7

    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, 0, 0)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameRounding, rounding)

    for i = 1, #values do
        local is_active = (adj.config.layouts.value == i)
        local button_color = is_active and adj.config.colors.Selected or adj.config.colors.Input.Background
        local hover_color = is_active and adj.config.colors.Selected or adj.config.colors.Input.Hover

        ImGui.PushStyleColor(ctx, ImGui.Col_Button, button_color)
        ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, hover_color)
        ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, button_color)
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, adj.config.colors.Text)

        if ImGui.Button(ctx, values[i] .. "##sync_layout_" .. i, button_width, button_height) then
            adj.config.layouts.value = i
            need_to_update_values = true
        end

        ImGui.PopStyleColor(ctx, 4)
        if i < #values then ImGui.SameLine(ctx, 0, button_spacing) end
    end

    ImGui.PopStyleVar(ctx, 2)
    ImGui.Dummy(ctx, 0, vertical_margin)
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
					if adj.params[key] then
						adj.SetValue(adj.params[key], value)
					end
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

function adj.ExportParameters()
	local debug = "{ "

	for id, param in pairs(adj.params) do
		local value = adj.GetValue(param, id)
		if value then
			debug = debug .. id .. " = " .. value.value .. ", "
		end
	end

	return debug .. " }"
end

function adj.ShowWindow()
	adj.UpdateValues()

	adj.DrawHeader()
	adj.DrawLayoutsButtons()

	if ImGui.BeginTable(ctx, "sep_tcp_1", 5) then
		ImGui.TableNextRow(ctx)

		ImGui.TableNextColumn(ctx);
		ImGui.TableNextColumn(ctx); adj.ShowParameter(adj.params.fader_color_a)
		ImGui.TableNextColumn(ctx); adj.ShowParameter(adj.params.fader_color_b)
		ImGui.TableNextColumn(ctx); adj.ShowParameter(adj.params.fader_color_c)

		ImGui.EndTable(ctx)
	end

	adj.DrawPresetsSelect()
	ImGui.Spacing(ctx)
	ImGui.Separator(ctx)

	ImGui.PushStyleVar(ctx, ImGui.StyleVar_ScrollbarSize, 14)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_ScrollbarRounding, 12)
	ImGui.PushStyleColor(ctx, ImGui.Col_ScrollbarBg, 0x00000000)
	ImGui.PushStyleColor(ctx, ImGui.Col_ScrollbarGrab, 0x555555ff)

	if ImGui.BeginChild(ctx, "MainContentScroll", 0, -1.0, ImGui.ChildFlags_None) then
		if adj.opened_first_tab == nil then
			ImGui.SetNextItemOpen(ctx, true)
			adj.opened_first_tab = true
		end

		adj.DrawCollapsingHeader('                         TRACK PANEL', function() 
			adj.ShowParameter(adj.params.tcp_solid_color)
			ImGui.Spacing(ctx)

			if ImGui.BeginTable(ctx, "sep_tcp_1", 2) then
				ImGui.TableNextColumn(ctx); adj.ShowParameter(adj.params.tcplabelbrightness)
				ImGui.TableNextColumn(ctx); adj.ShowParameter(adj.params.foldermargin)
				ImGui.EndTable(ctx)
			end

			adj.ShowParameter(adj.params.lnstatemd)
			ImGui.Spacing(ctx)
			adj.ShowParameter(adj.params.fxsidead)
			ImGui.Spacing(ctx)
			adj.ShowParameter(adj.params.tcp_layout)
			ImGui.Spacing(ctx)

			if ImGui.BeginTable(ctx, "sep_tcp_2", 2) then
				ImGui.TableNextColumn(ctx); adj.ShowParameter(adj.params.embed_position)
				ImGui.TableNextColumn(ctx)
				adj.ShowParameter(adj.params.dbscales)
				adj.ShowParameter(adj.params.tcp_folder_recarms)
				adj.ShowParameter(adj.params.min_fxlist)
				ImGui.EndTable(ctx)
			end

			if ImGui.BeginTable(ctx, "sep_tcp_3", 2) then
				ImGui.TableNextColumn(ctx); adj.ShowParameter(adj.params.sendlist)
				ImGui.TableNextColumn(ctx); adj.ShowParameter(adj.params.min_fxlist_sep)
				ImGui.EndTable(ctx)
			end

			if ImGui.BeginTable(ctx, "sep_tcp_4", 2) then
				ImGui.TableNextColumn(ctx); adj.ShowParameter(adj.params.dividercolor)
				ImGui.TableNextColumn(ctx); adj.ShowParameter(adj.params.fxheight)
				ImGui.EndTable(ctx)
			end

			ImGui.Spacing(ctx); adj.ShowParameter(adj.params.meter_position)
			ImGui.Spacing(ctx); adj.ShowParameter(adj.params.tinymode)

			ImGui.Spacing(ctx); ImGui.Spacing(ctx); ImGui.Spacing(ctx)
			ImGui.TextWrapped(ctx, "*in TCP, all pan/width controls are knobs technically, Even that it looks like slider, it works the same as knob")
			ImGui.Spacing(ctx); ImGui.Spacing(ctx)
			ImGui.TextWrapped(ctx, "**Embedded Ul will be shown instead of FX slots only it the option enabled")
			ImGui.Spacing(ctx); ImGui.Spacing(ctx)
			ImGui.TextWrapped(ctx, "***if separated, Sendlist will appear after creating any send")
		end)

		ImGui.Spacing(ctx)

		adj.DrawCollapsingHeader('                          MIXER PANEL', function()
			adj.ShowParameter(adj.params.mcp_solid_color)
			ImGui.Spacing(ctx)
			adj.ShowParameter(adj.params.mixer_folderindent)
			ImGui.Spacing(ctx)
			adj.ShowParameter(adj.params.mcppanslider)
			ImGui.Spacing(ctx)

			if ImGui.BeginTable(ctx, "sep_mcp_1", 2) then
				ImGui.TableNextColumn(ctx); adj.ShowParameter(adj.params.mcp_folder_recarms)
				ImGui.TableNextColumn(ctx); adj.ShowParameter(adj.params.mcpdbscales)
				ImGui.EndTable(ctx)
			end

			ImGui.Spacing(ctx)
			adj.ShowParameter(adj.params.mcp_layout)
			ImGui.Spacing(ctx)
			adj.ShowParameter(adj.params.volumeadj)
		end)

		ImGui.Spacing(ctx)

		adj.DrawCollapsingHeader('                          TRANSPORT', function()
			adj.ShowParameter(adj.params.trans_position)
			ImGui.Spacing(ctx)
			adj.DrawTransportButtonsPanel()
		end)

		ImGui.Spacing(ctx)

		adj.DrawCollapsingHeader('                          ABOUT SCRIPT', function()
			ImGui.PushFont(ctx, adj.getFont(adj.config.font_types.Bold, adj.config.font_size))
			ImGui.Text(ctx, "Cheat Sheet:")
			ImGui.PopFont(ctx)

			adj.ShowParameter(adj.params.gloss)
			ImGui.Spacing(ctx)
			ImGui.Spacing(ctx)
			ImGui.Spacing(ctx)

			ImGui.PushFont(ctx, adj.getFont(adj.config.font_types.Bold, adj.config.font_size))
			ImGui.Text(ctx, "Credits:")
			if ImGui.IsItemClicked(ctx) then
				reaper.ShowConsoleMsg(adj.ExportParameters() .. "\n")
			end
			ImGui.PopFont(ctx)

			ImGui.PushFont(ctx, adj.getFont(adj.config.font_types.None, adj.config.font_size))
			ImGui.TextWrapped(ctx, 'FM4 theme is created by Dmytro Hapochka, theme adjuster is designed by Dmytro Hapochka and developed by Ed Kashinsky.')
			ImGui.Spacing(ctx)
			ImGui.Spacing(ctx)

			if ImGui.BeginTable(ctx, "sep3", 2) then
			ImGui.TableNextColumn(ctx)

			adj.DrawImage(SCRIPT_PATH .. "/img/bmc_qr_hapochka.png", { width = 270, borderRad = 8, border = 2 })
			ImGui.Dummy(ctx, 195, 0)
			adj.CenterText("Support Dmytro Hapochka")

			ImGui.TableNextColumn(ctx)

			adj.DrawImage(SCRIPT_PATH .. "/img/bmc_qr_kashinsky.png", { width = 270, borderRad = 8, border = 2 })
			ImGui.Dummy(ctx, 195, 0)
			adj.CenterText("Support Ed Kashinsky")

			ImGui.EndTable(ctx)
		    end

		ImGui.PopFont(ctx)

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

		ImGui.EndChild(ctx)
	end

	ImGui.PopStyleColor(ctx, 2)
	ImGui.PopStyleVar(ctx, 2)

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