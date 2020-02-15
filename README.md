# XModConfig
An API allowing starbound mods to be configured.

**See the branches of this repo for components.**
- **API Component:** [CLICK HERE](https://github.com/XanTheDragon/XModConfig/tree/API)
- **Root Systems Component:** [CLICK HERE](https://github.com/XanTheDragon/XModConfig/tree/RootSys)
- **[Incomplete] GUI Component:** [CLICK HERE](https://github.com/XanTheDragon/XModConfig/tree/Interface)

# Features

### Simple and straightforward API!
You already go through enough crap when it comes to making Starbound mods work. I've got no interest in making that job any harder. It's (ideally) got good enough documentation to make the process of learning to use + implementing this API easy, but if you are confused / get stuck at any point, please do not hesitate to create an issue requesting better documentation! I'm more than willing to do little tweaks to ensure the usage experience is as smooth as possible.

### Easy setup!
Implementing configs into your mods is as easy as writing a simple patch file, and writing code to handle known config values. The code does the rest of the work for you. All you need to worry about is handling config flags in your code.

### Compatible with both Lua modes -- safe and unsafe -- with added features for unsafe Lua!
* **DISCLAIMER: Enabling unsafe lua is like looking down the barrel of a rifle and pulling the trigger to make sure it works. It's not just unsafe, it's *STUPID*. Do not enable unsafe lua unless you have HAND-CHECKED EVERY SINGLE ONE OF YOUR MODS TO ENSURE THEY DO NOT USE MALICIOUS CODE, and you are WILLING TO RISK CATASTROPHIC AND IRREVERSABLE DAMAGE TO YOUR COMPUTER if a malicious mod exists. I am not responsible if someone else's mod bricks your computer.**

Are you a private individual who works on your own mods for you and your group of friends? Pissed off that starbound doesn't let you reference the player from any context and use logical sides (client/server) to streamline what you can and can't reference? Me too. Enabling Unsafe Lua enables the mod to create a global config file that can be referenced from any Lua context.
 - This creates `%appdata%\.StarboundModConfigs\YOUR-MOD-NAME-HERE\config.cfg` on Windows
 - This creates `~\.StarboundModConfigs\YOUR-MOD-NAME-HERE\config.cfg` on Unix and OS-X.
