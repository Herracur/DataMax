--!strict

--[[
             __  ____________  ____  ___   ________  ______ 
            / / / / ____/ __ \/ __ \/   | / ____/ / / / __ \
           / /_/ / __/ / /_/ / /_/ / /| |/ /   / / / / /_/ /
          / __  / /___/ _, _/ _, _/ ___ / /___/ /_/ / _, _/ 
         /_/ /_/_____/_/ |_/_/ |_/_/  |_\____/\____/_/ |_|
]]

--Services
local DataStoreService = game:GetService("DataStoreService")
local Session = DataStoreService:GetDataStore("Session")

-- Variables
local DataStore = {}
local Instances: { [string]: InstanceData } = {}
local Cache = {}

DataStore.__index = DataStore

local RELOAD_DATA_TRY_LIMIT = 3

-- local functions
local function DeleteInstance(Player: Player, StoreName: string): ()
	local key = `{tostring(Player.UserId)}`
	Cache[tostring(Player.UserId)][StoreName] = nil
	Cache[tostring(Player.UserId)] = nil

	if Instances[key] and Instances[key][StoreName] then
		Instances[key][StoreName] = nil
		Instances[key] = nil
		print(`DataStore instance for player: {Player.Name} and store: {StoreName} has been deleted.`)
	else
		warn(`No DataStore instance found for player: {Player.Name} and store: {StoreName}.`)
	end

	return
end

local function IsDataUpdatable(Table: { any }?, self: self): boolean
	if self.StoreInfo.StoreType == "Table" and typeof(Table) ~= "table" then
		warn(`Data to update is not a table for player: {self.Player.Name}. Update operation aborted.`)
		return false
	end

	if self.StoreInfo.StoreType == "OneValue" and typeof(Table) == "table" then
		warn(
			`Data to update is a table for player: {self.Player.Name}, but the store type is OneValue. Update operation aborted.`
		)
		return false
	end

	return true
end

local function DecideTableType(Table: { any }): WhichTypeToSave
	local Key = 0
	local Value = 0

	for k, v in pairs(Table) do
		if type(k) == "number" then
			Value += 1
		else
			Key += 1
		end
	end

	if Key > Value then
		return "Dictionary"
	elseif Value > Key then
		return "Array"
	elseif Value == Key then
		return "Auto"
	end

	return "Auto"
end

-- Types
export type DefaultTableValues = {
	[string]: any,
	-- ... Add as much as you like
} | { any }

export type self = {
	Player: Player,
	StringId: string,
	DataStore: DataStore,
	LoadState: boolean?,
	LoadSessionState: boolean?,
	ReloadTryCount: number,
	AutoSave: thread?,
	Saving: boolean,
	CurrentData: WhatYouSet?,

	StoreInfo: {
		StoreType: StoreType,
		OneValueName: string?,
		OneValueValue: number | string | boolean | Instance? | nil,
		TableName: string?,
		DefaultTableValues: DefaultTableValues?,
		CacheNeededState: CacheNeededStates,
	},

	-- Functions type
	IsHaveCache: (self: self) -> (boolean, StoreType),
	GetCache: (self: self) -> any,
	SetCache: (self: self, Data: any, Key: string?) -> (),
	ClearCache: (self: self) -> (),
	RemoveDataFromCache: (self: self, Data: any?, Key: string?) -> (),
	CacheToSaveData: (self: self, DeleteOldDataAndOnlyAddCache: boolean?) -> (),
	LoadData: (self: self) -> WhatYouSet?,
	Destroy: (self: self) -> (),
	SaveData: (self: self, AutoSave: boolean?) -> (),
	Add: (self: self, DataToAdd: AdditionalData) -> (),
	Remove: (self: self, DataToRemove: AdditionalData) -> (),
	Set: (self: self, NewData: AdditionalData) -> (),
	Update: (self: self, DataToUpdate: AdditionalData) -> (),
	UpdateSessionOrGet: (self: self, Get: boolean?) -> { [string]: string | number }?,
	GlobalUserProcess: (self: self, Transaction: Transactions) -> (),
}

