PD.DM = PD.DM or {}
PD.DM.Medication = PD.DM.Medication or {}

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
            -- Accumulate the continuous modifiers
            pulse_mod = pulse_mod + (med.puls or 0)
            spo2_mod = spo2_mod + (med.spo2 or 0)
            bp_mod = bp_mod + (med.bp or 0) -- Assuming BP modifier is a single value for now

            -- Add this active medication to the list we are keeping
            table.insert(medications_to_keep, med)
        else
            -- Medication has EXPIRED
            -- Optional: Call the onExpire function if it exists
            for _, v in ipairs(PD.DM.Medication) do
                if v.name == med.name and v.onExpire and type(v.onExpire) == "function" then
                    v.onExpire(tbl)
                end
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
