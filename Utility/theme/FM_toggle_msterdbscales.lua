-- @author Dmytro Hapochka
-- @noindex

local target_id = 115

local retval, desc, current_val = reaper.ThemeLayout_GetParameter(target_id)

if retval then
    local new_val
    
    if current_val == 0 then
        new_val = 1
    else
        new_val = 0
    end
  
    reaper.ThemeLayout_SetParameter(target_id, new_val, true)
   
    reaper.ThemeLayout_RefreshAll()

    local x, y = reaper.GetMousePosition()
    reaper.TrackCtl_SetToolTip(string.format("Param %d (%s) set to: %d", target_id, desc, new_val), x, y + 20, true)
else
    reaper.MB("Параметр с ID " .. target_id .. " не найден в текущей теме.", "Ошибка", 0)
end
