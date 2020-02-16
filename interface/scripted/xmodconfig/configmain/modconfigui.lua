-- Mod config UI by Xan the Dragon // Eti the Spirit [RBX 18406183]
require("/scripts/api/XModConfig.lua")
-- To reference any ScrollArea children widgets in Lua scripts (widget.* table) use the following format: <ScrollArea name>.<Children widget name>.

local print, warn, error, assertwarn, assert, tostring; -- Specify these as locals
require("/scripts/xcore_modconfig/LoggingOverride.lua") -- tl;dr I can use print, warn, error, assert, and assertwarn

---------------------------
------ TEMPLATE DATA ------
---------------------------

-- A template for one of the buttons displayed in the mod list.
local TEMPLATE_MOD_LIST_BUTTON = {
	type = "button",
	caption = "",
	textAlign = "center",
	base = "/interface/scripted/xmodconfig/configmain/cfgbutton.png",
	hover = "/interface/scripted/xmodconfig/configmain/cfgbuttonhover.png",
	pressed = "/interface/scripted/xmodconfig/configmain/cfgbuttonhover.png",
	--position = {78, 35 + (index * 16)},
	callback = "ListButtonClicked"
}

-- A template for the title widget.
local TEMPLATE_TITLE_WIDGET = {
	type = "title",
	icon = {
		type = "image",
		file = "/interface/crafting/craftingicon.png"
	},
	title = "Mod Configuration",
	subtitle = ""
}

-- A template for a list item in the configurable options menu.
local TEMPLATE_ROOT_CONFIG_LIST_ITEM = {
	type = "image",
	file = "/interface/scripted/xmodconfig/configmain/cfglistitem.png"
}

-- A template for a textbox used to enter config data.
local TEMPLATE_TEXT_BOX = {
	-- 118, 6
	-- 100 x 7
	type = "textbox",
	position = {168, 4},
	maxWidth = 50,
	escapeKey = "TextBoxFinished",
	callback = "NullFunction",
	enterKey = "TextBoxFinished"
	-- specify regex, hint, and set custom data representing the key this textbox controls.
}

-- A template for a toggle button, which displays whether a boolean config is true or false.
local TEMPLATE_TOGGLE_BUTTON = {
	type = "button",
	position = {198, 4},
	base = "/interface/scripted/xmodconfig/configmain/cfgtoggle.png",
	hover = "/interface/scripted/xmodconfig/configmain/cfgtoggle.png",
	pressed = "/interface/scripted/xmodconfig/configmain/cfgtoggle.png",
	caption = "",
	callback = "ToggleButtonClicked"
}

-- A template for the help button of a specific config key, which shows any additional info it has.
local TEMPLATE_HELP_BUTTON = {
	type = "button",
	position = {5, 5},
	base = "/interface/scripted/xmodconfig/configmain/question.png",
	hover = "/interface/scripted/xmodconfig/configmain/question.png",
	pressed = "/interface/scripted/xmodconfig/configmain/question.png",
	callback = "HelpButtonPressed"
	-- set data of this widget to {ConfigInfo[key]}
}

-- A template for the label storing the name of the config data in the config list.
local TEMPLATE_CONFIG_ENTRY_LABEL = {
	type = "label",
	position = {16, 9},
	vAnchor = "mid",
	value = ".",
	wrapWidth = 134
}

-- Regex for a textbox that allows numbers only
local REGEX_NUMBERS_ONLY = "\\d+"

-- Regex for a textbox that allows numbers and a period for point.
-- TO DO: Localization edits to allow , as well? EDIT: Yes
local REGEX_NUMBERS_AND_DECIMALS = "(\\d+(\\.{1}|,{1})\\d+)"

-- Toggle button text color if the text is true
local COLOR_TEXT_TRUE = "#11FF11"

-- Toggle button text color if the text is false
local COLOR_TEXT_FALSE = "#FF1111"

-----------------------
------ CORE DATA ------
-----------------------

