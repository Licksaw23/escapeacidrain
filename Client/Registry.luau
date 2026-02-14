local modules = {}

modules.Registered = {}

modules.Register = function(mod)
	local succ, err = pcall(function()
		modules.Registered[mod.Name] = require(mod)
	end)

	if err then print(err) end
	
	return modules.Registered[mod.Name]
end

return modules