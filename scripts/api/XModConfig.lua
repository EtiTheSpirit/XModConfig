-- Written by Xan the Dragon // Eti the Spirit 2020
-- Public API for mod configuration.

-- XModConfig offers a solid and clean standard for allowing users to configure mod settings on a per-character basis.
-- It enforces a strict standard and will provide modders with the necessary information to debug incorrect use of this mod.

--[[

	NEW UPDATE: DO NOT REQUIRE THIS MODULE DIRECTLY UNLESS YOU REQUIRE YOUR USERS TO GET THIS MOD.
		If you want to optionally use XModConfig, get this script, which allows you to conditionally require it based on if it exists or not.
		https://github.com/XanTheDragon/XModConfig/blob/DEVELOPER_RESOURCES/scripts/xmodcfg_util/XModConfigProxy.lua

	API:
		https://github.com/XanTheDragon/XModConfig/wiki
					
--]]
require("/scripts/api/json.lua")

-- https://youtu.be/vXOUp0y9W4w?t=191

local LUA_ERROR = error
THROW_LUA_ERROR_ON_ERR_AND_ASSERT = true
TOSTRING_USES_SB_PRINT = true
local print, warn, error, assertwarn, assert, tostring; -- Specify these as locals
require("/scripts/xcore_modconfig/LoggingOverride.lua") -- tl;dr I can use print, warn, error, assert, and assertwarn

local HasCorruptInstall = nil
XModConfig = {}
XModConfig.IsUnsafeLuaEnabled = pcall(os.execute)
XModConfig.RawJSON = {}
XModConfig.__index = XModConfig
XModConfig.__newindex = function (tbl, key, value) error("Can't set value") end
-- Before one of yall gets all batshit mad at me for using a function for an indexing metamethod
-- 1: silence, liberal
-- 2a: any person that's setting things in XModConfig OR in a ConfigContainer is violating standards.
-- 2b: I've completely been run outta fucks to give when it comes to performance issues that occur from people are doing the one thing they *aren't* supposed to be doing

-------------------
---- CONSTANTS ----
-------------------

-- Format params: methodName, ctorName
local ERR_NOT_INSTANCE = "Cannot statically invoke method '%s' - It is an instance method. Call it on an instance of this class created via %s"

-- Format params: paramName, expectedType, actualType
local ERR_INVALID_TYPE = "Invalid type for JSON parameter '%s' (Expected %s, got %s)"

-- Format params: paramName, expectedType, actualType
local ERR_INVALID_TYPE_NULLABLE = "Invalid type for nullable JSON parameter '%s' (Expected nil or %s, got %s)"

-- Format params: paramName, notAllowedType
local ERR_INVALID_TYPE_INVERSE = "Invalid type for JSON parameter '%s' (This parameter explicitly does not support the use of %s)"

-- Format params: paramName, notAllowedType
local ERR_INVALID_TYPE_NULLABLE_INVERSE = "Invalid type for nullable JSON parameter '%s' (This parameter explicitly does not support the use of %s)"

-- Error for if this script exists but it's not installed properly due to root systems missing.
local ERR_ROOTSYS_NOT_INSTALLED = "XModConfig is not installed properly! It is currently missing the following required components: XModCfg_RootSys (Root Systems)"

-----------------------
---- STATIC MEMORY ----
-----------------------

-- A cached value for XModConfig:GetConfigurableMods()
local ConfigurableModsCache = nil

--------------------------------
---- CORE UTILITY FUNCTIONS ----
--------------------------------

-- Checks to see if all of the necessary components of XModConfig are installed.
-- Returns true if they are, false if they are not.
local function CheckForInstallStatus()
	if HasCorruptInstall == true then
		return false
	elseif HasCorruptInstall == false then
		return true
	elseif HasCorruptInstall == nil then

		-- If this is true, RootSys is installed.
		local successfullyGotSBConfig = pcall(function ()
			root.assetJson("/XMODCONFIG.config")
		end)
		
		-- At the moment, this is the only required library for the API.
		HasCorruptInstall = not successfullyGotSBConfig
		return successfullyGotSBConfig
	end
end

-- Alias function to automatically error out for invalid types.
local function MandateType(value, targetType, paramName, nullable)
	if nullable and value == nil then return end
	local fmt = nullable and ERR_INVALID_TYPE_NULLABLE or ERR_INVALID_TYPE
	assert(type(value) == targetType, fmt:format(paramName or "ERR_NO_PARAM_NAME", targetType, type(value)))
