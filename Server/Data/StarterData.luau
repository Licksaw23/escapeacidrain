local placeHolderData = {
	Brainrots = {}; -- brainrots --
	Plot = {}; -- plants basically --
	PlotGears = {}; -- SPRINKLERS, PLACEMENT GEARS ETC ETC ETC
	Unlocks = {}; -- index --
	Inventory = {}; -- ITEMS
	Settings = {AutoSell = {},["SoundEffects"] = true,["Music"] = true,["DisplayStats"] = false,["PerformanceMode"] = false,["ShowBrainrots"] = true,  ["TopNotifications"] = true; ["ItemNotifications"] = true; ["GiftNotifications"] = true; ["FavoriteIcons"]=  true,};
	Stats = {Orders = 0; Playtime = 0; MostCash = 0;};
	Purchases = {};
	Rebirths = 0;
	Boosts = {};
	Codes = {};
	
	Stock = {}; -- for current stock --
	CurrentStock = nil;
	
	CurrentGearStock = nil;
	GearStock = {};
	
	FirstJoin = tick();
	LastLeave = tick();
	Cash = 100000;
	OrdersComplete = 0;
}

return placeHolderData
