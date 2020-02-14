-- PlayerReplicator
-- Replicates ALL player functions and exposes them as a message handler.

require("/scripts/messageutil.lua")

local OldInit = init

function init()
	if OldInit then
		OldInit()
	end
	
	if not _ENV.ModRegistry then
		ModRegistry = {}
	end
	
	for index, data in pairs(player) do
		if type(data) == "function" then
			message.setHandler(index, localHandler(data))
		end
	end
	
	message.setHandler("isThisMyPlayer", localHandler(function () return true end))
end