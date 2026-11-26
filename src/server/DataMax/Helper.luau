local ReplicatedStorage = game:GetService("ReplicatedStorage")
local global = ReplicatedStorage:WaitForChild("global")

local Types = require(global:WaitForChild("GeneralDataTypes"))

local function decideTableType(table: { any }): Types.WhichTypeToSave
	if next(table) == nil then
		error("Cannot decide table type for an empty table. Please provide a non-empty table.")
	end

	local key = 0
	local value = 0

	for k, v in pairs(table) do
		if type(k) == "number" then
			value += 1
		else
			key += 1
		end
	end

	if key > value then
		return "Dictionary"
	elseif value > key then
		return "Array"
	elseif value == key then
		return "Auto"
	end

	return "Auto"
end

return {
    decideTableType = decideTableType,
}