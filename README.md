# SkillBasedMatchmaking
A module that implements a way to teleport players to parties depending on their level.

## Where could it be useful ?
Skill-Based Matchmaking is used on mostly on Competitive oriented FPS games where fighting against players with same level is privileged. 
It avoid players getting in matches with a too big level gap.

## How does it works ?
Module simply uses the new MemoryService introduced by Roblox as a RAM-like system. Allowing communiation cross-server. 
For the ranking, the module (for now) isnt using math modules or doing advanced math operations (planning on adding Glicko-2) 
It simply infinitely loops (starts whne user invokes method and stops when server stops), get running servers and player on queue. 
If there are none running servers after n iterations unique on each players, server will create a new server to teleport players in.
If there are running servers, but skill gap is too much high for p player, then level gap for this specific player will be increased by a.
As long as a isnt superior as a certain number, player will still loop searching for possible servers. if after all this it doesnt finds anything it will create a new
server to teleport him into.
If players with same level find a server with a reasonable level gap, they will get telepored into it as long as the length of players  to teleport doesnt exceed the max number of players, in that case tho, only players with the level that is the most closr to the mean will get teleported

## Prerequistes
The repo consists of only a ModuleScript. You will need a total of 3 scripts
 - The module
 - A server script inside the 'host server' aka place where players press play
 - A server script inside a separate place where players will figth. 

## Documentation
### Example Code
Lets start with the Start Place Script : 
```lua
-- Get the module
local MatchmakingModule = require(8824325549)

-- Inits all necessary variables
MatchmakingModule.hostInit()

MatchmakingModule:setDefaultPlaceId(8793056632) -- sets the place id where players will be TP to
MatchmakingModule:setDebugMode(true) -- useful for debuging code
MatchmakingModule:setDefaultLevelLimit(50) -- sets the max level gap between players in a server

-- Basic Remote Function adding player to queue, you can call this function whenever you want (button pressed, player joins...)
game.ReplicatedStorage.EnterMatchMaking.OnServerInvoke = function(player)
	MatchmakingModule:AddPlayerToQueue(player)
end

-- Removes player in the case he was in the queue but left while being processed
game.Players.PlayerRemoving:Connect(function(player)
	MatchmakingModule:RemoveFromQueue(player)
end)

-- Removes all players of the server when server shuts down.
game:BindToClose(function()
	MatchmakingModule:ClearAllQueues()
end)

-- Starts the main module 
MatchmakingModule:FindMatches()
```
Then with the server script located in the figth place: 
```lua
local id = game.PrivateServerId
local MatchmakingModule = require(8824325549)

MatchmakingModule.serverInit()

MatchmakingModule:setMaxPlayers(10)

MatchmakingModule:setDebugMode(false)

-- removes server to queue if too much players and updates server level mean.
game.Players.PlayerAdded:Connect(function(player)
	MatchmakingModule:AddPlayerServerToQueue(player, id)
end)

-- adds server to queue if not enough players and updates server level mean.
game.Players.PlayerRemoving:Connect(function(player)
	MatchmakingModule:AddPlayerServerToQueue(player, id)
end)

-- removes server from queue 
game:BindToClose(function()
	MatchmakingModule:ClearServer(id)
end)
```

## API 
### Host Functions :

```lua
QueueHandler:setDefaultPlaceId(number)
```
```lua
QueueHandler:setDefaultLevelLimit(number)
```
```lua
QueueHandler:setTimeIntervall(number)
```
```lua
QueueHandler:setDebugMode(bool)
```
```lua
QueueHandler:AddPlayerToQueue(player)
```
```lua
QueueHandler:RemoveFromQueue(player)
```
```lua
QueueHandler:ClearAllQueues()
```
```lua
QueueHandler:FindMatches()
```
### Party Server Functions :
```lua
QueueHandler:setMaxPlayers(n)
```
```lua
QueueHandler:AddPlayerServerToQueue(player, privateId)
```
```lua
QueueHandler:OnPlayerRemoving(player, privateServerId)
```
```lua
QueueHandler:ClearServer(privateServerid)
```
