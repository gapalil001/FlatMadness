-- @author Dmytro Hapochka
-- @noindex

local STEP = -0.1 
local SPEED = -0.5 
local DELAY = 1 

function db2val(db) return 10^(db/20) end
function val2db(val) return 20*(math.log(val, 10)) end

local start_time = os.clock()
local last_run = os.clock()
local is_first_click = true

function main()
    if reaper.JS_Mouse_GetState then
        if reaper.JS_Mouse_GetState(1) == 0 then return end
    end

    local current_time = os.clock()
    local duration = current_time - start_time
    
    if is_first_click then
        for i = 0, reaper.CountSelectedTracks(0) - 1 do
            local track = reaper.GetSelectedTrack(0, i)
            local vol = reaper.GetMediaTrackInfo_Value(track, "D_VOL")
            local db = val2db(vol)
            reaper.SetMediaTrackInfo_Value(track, "D_VOL", db2val(db + STEP))
        end
        is_first_click = false
    end

    if duration > DELAY then
        local delta_time = current_time - last_run
        local db_to_add = SPEED * delta_time
        for i = 0, reaper.CountSelectedTracks(0) - 1 do
            local track = reaper.GetSelectedTrack(0, i)
            local vol = reaper.GetMediaTrackInfo_Value(track, "D_VOL")
            local db = val2db(vol)
            reaper.SetMediaTrackInfo_Value(track, "D_VOL", db2val(db + db_to_add))
        end
        last_run = current_time
    end
    
    reaper.defer(main)
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Adjust Volume Up", -1)
