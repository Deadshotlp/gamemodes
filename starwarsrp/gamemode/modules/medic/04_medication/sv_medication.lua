PD.DM = PD.DM or {}
PD.DM.Medication = PD.DM.Medication or {}

-- Consider using medication names as keys for easier access and readability
PD.DM.Medication.tbl = {
    ["Aspirin"] = { -- Use name as key
        name = "Aspirin", -- Keep name field if needed
        time = 600, -- Example: 10 minutes duration
        puls = 0, -- Continuous pulse modifier (additive or multiplicative depends on CalculatePuls)
        spo2 = 0, -- Continuous SpO2 modifier (additive)
        bp = 0, -- Continuous BP modifier (additive or multiplicative depends on CalculateBP)
        effect = function(player_tbl, med_data)
            -- This function is called ONCE when the medication is first processed.
            -- Example: Slightly reduce pain level immediately.
            if player_tbl.pain_level then
                player_tbl.pain_level = math.max(0, player_tbl.pain_level - 0.5)
                -- print(player_tbl.name .. " feels slight relief from Aspirin.") -- Debug/Log
            end
        end
        -- Optional: Add an onExpire function if needed
        -- onExpire = function(player_tbl)
        --    print("Aspirin effects wore off for " .. player_tbl.name)
        -- end
    },
    ["Adrenaline"] = {
        name = "Adrenaline",
        time = 120, -- 2 minutes duration
        puls = 0.15, -- Example: +15% pulse modifier (Ensure CalculatePuls handles this)
        spo2 = 0,
        bp = 0.1, -- Example: +10% BP modifier (Ensure CalculateBP handles this)
        effect = function(player_tbl, med_data)
            -- print(player_tbl.name .. " received an Adrenaline shot!")
            -- Could add a temporary effect like faster movement or stamina regen here if needed
        end
    }
    -- Add more medications here...
}

--[[
Adds a medication effect to a player's active medication list.

@param ply Player The player receiving the medication.
@param medication_template table The template data for the medication (e.g., from PD.DM.Medication.tbl).
@return boolean True if successful, false otherwise.
]]
function PD.DM:AddMedication(ply, medication_template)
    -- Validate input template
    if not medication_template or type(medication_template) ~= "table" or not medication_template.name or
        not medication_template.time then
        ErrorNoHalt(string.format("[PD.DM Error] AddMedication: Invalid medication template provided: %s\n",
            vim.inspect(medication_template) or "nil"))
        return false
    end

    -- Request the player's current medication list
    local player_medications = PD.DM:RequestTable(ply, "medication")
    if not player_medications then
        -- This might happen if the player's data wasn't initialized correctly
        ErrorNoHalt("[PD.DM Error] AddMedication: Player medication table not found for " .. ply:Nick() .. "\n")
        return false
    end

    -- Create the entry for the player's active list
    local new_med_entry = {
        name = medication_template.name,
        administered = os.time(),
        time = medication_template.time,
        puls = medication_template.puls or 0, -- Default to 0 if missing
        spo2 = medication_template.spo2 or 0,
        bp = medication_template.bp or 0,
        effect = medication_template.effect, -- Store the function reference
        onExpire = medication_template.onExpire, -- Store optional expire function
        calculated = false -- Flag to track if the initial 'effect' has run
    }

    table.insert(player_medications, new_med_entry)

    -- Update the player's main data table (this should handle networking etc.)
    PD.DM:UpdateTable(ply, "medication", player_medications)
    -- print(string.format("[PD.DM Log] Added %s to %s's medications.", new_med_entry.name, ply:Nick())) -- Debug/Log
    return true
end

--[[
Calculates the combined continuous modifiers from active medications and removes expired ones.

@param tbl table The player's main medical data table.
@return number pulse_modifier, number spo2_modifier, number bp_modifier
]]
function PD.DM:CalculateMedication(tbl)
    local active_medications = tbl["medication"]

    -- Check if the medication list exists and has entries
    if not active_medications or not next(active_medications) then -- 'next' is faster than # for empty check
        return 0, 0, 0 -- No active medications, return zero modifiers
    end

    local pulse_mod, spo2_mod, bp_mod = 0, 0, 0
    local current_time = os.time()
    local medications_to_keep = {} -- Build a new list containing only active medications

    -- Iterate through the current list
    for i = 1, #active_medications do
        local med = active_medications[i]

        -- Check if the medication is still active
        if current_time < med.administered + med.time then
            -- Medication is ACTIVE

            -- Apply the one-time effect function if it hasn't run yet
            if not med.calculated then
                if med.effect and type(med.effect) == "function" then
                    -- Pass the main player table and the specific medication data
                    med.effect(tbl, med)
                end
                med.calculated = true -- Mark initial effect as done
            end

            -- Accumulate the continuous modifiers
            pulse_mod = pulse_mod + (med.puls or 0)
            spo2_mod = spo2_mod + (med.spo2 or 0)
            bp_mod = bp_mod + (med.bp or 0) -- Assuming BP modifier is a single value for now

            -- Add this active medication to the list we are keeping
            table.insert(medications_to_keep, med)
        else
            -- Medication has EXPIRED
            -- Optional: Call the onExpire function if it exists
            if med.onExpire and type(med.onExpire) == "function" then
                med.onExpire(tbl) -- Pass the main player table
            end
            -- Do not add modifiers, do not add to medications_to_keep
            -- print(string.format("[PD.DM Log] %s expired for %s.", med.name, tbl.name or "player")) -- Debug/Log
        end
    end

    -- Replace the player's old medication list with the filtered list of active ones
    tbl["medication"] = medications_to_keep

    -- Return the calculated total modifiers for this update cycle
    return pulse_mod, spo2_mod, bp_mod
end