end

-- Alias function to automatically error out for invalid types, except it *can't* be the specified type
local function MandateNotType(value, targetType, paramName, nullable)
	if nullable and value == nil then return end
	local fmt = nullable and ERR_INVALID_TYPE_NULLABLE_INVERSE or ERR_INVALID_TYPE_INVERSE
	assert(type(value) ~= targetType, fmt:format(paramName or "ERR_NO_PARAM_NAME", targetType))
end

-- Verifies the integrity of the given config data.
local function VerifyIntegrityOf(configData)
	-- Did I ever tell you what the definition of insanity is?
	-- MandateType(value, requiredType, paramName, nullable)
	MandateType(configData.key, "string", "key", false)
	MandateNotType(configData.default, "table", "default", true)
	MandateType(configData.enforceType, "boolean", "enforceType", true)
	if configData.enforceType == true and configData.default == nil then
		error(string.format("Type enforcement for config key %s is on, but it doesn't have a default value to get this type from! Switching enforceType off.", configData.key))
		configData.enforceType = false
	end
	
	MandateType(configData.limits, "table", "limits", true)
	if configData.limits ~= nil then
		local len = #configData.limits
		if not assert(len == 2 or len == 3, "Invalid length for JSON parameter 'limits' - Expected a length of 2 or 3.") then return end
		
		-- A bit of a hack but...
		if configData.limits[1] == "inf" then configData.limits[1] = math.huge end
		if configData.limits[1] == "-inf" then configData.limits[1] = -math.huge end
		if configData.limits[2] == "inf" then configData.limits[2] = math.huge end
		if configData.limits[2] == "-inf" then configData.limits[2] = -math.huge end
		
		MandateType(configData.limits[1], "number", "limits[1]", false)
		MandateType(configData.limits[2], "number", "limits[2]", false)
		MandateType(configData.limits[3], "boolean", "limits[3]", true)
	end
	MandateType(configData.display, "table", "display", false)
	MandateType(configData.display.name, "string", "display.name", false)
	MandateType(configData.display.description, "string", "display.description", true)
	
	return configData
end

-- Iterates through all given patches to XMODCONFIG.config and ensures all values are compliant.
-- This also looks for instances where limits[] has a string value of "-inf" or "inf" and replaces it with -math.huge or math.huge respectively.
local function SanityCheckConfigInfoValues()
	-- ConfigurableModsCache contains ModsWithConfig and ModList.
	for modName, configInfoContainer in pairs(ConfigurableModsCache.ModsWithConfig) do
		-- Go through ModsWithConfig. Keys are mod names, values are {FriendlyName = text, ConfigInfo = {}}
		for index = 1, #configInfoContainer.ConfigInfo do
			VerifyIntegrityOf(configInfoContainer.ConfigInfo[index])
		end
		ConfigurableModsCache.ModsWithConfig[modName] = configInfoContainer
	end
end

-- Since RawJSON is readonly (that is, the actual value itself, NOT its contents), this clears it out.
local function PopulateRawJSON(cfgContainer, newData)
	-- Clear.
	for index in pairs(cfgContainer.RawJSON) do
		cfgContainer.RawJSON[index] = nil
	end
	
	-- Repopulate.
	for index, value in pairs(newData) do
		cfgContainer.RawJSON[index] = value
	end
end

-- Verifies the integrity of the mod name to ensure that it is safe for all filesystems.
local AllowedCharList = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+-_ "
local function VerifyModName(modName)
	if type(modName) ~= "string" then 
		error("modName is not a string. Cannot create a ConfigContainer")
		return false
	end
	
	if #modName > 32 then
		error("modName is too long. It should be less than or equal to 32 chars in length.")
		return false
	end
	
	if modName == "" then 
		error("modName is an empty string, which is not allowed. Cannot create a ConfigContainer")
		return false
	end
	
	if modName:gsub(" ", "") == "" then
		error("modName is only composed of spaces, which is not allowed. Cannot create a ConfigContainer")
		return false
	end
	
	for index = 1, #modName do
		local char = modName:sub(index, index)
		if not AllowedCharList:find(char) then
			error("modName includes invalid characters. Expected the name to only include characters from the ranges: a-z A-Z 0-9 -+_")
			return false
		end
	end
	
	return true
