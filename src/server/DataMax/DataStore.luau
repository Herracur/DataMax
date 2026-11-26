--!strict

--[[
             __  ____________  ____  ___   ________  ______ 
            / / / / ____/ __ \/ __ \/   | / ____/ / / / __ \
           / /_/ / __/ / /_/ / /_/ / /| |/ /   / / / / /_/ /
          / __  / /___/ _, _/ _, _/ ___ / /___/ /_/ / _, _/ 
         /_/ /_/_____/_/ |_/_/ |_/_/  |_\____/\____/_/ |_|
]]

--Services
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Session = DataStoreService:GetDataStore("Session")

-- Types
local global = ReplicatedStorage:WaitForChild("global") -- folder
local DataMax = ServerScriptService:WaitForChild("DataMax") -- folder

local Types = require(global:WaitForChild("GeneralDataTypes"))

-- Main
local Cache = require(DataMax:WaitForChild("Cache"))
local DataStore = setmetatable({}, Cache)
local Instances: { [string]: Types.InstanceData } = {}

DataStore.__index = DataStore

-- Variables
local LOAD_DATA_TRY_LIMIT = 3
local SAVE_DATA_TRY_LIMIT = 3

-- Helper functions
local Helper = require(DataMax:WaitForChild("Helper"))

-- Constructor
function DataStore.new(player: Player, store: DataStore, config: Types.DataStoreConfig): Types.self | nil
	if DataStore.GetInstance(player, store.Name) then
		warn(`DataStore instance already exists for player: {player.Name} and store: {store.Name}`)
		return nil
	end
	local key = `{tostring(player.UserId)}`

	local self = setmetatable({}, DataStore) :: any

	self.Player = player
	self.StringId = tostring(player.UserId)
	self.AutoSave = nil :: thread?
	self.IsDebug = true :: boolean
	self.DataStore = store
	self.Destroyed = false :: boolean
	self.LoadState = nil :: boolean?
	self.LoadSessionState = nil :: boolean?
	self.Saving = false :: boolean
	self.SaveTryCount = SAVE_DATA_TRY_LIMIT :: number
	self.LoadTryCount = LOAD_DATA_TRY_LIMIT :: number
	self.CurrentData = nil :: Types.WhatYouSet?

	if config.AutoSave then
		self.AutoSave = task.spawn(function()
			while task.wait(config.AutoSave) do
				if not self.LoadState then
					continue
				end
				self:SaveData(true)
			end
		end)
	end

	if (config.CacheNeeded == true or config.CacheNeeded == "Idk") and config.StoreType == "Table" then
		self.Cache = {}
	elseif (config.CacheNeeded == true or config.CacheNeeded == "Idk") and config.StoreType == "OneValue" then
		self.Cache = nil
	end

	self.StoreInfo = {
		StoreType = config.StoreType,
		OneValueName = config.StoreType == "OneValue" and config.Value.Name or nil,
		OneValueValue = config.StoreType == "OneValue" and config.Value.Default or nil,
		TableName = config.StoreType == "Table" and config.TableName or nil,
		DefaultTableValues = config.StoreType == "Table" and config.DefaultTableValues or nil,
		CacheNeededState = config.CacheNeeded,
	}

	Instances[key] = Instances[key] or {}
	Instances[key][store.Name] = self :: any
	
	return (self :: any) :: Types.self
end

-- Other functions
function DataStore.GetInstance(Player: Player, StoreName: string): Types.self?
	if not Player or not StoreName then
		warn(`Player or Store is nil. Cannot retrieve DataStore instance.`)
		return nil
	end
	return Instances[tostring(Player.UserId)] and Instances[tostring(Player.UserId)][StoreName]
end

function DataStore.GetAllStores(Player: Player): { [string]: Types.self }?
	if not Player then
		warn(`Player is nil. Cannot retrieve DataStore instances.`)
		return nil
	end

	return Instances[tostring(Player.UserId)]
end

function DataStore.GetAllInstances(): { [string]: Types.InstanceData }
	return Instances
end

function DataStore.SaveAll()
	local threads = 0
	for _, stores in pairs(Instances) do
		for _, store in pairs(stores) do
			threads += 1
			task.spawn(function()
				store:SaveData()
				threads -= 1
			end)
		end
	end
	while threads > 0 do task.wait() end
end

function DataStore:Debug(debugType: Types.DebugType, debugMessage: string): ()
	if not self.IsDebug then return end

	if debugType == "print" then
		print(debugMessage)
	elseif debugType == "warn" then
		warn(debugMessage)
	elseif debugType == "error" then
		error(debugMessage)
	end
end

function DataStore:GetInfo(): ()
	print(self.StoreInfo)
	return
end

