local Rebirths = {}




Rebirths[1] = {
	["Unlocks"] = {
		["+50% Cash"] = {DataName = "UpgradeMoney",IsUpgrade = true,Icon = "Cash"};
		["+50% Luck"] = {DataName = "UpgradeLuck",IsUpgrade = true,Icon = "Luck"};
		["More Brainrot Pads!"] = {DataName = "DoesntMatter",IsUpgrade = true, Icon = "NormalPadViewport"}
	};
	
	["Requirements"] = {
		Money = 300000;
		["Cappuccino Assassino"] = 1;
		["Brr Brr Patapim"] = 1;
	};
}


Rebirths[2] = {
	["Unlocks"] = {
		["+50% Money"] = {DataName = "UpgradeMoney",IsUpgrade = true,Icon = "Cash"};
		["+50% Luck"] = {DataName = "UpgradeLuck",IsUpgrade = true,Icon = "Luck"};
		["More Brainrot Pads!"] = {DataName = "DoesntMatter",IsUpgrade = true, Icon = "NormalPadViewport"}
	};
	["Requirements"] = {
		Money = 1000000;
		["Chimpanzini Bananini"] = 1;
		["Bananita Dolphinita"] = 1;
	};
}

Rebirths[3] = {
	["Unlocks"] = {
		["+50% Money"] = {DataName = "UpgradeMoney",IsUpgrade = true,Icon = "Cash"};
		["+50% Luck"] = {DataName = "UpgradeLuck",IsUpgrade = true,Icon = "Luck"};
	};
	["Requirements"] = {
		Money = 3000000;
		["Pot Hotspot"] = 1;
		["Bombombini Gusini"] = 1;
	};
}









return Rebirths
