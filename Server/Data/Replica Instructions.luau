--[[ Instructions on how to use ReplicaService: 

- Replica:SetValue("Coins", NewValue) --// Modify/ Create a Value (Coins/gems/etc)

- Replica:SetValue({"Units","UnitName"},nil) --// Delete a unit from player's inventory

- Replica:SetValue({"Units","UniqueUnitID"},{ --// Add a unit/item to player's inventory
	Equipped = 0;
	Name = UnitName;
	Level = 0;
})

- Replica:SetValue({"Units","UnitName","Equipped"}, NewValue) --// Modify an existent unit's properties / Add a new property to unit

--]]