local QueueHandler = {}

-- Services 
local MemoryService = game:GetService('MemoryStoreService')
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local MessagingService = game:GetService('MessagingService')
local TeleportService = game:GetService('TeleportService')
local DataStoreService = game:GetService('DataStoreService')

-- Data 
local ActiveServers = MemoryService:GetSortedMap('ActiveServers')
local ReservedServers = MemoryService:GetSortedMap('ReservedServers')
local PlayerQueue = MemoryService:GetSortedMap('PlayerQueue')

local LevelDataStore = DataStoreService:GetDataStore('Level')

-- Variables 
local MIN_PLAYERS = 1 
local MAX_PLAYERS = 6

local MAX_PLAYER_LOOP = 40 
local MAX_LEVEL_LIMIT_PER_PLAYERS = {}
local DEFAULT_LEVEL_LIMIT = 50

local LoopCount = 0

local hubClose = false 

if game:GetService('RunService'):IsStudio() then warn('Module cannot work on Studio test instance. Please join a Roblox Client to test module.') end 
if game:GetService('RunService'):IsClient() then warn('Cannot manage queues on client') end 

--[[ 
	WARNING: Following functions are supposed to be called on game servers only 
]] -- 

-- Inits module on game server 
--@param: nil 
function QueueHandler.serverInit()
	local self = {}

	self.minPlayers = MIN_PLAYERS
	self.maxPlayers = MAX_PLAYERS
	self.debugMode = false 

	return setmetatable(self, QueueHandler)
end

-- Sets the default minimum amount of players for a server to run
--@param: int64 => n
function QueueHandler:setMinPlayers(n)
	if (not n) then return end 
	if (not tonumber(n)) then return end 

	self.minPlayers = n
end

-- Sets the default maxmimum amount of players for a game server. 
--@param: int64 => n
function QueueHandler:setMaxPlayers(n)
	if (not n) then return end 
	if (not tonumber(n)) then return end 

	self.maxPlayers = n
end


-- This functions updates server average RAM and adds players to server.
--@param: Player => player
--@param: string => game.PrivateServerId
function QueueHandler:AddPlayerServerToQueue(player, privateId)
	assert(player ~= nil, "Player argument missing")
	assert(privateId ~= nil, "PrivateServerId argument missing, (game.PrivateServerId is case senstitive)")
	
	local average = 0

	if #Players:GetPlayers() >= self.maxPlayers then 
		QueueHandler:ClearServer(privateId)
		return
	end

	for i,v in ipairs(Players:GetPlayers()) do 
		
		local data
		
		local success, err = pcall(function()
			data = LevelDataStore:GetAsync(tostring(v.UserId).."'s level")
		end)

		data = data ~= nil and data or 0

		if (success) then 
			average += data / #Players:GetPlayers()

			ActiveServers:SetAsync(privateId, average, 86400)
			print(ActiveServers:GetRangeAsync(Enum.SortDirection.Descending, 100))
		else 
			error(err)
		end
	end
end

-- This functions updates server average RAM and removes players from server.
--@param: Player => player
--@param: string => game.PrivateServerId
function QueueHandler:OnPlayerRemoving(player, privateServerId)
	assert(player ~= nil, "Player argument missing")
	assert(privateServerId ~= nil, "PrivateServerId argument missing, (game.PrivateServerId is case senstitive)")
	
	local average = 0

	for i,v in ipairs(game.Players:GetPlayers()) do 
		local data
		local success, err = pcall(function()
			data = LevelDataStore:GetAsync(tostring(v.UserId).."'s level")
		end)

		data = data ~= nil and data or 0

		if (success) then 
			average += data / #Players:GetPlayers()

			ActiveServers:SetAsync(privateServerId, average, 30)
		else 
			error(err)
		end
	end

	PlayerQueue:RemoveAsync(tostring(player.UserId))
end

-- This functions removes the server from the active servers
-- Will likely be used on BindtoClose function 

--@param: string => game.PrivateServerId
function QueueHandler:ClearServer(privateServerid)
	ActiveServers:RemoveAsync(privateServerid)
end

--[[ 
	WARNING: Following functions are supposed to be called on the server host only!
]] -- 

function QueueHandler.hostInit()
	local self = {}

	self.defaultPlaceId = 0 -- NEED TO UPDATE TO TARGET ID 
	self.defaultLevelLimit = DEFAULT_LEVEL_LIMIT 
	self.maxLevelPerPlayer = MAX_LEVEL_LIMIT_PER_PLAYERS
	self.tickBetweenLoops = 1/2
	self.loopCount = LoopCount
	self.debugMode = false 

	return setmetatable(QueueHandler, self)
end

-- Sets the default Game Server PlaceId
--@param: int64 => game.PlaceId
function QueueHandler:setDefaultPlaceId(newId)
	if (not newId) then return end 
	if (not tonumber(newId)) then return end 
	
	self.defaultPlaceId = newId
end

-- Sets the default level limit between players. Determines if a player can join a lobby or not depending or server level mean.
--@param: int64 => n
function QueueHandler:setDefaultLevelLimit(n)
	if (not n) then return end 
	if (not tonumber(n)) then return end 
	
	self.defaultLevelLimit = n
end

