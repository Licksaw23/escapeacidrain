return {
	["Recovery Basket"] = {
		Placeable = true;
		Type = "Gear";
		Rarity = "Legendary";
		hex = "#8D2130";
		BestStock = 4;
		MinimumStock = 1;
		Layout = 5;
		BuyPrice = 25000; -- this is kinda op
		PurchaseID = 0; -- Add your product ID here
	};
	
	["Lightning Rod"] = {
		Placeable = true;
		Type = "Gear";
		Rarity = "Legendary";
		hex = "#8D2130";
		BestStock = 1;
		MinimumStock = 0;
		Layout = 4;
		BuyPrice = 50000;
		ManualOffset = -0.2;
		PurchaseID = 0; -- Add your product ID here
		PlaceableData = {
			Radius = 30; -- it affects this radius
			Charges = 3; -- the place effect can be used this time (3 strikes)
			-- Add a duration, for sprinklers
		}
		
	};
	
	["Starter Sprinkler"] = {
		Placeable = true;
		Type = "Gear";
		Rarity = "Rare";
		hex = "#8D2130";
		BestStock = 5;
		MinimumStock = 0;
		Layout = 1;
		BuyPrice = 5000;
		PurchaseID = 0; -- Add your product ID here
		ManualOffset = 0.875;
		PlaceableData = {
			Radius = 20; -- it affects this radius
			Charges = 3; -- the place effect can be used this time (3 strikes)
			Duration = 5*60 -- 5 minutes
			-- Add a duration, for sprinklers
		}

	};
	
	["Bamboo Sprinkler"] = {
		Placeable = true;
		Type = "Gear";
		Rarity = "Epic";
		hex = "#8D2130";
		BestStock = 5;
		MinimumStock = 0;
		Layout = 2;
		BuyPrice = 1;
		PurchaseID = 0; -- Add your product ID here
		ManualOffset = 0.2;
		PlaceableData = {
			Radius = 30; -- it affects this radius
			Charges = 3; -- the place effect can be used this time (3 strikes)
			Duration = 5*60 -- 5 minutes
			-- Add a duration, for sprinklers
		}

	};
	
	["Industrial Sprinkler"] = {
		Placeable = true;
		Type = "Gear";
		Rarity = "Legendary";
		hex = "#8D2130";
		BestStock = 3;
		MinimumStock = 0;
		Layout = 1;
		BuyPrice = 1;
		PurchaseID = 0; -- Add your product ID here
		ManualOffset = 0.875;
		PlaceableData = {
			Radius = 45; -- it affects this radius
			Charges = 3; -- the place effect can be used this time (3 strikes)
			Duration = 5*60 -- 5 minutes
			-- Add a duration, for sprinklers
		}

	};
}