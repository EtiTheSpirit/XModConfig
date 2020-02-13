--[[
	
	Written by Xan the Dragon // Eti the Spirit [RBX 18406183]
	
	Home-brewed pure lua event system inspired by Roblox's RBXScriptSignal class. It is designed to mimic its behavior as closely as possible, but has some added features.
	
	INSTANTIATION:
		local signal = ScriptSignal.new()
	
	TYPES:
		ScriptSignal:
			EventConnection ScriptSignal:Connect(function f)
				Connects `f` to this event, returning an EventConnection.
				WARNING: Yes, it *IS* possible to connect the same callback to the same event more than once. Please be careful with this.
				
			void ScriptSignal:Fire(...)
				Fires this event with the specified arguments, running all connected callbacks with said arguments.
				
			Tuple ScriptSignal:Wait()
				Yields the current coroutine (if applicable) until this event fires, returning the args that the event fired with.
				Callbacks will run *after* all :Wait() calls have been resumed.
				If the location this method is called in is not contained within a yieldable coroutine, this method will error.
				
			void ScriptSignal:DisconnectAll()
				Disconnects all EventConnections from this event.
				This is identical to manually iterating through Connections and calling :Disconnect() on each of them.
				
			--------
			
			EventConnection[] Connections
				A reference to all child connections created via Connect
				
				
		EventConnection
			void Disconnect()
				Disconnects this EventConnection, preventing the associated callback from firing.
				This will error if this event has already been disconnected.
				
			--------
				
			ScriptSignal Parent
				A reference to the parent ScriptSignal that created this via the Connect method.
				
			function Callback
				The callback this connection uses.
				
			bool Live = true
				True if this connection is live, false if it's been disconnected and should be discarded.
				
				
	** USAGE EXAMPLE **
	
	local someSignal = ScriptSignal.new()
	
	someSignal:Connect(function (param0, param1, param2)
		print(param0, param1, param2)
	end)
	
	someSignal:Fire("a", "b", "c")
	
	
	** DOCUMENTATION EXAMPLE **
	
	If some docs say something like:
		string someText, number someNumber, table someTable SomeEventNameHere
		
	Then that means the event should be connected to and expect three parameters, which are a string, a number, and a table respectively:
	
		SomeEventNameHere:Connect(function (someText, someNumber, someTable)
			-- handle the string, number, and table as you see fit here.
		end)
	
	Certain parameters may display their type as "Variant" which means it can be anything.
--]]

if ScriptSignal then return end
-- If you do not have access to LoggingOverride, consider getting it from https://github.com/XanTheDragon/XanScriptCore
-- If you don't want to get it, it effectively makes print, warn, and error point to util's sb.logInfo, sb.logWarn, and sb.logError functions (with behavior identical to lua's stock print function).
-- It also adds assert and assertwarn that have similar behavior.

require("/scripts/xcore_modconfig/LoggingOverride.lua")
local print, warn, error, assertwarn, assert = MakeIntoContexualLogger("[LuaScriptSignal]")

ScriptSignal = {}
local EventConnection = {}
ScriptSignal.__index = ScriptSignal
EventConnection.__index = EventConnection

---------------------------------------------------
------------------- STATIC INFO -------------------
---------------------------------------------------
local ERR_STATIC_CALL = "Cannot statically invoke method %s. Call it on an instance of ScriptSignal created via the .new() function."
	
---------------------------------------------------
---------------- SCRIPT SIGNAL TYPE ---------------
---------------------------------------------------

function ScriptSignal.new()
	local object = {
		Connections = {};
		Yields = {};
	}
	setmetatable(object, ScriptSignal)
	return object
end

function ScriptSignal:Connect(f)
	assert(getmetatable(self) == ScriptSignal, ERR_STATIC_CALL:format("Connect"))
	assert(type(f) == "function", "Invalid type for parameter f (expected function, got " .. type(f) .. ")")
	local connection = EventConnection.new(self, f)
	table.insert(self.Connections, connection)
	return connection
end

function ScriptSignal:Fire(...)
	assert(getmetatable(self) == ScriptSignal, ERR_STATIC_CALL:format("Fire"))
	
	-- Start with this.
	for i = 1, #self.Yields do
		local yieldData = self.Yields[i]
		yieldData[1](...)
		coroutine.resume(yieldData[2])
	end
	self.Yields = {}
	
	-- Then do a normal fire.
	for i = 1, #self.Connections do
		self.Connections[i].Callback(...)
	end
end

function ScriptSignal:Wait()
	assert(getmetatable(self) == ScriptSignal, ERR_STATIC_CALL:format("Wait"))
	local routine = coroutine.running()
	assert(routine ~= nil and coroutine.isyieldable(), "Cannot call Wait unless it is in a yieldable coroutine.")
	
	-- This is disgusting but there's no other way to do it. Sorry.
	local data = {}
	table.insert(self.Yields, {function (...) data = {...} end, routine})
	coroutine.yield()
	return unpack(data)
end

function ScriptSignal:DisconnectAll()
	assert(getmetatable(self) == ScriptSignal, ERR_STATIC_CALL:format("DisconnectAll"))
	local connections = self.Connections
	for i = 1, #connections do
		connections[i]:Disconnect()
	end
end

---------------------------------------------------
----------------- CONNECTION TYPE -----------------
---------------------------------------------------

function EventConnection.new(parentEvent, callback)
	local object = {
		Parent = parentEvent;
		Callback = callback;
		Live = true;
	}
	setmetatable(object, EventConnection)
	return object
end

function EventConnection:Disconnect()
	assert(getmetatable(self) == EventConnection, "Cannot statically invoke method Disconnect.")
	assert(self.Live, "Cannot call Disconnect on an invalidated EventConnection")
	assert(self.Parent ~= nil, "EventConnection is malformed! It does not have a reference to a parent ScriptSignal.")
	
	local index = 0
	for i = 1, #self.Parent.Connections do
		local connection = self.Parent.Connections[i]
		if connection == self then
			index = i
			break
		end
	end
	if index ~= 0 then
		table.remove(self.Parent.Connections, index)
		self.Live = false
		self.Callback = nil
		self.Parent = nil
		-- Clear refs so it can be GC'd
	else
		error("ERROR: Could not properly disconnect -- This EventConnection could not be found in the registry in its parent ScriptSignal!")
	end
end