-- ModsWithConfig and ModList are the two things inside of this table.
-- This data is returned by XModConfig:GetConfigurableMods(). Refer to XModConfig API for more information.
--[[
quick reference to structure:
ConfigurableModsData = {
	ModList = {...}, -- all modName keys
	ModsWithConfig = {
		[modName] = {
			FriendlyName = "modder defined friendly name here",
			ConfigInfo = {
				{
					key = "config key",
					default = nil or default value
					enforceType = true or false/nil
					display = {
						name = "friendly display name"
						description = "a more detailed description"
					}
				},
				...
			}
		},
		...
	}
}

FOR FUTURE REFERENCE: All references to an "associatedData" var in any function points to ModsWithConfig[modName].
--]]
local ConfigurableModsData = nil

-- A reference to the current XModConfig Instance.
local CurrentConfig = nil

-- A registry of all the buttons in the list. Used for book-keeping more than anything.
local ButtonsToConfig = {}

-- All of the GUI elements within the current config page, which is populated when the user clicks a button from the mod list to access the config data for said mod.
-- This is used so that the page can be cleared without worry of interfering with other elements within in (e.g. the scrollbar)
local CurrentConfigPage = {}
-- Format: {parent, this object name, this object name with full parent/child hierarchy, table representing the widget}

------------------------------
------ HELPER FUNCTIONS ------
------------------------------

-- A little alias.
local function CreateParentChildHierarchy(parentName, childName, widgetTable)
	return {parentName, childName, parentName .. "." .. childName, widgetTable}
end

-- Opens the config description viewer for the specified config key.
-- https://youtu.be/vXOUp0y9W4w?t=191
local function ShowConfigDescription(config)
	-- Grab the raw json for the alternate config
	local configTooltip = root.assetJson("/interface/scripted/xmodconfig/configmain/configdesc/configdesc.config")
		
	configTooltip.gui.configtitle.title = config.display.name
	configTooltip.gui.configtitle.subtitle = "Configuration Value"
	configTooltip.gui.configdesc.value = config.display.description
	
	player.interact("ScriptPane", configTooltip, player.id())
end

-- Constructs the basic "container" for config entries, which is a tidy image designed to add some padding between elements in the list, as well as serve as a fairly neat place to put data into.
-- Since this is called by all other constructors, it returns the name of this container so that it can be added.
local function ConstructBaseConfigObjectContainer(configInfo, modName, index, isBoolean)
	print("Constructing new config container!")
	
	-- Create the container.
	local listItem = TEMPLATE_ROOT_CONFIG_LIST_ITEM
	local name = "config-" .. modName .. "-" .. configInfo.key
	local updatedName = "modconfigs." .. name
	--local updatedName = name
	
	listItem.position = {0, index * -20}
	if isBoolean then listItem.wrapWidth = 180 end
	
	widget.addChild("modconfigs", listItem, name)
	--table.insert(CurrentConfigPage, {"modconfigs", name, listItem})
	CurrentConfigPage[name] = CreateParentChildHierarchy("modconfigs", name, listItem)
	print("Added container to modconfigs. Container: " .. name)
	------------------------
	
	-- Create the config label.
	local cfgLabel = TEMPLATE_CONFIG_ENTRY_LABEL
	local cfgLabelName = "configLabel-" .. modName .. "-" .. configInfo.key
	local cfgPageData  = CreateParentChildHierarchy(updatedName, cfgLabelName, cfgLabel)
	CurrentConfigPage[cfgLabelName] = cfgPageData
	
	cfgLabel.value = configInfo.display.name
	widget.addChild(updatedName, cfgLabel, cfgLabelName)
	--table.insert(CurrentConfigPage, {updatedName, cfgLabelName, cfgLabel})
	print("Added config key name label. Label: " .. cfgLabelName)
	------------------------
	
	-- If needed, create the description field.
	if (configInfo.display.description or "") ~= "" then
		-- protect against 0-length strings.
		-- This has a description so we can add the help button.
		local helpButton = TEMPLATE_HELP_BUTTON
		local helpButtonName = "helpButton-" .. modName .. "-" .. configInfo.key
		local helpPageData = CreateParentChildHierarchy(updatedName, helpButtonName, helpButton)
		CurrentConfigPage[cfgLabelName] = helpPageData
		
		widget.addChild(updatedName, helpButton, helpButtonName)
		widget.setData(helpPageData[3], {configInfo})
		--table.insert(CurrentConfigPage, {updatedName, helpButtonName, helpButton})
		print("Added help button to view config description. Button: " .. helpButtonName)
	end
	-------------------------
	
	print("Returning name.")
	return updatedName, name