-- Sets the time between server makes checks on game servers and teleports player. 
--@param: int64 => t
function QueueHandler:setTimeIntervall(t)
	if (not t) then return end 
	if (not tonumber(t)) then return end 

	self.tickBetweenLoops = t
end

-- Sets if the module prints out possible errors / warnings / statments
--@param: int64 => t
function QueueHandler:setDebugMode(b)
	if (not b) then return end 
	
	self.debugMode = b 
end

-- Adds a player to queue setting its UserId as a key and its Level as its value
--@param: Player => player
function QueueHandler:AddPlayerToQueue(player)
	local userId = player.UserId

	local data = 0
	local success, err = pcall(function()

		data = LevelDataStore:GetAsync(tostring(userId).."'s level")
		data = data ~= nil and data or 0

		if (not PlayerQueue:GetAsync(tostring(userId))) then 
			PlayerQueue:SetAsync(tostring(userId), data, 86400)

			MAX_LEVEL_LIMIT_PER_PLAYERS[userId] = DEFAULT_LEVEL_LIMIT
		else 
			if (self.debugMode) then
				print('Already in queue!')
			end
		end
	end)

	if (self.debugMode) then
		if (success) then 
			print('Sucessfully added '..player.Name..' into the queue!')
		else 
			error(err)
		end
	end 
end

-- Removes a player from a queue 
--@param: Player => player
function QueueHandler:RemoveFromQueue(player)
	local userId = player.UserId

	local success, err = pcall(function()
		PlayerQueue:RemoveAsync(tostring(userId))
	end)
	
	if (self.debugMode) then
		if (success) then 
			print('Sucessfully removed '..player.Name..' from queue!')
		else 
			error(err)
		end
	end 
end

-- Clears the player queues, surely used in game:BindToClose function 
--@param: nil
function QueueHandler:ClearAllQueues()
	hubClose = true 
	
	for i = 1, #Players:GetPlayers() do 
		local currentPlayer = Players:GetPlayers()[i]
		QueueHandler:RemoveFromQueue(currentPlayer)
	end
end

-- Inits the main loop
--@param: nil
function QueueHandler:FindMatches()
	while task.wait(self.tickBetweenLoops) and not hubClose do 
		if (hubClose) then
			break 
		end
		
		local RunningServers = 0 

		local PlayersOnQueue = PlayerQueue:GetRangeAsync(Enum.SortDirection.Descending, 100);
		RunningServers = ActiveServers:GetRangeAsync(Enum.SortDirection.Descending, 100);

		if (#PlayersOnQueue >= 1) then
			
			if (self.debugMode) then 
				print('More than 0 player on queue')
			end 

			if (#RunningServers > 0) then

				if (self.debugMode) then 
					print('Servers already running')
				end 
				
				LoopCount = 0

				for i, v in ipairs(ActiveServers:GetRangeAsync(Enum.SortDirection.Ascending, 100)) do 
					local playersToTP = {}
					local serverAverage = v.value
					local server = v.key
					
					if (self.debugMode) then 
						print('Looping throught Active Servers. Current: '..server)
					end
					
					for _, plr in ipairs(PlayerQueue:GetRangeAsync(Enum.SortDirection.Ascending, 100)) do
						local level = plr.value
						local userId = plr.key
						
						if (self.debugMode) then 
							print('Looping throught Players. Current: '..userId)
						end
						
						local currentLevelLimit = self.maxLevelPerPlayer[userId] and self.maxLevelPerPlayer[userId] ~= nil or self.defaultLevelLimit

						if (math.abs(level-serverAverage) <= currentLevelLimit) then
							playersToTP[#playersToTP+1] = plr.key
							
							if (self.debugMode) then 
								print('Level difference is ok')
							end 
							
						else 
							self.maxLevelPerPlayer[userId] += 5 -- Increament
						end
					end

					local TPOptions = Instance.new('TeleportOptions')
					TPOptions.ReservedServerAccessCode = ReservedServers:GetAsync(server)

					for _, userId in ipairs(playersToTP) do 
						if (self.debugMode) then 
							print('Teleporting player(s)')
						end 
						
						local player = Players:GetPlayerByUserId(userId)

						TeleportService:TeleportAsync(self.defaultPlaceId, {player}, TPOptions)
						QueueHandler:RemoveFromQueue(player)
					end
				end
			else 
				if (self.debugMode) then 
					print('No servers running')
				end 
				
				if (LoopCount <= 50) then 
					
					if (self.debugMode) then 
						print('Adding 1 to loop')
					end 
					
					LoopCount += 1
					continue 
				else
					if (self.debugMode) then 
						print('Looped too much')
					end 
					
					local TPOptions = Instance.new('TeleportOptions')
					TPOptions.ShouldReserveServer = true 

					local playersToTp = {}

					for _, plr in ipairs(PlayerQueue:GetRangeAsync(Enum.SortDirection.Ascending, 100)) do
						table.insert(playersToTp, Players:GetPlayerByUserId(plr.key))
						QueueHandler:RemoveFromQueue(Players:GetPlayerByUserId(plr.key))
					end

					local TPResults = TeleportService:TeleportAsync(self.defaultPlaceId, playersToTp, TPOptions)

					ReservedServers:SetAsync(TPResults.PrivateServerId, TPResults.ReservedServerAccessCode, 86400)
				end
			end
		end
	end
end

return QueueHandler
