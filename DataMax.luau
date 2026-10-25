--!strict

--[[
    By Herracur, status: half completed
    Suanlik hatalar olabilir duzeltililecek
             __  ____________  ____  ___   ________  ______ 
            / / / / ____/ __ \/ __ \/   | / ____/ / / / __ \
           / /_/ / __/ / /_/ / /_/ / /| |/ /   / / / / /_/ /
          / __  / /___/ _, _/ _, _/ ___ / /___/ /_/ / _, _/ 
         /_/ /_/_____/_/ |_/_/ |_/_/  |_\____/\____/_/ |_|
    DataStoreFrameWork
]]

local DataStore = {}
local Instances: { [string]: InstanceData } = {} 
local Cache = {}

DataStore.__index = DataStore

local RELOAD_DATA_TRY_LIMIT = 3

-- local functions
local function DeleteInstance(Player : Player, StoreName : string) : ()
    local key = `{tostring(Player.UserId)}`
    Cache[`{tostring(Player.UserId)} {StoreName}`] = nil
    if Instances[key] then
        Instances[key] = nil
        print(`DataStore instance for player: {Player.Name} and store: {StoreName} has been deleted.`)
    else
        warn(`No DataStore instance found for player: {Player.Name} and store: {StoreName}.`)
    end

    return
end

local function IsDataUpdatable(Args : {any}, self : self) : boolean
    local MultipleArgs = #Args > 1

    if #Args == 0 then
        warn(`No arguments provided for updating data for player: {self.StoreInfo.PlayerName}. At least one argument is required.`)
        return false
    end

    if MultipleArgs and self.StoreType == "OneValue" then
        warn(`Multiple arguments provided for updating one-value data for player: {self.StoreInfo.PlayerName}. Only one argument is allowed.`)
        return false
    end

    if MultipleArgs  then
        for _, arg in pairs(Args) do
            if type(arg) == "table" then
                warn(`Invalid argument type for updating data for player: {self.StoreInfo.PlayerName}. Expected OneValue, got {type(arg)}.`)
                return false
            end
        end
    end

    return true
end

-- Types
export type TableValues = {
    [string]: any 
    -- ... Add as much as you like
} | {any}

export type self = {
    Player: Player,
    DataStore: DataStore,
    LoadState: boolean?,
    ReloadTryCount: number,
    StoreType: "Table" | "OneValue",
    AutoSave: thread?,
    Saving: boolean,
    StoreInfo: {
        Player: Player,
        PlayerName: string,
        PlayerUserId: number,
        StoreName: string,
        StoreType: "Table" | "OneValue",
        AnyAnyDataName: string | nil,
        AnyAnyDataValue: number | string | boolean | Instance? | nil,
        TableName: string | nil,
        TableValues: TableValues | nil
    }
}

export type WhatYouSet = any | TableValues | number | string | boolean | Instance
export type AutoSaveInterval = number 
export type CacheNeededStates = true | false | "Idk" -- "Idk" durumu sana Cache verir fakat ister kullan ister kullanma sana kalmis

export type InstanceData = { [string]: self }
export type AdditionalData = boolean | number | string | Instance | any -- Now it no take table value but it could be coming soon

