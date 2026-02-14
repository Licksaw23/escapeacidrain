-- Funny number shortener and comma adder for numbers. very op. made by Denis

local module = {}

local suffixes = {"k", "m", "b", "t", "q","Qi","Sx","Sp","Oc","No","Dc","Dd"}
function module.roundNumber(no)
	if no and type(no) == "string" then return no end 

	if no and no > 0 then
		local exponent = math.floor(math.log(no, 1e3))
		local scaled = no / (1000 ^ exponent)

		-- Round to 1 decimal place
		local rounded = math.floor(scaled * 10 + 0.5) / 10

		local suffix = suffixes[exponent] or ""

		-- Format: show 1 decimal only if it's not .0
		local finalNr
		if rounded % 1 == 0 then
			finalNr = string.format("%d", rounded) .. suffix  -- No decimal (e.g., "5K")
		else
			finalNr = string.format("%.1f", rounded) .. suffix  -- 1 decimal (e.g., "5.2K")
		end

		if finalNr == "nan" then return "0" end

		return finalNr
	end

	return "0"
end
function module.comma(amt)
	if amt and type(amt) == "string" then return amt end
	
	if amt and amt > 0 then
		local formatted = math.round(amt)
		local number = 0

		while true do  
			formatted, number = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
			if (number==0) then
				break
			end
		end

		return formatted
	end
	
	return "0"
end

local function roundNumber(num, numDecimalPlaces)
	return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
end

function module.shorten(amt, numDecimalPlaces)
	if amt and type(amt) == "string" then return amt end

	if amt and amt > 0 then
		return roundNumber(amt,numDecimalPlaces or 1)
	end
	
	return "0"
end

return module
