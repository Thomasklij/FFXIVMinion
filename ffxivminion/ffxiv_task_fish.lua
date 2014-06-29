ffxiv_task_fish = inheritsFrom(ml_task)
ffxiv_task_fish.name = "LT_FISH"

function ffxiv_task_fish.Create()
    local newinst = inheritsFrom(ffxiv_task_fish)
    
    --ml_task members
    newinst.valid = true
    newinst.completed = false
    newinst.subtask = nil
    newinst.auxiliary = false
    newinst.process_elements = {}
    newinst.overwatch_elements = {}
    
    --ffxiv_task_fish members
    newinst.castTimer = 0
    newinst.markerTime = 0
    newinst.currentMarker = false
    newinst.baitName = ""
    newinst.castFailTimer = 0
	newinst.filterLevel = true
    newinst.missingBait = false
    
    return newinst
end

c_cast = inheritsFrom( ml_cause )
e_cast = inheritsFrom( ml_effect )
function c_cast:evaluate()
    local castTimer = ml_task_hub:CurrentTask().castTimer
    if (ml_global_information.Now > castTimer) then
        local fs = tonumber(Player:GetFishingState())
        if (fs == 0 or fs == 4) then
            return true
        end
    end
    return false
end
function e_cast:execute()
    local mooch = ActionList:Get(297,1)
    if (mooch) and Player.level > 24 and (mooch.isready) then
        mooch:Cast()
    else
        local cast = ActionList:Get(289,1)
        if (cast and cast.isready) then			
            cast:Cast()
        end
    end
end

-- Has to get called, else the dude issnot moving thanks to "runforward" usage ;)
c_finishcast = inheritsFrom( ml_cause )
e_finishcast = inheritsFrom( ml_effect )
function c_finishcast:evaluate()
    local castTimer = ml_task_hub:CurrentTask().castTimer
    if (ml_global_information.Now > castTimer) then
        local fs = tonumber(Player:GetFishingState())
        if (fs ~= 0 and c_returntomarker:evaluate()) then
            return true
        end
    end
    return false
end
function e_finishcast:execute()
    local finishcast = ActionList:Get(299,1)
    if (finishcast and finishcast.isready) then
        finishcast:Cast()
    end
end

c_bite = inheritsFrom( ml_cause )
e_bite = inheritsFrom( ml_effect )
function c_bite:evaluate()
    local castTimer = ml_task_hub:CurrentTask().castTimer
    if (ml_global_information.Now > castTimer) then
        local fs = tonumber(Player:GetFishingState())
        if( fs == 5 ) then -- FISHSTATE_BITE
            return true
        end
    end
    return false
end
function e_bite:execute()
    local bite = ActionList:Get(296,1)
    if (bite and bite.isready) then
        bite:Cast()
    end
end

c_setbait = inheritsFrom( ml_cause )
e_setbait = inheritsFrom( ml_effect )
function c_setbait:evaluate()
    if (ml_task_hub:CurrentTask().missingBait) then
        return false
    end
    
    local fs = tonumber(Player:GetFishingState())
    if (fs == 0 or fs == 4) then
        local marker = ml_task_hub:CurrentTask().currentMarker
        if (marker ~= nil and marker ~= false) then
            local baitName = marker:GetFieldValue(strings[gCurrentLanguage].baitName)
            if (baitName ~="None" and baitName ~= ml_task_hub:CurrentTask().baitName) then
                --check to see if we have the bait in inventory
                ml_debug("Looking for bait named "..bait)
                for i = 0,4 do
                    local inventory = Inventory("type="..tostring(i))
                    if (inventory ~= nil and inventory ~= 0) then
                        for _,item in ipairs(inventory) do
                            if item.name == bait then
                                e_setbait.bait = item
								return true
                            end
                        end
                    end
                end
                
                ml_error("Could not find bait! Attempting to use current bait")
                
            end
        end
    end
        
    return false
end
function e_setbait:execute()
    Player:SetBait(e_setbait.item.ID)
    ml_task_hub:CurrentTask().baitName = e_setbait.item.name
end

