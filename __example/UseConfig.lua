-- This example is going to be treated like a player init script.
require("/scripts/api/XModConfig.lua")


-- Let's pretend this code is in a function that runs after init() is finished.

-- To use configs we need one of two things:
-- 1: A context where the player global is defined
-- 2: A context where the world global is defined, and either..
-- 2a: entity is defined and is the player's entity, OR
-- 2b: an entity representing the player can be found in the world

-- Instantiate is called to create a reference to your configuration. The specified name of the mod must be identical to the one specified in the patch file.
-- Ideally speaking, this name is identical to your mod's internal name specified in _metadata.
-- Refer to https://github.com/XanTheDragon/XModConfig/blob/RootSys/XMODCONFIG.config.patch-example if you need more information on this patch file and how it works.
-- As mentioned in this example and just above, the string name here must be identical to the key in the patch file. If it's not, this method will throw an error.
local MyModConfig = XModConfig:Instantiate("MyModName")

-- Now that we have a reference to the mod configuration object, we need to *do* stuff with it.
-- If we specified a proper config patch, we can optionally define a default value.
-- For demonstration's sake, let's assume we have this patch:
--[[

[
	{ 
		"op": "add", 
		"path": "/ModsWithConfig/MyModName", 
		"value": {
			"ConfigInfo" : [
				{
					"key" : "myReallyCoolKey",
					"default" : true,
					"enforceType" : true,
					"display" : {
						"name" : "Enable Cool Kid Mode",
						"description" : "If enabled, you will be the coolest kid on the block."
					}
				},
				{
					"key" : "myNumber",
					"default" : 50,
					"enforceType" : true,
					"limits" : [0, 100, true],
					"display" : {
						"name" : "My Number",
						"description" : "I'm thinking of a whole number between 0 and 100..."
					}
				}
			]
		}
	}
]

]]--

-- Note that enforceType is true and default is true too in that first config.
-- By extension, even if we've never set the value, we can reference the value...
local myValue = MyModConfig:Get("myReallyCoolKey")
-- and myValue will be true since that's the default, and it's (presumably) never been loaded before.
-- If this is set to a different value via...
MyModConfig:Set("myReallyCoolKey", false)
-- ... then, for obvious reasons, the Get statement will NOT return true, and will instead return false.


-- Now do mind: If there are configs you want to keep secret, it *is* possible to set and get keys that are not specified in your patch.
local myValue = MyModConfig:Get("ThisKeyDoesntExist", 69, true)
-- Since this key has no known default, we must manually specify a default (unless we want a nil value if it doesn't exist), which is determined by the second parameter (69).
-- The third parameter is a boolean. If it is true, it will also SET the config key to the given default value if it doesn't exist, populating the data ahead of time.

-- Now what if I want to remove one of these hidden keys?
MyModConfig:Remove("ThisKeyDoesntExist")
-- ... can be called to remove a config key. This is identical to...
MyModConfig:Set("ThisKeyDoesntExist", nil)
-- ... but uses the mnemonic of "Remove" for the sake of ease on your end as the developer.


-- In the second example, we make use of the limits tag. This tag is used to limit a numeric value.
-- DO NOTE: This limit is **EXCLUSIVELY ENFORCED IN THE CONFIG GUI.**
-- There is NO protection on this value on the code end!
-- This means that:
MyModConfig:Set("myNumber", 9999999999)
-- is perfectly valid, even though the max is 100, and also...
MyModConfig:Get("myNumber")
-- ... will return 9999999999 without worrying about clamping the value.
-- Do note, "clamping" refers to both min/max AND the whole number limitation (the third, boolean value stored in limits). So if you set this to a decimal, it will load the decimal, even if whole number enforcement is true.
-- Please be careful with this, and sanity check your values!

-- HOWEVER, when the developer *loads* this config data at any time via the Instantiate() method, all saved data in known + documented keys (keys specified in the patch file) will be sanity checked.
-- If myNumber is still 9999999999 when we call Instantiate(), a warning will be placed into starbound.log stating:
-- [Warn] Value is out of range! It is equal to 9999999999, but the min and max are 0 and 100. It will be clamped to 100
-- It will also enforce whole number status, if applicable.