-- Constructor
function DataStore.new(
    Player : Player,
    Store : DataStore,
    StoreType : "Table" | "OneValue",
    AnyAnyData : {AnyAnyDataName: string, AnyAnyDataValue: number | string | boolean | Instance?} | nil, -- This Type For one value
    HasTable : {TableName: string} | nil,
    TableValues : TableValues?,
    ThisDataNeedAutoSave :  AutoSaveInterval?,
    CacheNeeded : CacheNeededStates?
) : self | nil

    if DataStore.GetInstance(Player, Store.Name) then 
        warn(`DataStore instance already exists for player: {Player.Name} and store: {Store.Name}`)
        return nil
    end

    local self = setmetatable({}, DataStore) :: any

    self.Player = Player
    self.DataStore = Store
    self.StoreType = StoreType
    self.AutoSave = nil :: thread?
    self.LoadState = nil :: boolean?
    self.Saving = false :: boolean
    self.ReloadTryCount = RELOAD_DATA_TRY_LIMIT :: number

    if ThisDataNeedAutoSave then
        self.AutoSave = task.spawn(function()
            while task.wait(ThisDataNeedAutoSave) do
                self:SaveData(true)
            end
        end)
    end

    if CacheNeeded == true then
        Cache[tostring(Player.UserId)] = Cache[tostring(Player.UserId)] or {}
        Cache[tostring(Player.UserId)][Store.Name] = {} :: any
    elseif CacheNeeded == "Idk" then
        Cache[`{tostring(Player.UserId)} {Store.Name}`] = {}
    end
        
    self.StoreInfo = {
        Player = Player,
        PlayerName = Player.Name,
        PlayerUserId = Player.UserId,
        StoreName = Store.Name,
        StoreType = StoreType,
        AnyAnyDataName = type(AnyAnyData) == "table" and AnyAnyData.AnyAnyDataName or nil,
        AnyAnyDataValue = type(AnyAnyData) == "table" and AnyAnyData.AnyAnyDataValue or nil,
        AnyAnyDataType = AnyAnyData and typeof(AnyAnyData.AnyAnyDataValue) or nil,
        TableName = type(HasTable) == "table" and HasTable.TableName or nil,
        TableValues = type(TableValues) == "table" and TableValues or nil,
        CacheNeededState = CacheNeeded
    }

    local UserId = tostring(Player.UserId)

    Instances[UserId] = Instances[UserId] or {}
    Instances[UserId][Store.Name] = self :: any
    return (self :: any) :: self
end

-- Other functions
function DataStore.GetInstance(Player : Player, StoreName : string) : self?
    if not Player or not StoreName then
        warn(`Player or Store is nil. Cannot retrieve DataStore instance.`)
        return nil
    end
    return Instances[tostring(Player.UserId)] and Instances[tostring(Player.UserId)][StoreName]
end

function DataStore.GetAllStores(Player : Player) : { [string]: self }?
    if not Player then
        warn(`Player is nil. Cannot retrieve DataStore instances.`)
        return nil
    end

    return Instances[`{tostring(Player.UserId)}`]
end

function DataStore.GetAllInstances() : { [string]: InstanceData }
    return Instances
end

function DataStore:IsHaveCache()
    if self.StoreInfo.CacheNeededState == true or self.StoreInfo.CacheNeededState == "Idk" then
        return true
    else
        warn(`Cache is not enabled for player: {self.StoreInfo.PlayerName} and store: {self.StoreInfo.StoreName}. Cannot retrieve cache.`)
        return false
    end
end

function DataStore:GetInfo() : ()
    print(self.StoreInfo)
    return
end

function DataStore:GetCache() : any
    if self:IsHaveCache() == false then return nil end

    return Cache[tostring(self.StoreInfo.PlayerUserId)][self.StoreInfo.StoreName]
end

function DataStore:SetCache(Data : any, DataKey : string?) : ()
    if self:IsHaveCache() == false then return end
    if not DataKey then
        table.insert(Cache[tostring(self.StoreInfo.PlayerUserId)][self.StoreInfo.StoreName], Data)
    else
        Cache[tostring(self.StoreInfo.PlayerUserId)][self.StoreInfo.StoreName][DataKey] = Data
    end
    return
end

function DataStore:ClearCache() : ()
    if self:IsHaveCache() == false then return end

    Cache[tostring(self.StoreInfo.PlayerUserId)][self.StoreInfo.StoreName] = nil
    Cache[tostring(self.StoreInfo.PlayerUserId)] = nil
    return
end

function DataStore:RemoveDataFromCache(Data: any?,Key : string?) : ()
    if self:IsHaveCache() == false then return end

    if Data then
        table.remove(Cache[tostring(self.StoreInfo.PlayerUserId)][self.StoreInfo.StoreName], Data)
    else
        Cache[tostring(self.StoreInfo.PlayerUserId)][self.StoreInfo.StoreName][Key] = nil
    end
    return
end