end

-- Construct a new textbox designed to store arbitrary strings.
local function ConstructTextBoxConfig(configInfo, modName, index)
	print("Constructing stock textbox!")
	local containerName = ConstructBaseConfigObjectContainer(configInfo, modName, index)
	local thisName = "textBox-" .. modName .. "-" .. configInfo.key
	
	local newTextBox = TEMPLATE_TEXT_BOX
	newTextBox.hint = "Enter text..."
	newTextBox.value = tostring(CurrentConfig:Get(configInfo.key, ""))
	
	local pageData = CreateParentChildHierarchy(containerName, thisName, newTextBox)
	CurrentConfigPage[thisName] = pageData
	
	widget.addChild(containerName, newTextBox, thisName)
	widget.setData(pageData[3], {configInfo.key, "text"})
	--table.insert(CurrentConfigPage, {containerName, thisName, newTextBox})
	print("Added stock textbox.")
end

-- Construct a new textbox with its regex limiter set to numbers only.
local function ConstructNumberConfig(configInfo, modName, index)
	print("Constructing number textbox!")
	local containerName = ConstructBaseConfigObjectContainer(configInfo, modName, index)
	local thisName = "numberBox-" .. modName .. "-" .. configInfo.key
	
	local newTextBox = TEMPLATE_TEXT_BOX
	local isWholeNumber = configInfo.limits and (configInfo.limits[3] == true)
	if isWholeNumber then
		print("Limited to being a whole number only.")
		newTextBox.hint = "Enter whole number..."
		newTextBox.regex = REGEX_NUMBERS_ONLY
	else
		print("Can use decimals.")
		newTextBox.hint = "Enter number..."
		newTextBox.regex = REGEX_NUMBERS_AND_DECIMALS
	end
	newTextBox.value = tostring(CurrentConfig:Get(configInfo.key, ""))
	
	local pageData = CreateParentChildHierarchy(containerName, thisName, newTextBox)
	CurrentConfigPage[thisName] = pageData
	
	widget.addChild(containerName, newTextBox, thisName)
	widget.setData(pageData[3], {configInfo.key, "number", configInfo.limits})
	--table.insert(CurrentConfigPage, {containerName, thisName, newTextBox})
	print("Added number textbox.")
end

-- Construct a new checkbox designed to store a boolean.
local function ConstructBooleanConfig(configInfo, modName, index)
	print("Constructing boolean config button!")
	local containerName = ConstructBaseConfigObjectContainer(configInfo, modName, index, true)
	local thisName = "toggleButton-" .. modName .. "-" .. configInfo.key
	
	local button = TEMPLATE_TOGGLE_BUTTON
	local isTrue = CurrentConfig:Get(configInfo.key, false) == true
	-- the == true is important.
	if isTrue then
		print("Button is true.")
		button.base = "/interface/scripted/xmodconfig/configmain/cfgtoggle_true.png"
		button.hover = "/interface/scripted/xmodconfig/configmain/cfgtoggle_true.png"
		button.pressed = "/interface/scripted/xmodconfig/configmain/cfgtoggle_true.png"
	else
		print("Button is false.")
		button.base = "/interface/scripted/xmodconfig/configmain/cfgtoggle_false.png"
		button.hover = "/interface/scripted/xmodconfig/configmain/cfgtoggle_false.png"
		button.pressed = "/interface/scripted/xmodconfig/configmain/cfgtoggle_false.png"
	end
	
	local pageData = CreateParentChildHierarchy(containerName, thisName, button)
	CurrentConfigPage[thisName] = pageData
	
	widget.addChild(containerName, button, thisName)
	widget.setData(pageData[3], {configInfo.key, isTrue})
	--table.insert(CurrentConfigPage, {containerName, thisName, button})
	print("Added button.")