function DataStore:IsDataUpdatable(dataToCheck: {any}?): boolean
	if self.StoreInfo.StoreType == "Table" and typeof(table) ~= "table" then
		warn(`Data to update is not a table for player: {self.Player.Name}. Update operation aborted.`)
		return false
	end

	if self.StoreInfo.StoreType == "OneValue" and typeof(table) == "table" then
		warn(`Data to update is a table for player: {self.Player.Name}, but the store type is OneValue. Update operation aborted.`)
		return false
	end

	return true
end

function DataStore:WaitForLoad(timeout: number?): boolean
	local t = os.clock()
	while self.LoadState == nil do
		if timeout and os.clock() - t > timeout then return false end
		task.wait(0.1)
	end
	return self.LoadState == true
end

function DataStore:LoadData(): Types.WhatYouSet?
	local sessionControl

	if not self.LoadSessionState then
		self.LoadSessionState = true
		sessionControl = self:UpdateSessionOrGet(false)
	else
		sessionControl = self:UpdateSessionOrGet(true)
	end

	if not sessionControl then
		self.Player:Kick("Your Session have a problem. Please rejoin")
		self:DestroyAll()
	end

	if sessionControl.Session.JobId ~= game.JobId then
		self:Debug("warn", `Session mismatch for player: {self.Player.Name}. Data may not be saved correctly.`)
		self:DestroyAll()
		return nil
	end

	local success, Data = pcall(function()
		return self.DataStore:GetAsync(`{self.StringId} {self.DataStore.Name}`)
	end)

	if not success then
		self.ReloadTryCount = (self.ReloadTryCount :: any) - 1
	end

	self.LoadState = success

	if success and Data ~= nil then
		self:Debug("print", `Data loaded successfully for player: {self.Player.Name}`)
		self.CurrentData = Data

		return Data
	elseif success and Data == nil then
		self:Debug("warn", `No data found for player: {self.Player.Name}. Initializing with default values.`)
		if self.StoreInfo.StoreType == "Table" then
			self.CurrentData = self.StoreInfo.DefaultTableValues or {}
		elseif self.StoreInfo.StoreType == "OneValue" then
			self.CurrentData = self.StoreInfo.OneValueValue
		end
		return nil
	else
		self:Debug("warn", `Failed to load data for player: {self.Player.Name} Error: {Data}`)
		if self.ReloadTryCount > 0 then
			self:Debug("print", `Retrying to load data for player: {self.Player.Name}. Attempts left: {self.ReloadTryCount}`)
			task.wait(1)
			self:LoadData()
		else
			self:Debug("warn", `Exceeded maximum retry attempts for loading data for player: {self.Player.Name}.`)
			self.LoadState = false
			self.Player:Kick("Data loading failed. Please try again later.")
		end
	end

	return nil
end

function DataStore:Destroy(): ()
	if self.Destroyed then 
		self:Debug("warn", "DataStore Destroying not again Destroy")
		return 
	end 
	self.Destroyed = true

	if self.AutoSave then
		task.cancel(self.AutoSave)
		self.AutoSave = nil :: any
	end

	if self.Cache then
		self.Cache = nil
	end

	if Instances[self.StringId] and Instances[self.StringId][self.DataStore.Name] then
		Instances[self.StringId][self.DataStore.Name] = nil

		if next(Instances[self.StringId]) == nil then
			Instances[self.StringId] = nil
		end

		self:Debug("print", `DataStore instance for player: {self.Player.Name} and store: {self.DataStore.Name} has been deleted.`)
	else
		self:Debug("warn", `No DataStore instance found for player: {self.Player.Name} and store: {self.DataStore.Name}.`)
	end

	return
end

function DataStore:DestroyAll():()
	for _, Store in pairs(Instances[self.StringId]) do
		if next(Store) == nil then
			continue
		end

		if Store and not Store.Destroyed then
			Store.Destroyed = true
			Store:Destroy()
		end
	end

	return
end

function DataStore:SaveData(autoSave: boolean?, saveError: boolean?): ()
	if self.Saving and not saveError then
		self:Debug("warn", `Data is already being saved for player: {self.Player.Name}. Please wait until the current save operation is complete.`)
		return
	end

	if saveError then
		self.SaveTryCount = (self.SaveTryCount :: any) - 1

		if self.SaveTryCount <= 0 then
			self:Debug("warn", `Exceeded maximum retry attempts for saving data for player: {self.Player.Name}. Data may not be saved correctly.`)
			self:Destroy()
			return
		end
	end

	if not autoSave and not saveError then
		self.Saving = true
	end

	local sessionControl = self:UpdateSessionOrGet(true)

	if  sessionControl.Session.JobId ~= game.JobId or sessionControl.Session.PlaceId ~= game.PlaceId then
		self:Debug("warn", `Session mismatch for player: {self.Player.Name}. Data may not be saved correctly.`)
		self:Destroy()
		return
	end

	if not self.LoadState then
		self:Debug("warn", `Data for player: {self.Player.Name} has not been loaded yet. Cannot save data.`)
		self:Destroy()
		return
	end

	local success, ErrMsg = pcall(function()
		if self.StoreInfo.StoreType == "Table" then
			self.DataStore:SetAsync(`{self.StringId} {self.DataStore.Name}`, self.CurrentData)
		elseif self.StoreInfo.StoreType == "OneValue" then
			local DataValue = self.CurrentData
			local WhatISave = nil

			if typeof(DataValue) == "Instance" and DataValue:IsA("ValueBase") then
				WhatISave = (DataValue :: any).Value
			else
				WhatISave = DataValue
			end
			self.DataStore:SetAsync(`{self.StringId} {self.DataStore.Name}`, WhatISave)
		end
	end)

	if success then
		self:Debug("print", `Data saved successfully for player: {self.Player.Name}`)
	else
		self:Debug("warn", `Failed to save data for player: {self.Player.Name} Error: {ErrMsg} trying again...`)
		self:SaveData(false, true)
		return
	end

	if not autoSave and not saveError then
		self:Destroy()
	end

	return