export type StoreType = "Table" | "OneValue"
export type WhatYouSet = any | DefaultTableValues | number | string | boolean | Instance -- ... many many
export type AutoSaveInterval = number
export type CacheNeededStates = true | false | "Idk" -- "Idk" durumu sana Cache verir fakat ister kullan ister kullanma sana kalmis
export type WhichTypeToSave = "Array" | "Dictionary" | "Auto"
export type InstanceData = { [string]: self }
export type AdditionalData = boolean | number | string | Instance | any | {} -- Now it no take table value but it could be coming soon
export type Transactions = "Update" | "Add" | "Remove" | "Set" -- Update: Table, Add: Table, Remove: Table, Set: OneValue

export type OneValueConfig = {
	StoreType: "OneValue",
	Value: {
		Name: string,
		Default: number | string | boolean | Instance?,
	},
	AutoSave: AutoSaveInterval?,
	CacheNeeded: CacheNeededStates?,
}

export type TableConfig = {
	StoreType: "Table",
	TableName: string,
	DefaultTableValues: DefaultTableValues?,
	AutoSave: AutoSaveInterval?,
	CacheNeeded: CacheNeededStates?,
}

type DataStoreConfig = OneValueConfig | TableConfig

-- Constructor
function DataStore.new(Player: Player, Store: DataStore, Config: DataStoreConfig): self | nil
	if DataStore.GetInstance(Player, Store.Name) then
		warn(`DataStore instance already exists for player: {Player.Name} and store: {Store.Name}`)
		return nil
	end
	local key = `{tostring(Player.UserId)}`

	local self = setmetatable({}, DataStore) :: any

	self.Player = Player
	self.StringId = tostring(Player.UserId)
	self.AutoSave = nil :: thread?
	self.DataStore = Store
	self.LoadState = nil :: boolean?
	self.LoadSessionState = nil :: boolean?
	self.Saving = false :: boolean
	self.ReloadTryCount = RELOAD_DATA_TRY_LIMIT :: number
	self.CurrentData = nil :: WhatYouSet?

	if Config.AutoSave then
		self.AutoSave = task.spawn(function()
			while task.wait(Config.AutoSave) do
				if not self.LoadState then
					continue
				end
				self:SaveData(true)
			end
		end)
	end

	if (Config.CacheNeeded == true or Config.CacheNeeded == "Idk") and Config.StoreType == "Table" then
		Cache[key] = Cache[key] or {}
		Cache[key][Store.Name] = {} :: any
	elseif (Config.CacheNeeded == true or Config.CacheNeeded == "Idk") and Config.StoreType == "OneValue" then
		Cache[key] = Cache[key]
		Cache[key][Store.Name] = nil
	end

	self.StoreInfo = {
		StoreType = Config.StoreType,
		OneValueName = Config.StoreType == "OneValue" and Config.Value.Name or nil,
		OneValueValue = Config.StoreType == "OneValue" and Config.Value.Default or nil,
		TableName = Config.StoreType == "Table" and Config.TableName or nil,
		DefaultTableValues = Config.StoreType == "Table" and Config.DefaultTableValues or nil,
		CacheNeededState = Config.CacheNeeded,
	}

	Instances[key] = Instances[key] or {}
	Instances[key][Store.Name] = self :: any

	return (self :: any) :: self
end

-- Other functions
function DataStore.GetInstance(Player: Player, StoreName: string): self?
	if not Player or not StoreName then
		warn(`Player or Store is nil. Cannot retrieve DataStore instance.`)
		return nil
	end
	return Instances[tostring(Player.UserId)] and Instances[tostring(Player.UserId)][StoreName]
end

function DataStore.GetAllStores(Player: Player): { [string]: self }?
	if not Player then
		warn(`Player is nil. Cannot retrieve DataStore instances.`)
		return nil
	end

	return Instances[tostring(Player.UserId)]
end

function DataStore.GetAllInstances(): { [string]: InstanceData }
	return Instances
end

function DataStore:GetInfo(): ()
	print(self.StoreInfo)
	return
end

function DataStore:IsHaveCache(): (boolean, StoreType)
	if self.StoreInfo.CacheNeededState == true or self.StoreInfo.CacheNeededState == "Idk" then
		return true, self.StoreInfo.StoreType
	else
		warn(
			`Cache is not enabled for player: {self.Player.Name} and store: {self.DataStore.Name}. Cannot retrieve cache.`
		)
		return false, self.StoreInfo.StoreType
	end
