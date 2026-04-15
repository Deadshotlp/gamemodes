PD.DM = PD.DM or {}
PD.DM.Injury = PD.DM.Injury or {}
PD.DM.Injury.tbl = {
    --[1] = {
    --    name = "",
    --    condition = function(hitgroup, dmgTyp)
    --        if not bit.band(dmgTyp, DMG_BULLET) ~= 0 then
    --            return false
    --        end
    --
    --        return true
    --    end,
    --    onApply = function(tbl)
    --
    --    end,
    --    bypass_armor = false,
    --    needs_desinfication = true,
    --    blading = 0,
    --    pain = 1,
    --    treatment = {
    --        [1] = {
    --            name = "Apply Anticeptin-D",
    --            status = false
    --        },
    --        [2] = {
    --            name = "Apply Bacta Bandage",
    --            status = false
    --        }
    --    }
    --},
    
    [1] = {
        name = "Blaster Streifschuss",
        condition = function(hitgroup, dmgTyp)
            if (bit.band(dmgTyp, DMG_BULLET) == 0 and bit.band(dmgTyp, DMG_PLASMA) == 0) then return false end
            return true
        end,
        onApply = function(tbl)
        end,
        bypass_armor = false,
        needs_desinfication = true,
        bleading_level = 0.0,
        pain_level = 0.25,
        puls_influence = 0.1,
        spo2_influence = 0,
        bp_influence = -0.1,
        healing_time = 180,
        treatment = {"bacta_verband", "enkephalin", "dermasel"}
    },

    [2] = {
        name = "Oberflächiger Blastertreffer",
        condition = function(hitgroup, dmgTyp)
            if (bit.band(dmgTyp, DMG_BULLET) == 0 and bit.band(dmgTyp, DMG_PLASMA) == 0) then return false end
            if hitgroup == HITGROUP_HEAD then return false end

            return true
        end,
        onApply = function(tbl)
        end,
        bypass_armor = false,
        needs_desinfication = true,
        bleading_level = 0.0,
        pain_level = 0.45,
        puls_influence = 0.1,
        spo2_influence = 0,
        bp_influence = -0.1,
        healing_time = 240,
        treatment = {"bacta_verband", "enkephalin", "dermasel"}
    },

    [4] = {
        name = "Blaster Treffer Rumpf Schwer",
        condition = function(hitgroup, dmgTyp)
            if (bit.band(dmgTyp, DMG_BULLET) == 0 and bit.band(dmgTyp, DMG_PLASMA) == 0) then return false end
            if hitgroup ~= HITGROUP_CHEST and hitgroup ~= HITGROUP_STOMACH then return false end

            return true
        end,
        onApply = function(tbl)
            return true
        end,
        bypass_armor = false,
        needs_desinfication = true,
        bleading_level = 0.0,
        pain_level = 0.8,
        puls_influence = 0.2,
        spo2_influence = 0,
        bp_influence = -0.2,
        healing_time = 600,
        treatment = {"bacta_verband", "operativer_eingriff", "enkephalin", "dermasel"}
    },

    [5] = {
        name = "Blaster Kopftreffer",
        condition = function(hitgroup, dmgTyp)
            if (bit.band(dmgTyp, DMG_BULLET) == 0 and bit.band(dmgTyp, DMG_PLASMA) == 0) then return false end
            if hitgroup ~= HITGROUP_HEAD then return false end

            return true
        end,
        onApply = function(tbl)
            return true
        end,
        bypass_armor = false,
        needs_desinfication = true,
        bleading_level = 0.0,
        pain_level = 0.9,
        puls_influence = 0.2,
        spo2_influence = 0,
        bp_influence = -0.2,
        healing_time = 6000,
        treatment = {"bacta_verband", "bacta_tank", "operativer_eingriff", "enkephalin", "dermasel"}
    },

    -- ============================================
    -- QUETSCHUNGEN (DMG_CRUSH = 1)
    -- ============================================

    [6] = {
        name = "Quetschung Leicht",
        condition = function(hitgroup, dmgTyp)
            if bit.band(dmgTyp, DMG_CRUSH) == 0 then return false end

            return true
        end,
        onApply = function(tbl)
        end,
        bypass_armor = false,
        needs_desinfication = false,
        bleading_level = 0.0,
        pain_level = 0.4,
        puls_influence = 0,
        spo2_influence = 0,
        bp_influence = 0,
        healing_time = 180,
        treatment = {"bacta_verband"}
    },

    [7] = {
        name = "Quetschung Schwer",
        condition = function(hitgroup, dmgTyp)
            if bit.band(dmgTyp, DMG_CRUSH) == 0 then return false end

            return true
        end,
        onApply = function(tbl)
        end,
        bypass_armor = true,
        needs_desinfication = false,
        bleading_level = 0.0,
        pain_level = 0.75,
        puls_influence = 0.15,
        spo2_influence = 0,
        bp_influence = -0.2,
        healing_time = 360,
        treatment = {"bacta_verband", "operativer_eingriff"}
    },

    

    -- ============================================
    -- EXPLOSIONEN (DMG_BLAST = 64)
    -- ============================================

    [8] = {
        name = "Splitterverletzung Leicht",
        condition = function(hitgroup, dmgTyp)
            if bit.band(dmgTyp, DMG_BLAST) == 0 then return false end

            return true
        end,
        onApply = function(tbl)
        end,
        bypass_armor = true,
        needs_desinfication = true,
        bleading_level = 0.00008,
        pain_level = 0.25,
        puls_influence = 0.2,
        spo2_influence = 0,
        bp_influence = -0.2,
        healing_time = 6000,
        treatment = {"oberflaechige_splitter_entfernen", "synth_fleisch", "bacta_verband"}
    },

    [9] = {
        name = "Splitterverletzung Schwer",
        condition = function(hitgroup, dmgTyp)
            if bit.band(dmgTyp, DMG_BLAST) == 0 then return false end

            return true
        end,
        onApply = function(tbl)
        end,
        bypass_armor = true,
        needs_desinfication = true,
        bleading_level = 0.0005,
        pain_level = 0.75,
        puls_influence = 0.2,
        spo2_influence = 0,
        bp_influence = -0.2,
        healing_time = 6000,
        treatment = {"bacta_verband", "synth_fleisch", "operativer_eingriff"}
    },

    [45] = {
        name = "Druckwellen Trauma Leicht",
        condition = function(hitgroup, dmgTyp)
            if bit.band(dmgTyp, DMG_BLAST) == 0 then return false end
            if hitgroup ~= HITGROUP_CHEST and hitgroup ~= HITGROUP_STOMACH then return false end
            return true
        end,
        onApply = function(tbl)
        end,
        bypass_armor = true,
        needs_desinfication = false,
        bleading_level = 0.00002,
        pain_level = 0.4,
        puls_influence = 0.2,
        spo2_influence = 0,
        bp_influence = -0.2,
        healing_time = 300,
        treatment = {"bacta_verband", "enkephalin", "dermasel"}
    },
    [46] = {
        name = "Druckwellen Trauma Schwer",
        condition = function(hitgroup, dmgTyp)
            if bit.band(dmgTyp, DMG_BLAST) == 0 then return false end
            if hitgroup ~= HITGROUP_CHEST and hitgroup ~= HITGROUP_STOMACH then return false end
            return true
        end,
        onApply = function(tbl)
        end,
        bypass_armor = true,
        needs_desinfication = false,
        bleading_level = 0.00006,
        pain_level = 0.9,
        puls_influence = 0.2,
        spo2_influence = 0,
        bp_influence = -0.2,
        healing_time = 720,
        treatment = {"bacta_verband", "bacta_tank", "operativer_eingriff", "enkephalin", "dermasel"}
    },

    -- ============================================
    -- SCHNITTVERLETZUNGEN (DMG_SLASH = 4)
    -- ============================================

    [11] = {
        name = "Oberflächlicher Schnitt",
        condition = function(hitgroup, dmgTyp)
            if (bit.band(dmgTyp, DMG_SLASH) == 0 and bit.band(dmgTyp, DMG_BLAST) == 0 and bit.band(dmgTyp, DMG_FALL) == 0) then return false end

            return true
        end,
        onApply = function(tbl)
        end,
        bypass_armor = false,
        needs_desinfication = true,
        bleading_level = 0.00005,
        pain_level = 0.2,
        puls_influence = 0,
        spo2_influence = 0,
        bp_influence = 0,
        healing_time = 180,
        treatment = {"synth_fleisch", "bacta_verband"}
    },

    [12] = {
        name = "Tiefe Schnittwunde",
        condition = function(hitgroup, dmgTyp)
            if (bit.band(dmgTyp, DMG_SLASH) == 0 and bit.band(dmgTyp, DMG_BLAST) == 0) then return false end

            return true
        end,
        onApply = function(tbl)
        end,
        bypass_armor = false,
        needs_desinfication = true,
        bleading_level = 0.0005,
        pain_level = 0.5,
        puls_influence = 0.1,
        spo2_influence = 0,
        bp_influence = -0.1,
        healing_time = 360,
        treatment = {"synth_fleisch", "operativer_eingriff", "bacta_verband"}
    },
    [47] = {
        name = "Tiefe Schnittwunde am Hals",
        condition = function(hitgroup, dmgTyp)
            if (bit.band(dmgTyp, DMG_SLASH) == 0 and bit.band(dmgTyp, DMG_BLAST) == 0) then return false end
            if hitgroup ~= HITGROUP_HEAD then return false end
            return true
        end,
        onApply = function(tbl)
        end,
        bypass_armor = false,
        needs_desinfication = true,
        bleading_level = 0.0005,
        pain_level = 0.65,
        puls_influence = 0.2,
        spo2_influence = 0,
        bp_influence = -0.2,
        healing_time = 420,
        treatment = {"synth_fleisch", "operativer_eingriff", "bacta_verband", "enkephalin", "dermasel"}
    },

    -- ============================================
    -- VERBRENNUNGEN (DMG_BURN = 8)
    -- ============================================

    [13] = {
        name = "Verbrennung 1. Grades",
        condition = function(hitgroup, dmgTyp)
            if (bit.band(dmgTyp, DMG_BURN) == 0 and bit.band(dmgTyp, DMG_BLAST) == 0) then return false end

            return true
        end,
        onApply = function(tbl)
        end,
        bypass_armor = false,
        needs_desinfication = true,
        bleading_level = 0.0,
        pain_level = 0.3,
        puls_influence = 0,
        spo2_influence = 0,
        bp_influence = 0,
        healing_time = 180,
        treatment = {"bacta_verband", "enkephalin", "dermasel"}
    },

    [14] = {
        name = "Verbrennung 2. Grades",
        condition = function(hitgroup, dmgTyp)
            if (bit.band(dmgTyp, DMG_BURN) == 0 and bit.band(dmgTyp, DMG_BLAST) == 0) then return false end

            return true
        end,
        onApply = function(tbl)
        end,
        bypass_armor = false,
        needs_desinfication = true,
        bleading_level = 0.0,
        pain_level = 0.6,
        puls_influence = 0.1,
        spo2_influence = 0,
        bp_influence = -0.1,
        healing_time = 300,
        treatment = {"bacta_verband", "enkephalin", "dermasel"}
    },

    [15] = {
        name = "Verbrennung 3. Grades",
        condition = function(hitgroup, dmgTyp)
            if (bit.band(dmgTyp, DMG_BURN) == 0 and bit.band(dmgTyp, DMG_BLAST) == 0) then return false end

            return true
        end,
        onApply = function(tbl)
        end,
        bypass_armor = true,
        needs_desinfication = true,
        bleading_level = 0.0,
        pain_level = 0.9,
        puls_influence = 0.2,
        spo2_influence = 0,
        bp_influence = -0.2,
        healing_time = 600,
        treatment = {"bacta_verband", "bacta_tank", "operativer_eingriff", "enkephalin", "dermasel"}
    },

    -- ============================================
    -- STUMPFES TRAUMA (DMG_CLUB = 128)
    -- ============================================

    [16] = {
        name = "Prellung",
        condition = function(hitgroup, dmgTyp)
            if (bit.band(dmgTyp, DMG_CLUB) == 0 and bit.band(dmgTyp, DMG_FALL) == 0 and bit.band(dmgTyp, DMG_BLAST) == 0 and bit.band(dmgTyp, DMG_VEHICLE) == 0) then return false end

            return true
        end,
        onApply = function(tbl)
        end,
        bypass_armor = false,
        needs_desinfication = false,
        bleading_level = 0.0,
        pain_level = 0.3,
        puls_influence = 0,
        spo2_influence = 0,
        bp_influence = 0,
        healing_time = 180,
        treatment = {"bacta_verband"}
    },

    [17] = {
        name = "Gehirnerschütterung Leicht",
        condition = function(hitgroup, dmgTyp)
            if (bit.band(dmgTyp, DMG_CLUB) == 0 and bit.band(dmgTyp, DMG_FALL) == 0 and bit.band(dmgTyp, DMG_BLAST) == 0 and bit.band(dmgTyp, DMG_VEHICLE) == 0) then return false end
            if hitgroup ~= HITGROUP_HEAD then return false end

            return true
        end,
        onApply = function(tbl)
            return true
        end,
        bypass_armor = false,
        needs_desinfication = false,
        bleading_level = 0,
        pain_level = 0.5,
        puls_influence = 0,
        spo2_influence = 0,
        bp_influence = 0,
        healing_time = 420,
        treatment = {"bacta_verband"}
    },

    [18] = {
        name = "Gehirnerschütterung Schwer",
        condition = function(hitgroup, dmgTyp)
            if (bit.band(dmgTyp, DMG_CLUB) == 0 and bit.band(dmgTyp, DMG_FALL) == 0 and bit.band(dmgTyp, DMG_BLAST) == 0 and bit.band(dmgTyp, DMG_VEHICLE) == 0) then return false end
            if hitgroup ~= HITGROUP_HEAD then return false end

            return true
        end,
        onApply = function(tbl)
            return true
        end,
        bypass_armor = false,
        needs_desinfication = false,
        bleading_level = 0,
        pain_level = 0.8,
        puls_influence = 0.2,
        spo2_influence = 0,
        bp_influence = -0.2,
        healing_time = 600,
        treatment = {"bacta_verband", "bacta_tank"}
    },

    [19] = {
        name = "Rippenbruch Einfach",
        condition = function(hitgroup, dmgTyp)
            if (bit.band(dmgTyp, DMG_FALL) == 0 and bit.band(dmgTyp, DMG_BLAST) == 0 and bit.band(dmgTyp, DMG_CLUB) == 0 and bit.band(dmgTyp, DMG_VEHICLE) == 0) then return false end
            if hitgroup ~= HITGROUP_CHEST and hitgroup ~= HITGROUP_STOMACH then return false end

            return true
        end,
        onApply = function(tbl)
        end,
        bypass_armor = false,
        needs_desinfication = false,
        bleading_level = 0,
        pain_level = 0.8,
        puls_influence = 0.2,
        spo2_influence = 0,
        bp_influence = -0.2,
        healing_time = 600,
        treatment = {"bacta_verband", "bonemer"}
    },

    [20] = {
        name = "Rippenbruch Kompliziert",
        condition = function(hitgroup, dmgTyp)
            if (bit.band(dmgTyp, DMG_FALL) == 0 and bit.band(dmgTyp, DMG_BLAST) == 0 and bit.band(dmgTyp, DMG_CLUB) == 0 and bit.band(dmgTyp, DMG_VEHICLE) == 0) then return false end
            if hitgroup ~= HITGROUP_CHEST and hitgroup ~= HITGROUP_STOMACH then return false end

            return true
        end,
        onApply = function(tbl)
        end,
        bypass_armor = false,
        needs_desinfication = false,
        bleading_level = 0,
        pain_level = 0.75,
        puls_influence = 0,
        spo2_influence = 0,
        bp_influence = -0,
        healing_time = 600,
        treatment = {"bacta_verband", "operativer_eingriff", "bonemer"}
    },

    

    -- ============================================
    -- ELEKTRISCH (DMG_SHOCK = 256)
    -- ============================================

    [21] = {
        name = "Elektrische Verbrennung Leicht",
        condition = function(hitgroup, dmgTyp)
            if bit.band(dmgTyp, DMG_SHOCK) == 0 then return false end

            return true
        end,
        onApply = function(tbl)
        end,
        bypass_armor = true,
        needs_desinfication = false,
        bleading_level = 0.0,
        pain_level = 0.6,
        puls_influence = 0.2,
        spo2_influence = 0,
        bp_influence = -0.2,
        healing_time = 180,
        treatment = {"bacta_verband", "enkephalin", "dermasel"}
    },

    [22] = {
        name = "Elektrische Verbrennung Schwer",
        condition = function(hitgroup, dmgTyp)
            if bit.band(dmgTyp, DMG_SHOCK) == 0 then return false end
            if hitgroup ~= HITGROUP_CHEST and hitgroup ~= HITGROUP_STOMACH and hitgroup ~= HITGROUP_HEAD then return false end
            return true
        end,
        onApply = function(tbl)
        end,
        bypass_armor = true,
        needs_desinfication = false,
        bleading_level = 0.0,
        pain_level = 0.85,
        puls_influence = 0.2,
        spo2_influence = 0,
        bp_influence = -0.2,
        healing_time = 300,
        treatment = {"bacta_verband", "bacta_tank", "enkephalin", "dermasel"}
    },

    -- ============================================
    -- ENERGIE WAFFEN (DMG_ENERGYBEAM = 1024) TODO: Muss erst mit den Lichtschwerteren Getestet werden
    -- ============================================

    -- [23] = {
    --     name = "Lichtschwert Streifverletzung",
    --     condition = function(hitgroup, dmgTyp)
    --         if not (bit.band(dmgTyp, DMG_ENERGYBEAM) ~= 0) then return false end
    --         return true
    --     end,
    --     onApply = function(tbl)
    --     end,
    --     bypass_armor = true,
    --     needs_desinfication = true,
    --     bleading_level = 0.0,
    --     pain_level = 0.5,
    --     puls_influence = 0.1,
    --     spo2_influence = 0,
    --     bp_influence = -0.1,
    --     healing_time = 480,
    --     treatment = {"bacta_verband", "enkephalin", "dermasel"}
    -- },

    -- [24] = {
    --     name = "Lichtschwert Tiefer Schnitt",
    --     condition = function(hitgroup, dmgTyp)
    --         if not (bit.band(dmgTyp, DMG_ENERGYBEAM) ~= 0) then return false end
    --         return hitgroup == HITGROUP_CHEST or hitgroup == HITGROUP_STOMACH
    --     end,
    --     onApply = function(tbl)
    --     end,
    --     bypass_armor = true,
    --     needs_desinfication = true,
    --     bleading_level = 0,
    --     pain_level = 0.9,
    --     puls_influence = 0.2,
    --     spo2_influence = 0,
    --     bp_influence = -0.2,
    --     healing_time = 480,
    --     treatment = {"bacta_verband", "operativer_eingriff", "enkephalin", "dermasel"}
    -- },

    -- [25] = {
    --     name = "Amputation Hand",
    --     condition = function(hitgroup, dmgTyp)
    --         if not (bit.band(dmgTyp, DMG_ENERGYBEAM) ~= 0 or bit.band(dmgTyp, DMG_SLASH) ~= 0 or bit.band(dmgTyp, DMG_BLAST) ~= 0) then return false end
    --         return hitgroup == HITGROUP_LEFTARM or hitgroup == HITGROUP_RIGHTARM
    --     end,
    --     onApply = function(tbl)
    --     end,
    --     bypass_armor = true,
    --     needs_desinfication = true,
    --     bleading_level = 0.01,
    --     pain_level = 0.95,
    --     puls_influence = 0.2,
    --     spo2_influence = 0,
    --     bp_influence = -0.2,
    --     healing_time = 600,
    --     treatment = {"synth_fleisch", "bacta_verband", "operativer_eingriff", "prothese_anbauen", "enkephalin", "dermasel"}
    -- },

    -- [26] = {
    --     name = "Amputation Unterarm",
    --     condition = function(hitgroup, dmgTyp)
    --         if not (bit.band(dmgTyp, DMG_ENERGYBEAM) ~= 0 or bit.band(dmgTyp, DMG_SLASH) ~= 0 or bit.band(dmgTyp, DMG_BLAST) ~= 0) then return false end
    --         return hitgroup == HITGROUP_LEFTARM or hitgroup == HITGROUP_RIGHTARM
    --     end,
    --     onApply = function(tbl)
    --     end,
    --     bypass_armor = true,
    --     needs_desinfication = true,
    --     bleading_level = 0.05,
    --     pain_level = 1.0,
    --     puls_influence = 0.2,
    --     spo2_influence = 0,
    --     bp_influence = -0.2,
    --     healing_time = 720,
    --     treatment = {"synth_fleisch", "bacta_verband", "operativer_eingriff", "prothese_anbauen", "enkephalin", "dermasel"}
    -- },

    -- [27] = {
    --     name = "Lichtschwert Kopfamputation",
    --     condition = function(hitgroup, dmgTyp)
    --         if not (bit.band(dmgTyp, DMG_ENERGYBEAM) ~= 0) then return false end
    --         return hitgroup == HITGROUP_HEAD
    --     end,
    --     onApply = function(tbl)
    --     end,
    --     bypass_armor = true,
    --     needs_desinfication = true,
    --     bleading_level = 1.0,
    --     pain_level = 1.0,
    --     puls_influence = 4.0,
    --     spo2_influence = 0,
    --     bp_influence = -4.0,
    --     healing_time = 999999,
    --     treatment = {}
    -- },

    -- [48] = {
    --     name = "Amputation Fuß",
    --     condition = function(hitgroup, dmgTyp)
    --         if not (bit.band(dmgTyp, DMG_ENERGYBEAM) ~= 0 or bit.band(dmgTyp, DMG_SLASH) ~= 0 or bit.band(dmgTyp, DMG_BLAST) ~= 0) then return false end
    --         return hitgroup == HITGROUP_LEFTLEG or hitgroup == HITGROUP_RIGHTLEG
    --     end,
    --     onApply = function(tbl)
    --     end,
    --     bypass_armor = true,
    --     needs_desinfication = true,
    --     bleading_level = 0.01,
    --     pain_level = 0.95,
    --     puls_influence = 0.2,
    --     spo2_influence = 0,
    --     bp_influence = -0.2,
    --     healing_time = 600,
    --     treatment = {"synth_fleisch", "bacta_verband", "operativer_eingriff", "prothese_anbauen", "enkephalin", "dermasel"}
    -- },

    -- [49] = {
    --     name = "Amputation Unterschenkel",
    --     condition = function(hitgroup, dmgTyp)
    --         if not (bit.band(dmgTyp, DMG_ENERGYBEAM) ~= 0 or bit.band(dmgTyp, DMG_SLASH) ~= 0 or bit.band(dmgTyp, DMG_BLAST) ~= 0) then return false end
    --         return hitgroup == HITGROUP_LEFTLEG or hitgroup == HITGROUP_RIGHTLEG
    --     end,
    --     onApply = function(tbl)
    --     end,
    --     bypass_armor = true,
    --     needs_desinfication = true,
    --     bleading_level = 0.05,
    --     pain_level = 1.0,
    --     puls_influence = 0.2,
    --     spo2_influence = 0,
    --     bp_influence = -0.2,
    --     healing_time = 720,
    --     treatment = {"synth_fleisch", "bacta_verband", "operativer_eingriff", "prothese_anbauen"}
    -- },

    -- ============================================
    -- STURZ (DMG_FALL = 32)
    -- ============================================

    

    [28] = {
        name = "Knochenbruch Einfach",
        condition = function(hitgroup, dmgTyp)
            if (bit.band(dmgTyp, DMG_FALL) == 0 and bit.band(dmgTyp, DMG_VEHICLE) == 0) then return false end
            if hitgroup == HITGROUP_CHEST or hitgroup == HITGROUP_STOMACH or hitgroup == HITGROUP_HEAD then return false end

            return true
        end,
        onApply = function(tbl)
        end,
        bypass_armor = true,
        needs_desinfication = false,
        bleading_level = 0.0,
        pain_level = 0.8,
        puls_influence = 0,
        spo2_influence = 0,
        bp_influence = 0,
        healing_time = 600,
        treatment = {"bacta_verband", "schienung", "bonemer"}
    },

    [29] = {
        name = "Knochenbruch Kompliziert",
        condition = function(hitgroup, dmgTyp)
            if (bit.band(dmgTyp, DMG_FALL) == 0 and bit.band(dmgTyp, DMG_VEHICLE) == 0) then return false end
            if hitgroup == HITGROUP_CHEST or hitgroup == HITGROUP_STOMACH or hitgroup == HITGROUP_HEAD then return false end

            return true
        end,
        onApply = function(tbl)
        end,
        bypass_armor = true,
        needs_desinfication = false,
        bleading_level = 0.0,
        pain_level = 0.8,
        puls_influence = 0.2,
        spo2_influence = 0,
        bp_influence = -0.2,
        healing_time = 600,
        treatment = {"bacta_verband", "schienung", "operativer_eingriff", "bonemer"}
    },

    [30] = {
        name = "Knochenbruch Offen",
        condition = function(hitgroup, dmgTyp)
            if (bit.band(dmgTyp, DMG_FALL) == 0 and bit.band(dmgTyp, DMG_VEHICLE) == 0) then return false end
            if hitgroup == HITGROUP_CHEST or hitgroup == HITGROUP_STOMACH or hitgroup == HITGROUP_HEAD then return false end

            return true
        end,
        onApply = function(tbl)
        end,
        bypass_armor = true,
        needs_desinfication = true,
        bleading_level = 0.001,
        pain_level = 0.9,
        puls_influence = 0.2,
        spo2_influence = 0,
        bp_influence = -0.2,
        healing_time = 600,
        treatment = {"bacta_verband", "schienung", "synth_fleisch", "operativer_eingriff", "bonemer"}
    },

    [31] = {
        name = "Wirbelsäulenverletzung",
        condition = function(hitgroup, dmgTyp)
            if (bit.band(dmgTyp, DMG_FALL) == 0 and bit.band(dmgTyp, DMG_VEHICLE) == 0) then return false end
            if hitgroup ~= HITGROUP_CHEST and hitgroup ~= HITGROUP_STOMACH then return false end

            return true
        end,
        onApply = function(tbl)
        end,
        bypass_armor = true,
        needs_desinfication = false,
        bleading_level = 0.0,
        pain_level = 0.9,
        puls_influence = 0.2,
        spo2_influence = 0,
        bp_influence = -0.2,
        healing_time = 600,
        treatment = {"bacta_verband", "operativer_eingriff"}
    },

    -- ============================================
    -- GIFT (DMG_POISON = 131072) TODO: Vileicht später nochmal eine besseres System einbauen
    -- ============================================

    [32] = {
        name = "Leichte Vergiftung",
        condition = function(hitgroup, dmgTyp)
            if bit.band(dmgTyp, DMG_POISON) == 0 then return false end
            if hitgroup ~= HITGROUP_CHEST and hitgroup ~= HITGROUP_STOMACH then return false end

            return true
        end,
        onApply = function(tbl)
        end,
        bypass_armor = true,
        needs_desinfication = false,
        bleading_level = 0.0,
        pain_level = 0.4,
        puls_influence = 0.2,
        spo2_influence = 0,
        bp_influence = -0.2,
        healing_time = 240,
        treatment = {"gasbinder"}
    },

    [33] = {
        name = "Schwere Vergiftung",
        condition = function(hitgroup, dmgTyp)
            if bit.band(dmgTyp, DMG_POISON) == 0 then return false end
            if hitgroup ~= HITGROUP_CHEST and hitgroup ~= HITGROUP_STOMACH then return false end

            return true 
        end,
        onApply = function(tbl)
            return true -- Wenn die verletzung im anschluss entfernt werden soll
        end,
        bypass_armor = true,
        needs_desinfication = false,
        bleading_level = 0,
        pain_level = 0.7,
        puls_influence = 0.4,
        spo2_influence = 0,
        bp_influence = -0.4,
        healing_time = 600,
        treatment = {"gasbinder"}
    },

    -- ============================================
    -- SÄURE (DMG_ACID = 1048576)
    -- ============================================

    [34] = {
        name = "Säureverätzung Leicht",
        condition = function(hitgroup, dmgTyp)
            if bit.band(dmgTyp, DMG_ACID) == 0 then return false end

            return true
        end,
        onApply = function(tbl)
        end,
        bypass_armor = false,
        needs_desinfication = true,
        bleading_level = 0.0,
        pain_level = 0.8,
        puls_influence = 0.1,
        spo2_influence = 0,
        bp_influence = -0.1,
        healing_time = 360,
        treatment = {"bacta_verband", "enkephalin", "dermasel"}
    },

    [35] = {
        name = "Säureverätzung Schwer",
        condition = function(hitgroup, dmgTyp)
            if bit.band(dmgTyp, DMG_ACID) == 0 then return false end

            return true
        end,
        onApply = function(tbl)
        end,
        bypass_armor = false,
        needs_desinfication = true,
        bleading_level = 0.0,
        pain_level = 0.9,
        puls_influence = 0.5,
        spo2_influence = 0,
        bp_influence = -0.45,
        healing_time = 480,
        treatment = {"bacta_verband", "bacta_tank", "operativer_eingriff", "enkephalin", "dermasel"}
    },

    -- ============================================
    -- NERVENGAS (DMG_NERVEGAS = 65536) TODO: Muss ich nochmal schauen wass ich da genau machen
    -- ============================================

    -- [36] = {
    --     name = "Nervengas Exposition Leicht",
    --     condition = function(hitgroup, dmgTyp)
    --         if not (bit.band(dmgTyp, DMG_NERVEGAS) ~= 0) then return false end
    --         return true
    --     end,
    --     onApply = function(tbl)
    --     end,
    --     bypass_armor = true,
    --     needs_desinfication = false,
    --     bleading_level = 0.0,
    --     pain_level = 0.6,
    --     puls_influence = 0.8,
    --     spo2_influence = 0,
    --     bp_influence = -0.7,
    --     healing_time = 540,
    --     treatment = {"gasbinder"}
    -- },

    -- [37] = {
    --     name = "Nervengas Exposition Schwer",
    --     condition = function(hitgroup, dmgTyp)
    --         if not (bit.band(dmgTyp, DMG_NERVEGAS) ~= 0) then return false end
    --         return true
    --     end,
        -- onApply = function(tbl)
        --     return true -- Wenn die verletzung im anschluss entfernt werden soll
        -- end,
    --     bypass_armor = true,
    --     needs_desinfication = false,
    --     bleading_level = 0.0,
    --     pain_level = 0.7,
    --     puls_influence = 0.4,
    --     spo2_influence = 0,
    --     bp_influence = -0.4,
    --     healing_time = 600,
    --     treatment = {"gasbinder", "bacta_tank"}
    -- },

    -- ============================================
    -- STRAHLUNG (DMG_RADIATION = 262144) TODO: Mit Implementierung eines besseren Strahlungssystems aktivieren
    -- ============================================

    -- [38] = {
    --     name = "Strahlenvergiftung Leicht",
    --     condition = function(hitgroup, dmgTyp)
    --         if not (bit.band(dmgTyp, DMG_RADIATION) ~= 0) then return false end
    --         return true
    --     end,
    --     onApply = function(tbl)
    --     end,
    --     bypass_armor = true,
    --     needs_desinfication = false,
    --     bleading_level = 0.0,
    --     pain_level = 0.5,
    --     puls_influence = 0.3,
    --     spo2_influence = 0,
    --     bp_influence = -0.35,
    --     healing_time = 420,
    --     treatment = {"anti_strahlung_pille"}
    -- },

    -- [39] = {
    --     name = "Strahlenvergiftung Schwer",
    --     condition = function(hitgroup, dmgTyp)
    --         if not (bit.band(dmgTyp, DMG_RADIATION) ~= 0) then return false end
    --         return true
    --     end,
    --    onApply = function(tbl)
    --        return true -- Wenn die verletzung im anschluss entfernt werden soll
    --    end,
    --     bypass_armor = true,
    --     needs_desinfication = false,
    --     bleading_level = 0.0,
    --     pain_level = 0.8,
    --     puls_influence = 0.7,
    --     spo2_influence = 0,
    --     bp_influence = -0.65,
    --     healing_time = 720,
    --     treatment = {"anti_strahlung_pille"}
    -- },

    -- [40] = {
    --     name = "Strahlenverbrennung Leicht",
    --     condition = function(hitgroup, dmgTyp)
    --         if not (bit.band(dmgTyp, DMG_RADIATION) ~= 0) then return false end
    --         return true
    --     end,
    --     onApply = function(tbl)
    --     end,
    --     bypass_armor = true,
    --     needs_desinfication = false,
    --     bleading_level = 0.0,
    --     pain_level = 0.6,
    --     puls_influence = 0.3,
    --     spo2_influence = 0,
    --     bp_influence = -0.2,
    --     healing_time = 360,
    --     treatment = {"bacta_verband", "enkephalin", "dermasel"}
    -- },

    -- [41] = {
    --     name = "Strahlenverbrennung Schwer",
    --     condition = function(hitgroup, dmgTyp)
    --         if not (bit.band(dmgTyp, DMG_RADIATION) ~= 0) then return false end
    --         return true
    --     end,
    --     onApply = function(tbl)
    --     end,
    --     bypass_armor = true,
    --     needs_desinfication = false,
    --     bleading_level = 0.0,
    --     pain_level = 0.85,
    --     puls_influence = 0.25,
    --     spo2_influence = 0,
    --     bp_influence = -0.4,
    --     healing_time = 540,
    --     treatment = {"bacta_verband", "enkephalin", "dermasel", "bacta_tank"}
    -- },
}

