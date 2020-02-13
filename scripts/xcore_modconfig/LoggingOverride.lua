-- LoggingOverride
-- Changes lua's stock print and error functions so that they use the sb log, and appends a warn() function for warnings.
--[[
	API:
	
		boolean TOSTRING_USES_SB_PRINT = false
			If true, tostring() will call sb.print() instead of Lua's native method.
	
		boolean THROW_LUA_ERROR_ON_ERR_AND_ASSERT = false
			If this global is set to true, calling error() or assert(false) will throw an actual Lua error rather than just using sb.logError
			
			
		n.b. You can set the above globals on a per-context basis by locally setting them BEFORE requiring this.
		local TOSTRING_USES_SB_PRINT = true
		require("path/to/LoggingOverride.lua")
		
	
		void print(...)
			Behaves identically to Lua's stock print(), but redirects the output to sb.logInfo. All args are safely converted to strings.
			
		void warn(...)
			Behaves identically to Lua's stock print(), but redirects the output to sb.logWarn. All args are safely converted to strings.
			
		void error(...)
			Behaves identically to Lua's stock print(), but redirects the output to sb.logError. All args are safely converted to strings.
			NOTE: This REMOVES the trace level argument from error, since stack traces are not possible to grab in Starbound.
			This means that error("message", 3) will literally output "message 3" to the starbound.log file.
			
		void assert(bool requirement, string errorMsg = "Assertion failed")
			Checks if the requirement is met (the value is true). If the value is false, it will print errorMsg via sb.logError.
			
		void assertwarn(bool requirement, string errorMsg = "Assertion failed")
			Identical to assert but uses sb.logWarn instead of sb.logError
			
			
	EXTRA API:
		
		void MakeIntoContextualLogger(string prefix)
			
			This will override the existing modifications further to always include the specified prefix before all log entries.
			For instance:
				local print, warn, error, assertwarn, assert = MakeIntoContextualLogger("[Joe Mama]")
				-- NOTE: Setting ^ LOCALLY is very important! This function cannot do it out of the box since it causes loggers to get scrambled and simply use the latest call to MakeIntoContextualLogger
				print("asdfg")
				
			Will output:
				[Joe Mama] asdfg
--]]

require("/scripts/util.lua")
ENV_HAS_LOG_OVERRIDE = true
if THROW_LUA_ERROR_ON_ERR_AND_ASSERT == nil then THROW_LUA_ERROR_ON_ERR_AND_ASSERT = false end
if TOSTRING_USES_SB_PRINT == nil then TOSTRING_USES_SB_PRINT = false end
if not LUA_ERROR then LUA_ERROR = error end
if not LUA_TOSTRING then LUA_TOSTRING = tostring end
local OldInit = init()

-- Converts an arbitrary number of args into a string like how print() does.
local function ArgsToString(...)
	local array = {...}
	local strArray = {}
	
	-- Make sure everything is a string. table.concat does NOT get along with non-string values.
	-- sb.print adds some extra flair and I believe it's a better fit than stock tostring
	for index = 1, #array do
		strArray[index] = sb.print(array[index])
	end
	return table.concat(strArray, " ")
end


tostring = function (...)
	if (TOSTRING_USES_SB_PRINT or LUA_TOSTRING == nil) and (sb ~= nil) then
		return sb.print(...)
	else
		return LUA_TOSTRING(...)
	end
end

print = function (...)
	if sb == nil then return end
	sb.logInfo(ArgsToString(...))
end

warn = function (...)
	if sb == nil then return end
	sb.logWarn(ArgsToString(...))
end

error = function (...)
	if sb == nil then return end
	sb.logError(ArgsToString(...))
	if THROW_LUA_ERROR_ON_ERR_AND_ASSERT and LUA_ERROR then LUA_ERROR(...) end
end

assertwarn = function(requirement, msg)
	if not requirement then
		warn(msg or "Assertion failed")
	end
end

assert = function(requirement, msg)
	if not requirement then
		local msg = msg or "Assertion failed"
		error(msg)
		if THROW_LUA_ERROR_ON_ERR_AND_ASSERT and LUA_ERROR then LUA_ERROR(msg) end
	end
end

function MakeIntoContextualLogger(prefix)
	local oldprint, oldwarn, olderror, oldassertwarn, oldassert = print, warn, error, assertwarn, assert
	local print = function (...)
		oldprint(prefix, ...)
	end
	
	local warn = function (...)
		oldwarn(prefix, ...)
	end
	
	local error = function (...)
		olderror(prefix, ...)
	end
	
	local assertwarn = function (requirement, msg)
		oldassertwarn(requirement, ArgsToString(prefix, msg or "Assertion failed"))
	end
	
	local assert = function (requirement, msg)
		oldassert(requirement, ArgsToString(prefix, msg or "Assertion failed"))
	end
	
	return print, warn, error, assertwarn, assert
end