end

function DataStore:GetCache(): any
	local HasCache = self:IsHaveCache()
	if HasCache == false then
		return nil
	end

	return Cache[self.StringId][self.DataStore.Name]
end

function DataStore:SetCache(Data: any, Key: string?): ()
	local HasCache, StoreType = self:IsHaveCache()
	if HasCache == false then
		return nil
	end

	if StoreType == "Table" then
		if not Key then
			table.insert(Cache[self.StringId][self.DataStore.Name], Data)
		else
			Cache[self.StringId][self.DataStore.Name][Key] = Data
		end
	elseif StoreType == "OneValue" and not Key then
		Cache[self.StringId][self.DataStore.Name] = Data
	end
	return
end

function DataStore:ClearCache(): ()
	local HasCache = self:IsHaveCache()
	if HasCache == false then
		return
	end

	if self.StoreInfo.StoreType == "Table" then
		Cache[self.StringId][self.DataStore.Name] = {}
	elseif self.StoreInfo.StoreType == "OneValue" then
		Cache[self.StringId][self.DataStore.Name] = nil
	end

	return
end

function DataStore:RemoveDataFromCache(Data: any?, Key: string?): ()
	local HasCache, StoreType = self:IsHaveCache()
	if HasCache == false then
		return
	end

	if StoreType == "Table" then
		if Data then
			table.remove(Cache[self.StringId][self.DataStore.Name], Data)
		else
			Cache[self.StringId][self.DataStore.Name][Key] = nil
		end
	elseif StoreType == "OneValue" then
		Cache[self.StringId][self.DataStore.Name] = nil
	end
	return
end

function DataStore:CacheToSaveData(DeleteOldDataAndOnlyAddCache: boolean?): ()
	if self.StoreInfo.StoreType == "Table" then
		local Addkey
		local Cache = Cache[self.StringId][self.DataStore.Name]

		if DeleteOldDataAndOnlyAddCache then
			self.CurrentData = Cache
			return
		end
		local DataTableType = DecideTableType(self.CurrentData)
		local CacheTableType = DecideTableType(Cache)

		if DataTableType == "Array" then
			Addkey = false
		elseif DataTableType == "Dictionary" then
			Addkey = true
		elseif DataTableType == "Auto" then
			warn(
				`Both Cache and CurrentData are of type "Auto". Defaulting to Dictionary for saving data for player: {self.Player.Name}.`
			)
			Addkey = true
		end

		for k, v in pairs(Cache) do
			if (CacheTableType == "Dictionary" or CacheTableType == "Auto") and Addkey then
				if typeof(k) == "number" then
					continue
				end
				self.CurrentData[k] = v
			elseif not Addkey and CacheTableType == "Array" then
				table.insert(self.CurrentData, v)
			end
		end
	elseif self.StoreInfo.StoreType == "OneValue" then
		if DeleteOldDataAndOnlyAddCache then
			self.CurrentData = Cache
			return
		end

		if typeof(Cache) == "number" then
			self.CurrentData = (self.CurrentData :: any) + (Cache :: any)
		end
	end

	return
end

function DataStore:LoadData(): WhatYouSet?
	local SessionControl

	if not self.LoadSessionState then
		self.LoadSessionState = true
		SessionControl = self:UpdateSessionOrGet(false)
	else
		SessionControl = self:UpdateSessionOrGet(true)
	end

	if SessionControl.Session.JobId ~= game.JobId then
		warn(`Session mismatch for player: {self.Player.Name}. Data may not be saved correctly.`)
		self:Destroy()
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
		print(`Data loaded successfully for player: {self.Player.Name}`)
		self.CurrentData = Data

		return Data
	elseif success and Data == nil then
		warn(`No data found for player: {self.Player.Name}. Initializing with default values.`)
		if self.StoreInfo.StoreType == "Table" then
			self.CurrentData = self.StoreInfo.DefaultTableValues or {}
		elseif self.StoreInfo.StoreType == "OneValue" then
			self.CurrentData = self.StoreInfo.OneValueValue
		end
		return nil
	else
		warn(`Failed to load data for player: {self.Player.Name} Error: {Data}`)
		if self.ReloadTryCount > 0 then
			print(`Retrying to load data for player: {self.Player.Name}. Attempts left: {self.ReloadTryCount}`)
			task.wait(1)
			self:LoadData()
		else
			warn(`Exceeded maximum retry attempts for loading data for player: {self.Player.Name}.`)
			self.LoadState = false
			self.Player:Kick("Data loading failed. Please try again later.")
		end
	end

	return nil