PD.DM.Injury.custom_tbl = {

    [1] = {
        name = "Betäubung Leicht",
        condition = function(hitgroup, dmgTyp)
            if not (dmgTyp == 1) then return false end
            return true
        end,
        onApply = function(tbl)
            tbl.stunning_level = math.Clamp((tbl.stunning_level + 0.05), 0, 1)
            return true
        end,
        bypass_armor = true,
        needs_desinfication = false,
        bleading_level = 0,
        pain_level = 0,
        puls_influence = 0,
        spo2_influence = 0,
        bp_influence = 0,
        healing_time = 0,
        treatment = {}
    },
    [2] = {
        name = "Betäubung Mittel",
        condition = function(hitgroup, dmgTyp)
            if not (dmgTyp == 2) then return false end
            return true
        end,
        onApply = function(tbl)
            tbl.stunning_level = math.Clamp((tbl.stunning_level + 0.1), 0, 1)
            return true
        end,
        bypass_armor = true,
        needs_desinfication = false,
        bleading_level = 0,
        pain_level = 0,
        puls_influence = 0,
        spo2_influence = 0,
        bp_influence = 0,
        healing_time = 0,
        treatment = {}
    },
    [3] ={
        name = "Betäubung Stark",
        condition = function(hitgroup, dmgTyp)
            if not (dmgTyp == 3) then return false end
            return true
        end,
        onApply = function(tbl)
            tbl.stunning_level = math.Clamp((tbl.stunning_level + 0.5), 0, 1)
            return true -- Wenn die verletzung im anschluss entfernt werden soll
        end,
        bypass_armor = true,
        needs_desinfication = false,
        bleading_level = 0,
        pain_level = 0,
        puls_influence = 0,
        spo2_influence = 0,
        bp_influence = 0,
        healing_time = 0,
        treatment = {}
    },
}