c_nextfishingmarker = inheritsFrom( ml_cause )
e_nextfishingmarker = inheritsFrom( ml_effect )
function c_nextfishingmarker:evaluate()
    if ( ml_task_hub:CurrentTask().currentMarker ~= nil and ml_task_hub:CurrentTask().currentMarker ~= 0 ) then
        local marker = nil
        
        -- first check to see if we have no initiailized marker
        if (ml_task_hub:CurrentTask().currentMarker == false) then --default init value
            marker = ml_marker_mgr.GetNextMarker(strings[gCurrentLanguage].fishingMarker, ml_task_hub:CurrentTask().filterLevel)
        
			if (marker == nil) then
				ml_task_hub:CurrentTask().filterLevel = false
				marker = ml_marker_mgr.GetNextMarker(strings[gCurrentLanguage].fishingMarker, ml_task_hub:CurrentTask().filterLevel)
			end	
		end
        
        -- next check to see if our level is out of range
        if (marker == nil) then
            if (ValidTable(ml_task_hub:CurrentTask().currentMarker)) then
                if 	(ml_task_hub:CurrentTask().filterLevel) and
					(Player.level < ml_task_hub:CurrentTask().currentMarker:GetMinLevel() or 
                    Player.level > ml_task_hub:CurrentTask().currentMarker:GetMaxLevel()) 
                then
                    marker = ml_marker_mgr.GetNextMarker(ml_task_hub:CurrentTask().currentMarker:GetType(), ml_task_hub:CurrentTask().filterLevel)
                end
            end
        end
        
        -- last check if our time has run out
        if (marker == nil) then
            local time = ml_task_hub:CurrentTask().currentMarker:GetTime()
			if (time and time ~= 0 and TimeSince(ml_task_hub:CurrentTask().markerTime) > time * 1000) then
				--ml_debug("Marker timer: "..tostring(TimeSince(ml_task_hub:CurrentTask().markerTime)) .."seconds of " ..tostring(time)*1000)
                ml_debug("Getting Next Marker, TIME IS UP!")
                marker = ml_marker_mgr.GetNextMarker(ml_task_hub:CurrentTask().currentMarker:GetType(), ml_task_hub:CurrentTask().filterLevel)
            else
                return false
            end
        end
        
        if (ValidTable(marker)) then
            ml_task_hub:CurrentTask().missingBait = false
            e_nextfishingmarker.marker = marker
            return true
        end
    end
    
    return false
end
function e_nextfishingmarker:execute()
    ml_task_hub:CurrentTask().currentMarker = e_nextfishingmarker.marker
    ml_task_hub:CurrentTask().markerTime = ml_global_information.Now
	ml_global_information.MarkerTime = ml_global_information.Now
    ml_global_information.MarkerMinLevel = ml_task_hub:CurrentTask().currentMarker:GetMinLevel()
    ml_global_information.MarkerMaxLevel = ml_task_hub:CurrentTask().currentMarker:GetMaxLevel()
	gStatusMarkerName = ml_task_hub:CurrentTask().currentMarker:GetName()
end

function ffxiv_task_fish:Init()

    --init ProcessOverwatch() cnes
    local ke_dead = ml_element:create( "Dead", c_dead, e_dead, 20 )
    self:add( ke_dead, self.overwatch_elements)
    
    local ke_stealth = ml_element:create( "Stealth", c_stealth, e_stealth, 15 )
    self:add( ke_stealth, self.overwatch_elements)
  
    --init Process() cnes
    local ke_finishcast = ml_element:create( "FinishingCast", c_finishcast, e_finishcast, 30 )
    self:add(ke_finishcast, self.process_elements)
    
    local ke_returnToMarker = ml_element:create( "ReturnToMarker", c_returntomarker, e_returntomarker, 25 )
    self:add( ke_returnToMarker, self.process_elements)
    
    --nextmarker defined in ffxiv_task_gather.lua
    local ke_nextMarker = ml_element:create( "NextMarker", c_nextfishingmarker, e_nextfishingmarker, 20 )
    self:add( ke_nextMarker, self.process_elements)
    
    local ke_setbait = ml_element:create( "SetBait", c_setbait, e_setbait, 10 )
    self:add(ke_setbait, self.process_elements)
    
    local ke_cast = ml_element:create( "Cast", c_cast, e_cast, 5 )
    self:add(ke_cast, self.process_elements)
    
    local ke_bite = ml_element:create( "Bite", c_bite, e_bite, 5 )
    self:add(ke_bite, self.process_elements)
   
    
    self:AddTaskCheckCEs()
end

function ffxiv_task_fish:OnSleep()

end

function ffxiv_task_fish:OnTerminate()

end

function ffxiv_task_fish:IsGoodToAbort()

end

-- UI settings etc
function ffxiv_task_fish.UIInit()
	ffxiv_task_fish.SetupMarkers()
end

function ffxiv_task_fish.SetupMarkers()
    -- add marker templates for fishing
    local fishingMarker = ml_marker:Create("fishingTemplate")
	fishingMarker:SetType(strings[gCurrentLanguage].fishingMarker)
	fishingMarker:AddField("string", strings[gCurrentLanguage].baitName, "")
    fishingMarker:SetTime(300)
    fishingMarker:SetMinLevel(1)
    fishingMarker:SetMaxLevel(50)
    ml_marker_mgr.AddMarkerTemplate(fishingMarker)
	
    -- refresh the manager with the new templates
    ml_marker_mgr.RefreshMarkerTypes()
	ml_marker_mgr.RefreshMarkerNames()
end

function ffxiv_task_fish.GUIVarUpdate(Event, NewVals, OldVals)
    GUI_RefreshWindow(ml_global_information.MainWindow.Name)
end