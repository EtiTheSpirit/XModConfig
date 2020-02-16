-- Written by Xan the Dragon // Eti the Spirit [RBX 18406183]
-- Attempts to get an XModConfig safely by performing a late require.

-- Internal reference to XModConfig
local InternalXModConfigCache = nil

-- Global: Is XModConfig installed? This will be nil if it hasn't been tested, false if it is not, and true if it is.
XMODCONFIG_IS_INSTALLED = nil

-- Internal function to try to get XModConfig. Returns nil if it's not installed, and returns the table of XModConfig if it is.
function TryGetXModConfig() 
	if InternalXModConfigCache ~= nil then
		return InternalXModConfigCache
	end
	
	if XMODCONFIG_IS_INSTALLED == false then
		return
	end
	
	local successful = pcall(require, "/scripts/api/XModConfig.lua")
	if successful and XModConfig ~= nil then
		XMODCONFIG_IS_INSTALLED = true
		InternalXModConfigCache = XModConfig
		return XModConfig
	else
		XMODCONFIG_IS_INSTALLED = false
		return nil
	end
end