end

-- You know how long I spent trying to remember another type because I thought something was missing? ffs lol

-- Automatically call the necessary ctor for the given lua type, which is a type returned by type()
-- If the specified configuration value does not have an enforced type, it will default to string. This behavior is determined by the caller.
local function ConstructConfigElement(fromLuaType, configInfo, modName, index)
	if fromLuaType == "string" then
		ConstructTextBoxConfig(configInfo, modName, index)
	elseif fromLuaType == "number" then
		ConstructNumberConfig(configInfo, modName, index)
	elseif fromLuaType == "boolean" then
		ConstructBooleanConfig(configInfo, modName, index)
	else
		ConstructTextBoxConfig(configInfo, modName, index)
	end
end

-------------------------------
------ PRIMARY FUNCTIONS ------
-------------------------------

-- Displays the configurations for the given mod.
local function DisplayModConfigsFor(rawData)
	local modName = rawData.ModName
	print("Config button for mod [" .. modName .. "] pressed. Populating info...")
	
	local associatedData = rawData.Data
	CurrentConfig = XModConfig:Instantiate(modName)
	
	widget.setText("modtitle", associatedData.FriendlyName or modName)
	
	print("Clearing old mod config page (if needed)")
	for index, data in pairs(CurrentConfigPage) do
		widget.removeChild(data[1], data[2])
	end
	CurrentConfigPage = {}
	--widget.removeAllChildren("modconfigs")
	
	print("Going through keys...")
	for index = 1, #associatedData.ConfigInfo do
		local configInfo = associatedData.ConfigInfo[index]
		local valueType = nil
		if configInfo.enforceType then valueType = type(configInfo.default) end
		ConstructConfigElement(valueType, configInfo, modName, index)
		print("Finished constructing new config element of type " .. tostring(valueType) .. " (for key [" .. configInfo.key .. "])")
	end
end

-- Creates a button on the left-most list to configure the specific mod.
local function CreateButtonToConfigMod(modName, associatedData, index)
	local buttonName = "configsFor_" .. modName
	local friendlyName = associatedData.FriendlyName
	
	local button = TEMPLATE_MOD_LIST_BUTTON
	button.caption = friendlyName or modName
	button.position = {0, index * -16}
	
	ButtonsToConfig[buttonName] = {
		ModName = modName,
		WidgetName = buttonName,
		Data = associatedData
	}
	
	widget.addChild("modlist", button, buttonName)
	print("Button " .. buttonName .. " added to mod list children.")
end

-----------------------
------ CALLBACKS ------
-----------------------

-- Run when a button for the mod list is clicked.
-- Can't be a function :(
function ListButtonClicked(widgetName, widgetData)
	local data = ButtonsToConfig[widgetName]
	if data then DisplayModConfigsFor(data) end
end