end

-- Credit: https://stackoverflow.com/a/40195356/5469033
-- Returns true if a file exists, and false if it does not with the specified error message as a second return value.
local function FileExists(file)
	local ok, err, code = os.rename(file, file)
	if not ok then
		if code == 13 then
			-- Permission denied, but it exists
			return true
		end
	end
	return ok, err
end

-- Returns true if the directory exists, and false if it does not.
local function DirExists(path)
	-- "/" works on both Unix and Windows
	return FileExists(path.."/")
end

-- spooky scary lua functions
-- Initialize the system if unsafe lua is enabled.
-- This locates the user's application data directory, creating a .StarboundModConfigs folder.
-- From this point, it creates a folder with the name of the specified mod name, and then creates a config.cfg file inside.
local function InitializationSetupIfLuaIsUnsafe(modName, configContainer)
	local isWindows = os.getenv("windir")
	
	print("Setting up directory and making a default config if necessary...")
	if isWindows then
		print("windir environment var found. Assuming this is a Windows install.")
		local appdata = os.getenv("appdata")
		if not appdata then
			error("ERROR: Could not find environment variable \"appdata\"! It is not possible to locate appdata at this time. Consider manually creating this environment variable. Set its value to the Roaming folder in appdata. (e.g. set it to C:\\Users\\Xan\\AppData\\Roaming)")
			return
		end
		local appdata = appdata:gsub("\\", "/")
		
		print("Creating a new directory (or referencing an existing directory) as " .. appdata .. "/.StarboundModConfigs/" .. modName)
		if not DirExists(appdata .. "/.StarboundModConfigs") then
			os.execute("mkdir \"" .. appdata .. "/.StarboundModConfigs\"")
		end
		if not DirExists(appdata .. "/.StarboundModConfigs/" .. modName) then
			os.execute("mkdir \"" .. appdata .. "/.StarboundModConfigs/" .. modName .. "\"")
		end
		
		configContainer.ConfigFilePath = appdata .. "/.StarboundModConfigs/" .. modName .. "/config.cfg"
		
		if not FileExists(configContainer.ConfigFilePath) then
			local file = io.open(appdata .. "/.StarboundModConfigs/" .. modName .. "/config.cfg", "w")
			file:write("{}")
			file:flush()
			file:close()
			print("Wrote default config file")
		end
		
		local file = io.open(configContainer.ConfigFilePath, "r")
		-- Don't need to use the safe function here.
		configContainer.RawJSON = JSONSerializer:JSONDecode(file:read("*a"))
		file:close()
	else
		print("windir environment var was not found. Assuming this is running in OSX or Linux")
		configContainer.ConfigFilePath = "~/.StarboundModConfigs/" .. modName .. "/config.cfg"
		os.execute("mkdir -p ~/.StarboundModConfigs/" .. modName)
		
		if not FileExists(configContainer.ConfigFilePath) then
			local file = io.open(appdata .. "/.StarboundModConfigs/" .. modName .. "/config.cfg", "w")
			file:write("{}")
			file:flush()
			file:close()
			print("Wrote default config file")
		end
		local file = io.open(configContainer.ConfigFilePath, "r")
		-- Don't need to use the safe function here.
		configContainer.RawJSON = JSONSerializer:JSONDecode(file:read("*a"))
		file:close()
	end
	configContainer.ReferenceType = 3
	print("Successfully populated JSON.")
end

