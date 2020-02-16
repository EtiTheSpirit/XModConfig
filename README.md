# XModConfig
An API allowing starbound mods to be configured.

**See the branches of this repo for components.**
- **API Component:** [CLICK HERE](https://github.com/XanTheDragon/XModConfig/tree/API)
- **Root Systems Component:** [CLICK HERE](https://github.com/XanTheDragon/XModConfig/tree/RootSys)
- **GUI Component:** [CLICK HERE](https://github.com/XanTheDragon/XModConfig/tree/Interface)

## On Steam
* https://steamcommunity.com/sharedfiles/filedetails/?id=1998921194
* steam://url/CommunityFilePage/1998921194

# Features

## Simple and straightforward API!
You already go through enough crap when it comes to making Starbound mods work. I've got no interest in making that job any harder. It's (ideally) got good enough documentation to make the process of learning to use + implementing this API easy Please do not hesitate to create an issue requesting better documentation if confusion or difficulty arises!

## Easy setup!
Implementing configs into your mods is as easy as writing a simple patch file, and writing code to handle known config values. The code does the rest of the work for you. All you need to worry about is handling config flags in your code. You can get a template of the patch file [HERE (click here)](https://github.com/XanTheDragon/XModConfig/blob/RootSys/XMODCONFIG.config.patch-example)

## Compatible with both Lua modes -- safe and unsafe -- with added features for unsafe Lua!

***

**⚠️ WARNING ⚠️** 

Unsafe Lua is incredibly dangerous! It is best to treat it similarly to a firearm; never assume it is safe, and always practice extreme discretion and care when using it.
- **Never** enable unsafe Lua unless you have **manually checked to see that none of your mods contain malicious code**, and/or you are **willing to risk potential catastrophic and irreversible damage to your computer** should a mod employ the use of malicious code. **You have been warned!**

For your own safety, I will not be showing how to enable this feature. Any damage caused by other mods is not my responsibility. By enabling unsafe Lua, you acknowledge the potential dangers! Although I can personally assure you this mod does not employ malicious code, you should still check yourself because this is a serious security concern for everyone. Please be safe!

***

Are you a private individual who works on your own mods for you and your group of friends? Disgruntled that Starbound doesn't let you reference the player from any context and use logical sides (client/server) to streamline what you can and can't reference? Me too. Enabling Unsafe Lua allows the mod to create a global config file that can be referenced from any Lua context.
 - This creates `%appdata%\.StarboundModConfigs\YOUR-MOD-NAME-HERE\config.cfg` on Windows
 - This creates `~\.StarboundModConfigs\YOUR-MOD-NAME-HERE\config.cfg` on Unix and OS-X.
 
 
# Getting Started

To use XModConfig, download the API, GUI, and RootSys components. Put these into your mods folder.

When you ship your mod, you can include the API with it, and it will function even if the user doesn't have the GUI addon. This allows your mods to safely function in their own little sandbox with config data without worry of interference because the user doesn't have the config systems.

You will want to begin by patching XMODCONFIG.config to tell the system what configuration values your mod has. Refer to the RootSys repository for an example patch file.

After you have your patch file ready, which should be placed in the root of your mod directory, you can begin implementing the code. This is where the API section comes in handy. Refer to `__example/UseConfig.lua` for a bare-bones usage example for using mod configs in lua. **Please keep in mind that for safe Lua contexts, it only works when there is a player, or there is world + entity where entity is the player.**

After setting up the patch + the in-code handling for various config data, you are done! You've just implemented configurations into your mod.
