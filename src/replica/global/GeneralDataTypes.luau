local Types = {}

export type DefaultTableValues = {
	[string]: any,
	-- ... Add as much as you like
} | { any }

export type self = {
	Player: Player,
	StringId: string,
	AutoSave: thread?,
	IsDebug: boolean,
	DataStore: DataStore,
	Destroyed: boolean,
	LoadState: boolean?,
	LoadSessionState: boolean?,
	Saving: boolean,
	SaveTryCount: number,
	ReloadTryCount: number,
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
	Debug: (self: self, debugType: DebugType, debugMessage: string) -> (),
	GetInfo: (self: self) -> (),
	IsDataUpdatable: (self: self, dataToCheck: any) -> boolean,
	IsHaveCache: (self: self) -> (boolean, StoreType),
	GetCache: (self: self) -> any,
	AddCache: (self: self, data: any, Key: string?) -> (),
	SetCache: (self: self, data: any) -> (),
	ClearCache: (self: self) -> (),
	RemoveDataFromCache: (self: self, data: any?, Key: string?) -> (),
	CacheToSaveData: (self: self, deleteOldDataAndOnlyAddCache: boolean?) -> (),
	WaitForLoad: (self: self, timeout: number?) -> boolean,
	LoadData: (self: self) -> WhatYouSet?,
	Destroy: (self: self) -> (),
	DestroyAll: (self: self) -> (),
	SaveData: (self: self, autoSave: boolean?) -> (),
	GetData: (self: self) -> WhatYouSet?,
	Add: (self: self, dataToAdd: AdditionalData) -> (),
	Remove: (self: self, dataToRemove: AdditionalData) -> (),
	Set: (self: self, newData: AdditionalData) -> (),
	Update: (self: self, dataToUpdate: AdditionalData) -> (),
	UpdateSessionOrGet: (self: self, get: boolean?) -> { [string]: string | number }?,
}

export type StoreType = "Table" | "OneValue"
export type WhatYouSet = any | DefaultTableValues | number | string | boolean | Instance -- ... many many
export type AutoSaveInterval = number
export type CacheNeededStates = true | false | "Idk" -- "Idk" durumu sana Cache verir fakat ister kullan ister kullanma sana kalmis
export type WhichTypeToSave = "Array" | "Dictionary" | "Auto"
export type InstanceData = { [string]: self }
export type AdditionalData = boolean | number | string | Instance | any | {} -- Now it no take table value but it could be coming soon
export type Transactions = "Update" | "Add" | "Remove" | "Set" -- Update: Table, Add: Table, Remove: Table, Set: OneValue
export type DebugType = "print" | "warn" | "error"
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

export type DataStoreConfig = OneValueConfig | TableConfig

return Types