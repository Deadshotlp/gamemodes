Ammo = Ammo or {}
Ammo.config = {}

function addammoconf()
    Ammo.config.jobs = {
        [-99] = {
            types = {
                [-99] = {
                    maxammo = 1500
                },
                [8] = {
                    maxammo = 8
                },
				[10] = {
                    maxammo = 8
					
                },
                [39] = {
                    maxammo = 8
					
                },
				[41] = {
                    maxammo = 8
					
                },
				[43] = {
                    maxammo = 8
					
                },
				[44] = {
                    maxammo = 8
					
                },
				[45] = {
                    maxammo = 8
					
                },
				[46] = {
                    maxammo = 8
						
				},
				[47] = {
                    maxammo = 8
				
			    },
				[48] = {
                    maxammo = 8
				
                },
            }
        }
    }

    -- AmmoID
    Ammo.config.category = {
        [-99] = {}
    }
end


local doammocheck = false
hook.Add("PlayerAmmoChanged", "ammochangedfunction", function(ply, ammoid, old, new)
    if (Ammo.config.jobs == nil) then
        addammoconf()

        return
    end

    if (CLIENT) then
        if (ply ~= LocalPlayer()) then return end
    end

    if (doammocheck) then return end
    doammocheck = true
   
    local temp = Ammo.config.jobs[-99]
    local maxammo = temp.types[ammoid] or temp.types[-99] or Ammo.config.jobs[-99].types[-99]

    if (new > maxammo.maxammo) then
        timer.Simple(0.1, function()
            ply:SetAmmo(maxammo.maxammo, ammoid)
        end)
    end

    doammocheck = false
end)