function DataStore:LoadData() : WhatYouSet?
    local success, Data = pcall(function()
        return self.DataStore:GetAsync(tostring(`{self.StoreInfo.PlayerUserId} {self.StoreInfo.StoreName}`))
    end)
    if not success then
        self.ReloadTryCount = (self.ReloadTryCount :: any) - 1
    end

    self.LoadState = success

    if success and Data ~= nil  then
        print(`Data loaded successfully for player: {self.StoreInfo.PlayerName}`)
        return Data
    elseif success and Data == nil then
        warn(`No data found for player: {self.StoreInfo.PlayerName}. Initializing with default values.`)
        return nil
    else
        warn(`Failed to load data for player: {self.StoreInfo.PlayerName} Error: {Data}`)
        if self.ReloadTryCount > 0 then
            print(`Retrying to load data for player: {self.StoreInfo.PlayerName}. Attempts left: {self.ReloadTryCount}`)
            task.wait(1) 
            self:LoadData()
        else
            warn(`Exceeded maximum retry attempts for loading data for player: {self.StoreInfo.PlayerName}.`)
            self.LoadState = false
            self.StoreInfo.Player:Kick("Data loading failed. Please try again later.")
        end
    end

    return nil
end

function DataStore:Destroy() : ()
    if self.AutoSave then
        task.cancel(self.AutoSave)
        self.AutoSave = nil :: any
    end

    task.wait(.5)
    DeleteInstance(self.Player, self.StoreInfo.StoreName)

    return
end

function DataStore:SaveData(AutoSave: boolean | nil) : ()
    if self.Saving then 
        warn(`Data is already being saved for player: {self.StoreInfo.PlayerName}. Please wait until the current save operation is complete.`)
        return 
    end
    -- this line repeated twice cuz we was need speed this line(repeatted line 311)
    if not AutoSave then
        self.Saving = true
    end

    if not self.LoadState then
        warn(`Data for player: {self.StoreInfo.PlayerName} has not been loaded yet. Cannot save data.`)
        self:Destroy()
        return
    end

    local success, ErrMsg = pcall(function()
        if self.StoreType == "Table" then
            self.DataStore:SetAsync(tostring(`{self.StoreInfo.PlayerUserId} {self.StoreInfo.StoreName}`), self.StoreInfo.TableValues)
        elseif self.StoreType == "OneValue" then
            local DataValue = self.StoreInfo.AnyAnyDataValue 
            local WhatISave = nil

            if typeof(DataValue) == "Instance" and DataValue:IsA("ValueBase") then
                WhatISave = (DataValue :: any).Value
            else
                WhatISave = DataValue
            end
            self.DataStore:SetAsync(tostring(`{self.StoreInfo.PlayerUserId} {self.StoreInfo.StoreName}`), WhatISave)
        end
    end)

    if success then 
    print(`Data saved successfully for player: {self.StoreInfo.PlayerName}`)
    else
        warn(`Failed to save data for player: {self.StoreInfo.PlayerName} Error: {ErrMsg}`)
    end

    if not AutoSave then
        self:Destroy()
    end

    return
end

function DataStore:UpdateData(... : AdditionalData) : ()
    local Args = {...}
    local IsUpdatadble = IsDataUpdatable(Args, self)

    if not IsUpdatadble then return end

    local success, Data = pcall(function()
         return self.DataStore:UpdateAsync(tostring(`{self.StoreInfo.PlayerUserId} {self.StoreInfo.StoreName}`), function(oldData)
                if self.StoreType == "Table" then
                    -- I am lazy nigga, could be make after
                elseif self.StoreType == "OneValue" then
                    -- I am lazy nigga, could be make after
                end
            return
         end)
    end)

    if success then
        print(`Data updated successfully for player: {self.StoreInfo.PlayerName}`)
    else
        warn(`Failed to update data for player: {self.StoreInfo.PlayerName} Error: {Data}`)
    end

    return
end

return DataStore

    --[[
    it was considered

    Error Handling Control for Constructor(assert)
    Usable Cache(Add to table or add One Value)
    Client GetInstance Function, but this is risky ⚠️
    Session will be added
    Get
    Set
    Data.Init will be added

    this task when finished, things to be:
    Maximum Optimization
    Useless lines, will be deleted
    Variables will be made more readable
    
    Now Errors:
    DeleteInstance bır store sılınce oyuncunun dıger storelarını da dusuruyor suanda usendıgım ıcın yaparım bı ara
    Load data islendiginde Intances tablosu guncellenmeli guncel oradaki veriler ile
    ]]