end

function DataStore:Destroy(): ()
	if self.AutoSave then
		task.cancel(self.AutoSave)
		self.AutoSave = nil :: any
	end

	task.wait(0.5)
	DeleteInstance(self.Player, self.DataStore.Name)

	return
end

function DataStore:SaveData(AutoSave: boolean?): ()
	if self.Saving then
		warn(
			`Data is already being saved for player: {self.Player.Name}. Please wait until the current save operation is complete.`
		)
		return
	end

	-- this line repeated twice cuz we was need speed this line(repeatted line 445)
	if not AutoSave then
		self.Saving = true
	end

	local SessionControl = self:UpdateSessionOrGet(true)

	if SessionControl.Session.JobId ~= game.JobId or SessionControl.Session.PlaceId ~= game.PlaceId then
		warn(`Session mismatch for player: {self.Player.Name}. Data may not be saved correctly.`)
		self:Destroy()
		return
	end

	if not self.LoadState then
		warn(`Data for player: {self.Player.Name} has not been loaded yet. Cannot save data.`)
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
		print(`Data saved successfully for player: {self.Player.Name}`)
	else
		warn(`Failed to save data for player: {self.Player.Name} Error: {ErrMsg}`)
	end

	if not AutoSave then
		self:Destroy()
	end

	return
end

function DataStore:Add(DataToAdd: AdditionalData): ()
	if not IsDataUpdatable(DataToAdd :: any, self) then
		return
	end
	if self.CurrentData == nil then
		return
	end

	if self.StoreInfo.StoreType == "Table" then
		local CurrentData = self.CurrentData :: any
		local CurrentDataType = DecideTableType(CurrentData)

		for k, v in pairs(DataToAdd :: any) do
			if CurrentDataType == "Dictionary" then
				CurrentData[k] = v
			elseif CurrentDataType == "Array" then
				table.insert(CurrentData, v)
			end
		end
	elseif self.StoreInfo.StoreType == "OneValue" then
		warn(
			`Add operation is not applicable for OneValue data type for player: {self.Player.Name}. Use Update or Set instead.`
		)
		return
	end

	print(`Data added successfully for player: {self.Player.Name}`)
	self:SaveData(true)
	return
end

function DataStore:Remove(DataToRemove: AdditionalData): ()
	if not IsDataUpdatable(DataToRemove :: any, self) then
		return
	end
	if self.CurrentData == nil then
		return
	end

	if self.StoreInfo.StoreType == "Table" then
		local CurrentData = self.CurrentData :: any
		local CurrentDataType = DecideTableType(CurrentData)

		for k, v in pairs(DataToRemove :: any) do
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

	print(`Data removed successfully for player: {self.Player.Name}`)
	self:SaveData(true)
	return
end

function DataStore:Set(NewData: AdditionalData): ()
	if not IsDataUpdatable(NewData :: any, self) then
		return
	end

	self.CurrentData = NewData

	print(`Data set successfully for player: {self.Player.Name}`)
	self:SaveData(true)
end

function DataStore:Update(DataToUpdate: AdditionalData): ()
	if not IsDataUpdatable(DataToUpdate :: any, self) then
		return
	end
	if self.CurrentData == nil then
		return
	end

	if self.StoreInfo.StoreType == "Table" then
		local CurrentData = self.CurrentData :: any
		local CurrentDataType = DecideTableType(CurrentData)

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

	print(`Data updated successfully for player: {self.Player.Name}`)
end

function DataStore:UpdateSessionOrGet(Get: boolean?): { [string]: string | number }?
	if Get == true then
		local succ, data = pcall(function()
			return Session:GetAsync(`{self.StringId} {self.DataStore.Name}`)
		end)

		if succ and data then
			return data
		end
	end

	local succ, data = pcall(function()
		return Session:UpdateAsync(`{self.StringId} {self.DataStore.Name}`, function(Data)
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