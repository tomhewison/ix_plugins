PLUGIN.name = "Citizen Outfits"
PLUGIN.author = "Black Tea | Ported by: El Thomaso"
PLUGIN.desc = "This plugin allows the server having good amount of customizable citizens."

if SERVER then resource.AddWorkshop(320536858) end

ix.util.Include("sh_citizenmodels.lua")
ix.util.Include("cl_vgui.lua")
--ix.util.Include("sh_anims.lua")
-- requires material preload to acquire submaterial change.
if (CLIENT) then
	--[[local time = os.time()
	-- preventing vast loading
	for model, modelData in pairs(RESKINDATA) do
		for k, v in ipairs(modelData.facemaps) do
			surface.SetMaterial(Material(v))
		end
	end

	for model, modelData in pairs(CITIZENSHEETS) do
		for k, v in ipairs(modelData) do
			surface.SetMaterial(Material(v))
		end
	end]]

	function PLUGIN:OnEntityCreated(ragdoll)
		if (ragdoll and ragdoll:IsValid() and ragdoll:GetClass() == "class C_HL2MPRagdoll") then
			local client = ragdoll:GetRagdollOwner()
			if (client and client:IsValid()) then
				self:CreateEntityRagdoll(client, ragdoll)
			end
		end
	end

	-- currently only applies on local player.
	-- should store cloth data on char or player.
	function PLUGIN:CreateEntityRagdoll(client, ragdoll)
		if (ragdoll and ragdoll:IsValid() and client:GetCharacter()) then
			local char = client:GetCharacter()

			if (char) then
				local mdl = char:GetModel()
				local mon = OUTFIT_DATA[mdl:lower()]
				if (!mon) then return end
				
				local outfitList = OUTFIT_REGISTERED[mon.uid]
				for slot, value in pairs(char:GetData("outfits", {})) do
					local data = outfitList[slot] -- part

					if (type(data.outfits) == "function") then
						data.outfits = data.outfits(ragdoll)
					end
			 
					if (data and data.outfits) then
						local cnt = (table.Count(data.outfits))
						value = value % cnt
						value = (value == 0 and cnt or value)

						if (data.func) then
							data.func(ragdoll, data.outfits[value], data)
						end
					end
				end
			end
		end
	end

	netstream.Hook("ixCloseOutfit", function(client)
		if (ix.gui.outfit and ix.gui.outfit.remove) then
			ix.gui.outfit:remove()
		end
	end)
else
	netstream.Hook("ixApplyOutfit", function(client, values)
		local outfitEntity
		for k, v in ipairs(ents.FindInSphere(client:GetPos(), 128)) do
			if (v:GetClass() == "ix_outfit") then
				outfitEntity = v
				break
			end
		end

		if (!outfitEntity) then return end

		local char = client:GetCharacter()

		if (char) then
			local mdl = char:GetModel()
			local outfitList = OUTFIT_REGISTERED[OUTFIT_DATA[mdl:lower()].uid]

			if (!outfitList) then
				return
			end

			local price = 0 

			local charOutfits = char:GetData("outfits", {})

			for k, v in pairs(outfitList) do
				local index = values[k]
				local data = outfitList[k].outfits
	
				if (type(data) == "function") then
					data = data(client)
				end
				
				if (data) then
					local info = data[index]

					if (info) then
						if ((charOutfits[k] or 1) != index) then
							price = price + info.price or 0
						end
					end
				end
			end

			if (ix.currency.Get(price)) then
				char:TakeMoney(price)
			else
				client:notifyLocalized("cantAfford")

				return 
			end

			char:SetData("outfits", values)
			charOutfits = char:GetData("outfits", {})

			for slot, value in pairs(charOutfits) do
				local data = outfitList[slot] -- part

				if (type(data.outfits) == "function") then
					data.outfits = data.outfits(client)
				end
		 
				if (data and data.outfits) then
					local cnt = (table.Count(data.outfits))
						value = value % cnt
						value = (value == 0 and cnt or value)

					if (data.func) then
						data.func(client, data.outfits[value], data)
					end
				end
			end

			netstream.Start(client, "ixCloseOutfit")
		end
	end)
end


function recoverCloth(client, target)
	local char = client:GetCharacter()

	if (char) then
		local mdl = char:GetModel()
		local adoring = OUTFIT_DATA[mdl:lower()]
		if (!adoring) then return false end
		local outfitList = OUTFIT_REGISTERED[adoring.uid or ""]
		
		for slot, value in pairs(char:GetData("outfits", {})) do
			local data = outfitList[slot] -- part

			if (!data) then break end

			if (type(data.outfits) == "function") then
				data.outfits = data.outfits((target or client))
			end
	 
			if (data and data.outfits) then
				local cnt = (table.Count(data.outfits))
						value = value % cnt
						value = (value == 0 and cnt or value)

				if (data.func) then
					data.func((target or client), data.outfits[value], data)
				end
			end
		end
	end
end

function PLUGIN:OnCharFallover(client, ragdoll, isFallen)
	if (client and ragdoll and client:IsValid() and ragdoll:IsValid() and client:GetCharacter() and isFallen) then
		local char = client:GetCharacter()

		if (char) then
			local mdl = char:GetModel()
			local outfitList = OUTFIT_REGISTERED[OUTFIT_DATA[mdl:lower()].uid]
			for slot, value in pairs(char:GetData("outfits", {})) do
				local data = outfitList[slot] -- part

				if (type(data.outfits) == "function") then
					data.outfits = data.outfits(ragdoll)
				end
				
				if (data and data.outfits) then
					local cnt = (table.Count(data.outfits))
						value = value % cnt
						value = (value == 0 and cnt or value)

					if (data.func) then
						data.func(ragdoll, data.outfits[value], data)
					end
				end
			end
		end
	end
end

function PLUGIN:PostPlayerLoadout(client)
	timer.Simple(.01, function() -- to prevent getmodel failing.
		if (client:GetCharacter()) then
			recoverCloth(client)
		end
	end)
end

function PLUGIN:PlayerLoadedChar(client, netChar, prevChar)
	if (prevChar) then
		local b = client:GetBodyGroups()
		
		for k, v in pairs(b) do
			local id, name, num = v.id, v.name, v.num
			
			client:SetBodygroup(num, 0)
		end
		
		client:SetSubMaterial()
	
		timer.Simple(.01, function() -- to prevent getmodel failing.
			if (client:GetCharacter()) then
				recoverCloth(client)
			end
		end)
	end
end
