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
	
	-- on god if one of you "optimizes" this by setting it to "not XMODCONFIG_IS_INSTALLED" i'm gonna smack you
	-- "but why" nigga did you not read line 7
	if XMODCONFIG_IS_INSTALLED == false then
		return
	end
	
	-- IMPORTANT NOTICE: THIS STILL THROWS AN ERROR IN STARBOUND.LOG, BUT IT DOES ***NOT*** STOP SCRIPT EXECUTION.
	-- Despite being wrapped in pcall, starbound displays an error message, but thankfully (THANKFULLY. jfc chucklefish) this doesn't brick the script.
	-- So just to help you and your users out, assuming you have been blessed with remotely intelligent users...
	if sb then 
		sb.logWarn("\n=========================================================================================\n=========================================================================================\nIf an AssetException was thrown below reporting \"No such asset '/scripts/api/XModConfig.lua'\", IGNORE THE ERROR. An error is COMPLETELY EXPECTED to occur if the user does not have XModConfig installed.\n\n >>>>> THIS ERROR DOES NOT TERMINATE SCRIPT EXECUTION. DO NOT REPORT IT AS A BUG TO YOUR MOD AUTHOR. <<<<<\n >>>>> THIS ERROR DOES NOT TERMINATE SCRIPT EXECUTION. DO NOT REPORT IT AS A BUG TO YOUR MOD AUTHOR. <<<<<\n >>>>> THIS ERROR DOES NOT TERMINATE SCRIPT EXECUTION. DO NOT REPORT IT AS A BUG TO YOUR MOD AUTHOR. <<<<<\n\n")
	end
	local successful = pcall(require, "/scripts/api/XModConfig.lua")
	
	-- Expect bug reports anyway
	-- "If you idiotproof something, someone will just invent a better idiot" -- I can't remember lol
	
	if successful and XModConfig ~= nil then
		XMODCONFIG_IS_INSTALLED = true
		InternalXModConfigCache = XModConfig
	else
		XMODCONFIG_IS_INSTALLED = false
		if sb then 
			sb.logWarn("If an AssetException was thrown above reporting \"No such asset '/scripts/api/XModConfig.lua'\", IGNORE THE ERROR. An error is COMPLETELY EXPECTED to occur if the user does not have XModConfig installed.\n\n >>>>> THIS ERROR DOES NOT TERMINATE SCRIPT EXECUTION. DO NOT REPORT IT AS A BUG TO YOUR MOD AUTHOR. <<<<<\n >>>>> THIS ERROR DOES NOT TERMINATE SCRIPT EXECUTION. DO NOT REPORT IT AS A BUG TO YOUR MOD AUTHOR. <<<<<\n >>>>> THIS ERROR DOES NOT TERMINATE SCRIPT EXECUTION. DO NOT REPORT IT AS A BUG TO YOUR MOD AUTHOR. <<<<<\n")
		end
		sb.logWarn("If you report it anyway, please refer to https://youtu.be/CGnYWBJHRzM?t=46\n\n")
	end
	
	if sb then
		sb.logWarn("\n=========================================================================================\n=========================================================================================")
	end
	
	return InternalXModConfigCache
end