-- Run when a button for a boolean configuration key is changed.
function ToggleButtonClicked(widgetName, widgetData)
	local targetWidget = CurrentConfigPage[widgetName][3]

	local isTrue = widgetData[2] == true
	if isTrue then
		print("Button is true, setting to false.")
		widget.setButtonImages(targetWidget, {
			base = "/interface/scripted/xmodconfig/configmain/cfgtoggle_false.png",
			hover = "/interface/scripted/xmodconfig/configmain/cfgtoggle_false.png",
			pressed = "/interface/scripted/xmodconfig/configmain/cfgtoggle_false.png"
		})
	else
		print("Button is false, setting to true.")
		widget.setButtonImages(targetWidget, {
			base = "/interface/scripted/xmodconfig/configmain/cfgtoggle_true.png",
			hover = "/interface/scripted/xmodconfig/configmain/cfgtoggle_true.png",
			pressed = "/interface/scripted/xmodconfig/configmain/cfgtoggle_true.png"
		})
	end
	isTrue = not isTrue
	widget.setData(targetWidget, {widgetData[1], isTrue})
	CurrentConfig:Set(widgetData[1], isTrue)
end

-- Run when a user drops focus on a configuration textbox, either for string or number.
function TextBoxFinished(widgetName, widgetData)
	-- configInfo.key, "number", limits
	-- configInfo.key, "string"
	local targetWidget = CurrentConfigPage[widgetName][3]

	local key = widgetData[1]
	local targetType = widgetData[2]
	local text = widget.getText(targetWidget)	
	if targetType == "text" then
		-- Nothing really special here.
		CurrentConfig:Set(key, text)
	elseif targetType == "number" then
		-- Some handling here.
		-- First off: Clamped?
		local limits = widgetData[3] or {}
		local min = limits[1] or -math.huge
		local max = limits[2] or math.huge
		local wholeNumOnly = limits[3] == true
		
		local number = tonumber(text:gsub(",", "."))
		if not number then error("Number textbox had something that couldn't be turned into a number!") return end
		
		if wholeNumOnly then
			number = math.floor(number + 0.5) -- round it
		end
		
		if number < min then
			number = min
		elseif number > max then
			number = max
		end
		
		widget.setText(targetWidget, tostring(number)) -- Update the text
		CurrentConfig:Set(key, number)
	else
		warn("Something tried to fire TextBoxFinished, but its targetType (data in the text box) was not recognized! The type given was: " .. tostring(targetType))
	end
end

function HelpButtonPressed(widgetName, widgetData)
	ShowConfigDescription(widgetData[1])
end

function NullFunction() end

------------------------------
------ LOADER FUNCTIONS ------
------------------------------

-- Added by InitUtility. Runs *after* init but *before* the first update() call.
-- Note to modders: This is necessary in order to use some of the debug printing in XModConfig.
function postinit()
	ConfigurableModsData = XModConfig:GetConfigurableMods()
	print, warn, error, assertwarn, assert, tostring = CreateLoggingOverride("[Mod Config GUI]")
	
	-- NOTE: I used to have two title elements, but this does not work since it just uses the latest specified one no matter what.
	-- I must have NO title elements and then manually add the right data.
	
	local subtitle
	if XModConfig.IsUnsafeLuaEnabled then
		--widget.setVisible("windowtitle_safe", false)
		--widget.setVisible("windowtitle_unsafe", true)
		print("Setting subtitle to reflect unsafe lua.")
		subtitle = "^#BF332E;Unsafe Lua is ^#ED3D37;enabled ^#BF332E;-- All configs are stored globally."
	else
		--widget.setVisible("windowtitle_safe", true)
		--widget.setVisible("windowtitle_unsafe", false)
		print("Setting subtitle to reflect safe lua.")
		subtitle = "^#B9B5B2;Unsafe Lua is ^#D9D4D0;disabled ^#B9B5B2;-- All configs are stored per-character."
	end
	
	widget.setText("windowsubtitle", subtitle)
	
	
	for index = 1, #ConfigurableModsData.ModList do
		local modName = ConfigurableModsData.ModList[index]
		local associatedData = ConfigurableModsData.ModsWithConfig[modName]
		print("Added mod [" .. modName .. "] to config list.")
		CreateButtonToConfigMod(modName, associatedData, index)
	end
end


-- Yes, this goes down here. Don't move it or you will break it.
require("/scripts/xcore/InitializationUtility.lua")