end

function DataStore:GetData(): Types.WhatYouSet?
	return self.CurrentData
end

function DataStore:Add(dataToAdd: Types.AdditionalData): ()
	if not self:IsDataUpdatable(dataToAdd :: any) then
		return
	end
	if self.CurrentData == nil then
		return
	end

	if self.StoreInfo.StoreType == "Table" then
		local CurrentData = self.CurrentData :: any
		local CurrentDataType = Helper.decideTableType(CurrentData)

		for k, v in pairs(dataToAdd :: any) do
			if CurrentDataType == "Dictionary" then
				CurrentData[k] = v
			elseif CurrentDataType == "Array" then
				table.insert(CurrentData, v)
			end
		end
	elseif self.StoreInfo.StoreType == "OneValue" then
		self:Debug("warn", `Add operation is not applicable for OneValue data type for player: {self.Player.Name}. Use Update or Set instead.`)
		return
	end

	self:Debug("print", `Data added successfully for player: {self.Player.Name}`)
	self:SaveData(true)
	return
end

function DataStore:Remove(dataToRemove: Types.AdditionalData): ()
	if not self:IsDataUpdatable(dataToRemove :: any) then
		return
	end
	if self.CurrentData == nil then
		return
	end

	if self.StoreInfo.StoreType == "Table" then
		local CurrentData = self.CurrentData :: any
		local CurrentDataType = Helper.decideTableType(CurrentData)

		for k, v in pairs(dataToRemove :: any) do
			if CurrentDataType == "Dictionary" then
				if CurrentData[k] ~= nil then
					CurrentData[k] = nil
				end
			elseif CurrentDataType == "Array" then
				local Index = table.find(CurrentData, v)

				if Index then
					table.remove(CurrentData, Index)
				end
			end
		end
	elseif self.StoreInfo.StoreType == "OneValue" then
		self.CurrentData = nil
	end

	self:Debug("print", `Data removed successfully for player: {self.Player.Name}`)
	self:SaveData(true)
	return
end

function DataStore:Set(newData: Types.AdditionalData): ()
	if not self:IsDataUpdatable(newData :: any) then
		return
	end

	self.CurrentData = newData

	self:Debug("print", `Data set successfully for player: {self.Player.Name}`)
	self:SaveData(true)
end

function DataStore:Update(DataToUpdate: Types.AdditionalData): ()
	if not self:IsDataUpdatable(DataToUpdate :: any) then
		return
	end
	if self.CurrentData == nil then
		return
	end

	if self.StoreInfo.StoreType == "Table" then
		local CurrentData = self.CurrentData :: any
		local CurrentDataType = Helper.decideTableType(CurrentData)

		for k, v in pairs(DataToUpdate :: any) do
			if CurrentDataType == "Dictionary" then
				CurrentData[k] = v
			elseif CurrentDataType == "Array" then
				table.insert(CurrentData, v)
			end
		end
	elseif self.StoreInfo.StoreType == "OneValue" then
		local CurrentData = self.CurrentData

		if typeof(CurrentData) == "number" then
			self.CurrentData = CurrentData + (DataToUpdate :: number)
		elseif typeof(CurrentData) == "Instance" and CurrentData:IsA("ValueBase") then
			(CurrentData :: any).Value += DataToUpdate :: number
		end
	end
	self:SaveData(true)
	self:Debug("print", `Data updated successfully for player: {self.Player.Name}`)
end

function DataStore:UpdateSessionOrGet(get: boolean?): { [string]: string | number }?
	if get == true then
		local succ, data = pcall(function()
			return Session:GetAsync(self.StringId)
		end)

		if succ and data then
			return data
		end
	end

	local succ, data = pcall(function()
		return Session:UpdateAsync(self.StringId, function(Data)
			Data = Data or {}

			Data.Session = {
				JobId = game.JobId,
				PlaceId = game.PlaceId,
			}

			return Data
		end)
	end)

	if not succ then
		self:UpdateSessionOrGet()
	elseif succ and data then
		return data
	end

	return nil
end

return DataStore