-- Stock initialization.
-- This will set various values including if unsafe lua is enabled or not.
local function InitializationSetup(modName, configContainer)
	print("Initializing new XModConfig...")
	
	-- Ideally the warning in the mod description is enough to deter people, but just in case it isn't, give another logged warning.
	if XModConfig.IsUnsafeLuaEnabled then
		-- Unsafe lua is enabled, so warn them (again) because it's really not safe for generalized usage, and then jump to the unsafe init function.
		warn("ALERT: UNSAFE LUA IS ENABLED! This may have unintended reprocussions if other mods employ the use of malicious code!")
		InitializationSetupIfLuaIsUnsafe(modName, configContainer)
	else
		-- Unsafe lua is disabled, so perform stock init by trying to grab player OR world&entity.
		print("Unsafe lua is not enabled. Attempting to use a player to store data...")
		
		-- But a player ref is a *little* harder to deal with. That's OK!
		-- First off: Does player just flat out exist in the current context?
		if player ~= nil then
			-- YIPPIEKEYHEEAYPEIYEKAIYO
			print("Player exists in current context! Grabbing a direct reference.")
			configContainer.Player = player
			configContainer.ReferenceType = 0
			
		-- Second case: Does a reference to entity exist (and the world)?
		elseif world ~= nil then
			print("World exists!")
			if entity then
				print("A reference to entity exists too!")
				local promise = world.sendEntityMessage(entity.id(), "isThisMyPlayer")
				if promise:succeeded() then
					print("It is! Using an indirect reference.")
					configContainer.EntityId = entity.id()
					configContainer.ReferenceType = 1
					return
				end
			end
			
			-- If the code makes it here, entity is nil OR the entity wasn't the player.
			print("Attempting to get a player entity by going through the available players.")
			if world.players == nil then
				-- This nil check is here because world.md says this exists but it's always nil when I try to reference it.
				-- I had someone tell me it doesn't exist.
				-- Then I had someone else telling me it does exist and it's me "misusing it" being the reason that it's not working.
				-- However the hell you misuse a function by calling it is beyond me, unless it was some insane method of saying "you're calling a function that doesn't exist".
				-- Both sides were stingy about it so I'm just gonna do it this way. I'm a solid 60% sorry if this kind of code bothers you. It'd bother me too.
				
				error("here lies world.players -- he ran fast, and ceased to exist. (Config errored and the player could not be located)")
				configContainer.ReferenceType = 2
				return
			end
			local playerIds = world.players()
			
			-- This method is particularly yucky imo, and I'd like to get a better method if possible.
			-- Effectively this relies on two facts:
			-- #1: this is a localHandler
			-- #2: localHandlers have instant returns, networked calls do not
			-- The basic gist is that I can call this event on my player. All other players will have this message registered, just locally, so it should not succeed unless it's explicitly called on my own entity.
			for index = 1, #playerIds do
				local promise = world.sendEntityMessage(entity.id(), "isThisMyPlayer")
				if promise:succeeded() then
					print("Found me!")
					configContainer.EntityId = entity.id()
					configContainer.ReferenceType = 1
					return
				end
			end
			
			error("Cannot reference configs from this context. Could not find the player from entity ID alone, since no applicable ID could be located.")
			configContainer.ReferenceType = 2
			
		-- a
		else
			configContainer.ReferenceType = 2
			-- WHAT IS EXISTENCE?!
			-- HELP!!!!
			-- WHO IS PLAYER?!
			-- WHERE IS WORLD!?
			-- WHO AM I?!
			-- *WHAT* AM I?!
			-- https://youtu.be/bz92R5ptZRE?t=70
			error("Cannot reference configs from the current context. It does not include a direct reference to a player. It also does not contain a reference to entity and world. Without at least one of these two (player vs. entity & world), mod config data cannot be accessed.")
		end
	end
end

---------------------------------------
---- JSON UTILITIES FOR UNSAFE LUA ----
---------------------------------------

-- Writes JSON data to the config file. Unsafe lua only.
local function WriteJSONToFile(self)
	local hook = io.open(self.ConfigFilePath, "w")
	hook:write(JSONSerializer:JSONEncode(self.RawJSON))
	hook:flush()
	hook:close()
end

-- Reads JSON data from the config file. Unsafe lua only.
local function ReadJSONFromFile(self)
	local hook = io.open(self.ConfigFilePath, "r")
	PopulateRawJSON(self, JSONSerializer:JSONDecode(hook:read("*a")))
	hook:close()
end

----------------------
---- DATA CONTROL ----
----------------------

-- Set config for unsafe lua. Directly writes to a json file.
local function SetUnsafe(self, key, value)
	if type(key) ~= "string" then
		error("Config keys must be strings.")
		return
	end
	if type(value) == "userdata" then
		error("Cannot store userdata.")
		return
	end
	self.RawJSON[key] = value
	
	WriteJSONToFile(self)
	print(string.format("Key %s had its value changed to %s", key, tostring(value)))
end

