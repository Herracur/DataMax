local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataMax = ServerScriptService:WaitForChild("DataMax")

-- Helper Functions
local Helper = require(DataMax:WaitForChild("Helper"))

-- Types
local Types = require(ReplicatedStorage:WaitForChild("global"):WaitForChild("GeneralDataTypes"))

local Cache = {}
Cache.__index = Cache

function Cache:IsHaveCache(): (boolean, Types.StoreType)
	if self.StoreInfo.CacheNeededState == true or self.StoreInfo.CacheNeededState == "Idk" then
		return true, self.StoreInfo.StoreType
	else
		self:Debug("warn", `Cache is not enabled for player: {self.Player.Name} and store: {self.DataStore.Name}. Cannot retrieve cache.`)
		return false, self.StoreInfo.StoreType
	end
end

function Cache:GetCache(): any
	local hasCache = self:IsHaveCache()
	if hasCache == false then
		return nil
	end

	return self.Cache
end

function Cache:AddCache(data: any, key: string?): ()
	local hasCache, storeType = self:IsHaveCache()
	if hasCache == false then
		return nil
	end

	if storeType == "Table" then
		if not key then
			table.insert(self.Cache, data)
		else
			self.Cache[key] = data
		end
	elseif storeType == "OneValue" and not key then
		self:Debug("warn", `One value cannot add any cache for player: {self.Player.Name}. Use SetCache instead.`)
	end

	return
end

function Cache:SetCache(data: any): ()
	local hasCache, storeType = self:IsHaveCache()
	if hasCache == false then
		return nil
	end

	if storeType == "Table" then
		if typeof(data) ~= "table" then
			self:Debug("warn", `Data to set cache is not a table for player: {self.Player.Name}. SetCache operation aborted.`)
			return
		end
		self.Cache = data
	elseif storeType == "OneValue" then
		self.Cache = data
	end

	return
end

function Cache:ClearCache(): ()
	local hasCache, storeType = self:IsHaveCache()
	if hasCache == false then
		return
	end

	if storeType == "Table" then
		self.Cache = {}
	elseif storeType == "OneValue" then
		self.Cache = nil
	end

	return
end

function Cache:RemoveDataFromCache(dataOrIndex: any?, key: string?): ()
	local hasCache, storeType = self:IsHaveCache()
	if hasCache == false then
		return
	end

	if storeType == "Table" then
		if dataOrIndex then
			if typeof(dataOrIndex) == "number" then
				table.remove(self.Cache, dataOrIndex)
			else
				local index = table.find(self.Cache, dataOrIndex)
				table.remove(self.Cache, index)
			end
		else
			self.Cache[key] = nil
		end
	elseif storeType == "OneValue" then
		self.Cache = nil
	end

	return
end

function Cache:CacheToSaveData(deleteOldDataAndOnlyAddCache: boolean?): ()
	self = self :: any

	local hasCache, storeType = self:IsHaveCache()
	if hasCache == false then
		return
	end

	if storeType == "OneValue" then
		if deleteOldDataAndOnlyAddCache then
			self.CurrentData = self.Cache
			return
		end

		if typeof(self.Cache) == "number" then
			self.CurrentData = (self.CurrentData :: any) + (self.Cache :: any)
		end
	elseif storeType == "Table" then
		local addkey
		local cache = self.Cache

		if deleteOldDataAndOnlyAddCache then
			self.CurrentData = self.Cache
			return
		end
		local dataTableType = Helper.decideTableType(self.CurrentData)
		local cacheTableType = Helper.decideTableType(cache) :: any

		if dataTableType == "Array" then
			addkey = false
		elseif dataTableType == "Dictionary" then
			addkey = true
		elseif dataTableType == "Auto" then
			self:Debug("warn", `Both Cache and CurrentData are of type "Auto". Defaulting to Dictionary for saving data for player: {self.Player.Name}.`)
			addkey = true
		end

		for k, v in pairs(cache) do
			if (cacheTableType == "Dictionary" or cacheTableType == "Auto") and addkey then
				if typeof(k) == "number" then
					continue
				end
				self.CurrentData[k] = v
			elseif not addkey and cacheTableType == "Array" then
				table.insert(self.CurrentData, v)
			end
		end
	end

	return
end

return Cache