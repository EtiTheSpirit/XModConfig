-- Written by Xan the Dragon // Eti the Spirit 2020
-- Public API for mod configuration.

-- XModConfig offers a solid and clean standard for allowing users to configure mod settings on a per-character basis.
-- It enforces a strict standard and will provide modders with the necessary information to debug incorrect use of this mod.

--[[
	API:
		require("scripts/api/XModConfig")
		Configuration = XModConfig:Instantiate("Your unique mod name here")
		
		This will return a *value-synchronised object* (yes, even across separate scripts!) that represents the local mod config.
		IMPORTANT NOTICE: This object is NOT equal to any other configs! It is simply populated with the same data, so if you call Set("foo", "bar") in one script and Get("foo") in another, it will still return "bar" due to it
		directly reading and writing to and from player data (or raw config json if unsafe lua is enabled).
		
		This constructor will error if:
			- You do not specify a name as a string
			- The string is empty
			- The string is only whitespace
			- The string violates filesystem name rules. The allowed characters are a-z A-Z 0-9 -+_, and the maximum length is 32.
			- It is called before sb exists in the current context (It must be called after the current environment's init() function finishes.)
		
		This object is called a ConfigContainer.
		
			Properties of XModConfig:
				player XModConfig.Player [readonly]
					A reference to the current active player. This will be nil if ReferenceType is not 0.
					
				int XModConfig.EntityId [readonly]
					A reference to the current active player's entity ID. This will be nil if ReferenceType is not 1.
					
				int ReferenceType [readonly]
					Primarily used internally, but exposed publicly as a "just in case". 
					If this is 0, XModConfig.Player was acquired via a direct reference to the player global.
					If this is 1, XModConfig.Player could not be acquired, but world & entity globals exist and entity references the player.
					If this is 2, XModConfig.Player could not be acquired, and if entity exists, it's not the player. Config will be unusable here if this is the case.
					If this is 3, a player nor an entity was required due to unsafe lua being enabled.
					
				bool IsUnsafeLuaEnabled [readonly]
					Will be true if Starbound currently allows unsafe Lua to be executed, exposing groups like io for raw filesystem access.
					
			Methods of XModConfig:
				ConfigContainer Instantiate(string modName)
					Instantiates a new ConfigContainer from the specified mod name. 
					This mod name will be appended as a prefix to all keys in player data persistence to disambiguate keys. It is recommended that you keep it simple, but otherwise unique to your mod.
					This will error if modName is nil, modName is not a string, or modName is empty.
					This will also error if the current context that this is called from does not contain a reference to either: player, or world&entity (both are needed if player is not available)
					
					
				table GetConfigurableMods()
					Gets the array of configurable mods from the patched XMODCONFIG.config file.
					This table has a unique structure that looks a bit like this:
					{
						["ModsWithConfig"] = {...} -- JSON patches here.
						["ModList"] = {} -- All of the keys in ModsWithConfig.
					}
					
					
			Properties of ConfigContainer (Inherits XModConfig properties)
				string ModName [readonly]
					The specified name that :Instantiate() was called with.
					
				table RawJSON
					This will be nil if IsUnsafeLuaEnabled is false, and setting it will do nothing in this case.
					This is only used when unsafe lua is enabled and a custom config file is being referenced. Tampering with it will result in desyncs. Use the Get and Set methods to edit it.
					
			Methods of ConfigContainer:
				void Set(string key, Variant value)
					Sets the specified config key to contain the specified value via calling player.setProperty
				
				Variant Get(string key, [Variant defaultValue = nil], [bool setIfDoesntExist = false])
					Gets the value associated with the specified config key via calling player.getProperty
					If this key does not have an associated value or is equal to empty json ({}), it will return nil.
					If defaultValue is specified, it will return defaultValue if the key does not have a value
					if setIfDoesntExist is true, this will call Set(key, defaultValue) if the data was nil. This will do nothing if defaultValue is nil.
					
				void Remove(string key)
					Removes the specified config key from the saved config data. This is identical to calling Set(key, nil)
					
--]]
require("/scripts/api/json.lua")

-- https://youtu.be/vXOUp0y9W4w?t=191

local LUA_ERROR = error
THROW_LUA_ERROR_ON_ERR_AND_ASSERT = true
TOSTRING_USES_SB_PRINT = true
local print, warn, error, assertwarn, assert, tostring; -- Specify these as locals
require("/scripts/xcore_modconfig/LoggingOverride.lua") -- tl;dr I can use print, warn, error, assert, and assertwarn

XModConfig = {}
XModConfig.IsUnsafeLuaEnabled = pcall(os.execute) 
XModConfig.__index = XModConfig
XModConfig.__newindex = function (tbl, key, value) 
	if key ~= "RawJSON" then 
		error("Can't set value")
	else
		rawset(tbl, key, value)
	end
end
-- Before one of yall gets all batshit mad at me for using a function for an indexing metamethod
-- 1: silence, liberal
-- 2a: any person that's setting things in XModConfig OR in a ConfigContainer is violating standards.
-- 2b: I've completely been run outta fucks to give when it comes to performance issues that occur from people are doing the one thing they *aren't* supposed to be doing

--------------------------------
---- CORE UTILITY FUNCTIONS ----
--------------------------------

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
		configContainer.RawJSON = JSONSerializer:JSONDecode(file:read("*a"))
		file:close()
	end
	XModConfig.ReferenceType = 3
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
			XModConfig.Player = player
			XModConfig.ReferenceType = 0
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
					XModConfig.EntityId = entity.id()
					XModConfig.ReferenceType = 1
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
				XModConfig.ReferenceType = 2
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
					XModConfig.EntityId = entity.id()
					XModConfig.ReferenceType = 1
					configContainer.EntityId = entity.id()
					configContainer.ReferenceType = 1
					return
				end
			end
			
			error("Cannot reference configs from this context. Could not find the player from entity ID alone, since no applicable ID could be located.")
			XModConfig.ReferenceType = 2
			configContainer.ReferenceType = 2
			
		-- a
		else
			XModConfig.ReferenceType = 2
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
	self.RawJSON = JSONSerializer:JSONDecode(hook:read("*a"))
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
	print, warn, error, assertwarn, assert, tostring = CreateLoggingOverride("[XModConfig]")
	if sb == nil and LUA_ERROR ~= nil then
		LUA_ERROR("ERROR: Cannot call instantiate() before a script's init function has been called! (Global var sb does not exist.)")
		return
	end


	-- dumby block head stopper tron 3000
	assert(VerifyModName(modName), "The specified mod name is invalid. Cannot create a configuration reference.")
	
	local object = {
		ModName = modName
	}
	InitializationSetup(modName, object)
	setmetatable(object, XModConfig)
	
	-- Late data population: Set up the default data / load the existing data.
	if self.ReferenceType ~= 2 then	
		-- Let's populate our data.
		local cfgMods = self:GetConfigurableMods().ModsWithConfig
		local config = cfgMods[modName]
		assert(config ~= nil, string.format("Could not locate mod name %s in list of configurable mods. Did you specify the correct name? Did you remember to create XMODCONFIG.config.patch?", modName))
		
		-- https://youtu.be/vXOUp0y9W4w?t=478
		-- https://youtu.be/vXOUp0y9W4w?t=478
		-- https://youtu.be/vXOUp0y9W4w?t=478
		
		for index = 1, #config.ConfigInfo do
			local configData = config.ConfigInfo[index]
			-- Did I ever tell you what the definition of insanity is?
			-- MandateType(value, requiredType, paramName, nullable)
			MandateType(configData.key, "string", "key", false)
			MandateNotType(configData.default, "table", "default", true)
			MandateType(configData.enforceType, "boolean", "enforceType", true)
			if configData.enforceType == true and configData.default == nil then
				error(string.format("Type enforcement for config key %s is on, but it doesn't have a default value to get this type from!", configData.key))
			end
			
			MandateType(configData.limits, "table", "limits", true)
			if configData.limits ~= nil then
				local len = #configData.limits
				assert(len == 2 or len == 3, "Invalid length for JSON parameter 'limits' - Expected a length of 2 or 3.")
				
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

-- Returns a list of mods that patch /XMODCONFIG.config and add their name + configurable properties to the configurable mods list.
-- This table has an index added to it called "ModList" which is a list of all the registered mod names.
function XModConfig:GetConfigurableMods()
	-- Make sure we're good to go first.
	if sb then print, warn, error, assertwarn, assert, tostring = CreateLoggingOverride("[XModConfig]") end
	
	local cfg = root.assetJson("/XMODCONFIG.config")
	local keys = {}
	for key in pairs(cfg.ModsWithConfig) do
		table.insert(keys, key)
		if print then print(string.format("Added %s to mod registry.", key)) end 
		-- ^ Sometimes this might be called before init which is supposed to be safe for this function, so worst case scenario it's not and the condition up top fails.
	end
	cfg.ModList = keys
	return cfg
end

-- Set the specified key to the specified value.
function XModConfig:Set(key, value)
	assert(getmetatable(self) == XModConfig, ERR_NOT_INSTANCE:format("Set", "XModConfig::Instantiate"))
	if self.IsUnsafeLuaEnabled then
		SetUnsafe(self, key, value)
	else
		Set(self, key, value)
	end
end

-- Get the value stored in the specified key, or defaultValue if it is not specified (or nil if defaultValue isnt specified)
function XModConfig:Get(key, defaultValue, setIfDoesntExist)
	assert(getmetatable(self) == XModConfig, ERR_NOT_INSTANCE:format("Get", "XModConfig::Instantiate"))
	if self.IsUnsafeLuaEnabled then
		return GetUnsafe(self, key, defaultValue, setIfDoesntExist == true)
	else
		return Get(self, key, defaultValue, setIfDoesntExist == true)
	end
end

-- Remove the specified config key from the saved config data. Will do nothing if the key doesn't exist.
function XModConfig:Remove(key)
	assert(getmetatable(self) == XModConfig, ERR_NOT_INSTANCE:format("Remove", "XModConfig::Instantiate"))
	if self.IsUnsafeLuaEnabled then
		RemoveUnsafe(self, key)
	else
		Remove(self, key)
	end
end