-- Get config for unsafe lua. Directly reads from a json file.
local function GetUnsafe(self, key, defaultValue, setIfDoesntExist)
	if type(key) ~= "string" then
		error("Config keys must be strings.")
		return
	end
	ReadJSONFromFile(self) -- This is needed for sync behavior.
	
	local jsonData = self.RawJSON[key]
	if jsonData ~= nil and defaultValue ~= nil and type(defaultValue) ~= type(jsonData) then
		warn(string.format("Type mismatch for defaultValue and stored json data in key %s. This could cause unwanted behavior!", key))
	end
	if jsonData == nil and defaultValue ~= nil and setIfDoesntExist then
		SetUnsafe(self, key, defaultValue)
	end
	return self.RawJSON[key] or defaultValue
end

-- Remove config for unsafe lua.  Directly writes to a json file.
local function RemoveUnsafe(self, key)
	SetUnsafe(self, key, nil)
end

-- Set config data for safe Lua. Uses player.setProperty
local function Set(self, key, value)
	if type(key) ~= "string" then
		error("Config keys must be strings.")
		return
	end
	
	if type(value) == "userdata" then
		error("Cannot store userdata.")
		return
	end
	
	if self.ReferenceType == 0 then
		player.setProperty(self.ModName .. key, value)
	elseif XModConfig.ReferenceType == 1 then
		world.sendEntityMessage(self.EntityId, "setProperty", self.ModName .. key, value)
	else
		error("Can't use configs from this context!")
		return
	end
	print(string.format("Key %s had its value changed to %s", key, tostring(value)))
end

-- Get config data for safe Lua. Uses player.getProperty
local function Get(self, key, defaultValue, setIfDoesntExist)
	if type(key) ~= "string" then
		error("Config keys must be strings.")
		return
	end
	
	local data;
	if self.ReferenceType == 0 then
		data = player.getProperty(self.ModName .. key)
	elseif XModConfig.ReferenceType == 1 then
		data = world.sendEntityMessage(self.EntityId, "getProperty", self.ModName .. key):result()
	else
		error("Can't use configs from this context!")
		return
	end
	
	if data ~= nil and defaultValue ~= nil and type(defaultValue) ~= type(data) then
		warn(string.format("Type mismatch for defaultValue and stored json data in key %s. This could cause unwanted behavior!", key))
	end
	if data == nil and defaultValue ~= nil and setIfDoesntExist then
		Set(self, key, defaultValue)
	end
	return data or defaultValue
end

-- Remove config data for safe Lua. Uses player.setProperty
local function Remove(self, key)
	Set(self, key, nil)
end

------------------------------------------------
------------------------------------------------
------------------------------------------------

-- Instantiate new config object. The specified mod name must be the same as the mod name patched into XMODCONFIG.config
function XModConfig:Instantiate(modName)
	if sb == nil and LUA_ERROR ~= nil then
		LUA_ERROR("ERROR: Cannot call instantiate() before a script's init function has been called! (Global var sb does not exist.)")
		return
	end
	print, warn, error, assertwarn, assert, tostring = CreateLoggingOverride("[XModConfig]")
	
	-- dumby block head stopper tron 3000
	if not assert(VerifyModName(modName), "The specified mod name is invalid. Cannot create a configuration reference.") then return end
	
	-- New catch case: Is the thing installed properly?
	-- This populates XModConfig.ReferenceType as well.
	if not assert(CheckForInstallStatus(), ERR_ROOTSYS_NOT_INSTALLED) then return end
	
	local object = {
		ModName = modName
	}
	InitializationSetup(modName, object)
	setmetatable(object, XModConfig)
	
	-- Late data population: Set up the default data / load the existing data.
	if object.ReferenceType ~= 2 then
		-- Let's populate our data.
		local allMods = self:GetConfigurableMods()
		-- print(JSONSerializer:JSONEncode(allMods))
		local cfgMods = allMods.ModsWithConfig
		local config = cfgMods[modName]
		if not assert(config ~= nil, string.format("Could not locate mod name %s in list of configurable mods. Did you specify the correct name? Did you remember to create XMODCONFIG.config.patch?", modName)) then return end
		
		-- https://youtu.be/vXOUp0y9W4w?t=478
		-- https://youtu.be/vXOUp0y9W4w?t=478
		-- https://youtu.be/vXOUp0y9W4w?t=478
		
		for index = 1, #config.ConfigInfo do
			local configData = config.ConfigInfo[index]
			
			-- If we've made it here, config data is OK!
			local value = object:Get(configData.key, configData.default, true)
			if type(value) ~= type(configData.default) and configData.default ~= nil and configData.enforceType == true then
				warn("Type mismatch for the stored config data in key %s and the default value in the mod's config data specification! Since this key enforces its type, the config data under this key will be set to the default value.")
				object:Set(configData.key, configData.default)
			end
			
			if type(value) == "number" then
				-- This is a number, is it compliant with limits?
				if configData.limits then
					local min = configData.limits[1]
					local max = configData.limits[2]
					local round = configData.limits[3]
					if min and max then
						local oldValue = value
						if round == true then
							value = math.min(value + 0.5)
						end
						if value < min or value > max then
							value = math.max(min, math.min(max, value))
							warn("Value is out of range! It is equal to %s, but the min and max are %s and %s. It will be clamped to %s", tostring(oldValue), tostring(min), tostring(max), tostring(value))
							object:Set(configData.key, value)
						end
					end
				end
			end
		end
	end
	
	return object