local punkte = {
    {
    x = 100,
    y = 3
    }, 
    {
    x = 75,
    y = 17
    }, 
    {
    x = 50,
    y = 37
    }, 
    {
    x = 25,
    y = 69
    }, 
    {
    x = 0,
    y = 99
    }
}

-- https://docs.google.com/document/d/1FMGeQtCjmIfhwUJ6MItAneQauIpXqoIUE2xyPdc_8bQ/edit?usp=sharing

hook.Add("EntityTakeDamage", "DM.Injury", function(target, dmg)
    if target:GetClass() == "prop_ragdoll" then
        target = target:GetNW2Entity("PD.DM.RagdollOwner")
    end

    local attacker = dmg:GetAttacker()

    if not target:IsPlayer() then
        return
    end

    if target:HasGodMode() then
        return false
    end

    if attacker and attacker:IsValid() and attacker:IsPlayer() then
        target:SetNW2String("PD.DM.LastHitBy", attacker:Nick())
    end

    local hitGroup = target:LastHitGroup()

    if hitGroup == 0 then
        hitGroup = math.random(1, 7)
    end

    if attacker:GetActiveWeapon() == nil then
        return
    end

    local wep = attacker:GetActiveWeapon()
    if IsValid(wep) and wep.ArcCW then 
        local attachments = wep.Attachments
        if attachments then
            for slot, slotData in pairs(attachments) do
                if slotData.Installed == "ammo_low_btm" then
                    dmg:SetDamageCustom(1)
                elseif slotData.Installed == "ammo_mid_btm" then
                    dmg:SetDamageCustom(2)
                elseif slotData.Installed == "ammo_high_btm" then
                    dmg:SetDamageCustom(3)
                end
            end
        end
    end

    if dmg:GetDamageCustom() == 0 then
        local injury_count = math.floor(dmg:GetDamage() / 20) + 1

        for x = 1, injury_count do
            PD.DM:GetPossibleInjuries(target, hitGroup, dmg:GetDamageType(), PD.DM.Injury.tbl)
        end
    else
        PD.DM:GetPossibleInjuries(target, hitGroup, dmg:GetDamageCustom(), PD.DM.Injury.custom_tbl)
    end

    dmg:SetDamage(0)

    return false
end)