end

-- Returns nil if unsafe lua is inactive and this value cannot be acquired. Returns true if the current OS is Windows, false if it is not (OSX or Linux)
function XModConfig:IsWindows()
	self.IsUnsafeLuaEnabled = pcall(function () os.getenv("windir") end)
	if not self.IsUnsafeLuaEnabled then return end
	return os.getenv("windir") ~= nil
end

-- Returns a list of mods that patch /XMODCONFIG.config and add their name + configurable properties to the configurable mods list.
-- This table has an index added to it called "ModList" which is a list of all the registered mod names.
function XModConfig:GetConfigurableMods()
	-- Make sure we're good to go first.
	if not CheckForInstallStatus() then
		error(ERR_ROOTSYS_NOT_INSTALLED)
		return
	end
	
	if sb then print, warn, error, assertwarn, assert, tostring = CreateLoggingOverride("[XModConfig]") end
	
	if ConfigurableModsCache then
		return ConfigurableModsCache
	end
	
	local cfg = root.assetJson("/XMODCONFIG.config")
	local keys = {}
	for key in pairs(cfg.ModsWithConfig) do
		table.insert(keys, key)
		if print then print(string.format("Added %s to mod registry.", key)) end 
		-- ^ Sometimes this might be called before init which is supposed to be safe for this function, so worst case scenario it's not and the condition up top fails.
	end
	cfg.ModList = keys
	
	ConfigurableModsCache = cfg
	SanityCheckConfigInfoValues()
	
	return ConfigurableModsCache
end

-- Set the specified key to the specified value.
function XModConfig:Set(key, value)
	-- Doesn't need rootsys sanity check because of the line literally right after this comment (it requires an instance, which won't be given if it's not installed properly)
	assert(getmetatable(self) == XModConfig, ERR_NOT_INSTANCE:format("Set", "XModConfig::Instantiate"))
	if self.IsUnsafeLuaEnabled then
		SetUnsafe(self, key, value)
	else
		Set(self, key, value)
	end
end

-- Get the value stored in the specified key, or defaultValue if it is not specified (or nil if defaultValue isnt specified)
function XModConfig:Get(key, defaultValue, setIfDoesntExist)
	-- Doesn't need rootsys sanity check because of the line literally right after this comment (it requires an instance, which won't be given if it's not installed properly)
	assert(getmetatable(self) == XModConfig, ERR_NOT_INSTANCE:format("Get", "XModConfig::Instantiate"))
	if self.IsUnsafeLuaEnabled then
		return GetUnsafe(self, key, defaultValue, setIfDoesntExist == true)
	else
		return Get(self, key, defaultValue, setIfDoesntExist == true)
	end
end

-- Remove the specified config key from the saved config data. Will do nothing if the key doesn't exist.
function XModConfig:Remove(key)
	-- Doesn't need rootsys sanity check because of the line literally right after this comment (it requires an instance, which won't be given if it's not installed properly)
	assert(getmetatable(self) == XModConfig, ERR_NOT_INSTANCE:format("Remove", "XModConfig::Instantiate"))
	if self.IsUnsafeLuaEnabled then
		RemoveUnsafe(self, key)
	else
		Remove(self, key)
	end
end