local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[deepcopy(orig_key)] = deepcopy(orig_value) -- Rekursiv für verschachtelte Tabellen
        end
    else -- number, string, boolean, nil, function etc.
        copy = orig
    end
    return copy
end

-- function PD.DM:CheckForArmor(ply, dmg, hitGroup)
--     if hitGroup == 1 and ply:PDGetArmor().helm then
--         PD.Armor:CalculateArmor(ply, dmg, "helm")
--         return ply:PDGetArmor().helm
--     elseif (hitGroup >= 2 and hitGroup) <= 5 and ply:PDGetArmor().panzer then
--         PD.Armor:CalculateArmor(ply, dmg, "panzer")
--         return ply:PDGetArmor().panzer
--     elseif (hitGroup == 6 or hitGroup == 7) and ply:PDGetArmor().beine then
--         PD.Armor:CalculateArmor(ply, dmg, "beine")
--         return ply:PDGetArmor().beine
--     else
--         return nil
--     end
-- end

function PD.DM:GetPossibleInjuries(ply, hitGroup, dmgtype, tbl)
    local probabil_injury = {}
    for k, v in pairs(tbl) do
        if type(v) == "table" and v["condition"] and type(v["condition"]) == "function" then
            if v["condition"](hitGroup, dmgtype) then
                table.insert(probabil_injury, v)
            end
        end
    end
    if probabil_injury[1] ~= nil then
        local rand_1 = math.random(1, #probabil_injury)

        local armor

        if probabil_injury[rand_1].bypass_armor then
            armor = nil
        else
            armor = 65 --armor = PD.DM:CheckForArmor(ply, dmg, hitGroup)
        end

        if isnumber(armor) then
            local threshold = PD.LinearInterpolation(armor, punkte)
            local rand_2 = math.random(0, 100)

            if rand_2 < threshold then
                PD.DM:AddInjury(ply, probabil_injury[rand_1], hitGroup)
            end

            return
        end
        PD.DM:AddInjury(ply, probabil_injury[rand_1], hitGroup)
    end
end

function PD.DM:AddInjury(ply, tbl, hitGroup)
    if tbl.onApply(PD.DM.Main.tbl[ply:SteamID64()]) then
        return
    end

    local inj = PD.DM:RequestTable(ply, "injuries")

    local instance = deepcopy(tbl)

    local id = {
        name = instance.name,
        wo = hitGroup,
        needs_desinfication = instance.needs_desinfication,
        bleading_level = instance.bleading_level,
        pain_level = instance.pain_level,
        treatment = instance.treatment,
        puls_influence = instance.puls_influence,
        spo2_influence = instance.spo2_influence,
        bp_influence = instance.bp_influence,
        healing_time = instance.healing_time,
        calculated = false
    }

    table.insert(inj, id)

    PD.DM:UpdateTable(ply, "injuries", inj)
end

function PD.DM:CalculateInjuries(tbl)
    -- Stelle sicher, dass die notwendigen Tabellen existieren
    if not tbl or not tbl.injuries or not tbl.body_part then
        PD.LOGS.Add("[MEDIC]", "CalculateInjuries: Fehlende Spielerdaten!", Color(255, 255, 255))
        return
    end

    -- Initialisiere numerische Werte, falls sie fehlen
    tbl.pain_level = (type(tbl.pain_level) == "number") and tbl.pain_level or 0
    tbl.blood_amount = (type(tbl.blood_amount) == "number") and tbl.blood_amount or 5.5 -- Standard-Blutmenge

    local injuries = tbl.injuries
    local body_parts = tbl.body_part
    local total_bleeding_this_update = 0
    local pulse_mod, spo2_mod, bp_mod = 0, 0, 0

    -- --- Erste Schleife: Einmalige Effekte neuer Verletzungen anwenden ---
    for k, injury in pairs(injuries) do
        pulse_mod = pulse_mod + (injury.puls_influence or 0)
        spo2_mod = spo2_mod + (injury.spo2_influence or 0)
        bp_mod = bp_mod + (injury.bp_influence or 0)

        -- Stelle sicher, dass die Verletzung einen gültigen Körperteil referenziert
        local body_part_index = injury.wo
        local target_body_part = body_parts[body_part_index]

        injury.healing_time = injury.healing_time - 1
        if injury.healing_time <= 0 then
            injuries[k] = nil
            continue
        end

        if not target_body_part then
            continue
        end

        -- Wende initiale Effekte nur an, wenn die Verletzung noch nicht berechnet wurde
        if not injury.calculated then
            
            -- Füge die Blutungsrate der Verletzung zur Blutungsrate des Körperteils hinzu
            if injury.bleading_level and injury.bleading_level > 0 then
                -- Initialisiere die Blutungsrate des Körperteils, falls sie nicht existiert
                target_body_part.bleading_level = (type(target_body_part.bleading_level) == "number") and target_body_part.bleading_level or 0
                target_body_part.bleading_level = target_body_part.bleading_level + injury.bleading_level
                -- target_body_part.bleed = true -- Nicht wirklich nötig, da bleading_level > 0 dies impliziert
            end

            -- Füge den Schmerz der Verletzung zum Gesamtschmerz des Spielers hinzu
            if injury.pain_level and injury.pain_level > 0 then
                tbl.pain_level = tbl.pain_level + injury.pain_level
            end

            -- Markiere die Verletzung als berechnet, damit diese Effekte nicht erneut angewendet werden
            injury.calculated = true
        end

        -- --- Kontinuierliche Effekte (bei jedem Update prüfen) ---

        -- Prüfe auf Infektionsrisiko (dies geschieht bei jedem Update für relevante Verletzungen)
        if injury.needs_desinfication then
            -- TODO: Überprüfen, ob AddInfactions korrekt mit wiederholten Aufrufen umgeht
            -- oder ob hier eine Wahrscheinlichkeitsprüfung/einmalige Auslösung besser wäre.
            PD.DM:AddInfactions(tbl, injury) -- Übergibt optional Verletzungsdaten
        end
    end

    -- --- Zweite Schleife: Kontinuierlichen Blutverlust berechnen ---
    -- Iteriere durch alle Körperteile, um den Gesamtblutverlust zu ermitteln
    for i = 1, #body_parts do
        local part = body_parts[i]
        -- Prüfe, ob der Körperteil existiert, blutet und kein Tourniquet angelegt ist
        if part and part.bleading_level and part.bleading_level > 0 and not part.tourniquet then
            total_bleeding_this_update = total_bleeding_this_update + (part.bleading_level * (tbl.puls / 10 + 1))
        end
    end

    -- Wende den berechneten Gesamtblutverlust auf das Blutvolumen des Spielers an
    if total_bleeding_this_update > 0 then
        tbl.blood_amount = tbl.blood_amount - total_bleeding_this_update
        -- Stelle sicher, dass die Blutmenge nicht unter 0 fällt
        if tbl.blood_amount < 0 then
            tbl.blood_amount = 0
        end
    end

    -- Optional: Schmerzlevel begrenzen, falls Maximalwert existiert
    -- tbl.pain_level = math.Clamp(tbl.pain_level, 0, MAX_PAIN_LEVEL)

    return pulse_mod, spo2_mod, bp_mod
end