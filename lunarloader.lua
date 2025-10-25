-- Lunar Client Private (Bedwars)

-- create commit
--writefile('newlunar/profiles/commit.txt', 'a1a647c8475611d0acfd2068bf8f6a0453ae7615')

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local PlaceId = game.PlaceId
local JobId = game.JobId
local UserId = Player.UserId
local Username = Player.Name

local libraries = {
	drawing = function(...)
		if not get_comm_channel or not create_comm_channel then
			return '1'
		end

		local cloneref = cloneref or function(obj)
			return obj
		end
		local httpService = cloneref(game:GetService('HttpService'))
		local runService = cloneref(game:GetService('RunService'))
		local isactor = ...
		local id, commchannel
		if isactor then
			id, commchannel = isactor, get_comm_channel(isactor)
		else
			id, commchannel = create_comm_channel()
		end
		local drawingrefs, queued, thread = {}, {}
		isactor = isactor and true or false
		local classes = {
			Base = {
				'Visible',
				'ZIndex',
				'Transparency',
				'Color'
			},
			Line = {
				'Thickness',
				'From',
				'To'
			},
			Text = {
				'Text',
				'Size',
				'Center',
				'Outline',
				'OutlineColor',
				'Position',
				'TextBounds',
				'Font'
			},
			Image = {
				'Data',
				'Size',
				'Position',
				'Rounding'
			},
			Circle = {
				'Thickness',
				'NumSides',
				'Radius',
				'Filled',
				'Position'
			},
			Square = {
				'Thickness',
				'Size',
				'Position',
				'Filled'
			},
			Quad = {
				'Thickness',
				'PointA',
				'PointB',
				'PointC',
				'PointD',
				'Filled'
			},
			Triangle = {
				'Thickness',
				'PointA',
				'PointB',
				'PointC',
				'Filled'
			}
		}

		commchannel.Event:Connect(function(...)
			local actor, key = ...
			local args = {select(3, ...)}
			if isactor and actor then
				if key == 'new' then
					local proxy = newproxy(true)
					local meta = getmetatable(proxy)
					local realobj = {Changed = {}}

					function realobj:Remove()
						commchannel:Fire(false, 'remove', args[2])
						drawingrefs[args[2]] = nil
					end

					meta.__index = realobj
					meta.__newindex = function(_, ind, val)
						rawset(realobj.Changed, ind, val)
						return rawset(realobj, ind, val)
					end

					for i, v in args[1] do
						rawset(realobj, i, v)
					end
					drawingrefs[args[2]] = proxy
					queued[args[3]] = proxy
				elseif key == 'update' then
					for i, v in args[1] do
						local obj = drawingrefs[i]
						if obj then
							for propname, prop in v do
								rawset(obj, propname, prop)
							end
						end
					end
				end
			else
				if key == 'new' then
					local obj = Drawing.new(args[1])
					local ref = httpService:GenerateGUID():sub(1, 6)
					local props = {}
					for _, v in classes.Base do
						props[v] = obj[v]
					end
					for _, v in classes[args[1]] do
						props[v] = obj[v]
					end
					drawingrefs[ref] = obj
					commchannel:Fire(true, 'new', props, ref, args[2])
				elseif key == 'update' then
					for i, v in args[1] do
						local obj = drawingrefs[i]
						if obj then
							for propname, prop in v do
								obj[propname] = prop
							end
						end
					end
				elseif key == 'remove' then
					local obj = drawingrefs[args[1]]
					if obj then
						pcall(function()
							obj:Remove()
						end)
						drawingrefs[args[1]] = nil
					end
				end
			end
		end)

		if isactor and not Drawing then
			thread = task.spawn(function()
				repeat
					local changed, set = {}
					for i, v in drawingrefs do
						for propname, prop in v.Changed do
							if not changed[i] then
								changed[i] = {}
								set = true
							end
							rawset(changed[i], propname, prop)
						end
						if changed[i] then
							table.clear(v.Changed)
						end
					end

					if set then
						commchannel:Fire(false, 'update', changed)
					end
					runService.RenderStepped:Wait()
				until false
			end)

			getgenv().Drawing = {
				new = function(objtype)
					local newid = httpService:GenerateGUID(true):sub(1, 6)
					commchannel:Fire(false, 'new', objtype, newid)
					repeat task.wait() until queued[newid]
					local obj = queued[newid]
					queued[newid] = nil
					return obj
				end,
				kill = function()
					task.cancel(thread)
					for _, v in drawingrefs do
						pcall(function()
							v:Remove()
						end)
					end
					table.clear(drawingrefs)
				end
			}
		else
			return id
		end
	end,
	entity = function()
		local entitylib = {
			isAlive = false,
			character = {},
			List = {},
			Connections = {},
			PlayerConnections = {},
			EntityThreads = {},
			Running = false,
			Events = setmetatable({}, {
				__index = function(self, ind)
					self[ind] = {
						Connections = {},
						Connect = function(rself, func)
							table.insert(rself.Connections, func)
							return {
								Disconnect = function()
									local rind = table.find(rself.Connections, func)
									if rind then
										table.remove(rself.Connections, rind)
									end
								end
							}
						end,
						Fire = function(rself, ...)
							for _, v in rself.Connections do
								task.spawn(v, ...)
							end
						end,
						Destroy = function(rself)
							table.clear(rself.Connections)
							table.clear(rself)
						end
					}

					return self[ind]
				end
			})
		}

		local cloneref = cloneref or function(obj)
			return obj
		end
		local playersService = cloneref(game:GetService('Players'))
		local inputService = cloneref(game:GetService('UserInputService'))
		local lplr = playersService.LocalPlayer
		local gameCamera = workspace.CurrentCamera

		local function getMousePosition()
			if inputService.TouchEnabled then
				return gameCamera.ViewportSize / 2
			end
			return inputService.GetMouseLocation(inputService)
		end

		local function loopClean(tbl)
			for i, v in tbl do
				if type(v) == 'table' then
					loopClean(v)
				end
				tbl[i] = nil
			end
		end

		local function waitForChildOfType(obj, name, timeout, prop)
			local checktick = tick() + timeout
			local returned
			repeat
				returned = prop and obj[name] or obj:FindFirstChildOfClass(name)
				if returned or checktick < tick() then break end
				task.wait()
			until false
			return returned
		end

		entitylib.targetCheck = function(ent)
			if ent.TeamCheck then
				return ent:TeamCheck()
			end
			if ent.NPC then return true end
			if not lplr.Team then return true end
			if not ent.Player.Team then return true end
			if ent.Player.Team ~= lplr.Team then return true end
			return #ent.Player.Team:GetPlayers() == #playersService:GetPlayers()
		end

		entitylib.getUpdateConnections = function(ent)
			local hum = ent.Humanoid
			return {
				hum:GetPropertyChangedSignal('Health'),
				hum:GetPropertyChangedSignal('MaxHealth')
			}
		end

		entitylib.isVulnerable = function(ent)
			return ent.Health > 0 and not ent.Character.FindFirstChildWhichIsA(ent.Character, 'ForceField')
		end

		entitylib.getEntityColor = function(ent)
			ent = ent.Player
			return ent and tostring(ent.TeamColor) ~= 'White' and ent.TeamColor.Color or nil
		end

		entitylib.IgnoreObject = RaycastParams.new()
		entitylib.IgnoreObject.RespectCanCollide = true
		entitylib.Wallcheck = function(origin, position, ignoreobject)
			if typeof(ignoreobject) ~= 'Instance' then
				local ignorelist = {gameCamera, lplr.Character}
				for _, v in entitylib.List do
					if v.Targetable then
						table.insert(ignorelist, v.Character)
					end
				end

				if typeof(ignoreobject) == 'table' then
					for _, v in ignoreobject do
						table.insert(ignorelist, v)
					end
				end

				ignoreobject = entitylib.IgnoreObject
				ignoreobject.FilterDescendantsInstances = ignorelist
			end
			return workspace.Raycast(workspace, origin, (position - origin), ignoreobject)
		end

		entitylib.EntityMouse = function(entitysettings)
			if entitylib.isAlive then
				local mouseLocation, sortingTable = entitysettings.MouseOrigin or getMousePosition(), {}
				for _, v in entitylib.List do
					if not entitysettings.Players and v.Player then continue end
					if not entitysettings.NPCs and v.NPC then continue end
					if not v.Targetable then continue end
					local position, vis = gameCamera.WorldToViewportPoint(gameCamera, v[entitysettings.Part].Position)
					if not vis then continue end
					local mag = (mouseLocation - Vector2.new(position.x, position.y)).Magnitude
					if mag > entitysettings.Range then continue end
					if entitylib.isVulnerable(v) then
						table.insert(sortingTable, {
							Entity = v,
							Magnitude = v.Target and -1 or mag
						})
					end
				end

				table.sort(sortingTable, entitysettings.Sort or function(a, b)
					return a.Magnitude < b.Magnitude
				end)

				for _, v in sortingTable do
					if entitysettings.Wallcheck then
						if entitylib.Wallcheck(entitysettings.Origin, v.Entity[entitysettings.Part].Position, entitysettings.Wallcheck) then continue end
					end
					table.clear(entitysettings)
					table.clear(sortingTable)
					return v.Entity
				end
				table.clear(sortingTable)
			end
			table.clear(entitysettings)
		end

		entitylib.EntityPosition = function(entitysettings)
			if entitylib.isAlive then
				local localPosition, sortingTable = entitysettings.Origin or entitylib.character.HumanoidRootPart.Position, {}
				for _, v in entitylib.List do
					if not entitysettings.Players and v.Player then continue end
					if not entitysettings.NPCs and v.NPC then continue end
					if not v.Targetable then continue end
					local mag = (v[entitysettings.Part].Position - localPosition).Magnitude
					if mag > entitysettings.Range then continue end
					if entitylib.isVulnerable(v) then
						table.insert(sortingTable, {
							Entity = v,
							Magnitude = v.Target and -1 or mag
						})
					end
				end

				table.sort(sortingTable, entitysettings.Sort or function(a, b)
					return a.Magnitude < b.Magnitude
				end)

				for _, v in sortingTable do
					if entitysettings.Wallcheck then
						if entitylib.Wallcheck(localPosition, v.Entity[entitysettings.Part].Position, entitysettings.Wallcheck) then continue end
					end
					table.clear(entitysettings)
					table.clear(sortingTable)
					return v.Entity
				end
				table.clear(sortingTable)
			end
			table.clear(entitysettings)
		end

		entitylib.AllPosition = function(entitysettings)
			local returned = {}
			if entitylib.isAlive then
				local localPosition, sortingTable = entitysettings.Origin or entitylib.character.HumanoidRootPart.Position, {}
				for _, v in entitylib.List do
					if not entitysettings.Players and v.Player then continue end
					if not entitysettings.NPCs and v.NPC then continue end
					if not v.Targetable then continue end
					local mag = (v[entitysettings.Part].Position - localPosition).Magnitude
					if mag > entitysettings.Range then continue end
					if entitylib.isVulnerable(v) then
						table.insert(sortingTable, {Entity = v, Magnitude = v.Target and -1 or mag})
					end
				end

				table.sort(sortingTable, entitysettings.Sort or function(a, b)
					return a.Magnitude < b.Magnitude
				end)

				for _, v in sortingTable do
					if entitysettings.Wallcheck then
						if entitylib.Wallcheck(localPosition, v.Entity[entitysettings.Part].Position, entitysettings.Wallcheck) then continue end
					end
					table.insert(returned, v.Entity)
					if #returned >= (entitysettings.Limit or math.huge) then break end
				end
				table.clear(sortingTable)
			end
			table.clear(entitysettings)
			return returned
		end

		entitylib.getEntity = function(char)
			for i, v in entitylib.List do
				if v.Player == char or v.Character == char then
					return v, i
				end
			end
		end

		entitylib.addEntity = function(char, plr, teamfunc)
			if not char then return end
			entitylib.EntityThreads[char] = task.spawn(function()
				local hum = waitForChildOfType(char, 'Humanoid', 10)
				local humrootpart = hum and waitForChildOfType(hum, 'RootPart', workspace.StreamingEnabled and 9e9 or 10, true)
				local head = char:WaitForChild('Head', 10) or humrootpart

				if hum and humrootpart then
					local entity = {
						Connections = {},
						Character = char,
						Health = hum.Health,
						Head = head,
						Humanoid = hum,
						HumanoidRootPart = humrootpart,
						HipHeight = hum.HipHeight + (humrootpart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
						MaxHealth = hum.MaxHealth,
						NPC = plr == nil,
						Player = plr,
						RootPart = humrootpart,
						TeamCheck = teamfunc
					}

					if plr == lplr then
						entitylib.character = entity
						entitylib.isAlive = true
						entitylib.Events.LocalAdded:Fire(entity)
					else
						entity.Targetable = entitylib.targetCheck(entity)

						for _, v in entitylib.getUpdateConnections(entity) do
							table.insert(entity.Connections, v:Connect(function()
								entity.Health = hum.Health
								entity.MaxHealth = hum.MaxHealth
								entitylib.Events.EntityUpdated:Fire(entity)
							end))
						end

						table.insert(entitylib.List, entity)
						entitylib.Events.EntityAdded:Fire(entity)
					end
			--[[table.insert(entity.Connections, char.ChildRemoved:Connect(function(part)
				if (part == humrootpart or part == hum or part == head) then
					local found = char:FindFirstChild(part.Name)
					if found then
						if part == humrootpart then
							entity.HumanoidRootPart = found
							entity.RootPart = found
							humrootpart = found
							return
						elseif part == head then
							entity.Head = found
							head = found
							return
						end
					end
					entitylib.removeEntity(char, plr == lplr)
				end
			end))]]
				end
				entitylib.EntityThreads[char] = nil
			end)
		end

		entitylib.removeEntity = function(char, localcheck)
			if localcheck then
				if entitylib.isAlive then
					entitylib.isAlive = false
					for _, v in entitylib.character.Connections do
						v:Disconnect()
					end
					table.clear(entitylib.character.Connections)
					entitylib.Events.LocalRemoved:Fire(entitylib.character)
					--table.clear(entitylib.character)
				end
				return
			end

			if char then
				if entitylib.EntityThreads[char] then
					task.cancel(entitylib.EntityThreads[char])
					entitylib.EntityThreads[char] = nil
				end

				local entity, ind = entitylib.getEntity(char)
				if ind then
					for _, v in entity.Connections do
						v:Disconnect()
					end
					table.clear(entity.Connections)
					table.remove(entitylib.List, ind)
					entitylib.Events.EntityRemoved:Fire(entity)
				end
			end
		end

		entitylib.refreshEntity = function(char, plr)
			entitylib.removeEntity(char)
			entitylib.addEntity(char, plr)
		end

		entitylib.addPlayer = function(plr)
			if plr.Character then
				entitylib.refreshEntity(plr.Character, plr)
			end
			entitylib.PlayerConnections[plr] = {
				plr.CharacterAdded:Connect(function(char)
					entitylib.refreshEntity(char, plr)
				end),
				plr.CharacterRemoving:Connect(function(char)
					entitylib.removeEntity(char, plr == lplr)
				end),
				plr:GetPropertyChangedSignal('Team'):Connect(function()
					for _, v in entitylib.List do
						if v.Targetable ~= entitylib.targetCheck(v) then
							entitylib.refreshEntity(v.Character, v.Player)
						end
					end

					if plr == lplr then
						entitylib.start()
					else
						entitylib.refreshEntity(plr.Character, plr)
					end
				end)
			}
		end

		entitylib.removePlayer = function(plr)
			if entitylib.PlayerConnections[plr] then
				for _, v in entitylib.PlayerConnections[plr] do
					v:Disconnect()
				end
				table.clear(entitylib.PlayerConnections[plr])
				entitylib.PlayerConnections[plr] = nil
			end
			entitylib.removeEntity(plr)
		end

		entitylib.start = function()
			if entitylib.Running then
				entitylib.stop()
			end
			table.insert(entitylib.Connections, playersService.PlayerAdded:Connect(function(v)
				entitylib.addPlayer(v)
			end))
			table.insert(entitylib.Connections, playersService.PlayerRemoving:Connect(function(v)
				entitylib.removePlayer(v)
			end))
			for _, v in playersService:GetPlayers() do
				entitylib.addPlayer(v)
			end
			table.insert(entitylib.Connections, workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
				gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
			end))
			entitylib.Running = true
		end

		entitylib.stop = function()
			for _, v in entitylib.Connections do
				v:Disconnect()
			end
			for _, v in entitylib.PlayerConnections do
				for _, v2 in v do
					v2:Disconnect()
				end
				table.clear(v)
			end
			entitylib.removeEntity(nil, true)
			local cloned = table.clone(entitylib.List)
			for _, v in cloned do
				entitylib.removeEntity(v.Character)
			end
			for _, v in entitylib.EntityThreads do
				task.cancel(v)
			end
			table.clear(entitylib.PlayerConnections)
			table.clear(entitylib.EntityThreads)
			table.clear(entitylib.Connections)
			table.clear(cloned)
			entitylib.Running = false
		end

		entitylib.kill = function()
			if entitylib.Running then
				entitylib.stop()
			end
			for _, v in entitylib.Events do
				v:Destroy()
			end
			entitylib.IgnoreObject:Destroy()
			loopClean(entitylib)
		end

		entitylib.refresh = function()
			local cloned = table.clone(entitylib.List)
			for _, v in cloned do
				entitylib.refreshEntity(v.Character, v.Player)
			end
			table.clear(cloned)
		end

		entitylib.start()

		return entitylib
	end,
	hash = function()
		-- HashLib by Egor Skriptunoff, boatbomber, and howmanysmall, I'm not trusting exploits to have a built in crypt library.

--[=[------------------------------------------------------------------------------------------------------------------------

Documentation here: https://devforum.roblox.com/t/open-source-hashlib/416732/1

--------------------------------------------------------------------------------------------------------------------------

Module was originally written by Egor Skriptunoff and distributed under an MIT license.
It can be found here: https://github.com/Egor-Skriptunoff/pure_lua_SHA/blob/master/sha2.lua

That version was around 3000 lines long, and supported Lua versions 5.1, 5.2, 5.3, and 5.4, and LuaJIT.
Although that is super cool, Roblox only uses Lua 5.1, so that was extreme overkill.

I, boatbomber, worked to port it to Roblox in a way that doesn't overcomplicate it with support of unreachable
cases. Then, howmanysmall did some final optimizations that really squeeze out all the performance possible.
It's gotten stupid fast, thanks to her!

After quite a bit of work and benchmarking, this is what we were left with.
Enjoy!

--------------------------------------------------------------------------------------------------------------------------

DESCRIPTION:
	This module contains functions to calculate SHA digest:
		MD5, SHA-1,
		SHA-224, SHA-256, SHA-512/224, SHA-512/256, SHA-384, SHA-512,
		SHA3-224, SHA3-256, SHA3-384, SHA3-512, SHAKE128, SHAKE256,
		HMAC
	Additionally, it has a few extra utility functions:
		hex_to_bin
		base64_to_bin
		bin_to_base64
	Written in pure Lua.
USAGE:
	Input data should be a string
	Result (SHA digest) is returned in hexadecimal representation as a string of lowercase hex digits.
	Simplest usage example:
		local HashLib = require(script.HashLib)
		local your_hash = HashLib.sha256("your string")
API:
		HashLib.md5
		HashLib.sha1
	SHA2 hash functions:
		HashLib.sha224
		HashLib.sha256
		HashLib.sha512_224
		HashLib.sha512_256
		HashLib.sha384
		HashLib.sha512
	SHA3 hash functions:
		HashLib.sha3_224
		HashLib.sha3_256
		HashLib.sha3_384
		HashLib.sha3_512
		HashLib.shake128
		HashLib.shake256
	Misc utilities:
		HashLib.hmac (Applicable to any hash function from this module except SHAKE*)
		HashLib.hex_to_bin
		HashLib.base64_to_bin
		HashLib.bin_to_base64

--]=]---------------------------------------------------------------------------

		--------------------------------------------------------------------------------
		-- LOCALIZATION FOR VM OPTIMIZATIONS
		--------------------------------------------------------------------------------

		local ipairs = ipairs

		--------------------------------------------------------------------------------
		-- 32-BIT BITWISE FUNCTIONS
		--------------------------------------------------------------------------------
		-- Only low 32 bits of function arguments matter, high bits are ignored
		-- The result of all functions (except HEX) is an integer inside "correct range":
		-- for "bit" library:	(-TWO_POW_31)..(TWO_POW_31-1)
		-- for "bit32" library:		0..(TWO_POW_32-1)
		local bit32_band = bit32.band -- 2 arguments
		local bit32_bor = bit32.bor -- 2 arguments
		local bit32_bxor = bit32.bxor -- 2..5 arguments
		local bit32_lshift = bit32.lshift -- second argument is integer 0..31
		local bit32_rshift = bit32.rshift -- second argument is integer 0..31
		local bit32_lrotate = bit32.lrotate -- second argument is integer 0..31
		local bit32_rrotate = bit32.rrotate -- second argument is integer 0..31

		--------------------------------------------------------------------------------
		-- CREATING OPTIMIZED INNER LOOP
		--------------------------------------------------------------------------------
		-- Arrays of SHA2 "magic numbers" (in "INT64" and "FFI" branches "*_lo" arrays contain 64-bit values)
		local sha2_K_lo, sha2_K_hi, sha2_H_lo, sha2_H_hi, sha3_RC_lo, sha3_RC_hi = {}, {}, {}, {}, {}, {}
		local sha2_H_ext256 = {
			[224] = {};
			[256] = sha2_H_hi;
		}

		local sha2_H_ext512_lo, sha2_H_ext512_hi = {
			[384] = {};
			[512] = sha2_H_lo;
		}, {
			[384] = {};
			[512] = sha2_H_hi;
		}

		local md5_K, md5_sha1_H = {}, {0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0}
		local md5_next_shift = {0, 0, 0, 0, 0, 0, 0, 0, 28, 25, 26, 27, 0, 0, 10, 9, 11, 12, 0, 15, 16, 17, 18, 0, 20, 22, 23, 21}
		local HEX64, XOR64A5, lanes_index_base -- defined only for branches that internally use 64-bit integers: "INT64" and "FFI"
		local common_W = {} -- temporary table shared between all calculations (to avoid creating new temporary table every time)
		local K_lo_modulo, hi_factor, hi_factor_keccak = 4294967296, 0, 0

		local TWO_POW_NEG_56 = 2 ^ -56
		local TWO_POW_NEG_17 = 2 ^ -17

		local TWO_POW_2 = 2 ^ 2
		local TWO_POW_3 = 2 ^ 3
		local TWO_POW_4 = 2 ^ 4
		local TWO_POW_5 = 2 ^ 5
		local TWO_POW_6 = 2 ^ 6
		local TWO_POW_7 = 2 ^ 7
		local TWO_POW_8 = 2 ^ 8
		local TWO_POW_9 = 2 ^ 9
		local TWO_POW_10 = 2 ^ 10
		local TWO_POW_11 = 2 ^ 11
		local TWO_POW_12 = 2 ^ 12
		local TWO_POW_13 = 2 ^ 13
		local TWO_POW_14 = 2 ^ 14
		local TWO_POW_15 = 2 ^ 15
		local TWO_POW_16 = 2 ^ 16
		local TWO_POW_17 = 2 ^ 17
		local TWO_POW_18 = 2 ^ 18
		local TWO_POW_19 = 2 ^ 19
		local TWO_POW_20 = 2 ^ 20
		local TWO_POW_21 = 2 ^ 21
		local TWO_POW_22 = 2 ^ 22
		local TWO_POW_23 = 2 ^ 23
		local TWO_POW_24 = 2 ^ 24
		local TWO_POW_25 = 2 ^ 25
		local TWO_POW_26 = 2 ^ 26
		local TWO_POW_27 = 2 ^ 27
		local TWO_POW_28 = 2 ^ 28
		local TWO_POW_29 = 2 ^ 29
		local TWO_POW_30 = 2 ^ 30
		local TWO_POW_31 = 2 ^ 31
		local TWO_POW_32 = 2 ^ 32
		local TWO_POW_40 = 2 ^ 40

		local TWO56_POW_7 = 256 ^ 7

		-- Implementation for Lua 5.1/5.2 (with or without bitwise library available)
		local function sha256_feed_64(H, str, offs, size)
			-- offs >= 0, size >= 0, size is multiple of 64
			local W, K = common_W, sha2_K_hi
			local h1, h2, h3, h4, h5, h6, h7, h8 = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
			for pos = offs, offs + size - 1, 64 do
				for j = 1, 16 do
					pos = pos + 4
					local a, b, c, d = string.byte(str, pos - 3, pos)
					W[j] = ((a * 256 + b) * 256 + c) * 256 + d
				end

				for j = 17, 64 do
					local a, b = W[j - 15], W[j - 2]
					W[j] = bit32_bxor(bit32_rrotate(a, 7), bit32_lrotate(a, 14), bit32_rshift(a, 3)) + bit32_bxor(bit32_lrotate(b, 15), bit32_lrotate(b, 13), bit32_rshift(b, 10)) + W[j - 7] + W[j - 16]
				end

				local a, b, c, d, e, f, g, h = h1, h2, h3, h4, h5, h6, h7, h8
				for j = 1, 64 do
					local z = bit32_bxor(bit32_rrotate(e, 6), bit32_rrotate(e, 11), bit32_lrotate(e, 7)) + bit32_band(e, f) + bit32_band(-1 - e, g) + h + K[j] + W[j]
					h = g
					g = f
					f = e
					e = z + d
					d = c
					c = b
					b = a
					a = z + bit32_band(d, c) + bit32_band(a, bit32_bxor(d, c)) + bit32_bxor(bit32_rrotate(a, 2), bit32_rrotate(a, 13), bit32_lrotate(a, 10))
				end

				h1, h2, h3, h4 = (a + h1) % 4294967296, (b + h2) % 4294967296, (c + h3) % 4294967296, (d + h4) % 4294967296
				h5, h6, h7, h8 = (e + h5) % 4294967296, (f + h6) % 4294967296, (g + h7) % 4294967296, (h + h8) % 4294967296
			end

			H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8] = h1, h2, h3, h4, h5, h6, h7, h8
		end

		local function sha512_feed_128(H_lo, H_hi, str, offs, size)
			-- offs >= 0, size >= 0, size is multiple of 128
			-- W1_hi, W1_lo, W2_hi, W2_lo, ...   Wk_hi = W[2*k-1], Wk_lo = W[2*k]
			local W, K_lo, K_hi = common_W, sha2_K_lo, sha2_K_hi
			local h1_lo, h2_lo, h3_lo, h4_lo, h5_lo, h6_lo, h7_lo, h8_lo = H_lo[1], H_lo[2], H_lo[3], H_lo[4], H_lo[5], H_lo[6], H_lo[7], H_lo[8]
			local h1_hi, h2_hi, h3_hi, h4_hi, h5_hi, h6_hi, h7_hi, h8_hi = H_hi[1], H_hi[2], H_hi[3], H_hi[4], H_hi[5], H_hi[6], H_hi[7], H_hi[8]
			for pos = offs, offs + size - 1, 128 do
				for j = 1, 16 * 2 do
					pos = pos + 4
					local a, b, c, d = string.byte(str, pos - 3, pos)
					W[j] = ((a * 256 + b) * 256 + c) * 256 + d
				end

				for jj = 34, 160, 2 do
					local a_lo, a_hi, b_lo, b_hi = W[jj - 30], W[jj - 31], W[jj - 4], W[jj - 5]
					local tmp1 = bit32_bxor(bit32_rshift(a_lo, 1) + bit32_lshift(a_hi, 31), bit32_rshift(a_lo, 8) + bit32_lshift(a_hi, 24), bit32_rshift(a_lo, 7) + bit32_lshift(a_hi, 25)) % 4294967296 +
						bit32_bxor(bit32_rshift(b_lo, 19) + bit32_lshift(b_hi, 13), bit32_lshift(b_lo, 3) + bit32_rshift(b_hi, 29), bit32_rshift(b_lo, 6) + bit32_lshift(b_hi, 26)) % 4294967296 +
						W[jj - 14] + W[jj - 32]

					local tmp2 = tmp1 % 4294967296
					W[jj - 1] = bit32_bxor(bit32_rshift(a_hi, 1) + bit32_lshift(a_lo, 31), bit32_rshift(a_hi, 8) + bit32_lshift(a_lo, 24), bit32_rshift(a_hi, 7)) +
						bit32_bxor(bit32_rshift(b_hi, 19) + bit32_lshift(b_lo, 13), bit32_lshift(b_hi, 3) + bit32_rshift(b_lo, 29), bit32_rshift(b_hi, 6)) +
						W[jj - 15] + W[jj - 33] + (tmp1 - tmp2) / 4294967296

					W[jj] = tmp2
				end

				local a_lo, b_lo, c_lo, d_lo, e_lo, f_lo, g_lo, h_lo = h1_lo, h2_lo, h3_lo, h4_lo, h5_lo, h6_lo, h7_lo, h8_lo
				local a_hi, b_hi, c_hi, d_hi, e_hi, f_hi, g_hi, h_hi = h1_hi, h2_hi, h3_hi, h4_hi, h5_hi, h6_hi, h7_hi, h8_hi
				for j = 1, 80 do
					local jj = 2 * j
					local tmp1 = bit32_bxor(bit32_rshift(e_lo, 14) + bit32_lshift(e_hi, 18), bit32_rshift(e_lo, 18) + bit32_lshift(e_hi, 14), bit32_lshift(e_lo, 23) + bit32_rshift(e_hi, 9)) % 4294967296 +
						(bit32_band(e_lo, f_lo) + bit32_band(-1 - e_lo, g_lo)) % 4294967296 +
						h_lo + K_lo[j] + W[jj]

					local z_lo = tmp1 % 4294967296
					local z_hi = bit32_bxor(bit32_rshift(e_hi, 14) + bit32_lshift(e_lo, 18), bit32_rshift(e_hi, 18) + bit32_lshift(e_lo, 14), bit32_lshift(e_hi, 23) + bit32_rshift(e_lo, 9)) +
						bit32_band(e_hi, f_hi) + bit32_band(-1 - e_hi, g_hi) +
						h_hi + K_hi[j] + W[jj - 1] +
						(tmp1 - z_lo) / 4294967296

					h_lo = g_lo
					h_hi = g_hi
					g_lo = f_lo
					g_hi = f_hi
					f_lo = e_lo
					f_hi = e_hi
					tmp1 = z_lo + d_lo
					e_lo = tmp1 % 4294967296
					e_hi = z_hi + d_hi + (tmp1 - e_lo) / 4294967296
					d_lo = c_lo
					d_hi = c_hi
					c_lo = b_lo
					c_hi = b_hi
					b_lo = a_lo
					b_hi = a_hi
					tmp1 = z_lo + (bit32_band(d_lo, c_lo) + bit32_band(b_lo, bit32_bxor(d_lo, c_lo))) % 4294967296 + bit32_bxor(bit32_rshift(b_lo, 28) + bit32_lshift(b_hi, 4), bit32_lshift(b_lo, 30) + bit32_rshift(b_hi, 2), bit32_lshift(b_lo, 25) + bit32_rshift(b_hi, 7)) % 4294967296
					a_lo = tmp1 % 4294967296
					a_hi = z_hi + (bit32_band(d_hi, c_hi) + bit32_band(b_hi, bit32_bxor(d_hi, c_hi))) + bit32_bxor(bit32_rshift(b_hi, 28) + bit32_lshift(b_lo, 4), bit32_lshift(b_hi, 30) + bit32_rshift(b_lo, 2), bit32_lshift(b_hi, 25) + bit32_rshift(b_lo, 7)) + (tmp1 - a_lo) / 4294967296
				end

				a_lo = h1_lo + a_lo
				h1_lo = a_lo % 4294967296
				h1_hi = (h1_hi + a_hi + (a_lo - h1_lo) / 4294967296) % 4294967296
				a_lo = h2_lo + b_lo
				h2_lo = a_lo % 4294967296
				h2_hi = (h2_hi + b_hi + (a_lo - h2_lo) / 4294967296) % 4294967296
				a_lo = h3_lo + c_lo
				h3_lo = a_lo % 4294967296
				h3_hi = (h3_hi + c_hi + (a_lo - h3_lo) / 4294967296) % 4294967296
				a_lo = h4_lo + d_lo
				h4_lo = a_lo % 4294967296
				h4_hi = (h4_hi + d_hi + (a_lo - h4_lo) / 4294967296) % 4294967296
				a_lo = h5_lo + e_lo
				h5_lo = a_lo % 4294967296
				h5_hi = (h5_hi + e_hi + (a_lo - h5_lo) / 4294967296) % 4294967296
				a_lo = h6_lo + f_lo
				h6_lo = a_lo % 4294967296
				h6_hi = (h6_hi + f_hi + (a_lo - h6_lo) / 4294967296) % 4294967296
				a_lo = h7_lo + g_lo
				h7_lo = a_lo % 4294967296
				h7_hi = (h7_hi + g_hi + (a_lo - h7_lo) / 4294967296) % 4294967296
				a_lo = h8_lo + h_lo
				h8_lo = a_lo % 4294967296
				h8_hi = (h8_hi + h_hi + (a_lo - h8_lo) / 4294967296) % 4294967296
			end

			H_lo[1], H_lo[2], H_lo[3], H_lo[4], H_lo[5], H_lo[6], H_lo[7], H_lo[8] = h1_lo, h2_lo, h3_lo, h4_lo, h5_lo, h6_lo, h7_lo, h8_lo
			H_hi[1], H_hi[2], H_hi[3], H_hi[4], H_hi[5], H_hi[6], H_hi[7], H_hi[8] = h1_hi, h2_hi, h3_hi, h4_hi, h5_hi, h6_hi, h7_hi, h8_hi
		end

		local function md5_feed_64(H, str, offs, size)
			-- offs >= 0, size >= 0, size is multiple of 64
			local W, K, md5_next_shift = common_W, md5_K, md5_next_shift
			local h1, h2, h3, h4 = H[1], H[2], H[3], H[4]
			for pos = offs, offs + size - 1, 64 do
				for j = 1, 16 do
					pos = pos + 4
					local a, b, c, d = string.byte(str, pos - 3, pos)
					W[j] = ((d * 256 + c) * 256 + b) * 256 + a
				end

				local a, b, c, d = h1, h2, h3, h4
				local s = 25
				for j = 1, 16 do
					local F = bit32_rrotate(bit32_band(b, c) + bit32_band(-1 - b, d) + a + K[j] + W[j], s) + b
					s = md5_next_shift[s]
					a = d
					d = c
					c = b
					b = F
				end

				s = 27
				for j = 17, 32 do
					local F = bit32_rrotate(bit32_band(d, b) + bit32_band(-1 - d, c) + a + K[j] + W[(5 * j - 4) % 16 + 1], s) + b
					s = md5_next_shift[s]
					a = d
					d = c
					c = b
					b = F
				end

				s = 28
				for j = 33, 48 do
					local F = bit32_rrotate(bit32_bxor(bit32_bxor(b, c), d) + a + K[j] + W[(3 * j + 2) % 16 + 1], s) + b
					s = md5_next_shift[s]
					a = d
					d = c
					c = b
					b = F
				end

				s = 26
				for j = 49, 64 do
					local F = bit32_rrotate(bit32_bxor(c, bit32_bor(b, -1 - d)) + a + K[j] + W[(j * 7 - 7) % 16 + 1], s) + b
					s = md5_next_shift[s]
					a = d
					d = c
					c = b
					b = F
				end

				h1 = (a + h1) % 4294967296
				h2 = (b + h2) % 4294967296
				h3 = (c + h3) % 4294967296
				h4 = (d + h4) % 4294967296
			end

			H[1], H[2], H[3], H[4] = h1, h2, h3, h4
		end

		local function sha1_feed_64(H, str, offs, size)
			-- offs >= 0, size >= 0, size is multiple of 64
			local W = common_W
			local h1, h2, h3, h4, h5 = H[1], H[2], H[3], H[4], H[5]
			for pos = offs, offs + size - 1, 64 do
				for j = 1, 16 do
					pos = pos + 4
					local a, b, c, d = string.byte(str, pos - 3, pos)
					W[j] = ((a * 256 + b) * 256 + c) * 256 + d
				end

				for j = 17, 80 do
					W[j] = bit32_lrotate(bit32_bxor(W[j - 3], W[j - 8], W[j - 14], W[j - 16]), 1)
				end

				local a, b, c, d, e = h1, h2, h3, h4, h5
				for j = 1, 20 do
					local z = bit32_lrotate(a, 5) + bit32_band(b, c) + bit32_band(-1 - b, d) + 0x5A827999 + W[j] + e -- constant = math.floor(TWO_POW_30 * sqrt(2))
					e = d
					d = c
					c = bit32_rrotate(b, 2)
					b = a
					a = z
				end

				for j = 21, 40 do
					local z = bit32_lrotate(a, 5) + bit32_bxor(b, c, d) + 0x6ED9EBA1 + W[j] + e -- TWO_POW_30 * sqrt(3)
					e = d
					d = c
					c = bit32_rrotate(b, 2)
					b = a
					a = z
				end

				for j = 41, 60 do
					local z = bit32_lrotate(a, 5) + bit32_band(d, c) + bit32_band(b, bit32_bxor(d, c)) + 0x8F1BBCDC + W[j] + e -- TWO_POW_30 * sqrt(5)
					e = d
					d = c
					c = bit32_rrotate(b, 2)
					b = a
					a = z
				end

				for j = 61, 80 do
					local z = bit32_lrotate(a, 5) + bit32_bxor(b, c, d) + 0xCA62C1D6 + W[j] + e -- TWO_POW_30 * sqrt(10)
					e = d
					d = c
					c = bit32_rrotate(b, 2)
					b = a
					a = z
				end

				h1 = (a + h1) % 4294967296
				h2 = (b + h2) % 4294967296
				h3 = (c + h3) % 4294967296
				h4 = (d + h4) % 4294967296
				h5 = (e + h5) % 4294967296
			end

			H[1], H[2], H[3], H[4], H[5] = h1, h2, h3, h4, h5
		end

		local function keccak_feed(lanes_lo, lanes_hi, str, offs, size, block_size_in_bytes)
			-- This is an example of a Lua function having 79 local variables :-)
			-- offs >= 0, size >= 0, size is multiple of block_size_in_bytes, block_size_in_bytes is positive multiple of 8
			local RC_lo, RC_hi = sha3_RC_lo, sha3_RC_hi
			local qwords_qty = block_size_in_bytes / 8
			for pos = offs, offs + size - 1, block_size_in_bytes do
				for j = 1, qwords_qty do
					local a, b, c, d = string.byte(str, pos + 1, pos + 4)
					lanes_lo[j] = bit32_bxor(lanes_lo[j], ((d * 256 + c) * 256 + b) * 256 + a)
					pos = pos + 8
					a, b, c, d = string.byte(str, pos - 3, pos)
					lanes_hi[j] = bit32_bxor(lanes_hi[j], ((d * 256 + c) * 256 + b) * 256 + a)
				end

				local L01_lo, L01_hi, L02_lo, L02_hi, L03_lo, L03_hi, L04_lo, L04_hi, L05_lo, L05_hi, L06_lo, L06_hi, L07_lo, L07_hi, L08_lo, L08_hi, L09_lo, L09_hi, L10_lo, L10_hi, L11_lo, L11_hi, L12_lo, L12_hi, L13_lo, L13_hi, L14_lo, L14_hi, L15_lo, L15_hi, L16_lo, L16_hi, L17_lo, L17_hi, L18_lo, L18_hi, L19_lo, L19_hi, L20_lo, L20_hi, L21_lo, L21_hi, L22_lo, L22_hi, L23_lo, L23_hi, L24_lo, L24_hi, L25_lo, L25_hi = lanes_lo[1], lanes_hi[1], lanes_lo[2], lanes_hi[2], lanes_lo[3], lanes_hi[3], lanes_lo[4], lanes_hi[4], lanes_lo[5], lanes_hi[5], lanes_lo[6], lanes_hi[6], lanes_lo[7], lanes_hi[7], lanes_lo[8], lanes_hi[8], lanes_lo[9], lanes_hi[9], lanes_lo[10], lanes_hi[10], lanes_lo[11], lanes_hi[11], lanes_lo[12], lanes_hi[12], lanes_lo[13], lanes_hi[13], lanes_lo[14], lanes_hi[14], lanes_lo[15], lanes_hi[15], lanes_lo[16], lanes_hi[16], lanes_lo[17], lanes_hi[17], lanes_lo[18], lanes_hi[18], lanes_lo[19], lanes_hi[19], lanes_lo[20], lanes_hi[20], lanes_lo[21], lanes_hi[21], lanes_lo[22], lanes_hi[22], lanes_lo[23], lanes_hi[23], lanes_lo[24], lanes_hi[24], lanes_lo[25], lanes_hi[25]

				for round_idx = 1, 24 do
					local C1_lo = bit32_bxor(L01_lo, L06_lo, L11_lo, L16_lo, L21_lo)
					local C1_hi = bit32_bxor(L01_hi, L06_hi, L11_hi, L16_hi, L21_hi)
					local C2_lo = bit32_bxor(L02_lo, L07_lo, L12_lo, L17_lo, L22_lo)
					local C2_hi = bit32_bxor(L02_hi, L07_hi, L12_hi, L17_hi, L22_hi)
					local C3_lo = bit32_bxor(L03_lo, L08_lo, L13_lo, L18_lo, L23_lo)
					local C3_hi = bit32_bxor(L03_hi, L08_hi, L13_hi, L18_hi, L23_hi)
					local C4_lo = bit32_bxor(L04_lo, L09_lo, L14_lo, L19_lo, L24_lo)
					local C4_hi = bit32_bxor(L04_hi, L09_hi, L14_hi, L19_hi, L24_hi)
					local C5_lo = bit32_bxor(L05_lo, L10_lo, L15_lo, L20_lo, L25_lo)
					local C5_hi = bit32_bxor(L05_hi, L10_hi, L15_hi, L20_hi, L25_hi)

					local D_lo = bit32_bxor(C1_lo, C3_lo * 2 + (C3_hi % TWO_POW_32 - C3_hi % TWO_POW_31) / TWO_POW_31)
					local D_hi = bit32_bxor(C1_hi, C3_hi * 2 + (C3_lo % TWO_POW_32 - C3_lo % TWO_POW_31) / TWO_POW_31)

					local T0_lo = bit32_bxor(D_lo, L02_lo)
					local T0_hi = bit32_bxor(D_hi, L02_hi)
					local T1_lo = bit32_bxor(D_lo, L07_lo)
					local T1_hi = bit32_bxor(D_hi, L07_hi)
					local T2_lo = bit32_bxor(D_lo, L12_lo)
					local T2_hi = bit32_bxor(D_hi, L12_hi)
					local T3_lo = bit32_bxor(D_lo, L17_lo)
					local T3_hi = bit32_bxor(D_hi, L17_hi)
					local T4_lo = bit32_bxor(D_lo, L22_lo)
					local T4_hi = bit32_bxor(D_hi, L22_hi)

					L02_lo = (T1_lo % TWO_POW_32 - T1_lo % TWO_POW_20) / TWO_POW_20 + T1_hi * TWO_POW_12
					L02_hi = (T1_hi % TWO_POW_32 - T1_hi % TWO_POW_20) / TWO_POW_20 + T1_lo * TWO_POW_12
					L07_lo = (T3_lo % TWO_POW_32 - T3_lo % TWO_POW_19) / TWO_POW_19 + T3_hi * TWO_POW_13
					L07_hi = (T3_hi % TWO_POW_32 - T3_hi % TWO_POW_19) / TWO_POW_19 + T3_lo * TWO_POW_13
					L12_lo = T0_lo * 2 + (T0_hi % TWO_POW_32 - T0_hi % TWO_POW_31) / TWO_POW_31
					L12_hi = T0_hi * 2 + (T0_lo % TWO_POW_32 - T0_lo % TWO_POW_31) / TWO_POW_31
					L17_lo = T2_lo * TWO_POW_10 + (T2_hi % TWO_POW_32 - T2_hi % TWO_POW_22) / TWO_POW_22
					L17_hi = T2_hi * TWO_POW_10 + (T2_lo % TWO_POW_32 - T2_lo % TWO_POW_22) / TWO_POW_22
					L22_lo = T4_lo * TWO_POW_2 + (T4_hi % TWO_POW_32 - T4_hi % TWO_POW_30) / TWO_POW_30
					L22_hi = T4_hi * TWO_POW_2 + (T4_lo % TWO_POW_32 - T4_lo % TWO_POW_30) / TWO_POW_30

					D_lo = bit32_bxor(C2_lo, C4_lo * 2 + (C4_hi % TWO_POW_32 - C4_hi % TWO_POW_31) / TWO_POW_31)
					D_hi = bit32_bxor(C2_hi, C4_hi * 2 + (C4_lo % TWO_POW_32 - C4_lo % TWO_POW_31) / TWO_POW_31)

					T0_lo = bit32_bxor(D_lo, L03_lo)
					T0_hi = bit32_bxor(D_hi, L03_hi)
					T1_lo = bit32_bxor(D_lo, L08_lo)
					T1_hi = bit32_bxor(D_hi, L08_hi)
					T2_lo = bit32_bxor(D_lo, L13_lo)
					T2_hi = bit32_bxor(D_hi, L13_hi)
					T3_lo = bit32_bxor(D_lo, L18_lo)
					T3_hi = bit32_bxor(D_hi, L18_hi)
					T4_lo = bit32_bxor(D_lo, L23_lo)
					T4_hi = bit32_bxor(D_hi, L23_hi)

					L03_lo = (T2_lo % TWO_POW_32 - T2_lo % TWO_POW_21) / TWO_POW_21 + T2_hi * TWO_POW_11
					L03_hi = (T2_hi % TWO_POW_32 - T2_hi % TWO_POW_21) / TWO_POW_21 + T2_lo * TWO_POW_11
					L08_lo = (T4_lo % TWO_POW_32 - T4_lo % TWO_POW_3) / TWO_POW_3 + T4_hi * TWO_POW_29 % TWO_POW_32
					L08_hi = (T4_hi % TWO_POW_32 - T4_hi % TWO_POW_3) / TWO_POW_3 + T4_lo * TWO_POW_29 % TWO_POW_32
					L13_lo = T1_lo * TWO_POW_6 + (T1_hi % TWO_POW_32 - T1_hi % TWO_POW_26) / TWO_POW_26
					L13_hi = T1_hi * TWO_POW_6 + (T1_lo % TWO_POW_32 - T1_lo % TWO_POW_26) / TWO_POW_26
					L18_lo = T3_lo * TWO_POW_15 + (T3_hi % TWO_POW_32 - T3_hi % TWO_POW_17) / TWO_POW_17
					L18_hi = T3_hi * TWO_POW_15 + (T3_lo % TWO_POW_32 - T3_lo % TWO_POW_17) / TWO_POW_17
					L23_lo = (T0_lo % TWO_POW_32 - T0_lo % TWO_POW_2) / TWO_POW_2 + T0_hi * TWO_POW_30 % TWO_POW_32
					L23_hi = (T0_hi % TWO_POW_32 - T0_hi % TWO_POW_2) / TWO_POW_2 + T0_lo * TWO_POW_30 % TWO_POW_32

					D_lo = bit32_bxor(C3_lo, C5_lo * 2 + (C5_hi % TWO_POW_32 - C5_hi % TWO_POW_31) / TWO_POW_31)
					D_hi = bit32_bxor(C3_hi, C5_hi * 2 + (C5_lo % TWO_POW_32 - C5_lo % TWO_POW_31) / TWO_POW_31)

					T0_lo = bit32_bxor(D_lo, L04_lo)
					T0_hi = bit32_bxor(D_hi, L04_hi)
					T1_lo = bit32_bxor(D_lo, L09_lo)
					T1_hi = bit32_bxor(D_hi, L09_hi)
					T2_lo = bit32_bxor(D_lo, L14_lo)
					T2_hi = bit32_bxor(D_hi, L14_hi)
					T3_lo = bit32_bxor(D_lo, L19_lo)
					T3_hi = bit32_bxor(D_hi, L19_hi)
					T4_lo = bit32_bxor(D_lo, L24_lo)
					T4_hi = bit32_bxor(D_hi, L24_hi)

					L04_lo = T3_lo * TWO_POW_21 % TWO_POW_32 + (T3_hi % TWO_POW_32 - T3_hi % TWO_POW_11) / TWO_POW_11
					L04_hi = T3_hi * TWO_POW_21 % TWO_POW_32 + (T3_lo % TWO_POW_32 - T3_lo % TWO_POW_11) / TWO_POW_11
					L09_lo = T0_lo * TWO_POW_28 % TWO_POW_32 + (T0_hi % TWO_POW_32 - T0_hi % TWO_POW_4) / TWO_POW_4
					L09_hi = T0_hi * TWO_POW_28 % TWO_POW_32 + (T0_lo % TWO_POW_32 - T0_lo % TWO_POW_4) / TWO_POW_4
					L14_lo = T2_lo * TWO_POW_25 % TWO_POW_32 + (T2_hi % TWO_POW_32 - T2_hi % TWO_POW_7) / TWO_POW_7
					L14_hi = T2_hi * TWO_POW_25 % TWO_POW_32 + (T2_lo % TWO_POW_32 - T2_lo % TWO_POW_7) / TWO_POW_7
					L19_lo = (T4_lo % TWO_POW_32 - T4_lo % TWO_POW_8) / TWO_POW_8 + T4_hi * TWO_POW_24 % TWO_POW_32
					L19_hi = (T4_hi % TWO_POW_32 - T4_hi % TWO_POW_8) / TWO_POW_8 + T4_lo * TWO_POW_24 % TWO_POW_32
					L24_lo = (T1_lo % TWO_POW_32 - T1_lo % TWO_POW_9) / TWO_POW_9 + T1_hi * TWO_POW_23 % TWO_POW_32
					L24_hi = (T1_hi % TWO_POW_32 - T1_hi % TWO_POW_9) / TWO_POW_9 + T1_lo * TWO_POW_23 % TWO_POW_32

					D_lo = bit32_bxor(C4_lo, C1_lo * 2 + (C1_hi % TWO_POW_32 - C1_hi % TWO_POW_31) / TWO_POW_31)
					D_hi = bit32_bxor(C4_hi, C1_hi * 2 + (C1_lo % TWO_POW_32 - C1_lo % TWO_POW_31) / TWO_POW_31)

					T0_lo = bit32_bxor(D_lo, L05_lo)
					T0_hi = bit32_bxor(D_hi, L05_hi)
					T1_lo = bit32_bxor(D_lo, L10_lo)
					T1_hi = bit32_bxor(D_hi, L10_hi)
					T2_lo = bit32_bxor(D_lo, L15_lo)
					T2_hi = bit32_bxor(D_hi, L15_hi)
					T3_lo = bit32_bxor(D_lo, L20_lo)
					T3_hi = bit32_bxor(D_hi, L20_hi)
					T4_lo = bit32_bxor(D_lo, L25_lo)
					T4_hi = bit32_bxor(D_hi, L25_hi)

					L05_lo = T4_lo * TWO_POW_14 + (T4_hi % TWO_POW_32 - T4_hi % TWO_POW_18) / TWO_POW_18
					L05_hi = T4_hi * TWO_POW_14 + (T4_lo % TWO_POW_32 - T4_lo % TWO_POW_18) / TWO_POW_18
					L10_lo = T1_lo * TWO_POW_20 % TWO_POW_32 + (T1_hi % TWO_POW_32 - T1_hi % TWO_POW_12) / TWO_POW_12
					L10_hi = T1_hi * TWO_POW_20 % TWO_POW_32 + (T1_lo % TWO_POW_32 - T1_lo % TWO_POW_12) / TWO_POW_12
					L15_lo = T3_lo * TWO_POW_8 + (T3_hi % TWO_POW_32 - T3_hi % TWO_POW_24) / TWO_POW_24
					L15_hi = T3_hi * TWO_POW_8 + (T3_lo % TWO_POW_32 - T3_lo % TWO_POW_24) / TWO_POW_24
					L20_lo = T0_lo * TWO_POW_27 % TWO_POW_32 + (T0_hi % TWO_POW_32 - T0_hi % TWO_POW_5) / TWO_POW_5
					L20_hi = T0_hi * TWO_POW_27 % TWO_POW_32 + (T0_lo % TWO_POW_32 - T0_lo % TWO_POW_5) / TWO_POW_5
					L25_lo = (T2_lo % TWO_POW_32 - T2_lo % TWO_POW_25) / TWO_POW_25 + T2_hi * TWO_POW_7
					L25_hi = (T2_hi % TWO_POW_32 - T2_hi % TWO_POW_25) / TWO_POW_25 + T2_lo * TWO_POW_7

					D_lo = bit32_bxor(C5_lo, C2_lo * 2 + (C2_hi % TWO_POW_32 - C2_hi % TWO_POW_31) / TWO_POW_31)
					D_hi = bit32_bxor(C5_hi, C2_hi * 2 + (C2_lo % TWO_POW_32 - C2_lo % TWO_POW_31) / TWO_POW_31)

					T1_lo = bit32_bxor(D_lo, L06_lo)
					T1_hi = bit32_bxor(D_hi, L06_hi)
					T2_lo = bit32_bxor(D_lo, L11_lo)
					T2_hi = bit32_bxor(D_hi, L11_hi)
					T3_lo = bit32_bxor(D_lo, L16_lo)
					T3_hi = bit32_bxor(D_hi, L16_hi)
					T4_lo = bit32_bxor(D_lo, L21_lo)
					T4_hi = bit32_bxor(D_hi, L21_hi)

					L06_lo = T2_lo * TWO_POW_3 + (T2_hi % TWO_POW_32 - T2_hi % TWO_POW_29) / TWO_POW_29
					L06_hi = T2_hi * TWO_POW_3 + (T2_lo % TWO_POW_32 - T2_lo % TWO_POW_29) / TWO_POW_29
					L11_lo = T4_lo * TWO_POW_18 + (T4_hi % TWO_POW_32 - T4_hi % TWO_POW_14) / TWO_POW_14
					L11_hi = T4_hi * TWO_POW_18 + (T4_lo % TWO_POW_32 - T4_lo % TWO_POW_14) / TWO_POW_14
					L16_lo = (T1_lo % TWO_POW_32 - T1_lo % TWO_POW_28) / TWO_POW_28 + T1_hi * TWO_POW_4
					L16_hi = (T1_hi % TWO_POW_32 - T1_hi % TWO_POW_28) / TWO_POW_28 + T1_lo * TWO_POW_4
					L21_lo = (T3_lo % TWO_POW_32 - T3_lo % TWO_POW_23) / TWO_POW_23 + T3_hi * TWO_POW_9
					L21_hi = (T3_hi % TWO_POW_32 - T3_hi % TWO_POW_23) / TWO_POW_23 + T3_lo * TWO_POW_9

					L01_lo = bit32_bxor(D_lo, L01_lo)
					L01_hi = bit32_bxor(D_hi, L01_hi)
					L01_lo, L02_lo, L03_lo, L04_lo, L05_lo = bit32_bxor(L01_lo, bit32_band(-1 - L02_lo, L03_lo)), bit32_bxor(L02_lo, bit32_band(-1 - L03_lo, L04_lo)), bit32_bxor(L03_lo, bit32_band(-1 - L04_lo, L05_lo)), bit32_bxor(L04_lo, bit32_band(-1 - L05_lo, L01_lo)), bit32_bxor(L05_lo, bit32_band(-1 - L01_lo, L02_lo))
					L01_hi, L02_hi, L03_hi, L04_hi, L05_hi = bit32_bxor(L01_hi, bit32_band(-1 - L02_hi, L03_hi)), bit32_bxor(L02_hi, bit32_band(-1 - L03_hi, L04_hi)), bit32_bxor(L03_hi, bit32_band(-1 - L04_hi, L05_hi)), bit32_bxor(L04_hi, bit32_band(-1 - L05_hi, L01_hi)), bit32_bxor(L05_hi, bit32_band(-1 - L01_hi, L02_hi))
					L06_lo, L07_lo, L08_lo, L09_lo, L10_lo = bit32_bxor(L09_lo, bit32_band(-1 - L10_lo, L06_lo)), bit32_bxor(L10_lo, bit32_band(-1 - L06_lo, L07_lo)), bit32_bxor(L06_lo, bit32_band(-1 - L07_lo, L08_lo)), bit32_bxor(L07_lo, bit32_band(-1 - L08_lo, L09_lo)), bit32_bxor(L08_lo, bit32_band(-1 - L09_lo, L10_lo))
					L06_hi, L07_hi, L08_hi, L09_hi, L10_hi = bit32_bxor(L09_hi, bit32_band(-1 - L10_hi, L06_hi)), bit32_bxor(L10_hi, bit32_band(-1 - L06_hi, L07_hi)), bit32_bxor(L06_hi, bit32_band(-1 - L07_hi, L08_hi)), bit32_bxor(L07_hi, bit32_band(-1 - L08_hi, L09_hi)), bit32_bxor(L08_hi, bit32_band(-1 - L09_hi, L10_hi))
					L11_lo, L12_lo, L13_lo, L14_lo, L15_lo = bit32_bxor(L12_lo, bit32_band(-1 - L13_lo, L14_lo)), bit32_bxor(L13_lo, bit32_band(-1 - L14_lo, L15_lo)), bit32_bxor(L14_lo, bit32_band(-1 - L15_lo, L11_lo)), bit32_bxor(L15_lo, bit32_band(-1 - L11_lo, L12_lo)), bit32_bxor(L11_lo, bit32_band(-1 - L12_lo, L13_lo))
					L11_hi, L12_hi, L13_hi, L14_hi, L15_hi = bit32_bxor(L12_hi, bit32_band(-1 - L13_hi, L14_hi)), bit32_bxor(L13_hi, bit32_band(-1 - L14_hi, L15_hi)), bit32_bxor(L14_hi, bit32_band(-1 - L15_hi, L11_hi)), bit32_bxor(L15_hi, bit32_band(-1 - L11_hi, L12_hi)), bit32_bxor(L11_hi, bit32_band(-1 - L12_hi, L13_hi))
					L16_lo, L17_lo, L18_lo, L19_lo, L20_lo = bit32_bxor(L20_lo, bit32_band(-1 - L16_lo, L17_lo)), bit32_bxor(L16_lo, bit32_band(-1 - L17_lo, L18_lo)), bit32_bxor(L17_lo, bit32_band(-1 - L18_lo, L19_lo)), bit32_bxor(L18_lo, bit32_band(-1 - L19_lo, L20_lo)), bit32_bxor(L19_lo, bit32_band(-1 - L20_lo, L16_lo))
					L16_hi, L17_hi, L18_hi, L19_hi, L20_hi = bit32_bxor(L20_hi, bit32_band(-1 - L16_hi, L17_hi)), bit32_bxor(L16_hi, bit32_band(-1 - L17_hi, L18_hi)), bit32_bxor(L17_hi, bit32_band(-1 - L18_hi, L19_hi)), bit32_bxor(L18_hi, bit32_band(-1 - L19_hi, L20_hi)), bit32_bxor(L19_hi, bit32_band(-1 - L20_hi, L16_hi))
					L21_lo, L22_lo, L23_lo, L24_lo, L25_lo = bit32_bxor(L23_lo, bit32_band(-1 - L24_lo, L25_lo)), bit32_bxor(L24_lo, bit32_band(-1 - L25_lo, L21_lo)), bit32_bxor(L25_lo, bit32_band(-1 - L21_lo, L22_lo)), bit32_bxor(L21_lo, bit32_band(-1 - L22_lo, L23_lo)), bit32_bxor(L22_lo, bit32_band(-1 - L23_lo, L24_lo))
					L21_hi, L22_hi, L23_hi, L24_hi, L25_hi = bit32_bxor(L23_hi, bit32_band(-1 - L24_hi, L25_hi)), bit32_bxor(L24_hi, bit32_band(-1 - L25_hi, L21_hi)), bit32_bxor(L25_hi, bit32_band(-1 - L21_hi, L22_hi)), bit32_bxor(L21_hi, bit32_band(-1 - L22_hi, L23_hi)), bit32_bxor(L22_hi, bit32_band(-1 - L23_hi, L24_hi))
					L01_lo = bit32_bxor(L01_lo, RC_lo[round_idx])
					L01_hi = L01_hi + RC_hi[round_idx] -- RC_hi[] is either 0 or 0x80000000, so we could use fast addition instead of slow XOR
				end

				lanes_lo[1] = L01_lo
				lanes_hi[1] = L01_hi
				lanes_lo[2] = L02_lo
				lanes_hi[2] = L02_hi
				lanes_lo[3] = L03_lo
				lanes_hi[3] = L03_hi
				lanes_lo[4] = L04_lo
				lanes_hi[4] = L04_hi
				lanes_lo[5] = L05_lo
				lanes_hi[5] = L05_hi
				lanes_lo[6] = L06_lo
				lanes_hi[6] = L06_hi
				lanes_lo[7] = L07_lo
				lanes_hi[7] = L07_hi
				lanes_lo[8] = L08_lo
				lanes_hi[8] = L08_hi
				lanes_lo[9] = L09_lo
				lanes_hi[9] = L09_hi
				lanes_lo[10] = L10_lo
				lanes_hi[10] = L10_hi
				lanes_lo[11] = L11_lo
				lanes_hi[11] = L11_hi
				lanes_lo[12] = L12_lo
				lanes_hi[12] = L12_hi
				lanes_lo[13] = L13_lo
				lanes_hi[13] = L13_hi
				lanes_lo[14] = L14_lo
				lanes_hi[14] = L14_hi
				lanes_lo[15] = L15_lo
				lanes_hi[15] = L15_hi
				lanes_lo[16] = L16_lo
				lanes_hi[16] = L16_hi
				lanes_lo[17] = L17_lo
				lanes_hi[17] = L17_hi
				lanes_lo[18] = L18_lo
				lanes_hi[18] = L18_hi
				lanes_lo[19] = L19_lo
				lanes_hi[19] = L19_hi
				lanes_lo[20] = L20_lo
				lanes_hi[20] = L20_hi
				lanes_lo[21] = L21_lo
				lanes_hi[21] = L21_hi
				lanes_lo[22] = L22_lo
				lanes_hi[22] = L22_hi
				lanes_lo[23] = L23_lo
				lanes_hi[23] = L23_hi
				lanes_lo[24] = L24_lo
				lanes_hi[24] = L24_hi
				lanes_lo[25] = L25_lo
				lanes_hi[25] = L25_hi
			end
		end

		--------------------------------------------------------------------------------
		-- MAGIC NUMBERS CALCULATOR
		--------------------------------------------------------------------------------
		-- Q:
		--	Is 53-bit "double" math enough to calculate square roots and cube roots of primes with 64 correct bits after decimal point?
		-- A:
		--	Yes, 53-bit "double" arithmetic is enough.
		--	We could obtain first 40 bits by direct calculation of p^(1/3) and next 40 bits by one step of Newton's method.
		do
			local function mul(src1, src2, factor, result_length)
				-- src1, src2 - long integers (arrays of digits in base TWO_POW_24)
				-- factor - small integer
				-- returns long integer result (src1 * src2 * factor) and its floating point approximation
				local result, carry, value, weight = table.create(result_length), 0, 0, 1
				for j = 1, result_length do
					for k = math.max(1, j + 1 - #src2), math.min(j, #src1) do
						carry = carry + factor * src1[k] * src2[j + 1 - k] -- "int32" is not enough for multiplication result, that's why "factor" must be of type "double"
					end

					local digit = carry % TWO_POW_24
					result[j] = math.floor(digit)
					carry = (carry - digit) / TWO_POW_24
					value = value + digit * weight
					weight = weight * TWO_POW_24
				end

				return result, value
			end

			local idx, step, p, one, sqrt_hi, sqrt_lo = 0, {4, 1, 2, -2, 2}, 4, {1}, sha2_H_hi, sha2_H_lo
			repeat
				p = p + step[p % 6]
				local d = 1
				repeat
					d = d + step[d % 6]
					if d * d > p then
						-- next prime number is found
						local root = p ^ (1 / 3)
						local R = root * TWO_POW_40
						R = mul(table.create(1, math.floor(R)), one, 1, 2)
						local _, delta = mul(R, mul(R, R, 1, 4), -1, 4)
						local hi = R[2] % 65536 * 65536 + math.floor(R[1] / 256)
						local lo = R[1] % 256 * 16777216 + math.floor(delta * (TWO_POW_NEG_56 / 3) * root / p)

						if idx < 16 then
							root = math.sqrt(p)
							R = root * TWO_POW_40
							R = mul(table.create(1, math.floor(R)), one, 1, 2)
							_, delta = mul(R, R, -1, 2)
							local hi = R[2] % 65536 * 65536 + math.floor(R[1] / 256)
							local lo = R[1] % 256 * 16777216 + math.floor(delta * TWO_POW_NEG_17 / root)
							local idx = idx % 8 + 1
							sha2_H_ext256[224][idx] = lo
							sqrt_hi[idx], sqrt_lo[idx] = hi, lo + hi * hi_factor
							if idx > 7 then
								sqrt_hi, sqrt_lo = sha2_H_ext512_hi[384], sha2_H_ext512_lo[384]
							end
						end

						idx = idx + 1
						sha2_K_hi[idx], sha2_K_lo[idx] = hi, lo % K_lo_modulo + hi * hi_factor
						break
					end
				until p % d == 0
			until idx > 79
		end

		-- Calculating IVs for SHA512/224 and SHA512/256
		for width = 224, 256, 32 do
			local H_lo, H_hi = {}, nil
			if XOR64A5 then
				for j = 1, 8 do
					H_lo[j] = XOR64A5(sha2_H_lo[j])
				end
			else
				H_hi = {}
				for j = 1, 8 do
					H_lo[j] = bit32_bxor(sha2_H_lo[j], 0xA5A5A5A5) % 4294967296
					H_hi[j] = bit32_bxor(sha2_H_hi[j], 0xA5A5A5A5) % 4294967296
				end
			end

			sha512_feed_128(H_lo, H_hi, "SHA-512/" .. tostring(width) .. "\128" .. string.rep("\0", 115) .. "\88", 0, 128)
			sha2_H_ext512_lo[width] = H_lo
			sha2_H_ext512_hi[width] = H_hi
		end

		-- Constants for MD5
		do
			for idx = 1, 64 do
				-- we can't use formula math.floor(abs(sin(idx))*TWO_POW_32) because its result may be beyond integer range on Lua built with 32-bit integers
				local hi, lo = math.modf(math.abs(math.sin(idx)) * TWO_POW_16)
				md5_K[idx] = hi * 65536 + math.floor(lo * TWO_POW_16)
			end
		end

		-- Constants for SHA3
		do
			local sh_reg = 29
			local function next_bit()
				local r = sh_reg % 2
				sh_reg = bit32_bxor((sh_reg - r) / 2, 142 * r)
				return r
			end

			for idx = 1, 24 do
				local lo, m = 0, nil
				for _ = 1, 6 do
					m = m and m * m * 2 or 1
					lo = lo + next_bit() * m
				end

				local hi = next_bit() * m
				sha3_RC_hi[idx], sha3_RC_lo[idx] = hi, lo + hi * hi_factor_keccak
			end
		end

		--------------------------------------------------------------------------------
		-- MAIN FUNCTIONS
		--------------------------------------------------------------------------------
		local function sha256ext(width, message)
			-- Create an instance (private objects for current calculation)
			local Array256 = sha2_H_ext256[width] -- # == 8
			local length, tail = 0, ""
			local H = table.create(8)
			H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8] = Array256[1], Array256[2], Array256[3], Array256[4], Array256[5], Array256[6], Array256[7], Array256[8]

			local function partial(message_part)
				if message_part then
					local partLength = #message_part
					if tail then
						length = length + partLength
						local offs = 0
						local tailLength = #tail
						if tail ~= "" and tailLength + partLength >= 64 then
							offs = 64 - tailLength
							sha256_feed_64(H, tail .. string.sub(message_part, 1, offs), 0, 64)
							tail = ""
						end

						local size = partLength - offs
						local size_tail = size % 64
						sha256_feed_64(H, message_part, offs, size - size_tail)
						tail = tail .. string.sub(message_part, partLength + 1 - size_tail)
						return partial
					else
						error("Adding more chunks is not allowed after receiving the result", 2)
					end
				else
					if tail then
						local final_blocks = table.create(10) --{tail, "\128", string.rep("\0", (-9 - length) % 64 + 1)}
						final_blocks[1] = tail
						final_blocks[2] = "\128"
						final_blocks[3] = string.rep("\0", (-9 - length) % 64 + 1)

						tail = nil
						-- Assuming user data length is shorter than (TWO_POW_53)-9 bytes
						-- Anyway, it looks very unrealistic that someone would spend more than a year of calculations to process TWO_POW_53 bytes of data by using this Lua script :-)
						-- TWO_POW_53 bytes = TWO_POW_56 bits, so "bit-counter" fits in 7 bytes
						length = length * (8 / TWO56_POW_7) -- convert "byte-counter" to "bit-counter" and move decimal point to the left
						for j = 4, 10 do
							length = length % 1 * 256
							final_blocks[j] = string.char(math.floor(length))
						end

						final_blocks = table.concat(final_blocks)
						sha256_feed_64(H, final_blocks, 0, #final_blocks)
						local max_reg = width / 32
						for j = 1, max_reg do
							H[j] = string.format("%08x", H[j] % 4294967296)
						end

						H = table.concat(H, "", 1, max_reg)
					end

					return H
				end
			end

			if message then
				-- Actually perform calculations and return the SHA256 digest of a message
				return partial(message)()
			else
				-- Return function for chunk-by-chunk loading
				-- User should feed every chunk of input data as single argument to this function and finally get SHA256 digest by invoking this function without an argument
				return partial
			end
		end

		local function sha512ext(width, message)

			-- Create an instance (private objects for current calculation)
			local length, tail, H_lo, H_hi = 0, "", table.pack(table.unpack(sha2_H_ext512_lo[width])), not HEX64 and table.pack(table.unpack(sha2_H_ext512_hi[width]))

			local function partial(message_part)
				if message_part then
					local partLength = #message_part
					if tail then
						length = length + partLength
						local offs = 0
						if tail ~= "" and #tail + partLength >= 128 then
							offs = 128 - #tail
							sha512_feed_128(H_lo, H_hi, tail .. string.sub(message_part, 1, offs), 0, 128)
							tail = ""
						end

						local size = partLength - offs
						local size_tail = size % 128
						sha512_feed_128(H_lo, H_hi, message_part, offs, size - size_tail)
						tail = tail .. string.sub(message_part, partLength + 1 - size_tail)
						return partial
					else
						error("Adding more chunks is not allowed after receiving the result", 2)
					end
				else
					if tail then
						local final_blocks = table.create(3) --{tail, "\128", string.rep("\0", (-17-length) % 128 + 9)}
						final_blocks[1] = tail
						final_blocks[2] = "\128"
						final_blocks[3] = string.rep("\0", (-17 - length) % 128 + 9)

						tail = nil
						-- Assuming user data length is shorter than (TWO_POW_53)-17 bytes
						-- TWO_POW_53 bytes = TWO_POW_56 bits, so "bit-counter" fits in 7 bytes
						length = length * (8 / TWO56_POW_7) -- convert "byte-counter" to "bit-counter" and move floating point to the left
						for j = 4, 10 do
							length = length % 1 * 256
							final_blocks[j] = string.char(math.floor(length))
						end

						final_blocks = table.concat(final_blocks)
						sha512_feed_128(H_lo, H_hi, final_blocks, 0, #final_blocks)
						local max_reg = math.ceil(width / 64)

						if HEX64 then
							for j = 1, max_reg do
								H_lo[j] = HEX64(H_lo[j])
							end
						else
							for j = 1, max_reg do
								H_lo[j] = string.format("%08x", H_hi[j] % 4294967296) .. string.format("%08x", H_lo[j] % 4294967296)
							end

							H_hi = nil
						end

						H_lo = string.sub(table.concat(H_lo, "", 1, max_reg), 1, width / 4)
					end

					return H_lo
				end
			end

			if message then
				-- Actually perform calculations and return the SHA512 digest of a message
				return partial(message)()
			else
				-- Return function for chunk-by-chunk loading
				-- User should feed every chunk of input data as single argument to this function and finally get SHA512 digest by invoking this function without an argument
				return partial
			end
		end

		local function md5(message)

			-- Create an instance (private objects for current calculation)
			local H, length, tail = table.create(4), 0, ""
			H[1], H[2], H[3], H[4] = md5_sha1_H[1], md5_sha1_H[2], md5_sha1_H[3], md5_sha1_H[4]

			local function partial(message_part)
				if message_part then
					local partLength = #message_part
					if tail then
						length = length + partLength
						local offs = 0
						if tail ~= "" and #tail + partLength >= 64 then
							offs = 64 - #tail
							md5_feed_64(H, tail .. string.sub(message_part, 1, offs), 0, 64)
							tail = ""
						end

						local size = partLength - offs
						local size_tail = size % 64
						md5_feed_64(H, message_part, offs, size - size_tail)
						tail = tail .. string.sub(message_part, partLength + 1 - size_tail)
						return partial
					else
						error("Adding more chunks is not allowed after receiving the result", 2)
					end
				else
					if tail then
						local final_blocks = table.create(3) --{tail, "\128", string.rep("\0", (-9 - length) % 64)}
						final_blocks[1] = tail
						final_blocks[2] = "\128"
						final_blocks[3] = string.rep("\0", (-9 - length) % 64)
						tail = nil
						length = length * 8 -- convert "byte-counter" to "bit-counter"
						for j = 4, 11 do
							local low_byte = length % 256
							final_blocks[j] = string.char(low_byte)
							length = (length - low_byte) / 256
						end

						final_blocks = table.concat(final_blocks)
						md5_feed_64(H, final_blocks, 0, #final_blocks)
						for j = 1, 4 do
							H[j] = string.format("%08x", H[j] % 4294967296)
						end

						H = string.gsub(table.concat(H), "(..)(..)(..)(..)", "%4%3%2%1")
					end

					return H
				end
			end

			if message then
				-- Actually perform calculations and return the MD5 digest of a message
				return partial(message)()
			else
				-- Return function for chunk-by-chunk loading
				-- User should feed every chunk of input data as single argument to this function and finally get MD5 digest by invoking this function without an argument
				return partial
			end
		end

		local function sha1(message)
			-- Create an instance (private objects for current calculation)
			local H, length, tail = table.pack(table.unpack(md5_sha1_H)), 0, ""

			local function partial(message_part)
				if message_part then
					local partLength = #message_part
					if tail then
						length = length + partLength
						local offs = 0
						if tail ~= "" and #tail + partLength >= 64 then
							offs = 64 - #tail
							sha1_feed_64(H, tail .. string.sub(message_part, 1, offs), 0, 64)
							tail = ""
						end

						local size = partLength - offs
						local size_tail = size % 64
						sha1_feed_64(H, message_part, offs, size - size_tail)
						tail = tail .. string.sub(message_part, partLength + 1 - size_tail)
						return partial
					else
						error("Adding more chunks is not allowed after receiving the result", 2)
					end
				else
					if tail then
						local final_blocks = table.create(10) --{tail, "\128", string.rep("\0", (-9 - length) % 64 + 1)}
						final_blocks[1] = tail
						final_blocks[2] = "\128"
						final_blocks[3] = string.rep("\0", (-9 - length) % 64 + 1)
						tail = nil

						-- Assuming user data length is shorter than (TWO_POW_53)-9 bytes
						-- TWO_POW_53 bytes = TWO_POW_56 bits, so "bit-counter" fits in 7 bytes
						length = length * (8 / TWO56_POW_7) -- convert "byte-counter" to "bit-counter" and move decimal point to the left
						for j = 4, 10 do
							length = length % 1 * 256
							final_blocks[j] = string.char(math.floor(length))
						end

						final_blocks = table.concat(final_blocks)
						sha1_feed_64(H, final_blocks, 0, #final_blocks)
						for j = 1, 5 do
							H[j] = string.format("%08x", H[j] % 4294967296)
						end

						H = table.concat(H)
					end

					return H
				end
			end

			if message then
				-- Actually perform calculations and return the SHA-1 digest of a message
				return partial(message)()
			else
				-- Return function for chunk-by-chunk loading
				-- User should feed every chunk of input data as single argument to this function and finally get SHA-1 digest by invoking this function without an argument
				return partial
			end
		end

		local function keccak(block_size_in_bytes, digest_size_in_bytes, is_SHAKE, message)
			-- "block_size_in_bytes" is multiple of 8
			if type(digest_size_in_bytes) ~= "number" then
				-- arguments in SHAKE are swapped:
				--	NIST FIPS 202 defines SHAKE(message,num_bits)
				--	this module   defines SHAKE(num_bytes,message)
				-- it's easy to forget about this swap, hence the check
				error("Argument 'digest_size_in_bytes' must be a number", 2)
			end

			-- Create an instance (private objects for current calculation)
			local tail, lanes_lo, lanes_hi = "", table.create(25, 0), hi_factor_keccak == 0 and table.create(25, 0)
			local result

			--~	 pad the input N using the pad function, yielding a padded bit string P with a length divisible by r (such that n = len(P)/r is integer),
			--~	 break P into n consecutive r-bit pieces P0, ..., Pn-1 (last is zero-padded)
			--~	 initialize the state S to a string of b 0 bits.
			--~	 absorb the input into the state: For each block Pi,
			--~		 extend Pi at the end by a string of c 0 bits, yielding one of length b,
			--~		 XOR that with S and
			--~		 apply the block permutation f to the result, yielding a new state S
			--~	 initialize Z to be the empty string
			--~	 while the length of Z is less than d:
			--~		 append the first r bits of S to Z
			--~		 if Z is still less than d bits long, apply f to S, yielding a new state S.
			--~	 truncate Z to d bits
			local function partial(message_part)
				if message_part then
					local partLength = #message_part
					if tail then
						local offs = 0
						if tail ~= "" and #tail + partLength >= block_size_in_bytes then
							offs = block_size_in_bytes - #tail
							keccak_feed(lanes_lo, lanes_hi, tail .. string.sub(message_part, 1, offs), 0, block_size_in_bytes, block_size_in_bytes)
							tail = ""
						end

						local size = partLength - offs
						local size_tail = size % block_size_in_bytes
						keccak_feed(lanes_lo, lanes_hi, message_part, offs, size - size_tail, block_size_in_bytes)
						tail = tail .. string.sub(message_part, partLength + 1 - size_tail)
						return partial
					else
						error("Adding more chunks is not allowed after receiving the result", 2)
					end
				else
					if tail then
						-- append the following bits to the message: for usual SHA3: 011(0*)1, for SHAKE: 11111(0*)1
						local gap_start = is_SHAKE and 31 or 6
						tail = tail .. (#tail + 1 == block_size_in_bytes and string.char(gap_start + 128) or string.char(gap_start) .. string.rep("\0", (-2 - #tail) % block_size_in_bytes) .. "\128")
						keccak_feed(lanes_lo, lanes_hi, tail, 0, #tail, block_size_in_bytes)
						tail = nil

						local lanes_used = 0
						local total_lanes = math.floor(block_size_in_bytes / 8)
						local qwords = {}

						local function get_next_qwords_of_digest(qwords_qty)
							-- returns not more than 'qwords_qty' qwords ('qwords_qty' might be non-integer)
							-- doesn't go across keccak-buffer boundary
							-- block_size_in_bytes is a multiple of 8, so, keccak-buffer contains integer number of qwords
							if lanes_used >= total_lanes then
								keccak_feed(lanes_lo, lanes_hi, "\0\0\0\0\0\0\0\0", 0, 8, 8)
								lanes_used = 0
							end

							qwords_qty = math.floor(math.min(qwords_qty, total_lanes - lanes_used))
							if hi_factor_keccak ~= 0 then
								for j = 1, qwords_qty do
									qwords[j] = HEX64(lanes_lo[lanes_used + j - 1 + lanes_index_base])
								end
							else
								for j = 1, qwords_qty do
									qwords[j] = string.format("%08x", lanes_hi[lanes_used + j] % 4294967296) .. string.format("%08x", lanes_lo[lanes_used + j] % 4294967296)
								end
							end

							lanes_used = lanes_used + qwords_qty
							return string.gsub(table.concat(qwords, "", 1, qwords_qty), "(..)(..)(..)(..)(..)(..)(..)(..)", "%8%7%6%5%4%3%2%1"), qwords_qty * 8
						end

						local parts = {} -- digest parts
						local last_part, last_part_size = "", 0

						local function get_next_part_of_digest(bytes_needed)
							-- returns 'bytes_needed' bytes, for arbitrary integer 'bytes_needed'
							bytes_needed = bytes_needed or 1
							if bytes_needed <= last_part_size then
								last_part_size = last_part_size - bytes_needed
								local part_size_in_nibbles = bytes_needed * 2
								local result = string.sub(last_part, 1, part_size_in_nibbles)
								last_part = string.sub(last_part, part_size_in_nibbles + 1)
								return result
							end

							local parts_qty = 0
							if last_part_size > 0 then
								parts_qty = 1
								parts[parts_qty] = last_part
								bytes_needed = bytes_needed - last_part_size
							end

							-- repeats until the length is enough
							while bytes_needed >= 8 do
								local next_part, next_part_size = get_next_qwords_of_digest(bytes_needed / 8)
								parts_qty = parts_qty + 1
								parts[parts_qty] = next_part
								bytes_needed = bytes_needed - next_part_size
							end

							if bytes_needed > 0 then
								last_part, last_part_size = get_next_qwords_of_digest(1)
								parts_qty = parts_qty + 1
								parts[parts_qty] = get_next_part_of_digest(bytes_needed)
							else
								last_part, last_part_size = "", 0
							end

							return table.concat(parts, "", 1, parts_qty)
						end

						if digest_size_in_bytes < 0 then
							result = get_next_part_of_digest
						else
							result = get_next_part_of_digest(digest_size_in_bytes)
						end

					end

					return result
				end
			end

			if message then
				-- Actually perform calculations and return the SHA3 digest of a message
				return partial(message)()
			else
				-- Return function for chunk-by-chunk loading
				-- User should feed every chunk of input data as single argument to this function and finally get SHA3 digest by invoking this function without an argument
				return partial
			end
		end

		local function HexToBinFunction(hh)
			return string.char(tonumber(hh, 16))
		end

		local function hex2bin(hex_string)
			return (string.gsub(hex_string, "%x%x", HexToBinFunction))
		end

		local base64_symbols = {
			["+"] = 62, ["-"] = 62, [62] = "+";
			["/"] = 63, ["_"] = 63, [63] = "/";
			["="] = -1, ["."] = -1, [-1] = "=";
		}

		local symbol_index = 0
		for j, pair in ipairs{"AZ", "az", "09"} do
			for ascii = string.byte(pair), string.byte(pair, 2) do
				local ch = string.char(ascii)
				base64_symbols[ch] = symbol_index
				base64_symbols[symbol_index] = ch
				symbol_index = symbol_index + 1
			end
		end

		local function bin2base64(binary_string)
			local stringLength = #binary_string
			local result = table.create(math.ceil(stringLength / 3))
			local length = 0

			for pos = 1, #binary_string, 3 do
				local c1, c2, c3, c4 = string.byte(string.sub(binary_string, pos, pos + 2) .. '\0', 1, -1)
				length = length + 1
				result[length] =
					base64_symbols[math.floor(c1 / 4)] ..
					base64_symbols[c1 % 4 * 16 + math.floor(c2 / 16)] ..
					base64_symbols[c3 and c2 % 16 * 4 + math.floor(c3 / 64) or -1] ..
					base64_symbols[c4 and c3 % 64 or -1]
			end

			return table.concat(result)
		end

		local function base642bin(base64_string)
			local result, chars_qty = {}, 3
			for pos, ch in string.gmatch(string.gsub(base64_string, "%s+", ""), "()(.)") do
				local code = base64_symbols[ch]
				if code < 0 then
					chars_qty = chars_qty - 1
					code = 0
				end

				local idx = pos % 4
				if idx > 0 then
					result[-idx] = code
				else
					local c1 = result[-1] * 4 + math.floor(result[-2] / 16)
					local c2 = (result[-2] % 16) * 16 + math.floor(result[-3] / 4)
					local c3 = (result[-3] % 4) * 64 + code
					result[#result + 1] = string.sub(string.char(c1, c2, c3), 1, chars_qty)
				end
			end

			return table.concat(result)
		end

		local block_size_for_HMAC -- this table will be initialized at the end of the module
		--local function pad_and_xor(str, result_length, byte_for_xor)
		--	return string.gsub(str, ".", function(c)
		--		return string.char(bit32_bxor(string.byte(c), byte_for_xor))
		--	end) .. string.rep(string.char(byte_for_xor), result_length - #str)
		--end

		-- For the sake of speed of converting hexes to strings, there's a map of the conversions here
		local BinaryStringMap = {}
		for Index = 0, 255 do
			BinaryStringMap[string.format("%02x", Index)] = string.char(Index)
		end

		-- Update 02.14.20 - added AsBinary for easy GameAnalytics replacement.
		local function hmac(hash_func, key, message, AsBinary)
			-- Create an instance (private objects for current calculation)
			local block_size = block_size_for_HMAC[hash_func]
			if not block_size then
				error("Unknown hash function", 2)
			end

			local KeyLength = #key
			if KeyLength > block_size then
				key = string.gsub(hash_func(key), "%x%x", HexToBinFunction)
				KeyLength = #key
			end

			local append = hash_func()(string.gsub(key, ".", function(c)
				return string.char(bit32_bxor(string.byte(c), 0x36))
			end) .. string.rep("6", block_size - KeyLength)) -- 6 = string.char(0x36)

			local result

			local function partial(message_part)
				if not message_part then
					result = result or hash_func(
						string.gsub(key, ".", function(c)
							return string.char(bit32_bxor(string.byte(c), 0x5c))
						end) .. string.rep("\\", block_size - KeyLength) -- \ = string.char(0x5c)
							.. (string.gsub(append(), "%x%x", HexToBinFunction))
					)

					return result
				elseif result then
					error("Adding more chunks is not allowed after receiving the result", 2)
				else
					append(message_part)
					return partial
				end
			end

			if message then
				-- Actually perform calculations and return the HMAC of a message
				local FinalMessage = partial(message)()
				return AsBinary and (string.gsub(FinalMessage, "%x%x", BinaryStringMap)) or FinalMessage
			else
				-- Return function for chunk-by-chunk loading of a message
				-- User should feed every chunk of the message as single argument to this function and finally get HMAC by invoking this function without an argument
				return partial
			end
		end

		local sha = {
			md5 = md5,
			sha1 = sha1,
			-- SHA2 hash functions:
			sha224 = function(message)
				return sha256ext(224, message)
			end;

			sha256 = function(message)
				return sha256ext(256, message)
			end;

			sha512_224 = function(message)
				return sha512ext(224, message)
			end;

			sha512_256 = function(message)
				return sha512ext(256, message)
			end;

			sha384 = function(message)
				return sha512ext(384, message)
			end;

			sha512 = function(message)
				return sha512ext(512, message)
			end;

			-- SHA3 hash functions:
			sha3_224 = function(message)
				return keccak((1600 - 2 * 224) / 8, 224 / 8, false, message)
			end;

			sha3_256 = function(message)
				return keccak((1600 - 2 * 256) / 8, 256 / 8, false, message)
			end;

			sha3_384 = function(message)
				return keccak((1600 - 2 * 384) / 8, 384 / 8, false, message)
			end;

			sha3_512 = function(message)
				return keccak((1600 - 2 * 512) / 8, 512 / 8, false, message)
			end;

			shake128 = function(message, digest_size_in_bytes)
				return keccak((1600 - 2 * 128) / 8, digest_size_in_bytes, true, message)
			end;

			shake256 = function(message, digest_size_in_bytes)
				return keccak((1600 - 2 * 256) / 8, digest_size_in_bytes, true, message)
			end;

			-- misc utilities:
			hmac = hmac; -- HMAC(hash_func, key, message) is applicable to any hash function from this module except SHAKE*
			hex_to_bin = hex2bin; -- converts hexadecimal representation to binary string
			base64_to_bin = base642bin; -- converts base64 representation to binary string
			bin_to_base64 = bin2base64; -- converts binary string to base64 representation
		}

		block_size_for_HMAC = {
			[sha.md5] = 64;
			[sha.sha1] = 64;
			[sha.sha224] = 64;
			[sha.sha256] = 64;
			[sha.sha512_224] = 128;
			[sha.sha512_256] = 128;
			[sha.sha384] = 128;
			[sha.sha512] = 128;
			[sha.sha3_224] = (1600 - 2 * 224) / 8;
			[sha.sha3_256] = (1600 - 2 * 256) / 8;
			[sha.sha3_384] = (1600 - 2 * 384) / 8;
			[sha.sha3_512] = (1600 - 2 * 512) / 8;
		}

		return sha
	end,
	prediction = function()
		--[[
	Prediction Library
	Source: https://devforum.roblox.com/t/predict-projectile-ballistics-including-gravity-and-motion/1842434
]]
		local module = {}
		local eps = 1e-9
		local function isZero(d)
			return (d > -eps and d < eps)
		end

		local function cuberoot(x)
			return (x > 0) and math.pow(x, (1 / 3)) or -math.pow(math.abs(x), (1 / 3))
		end

		local function solveQuadric(c0, c1, c2)
			local s0, s1

			local p, q, D

			p = c1 / (2 * c0)
			q = c2 / c0
			D = p * p - q

			if isZero(D) then
				s0 = -p
				return s0
			elseif (D < 0) then
				return
			else -- if (D > 0)
				local sqrt_D = math.sqrt(D)

				s0 = sqrt_D - p
				s1 = -sqrt_D - p
				return s0, s1
			end
		end

		local function solveCubic(c0, c1, c2, c3)
			local s0, s1, s2

			local num, sub
			local A, B, C
			local sq_A, p, q
			local cb_p, D

			A = c1 / c0
			B = c2 / c0
			C = c3 / c0

			sq_A = A * A
			p = (1 / 3) * (-(1 / 3) * sq_A + B)
			q = 0.5 * ((2 / 27) * A * sq_A - (1 / 3) * A * B + C)

			cb_p = p * p * p
			D = q * q + cb_p

			if isZero(D) then
				if isZero(q) then -- one triple solution
					s0 = 0
					num = 1
				else -- one single and one double solution
					local u = cuberoot(-q)
					s0 = 2 * u
					s1 = -u
					num = 2
				end
			elseif (D < 0) then -- Casus irreducibilis: three real solutions
				local phi = (1 / 3) * math.acos(-q / math.sqrt(-cb_p))
				local t = 2 * math.sqrt(-p)

				s0 = t * math.cos(phi)
				s1 = -t * math.cos(phi + math.pi / 3)
				s2 = -t * math.cos(phi - math.pi / 3)
				num = 3
			else -- one real solution
				local sqrt_D = math.sqrt(D)
				local u = cuberoot(sqrt_D - q)
				local v = -cuberoot(sqrt_D + q)

				s0 = u + v
				num = 1
			end

			sub = (1 / 3) * A

			if (num > 0) then s0 = s0 - sub end
			if (num > 1) then s1 = s1 - sub end
			if (num > 2) then s2 = s2 - sub end

			return s0, s1, s2
		end

		function module.solveQuartic(c0, c1, c2, c3, c4)
			local s0, s1, s2, s3

			local coeffs = {}
			local z, u, v, sub
			local A, B, C, D
			local sq_A, p, q, r
			local num

			A = c1 / c0
			B = c2 / c0
			C = c3 / c0
			D = c4 / c0

			sq_A = A * A
			p = -0.375 * sq_A + B
			q = 0.125 * sq_A * A - 0.5 * A * B + C
			r = -(3 / 256) * sq_A * sq_A + 0.0625 * sq_A * B - 0.25 * A * C + D

			if isZero(r) then
				coeffs[3] = q
				coeffs[2] = p
				coeffs[1] = 0
				coeffs[0] = 1

				local results = {solveCubic(coeffs[0], coeffs[1], coeffs[2], coeffs[3])}
				num = #results
				s0, s1, s2 = results[1], results[2], results[3]
			else
				coeffs[3] = 0.5 * r * p - 0.125 * q * q
				coeffs[2] = -r
				coeffs[1] = -0.5 * p
				coeffs[0] = 1

				s0, s1, s2 = solveCubic(coeffs[0], coeffs[1], coeffs[2], coeffs[3])
				z = s0

				u = z * z - r
				v = 2 * z - p

				if isZero(u) then
					u = 0
				elseif (u > 0) then
					u = math.sqrt(u)
				else
					return
				end
				if isZero(v) then
					v = 0
				elseif (v > 0) then
					v = math.sqrt(v)
				else
					return
				end

				coeffs[2] = z - u
				coeffs[1] = q < 0 and -v or v
				coeffs[0] = 1

				do
					local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
					num = #results
					s0, s1 = results[1], results[2]
				end

				coeffs[2] = z + u
				coeffs[1] = q < 0 and v or -v
				coeffs[0] = 1

				if (num == 0) then
					local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
					num = num + #results
					s0, s1 = results[1], results[2]
				end
				if (num == 1) then
					local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
					num = num + #results
					s1, s2 = results[1], results[2]
				end
				if (num == 2) then
					local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
					num = num + #results
					s2, s3 = results[1], results[2]
				end
			end

			sub = 0.25 * A

			if (num > 0) then s0 = s0 - sub end
			if (num > 1) then s1 = s1 - sub end
			if (num > 2) then s2 = s2 - sub end
			if (num > 3) then s3 = s3 - sub end

			return {s3, s2, s1, s0}
		end

		function module.SolveTrajectory(origin, projectileSpeed, gravity, targetPos, targetVelocity, playerGravity, playerHeight, playerJump, params)
			local disp = targetPos - origin
			local p, q, r = targetVelocity.X, targetVelocity.Y, targetVelocity.Z
			local h, j, k = disp.X, disp.Y, disp.Z
			local l = -.5 * gravity
			--attemped gravity calculation, may return to it in the future.
			if math.abs(q) > 0.01 and playerGravity and playerGravity > 0 then
				local estTime = (disp.Magnitude / projectileSpeed)
				local origq = q
				local origj = j
				for i = 1, 100 do
					q -= (.5 * playerGravity) * estTime
					local velo = targetVelocity * 0.016
					local ray = workspace.Raycast(workspace, Vector3.new(targetPos.X, targetPos.Y, targetPos.Z), Vector3.new(velo.X, (q * estTime) - playerHeight, velo.Z), params)
					if ray then
						local newTarget = ray.Position + Vector3.new(0, playerHeight, 0)
						estTime -= math.sqrt(((targetPos - newTarget).Magnitude * 2) / playerGravity)
						targetPos = newTarget
						j = (targetPos - origin).Y
						q = 0
						break
					else
						break
					end
				end
			end

			local solutions = module.solveQuartic(
				l*l,
				-2*q*l,
				q*q - 2*j*l - projectileSpeed*projectileSpeed + p*p + r*r,
				2*j*q + 2*h*p + 2*k*r,
				j*j + h*h + k*k
			)
			if solutions then
				local posRoots = table.create(2)
				for _, v in solutions do --filter out the negative roots
					if v > 0 then
						table.insert(posRoots, v)
					end
				end
				posRoots[1] = posRoots[1]
				if posRoots[1] then
					local t = posRoots[1]
					local d = (h + p*t)/t
					local e = (j + q*t - l*t*t)/t
					local f = (k + r*t)/t
					return origin + Vector3.new(d, e, f)
				end
			elseif gravity == 0 then
				local t = (disp.Magnitude / projectileSpeed)
				local d = (h + p*t)/t
				local e = (j + q*t - l*t*t)/t
				local f = (k + r*t)/t
				return origin + Vector3.new(d, e, f)
			end
		end

		return module
	end,
	vm = function()
		--[[
	Prediction Library
	Source: https://devforum.roblox.com/t/predict-projectile-ballistics-including-gravity-and-motion/1842434
]]
		local module = {}
		local eps = 1e-9
		local function isZero(d)
			return (d > -eps and d < eps)
		end

		local function cuberoot(x)
			return (x > 0) and math.pow(x, (1 / 3)) or -math.pow(math.abs(x), (1 / 3))
		end

		local function solveQuadric(c0, c1, c2)
			local s0, s1

			local p, q, D

			p = c1 / (2 * c0)
			q = c2 / c0
			D = p * p - q

			if isZero(D) then
				s0 = -p
				return s0
			elseif (D < 0) then
				return
			else -- if (D > 0)
				local sqrt_D = math.sqrt(D)

				s0 = sqrt_D - p
				s1 = -sqrt_D - p
				return s0, s1
			end
		end

		local function solveCubic(c0, c1, c2, c3)
			local s0, s1, s2

			local num, sub
			local A, B, C
			local sq_A, p, q
			local cb_p, D

			A = c1 / c0
			B = c2 / c0
			C = c3 / c0

			sq_A = A * A
			p = (1 / 3) * (-(1 / 3) * sq_A + B)
			q = 0.5 * ((2 / 27) * A * sq_A - (1 / 3) * A * B + C)

			cb_p = p * p * p
			D = q * q + cb_p

			if isZero(D) then
				if isZero(q) then -- one triple solution
					s0 = 0
					num = 1
				else -- one single and one double solution
					local u = cuberoot(-q)
					s0 = 2 * u
					s1 = -u
					num = 2
				end
			elseif (D < 0) then -- Casus irreducibilis: three real solutions
				local phi = (1 / 3) * math.acos(-q / math.sqrt(-cb_p))
				local t = 2 * math.sqrt(-p)

				s0 = t * math.cos(phi)
				s1 = -t * math.cos(phi + math.pi / 3)
				s2 = -t * math.cos(phi - math.pi / 3)
				num = 3
			else -- one real solution
				local sqrt_D = math.sqrt(D)
				local u = cuberoot(sqrt_D - q)
				local v = -cuberoot(sqrt_D + q)

				s0 = u + v
				num = 1
			end

			sub = (1 / 3) * A

			if (num > 0) then s0 = s0 - sub end
			if (num > 1) then s1 = s1 - sub end
			if (num > 2) then s2 = s2 - sub end

			return s0, s1, s2
		end

		function module.solveQuartic(c0, c1, c2, c3, c4)
			local s0, s1, s2, s3

			local coeffs = {}
			local z, u, v, sub
			local A, B, C, D
			local sq_A, p, q, r
			local num

			A = c1 / c0
			B = c2 / c0
			C = c3 / c0
			D = c4 / c0

			sq_A = A * A
			p = -0.375 * sq_A + B
			q = 0.125 * sq_A * A - 0.5 * A * B + C
			r = -(3 / 256) * sq_A * sq_A + 0.0625 * sq_A * B - 0.25 * A * C + D

			if isZero(r) then
				coeffs[3] = q
				coeffs[2] = p
				coeffs[1] = 0
				coeffs[0] = 1

				local results = {solveCubic(coeffs[0], coeffs[1], coeffs[2], coeffs[3])}
				num = #results
				s0, s1, s2 = results[1], results[2], results[3]
			else
				coeffs[3] = 0.5 * r * p - 0.125 * q * q
				coeffs[2] = -r
				coeffs[1] = -0.5 * p
				coeffs[0] = 1

				s0, s1, s2 = solveCubic(coeffs[0], coeffs[1], coeffs[2], coeffs[3])
				z = s0

				u = z * z - r
				v = 2 * z - p

				if isZero(u) then
					u = 0
				elseif (u > 0) then
					u = math.sqrt(u)
				else
					return
				end
				if isZero(v) then
					v = 0
				elseif (v > 0) then
					v = math.sqrt(v)
				else
					return
				end

				coeffs[2] = z - u
				coeffs[1] = q < 0 and -v or v
				coeffs[0] = 1

				do
					local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
					num = #results
					s0, s1 = results[1], results[2]
				end

				coeffs[2] = z + u
				coeffs[1] = q < 0 and v or -v
				coeffs[0] = 1

				if (num == 0) then
					local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
					num = num + #results
					s0, s1 = results[1], results[2]
				end
				if (num == 1) then
					local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
					num = num + #results
					s1, s2 = results[1], results[2]
				end
				if (num == 2) then
					local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
					num = num + #results
					s2, s3 = results[1], results[2]
				end
			end

			sub = 0.25 * A

			if (num > 0) then s0 = s0 - sub end
			if (num > 1) then s1 = s1 - sub end
			if (num > 2) then s2 = s2 - sub end
			if (num > 3) then s3 = s3 - sub end

			return {s3, s2, s1, s0}
		end

		function module.SolveTrajectory(origin, projectileSpeed, gravity, targetPos, targetVelocity, playerGravity, playerHeight, playerJump, params)
			local disp = targetPos - origin
			local p, q, r = targetVelocity.X, targetVelocity.Y, targetVelocity.Z
			local h, j, k = disp.X, disp.Y, disp.Z
			local l = -.5 * gravity
			--attemped gravity calculation, may return to it in the future.
			if math.abs(q) > 0.01 and playerGravity and playerGravity > 0 then
				local estTime = (disp.Magnitude / projectileSpeed)
				local origq = q
				local origj = j
				for i = 1, 100 do
					q -= (.5 * playerGravity) * estTime
					local velo = targetVelocity * 0.016
					local ray = workspace.Raycast(workspace, Vector3.new(targetPos.X, targetPos.Y, targetPos.Z), Vector3.new(velo.X, (q * estTime) - playerHeight, velo.Z), params)
					if ray then
						local newTarget = ray.Position + Vector3.new(0, playerHeight, 0)
						estTime -= math.sqrt(((targetPos - newTarget).Magnitude * 2) / playerGravity)
						targetPos = newTarget
						j = (targetPos - origin).Y
						q = 0
						break
					else
						break
					end
				end
			end

			local solutions = module.solveQuartic(
				l*l,
				-2*q*l,
				q*q - 2*j*l - projectileSpeed*projectileSpeed + p*p + r*r,
				2*j*q + 2*h*p + 2*k*r,
				j*j + h*h + k*k
			)
			if solutions then
				local posRoots = table.create(2)
				for _, v in solutions do --filter out the negative roots
					if v > 0 then
						table.insert(posRoots, v)
					end
				end
				posRoots[1] = posRoots[1]
				if posRoots[1] then
					local t = posRoots[1]
					local d = (h + p*t)/t
					local e = (j + q*t - l*t*t)/t
					local f = (k + r*t)/t
					return origin + Vector3.new(d, e, f)
				end
			elseif gravity == 0 then
				local t = (disp.Magnitude / projectileSpeed)
				local d = (h + p*t)/t
				local e = (j + q*t - l*t*t)/t
				local f = (k + r*t)/t
				return origin + Vector3.new(d, e, f)
			end
		end

		return module
	end,
}

local games = {
	[6872265039] = function()
		local run = function(func) func() end
		local cloneref = cloneref or function(obj) return obj end

		local playersService = cloneref(game:GetService('Players'))
		local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
		local inputService = cloneref(game:GetService('UserInputService'))

		local lplr = playersService.LocalPlayer
		local vape = shared.vape
		local entitylib = vape.Libraries.entity
		local sessioninfo = vape.Libraries.sessioninfo
		local bedwars = {}

		local function notif(...)
			return vape:CreateNotification(...)
		end

		run(function()
			local function dumpRemote(tab)
				local ind = table.find(tab, 'Client')
				return ind and tab[ind + 1] or ''
			end

			local KnitInit, Knit
			repeat
				KnitInit, Knit = pcall(function() return debug.getupvalue(require(lplr.PlayerScripts.TS.knit).setup, 9) end)
				if KnitInit then break end
				task.wait()
			until KnitInit
			if not debug.getupvalue(Knit.Start, 1) then
				repeat task.wait() until debug.getupvalue(Knit.Start, 1)
			end
			local Flamework = require(replicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out).Flamework
			local Client = require(replicatedStorage.TS.remotes).default.Client

			bedwars = setmetatable({
				Client = Client,
				CrateItemMeta = debug.getupvalue(Flamework.resolveDependency('client/controllers/global/reward-crate/crate-controller@CrateController').onStart, 3),
				Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore
			}, {
				__index = function(self, ind)
					rawset(self, ind, Knit.Controllers[ind])
					return rawget(self, ind)
				end
			})

			local kills = sessioninfo:AddItem('Kills')
			local beds = sessioninfo:AddItem('Beds')
			local wins = sessioninfo:AddItem('Wins')
			local games = sessioninfo:AddItem('Games')

			vape:Clean(function()
				table.clear(bedwars)
			end)
		end)

		for _, v in vape.Modules do
			if v.Category == 'Combat' or v.Category == 'Minigames' then
				vape:Remove(i)
			end
		end

		run(function()
			local Sprint
			local old

			Sprint = vape.Categories.Combat:CreateModule({
				Name = 'Sprint',
				Function = function(callback)
					if callback then
						if inputService.TouchEnabled then pcall(function() lplr.PlayerGui.MobileUI['2'].Visible = false end) end
						old = bedwars.SprintController.stopSprinting
						bedwars.SprintController.stopSprinting = function(...)
							local call = old(...)
							bedwars.SprintController:startSprinting()
							return call
						end
						Sprint:Clean(entitylib.Events.LocalAdded:Connect(function() bedwars.SprintController:stopSprinting() end))
						bedwars.SprintController:stopSprinting()
					else
						if inputService.TouchEnabled then pcall(function() lplr.PlayerGui.MobileUI['2'].Visible = true end) end
						bedwars.SprintController.stopSprinting = old
						bedwars.SprintController:stopSprinting()
					end
				end,
				Tooltip = 'Sets your sprinting to true.'
			})
		end)

		run(function()
			local AutoGamble

			AutoGamble = vape.Categories.Minigames:CreateModule({
				Name = 'AutoGamble',
				Function = function(callback)
					if callback then
						AutoGamble:Clean(bedwars.Client:GetNamespace('RewardCrate'):Get('CrateOpened'):Connect(function(data)
							if data.openingPlayer == lplr then
								local tab = bedwars.CrateItemMeta[data.reward.itemType] or {displayName = data.reward.itemType or 'unknown'}
								notif('AutoGamble', 'Won '..tab.displayName, 5)
							end
						end))

						repeat
							if not bedwars.CrateAltarController.activeCrates[1] then
								for _, v in bedwars.Store:getState().Consumable.inventory do
									if v.consumable:find('crate') then
										bedwars.CrateAltarController:pickCrate(v.consumable, 1)
										task.wait(1.2)
										if bedwars.CrateAltarController.activeCrates[1] and bedwars.CrateAltarController.activeCrates[1][2] then
											bedwars.Client:GetNamespace('RewardCrate'):Get('OpenRewardCrate'):SendToServer({
												crateId = bedwars.CrateAltarController.activeCrates[1][2].attributes.crateId
											})
										end
										break
									end
								end
							end
							task.wait(1)
						until not AutoGamble.Enabled
					end
				end,
				Tooltip = 'Automatically opens lucky crates, piston inspired!'
			})
		end)
	end,
	[8444591321] = function()
		local vape = shared.vape
		local loadstring = function(...)
			local res, err = loadstring(...)
			if err and vape then 
				vape:CreateNotification('Lunar', 'Failed to load : '..err, 30, 'alert') 
			end
			return res
		end
		local isfile = isfile or function(file)
			local suc, res = pcall(function() 
				return readfile(file) 
			end)
			return suc and res ~= nil and res ~= ''
		end
		local function downloadFile(path, func)
			if not isfile(path) then
				local suc, res = pcall(function() 
					return game:HttpGet('https://raw.githubusercontent.com/xylex1/LunarClient/'..readfile('newlunar/profiles/commit.txt')..'/'..select(1, path:gsub('newlunar/', '')), true) 
				end)
				if not suc or res == '404: Not Found' then 
					error(res) 
				end
				if path:find('.lua') then 
					res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after lunar updates.\n'..res 
				end
				writefile(path, res)
			end
			return (func or readfile)(path)
		end

		vape.Place = 6872274481
		if isfile('newlunar/games/'..vape.Place..'.lua') then
			loadstring(readfile('newlunar/games/'..vape.Place..'.lua'), 'bedwars')()
		else
			if not shared.VapeDeveloper then
				local suc, res = pcall(function() 
					return game:HttpGet('https://raw.githubusercontent.com/xylex1/LunarClient/'..readfile('newlunar/profiles/commit.txt')..'/games/'..vape.Place..'.lua', true) 
				end)
				if suc and res ~= '404: Not Found' then
					loadstring(game:HttpGet('https://raw.githubusercontent.com/xylex1/LunarClient/main/games/'..vape.Place..'.lua'), 'bedwars')()
				end
			end
		end
	end,
	[8560631822] = function()
		local vape = shared.vape
		local loadstring = function(...)
			local res, err = loadstring(...)
			if err and vape then 
				vape:CreateNotification('Lunar', 'Failed to load : '..err, 30, 'alert') 
			end
			return res
		end
		local isfile = isfile or function(file)
			local suc, res = pcall(function() 
				return readfile(file) 
			end)
			return suc and res ~= nil and res ~= ''
		end
		local function downloadFile(path, func)
			if not isfile(path) then
				local suc, res = pcall(function() 
					return game:HttpGet('https://raw.githubusercontent.com/xylex1/LunarClient/'..readfile('newlunar/profiles/commit.txt')..'/'..select(1, path:gsub('newlunar/', '')), true) 
				end)
				if not suc or res == '404: Not Found' then 
					error(res) 
				end
				if path:find('.lua') then 
					res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res 
				end
				writefile(path, res)
			end
			return (func or readfile)(path)
		end

		vape.Place = 6872274481
		if isfile('newlunar/games/'..vape.Place..'.lua') then
			loadstring(readfile('newlunar/games/'..vape.Place..'.lua'), 'bedwars')()
		else
			if not shared.VapeDeveloper then
				local suc, res = pcall(function() 
					return game:HttpGet('https://raw.githubusercontent.com/xylex1/LunarClient/'..readfile('newlunar/profiles/commit.txt')..'/games/'..vape.Place..'.lua', true) 
				end)
				if suc and res ~= '404: Not Found' then
					loadstring(game:HttpGet('https://raw.githubusercontent.com/xylex1/LunarClient/main/games/'..vape.Place..'.lua'), 'bedwars')()
				end
			end
		end
	end,
	[6872274481] = function()
		local run = function(func)
			func()
		end
		local cloneref = cloneref or function(obj)
			return obj
		end
		local vapeEvents = setmetatable({}, {
			__index = function(self, index)
				self[index] = Instance.new('BindableEvent')
				return self[index]
			end
		})

		local playersService = cloneref(game:GetService('Players'))
		local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
		local runService = cloneref(game:GetService('RunService'))
		local inputService = cloneref(game:GetService('UserInputService'))
		local tweenService = cloneref(game:GetService('TweenService'))
		local httpService = cloneref(game:GetService('HttpService'))
		local textChatService = cloneref(game:GetService('TextChatService'))
		local collectionService = cloneref(game:GetService('CollectionService'))
		local contextActionService = cloneref(game:GetService('ContextActionService'))
		local guiService = cloneref(game:GetService('GuiService'))
		local coreGui = cloneref(game:GetService('CoreGui'))
		local starterGui = cloneref(game:GetService('StarterGui'))

		local isnetworkowner = identifyexecutor and table.find({'AWP', 'Nihon'}, ({identifyexecutor()})[1]) and isnetworkowner or function()
			return true
		end
		local gameCamera = workspace.CurrentCamera
		local lplr = playersService.LocalPlayer
		local assetfunction = getcustomasset

		local vape = shared.vape
		local entitylib = vape.Libraries.entity
		local targetinfo = vape.Libraries.targetinfo
		local sessioninfo = vape.Libraries.sessioninfo
		local uipallet = vape.Libraries.uipallet
		local tween = vape.Libraries.tween
		local color = vape.Libraries.color
		local whitelist = vape.Libraries.whitelist
		local prediction = vape.Libraries.prediction
		local getfontsize = vape.Libraries.getfontsize
		local getcustomasset = vape.Libraries.getcustomasset

		local store = {
			attackReach = 0,
			attackReachUpdate = tick(),
			damageBlockFail = tick(),
			hand = {},
			inventory = {
				inventory = {
					items = {},
					armor = {}
				},
				hotbar = {}
			},
			inventories = {},
			matchState = 0,
			queueType = 'bedwars_test',
			tools = {}
		}
		local Reach = {}
		local HitBoxes = {}
		local InfiniteFly = {}
		local TrapDisabler
		local AntiFallPart
		local bedwars, remotes, sides, oldinvrender, oldSwing = {}, {}, {}

		local function addBlur(parent)
			local blur = Instance.new('ImageLabel')
			blur.Name = 'Blur'
			blur.Size = UDim2.new(1, 89, 1, 52)
			blur.Position = UDim2.fromOffset(-48, -31)
			blur.BackgroundTransparency = 1
			blur.Image = 'rbxassetid://14898786664'
			blur.ScaleType = Enum.ScaleType.Slice
			blur.SliceCenter = Rect.new(52, 31, 261, 502)
			blur.Parent = parent
			return blur
		end

		local function collection(tags, module, customadd, customremove)
			tags = typeof(tags) ~= 'table' and {tags} or tags
			local objs, connections = {}, {}

			for _, tag in tags do
				table.insert(connections, collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
					if customadd then
						customadd(objs, v, tag)
						return
					end
					table.insert(objs, v)
				end))
				table.insert(connections, collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
					if customremove then
						customremove(objs, v, tag)
						return
					end
					v = table.find(objs, v)
					if v then
						table.remove(objs, v)
					end
				end))

				for _, v in collectionService:GetTagged(tag) do
					if customadd then
						customadd(objs, v, tag)
						continue
					end
					table.insert(objs, v)
				end
			end

			local cleanFunc = function(self)
				for _, v in connections do
					v:Disconnect()
				end
				table.clear(connections)
				table.clear(objs)
				table.clear(self)
			end
			if module then
				module:Clean(cleanFunc)
			end
			return objs, cleanFunc
		end

		local function getBestArmor(slot)
			local closest, mag = nil, 0

			for _, item in store.inventory.inventory.items do
				local meta = item and bedwars.ItemMeta[item.itemType] or {}

				if meta.armor and meta.armor.slot == slot then
					local newmag = (meta.armor.damageReductionMultiplier or 0)

					if newmag > mag then
						closest, mag = item, newmag
					end
				end
			end

			return closest
		end

		local function getBow()
			local bestBow, bestBowSlot, bestBowDamage = nil, nil, 0
			for slot, item in store.inventory.inventory.items do
				local bowMeta = bedwars.ItemMeta[item.itemType].projectileSource
				if bowMeta and table.find(bowMeta.ammoItemTypes, 'arrow') then
					local bowDamage = bedwars.ProjectileMeta[bowMeta.projectileType('arrow')].combat.damage or 0
					if bowDamage > bestBowDamage then
						bestBow, bestBowSlot, bestBowDamage = item, slot, bowDamage
					end
				end
			end
			return bestBow, bestBowSlot
		end

		local function getItem(itemName, inv)
			for slot, item in (inv or store.inventory.inventory.items) do
				if item.itemType == itemName then
					return item, slot
				end
			end
			return nil
		end

		local function getRoactRender(func)
			return debug.getupvalue(debug.getupvalue(debug.getupvalue(func, 3).render, 2).render, 1)
		end

		local function getSword()
			local bestSword, bestSwordSlot, bestSwordDamage = nil, nil, 0
			for slot, item in store.inventory.inventory.items do
				local swordMeta = bedwars.ItemMeta[item.itemType].sword
				if swordMeta then
					local swordDamage = swordMeta.damage or 0
					if swordDamage > bestSwordDamage then
						bestSword, bestSwordSlot, bestSwordDamage = item, slot, swordDamage
					end
				end
			end
			return bestSword, bestSwordSlot
		end

		local function getTool(breakType)
			local bestTool, bestToolSlot, bestToolDamage = nil, nil, 0
			for slot, item in store.inventory.inventory.items do
				local toolMeta = bedwars.ItemMeta[item.itemType].breakBlock
				if toolMeta then
					local toolDamage = toolMeta[breakType] or 0
					if toolDamage > bestToolDamage then
						bestTool, bestToolSlot, bestToolDamage = item, slot, toolDamage
					end
				end
			end
			return bestTool, bestToolSlot
		end

		local function getWool()
			for _, wool in (inv or store.inventory.inventory.items) do
				if wool.itemType:find('wool') then
					return wool and wool.itemType, wool and wool.amount
				end
			end
		end

		local function getStrength(plr)
			if not plr.Player then
				return 0
			end

			local strength = 0
			for _, v in (store.inventories[plr.Player] or {items = {}}).items do
				local itemmeta = bedwars.ItemMeta[v.itemType]
				if itemmeta and itemmeta.sword and itemmeta.sword.damage > strength then
					strength = itemmeta.sword.damage
				end
			end

			return strength
		end

		local function getPlacedBlock(pos)
			if not pos then
				return
			end
			local roundedPosition = bedwars.BlockController:getBlockPosition(pos)
			return bedwars.BlockController:getStore():getBlockAt(roundedPosition), roundedPosition
		end

		local function getBlocksInPoints(s, e)
			local blocks, list = bedwars.BlockController:getStore(), {}
			for x = s.X, e.X do
				for y = s.Y, e.Y do
					for z = s.Z, e.Z do
						local vec = Vector3.new(x, y, z)
						if blocks:getBlockAt(vec) then
							table.insert(list, vec * 3)
						end
					end
				end
			end
			return list
		end

		local function getNearGround(range)
			range = Vector3.new(3, 3, 3) * (range or 10)
			local localPosition, mag, closest = entitylib.character.RootPart.Position, 60
			local blocks = getBlocksInPoints(bedwars.BlockController:getBlockPosition(localPosition - range), bedwars.BlockController:getBlockPosition(localPosition + range))

			for _, v in blocks do
				if not getPlacedBlock(v + Vector3.new(0, 3, 0)) then
					local newmag = (localPosition - v).Magnitude
					if newmag < mag then
						mag, closest = newmag, v + Vector3.new(0, 3, 0)
					end
				end
			end

			table.clear(blocks)
			return closest
		end

		local function getShieldAttribute(char)
			local returned = 0
			for name, val in char:GetAttributes() do
				if name:find('Shield') and type(val) == 'number' and val > 0 then
					returned += val
				end
			end
			return returned
		end

		local function getSpeed()
			local multi, increase, modifiers = 0, true, bedwars.SprintController:getMovementStatusModifier():getModifiers()

			for v in modifiers do
				local val = v.constantSpeedMultiplier and v.constantSpeedMultiplier or 0
				if val and val > math.max(multi, 1) then
					increase = false
					multi = val - (0.06 * math.round(val))
				end
			end

			for v in modifiers do
				multi += math.max((v.moveSpeedMultiplier or 0) - 1, 0)
			end

			if multi > 0 and increase then
				multi += 0.16 + (0.02 * math.round(multi))
			end

			return 20 * (multi + 1)
		end

		local function getTableSize(tab)
			local ind = 0
			for _ in tab do
				ind += 1
			end
			return ind
		end

		local function hotbarSwitch(slot)
			if slot and store.inventory.hotbarSlot ~= slot then
				bedwars.Store:dispatch({
					type = 'InventorySelectHotbarSlot',
					slot = slot
				})
				vapeEvents.InventoryChanged.Event:Wait()
				return true
			end
			return false
		end

		local function isFriend(plr, recolor)
			if vape.Categories.Friends.Options['Use friends'].Enabled then
				local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
				if recolor then
					friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
				end
				return friend
			end
			return nil
		end

		local function isTarget(plr)
			return table.find(vape.Categories.Targets.ListEnabled, plr.Name) and true
		end

		local function notif(...) return
			vape:CreateNotification(...)
		end

		local function removeTags(str)
			str = str:gsub('<br%s*/>', '\n')
			return (str:gsub('<[^<>]->', ''))
		end

		local function roundPos(vec)
			return Vector3.new(math.round(vec.X / 3) * 3, math.round(vec.Y / 3) * 3, math.round(vec.Z / 3) * 3)
		end

		local function switchItem(tool, delayTime)
			delayTime = delayTime or 0.05
			local check = lplr.Character and lplr.Character:FindFirstChild('HandInvItem') or nil
			if check and check.Value ~= tool and tool.Parent ~= nil then
				task.spawn(function()
					bedwars.Client:Get(remotes.EquipItem):CallServerAsync({hand = tool})
				end)
				check.Value = tool
				if delayTime > 0 then
					task.wait(delayTime)
				end
				return true
			end
		end

		local function waitForChildOfType(obj, name, timeout, prop)
			local check, returned = tick() + timeout
			repeat
				returned = prop and obj[name] or obj:FindFirstChildOfClass(name)
				if returned and returned.Name ~= 'UpperTorso' or check < tick() then
					break
				end
				task.wait()
			until false
			return returned
		end

		local frictionTable, oldfrict = {}, {}
		local frictionConnection
		local frictionState

		local function modifyVelocity(v)
			if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
				oldfrict[v] = v.CustomPhysicalProperties or 'none'
				v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
			end
		end

		local function updateVelocity(force)
			local newState = getTableSize(frictionTable) > 0
			if frictionState ~= newState or force then
				if frictionConnection then
					frictionConnection:Disconnect()
				end
				if newState then
					if entitylib.isAlive then
						for _, v in entitylib.character.Character:GetDescendants() do
							modifyVelocity(v)
						end
						frictionConnection = entitylib.character.Character.DescendantAdded:Connect(modifyVelocity)
					end
				else
					for i, v in oldfrict do
						i.CustomPhysicalProperties = v ~= 'none' and v or nil
					end
					table.clear(oldfrict)
				end
			end
			frictionState = newState
		end

		local kitorder = {
			hannah = 5,
			spirit_assassin = 4,
			dasher = 3,
			jade = 2,
			regent = 1
		}

		local sortmethods = {
			Damage = function(a, b)
				return a.Entity.Character:GetAttribute('LastDamageTakenTime') < b.Entity.Character:GetAttribute('LastDamageTakenTime')
			end,
			Threat = function(a, b)
				return getStrength(a.Entity) > getStrength(b.Entity)
			end,
			Kit = function(a, b)
				return (a.Entity.Player and kitorder[a.Entity.Player:GetAttribute('PlayingAsKit')] or 0) > (b.Entity.Player and kitorder[b.Entity.Player:GetAttribute('PlayingAsKit')] or 0)
			end,
			Health = function(a, b)
				return a.Entity.Health < b.Entity.Health
			end,
			Angle = function(a, b)
				local selfrootpos = entitylib.character.RootPart.Position
				local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
				local angle = math.acos(localfacing:Dot(((a.Entity.RootPart.Position - selfrootpos) * Vector3.new(1, 0, 1)).Unit))
				local angle2 = math.acos(localfacing:Dot(((b.Entity.RootPart.Position - selfrootpos) * Vector3.new(1, 0, 1)).Unit))
				return angle < angle2
			end
		}

		run(function()
			local oldstart = entitylib.start
			local function customEntity(ent)
				if ent:HasTag('inventory-entity') and not ent:HasTag('Monster') then
					return
				end

				entitylib.addEntity(ent, nil, ent:HasTag('Drone') and function(self)
					local droneplr = playersService:GetPlayerByUserId(self.Character:GetAttribute('PlayerUserId'))
					return not droneplr or lplr:GetAttribute('Team') ~= droneplr:GetAttribute('Team')
				end or function(self)
					return lplr:GetAttribute('Team') ~= self.Character:GetAttribute('Team')
				end)
			end

			entitylib.start = function()
				oldstart()
				if entitylib.Running then
					for _, ent in collectionService:GetTagged('entity') do
						customEntity(ent)
					end
					table.insert(entitylib.Connections, collectionService:GetInstanceAddedSignal('entity'):Connect(customEntity))
					table.insert(entitylib.Connections, collectionService:GetInstanceRemovedSignal('entity'):Connect(function(ent)
						entitylib.removeEntity(ent)
					end))
				end
			end

			entitylib.addPlayer = function(plr)
				if plr.Character then
					entitylib.refreshEntity(plr.Character, plr)
				end
				entitylib.PlayerConnections[plr] = {
					plr.CharacterAdded:Connect(function(char)
						entitylib.refreshEntity(char, plr)
					end),
					plr.CharacterRemoving:Connect(function(char)
						entitylib.removeEntity(char, plr == lplr)
					end),
					plr:GetAttributeChangedSignal('Team'):Connect(function()
						for _, v in entitylib.List do
							if v.Targetable ~= entitylib.targetCheck(v) then
								entitylib.refreshEntity(v.Character, v.Player)
							end
						end

						if plr == lplr then
							entitylib.start()
						else
							entitylib.refreshEntity(plr.Character, plr)
						end
					end)
				}
			end

			entitylib.addEntity = function(char, plr, teamfunc)
				if not char then return end
				entitylib.EntityThreads[char] = task.spawn(function()
					local hum, humrootpart, head
					if plr then
						hum = waitForChildOfType(char, 'Humanoid', 10)
						humrootpart = hum and waitForChildOfType(hum, 'RootPart', workspace.StreamingEnabled and 9e9 or 10, true)
						head = char:WaitForChild('Head', 10) or humrootpart
					else
						hum = {HipHeight = 0.5}
						humrootpart = waitForChildOfType(char, 'PrimaryPart', 10, true)
						head = humrootpart
					end
					local updateobjects = plr and plr ~= lplr and {
						char:WaitForChild('ArmorInvItem_0', 5),
						char:WaitForChild('ArmorInvItem_1', 5),
						char:WaitForChild('ArmorInvItem_2', 5),
						char:WaitForChild('HandInvItem', 5)
					} or {}

					if hum and humrootpart then
						local entity = {
							Connections = {},
							Character = char,
							Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char),
							Head = head,
							Humanoid = hum,
							HumanoidRootPart = humrootpart,
							HipHeight = hum.HipHeight + (humrootpart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
							Jumps = 0,
							JumpTick = tick(),
							Jumping = false,
							LandTick = tick(),
							MaxHealth = char:GetAttribute('MaxHealth') or 100,
							NPC = plr == nil,
							Player = plr,
							RootPart = humrootpart,
							TeamCheck = teamfunc
						}

						if plr == lplr then
							entity.AirTime = tick()
							entitylib.character = entity
							entitylib.isAlive = true
							entitylib.Events.LocalAdded:Fire(entity)
							table.insert(entitylib.Connections, char.AttributeChanged:Connect(function(attr)
								vapeEvents.AttributeChanged:Fire(attr)
							end))
						else
							entity.Targetable = entitylib.targetCheck(entity)

							for _, v in entitylib.getUpdateConnections(entity) do
								table.insert(entity.Connections, v:Connect(function()
									entity.Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char)
									entity.MaxHealth = char:GetAttribute('MaxHealth') or 100
									entitylib.Events.EntityUpdated:Fire(entity)
								end))
							end

							for _, v in updateobjects do
								table.insert(entity.Connections, v:GetPropertyChangedSignal('Value'):Connect(function()
									task.delay(0.1, function()
										if bedwars.getInventory then
											store.inventories[plr] = bedwars.getInventory(plr)
											entitylib.Events.EntityUpdated:Fire(entity)
										end
									end)
								end))
							end

							if plr then
								local anim = char:FindFirstChild('Animate')
								if anim then
									pcall(function()
										anim = anim.jump:FindFirstChildWhichIsA('Animation').AnimationId
										table.insert(entity.Connections, hum.Animator.AnimationPlayed:Connect(function(playedanim)
											if playedanim.Animation.AnimationId == anim then
												entity.JumpTick = tick()
												entity.Jumps += 1
												entity.LandTick = tick() + 1
												entity.Jumping = entity.Jumps > 1
											end
										end))
									end)
								end

								task.delay(0.1, function()
									if bedwars.getInventory then
										store.inventories[plr] = bedwars.getInventory(plr)
									end
								end)
							end
							table.insert(entitylib.List, entity)
							entitylib.Events.EntityAdded:Fire(entity)
						end

						table.insert(entity.Connections, char.ChildRemoved:Connect(function(part)
							if part == humrootpart or part == hum or part == head then
								if part == humrootpart and hum.RootPart then
									humrootpart = hum.RootPart
									entity.RootPart = hum.RootPart
									entity.HumanoidRootPart = hum.RootPart
									return
								end
								entitylib.removeEntity(char, plr == lplr)
							end
						end))
					end
					entitylib.EntityThreads[char] = nil
				end)
			end

			entitylib.getUpdateConnections = function(ent)
				local char = ent.Character
				local tab = {
					char:GetAttributeChangedSignal('Health'),
					char:GetAttributeChangedSignal('MaxHealth'),
					{
						Connect = function()
							ent.Friend = ent.Player and isFriend(ent.Player) or nil
							ent.Target = ent.Player and isTarget(ent.Player) or nil
							return {Disconnect = function() end}
						end
					}
				}

				if ent.Player then
					table.insert(tab, ent.Player:GetAttributeChangedSignal('PlayingAsKit'))
				end

				for name, val in char:GetAttributes() do
					if name:find('Shield') and type(val) == 'number' then
						table.insert(tab, char:GetAttributeChangedSignal(name))
					end
				end

				return tab
			end

			entitylib.targetCheck = function(ent)
				if ent.TeamCheck then
					return ent:TeamCheck()
				end
				if ent.NPC then return true end
				if isFriend(ent.Player) then return false end
				if not select(2, whitelist:get(ent.Player)) then return false end
				return lplr:GetAttribute('Team') ~= ent.Player:GetAttribute('Team')
			end
			vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
		end)
		entitylib.start()

		run(function()
			local KnitInit, Knit
			repeat
				KnitInit, Knit = pcall(function()
					return debug.getupvalue(require(lplr.PlayerScripts.TS.knit).setup, 9)
				end)
				if KnitInit then break end
				task.wait()
			until KnitInit

			if not debug.getupvalue(Knit.Start, 1) then
				repeat task.wait() until debug.getupvalue(Knit.Start, 1)
			end

			local Flamework = require(replicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out).Flamework
			local InventoryUtil = require(replicatedStorage.TS.inventory['inventory-util']).InventoryUtil
			local Client = require(replicatedStorage.TS.remotes).default.Client
			local OldGet, OldBreak = Client.Get

			bedwars = setmetatable({
				AbilityController = Flamework.resolveDependency('@easy-games/game-core:client/controllers/ability/ability-controller@AbilityController'),
				AnimationType = require(replicatedStorage.TS.animation['animation-type']).AnimationType,
				AnimationUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out['shared'].util['animation-util']).AnimationUtil,
				AppController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.controllers['app-controller']).AppController,
				BedBreakEffectMeta = require(replicatedStorage.TS.locker['bed-break-effect']['bed-break-effect-meta']).BedBreakEffectMeta,
				BedwarsKitMeta = require(replicatedStorage.TS.games.bedwars.kit['bedwars-kit-meta']).BedwarsKitMeta,
				BlockBreaker = Knit.Controllers.BlockBreakController.blockBreaker,
				BlockController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out).BlockEngine,
				BlockEngine = require(lplr.PlayerScripts.TS.lib['block-engine']['client-block-engine']).ClientBlockEngine,
				BlockPlacer = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.client.placement['block-placer']).BlockPlacer,
				BowConstantsTable = debug.getupvalue(Knit.Controllers.ProjectileController.enableBeam, 8),
				ClickHold = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.ui.lib.util['click-hold']).ClickHold,
				Client = Client,
				ClientConstructor = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts'].net.out.client),
				ClientDamageBlock = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.shared.remotes).BlockEngineRemotes.Client,
				CombatConstant = require(replicatedStorage.TS.combat['combat-constant']).CombatConstant,
				DamageIndicator = Knit.Controllers.DamageIndicatorController.spawnDamageIndicator,
				DefaultKillEffect = require(lplr.PlayerScripts.TS.controllers.game.locker['kill-effect'].effects['default-kill-effect']),
				EmoteType = require(replicatedStorage.TS.locker.emote['emote-type']).EmoteType,
				GameAnimationUtil = require(replicatedStorage.TS.animation['animation-util']).GameAnimationUtil,
				getIcon = function(item, showinv)
					local itemmeta = bedwars.ItemMeta[item.itemType]
					return itemmeta and showinv and itemmeta.image or ''
				end,
				getInventory = function(plr)
					local suc, res = pcall(function()
						return InventoryUtil.getInventory(plr)
					end)
					return suc and res or {
						items = {},
						armor = {}
					}
				end,
				HudAliveCount = require(lplr.PlayerScripts.TS.controllers.global['top-bar'].ui.game['hud-alive-player-counts']).HudAlivePlayerCounts,
				ItemMeta = debug.getupvalue(require(replicatedStorage.TS.item['item-meta']).getItemMeta, 1),
				KillEffectMeta = require(replicatedStorage.TS.locker['kill-effect']['kill-effect-meta']).KillEffectMeta,
				KillFeedController = Flamework.resolveDependency('client/controllers/game/kill-feed/kill-feed-controller@KillFeedController'),
				Knit = Knit,
				KnockbackUtil = require(replicatedStorage.TS.damage['knockback-util']).KnockbackUtil,
				MageKitUtil = require(replicatedStorage.TS.games.bedwars.kit.kits.mage['mage-kit-util']).MageKitUtil,
				NametagController = Knit.Controllers.NametagController,
				PartyController = Flamework.resolveDependency('@easy-games/lobby:client/controllers/party-controller@PartyController'),
				ProjectileMeta = require(replicatedStorage.TS.projectile['projectile-meta']).ProjectileMeta,
				QueryUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).GameQueryUtil,
				QueueCard = require(lplr.PlayerScripts.TS.controllers.global.queue.ui['queue-card']).QueueCard,
				QueueMeta = require(replicatedStorage.TS.game['queue-meta']).QueueMeta,
				Roact = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts']['roact'].src),
				RuntimeLib = require(replicatedStorage['rbxts_include'].RuntimeLib),
				SoundList = require(replicatedStorage.TS.sound['game-sound']).GameSound,
				SoundManager = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).SoundManager,
				Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore,
				TeamUpgradeMeta = debug.getupvalue(require(replicatedStorage.TS.games.bedwars['team-upgrade']['team-upgrade-meta']).getTeamUpgradeMetaForQueue, 6),
				UILayers = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).UILayers,
				VisualizerUtils = require(lplr.PlayerScripts.TS.lib.visualizer['visualizer-utils']).VisualizerUtils,
				WeldTable = require(replicatedStorage.TS.util['weld-util']).WeldUtil,
				WinEffectMeta = require(replicatedStorage.TS.locker['win-effect']['win-effect-meta']).WinEffectMeta,
				ZapNetworking = require(lplr.PlayerScripts.TS.lib.network)
			}, {
				__index = function(self, ind)
					rawset(self, ind, Knit.Controllers[ind])
					return rawget(self, ind)
				end
			})

			local remoteNames = {
				AfkStatus = debug.getproto(Knit.Controllers.AfkController.KnitStart, 1),
				AttackEntity = Knit.Controllers.SwordController.sendServerRequest,
				BeePickup = Knit.Controllers.BeeNetController.trigger,
				CannonAim = debug.getproto(Knit.Controllers.CannonController.startAiming, 5),
				CannonLaunch = Knit.Controllers.CannonHandController.launchSelf,
				ConsumeBattery = debug.getproto(Knit.Controllers.BatteryController.onKitLocalActivated, 1),
				ConsumeItem = debug.getproto(Knit.Controllers.ConsumeController.onEnable, 1),
				ConsumeSoul = Knit.Controllers.GrimReaperController.consumeSoul,
				ConsumeTreeOrb = debug.getproto(Knit.Controllers.EldertreeController.createTreeOrbInteraction, 1),
				DepositPinata = debug.getproto(debug.getproto(Knit.Controllers.PiggyBankController.KnitStart, 2), 5),
				DragonBreath = debug.getproto(Knit.Controllers.VoidDragonController.onKitLocalActivated, 5),
				DragonEndFly = debug.getproto(Knit.Controllers.VoidDragonController.flapWings, 1),
				DragonFly = Knit.Controllers.VoidDragonController.flapWings,
				DropItem = Knit.Controllers.ItemDropController.dropItemInHand,
				EquipItem = debug.getproto(require(replicatedStorage.TS.entity.entities['inventory-entity']).InventoryEntity.equipItem, 3),
				FireProjectile = debug.getupvalue(Knit.Controllers.ProjectileController.launchProjectileWithValues, 2),
				GroundHit = Knit.Controllers.FallDamageController.KnitStart,
				GuitarHeal = Knit.Controllers.GuitarController.performHeal,
				HannahKill = debug.getproto(Knit.Controllers.HannahController.registerExecuteInteractions, 1),
				HarvestCrop = debug.getproto(debug.getproto(Knit.Controllers.CropController.KnitStart, 4), 1),
				KaliyahPunch = debug.getproto(Knit.Controllers.DragonSlayerController.onKitLocalActivated, 1),
				MageSelect = debug.getproto(Knit.Controllers.MageController.registerTomeInteraction, 1),
				MinerDig = debug.getproto(Knit.Controllers.MinerController.setupMinerPrompts, 1),
				PickupItem = Knit.Controllers.ItemDropController.checkForPickup,
				PickupMetal = debug.getproto(Knit.Controllers.HiddenMetalController.onKitLocalActivated, 4),
				ReportPlayer = require(lplr.PlayerScripts.TS.controllers.global.report['report-controller']).default.reportPlayer,
				ResetCharacter = debug.getproto(Knit.Controllers.ResetController.createBindable, 1),
				SpawnRaven = debug.getproto(Knit.Controllers.RavenController.KnitStart, 1),
				SummonerClawAttack = Knit.Controllers.SummonerClawHandController.attack,
				WarlockTarget = debug.getproto(Knit.Controllers.WarlockStaffController.KnitStart, 2)
			}

			local function dumpRemote(tab)
				local ind
				for i, v in tab do
					if v == 'Client' then
						ind = i
						break
					end
				end
				return ind and tab[ind + 1] or ''
			end

			for i, v in remoteNames do
				local remote = dumpRemote(debug.getconstants(v))
				if remote == '' then
					notif('Lunar', 'Failed to grab remote ('..i..')', 10, 'alert')
				end
				remotes[i] = remote
			end

			OldBreak = bedwars.BlockController.isBlockBreakable

			Client.Get = function(self, remoteName)
				local call = OldGet(self, remoteName)

				if remoteName == remotes.AttackEntity then
					return {
						instance = call.instance,
						SendToServer = function(_, attackTable, ...)
							local suc, plr = pcall(function()
								return playersService:GetPlayerFromCharacter(attackTable.entityInstance)
							end)

							local selfpos = attackTable.validate.selfPosition.value
							local targetpos = attackTable.validate.targetPosition.value
							store.attackReach = ((selfpos - targetpos).Magnitude * 100) // 1 / 100
							store.attackReachUpdate = tick() + 1

							if Reach.Enabled or HitBoxes.Enabled then
								attackTable.validate.raycast = attackTable.validate.raycast or {}
								attackTable.validate.selfPosition.value += CFrame.lookAt(selfpos, targetpos).LookVector * math.max((selfpos - targetpos).Magnitude - 14.399, 0)
							end

							if suc and plr then
								if not select(2, whitelist:get(plr)) then return end
							end

							return call:SendToServer(attackTable, ...)
						end
					}
				elseif remoteName == 'StepOnSnapTrap' and TrapDisabler.Enabled then
					return {SendToServer = function() end}
				end

				return call
			end

			bedwars.BlockController.isBlockBreakable = function(self, breakTable, plr)
				local obj = bedwars.BlockController:getStore():getBlockAt(breakTable.blockPosition)

				if obj and obj.Name == 'bed' then
					for _, plr in playersService:GetPlayers() do
						if obj:GetAttribute('Team'..(plr:GetAttribute('Team') or 0)..'NoBreak') and not select(2, whitelist:get(plr)) then
							return false
						end
					end
				end

				return OldBreak(self, breakTable, plr)
			end

			local cache, blockhealthbar = {}, {blockHealth = -1, breakingBlockPosition = Vector3.zero}
			store.blockPlacer = bedwars.BlockPlacer.new(bedwars.BlockEngine, 'wool_white')

			local function getBlockHealth(block, blockpos)
				local blockdata = bedwars.BlockController:getStore():getBlockData(blockpos)
				return (blockdata and (blockdata:GetAttribute('1') or blockdata:GetAttribute('Health')) or block:GetAttribute('Health'))
			end

			local function getBlockHits(block, blockpos)
				if not block then return 0 end
				local breaktype = bedwars.ItemMeta[block.Name].block.breakType
				local tool = store.tools[breaktype]
				tool = tool and bedwars.ItemMeta[tool.itemType].breakBlock[breaktype] or 2
				return getBlockHealth(block, bedwars.BlockController:getBlockPosition(blockpos)) / tool
			end

	--[[
		Pathfinding using a luau version of dijkstra's algorithm
		Source: https://stackoverflow.com/questions/39355587/speeding-up-dijkstras-algorithm-to-solve-a-3d-maze
	]]
			local function calculatePath(target, blockpos)
				if cache[blockpos] then
					return unpack(cache[blockpos])
				end
				local visited, unvisited, distances, air, path = {}, {{0, blockpos}}, {[blockpos] = 0}, {}, {}

				for _ = 1, 10000 do
					local _, node = next(unvisited)
					if not node then break end
					table.remove(unvisited, 1)
					visited[node[2]] = true

					for _, side in sides do
						side = node[2] + side
						if visited[side] then continue end

						local block = getPlacedBlock(side)
						if not block or block:GetAttribute('NoBreak') or block == target then
							if not block then
								air[node[2]] = true
							end
							continue
						end

						local curdist = getBlockHits(block, side) + node[1]
						if curdist < (distances[side] or math.huge) then
							table.insert(unvisited, {curdist, side})
							distances[side] = curdist
							path[side] = node[2]
						end
					end
				end

				local pos, cost = nil, math.huge
				for node in air do
					if distances[node] < cost then
						pos, cost = node, distances[node]
					end
				end

				if pos then
					cache[blockpos] = {
						pos,
						cost,
						path
					}
					return pos, cost, path
				end
			end

			bedwars.placeBlock = function(pos, item)
				if getItem(item) then
					store.blockPlacer.blockType = item
					return store.blockPlacer:placeBlock(bedwars.BlockController:getBlockPosition(pos))
				end
			end

			bedwars.breakBlock = function(block, effects, anim, customHealthbar)
				if lplr:GetAttribute('DenyBlockBreak') or not entitylib.isAlive or InfiniteFly.Enabled then return end
				local handler = bedwars.BlockController:getHandlerRegistry():getHandler(block.Name)
				local cost, pos, target, path = math.huge

				for _, v in (handler and handler:getContainedPositions(block) or {block.Position / 3}) do
					local dpos, dcost, dpath = calculatePath(block, v * 3)
					if dpos and dcost < cost then
						cost, pos, target, path = dcost, dpos, v * 3, dpath
					end
				end

				if pos then
					if (entitylib.character.RootPart.Position - pos).Magnitude > 30 then return end
					local dblock, dpos = getPlacedBlock(pos)
					if not dblock then return end

					if (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > 0.4 then
						local breaktype = bedwars.ItemMeta[dblock.Name].block.breakType
						local tool = store.tools[breaktype]
						if tool then
							switchItem(tool.tool)
						end
					end

					if blockhealthbar.blockHealth == -1 or dpos ~= blockhealthbar.breakingBlockPosition then
						blockhealthbar.blockHealth = getBlockHealth(dblock, dpos)
						blockhealthbar.breakingBlockPosition = dpos
					end

					bedwars.ClientDamageBlock:Get('DamageBlock'):CallServerAsync({
						blockRef = {blockPosition = dpos},
						hitPosition = pos,
						hitNormal = Vector3.FromNormalId(Enum.NormalId.Top)
					}):andThen(function(result)
						if result then
							if result == 'cancelled' then
								store.damageBlockFail = tick() + 1
								return
							end

							if effects then
								local blockdmg = (blockhealthbar.blockHealth - (result == 'destroyed' and 0 or getBlockHealth(dblock, dpos)))
								customHealthbar = customHealthbar or bedwars.BlockBreaker.updateHealthbar
								customHealthbar(bedwars.BlockBreaker, {blockPosition = dpos}, blockhealthbar.blockHealth, dblock:GetAttribute('MaxHealth'), blockdmg, dblock)
								blockhealthbar.blockHealth = math.max(blockhealthbar.blockHealth - blockdmg, 0)

								if blockhealthbar.blockHealth <= 0 then
									bedwars.BlockBreaker.breakEffect:playBreak(dblock.Name, dpos, lplr)
									bedwars.BlockBreaker.healthbarMaid:DoCleaning()
									blockhealthbar.breakingBlockPosition = Vector3.zero
								else
									bedwars.BlockBreaker.breakEffect:playHit(dblock.Name, dpos, lplr)
								end
							end

							if anim then
								local animation = bedwars.AnimationUtil:playAnimation(lplr, bedwars.BlockController:getAnimationController():getAssetId(1))
								bedwars.ViewmodelController:playAnimation(15)
								task.wait(0.3)
								animation:Stop()
								animation:Destroy()
							end
						end
					end)

					if effects then
						return pos, path, target
					end
				end
			end

			for _, v in Enum.NormalId:GetEnumItems() do
				table.insert(sides, Vector3.FromNormalId(v) * 3)
			end

			local function updateStore(new, old)
				if new.Bedwars ~= old.Bedwars then
					store.equippedKit = new.Bedwars.kit ~= 'none' and new.Bedwars.kit or ''
				end

				if new.Game ~= old.Game then
					store.matchState = new.Game.matchState
					store.queueType = new.Game.queueType or 'bedwars_test'
				end

				if new.Inventory ~= old.Inventory then
					local newinv = (new.Inventory and new.Inventory.observedInventory or {inventory = {}})
					local oldinv = (old.Inventory and old.Inventory.observedInventory or {inventory = {}})
					store.inventory = newinv

					if newinv ~= oldinv then
						vapeEvents.InventoryChanged:Fire()
					end

					if newinv.inventory.items ~= oldinv.inventory.items then
						vapeEvents.InventoryAmountChanged:Fire()
						store.tools.sword = getSword()
						for _, v in {'stone', 'wood', 'wool'} do
							store.tools[v] = getTool(v)
						end
					end

					if newinv.inventory.hand ~= oldinv.inventory.hand then
						local currentHand, toolType = new.Inventory.observedInventory.inventory.hand, ''
						if currentHand then
							local handData = bedwars.ItemMeta[currentHand.itemType]
							toolType = handData.sword and 'sword' or handData.block and 'block' or currentHand.itemType:find('bow') and 'bow'
						end

						store.hand = {
							tool = currentHand and currentHand.tool,
							amount = currentHand and currentHand.amount or 0,
							toolType = toolType
						}
					end
				end
			end

			local storeChanged = bedwars.Store.changed:connect(updateStore)
			updateStore(bedwars.Store:getState(), {})

			for _, event in {'MatchEndEvent', 'EntityDeathEvent', 'BedwarsBedBreak', 'BalloonPopped', 'AngelProgress', 'GrapplingHookFunctions'} do
				if not vape.Connections then return end
				bedwars.Client:WaitFor(event):andThen(function(connection)
					vape:Clean(connection:Connect(function(...)
						vapeEvents[event]:Fire(...)
					end))
				end)
			end

			vape:Clean(bedwars.ZapNetworking.EntityDamageEventZap.On(function(...)
				vapeEvents.EntityDamageEvent:Fire({
					entityInstance = ...,
					damage = select(2, ...),
					damageType = select(3, ...),
					fromPosition = select(4, ...),
					fromEntity = select(5, ...),
					knockbackMultiplier = select(6, ...),
					knockbackId = select(7, ...),
					disableDamageHighlight = select(13, ...)
				})
			end))

			for _, event in {'PlaceBlockEvent', 'BreakBlockEvent'} do
				vape:Clean(bedwars.ZapNetworking[event..'Zap'].On(function(...)
					local data = {
						blockRef = {
							blockPosition = ...,
						},
						player = select(5, ...)
					}
					for i, v in cache do
						if ((data.blockRef.blockPosition * 3) - v[1]).Magnitude <= 30 then
							table.clear(v[3])
							table.clear(v)
							cache[i] = nil
						end
					end
					vapeEvents[event]:Fire(data)
				end))
			end

			store.blocks = collection('block', gui)
			store.shop = collection({'BedwarsItemShop', 'TeamUpgradeShopkeeper'}, gui, function(tab, obj)
				table.insert(tab, {
					Id = obj.Name,
					RootPart = obj,
					Shop = obj:HasTag('BedwarsItemShop'),
					Upgrades = obj:HasTag('TeamUpgradeShopkeeper')
				})
			end)
			store.enchant = collection({'enchant-table', 'broken-enchant-table'}, gui, nil, function(tab, obj, tag)
				if obj:HasTag('enchant-table') and tag == 'broken-enchant-table' then return end
				obj = table.find(tab, obj)
				if obj then
					table.remove(tab, obj)
				end
			end)

			local kills = sessioninfo:AddItem('Kills')
			local beds = sessioninfo:AddItem('Beds')
			local wins = sessioninfo:AddItem('Wins')
			local games = sessioninfo:AddItem('Games')

			local mapname = 'Unknown'
			sessioninfo:AddItem('Map', 0, function()
				return mapname
			end, false)

			task.delay(1, function()
				games:Increment()
			end)

			task.spawn(function()
				pcall(function()
					repeat task.wait() until store.matchState ~= 0 or vape.Loaded == nil
					if vape.Loaded == nil then return end
					mapname = workspace:WaitForChild('Map', 5):WaitForChild('Worlds', 5):GetChildren()[1].Name
					mapname = string.gsub(string.split(mapname, '_')[2] or mapname, '-', '') or 'Blank'
				end)
			end)

			vape:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
				if bedTable.player and bedTable.player.UserId == lplr.UserId then
					beds:Increment()
				end
			end))

			vape:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winTable)
				if (bedwars.Store:getState().Game.myTeam or {}).id == winTable.winningTeamId or lplr.Neutral then
					wins:Increment()
				end
			end))

			vape:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
				local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
				local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
				if not killed or not killer then return end

				if killed ~= lplr and killer == lplr then
					kills:Increment()
				end
			end))

			task.spawn(function()
				repeat
					if entitylib.isAlive then
						entitylib.character.AirTime = entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air and tick() or entitylib.character.AirTime
					end

					for _, v in entitylib.List do
						v.LandTick = math.abs(v.RootPart.Velocity.Y) < 0.1 and v.LandTick or tick()
						if (tick() - v.LandTick) > 0.2 and v.Jumps ~= 0 then
							v.Jumps = 0
							v.Jumping = false
						end
					end
					task.wait()
				until vape.Loaded == nil
			end)

			pcall(function()
				if getthreadidentity and setthreadidentity then
					local old = getthreadidentity()
					setthreadidentity(2)

					bedwars.Shop = require(replicatedStorage.TS.games.bedwars.shop['bedwars-shop']).BedwarsShop
					bedwars.ShopItems = debug.getupvalue(debug.getupvalue(bedwars.Shop.getShopItem, 1), 2)
					bedwars.Shop.getShopItem('iron_sword', lplr)

					setthreadidentity(old)
					store.shopLoaded = true
				else
					task.spawn(function()
						repeat
							task.wait(0.1)
						until vape.Loaded == nil or bedwars.AppController:isAppOpen('BedwarsItemShopApp')

						bedwars.Shop = require(replicatedStorage.TS.games.bedwars.shop['bedwars-shop']).BedwarsShop
						bedwars.ShopItems = debug.getupvalue(debug.getupvalue(bedwars.Shop.getShopItem, 1), 2)
						store.shopLoaded = true
					end)
				end
			end)

			vape:Clean(function()
				Client.Get = OldGet
				bedwars.BlockController.isBlockBreakable = OldBreak
				store.blockPlacer:disable()
				for _, v in vapeEvents do
					v:Destroy()
				end
				for _, v in cache do
					table.clear(v[3])
					table.clear(v)
				end
				table.clear(store.blockPlacer)
				table.clear(vapeEvents)
				table.clear(bedwars)
				table.clear(store)
				table.clear(cache)
				table.clear(sides)
				table.clear(remotes)
				storeChanged:disconnect()
				storeChanged = nil
			end)
		end)

		for _, v in {'AntiRagdoll', 'TriggerBot', 'SilentAim', 'AutoRejoin', 'Rejoin', 'Disabler', 'Timer', 'ServerHop', 'MouseTP', 'MurderMystery'} do
			vape:Remove(v)
		end
		run(function()
			local AimAssist
			local Targets
			local Sort
			local AimSpeed
			local Distance
			local AngleSlider
			local StrafeIncrease
			local KillauraTarget
			local ClickAim

			AimAssist = vape.Categories.Combat:CreateModule({
				Name = 'AimAssist',
				Function = function(callback)
					if callback then
						AimAssist:Clean(runService.Heartbeat:Connect(function(dt)
							if entitylib.isAlive and store.hand.toolType == 'sword' and ((not ClickAim.Enabled) or (tick() - bedwars.SwordController.lastSwing) < 0.4) then
								local ent = not KillauraTarget.Enabled and entitylib.EntityPosition({
									Range = Distance.Value,
									Part = 'RootPart',
									Wallcheck = Targets.Walls.Enabled,
									Players = Targets.Players.Enabled,
									NPCs = Targets.NPCs.Enabled,
									Sort = sortmethods[Sort.Value]
								}) or store.KillauraTarget

								if ent then
									local delta = (ent.RootPart.Position - entitylib.character.RootPart.Position)
									local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
									local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
									if angle >= (math.rad(AngleSlider.Value) / 2) then return end
									targetinfo.Targets[ent] = tick() + 1
									gameCamera.CFrame = gameCamera.CFrame:Lerp(CFrame.lookAt(gameCamera.CFrame.p, ent.RootPart.Position), (AimSpeed.Value + (StrafeIncrease.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) and 10 or 0)) * dt)
								end
							end
						end))
					end
				end,
				Tooltip = 'Smoothly aims to closest valid target with sword'
			})
			Targets = AimAssist:CreateTargets({
				Players = true,
				Walls = true
			})
			local methods = {'Damage', 'Distance'}
			for i in sortmethods do
				if not table.find(methods, i) then
					table.insert(methods, i)
				end
			end
			Sort = AimAssist:CreateDropdown({
				Name = 'Target Mode',
				List = methods
			})
			AimSpeed = AimAssist:CreateSlider({
				Name = 'Aim Speed',
				Min = 1,
				Max = 20,
				Default = 6
			})
			Distance = AimAssist:CreateSlider({
				Name = 'Distance',
				Min = 1,
				Max = 30,
				Default = 30,
				Suffx = function(val)
					return val == 1 and 'stud' or 'studs'
				end
			})
			AngleSlider = AimAssist:CreateSlider({
				Name = 'Max angle',
				Min = 1,
				Max = 360,
				Default = 70
			})
			ClickAim = AimAssist:CreateToggle({
				Name = 'Click Aim',
				Default = true
			})
			KillauraTarget = AimAssist:CreateToggle({
				Name = 'Use killaura target'
			})
			StrafeIncrease = AimAssist:CreateToggle({Name = 'Strafe increase'})
		end)

		run(function()
			local old

			AutoCharge = vape.Categories.Combat:CreateModule({
				Name = 'AutoCharge',
				Function = function(callback)
					debug.setconstant(bedwars.SwordController.attackEntity, 58, callback and 'damage' or 'multiHitCheckDurationSec')
					if callback then
						local chargeSwingTime = 0
						local canSwing

						old = bedwars.SwordController.sendServerRequest
						bedwars.SwordController.sendServerRequest = function(self, ...)
							if (os.clock() - chargeSwingTime) < AutoChargeTime.Value then return end
							self.lastSwingServerTimeDelta = 0.5
							chargeSwingTime = os.clock()
							canSwing = true

							local item = self:getHandItem()
							if item and item.tool then
								self:playSwordEffect(bedwars.ItemMeta[item.tool.Name], false)
							end

							return old(self, ...)
						end

						oldSwing = bedwars.SwordController.playSwordEffect
						bedwars.SwordController.playSwordEffect = function(...)
							if not canSwing then return end
							canSwing = false
							return oldSwing(...)
						end
					else
						if old then
							bedwars.SwordController.sendServerRequest = old
							old = nil
						end

						if oldSwing then
							bedwars.SwordController.playSwordEffect = oldSwing
							oldSwing = nil
						end
					end
				end,
				Tooltip = 'Allows you to get charged hits while spam clicking.'
			})
			AutoChargeTime = AutoCharge:CreateSlider({
				Name = 'Charge Time',
				Min = 0,
				Max = 0.5,
				Default = 0.4,
				Decimal = 100
			})
		end)

		run(function()
			local AutoClicker
			local CPS
			local BlockCPS = {}
			local Thread

			local function AutoClick()
				if Thread then
					task.cancel(Thread)
				end

				Thread = task.delay(1 / 7, function()
					repeat
						if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
							local blockPlacer = bedwars.BlockPlacementController.blockPlacer
							if store.hand.toolType == 'block' and blockPlacer then
								if (workspace:GetServerTimeNow() - bedwars.BlockCpsController.lastPlaceTimestamp) >= ((1 / 12) * 0.5) then
									local mouseinfo = blockPlacer.clientManager:getBlockSelector():getMouseInfo(0)
									if mouseinfo and mouseinfo.placementPosition == mouseinfo.placementPosition then
										task.spawn(blockPlacer.placeBlock, blockPlacer, mouseinfo.placementPosition)
									end
								end
							elseif store.hand.toolType == 'sword' then
								bedwars.SwordController:swingSwordAtMouse(0.39)
							end
						end

						task.wait(1 / (store.hand.toolType == 'block' and BlockCPS or CPS).GetRandomValue())
					until not AutoClicker.Enabled
				end)
			end

			AutoClicker = vape.Categories.Combat:CreateModule({
				Name = 'AutoClicker',
				Function = function(callback)
					if callback then
						AutoClicker:Clean(inputService.InputBegan:Connect(function(input)
							if input.UserInputType == Enum.UserInputType.MouseButton1 then
								AutoClick()
							end
						end))

						AutoClicker:Clean(inputService.InputEnded:Connect(function(input)
							if input.UserInputType == Enum.UserInputType.MouseButton1 and Thread then
								task.cancel(Thread)
								Thread = nil
							end
						end))

						if inputService.TouchEnabled then
							pcall(function()
								AutoClicker:Clean(lplr.PlayerGui.MobileUI['2'].MouseButton1Down:Connect(AutoClick))
								AutoClicker:Clean(lplr.PlayerGui.MobileUI['2'].MouseButton1Up:Connect(function()
									if Thread then
										task.cancel(Thread)
										Thread = nil
									end
								end))
							end)
						end
					else
						if Thread then
							task.cancel(Thread)
							Thread = nil
						end
					end
				end,
				Tooltip = 'Hold attack button to automatically click'
			})
			CPS = AutoClicker:CreateTwoSlider({
				Name = 'CPS',
				Min = 1,
				Max = 9,
				DefaultMin = 7,
				DefaultMax = 7
			})
			AutoClicker:CreateToggle({
				Name = 'Place Blocks',
				Default = true,
				Function = function(callback)
					if BlockCPS.Object then
						BlockCPS.Object.Visible = callback
					end
				end
			})
			BlockCPS = AutoClicker:CreateTwoSlider({
				Name = 'Block CPS',
				Min = 1,
				Max = 12,
				DefaultMin = 12,
				DefaultMax = 12,
				Darker = true
			})
		end)

		run(function()
			local old

			vape.Categories.Combat:CreateModule({
				Name = 'NoClickDelay',
				Function = function(callback)
					if callback then
						old = bedwars.SwordController.isClickingTooFast
						bedwars.SwordController.isClickingTooFast = function(self)
							self.lastSwing = os.clock()
							return false
						end
					else
						bedwars.SwordController.isClickingTooFast = old
					end
				end,
				Tooltip = 'Remove the CPS cap'
			})
		end)

		run(function()
			local Value

			Reach = vape.Categories.Combat:CreateModule({
				Name = 'Reach',
				Function = function(callback)
					bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = callback and Value.Value + 2 or 14.4
				end,
				Tooltip = 'Extends attack reach'
			})
			Value = Reach:CreateSlider({
				Name = 'Range',
				Min = 0,
				Max = 18,
				Default = 18,
				Function = function(val)
					if Reach.Enabled then
						bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = val + 2
					end
				end,
				Suffix = function(val)
					return val == 1 and 'stud' or 'studs'
				end
			})
		end)

		run(function()
			local Sprint
			local old

			Sprint = vape.Categories.Combat:CreateModule({
				Name = 'Sprint',
				Function = function(callback)
					if callback then
						if inputService.TouchEnabled then 
							pcall(function() 
								lplr.PlayerGui.MobileUI['4'].Visible = false 
							end) 
						end
						old = bedwars.SprintController.stopSprinting
						bedwars.SprintController.stopSprinting = function(...)
							local call = old(...)
							bedwars.SprintController:startSprinting()
							return call
						end
						Sprint:Clean(entitylib.Events.LocalAdded:Connect(function() 
							task.delay(0.1, function() 
								bedwars.SprintController:stopSprinting() 
							end) 
						end))
						bedwars.SprintController:stopSprinting()
					else
						if inputService.TouchEnabled then 
							pcall(function() 
								lplr.PlayerGui.MobileUI['4'].Visible = true 
							end) 
						end
						bedwars.SprintController.stopSprinting = old
						bedwars.SprintController:stopSprinting()
					end
				end,
				Tooltip = 'Sets your sprinting to true.'
			})
		end)

		run(function()
			local TriggerBot
			local CPS
			local rayParams = RaycastParams.new()

			TriggerBot = vape.Categories.Combat:CreateModule({
				Name = 'TriggerBot',
				Function = function(callback)
					if callback then
						repeat
							local doAttack
							if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
								if entitylib.isAlive and store.hand.toolType == 'sword' and bedwars.DaoController.chargingMaid == nil then
									local attackRange = bedwars.ItemMeta[store.hand.tool.Name].sword.attackRange
									rayParams.FilterDescendantsInstances = {lplr.Character}

									local unit = lplr:GetMouse().UnitRay
									local localPos = entitylib.character.RootPart.Position
									local rayRange = (attackRange or 14.4)
									local ray = bedwars.QueryUtil:raycast(unit.Origin, unit.Direction * 200, rayParams)
									if ray and (localPos - ray.Instance.Position).Magnitude <= rayRange then
										local limit = (attackRange)
										for _, ent in entitylib.List do
											doAttack = ent.Targetable and ray.Instance:IsDescendantOf(ent.Character) and (localPos - ent.RootPart.Position).Magnitude <= rayRange
											if doAttack then
												break
											end
										end
									end

									doAttack = doAttack or bedwars.SwordController:getTargetInRegion(attackRange or 3.8 * 3, 0)
									if doAttack then
										bedwars.SwordController:swingSwordAtMouse()
									end
								end
							end

							task.wait(doAttack and 1 / CPS.GetRandomValue() or 0.016)
						until not TriggerBot.Enabled
					end
				end,
				Tooltip = 'Automatically swings when hovering over a entity'
			})
			CPS = TriggerBot:CreateTwoSlider({
				Name = 'CPS',
				Min = 1,
				Max = 9,
				DefaultMin = 7,
				DefaultMax = 7
			})
		end)

		run(function()
			local Velocity
			local Horizontal
			local Vertical
			local Chance
			local TargetCheck
			local rand, old = Random.new()

			Velocity = vape.Categories.Combat:CreateModule({
				Name = 'Velocity',
				Function = function(callback)
					if callback then
						old = bedwars.KnockbackUtil.applyKnockback
						bedwars.KnockbackUtil.applyKnockback = function(root, mass, dir, knockback, ...)
							if rand:NextNumber(0, 100) > Chance.Value then return end
							local check = (not TargetCheck.Enabled) or entitylib.EntityPosition({
								Range = 50,
								Part = 'RootPart',
								Players = true
							})

							if check then
								knockback = knockback or {}
								if Horizontal.Value == 0 and Vertical.Value == 0 then return end
								knockback.horizontal = (knockback.horizontal or 1) * (Horizontal.Value / 100)
								knockback.vertical = (knockback.vertical or 1) * (Vertical.Value / 100)
							end

							return old(root, mass, dir, knockback, ...)
						end
					else
						bedwars.KnockbackUtil.applyKnockback = old
					end
				end,
				Tooltip = 'Reduces knockback taken'
			})
			Horizontal = Velocity:CreateSlider({
				Name = 'Horizontal',
				Min = 0,
				Max = 100,
				Default = 0,
				Suffix = '%'
			})
			Vertical = Velocity:CreateSlider({
				Name = 'Vertical',
				Min = 0,
				Max = 100,
				Default = 0,
				Suffix = '%'
			})
			Chance = Velocity:CreateSlider({
				Name = 'Chance',
				Min = 0,
				Max = 100,
				Default = 100,
				Suffix = '%'
			})
			TargetCheck = Velocity:CreateToggle({Name = 'Only when targeting'})
		end)

		local AntiFallDirection
		run(function()
			local AntiFall
			local Mode
			local Material
			local Color
			local rayCheck = RaycastParams.new()
			rayCheck.RespectCanCollide = true

			local function getLowGround()
				local mag = math.huge
				for _, pos in bedwars.BlockController:getStore():getAllBlockPositions() do
					pos = pos * 3
					if pos.Y < mag and not getPlacedBlock(pos + Vector3.new(0, 3, 0)) then
						mag = pos.Y
					end
				end
				return mag
			end

			AntiFall = vape.Categories.Blatant:CreateModule({
				Name = 'AntiFall',
				Function = function(callback)
					if callback then
						repeat task.wait() until store.matchState ~= 0 or (not AntiFall.Enabled)
						if not AntiFall.Enabled then return end

						local pos, debounce = getLowGround(), tick()
						if pos ~= math.huge then
							AntiFallPart = Instance.new('Part')
							AntiFallPart.Size = Vector3.new(10000, 1, 10000)
							AntiFallPart.Transparency = 1 - Color.Opacity
							AntiFallPart.Material = Enum.Material[Material.Value]
							AntiFallPart.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
							AntiFallPart.Position = Vector3.new(0, pos - 2, 0)
							AntiFallPart.CanCollide = Mode.Value == 'Collide'
							AntiFallPart.Anchored = true
							AntiFallPart.CanQuery = false
							AntiFallPart.Parent = workspace
							AntiFall:Clean(AntiFallPart)
							AntiFall:Clean(AntiFallPart.Touched:Connect(function(touched)
								if touched.Parent == lplr.Character and entitylib.isAlive and debounce < tick() then
									debounce = tick() + 0.1
									if Mode.Value == 'Normal' then
										local top = getNearGround()
										if top then
											local lastTeleport = lplr:GetAttribute('LastTeleported')
											local connection
											connection = runService.PreSimulation:Connect(function()
												if vape.Modules.Fly.Enabled or vape.Modules.InfiniteFly.Enabled or vape.Modules.LongJump.Enabled then
													connection:Disconnect()
													AntiFallDirection = nil
													return
												end

												if entitylib.isAlive and lplr:GetAttribute('LastTeleported') == lastTeleport then
													local delta = ((top - entitylib.character.RootPart.Position) * Vector3.new(1, 0, 1))
													local root = entitylib.character.RootPart
													AntiFallDirection = delta.Unit == delta.Unit and delta.Unit or Vector3.zero
													root.Velocity *= Vector3.new(1, 0, 1)
													rayCheck.FilterDescendantsInstances = {gameCamera, lplr.Character}
													rayCheck.CollisionGroup = root.CollisionGroup

													local ray = workspace:Raycast(root.Position, AntiFallDirection, rayCheck)
													if ray then
														for _ = 1, 10 do
															local dpos = roundPos(ray.Position + ray.Normal * 1.5) + Vector3.new(0, 3, 0)
															if not getPlacedBlock(dpos) then
																top = Vector3.new(top.X, pos.Y, top.Z)
																break
															end
														end
													end

													root.CFrame += Vector3.new(0, top.Y - root.Position.Y, 0)
													if not frictionTable.Speed then
														root.AssemblyLinearVelocity = (AntiFallDirection * getSpeed()) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
													end

													if delta.Magnitude < 1 then
														connection:Disconnect()
														AntiFallDirection = nil
													end
												else
													connection:Disconnect()
													AntiFallDirection = nil
												end
											end)
											AntiFall:Clean(connection)
										end
									elseif Mode.Value == 'Velocity' then
										entitylib.character.RootPart.Velocity = Vector3.new(entitylib.character.RootPart.Velocity.X, 100, entitylib.character.RootPart.Velocity.Z)
									end
								end
							end))
						end
					else
						AntiFallDirection = nil
					end
				end,
				Tooltip = 'Help\'s you with your Parkinson\'s\nPrevents you from falling into the void.'
			})
			Mode = AntiFall:CreateDropdown({
				Name = 'Move Mode',
				List = {'Normal', 'Collide', 'Velocity'},
				Function = function(val)
					if AntiFallPart then
						AntiFallPart.CanCollide = val == 'Collide'
					end
				end,
				Tooltip = 'Normal - Smoothly moves you towards the nearest safe point\nVelocity - Launches you upward after touching\nCollide - Allows you to walk on the part'
			})
			local materials = {'ForceField'}
			for _, v in Enum.Material:GetEnumItems() do
				if v.Name ~= 'ForceField' then
					table.insert(materials, v.Name)
				end
			end
			Material = AntiFall:CreateDropdown({
				Name = 'Material',
				List = materials,
				Function = function(val)
					if AntiFallPart then
						AntiFallPart.Material = Enum.Material[val]
					end
				end
			})
			Color = AntiFall:CreateColorSlider({
				Name = 'Color',
				DefaultOpacity = 0.5,
				Function = function(h, s, v, o)
					if AntiFallPart then
						AntiFallPart.Color = Color3.fromHSV(h, s, v)
						AntiFallPart.Transparency = 1 - o
					end
				end
			})
		end)

		run(function()
			local FastBreak
			local Time

			FastBreak = vape.Categories.Blatant:CreateModule({
				Name = 'FastBreak',
				Function = function(callback)
					if callback then
						repeat
							bedwars.BlockBreakController.blockBreaker:setCooldown(Time.Value)
							task.wait(0.1)
						until not FastBreak.Enabled
					else
						bedwars.BlockBreakController.blockBreaker:setCooldown(0.3)
					end
				end,
				Tooltip = 'Decreases block hit cooldown'
			})
			Time = FastBreak:CreateSlider({
				Name = 'Break speed',
				Min = 0,
				Max = 0.3,
				Default = 0.25,
				Decimal = 100,
				Suffix = 'seconds'
			})
		end)

		local Fly
		local LongJump
		run(function()
			local Value
			local VerticalValue
			local WallCheck
			local PopBalloons
			local TP
			local rayCheck = RaycastParams.new()
			rayCheck.RespectCanCollide = true
			local up, down, old = 0, 0

			Fly = vape.Categories.Blatant:CreateModule({
				Name = 'Fly',
				Function = function(callback)
					frictionTable.Fly = callback or nil
					updateVelocity()
					if callback then
						up, down, old = 0, 0, bedwars.BalloonController.deflateBalloon
						bedwars.BalloonController.deflateBalloon = function() end
						local tpTick, tpToggle, oldy = tick(), true

						if lplr.Character and (lplr.Character:GetAttribute('InflatedBalloons') or 0) == 0 and getItem('balloon') then
							bedwars.BalloonController:inflateBalloon()
						end
						Fly:Clean(vapeEvents.AttributeChanged.Event:Connect(function(changed)
							if changed == 'InflatedBalloons' and (lplr.Character:GetAttribute('InflatedBalloons') or 0) == 0 and getItem('balloon') then
								bedwars.BalloonController:inflateBalloon()
							end
						end))
						Fly:Clean(runService.PreSimulation:Connect(function(dt)
							if entitylib.isAlive and not InfiniteFly.Enabled and isnetworkowner(entitylib.character.RootPart) then
								local flyAllowed = (lplr.Character:GetAttribute('InflatedBalloons') and lplr.Character:GetAttribute('InflatedBalloons') > 0) or store.matchState == 2
								local mass = (1.5 + (flyAllowed and 6 or 0) * (tick() % 0.4 < 0.2 and -1 or 1)) + ((up + down) * VerticalValue.Value)
								local root, moveDirection = entitylib.character.RootPart, entitylib.character.Humanoid.MoveDirection
								local velo = getSpeed()
								local destination = (moveDirection * math.max(Value.Value - velo, 0) * dt)
								rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiFallPart}
								rayCheck.CollisionGroup = root.CollisionGroup

								if WallCheck.Enabled then
									local ray = workspace:Raycast(root.Position, destination, rayCheck)
									if ray then
										destination = ((ray.Position + ray.Normal) - root.Position)
									end
								end

								if not flyAllowed then
									if tpToggle then
										local airleft = (tick() - entitylib.character.AirTime)
										if airleft > 2 then
											if not oldy then
												local ray = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), rayCheck)
												if ray and TP.Enabled then
													tpToggle = false
													oldy = root.Position.Y
													tpTick = tick() + 0.11
													root.CFrame = CFrame.lookAlong(Vector3.new(root.Position.X, ray.Position.Y + entitylib.character.HipHeight, root.Position.Z), root.CFrame.LookVector)
												end
											end
										end
									else
										if oldy then
											if tpTick < tick() then
												local newpos = Vector3.new(root.Position.X, oldy, root.Position.Z)
												root.CFrame = CFrame.lookAlong(newpos, root.CFrame.LookVector)
												tpToggle = true
												oldy = nil
											else
												mass = 0
											end
										end
									end
								end

								root.CFrame += destination
								root.AssemblyLinearVelocity = (moveDirection * velo) + Vector3.new(0, mass, 0)
							end
						end))
						Fly:Clean(inputService.InputBegan:Connect(function(input)
							if not inputService:GetFocusedTextBox() then
								if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
									up = 1
								elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
									down = -1
								end
							end
						end))
						Fly:Clean(inputService.InputEnded:Connect(function(input)
							if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
								up = 0
							elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
								down = 0
							end
						end))
						if inputService.TouchEnabled then
							pcall(function()
								local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
								Fly:Clean(jumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(function()
									up = jumpButton.ImageRectOffset.X == 146 and 1 or 0
								end))
							end)
						end
					else
						bedwars.BalloonController.deflateBalloon = old
						if PopBalloons.Enabled and entitylib.isAlive and (lplr.Character:GetAttribute('InflatedBalloons') or 0) > 0 then
							for _ = 1, 3 do
								bedwars.BalloonController:deflateBalloon()
							end
						end
					end
				end,
				ExtraText = function()
					return 'Heatseeker'
				end,
				Tooltip = 'Makes you go zoom.'
			})
			Value = Fly:CreateSlider({
				Name = 'Speed',
				Min = 1,
				Max = 23,
				Default = 23,
				Suffix = function(val)
					return val == 1 and 'stud' or 'studs'
				end
			})
			VerticalValue = Fly:CreateSlider({
				Name = 'Vertical Speed',
				Min = 1,
				Max = 150,
				Default = 50,
				Suffix = function(val)
					return val == 1 and 'stud' or 'studs'
				end
			})
			WallCheck = Fly:CreateToggle({
				Name = 'Wall Check',
				Default = true
			})
			PopBalloons = Fly:CreateToggle({
				Name = 'Pop Balloons',
				Default = true
			})
			TP = Fly:CreateToggle({
				Name = 'TP Down',
				Default = true
			})
		end)

		run(function()
			local Mode
			local Expand
			local objects, set = {}

			local function createHitbox(ent)
				if ent.Targetable and ent.Player then
					local hitbox = Instance.new('Part')
					hitbox.Size = Vector3.new(3, 6, 3) + Vector3.one * (Expand.Value / 5)
					hitbox.Position = ent.RootPart.Position
					hitbox.CanCollide = false
					hitbox.Massless = true
					hitbox.Transparency = 1
					hitbox.Parent = ent.Character
					local weld = Instance.new('Motor6D')
					weld.Part0 = hitbox
					weld.Part1 = ent.RootPart
					weld.Parent = hitbox
					objects[ent] = hitbox
				end
			end

			HitBoxes = vape.Categories.Blatant:CreateModule({
				Name = 'HitBoxes',
				Function = function(callback)
					if callback then
						if Mode.Value == 'Sword' then
							debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (Expand.Value / 3))
							set = true
						else
							HitBoxes:Clean(entitylib.Events.EntityAdded:Connect(createHitbox))
							HitBoxes:Clean(entitylib.Events.EntityRemoving:Connect(function(ent)
								if objects[ent] then
									objects[ent]:Destroy()
									objects[ent] = nil
								end
							end))
							for _, ent in entitylib.List do
								createHitbox(ent)
							end
						end
					else
						if set then
							debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, 3.8)
							set = nil
						end
						for _, part in objects do
							part:Destroy()
						end
						table.clear(objects)
					end
				end,
				Tooltip = 'Expands attack hitbox'
			})
			Mode = HitBoxes:CreateDropdown({
				Name = 'Mode',
				List = {'Sword', 'Player'},
				Function = function()
					if HitBoxes.Enabled then
						HitBoxes:Toggle()
						HitBoxes:Toggle()
					end
				end,
				Tooltip = 'Sword - Increases the range around you to hit entities\nPlayer - Increases the players hitbox'
			})
			Expand = HitBoxes:CreateSlider({
				Name = 'Expand amount',
				Min = 0,
				Max = 14.4,
				Default = 14.4,
				Decimal = 10,
				Function = function(val)
					if HitBoxes.Enabled then
						if Mode.Value == 'Sword' then
							debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (val / 3))
						else
							for _, part in objects do
								part.Size = Vector3.new(3, 6, 3) + Vector3.one * (val / 5)
							end
						end
					end
				end,
				Suffix = function(val)
					return val == 1 and 'stud' or 'studs'
				end
			})
		end)

		run(function()
			vape.Categories.Blatant:CreateModule({
				Name = 'KeepSprint',
				Function = function(callback)
					debug.setconstant(bedwars.SprintController.startSprinting, 5, callback and 'blockSprinting' or 'blockSprint')
					bedwars.SprintController:stopSprinting()
				end,
				Tooltip = 'Lets you sprint with a speed potion.'
			})
		end)

		local Attacking
		run(function()
			local Killaura
			local Targets
			local Sort
			local SwingRange
			local AttackRange
			local ChargeTime
			local UpdateRate
			local AngleSlider
			local MaxTargets
			local Mouse
			local Swing
			local GUI
			local BoxSwingColor
			local BoxAttackColor
			local ParticleTexture
			local ParticleColor1
			local ParticleColor2
			local ParticleSize
			local Face
			local Animation
			local AnimationMode
			local AnimationSpeed
			local AnimationTween
			local Limit
			local LegitAura = {}
			local Particles, Boxes = {}, {}
			local anims, AnimDelay, AnimTween, armC0 = vape.Libraries.auraanims, tick()
			local AttackRemote = {FireServer = function() end}
			task.spawn(function()
				AttackRemote = bedwars.Client:Get(remotes.AttackEntity).instance
			end)

			local function getAttackData()
				if Mouse.Enabled then
					if not inputService:IsMouseButtonPressed(0) then return false end
				end

				if GUI.Enabled then
					if bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then return false end
				end

				local sword = Limit.Enabled and store.hand or store.tools.sword
				if not sword or not sword.tool then return false end

				local meta = bedwars.ItemMeta[sword.tool.Name]
				if Limit.Enabled then
					if store.hand.toolType ~= 'sword' or bedwars.DaoController.chargingMaid then return false end
				end

				if LegitAura.Enabled then
					if (tick() - bedwars.SwordController.lastSwing) > 0.2 then return false end
				end

				return sword, meta
			end

			Killaura = vape.Categories.Blatant:CreateModule({
				Name = 'Killaura',
				Function = function(callback)
					if callback then
						if inputService.TouchEnabled then
							pcall(function()
								lplr.PlayerGui.MobileUI['2'].Visible = Limit.Enabled
							end)
						end

						if Animation.Enabled and not (identifyexecutor and table.find({'Argon', 'Delta'}, ({identifyexecutor()})[1])) then
							local fake = {
								Controllers = {
									ViewmodelController = {
										isVisible = function()
											return not Attacking
										end,
										playAnimation = function(...)
											if not Attacking then
												bedwars.ViewmodelController:playAnimation(select(2, ...))
											end
										end
									}
								}
							}
							debug.setupvalue(oldSwing or bedwars.SwordController.playSwordEffect, 6, fake)
							debug.setupvalue(bedwars.ScytheController.playLocalAnimation, 3, fake)

							task.spawn(function()
								local started = false
								repeat
									if Attacking then
										if not armC0 then
											armC0 = gameCamera.Viewmodel.RightHand.RightWrist.C0
										end
										local first = not started
										started = true

										if AnimationMode.Value == 'Random' then
											anims.Random = {{CFrame = CFrame.Angles(math.rad(math.random(1, 360)), math.rad(math.random(1, 360)), math.rad(math.random(1, 360))), Time = 0.12}}
										end

										for _, v in anims[AnimationMode.Value] do
											AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(first and (AnimationTween.Enabled and 0.001 or 0.1) or v.Time / AnimationSpeed.Value, Enum.EasingStyle.Linear), {
												C0 = armC0 * v.CFrame
											})
											AnimTween:Play()
											AnimTween.Completed:Wait()
											first = false
											if (not Killaura.Enabled) or (not Attacking) then break end
										end
									elseif started then
										started = false
										AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
											C0 = armC0
										})
										AnimTween:Play()
									end

									if not started then
										task.wait(1 / UpdateRate.Value)
									end
								until (not Killaura.Enabled) or (not Animation.Enabled)
							end)
						end

						local swingCooldown = 0
						repeat
							local attacked, sword, meta = {}, getAttackData()
							Attacking = false
							store.KillauraTarget = nil
							if sword then
								local plrs = entitylib.AllPosition({
									Range = SwingRange.Value,
									Wallcheck = Targets.Walls.Enabled or nil,
									Part = 'RootPart',
									Players = Targets.Players.Enabled,
									NPCs = Targets.NPCs.Enabled,
									Limit = MaxTargets.Value,
									Sort = sortmethods[Sort.Value]
								})

								if #plrs > 0 then
									switchItem(sword.tool, 0)
									local selfpos = entitylib.character.RootPart.Position
									local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)

									for _, v in plrs do
										local delta = (v.RootPart.Position - selfpos)
										local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
										if angle > (math.rad(AngleSlider.Value) / 2) then continue end

										table.insert(attacked, {
											Entity = v,
											Check = delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor
										})
										targetinfo.Targets[v] = tick() + 1

										if not Attacking then
											Attacking = true
											store.KillauraTarget = v
											if not Swing.Enabled and AnimDelay < tick() and not LegitAura.Enabled then
												AnimDelay = tick() + (meta.sword.respectAttackSpeedForEffects and meta.sword.attackSpeed or math.max(ChargeTime.Value, 0.11))
												bedwars.SwordController:playSwordEffect(meta, false)
												if meta.displayName:find(' Scythe') then
													bedwars.ScytheController:playLocalAnimation()
												end

												if vape.ThreadFix then
													setthreadidentity(8)
												end
											end
										end

										if delta.Magnitude > AttackRange.Value then continue end
										if delta.Magnitude < 14.4 and (tick() - swingCooldown) < math.max(ChargeTime.Value, 0.02) then continue end

										local actualRoot = v.Character.PrimaryPart
										if actualRoot then
											local dir = CFrame.lookAt(selfpos, actualRoot.Position).LookVector
											local pos = selfpos + dir * math.max(delta.Magnitude - 14.399, 0)
											swingCooldown = tick()
											bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
											store.attackReach = (delta.Magnitude * 100) // 1 / 100
											store.attackReachUpdate = tick() + 1

											if delta.Magnitude < 14.4 and ChargeTime.Value > 0.11 then
												AnimDelay = tick()
											end

											AttackRemote:FireServer({
												weapon = sword.tool,
												chargedAttack = {chargeRatio = 0},
												lastSwingServerTimeDelta = 0.5,
												entityInstance = v.Character,
												validate = {
													raycast = {
														cameraPosition = {value = pos},
														cursorDirection = {value = dir}
													},
													targetPosition = {value = actualRoot.Position},
													selfPosition = {value = pos}
												}
											})
										end
									end
								end
							end

							for i, v in Boxes do
								v.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
								if v.Adornee then
									v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
									v.Transparency = 1 - attacked[i].Check.Opacity
								end
							end

							for i, v in Particles do
								v.Position = attacked[i] and attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
								v.Parent = attacked[i] and gameCamera or nil
							end

							if Face.Enabled and attacked[1] then
								local vec = attacked[1].Entity.RootPart.Position * Vector3.new(1, 0, 1)
								entitylib.character.RootPart.CFrame = CFrame.lookAt(entitylib.character.RootPart.Position, Vector3.new(vec.X, entitylib.character.RootPart.Position.Y + 0.001, vec.Z))
							end

							--#attacked > 0 and #attacked * 0.02 or
							task.wait(1 / UpdateRate.Value)
						until not Killaura.Enabled
					else
						store.KillauraTarget = nil
						for _, v in Boxes do
							v.Adornee = nil
						end
						for _, v in Particles do
							v.Parent = nil
						end
						if inputService.TouchEnabled then
							pcall(function()
								lplr.PlayerGui.MobileUI['2'].Visible = true
							end)
						end
						debug.setupvalue(oldSwing or bedwars.SwordController.playSwordEffect, 6, bedwars.Knit)
						debug.setupvalue(bedwars.ScytheController.playLocalAnimation, 3, bedwars.Knit)
						Attacking = false
						if armC0 then
							AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
								C0 = armC0
							})
							AnimTween:Play()
						end
					end
				end,
				Tooltip = 'Attack players around you\nwithout aiming at them.'
			})
			Targets = Killaura:CreateTargets({
				Players = true,
				NPCs = true
			})
			local methods = {'Damage', 'Distance'}
			for i in sortmethods do
				if not table.find(methods, i) then
					table.insert(methods, i)
				end
			end
			SwingRange = Killaura:CreateSlider({
				Name = 'Swing range',
				Min = 1,
				Max = 18,
				Default = 18,
				Suffix = function(val)
					return val == 1 and 'stud' or 'studs'
				end
			})
			AttackRange = Killaura:CreateSlider({
				Name = 'Attack range',
				Min = 1,
				Max = 18,
				Default = 18,
				Suffix = function(val)
					return val == 1 and 'stud' or 'studs'
				end
			})
			ChargeTime = Killaura:CreateSlider({
				Name = 'Swing time',
				Min = 0,
				Max = 0.5,
				Default = 0.42,
				Decimal = 100
			})
			AngleSlider = Killaura:CreateSlider({
				Name = 'Max angle',
				Min = 1,
				Max = 360,
				Default = 360
			})
			UpdateRate = Killaura:CreateSlider({
				Name = 'Update rate',
				Min = 1,
				Max = 120,
				Default = 60,
				Suffix = 'hz'
			})
			MaxTargets = Killaura:CreateSlider({
				Name = 'Max targets',
				Min = 1,
				Max = 5,
				Default = 5
			})
			Sort = Killaura:CreateDropdown({
				Name = 'Target Mode',
				List = methods
			})
			Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
			Swing = Killaura:CreateToggle({Name = 'No Swing'})
			GUI = Killaura:CreateToggle({Name = 'GUI check'})
			Killaura:CreateToggle({
				Name = 'Show target',
				Function = function(callback)
					BoxSwingColor.Object.Visible = callback
					BoxAttackColor.Object.Visible = callback
					if callback then
						for i = 1, 10 do
							local box = Instance.new('BoxHandleAdornment')
							box.Adornee = nil
							box.AlwaysOnTop = true
							box.Size = Vector3.new(3, 5, 3)
							box.CFrame = CFrame.new(0, -0.5, 0)
							box.ZIndex = 0
							box.Parent = vape.gui
							Boxes[i] = box
						end
					else
						for _, v in Boxes do
							v:Destroy()
						end
						table.clear(Boxes)
					end
				end
			})
			BoxSwingColor = Killaura:CreateColorSlider({
				Name = 'Target Color',
				Darker = true,
				DefaultHue = 0.6,
				DefaultOpacity = 0.5,
				Visible = false
			})
			BoxAttackColor = Killaura:CreateColorSlider({
				Name = 'Attack Color',
				Darker = true,
				DefaultOpacity = 0.5,
				Visible = false
			})
			Killaura:CreateToggle({
				Name = 'Target particles',
				Function = function(callback)
					ParticleTexture.Object.Visible = callback
					ParticleColor1.Object.Visible = callback
					ParticleColor2.Object.Visible = callback
					ParticleSize.Object.Visible = callback
					if callback then
						for i = 1, 10 do
							local part = Instance.new('Part')
							part.Size = Vector3.new(2, 4, 2)
							part.Anchored = true
							part.CanCollide = false
							part.Transparency = 1
							part.CanQuery = false
							part.Parent = Killaura.Enabled and gameCamera or nil
							local particles = Instance.new('ParticleEmitter')
							particles.Brightness = 1.5
							particles.Size = NumberSequence.new(ParticleSize.Value)
							particles.Shape = Enum.ParticleEmitterShape.Sphere
							particles.Texture = ParticleTexture.Value
							particles.Transparency = NumberSequence.new(0)
							particles.Lifetime = NumberRange.new(0.4)
							particles.Speed = NumberRange.new(16)
							particles.Rate = 128
							particles.Drag = 16
							particles.ShapePartial = 1
							particles.Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
								ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
							})
							particles.Parent = part
							Particles[i] = part
						end
					else
						for _, v in Particles do
							v:Destroy()
						end
						table.clear(Particles)
					end
				end
			})
			ParticleTexture = Killaura:CreateTextBox({
				Name = 'Texture',
				Default = 'rbxassetid://14736249347',
				Function = function()
					for _, v in Particles do
						v.ParticleEmitter.Texture = ParticleTexture.Value
					end
				end,
				Darker = true,
				Visible = false
			})
			ParticleColor1 = Killaura:CreateColorSlider({
				Name = 'Color Begin',
				Function = function(hue, sat, val)
					for _, v in Particles do
						v.ParticleEmitter.Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
							ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
						})
					end
				end,
				Darker = true,
				Visible = false
			})
			ParticleColor2 = Killaura:CreateColorSlider({
				Name = 'Color End',
				Function = function(hue, sat, val)
					for _, v in Particles do
						v.ParticleEmitter.Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
							ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
						})
					end
				end,
				Darker = true,
				Visible = false
			})
			ParticleSize = Killaura:CreateSlider({
				Name = 'Size',
				Min = 0,
				Max = 1,
				Default = 0.2,
				Decimal = 100,
				Function = function(val)
					for _, v in Particles do
						v.ParticleEmitter.Size = NumberSequence.new(val)
					end
				end,
				Darker = true,
				Visible = false
			})
			Face = Killaura:CreateToggle({Name = 'Face target'})
			Animation = Killaura:CreateToggle({
				Name = 'Custom Animation',
				Function = function(callback)
					AnimationMode.Object.Visible = callback
					AnimationTween.Object.Visible = callback
					AnimationSpeed.Object.Visible = callback
					if Killaura.Enabled then
						Killaura:Toggle()
						Killaura:Toggle()
					end
				end
			})
			local animnames = {}
			for i in anims do
				table.insert(animnames, i)
			end
			AnimationMode = Killaura:CreateDropdown({
				Name = 'Animation Mode',
				List = animnames,
				Darker = true,
				Visible = false
			})
			AnimationSpeed = Killaura:CreateSlider({
				Name = 'Animation Speed',
				Min = 0,
				Max = 2,
				Default = 1,
				Decimal = 10,
				Darker = true,
				Visible = false
			})
			AnimationTween = Killaura:CreateToggle({
				Name = 'No Tween',
				Darker = true,
				Visible = false
			})
			Limit = Killaura:CreateToggle({
				Name = 'Limit to items',
				Function = function(callback)
					if inputService.TouchEnabled and Killaura.Enabled then
						pcall(function()
							lplr.PlayerGui.MobileUI['2'].Visible = callback
						end)
					end
				end,
				Tooltip = 'Only attacks when the sword is held'
			})
	--[[LegitAura = Killaura:CreateToggle({
		Name = 'Swing only',
		Tooltip = 'Only attacks while swinging manually'
	})]]
		end)

		run(function()
			local Value
			local CameraDir
			local start
			local JumpTick, JumpSpeed, Direction = tick(), 0
			local projectileRemote = {InvokeServer = function() end}
			task.spawn(function()
				projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
			end)

			local function launchProjectile(item, pos, proj, speed, dir)
				if not pos then return end

				pos = pos - dir * 0.1
				local shootPosition = (CFrame.lookAlong(pos, Vector3.new(0, -speed, 0)) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ)))
				switchItem(item.tool, 0)
				task.wait(0.1)
				bedwars.ProjectileController:createLocalProjectile(bedwars.ProjectileMeta[proj], proj, proj, shootPosition.Position, '', shootPosition.LookVector * speed, {drawDurationSeconds = 1})
				if projectileRemote:InvokeServer(item.tool, proj, proj, shootPosition.Position, pos, shootPosition.LookVector * speed, httpService:GenerateGUID(true), {drawDurationSeconds = 1}, workspace:GetServerTimeNow() - 0.045) then
					local shoot = bedwars.ItemMeta[item.itemType].projectileSource.launchSound
					shoot = shoot and shoot[math.random(1, #shoot)] or nil
					if shoot then
						bedwars.SoundManager:playSound(shoot)
					end
				end
			end

			local LongJumpMethods = {
				cannon = function(_, pos, dir)
					pos = pos - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
					local rounded = Vector3.new(math.round(pos.X / 3) * 3, math.round(pos.Y / 3) * 3, math.round(pos.Z / 3) * 3)
					bedwars.placeBlock(rounded, 'cannon', false)

					task.delay(0, function()
						local block, blockpos = getPlacedBlock(rounded)
						if block and block.Name == 'cannon' and (entitylib.character.RootPart.Position - block.Position).Magnitude < 20 then
							local breaktype = bedwars.ItemMeta[block.Name].block.breakType
							local tool = store.tools[breaktype]
							if tool then
								switchItem(tool.tool)
							end

							bedwars.Client:Get(remotes.CannonAim):SendToServer({
								cannonBlockPos = blockpos,
								lookVector = dir
							})

							local broken = 0.1
							if bedwars.BlockController:calculateBlockDamage(lplr, {blockPosition = blockpos}) < block:GetAttribute('Health') then
								broken = 0.4
								bedwars.breakBlock(block, true, true)
							end

							task.delay(broken, function()
								for _ = 1, 3 do
									local call = bedwars.Client:Get(remotes.CannonLaunch):CallServer({cannonBlockPos = blockpos})
									if call then
										bedwars.breakBlock(block, true, true)
										JumpSpeed = 5.25 * Value.Value
										JumpTick = tick() + 2.3
										Direction = Vector3.new(dir.X, 0, dir.Z).Unit
										break
									end
									task.wait(0.1)
								end
							end)
						end
					end)
				end,
				cat = function(_, _, dir)
					LongJump:Clean(vapeEvents.CatPounce.Event:Connect(function()
						JumpSpeed = 4 * Value.Value
						JumpTick = tick() + 2.5
						Direction = Vector3.new(dir.X, 0, dir.Z).Unit
						entitylib.character.RootPart.Velocity = Vector3.zero
					end))

					if not bedwars.AbilityController:canUseAbility('CAT_POUNCE') then
						repeat task.wait() until bedwars.AbilityController:canUseAbility('CAT_POUNCE') or not LongJump.Enabled
					end

					if bedwars.AbilityController:canUseAbility('CAT_POUNCE') and LongJump.Enabled then
						bedwars.AbilityController:useAbility('CAT_POUNCE')
					end
				end,
				fireball = function(item, pos, dir)
					launchProjectile(item, pos, 'fireball', 60, dir)
				end,
				grappling_hook = function(item, pos, dir)
					launchProjectile(item, pos, 'grappling_hook_projectile', 140, dir)
				end,
				jade_hammer = function(item, _, dir)
					if not bedwars.AbilityController:canUseAbility(item.itemType..'_jump') then
						repeat task.wait() until bedwars.AbilityController:canUseAbility(item.itemType..'_jump') or not LongJump.Enabled
					end

					if bedwars.AbilityController:canUseAbility(item.itemType..'_jump') and LongJump.Enabled then
						bedwars.AbilityController:useAbility(item.itemType..'_jump')
						JumpSpeed = 1.4 * Value.Value
						JumpTick = tick() + 2.5
						Direction = Vector3.new(dir.X, 0, dir.Z).Unit
					end
				end,
				tnt = function(item, pos, dir)
					pos = pos - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
					local rounded = Vector3.new(math.round(pos.X / 3) * 3, math.round(pos.Y / 3) * 3, math.round(pos.Z / 3) * 3)
					start = Vector3.new(rounded.X, start.Y, rounded.Z) + (dir * (item.itemType == 'pirate_gunpowder_barrel' and 2.6 or 0.2))
					bedwars.placeBlock(rounded, item.itemType, false)
				end,
				wood_dao = function(item, pos, dir)
					if (lplr.Character:GetAttribute('CanDashNext') or 0) > workspace:GetServerTimeNow() or not bedwars.AbilityController:canUseAbility('dash') then
						repeat task.wait() until (lplr.Character:GetAttribute('CanDashNext') or 0) < workspace:GetServerTimeNow() and bedwars.AbilityController:canUseAbility('dash') or not LongJump.Enabled
					end

					if LongJump.Enabled then
						bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
						switchItem(item.tool, 0.1)
						replicatedStorage['events-@easy-games/game-core:shared/game-core-networking@getEvents.Events'].useAbility:FireServer('dash', {
							direction = dir,
							origin = pos,
							weapon = item.itemType
						})
						JumpSpeed = 4.5 * Value.Value
						JumpTick = tick() + 2.4
						Direction = Vector3.new(dir.X, 0, dir.Z).Unit
					end
				end
			}
			for _, v in {'stone_dao', 'iron_dao', 'diamond_dao', 'emerald_dao'} do
				LongJumpMethods[v] = LongJumpMethods.wood_dao
			end
			LongJumpMethods.void_axe = LongJumpMethods.jade_hammer
			LongJumpMethods.siege_tnt = LongJumpMethods.tnt
			LongJumpMethods.pirate_gunpowder_barrel = LongJumpMethods.tnt

			LongJump = vape.Categories.Blatant:CreateModule({
				Name = 'LongJump',
				Function = function(callback)
					frictionTable.LongJump = callback or nil
					updateVelocity()
					if callback then
						LongJump:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
							if damageTable.entityInstance == lplr.Character and damageTable.fromEntity == lplr.Character and (not damageTable.knockbackMultiplier or not damageTable.knockbackMultiplier.disabled) then
								local knockbackBoost = bedwars.KnockbackUtil.calculateKnockbackVelocity(Vector3.one, 1, {
									vertical = 0,
									horizontal = (damageTable.knockbackMultiplier and damageTable.knockbackMultiplier.horizontal or 1)
								}).Magnitude * 1.1

								if knockbackBoost >= JumpSpeed then
									local pos = damageTable.fromPosition and Vector3.new(damageTable.fromPosition.X, damageTable.fromPosition.Y, damageTable.fromPosition.Z) or damageTable.fromEntity and damageTable.fromEntity.PrimaryPart.Position
									if not pos then return end
									local vec = (entitylib.character.RootPart.Position - pos)
									JumpSpeed = knockbackBoost
									JumpTick = tick() + 2.5
									Direction = Vector3.new(vec.X, 0, vec.Z).Unit
								end
							end
						end))
						LongJump:Clean(vapeEvents.GrapplingHookFunctions.Event:Connect(function(dataTable)
							if dataTable.hookFunction == 'PLAYER_IN_TRANSIT' then
								local vec = entitylib.character.RootPart.CFrame.LookVector
								JumpSpeed = 2.5 * Value.Value
								JumpTick = tick() + 2.5
								Direction = Vector3.new(vec.X, 0, vec.Z).Unit
							end
						end))

						start = entitylib.isAlive and entitylib.character.RootPart.Position or nil
						LongJump:Clean(runService.PreSimulation:Connect(function(dt)
							local root = entitylib.isAlive and entitylib.character.RootPart or nil

							if root and isnetworkowner(root) then
								if JumpTick > tick() then
									root.AssemblyLinearVelocity = Direction * (getSpeed() + ((JumpTick - tick()) > 1.1 and JumpSpeed or 0)) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
									if entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air and not start then
										root.AssemblyLinearVelocity += Vector3.new(0, dt * (workspace.Gravity - 23), 0)
									else
										root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 15, root.AssemblyLinearVelocity.Z)
									end
									start = nil
								else
									if start then
										root.CFrame = CFrame.lookAlong(start, root.CFrame.LookVector)
									end
									root.AssemblyLinearVelocity = Vector3.zero
									JumpSpeed = 0
								end
							else
								start = nil
							end
						end))

						if store.hand and LongJumpMethods[store.hand.tool.Name] then
							task.spawn(LongJumpMethods[store.hand.tool.Name], getItem(store.hand.tool.Name), start, (CameraDir.Enabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector)
							return
						end

						for i, v in LongJumpMethods do
							local item = getItem(i)
							if item or store.equippedKit == i then
								task.spawn(v, item, start, (CameraDir.Enabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector)
								break
							end
						end
					else
						JumpTick = tick()
						Direction = nil
						JumpSpeed = 0
					end
				end,
				ExtraText = function()
					return 'Heatseeker'
				end,
				Tooltip = 'Lets you jump farther'
			})
			Value = LongJump:CreateSlider({
				Name = 'Speed',
				Min = 1,
				Max = 37,
				Default = 37,
				Suffix = function(val)
					return val == 1 and 'stud' or 'studs'
				end
			})
			CameraDir = LongJump:CreateToggle({
				Name = 'Camera Direction'
			})
		end)

		run(function()
			local NoFall
			local Mode
			local rayParams = RaycastParams.new()
			local groundHit
			task.spawn(function()
				groundHit = bedwars.Client:Get(remotes.GroundHit).instance
			end)

			NoFall = vape.Categories.Blatant:CreateModule({
				Name = 'NoFall',
				Function = function(callback)
					if callback then
						local tracked = 0
						if Mode.Value == 'Gravity' then
							local extraGravity = 0
							NoFall:Clean(runService.PreSimulation:Connect(function(dt)
								if entitylib.isAlive then
									local root = entitylib.character.RootPart
									if root.AssemblyLinearVelocity.Y < -85 then
										rayParams.FilterDescendantsInstances = {lplr.Character, gameCamera}
										rayParams.CollisionGroup = root.CollisionGroup

										local rootSize = root.Size.Y / 2 + entitylib.character.HipHeight
										local ray = workspace:Blockcast(root.CFrame, Vector3.new(3, 3, 3), Vector3.new(0, (tracked * 0.1) - rootSize, 0), rayParams)
										if not ray then
											root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, -86, root.AssemblyLinearVelocity.Z)
											root.CFrame += Vector3.new(0, extraGravity * dt, 0)
											extraGravity += -workspace.Gravity * dt
										end
									else
										extraGravity = 0
									end
								end
							end))
						else
							repeat
								if entitylib.isAlive then
									local root = entitylib.character.RootPart
									tracked = entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air and math.min(tracked, root.AssemblyLinearVelocity.Y) or 0

									if tracked < -85 then
										if Mode.Value == 'Packet' then
											groundHit:FireServer(nil, Vector3.new(0, tracked, 0), workspace:GetServerTimeNow())
										else
											rayParams.FilterDescendantsInstances = {lplr.Character, gameCamera}
											rayParams.CollisionGroup = root.CollisionGroup

											local rootSize = root.Size.Y / 2 + entitylib.character.HipHeight
											if Mode.Value == 'Teleport' then
												local ray = workspace:Blockcast(root.CFrame, Vector3.new(3, 3, 3), Vector3.new(0, -1000, 0), rayParams)
												if ray then
													root.CFrame -= Vector3.new(0, root.Position.Y - (ray.Position.Y + rootSize), 0)
												end
											else
												local ray = workspace:Blockcast(root.CFrame, Vector3.new(3, 3, 3), Vector3.new(0, (tracked * 0.1) - rootSize, 0), rayParams)
												if ray then
													tracked = 0
													root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, -80, root.AssemblyLinearVelocity.Z)
												end
											end
										end
									end
								end

								task.wait(0.03)
							until not NoFall.Enabled
						end
					end
				end,
				Tooltip = 'Prevents taking fall damage.'
			})
			Mode = NoFall:CreateDropdown({
				Name = 'Mode',
				List = {'Packet', 'Gravity', 'Teleport', 'Bounce'},
				Function = function()
					if NoFall.Enabled then
						NoFall:Toggle()
						NoFall:Toggle()
					end
				end
			})
		end)

		run(function()
			local old

			vape.Categories.Blatant:CreateModule({
				Name = 'NoSlowdown',
				Function = function(callback)
					local modifier = bedwars.SprintController:getMovementStatusModifier()
					if callback then
						old = modifier.addModifier
						modifier.addModifier = function(self, tab)
							if tab.moveSpeedMultiplier then
								tab.moveSpeedMultiplier = math.max(tab.moveSpeedMultiplier, 1)
							end
							return old(self, tab)
						end

						for i in modifier.modifiers do
							if (i.moveSpeedMultiplier or 1) < 1 then
								modifier:removeModifier(i)
							end
						end
					else
						modifier.addModifier = old
						old = nil
					end
				end,
				Tooltip = 'Prevents slowing down when using items.'
			})
		end)

		run(function()
			local TargetPart
			local Targets
			local FOV
			local OtherProjectiles
			local rayCheck = RaycastParams.new()
			rayCheck.FilterType = Enum.RaycastFilterType.Include
			rayCheck.FilterDescendantsInstances = {workspace:FindFirstChild('Map')}
			local old

			local ProjectileAimbot = vape.Categories.Blatant:CreateModule({
				Name = 'ProjectileAimbot',
				Function = function(callback)
					if callback then
						old = bedwars.ProjectileController.calculateImportantLaunchValues
						bedwars.ProjectileController.calculateImportantLaunchValues = function(...)
							local self, projmeta, worldmeta, origin, shootpos = ...
							local plr = entitylib.EntityMouse({
								Part = 'RootPart',
								Range = FOV.Value,
								Players = Targets.Players.Enabled,
								NPCs = Targets.NPCs.Enabled,
								Wallcheck = Targets.Walls.Enabled,
								Origin = entitylib.isAlive and (shootpos or entitylib.character.RootPart.Position) or Vector3.zero
							})

							if plr then
								local pos = shootpos or self:getLaunchPosition(origin)
								if not pos then
									return old(...)
								end

								if (not OtherProjectiles.Enabled) and not projmeta.projectile:find('arrow') then
									return old(...)
								end

								local meta = projmeta:getProjectileMeta()
								local lifetime = (worldmeta and meta.predictionLifetimeSec or meta.lifetimeSec or 3)
								local gravity = (meta.gravitationalAcceleration or 196.2) * projmeta.gravityMultiplier
								local projSpeed = (meta.launchVelocity or 100)
								local offsetpos = pos + (projmeta.projectile == 'owl_projectile' and Vector3.zero or projmeta.fromPositionOffset)
								local balloons = plr.Character:GetAttribute('InflatedBalloons')
								local playerGravity = workspace.Gravity

								if balloons and balloons > 0 then
									playerGravity = (workspace.Gravity * (1 - ((balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))))
								end

								if plr.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
									playerGravity = 6
								end

								if plr.Player:GetAttribute('IsOwlTarget') then
									for _, owl in collectionService:GetTagged('Owl') do
										if owl:GetAttribute('Target') == plr.Player.UserId and owl:GetAttribute('Status') == 2 then
											playerGravity = 0
										end
									end
								end

								local newlook = CFrame.new(offsetpos, plr[TargetPart.Value].Position) * CFrame.new(projmeta.projectile == 'owl_projectile' and Vector3.zero or Vector3.new(bedwars.BowConstantsTable.RelX, bedwars.BowConstantsTable.RelY, bedwars.BowConstantsTable.RelZ))
								local calc = prediction.SolveTrajectory(newlook.p, projSpeed, gravity, plr[TargetPart.Value].Position, projmeta.projectile == 'telepearl' and Vector3.zero or plr[TargetPart.Value].Velocity, playerGravity, plr.HipHeight, plr.Jumping and 42.6 or nil, rayCheck)
								if calc then
									targetinfo.Targets[plr] = tick() + 1
									return {
										initialVelocity = CFrame.new(newlook.Position, calc).LookVector * projSpeed,
										positionFrom = offsetpos,
										deltaT = lifetime,
										gravitationalAcceleration = gravity,
										drawDurationSeconds = 5
									}
								end
							end

							return old(...)
						end
					else
						bedwars.ProjectileController.calculateImportantLaunchValues = old
					end
				end,
				Tooltip = 'Silently adjusts your aim towards the enemy'
			})
			Targets = ProjectileAimbot:CreateTargets({
				Players = true,
				Walls = true
			})
			TargetPart = ProjectileAimbot:CreateDropdown({
				Name = 'Part',
				List = {'RootPart', 'Head'}
			})
			FOV = ProjectileAimbot:CreateSlider({
				Name = 'FOV',
				Min = 1,
				Max = 1000,
				Default = 1000
			})
			OtherProjectiles = ProjectileAimbot:CreateToggle({
				Name = 'Other Projectiles',
				Default = true
			})
		end)

		run(function()
			local ProjectileAura
			local Targets
			local Range
			local List
			local rayCheck = RaycastParams.new()
			rayCheck.FilterType = Enum.RaycastFilterType.Include
			local projectileRemote = {InvokeServer = function() end}
			local FireDelays = {}
			task.spawn(function()
				projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
			end)

			local function getAmmo(check)
				for _, item in store.inventory.inventory.items do
					if check.ammoItemTypes and table.find(check.ammoItemTypes, item.itemType) then
						return item.itemType
					end
				end
			end

			local function getProjectiles()
				local items = {}
				for _, item in store.inventory.inventory.items do
					local proj = bedwars.ItemMeta[item.itemType].projectileSource
					local ammo = proj and getAmmo(proj)
					if ammo and table.find(List.ListEnabled, ammo) then
						table.insert(items, {
							item,
							ammo,
							proj.projectileType(ammo),
							proj
						})
					end
				end
				return items
			end

			ProjectileAura = vape.Categories.Blatant:CreateModule({
				Name = 'ProjectileAura',
				Function = function(callback)
					if callback then
						repeat
							if (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > 0.5 then
								local ent = entitylib.EntityPosition({
									Part = 'RootPart',
									Range = Range.Value,
									Players = Targets.Players.Enabled,
									NPCs = Targets.NPCs.Enabled,
									Wallcheck = Targets.Walls.Enabled
								})

								if ent then
									local pos = entitylib.character.RootPart.Position
									for _, data in getProjectiles() do
										local item, ammo, projectile, itemMeta = unpack(data)
										if (FireDelays[item.itemType] or 0) < tick() then
											rayCheck.FilterDescendantsInstances = {workspace.Map}
											local meta = bedwars.ProjectileMeta[projectile]
											local projSpeed, gravity = meta.launchVelocity, meta.gravitationalAcceleration or 196.2
											local calc = prediction.SolveTrajectory(pos, projSpeed, gravity, ent.RootPart.Position, ent.RootPart.Velocity, workspace.Gravity, ent.HipHeight, ent.Jumping and 42.6 or nil, rayCheck)
											if calc then
												targetinfo.Targets[ent] = tick() + 1
												local switched = switchItem(item.tool)

												task.spawn(function()
													local dir, id = CFrame.lookAt(pos, calc).LookVector, httpService:GenerateGUID(true)
													local shootPosition = (CFrame.new(pos, calc) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ))).Position
													bedwars.ProjectileController:createLocalProjectile(meta, ammo, projectile, shootPosition, id, dir * projSpeed, {drawDurationSeconds = 1})
													local res = projectileRemote:InvokeServer(item.tool, ammo, projectile, shootPosition, pos, dir * projSpeed, id, {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace:GetServerTimeNow() - 0.045)
													if not res then
														FireDelays[item.itemType] = tick()
													else
														local shoot = itemMeta.launchSound
														shoot = shoot and shoot[math.random(1, #shoot)] or nil
														if shoot then
															bedwars.SoundManager:playSound(shoot)
														end
													end
												end)

												FireDelays[item.itemType] = tick() + itemMeta.fireDelaySec
												if switched then
													task.wait(0.05)
												end
											end
										end
									end
								end
							end
							task.wait(0.1)
						until not ProjectileAura.Enabled
					end
				end,
				Tooltip = 'Shoots people around you'
			})
			Targets = ProjectileAura:CreateTargets({
				Players = true,
				Walls = true
			})
			List = ProjectileAura:CreateTextList({
				Name = 'Projectiles',
				Default = {'arrow', 'snowball'}
			})
			Range = ProjectileAura:CreateSlider({
				Name = 'Range',
				Min = 1,
				Max = 50,
				Default = 50,
				Suffix = function(val)
					return val == 1 and 'stud' or 'studs'
				end
			})
		end)

		run(function()
			local Speed
			local Value
			local WallCheck
			local AutoJump
			local AlwaysJump
			local rayCheck = RaycastParams.new()
			rayCheck.RespectCanCollide = true

			Speed = vape.Categories.Blatant:CreateModule({
				Name = 'Speed',
				Function = function(callback)
					frictionTable.Speed = callback or nil
					updateVelocity()
					pcall(function()
						debug.setconstant(bedwars.WindWalkerController.updateSpeed, 7, callback and 'constantSpeedMultiplier' or 'moveSpeedMultiplier')
					end)

					if callback then
						Speed:Clean(runService.PreSimulation:Connect(function(dt)
							bedwars.StatefulEntityKnockbackController.lastImpulseTime = callback and math.huge or time()
							if entitylib.isAlive and not Fly.Enabled and not InfiniteFly.Enabled and not LongJump.Enabled and isnetworkowner(entitylib.character.RootPart) then
								local state = entitylib.character.Humanoid:GetState()
								if state == Enum.HumanoidStateType.Climbing then return end

								local root, velo = entitylib.character.RootPart, getSpeed()
								local moveDirection = AntiFallDirection or entitylib.character.Humanoid.MoveDirection
								local destination = (moveDirection * math.max(Value.Value - velo, 0) * dt)

								if WallCheck.Enabled then
									rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
									rayCheck.CollisionGroup = root.CollisionGroup
									local ray = workspace:Raycast(root.Position, destination, rayCheck)
									if ray then
										destination = ((ray.Position + ray.Normal) - root.Position)
									end
								end

								root.CFrame += destination
								root.AssemblyLinearVelocity = (moveDirection * velo) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
								if AutoJump.Enabled and (state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed) and moveDirection ~= Vector3.zero and (Attacking or AlwaysJump.Enabled) then
									entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
								end
							end
						end))
					end
				end,
				ExtraText = function()
					return 'Heatseeker'
				end,
				Tooltip = 'Increases your movement with various methods.'
			})
			Value = Speed:CreateSlider({
				Name = 'Speed',
				Min = 1,
				Max = 23,
				Default = 23,
				Suffix = function(val)
					return val == 1 and 'stud' or 'studs'
				end
			})
			WallCheck = Speed:CreateToggle({
				Name = 'Wall Check',
				Default = true
			})
			AutoJump = Speed:CreateToggle({
				Name = 'AutoJump',
				Function = function(callback)
					AlwaysJump.Object.Visible = callback
				end
			})
			AlwaysJump = Speed:CreateToggle({
				Name = 'Always Jump',
				Visible = false,
				Darker = true
			})
		end)

		run(function()
			local BedESP
			local Reference = {}
			local Folder = Instance.new('Folder')
			Folder.Parent = vape.gui

			local function Added(bed)
				if not BedESP.Enabled then return end
				local BedFolder = Instance.new('Folder')
				BedFolder.Parent = Folder
				Reference[bed] = BedFolder
				local parts = bed:GetChildren()
				table.sort(parts, function(a, b)
					return a.Name > b.Name
				end)

				for _, part in parts do
					if part:IsA('BasePart') and part.Name ~= 'Blanket' then
						local handle = Instance.new('BoxHandleAdornment')
						handle.Size = part.Size + Vector3.new(.01, .01, .01)
						handle.AlwaysOnTop = true
						handle.ZIndex = 2
						handle.Visible = true
						handle.Adornee = part
						handle.Color3 = part.Color
						if part.Name == 'Legs' then
							handle.Color3 = Color3.fromRGB(167, 112, 64)
							handle.Size = part.Size + Vector3.new(.01, -1, .01)
							handle.CFrame = CFrame.new(0, -0.4, 0)
							handle.ZIndex = 0
						end
						handle.Parent = BedFolder
					end
				end

				table.clear(parts)
			end

			BedESP = vape.Categories.Render:CreateModule({
				Name = 'BedESP',
				Function = function(callback)
					if callback then
						BedESP:Clean(collectionService:GetInstanceAddedSignal('bed'):Connect(function(bed)
							task.delay(0.2, Added, bed)
						end))
						BedESP:Clean(collectionService:GetInstanceRemovedSignal('bed'):Connect(function(bed)
							if Reference[bed] then
								Reference[bed]:Destroy()
								Reference[bed] = nil
							end
						end))
						for _, bed in collectionService:GetTagged('bed') do
							Added(bed)
						end
					else
						Folder:ClearAllChildren()
						table.clear(Reference)
					end
				end,
				Tooltip = 'Render Beds through walls'
			})
		end)

		run(function()
			local Health

			Health = vape.Categories.Render:CreateModule({
				Name = 'Health',
				Function = function(callback)
					if callback then
						local label = Instance.new('TextLabel')
						label.Size = UDim2.fromOffset(100, 20)
						label.Position = UDim2.new(0.5, 6, 0.5, 30)
						label.BackgroundTransparency = 1
						label.AnchorPoint = Vector2.new(0.5, 0)
						label.Text = entitylib.isAlive and math.round(lplr.Character:GetAttribute('Health'))..' ❤️' or ''
						label.TextColor3 = entitylib.isAlive and Color3.fromHSV((lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) / 2.8, 0.86, 1) or Color3.new()
						label.TextSize = 18
						label.Font = Enum.Font.Arial
						label.Parent = vape.gui
						Health:Clean(label)
						Health:Clean(vapeEvents.AttributeChanged.Event:Connect(function()
							label.Text = entitylib.isAlive and math.round(lplr.Character:GetAttribute('Health'))..' ❤️' or ''
							label.TextColor3 = entitylib.isAlive and Color3.fromHSV((lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) / 2.8, 0.86, 1) or Color3.new()
						end))
					end
				end,
				Tooltip = 'Displays your health in the center of your screen.'
			})
		end)

		run(function()
			local KitESP
			local Background
			local Color = {}
			local Reference = {}
			local Folder = Instance.new('Folder')
			Folder.Parent = vape.gui

			local ESPKits = {
				alchemist = {'alchemist_ingedients', 'wild_flower'},
				beekeeper = {'bee', 'bee'},
				bigman = {'treeOrb', 'natures_essence_1'},
				ghost_catcher = {'ghost', 'ghost_orb'},
				metal_detector = {'hidden-metal', 'iron'},
				sheep_herder = {'SheepModel', 'purple_hay_bale'},
				sorcerer = {'alchemy_crystal', 'wild_flower'},
				star_collector = {'stars', 'crit_star'}
			}

			local function Added(v, icon)
				local billboard = Instance.new('BillboardGui')
				billboard.Parent = Folder
				billboard.Name = icon
				billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
				billboard.Size = UDim2.fromOffset(36, 36)
				billboard.AlwaysOnTop = true
				billboard.ClipsDescendants = false
				billboard.Adornee = v
				local blur = addBlur(billboard)
				blur.Visible = Background.Enabled
				local image = Instance.new('ImageLabel')
				image.Size = UDim2.fromOffset(36, 36)
				image.Position = UDim2.fromScale(0.5, 0.5)
				image.AnchorPoint = Vector2.new(0.5, 0.5)
				image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
				image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
				image.BorderSizePixel = 0
				image.Image = bedwars.getIcon({itemType = icon}, true)
				image.Parent = billboard
				local uicorner = Instance.new('UICorner')
				uicorner.CornerRadius = UDim.new(0, 4)
				uicorner.Parent = image
				Reference[v] = billboard
			end

			local function addKit(tag, icon)
				KitESP:Clean(collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
					Added(v.PrimaryPart, icon)
				end))
				KitESP:Clean(collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
					if Reference[v.PrimaryPart] then
						Reference[v.PrimaryPart]:Destroy()
						Reference[v.PrimaryPart] = nil
					end
				end))
				for _, v in collectionService:GetTagged(tag) do
					Added(v.PrimaryPart, icon)
				end
			end

			KitESP = vape.Categories.Render:CreateModule({
				Name = 'KitESP',
				Function = function(callback)
					if callback then
						repeat task.wait() until store.equippedKit ~= '' or (not KitESP.Enabled)
						local kit = KitESP.Enabled and ESPKits[store.equippedKit] or nil
						if kit then
							addKit(kit[1], kit[2])
						end
					else
						Folder:ClearAllChildren()
						table.clear(Reference)
					end
				end,
				Tooltip = 'ESP for certain kit related objects'
			})
			Background = KitESP:CreateToggle({
				Name = 'Background',
				Function = function(callback)
					if Color.Object then Color.Object.Visible = callback end
					for _, v in Reference do
						v.ImageLabel.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
						v.Blur.Visible = callback
					end
				end,
				Default = true
			})
			Color = KitESP:CreateColorSlider({
				Name = 'Background Color',
				DefaultValue = 0,
				DefaultOpacity = 0.5,
				Function = function(hue, sat, val, opacity)
					for _, v in Reference do
						v.ImageLabel.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
						v.ImageLabel.BackgroundTransparency = 1 - opacity
					end
				end,
				Darker = true
			})
		end)

		run(function()
			local NameTags
			local Targets
			local Color
			local Background
			local DisplayName
			local Health
			local Distance
			local Equipment
			local DrawingToggle
			local Scale
			local FontOption
			local Teammates
			local DistanceCheck
			local DistanceLimit
			local Strings, Sizes, Reference = {}, {}, {}
			local Folder = Instance.new('Folder')
			Folder.Parent = vape.gui
			local methodused

			local Added = {
				Normal = function(ent)
					if not Targets.Players.Enabled and ent.Player then return end
					if not Targets.NPCs.Enabled and ent.NPC then return end
					if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end

					local nametag = Instance.new('TextLabel')
					Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name

					if Health.Enabled then
						local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
						Strings[ent] = Strings[ent]..' <font color="rgb('..tostring(math.floor(healthColor.R * 255))..','..tostring(math.floor(healthColor.G * 255))..','..tostring(math.floor(healthColor.B * 255))..')">'..math.round(ent.Health)..'</font>'
					end

					if Distance.Enabled then
						Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '..Strings[ent]
					end

					if Equipment.Enabled then
						for i, v in {'Hand', 'Helmet', 'Chestplate', 'Boots', 'Kit'} do
							local Icon = Instance.new('ImageLabel')
							Icon.Name = v
							Icon.Size = UDim2.fromOffset(30, 30)
							Icon.Position = UDim2.fromOffset(-60 + (i * 30), -30)
							Icon.BackgroundTransparency = 1
							Icon.Image = ''
							Icon.Parent = nametag
						end
					end

					nametag.TextSize = 14 * Scale.Value
					nametag.FontFace = FontOption.Value
					local size = getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
					nametag.Name = ent.Player and ent.Player.Name or ent.Character.Name
					nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
					nametag.AnchorPoint = Vector2.new(0.5, 1)
					nametag.BackgroundColor3 = Color3.new()
					nametag.BackgroundTransparency = Background.Value
					nametag.BorderSizePixel = 0
					nametag.Visible = false
					nametag.Text = Strings[ent]
					nametag.TextColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
					nametag.RichText = true
					nametag.Parent = Folder
					Reference[ent] = nametag
				end,
				Drawing = function(ent)
					if not Targets.Players.Enabled and ent.Player then return end
					if not Targets.NPCs.Enabled and ent.NPC then return end
					if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end

					local nametag = {}
					nametag.BG = Drawing.new('Square')
					nametag.BG.Filled = true
					nametag.BG.Transparency = 1 - Background.Value
					nametag.BG.Color = Color3.new()
					nametag.BG.ZIndex = 1
					nametag.Text = Drawing.new('Text')
					nametag.Text.Size = 15 * Scale.Value
					nametag.Text.Font = 0
					nametag.Text.ZIndex = 2
					Strings[ent] = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name

					if Health.Enabled then
						Strings[ent] = Strings[ent]..' '..math.round(ent.Health)
					end

					if Distance.Enabled then
						Strings[ent] = '[%s] '..Strings[ent]
					end

					nametag.Text.Text = Strings[ent]
					nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
					nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
					Reference[ent] = nametag
				end
			}

			local Removed = {
				Normal = function(ent)
					local v = Reference[ent]
					if v then
						Reference[ent] = nil
						Strings[ent] = nil
						Sizes[ent] = nil
						v:Destroy()
					end
				end,
				Drawing = function(ent)
					local v = Reference[ent]
					if v then
						Reference[ent] = nil
						Strings[ent] = nil
						Sizes[ent] = nil
						for _, obj in v do
							pcall(function()
								obj.Visible = false
								obj:Remove()
							end)
						end
					end
				end
			}

			local Updated = {
				Normal = function(ent)
					local nametag = Reference[ent]
					if nametag then
						Sizes[ent] = nil
						Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name

						if Health.Enabled then
							local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
							Strings[ent] = Strings[ent]..' <font color="rgb('..tostring(math.floor(healthColor.R * 255))..','..tostring(math.floor(healthColor.G * 255))..','..tostring(math.floor(healthColor.B * 255))..')">'..math.round(ent.Health)..'</font>'
						end

						if Distance.Enabled then
							Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '..Strings[ent]
						end

						if Equipment.Enabled and store.inventories[ent.Player] then
							local kit = ent.Player:GetAttribute('PlayingAsKit')
							local inventory = store.inventories[ent.Player]
							nametag.Hand.Image = bedwars.getIcon(inventory.hand or {itemType = ''}, true)
							nametag.Helmet.Image = bedwars.getIcon(inventory.armor[4] or {itemType = ''}, true)
							nametag.Chestplate.Image = bedwars.getIcon(inventory.armor[5] or {itemType = ''}, true)
							nametag.Boots.Image = bedwars.getIcon(inventory.armor[6] or {itemType = ''}, true)
							nametag.Kit.Image = kit and kit ~= 'none' and bedwars.BedwarsKitMeta[kit].renderImage or ''
						end

						local size = getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
						nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
						nametag.Text = Strings[ent]
					end
				end,
				Drawing = function(ent)
					local nametag = Reference[ent]
					if nametag then
						if vape.ThreadFix then
							setthreadidentity(8)
						end
						Sizes[ent] = nil
						Strings[ent] = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name

						if Health.Enabled then
							Strings[ent] = Strings[ent]..' '..math.round(ent.Health)
						end

						if Distance.Enabled then
							Strings[ent] = '[%s] '..Strings[ent]
							nametag.Text.Text = entitylib.isAlive and string.format(Strings[ent], math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude)) or Strings[ent]
						else
							nametag.Text.Text = Strings[ent]
						end

						nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
						nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
					end
				end
			}

			local ColorFunc = {
				Normal = function(hue, sat, val)
					local color = Color3.fromHSV(hue, sat, val)
					for i, v in Reference do
						v.TextColor3 = entitylib.getEntityColor(i) or color
					end
				end,
				Drawing = function(hue, sat, val)
					local color = Color3.fromHSV(hue, sat, val)
					for i, v in Reference do
						v.Text.Color = entitylib.getEntityColor(i) or color
					end
				end
			}

			local Loop = {
				Normal = function()
					for ent, nametag in Reference do
						if DistanceCheck.Enabled then
							local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
							if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
								nametag.Visible = false
								continue
							end
						end

						local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
						nametag.Visible = headVis
						if not headVis then
							continue
						end

						if Distance.Enabled then
							local mag = entitylib.isAlive and math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude) or 0
							if Sizes[ent] ~= mag then
								nametag.Text = string.format(Strings[ent], mag)
								local ize = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
								nametag.Size = UDim2.fromOffset(ize.X + 8, ize.Y + 7)
								Sizes[ent] = mag
							end
						end
						nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
					end
				end,
				Drawing = function()
					for ent, nametag in Reference do
						if DistanceCheck.Enabled then
							local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
							if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
								nametag.Text.Visible = false
								nametag.BG.Visible = false
								continue
							end
						end

						local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
						nametag.Text.Visible = headVis
						nametag.BG.Visible = headVis
						if not headVis then
							continue
						end

						if Distance.Enabled then
							local mag = entitylib.isAlive and math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude) or 0
							if Sizes[ent] ~= mag then
								nametag.Text.Text = string.format(Strings[ent], mag)
								nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
								Sizes[ent] = mag
							end
						end
						nametag.BG.Position = Vector2.new(headPos.X - (nametag.BG.Size.X / 2), headPos.Y - nametag.BG.Size.Y)
						nametag.Text.Position = nametag.BG.Position + Vector2.new(4, 3)
					end
				end
			}

			NameTags = vape.Categories.Render:CreateModule({
				Name = 'NameTags',
				Function = function(callback)
					if callback then
						methodused = DrawingToggle.Enabled and 'Drawing' or 'Normal'
						if Removed[methodused] then
							NameTags:Clean(entitylib.Events.EntityRemoved:Connect(Removed[methodused]))
						end
						if Added[methodused] then
							for _, v in entitylib.List do
								if Reference[v] then
									Removed[methodused](v)
								end
								Added[methodused](v)
							end
							NameTags:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
								if Reference[ent] then
									Removed[methodused](ent)
								end
								Added[methodused](ent)
							end))
						end
						if Updated[methodused] then
							NameTags:Clean(entitylib.Events.EntityUpdated:Connect(Updated[methodused]))
							for _, v in entitylib.List do
								Updated[methodused](v)
							end
						end
						if ColorFunc[methodused] then
							NameTags:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
								ColorFunc[methodused](Color.Hue, Color.Sat, Color.Value)
							end))
						end
						if Loop[methodused] then
							NameTags:Clean(runService.RenderStepped:Connect(Loop[methodused]))
						end
					else
						if Removed[methodused] then
							for i in Reference do
								Removed[methodused](i)
							end
						end
					end
				end,
				Tooltip = 'Renders nametags on entities through walls.'
			})
			Targets = NameTags:CreateTargets({
				Players = true,
				Function = function()
					if NameTags.Enabled then
						NameTags:Toggle()
						NameTags:Toggle()
					end
				end
			})
			FontOption = NameTags:CreateFont({
				Name = 'Font',
				Blacklist = 'Arial',
				Function = function()
					if NameTags.Enabled then
						NameTags:Toggle()
						NameTags:Toggle()
					end
				end
			})
			Color = NameTags:CreateColorSlider({
				Name = 'Player Color',
				Function = function(hue, sat, val)
					if NameTags.Enabled and ColorFunc[methodused] then
						ColorFunc[methodused](hue, sat, val)
					end
				end
			})
			Scale = NameTags:CreateSlider({
				Name = 'Scale',
				Function = function()
					if NameTags.Enabled then
						NameTags:Toggle()
						NameTags:Toggle()
					end
				end,
				Default = 1,
				Min = 0.1,
				Max = 1.5,
				Decimal = 10
			})
			Background = NameTags:CreateSlider({
				Name = 'Transparency',
				Function = function()
					if NameTags.Enabled then
						NameTags:Toggle()
						NameTags:Toggle()
					end
				end,
				Default = 0.5,
				Min = 0,
				Max = 1,
				Decimal = 10
			})
			Health = NameTags:CreateToggle({
				Name = 'Health',
				Function = function()
					if NameTags.Enabled then
						NameTags:Toggle()
						NameTags:Toggle()
					end
				end
			})
			Distance = NameTags:CreateToggle({
				Name = 'Distance',
				Function = function()
					if NameTags.Enabled then
						NameTags:Toggle()
						NameTags:Toggle()
					end
				end
			})
			Equipment = NameTags:CreateToggle({
				Name = 'Equipment',
				Function = function()
					if NameTags.Enabled then
						NameTags:Toggle()
						NameTags:Toggle()
					end
				end
			})
			DisplayName = NameTags:CreateToggle({
				Name = 'Use Displayname',
				Function = function()
					if NameTags.Enabled then
						NameTags:Toggle()
						NameTags:Toggle()
					end
				end,
				Default = true
			})
			Teammates = NameTags:CreateToggle({
				Name = 'Priority Only',
				Function = function()
					if NameTags.Enabled then
						NameTags:Toggle()
						NameTags:Toggle()
					end
				end,
				Default = true
			})
			DrawingToggle = NameTags:CreateToggle({
				Name = 'Drawing',
				Function = function()
					if NameTags.Enabled then
						NameTags:Toggle()
						NameTags:Toggle()
					end
				end,
			})
			DistanceCheck = NameTags:CreateToggle({
				Name = 'Distance Check',
				Function = function(callback)
					DistanceLimit.Object.Visible = callback
				end
			})
			DistanceLimit = NameTags:CreateTwoSlider({
				Name = 'Player Distance',
				Min = 0,
				Max = 256,
				DefaultMin = 0,
				DefaultMax = 64,
				Darker = true,
				Visible = false
			})
		end)

		run(function()
			local StorageESP
			local List
			local Background
			local Color = {}
			local Reference = {}
			local Folder = Instance.new('Folder')
			Folder.Parent = vape.gui

			local function nearStorageItem(item)
				for _, v in List.ListEnabled do
					if item:find(v) then return v end
				end
			end

			local function refreshAdornee(v)
				local chest = v.Adornee:FindFirstChild('ChestFolderValue')
				chest = chest and chest.Value or nil
				if not chest then
					v.Enabled = false
					return
				end

				local chestitems = chest and chest:GetChildren() or {}
				for _, obj in v.Frame:GetChildren() do
					if obj:IsA('ImageLabel') and obj.Name ~= 'Blur' then
						obj:Destroy()
					end
				end

				v.Enabled = false
				local alreadygot = {}
				for _, item in chestitems do
					if not alreadygot[item.Name] and (table.find(List.ListEnabled, item.Name) or nearStorageItem(item.Name)) then
						alreadygot[item.Name] = true
						v.Enabled = true
						local blockimage = Instance.new('ImageLabel')
						blockimage.Size = UDim2.fromOffset(32, 32)
						blockimage.BackgroundTransparency = 1
						blockimage.Image = bedwars.getIcon({itemType = item.Name}, true)
						blockimage.Parent = v.Frame
					end
				end
				table.clear(chestitems)
			end

			local function Added(v)
				local chest = v:WaitForChild('ChestFolderValue', 3)
				if not (chest and StorageESP.Enabled) then return end
				chest = chest.Value
				local billboard = Instance.new('BillboardGui')
				billboard.Parent = Folder
				billboard.Name = 'chest'
				billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
				billboard.Size = UDim2.fromOffset(36, 36)
				billboard.AlwaysOnTop = true
				billboard.ClipsDescendants = false
				billboard.Adornee = v
				local blur = addBlur(billboard)
				blur.Visible = Background.Enabled
				local frame = Instance.new('Frame')
				frame.Size = UDim2.fromScale(1, 1)
				frame.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
				frame.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
				frame.Parent = billboard
				local layout = Instance.new('UIListLayout')
				layout.FillDirection = Enum.FillDirection.Horizontal
				layout.Padding = UDim.new(0, 4)
				layout.VerticalAlignment = Enum.VerticalAlignment.Center
				layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
				layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
					billboard.Size = UDim2.fromOffset(math.max(layout.AbsoluteContentSize.X + 4, 36), 36)
				end)
				layout.Parent = frame
				local corner = Instance.new('UICorner')
				corner.CornerRadius = UDim.new(0, 4)
				corner.Parent = frame
				Reference[v] = billboard
				StorageESP:Clean(chest.ChildAdded:Connect(function(item)
					if table.find(List.ListEnabled, item.Name) or nearStorageItem(item.Name) then
						refreshAdornee(billboard)
					end
				end))
				StorageESP:Clean(chest.ChildRemoved:Connect(function(item)
					if table.find(List.ListEnabled, item.Name) or nearStorageItem(item.Name) then
						refreshAdornee(billboard)
					end
				end))
				task.spawn(refreshAdornee, billboard)
			end

			StorageESP = vape.Categories.Render:CreateModule({
				Name = 'StorageESP',
				Function = function(callback)
					if callback then
						StorageESP:Clean(collectionService:GetInstanceAddedSignal('chest'):Connect(Added))
						for _, v in collectionService:GetTagged('chest') do
							task.spawn(Added, v)
						end
					else
						table.clear(Reference)
						Folder:ClearAllChildren()
					end
				end,
				Tooltip = 'Displays items in chests'
			})
			List = StorageESP:CreateTextList({
				Name = 'Item',
				Function = function()
					for _, v in Reference do
						task.spawn(refreshAdornee, v)
					end
				end
			})
			Background = StorageESP:CreateToggle({
				Name = 'Background',
				Function = function(callback)
					if Color.Object then Color.Object.Visible = callback end
					for _, v in Reference do
						v.Frame.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
						v.Blur.Visible = callback
					end
				end,
				Default = true
			})
			Color = StorageESP:CreateColorSlider({
				Name = 'Background Color',
				DefaultValue = 0,
				DefaultOpacity = 0.5,
				Function = function(hue, sat, val, opacity)
					for _, v in Reference do
						v.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
						v.Frame.BackgroundTransparency = 1 - opacity
					end
				end,
				Darker = true
			})
		end)

		run(function()
			local AutoBalloon

			AutoBalloon = vape.Categories.Utility:CreateModule({
				Name = 'AutoBalloon',
				Function = function(callback)
					if callback then
						repeat task.wait() until store.matchState ~= 0 or (not AutoBalloon.Enabled)
						if not AutoBalloon.Enabled then return end

						local lowestpoint = math.huge
						for _, v in store.blocks do
							local point = (v.Position.Y - (v.Size.Y / 2)) - 50
							if point < lowestpoint then 
								lowestpoint = point 
							end
						end

						repeat
							if entitylib.isAlive then
								if entitylib.character.RootPart.Position.Y < lowestpoint and (lplr.Character:GetAttribute('InflatedBalloons') or 0) < 3 then
									local balloon = getItem('balloon')
									if balloon then
										for _ = 1, 3 do 
											bedwars.BalloonController:inflateBalloon() 
										end
									end
									task.wait(0.1)
								end
							end
							task.wait(0.1)
						until not AutoBalloon.Enabled
					end
				end,
				Tooltip = 'Inflates when you fall into the void'
			})
		end)

		run(function()
			local AutoKit
			local Legit
			local Toggles = {}

			local function kitCollection(id, func, range, specific)
				local objs = type(id) == 'table' and id or collection(id, AutoKit)
				repeat
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in objs do
							if InfiniteFly.Enabled or not AutoKit.Enabled then break end
							local part = not v:IsA('Model') and v or v.PrimaryPart
							if part and (part.Position - localPosition).Magnitude <= (not Legit.Enabled and specific and math.huge or range) then
								func(v)
							end
						end
					end
					task.wait(0.1)
				until not AutoKit.Enabled
			end

			local AutoKitFunctions = {
				battery = function()
					repeat
						if entitylib.isAlive then
							local localPosition = entitylib.character.RootPart.Position
							for i, v in bedwars.BatteryEffectsController.liveBatteries do
								if (v.position - localPosition).Magnitude <= 10 then
									local BatteryInfo = bedwars.BatteryEffectsController:getBatteryInfo(i)
									if not BatteryInfo or BatteryInfo.activateTime >= workspace:GetServerTimeNow() or BatteryInfo.consumeTime + 0.1 >= workspace:GetServerTimeNow() then continue end
									BatteryInfo.consumeTime = workspace:GetServerTimeNow()
									bedwars.Client:Get(remotes.ConsumeBattery):SendToServer({batteryId = i})
								end
							end
						end
						task.wait(0.1)
					until not AutoKit.Enabled
				end,
				beekeeper = function()
					kitCollection('bee', function(v)
						bedwars.Client:Get(remotes.BeePickup):SendToServer({beeId = v:GetAttribute('BeeId')})
					end, 18, false)
				end,
				bigman = function()
					kitCollection('treeOrb', function(v)
						if bedwars.Client:Get(remotes.ConsumeTreeOrb):CallServer({treeOrbSecret = v:GetAttribute('TreeOrbSecret')}) then
							v:Destroy()
						end
					end, 12, false)
				end,
				block_kicker = function()
					local old = bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition
					bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition = function(...)
						local origin, dir = select(2, ...)
						local plr = entitylib.EntityMouse({
							Part = 'RootPart',
							Range = 1000,
							Origin = origin,
							Players = true,
							Wallcheck = true
						})

						if plr then
							local calc = prediction.SolveTrajectory(origin, 100, 20, plr.RootPart.Position, plr.RootPart.Velocity, workspace.Gravity, plr.HipHeight, plr.Jumping and 42.6 or nil)

							if calc then
								for i, v in debug.getstack(2) do
									if v == dir then
										debug.setstack(2, i, CFrame.lookAt(origin, calc).LookVector)
									end
								end
							end
						end

						return old(...)
					end

					AutoKit:Clean(function()
						bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition = old
					end)
				end,
				cat = function()
					local old = bedwars.CatController.leap
					bedwars.CatController.leap = function(...)
						vapeEvents.CatPounce:Fire()
						return old(...)
					end

					AutoKit:Clean(function()
						bedwars.CatController.leap = old
					end)
				end,
				davey = function()
					local old = bedwars.CannonHandController.launchSelf
					bedwars.CannonHandController.launchSelf = function(...)
						local res = {old(...)}
						local self, block = ...

						if block:GetAttribute('PlacedByUserId') == lplr.UserId and (block.Position - entitylib.character.RootPart.Position).Magnitude < 30 then
							task.spawn(bedwars.breakBlock, block, false, nil, true)
						end

						return unpack(res)
					end

					AutoKit:Clean(function()
						bedwars.CannonHandController.launchSelf = old
					end)
				end,
				dragon_slayer = function()
					kitCollection('KaliyahPunchInteraction', function(v)
						bedwars.DragonSlayerController:deleteEmblem(v)
						bedwars.DragonSlayerController:playPunchAnimation(Vector3.zero)
						bedwars.Client:Get(remotes.KaliyahPunch):SendToServer({
							target = v
						})
					end, 18, true)
				end,
				farmer_cletus = function()
					kitCollection('HarvestableCrop', function(v)
						if bedwars.Client:Get(remotes.HarvestCrop):CallServer({position = bedwars.BlockController:getBlockPosition(v.Position)}) then
							bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.PUNCH)
							bedwars.SoundManager:playSound(bedwars.SoundList.CROP_HARVEST)
						end
					end, 10, false)
				end,
				fisherman = function()
					local old = bedwars.FishingMinigameController.startMinigame
					bedwars.FishingMinigameController.startMinigame = function(_, _, result)
						result({win = true})
					end

					AutoKit:Clean(function()
						bedwars.FishingMinigameController.startMinigame = old
					end)
				end,
				gingerbread_man = function()
					local old = bedwars.LaunchPadController.attemptLaunch
					bedwars.LaunchPadController.attemptLaunch = function(...)
						local res = {old(...)}
						local self, block = ...

						if (workspace:GetServerTimeNow() - self.lastLaunch) < 0.4 then
							if block:GetAttribute('PlacedByUserId') == lplr.UserId and (block.Position - entitylib.character.RootPart.Position).Magnitude < 30 then
								task.spawn(bedwars.breakBlock, block, false, nil, true)
							end
						end

						return unpack(res)
					end

					AutoKit:Clean(function()
						bedwars.LaunchPadController.attemptLaunch = old
					end)
				end,
				hannah = function()
					kitCollection('HannahExecuteInteraction', function(v)
						local billboard = bedwars.Client:Get(remotes.HannahKill):CallServer({
							user = lplr,
							victimEntity = v
						}) and v:FindFirstChild('Hannah Execution Icon')

						if billboard then
							billboard:Destroy()
						end
					end, 30, true)
				end,
				jailor = function()
					kitCollection('jailor_soul', function(v)
						bedwars.JailorController:collectEntity(lplr, v, 'JailorSoul')
					end, 20, false)
				end,
				grim_reaper = function()
					kitCollection(bedwars.GrimReaperController.soulsByPosition, function(v)
						if entitylib.isAlive and lplr.Character:GetAttribute('Health') <= (lplr.Character:GetAttribute('MaxHealth') / 4) and (not lplr.Character:GetAttribute('GrimReaperChannel')) then
							bedwars.Client:Get(remotes.ConsumeSoul):CallServer({
								secret = v:GetAttribute('GrimReaperSoulSecret')
							})
						end
					end, 120, false)
				end,
				melody = function()
					repeat
						local mag, hp, ent = 30, math.huge
						if entitylib.isAlive then
							local localPosition = entitylib.character.RootPart.Position
							for _, v in entitylib.List do
								if v.Player and v.Player:GetAttribute('Team') == lplr:GetAttribute('Team') then
									local newmag = (localPosition - v.RootPart.Position).Magnitude
									if newmag <= mag and v.Health < hp and v.Health < v.MaxHealth then
										mag, hp, ent = newmag, v.Health, v
									end
								end
							end
						end

						if ent and getItem('guitar') then
							bedwars.Client:Get(remotes.GuitarHeal):SendToServer({
								healTarget = ent.Character
							})
						end

						task.wait(0.1)
					until not AutoKit.Enabled
				end,
				metal_detector = function()
					kitCollection('hidden-metal', function(v)
						bedwars.Client:Get(remotes.PickupMetal):SendToServer({
							id = v:GetAttribute('Id')
						})
					end, 20, false)
				end,
				miner = function()
					kitCollection('petrified-player', function(v)
						bedwars.Client:Get(remotes.MinerDig):SendToServer({
							petrifyId = v:GetAttribute('PetrifyId')
						})
					end, 6, true)
				end,
				pinata = function()
					kitCollection(lplr.Name..':pinata', function(v)
						if getItem('candy') then
							bedwars.Client:Get(remotes.DepositPinata):CallServer(v)
						end
					end, 6, true)
				end,
				spirit_assassin = function()
					kitCollection('EvelynnSoul', function(v)
						bedwars.SpiritAssassinController:useSpirit(lplr, v)
					end, 120, true)
				end,
				star_collector = function()
					kitCollection('stars', function(v)
						bedwars.StarCollectorController:collectEntity(lplr, v, v.Name)
					end, 20, false)
				end,
				summoner = function()
					repeat
						local plr = entitylib.EntityPosition({
							Range = 31,
							Part = 'RootPart',
							Players = true,
							Sort = sortmethods.Health
						})

						if plr and (not Legit.Enabled or (lplr.Character:GetAttribute('Health') or 0) > 0) then
							local localPosition = entitylib.character.RootPart.Position
							local shootDir = CFrame.lookAt(localPosition, plr.RootPart.Position).LookVector
							localPosition += shootDir * math.max((localPosition - plr.RootPart.Position).Magnitude - 16, 0)

							bedwars.Client:Get(remotes.SummonerClawAttack):SendToServer({
								position = localPosition,
								direction = shootDir,
								clientTime = workspace:GetServerTimeNow()
							})
						end

						task.wait(0.1)
					until not AutoKit.Enabled
				end,
				void_dragon = function()
					local oldflap = bedwars.VoidDragonController.flapWings
					local flapped

					bedwars.VoidDragonController.flapWings = function(self)
						if not flapped and bedwars.Client:Get(remotes.DragonFly):CallServer() then
							local modifier = bedwars.SprintController:getMovementStatusModifier():addModifier({
								blockSprint = true,
								constantSpeedMultiplier = 2
							})
							self.SpeedMaid:GiveTask(modifier)
							self.SpeedMaid:GiveTask(function()
								flapped = false
							end)
							flapped = true
						end
					end

					AutoKit:Clean(function()
						bedwars.VoidDragonController.flapWings = oldflap
					end)

					repeat
						if bedwars.VoidDragonController.inDragonForm then
							local plr = entitylib.EntityPosition({
								Range = 30,
								Part = 'RootPart',
								Players = true
							})

							if plr then
								bedwars.Client:Get(remotes.DragonBreath):SendToServer({
									player = lplr,
									targetPoint = plr.RootPart.Position
								})
							end
						end
						task.wait(0.1)
					until not AutoKit.Enabled
				end,
				warlock = function()
					local lastTarget
					repeat
						if store.hand.tool and store.hand.tool.Name == 'warlock_staff' then
							local plr = entitylib.EntityPosition({
								Range = 30,
								Part = 'RootPart',
								Players = true,
								NPCs = true
							})

							if plr and plr.Character ~= lastTarget then
								if not bedwars.Client:Get(remotes.WarlockTarget):CallServer({
									target = plr.Character
									}) then
									plr = nil
								end
							end

							lastTarget = plr and plr.Character
						else
							lastTarget = nil
						end

						task.wait(0.1)
					until not AutoKit.Enabled
				end,
				wizard = function()
					repeat
						local ability = lplr:GetAttribute('WizardAbility')
						if ability and bedwars.AbilityController:canUseAbility(ability) then
							local plr = entitylib.EntityPosition({
								Range = 50,
								Part = 'RootPart',
								Players = true,
								Sort = sortmethods.Health
							})

							if plr then
								bedwars.AbilityController:useAbility(ability, newproxy(true), {target = plr.RootPart.Position})
							end
						end

						task.wait(0.1)
					until not AutoKit.Enabled
				end
			}

			AutoKit = vape.Categories.Utility:CreateModule({
				Name = 'AutoKit',
				Function = function(callback)
					if callback then
						repeat task.wait() until store.equippedKit ~= '' and store.matchState ~= 0 or (not AutoKit.Enabled)
						if AutoKit.Enabled and AutoKitFunctions[store.equippedKit] and Toggles[store.equippedKit].Enabled then
							AutoKitFunctions[store.equippedKit]()
						end
					end
				end,
				Tooltip = 'Automatically uses kit abilities.'
			})
			Legit = AutoKit:CreateToggle({Name = 'Legit Range'})
			local sortTable = {}
			for i in AutoKitFunctions do
				table.insert(sortTable, i)
			end
			table.sort(sortTable, function(a, b)
				return bedwars.BedwarsKitMeta[a].name < bedwars.BedwarsKitMeta[b].name
			end)
			for _, v in sortTable do
				Toggles[v] = AutoKit:CreateToggle({
					Name = bedwars.BedwarsKitMeta[v].name,
					Default = true
				})
			end
		end)

		run(function()
			local AutoPearl
			local rayCheck = RaycastParams.new()
			rayCheck.RespectCanCollide = true
			local projectileRemote = {InvokeServer = function() end}
			task.spawn(function()
				projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
			end)

			local function firePearl(pos, spot, item)
				switchItem(item.tool)
				local meta = bedwars.ProjectileMeta.telepearl
				local calc = prediction.SolveTrajectory(pos, meta.launchVelocity, meta.gravitationalAcceleration, spot, Vector3.zero, workspace.Gravity, 0, 0)

				if calc then
					local dir = CFrame.lookAt(pos, calc).LookVector * meta.launchVelocity
					bedwars.ProjectileController:createLocalProjectile(meta, 'telepearl', 'telepearl', pos, nil, dir, {drawDurationSeconds = 1})
					projectileRemote:InvokeServer(item.tool, 'telepearl', 'telepearl', pos, pos, dir, httpService:GenerateGUID(true), {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace:GetServerTimeNow() - 0.045)
				end

				if store.hand then
					switchItem(store.hand.tool)
				end
			end

			AutoPearl = vape.Categories.Utility:CreateModule({
				Name = 'AutoPearl',
				Function = function(callback)
					if callback then
						local check
						repeat
							if entitylib.isAlive then
								local root = entitylib.character.RootPart
								local pearl = getItem('telepearl')
								rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiFallPart}
								rayCheck.CollisionGroup = root.CollisionGroup

								if pearl and root.Velocity.Y < -100 and not workspace:Raycast(root.Position, Vector3.new(0, -200, 0), rayCheck) then
									if not check then
										check = true
										local ground = getNearGround(20)

										if ground then
											firePearl(root.Position, ground, pearl)
										end
									end
								else
									check = false
								end
							end
							task.wait(0.1)
						until not AutoPearl.Enabled
					end
				end,
				Tooltip = 'Automatically throws a pearl onto nearby ground after\nfalling a certain distance.'
			})
		end)

		run(function()
			local AutoPlay
			local Random

			local function isEveryoneDead()
				return #bedwars.Store:getState().Party.members <= 0
			end

			local function joinQueue()
				if not bedwars.Store:getState().Game.customMatch and bedwars.Store:getState().Party.leader.userId == lplr.UserId and bedwars.Store:getState().Party.queueState == 0 then
					if Random.Enabled then
						local listofmodes = {}
						for i, v in bedwars.QueueMeta do
							if not v.disabled and not v.voiceChatOnly and not v.rankCategory then 
								table.insert(listofmodes, i) 
							end
						end
						bedwars.QueueController:joinQueue(listofmodes[math.random(1, #listofmodes)])
					else
						bedwars.QueueController:joinQueue(store.queueType)
					end
				end
			end

			AutoPlay = vape.Categories.Utility:CreateModule({
				Name = 'AutoPlay',
				Function = function(callback)
					if callback then
						AutoPlay:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
							if deathTable.finalKill and deathTable.entityInstance == lplr.Character and isEveryoneDead() and store.matchState ~= 2 then
								joinQueue()
							end
						end))
						AutoPlay:Clean(vapeEvents.MatchEndEvent.Event:Connect(joinQueue))
					end
				end,
				Tooltip = 'Automatically queues after the match ends.'
			})
			Random = AutoPlay:CreateToggle({
				Name = 'Random',
				Tooltip = 'Chooses a random mode'
			})
		end)

		run(function()
			local shooting, old = false

			local function getCrossbows()
				local crossbows = {}
				for i, v in store.inventory.hotbar do
					if v.item and v.item.itemType:find('crossbow') and i ~= (store.inventory.hotbarSlot + 1) then table.insert(crossbows, i - 1) end
				end
				return crossbows
			end

			vape.Categories.Utility:CreateModule({
				Name = 'AutoShoot',
				Function = function(callback)
					if callback then
						old = bedwars.ProjectileController.createLocalProjectile
						bedwars.ProjectileController.createLocalProjectile = function(...)
							local source, data, proj = ...
							if source and (proj == 'arrow' or proj == 'fireball') and not shooting then
								task.spawn(function()
									local bows = getCrossbows()
									if #bows > 0 then
										shooting = true
										task.wait(0.15)
										local selected = store.inventory.hotbarSlot
										for _, v in getCrossbows() do
											if hotbarSwitch(v) then
												task.wait(0.05)
												mouse1click()
												task.wait(0.05)
											end
										end
										hotbarSwitch(selected)
										shooting = false
									end
								end)
							end
							return old(...)
						end
					else
						bedwars.ProjectileController.createLocalProjectile = old
					end
				end,
				Tooltip = 'Automatically crossbow macro\'s'
			})

		end)

		run(function()
			local AutoToxic
			local GG
			local Toggles, Lists, said, dead = {}, {}, {}

			local function sendMessage(name, obj, default)
				local tab = Lists[name].ListEnabled
				local custommsg = #tab > 0 and tab[math.random(1, #tab)] or default
				if not custommsg then return end
				if #tab > 1 and custommsg == said[name] then
					repeat 
						task.wait() 
						custommsg = tab[math.random(1, #tab)] 
					until custommsg ~= said[name]
				end
				said[name] = custommsg

				custommsg = custommsg and custommsg:gsub('<obj>', obj or '') or ''
				if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
					textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(custommsg)
				else
					replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(custommsg, 'All')
				end
			end

			AutoToxic = vape.Categories.Utility:CreateModule({
				Name = 'AutoToxic',
				Function = function(callback)
					if callback then
						AutoToxic:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
							if Toggles.BedDestroyed.Enabled and bedTable.brokenBedTeam.id == lplr:GetAttribute('Team') then
								sendMessage('BedDestroyed', (bedTable.player.DisplayName or bedTable.player.Name), 'how dare you >:( | <obj>')
							elseif Toggles.Bed.Enabled and bedTable.player.UserId == lplr.UserId then
								local team = bedwars.QueueMeta[store.queueType].teams[tonumber(bedTable.brokenBedTeam.id)]
								sendMessage('Bed', team and team.displayName:lower() or 'white', 'nice bed lul | <obj>')
							end
						end))
						AutoToxic:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
							if deathTable.finalKill then
								local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
								local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
								if not killed or not killer then return end
								if killed == lplr then
									if (not dead) and killer ~= lplr and Toggles.Death.Enabled then
										dead = true
										sendMessage('Death', (killer.DisplayName or killer.Name), 'my gaming chair subscription expired :( | <obj>')
									end
								elseif killer == lplr and Toggles.Kill.Enabled then
									sendMessage('Kill', (killed.DisplayName or killed.Name), 'vxp on top | <obj>')
								end
							end
						end))
						AutoToxic:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winstuff)
							if GG.Enabled then
								if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
									textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync('gg')
								else
									replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer('gg', 'All')
								end
							end

							local myTeam = bedwars.Store:getState().Game.myTeam
							if myTeam and myTeam.id == winstuff.winningTeamId or lplr.Neutral then
								if Toggles.Win.Enabled then 
									sendMessage('Win', nil, 'yall garbage') 
								end
							end
						end))
					end
				end,
				Tooltip = 'Says a message after a certain action'
			})
			GG = AutoToxic:CreateToggle({
				Name = 'AutoGG',
				Default = true
			})
			for _, v in {'Kill', 'Death', 'Bed', 'BedDestroyed', 'Win'} do
				Toggles[v] = AutoToxic:CreateToggle({
					Name = v..' ',
					Function = function(callback)
						if Lists[v] then
							Lists[v].Object.Visible = callback
						end
					end
				})
				Lists[v] = AutoToxic:CreateTextList({
					Name = v,
					Darker = true,
					Visible = false
				})
			end
		end)

		run(function()
			local AutoVoidDrop
			local OwlCheck

			AutoVoidDrop = vape.Categories.Utility:CreateModule({
				Name = 'AutoVoidDrop',
				Function = function(callback)
					if callback then
						repeat task.wait() until store.matchState ~= 0 or (not AutoVoidDrop.Enabled)
						if not AutoVoidDrop.Enabled then return end

						local lowestpoint = math.huge
						for _, v in store.blocks do
							local point = (v.Position.Y - (v.Size.Y / 2)) - 50
							if point < lowestpoint then
								lowestpoint = point
							end
						end

						repeat
							if entitylib.isAlive then
								local root = entitylib.character.RootPart
								if root.Position.Y < lowestpoint and (lplr.Character:GetAttribute('InflatedBalloons') or 0) <= 0 and not getItem('balloon') then
									if not OwlCheck.Enabled or not root:FindFirstChild('OwlLiftForce') then
										for _, item in {'iron', 'diamond', 'emerald', 'gold'} do
											item = getItem(item)
											if item then
												item = bedwars.Client:Get(remotes.DropItem):CallServer({
													item = item.tool,
													amount = item.amount
												})

												if item then
													item:SetAttribute('ClientDropTime', tick() + 100)
												end
											end
										end
									end
								end
							end

							task.wait(0.1)
						until not AutoVoidDrop.Enabled
					end
				end,
				Tooltip = 'Drops resources when you fall into the void'
			})
			OwlCheck = AutoVoidDrop:CreateToggle({
				Name = 'Owl check',
				Default = true,
				Tooltip = 'Refuses to drop items if being picked up by an owl'
			})
		end)

		run(function()
			local MissileTP

			MissileTP = vape.Categories.Utility:CreateModule({
				Name = 'MissileTP',
				Function = function(callback)
					if callback then
						MissileTP:Toggle()
						local plr = entitylib.EntityMouse({
							Range = 1000,
							Players = true,
							Part = 'RootPart'
						})

						if getItem('guided_missile') and plr then
							local projectile = bedwars.RuntimeLib.await(bedwars.GuidedProjectileController.fireGuidedProjectile:CallServerAsync('guided_missile'))
							if projectile then
								local projectilemodel = projectile.model
								if not projectilemodel.PrimaryPart then
									projectilemodel:GetPropertyChangedSignal('PrimaryPart'):Wait()
								end

								local bodyforce = Instance.new('BodyForce')
								bodyforce.Force = Vector3.new(0, projectilemodel.PrimaryPart.AssemblyMass * workspace.Gravity, 0)
								bodyforce.Name = 'AntiGravity'
								bodyforce.Parent = projectilemodel.PrimaryPart

								repeat
									projectile.model:SetPrimaryPartCFrame(CFrame.lookAlong(plr.RootPart.CFrame.p, gameCamera.CFrame.LookVector))
									task.wait(0.1)
								until not projectile.model or not projectile.model.Parent
							else
								notif('MissileTP', 'Missile on cooldown.', 3)
							end
						end
					end
				end,
				Tooltip = 'Spawns and teleports a missile to a player\nnear your mouse.'
			})
		end)

		run(function()
			local PickupRange
			local Range
			local Network
			local Lower

			PickupRange = vape.Categories.Utility:CreateModule({
				Name = 'PickupRange',
				Function = function(callback)
					if callback then
						local items = collection('ItemDrop', PickupRange)
						repeat
							if entitylib.isAlive then
								local localPosition = entitylib.character.RootPart.Position
								for _, v in items do
									if tick() - (v:GetAttribute('ClientDropTime') or 0) < 2 then continue end
									if isnetworkowner(v) and Network.Enabled and entitylib.character.Humanoid.Health > 0 then 
										v.CFrame = CFrame.new(localPosition - Vector3.new(0, 3, 0)) 
									end

									if (localPosition - v.Position).Magnitude <= Range.Value then
										if Lower.Enabled and (localPosition.Y - v.Position.Y) < (entitylib.character.HipHeight - 1) then continue end
										task.spawn(function()
											bedwars.Client:Get(remotes.PickupItem):CallServerAsync({
												itemDrop = v
											}):andThen(function(suc)
												if suc and bedwars.SoundList then
													bedwars.SoundManager:playSound(bedwars.SoundList.PICKUP_ITEM_DROP)
													local sound = bedwars.ItemMeta[v.Name].pickUpOverlaySound
													if sound then
														bedwars.SoundManager:playSound(sound, {
															position = v.Position,
															volumeMultiplier = 0.9
														})
													end
												end
											end)
										end)
									end
								end
							end
							task.wait(0.1)
						until not PickupRange.Enabled
					end
				end,
				Tooltip = 'Picks up items from a farther distance'
			})
			Range = PickupRange:CreateSlider({
				Name = 'Range',
				Min = 1,
				Max = 10,
				Default = 10,
				Suffix = function(val) 
					return val == 1 and 'stud' or 'studs' 
				end
			})
			Network = PickupRange:CreateToggle({
				Name = 'Network TP',
				Default = true
			})
			Lower = PickupRange:CreateToggle({Name = 'Feet Check'})
		end)

		run(function()
			local RavenTP

			RavenTP = vape.Categories.Utility:CreateModule({
				Name = 'RavenTP',
				Function = function(callback)
					if callback then
						RavenTP:Toggle()
						local plr = entitylib.EntityMouse({
							Range = 1000,
							Players = true,
							Part = 'RootPart'
						})

						if getItem('raven') and plr then
							bedwars.Client:Get(remotes.SpawnRaven):CallServerAsync():andThen(function(projectile)
								if projectile then
									local bodyforce = Instance.new('BodyForce')
									bodyforce.Force = Vector3.new(0, projectile.PrimaryPart.AssemblyMass * workspace.Gravity, 0)
									bodyforce.Parent = projectile.PrimaryPart

									if plr then
										task.spawn(function()
											for _ = 1, 20 do
												if plr.RootPart and projectile then
													projectile:SetPrimaryPartCFrame(CFrame.lookAlong(plr.RootPart.Position, gameCamera.CFrame.LookVector))
												end
												task.wait(0.05)
											end
										end)
										task.wait(0.3)
										bedwars.RavenController:detonateRaven()
									end
								end
							end)
						end
					end
				end,
				Tooltip = 'Spawns and teleports a raven to a player\nnear your mouse.'
			})
		end)

		run(function()
			local Scaffold
			local Expand
			local Tower
			local Downwards
			local Diagonal
			local LimitItem
			local Mouse
			local adjacent, lastpos, label = {}, Vector3.zero

			for x = -3, 3, 3 do
				for y = -3, 3, 3 do
					for z = -3, 3, 3 do
						local vec = Vector3.new(x, y, z)
						if vec ~= Vector3.zero then
							table.insert(adjacent, vec)
						end
					end
				end
			end

			local function nearCorner(poscheck, pos)
				local startpos = poscheck - Vector3.new(3, 3, 3)
				local endpos = poscheck + Vector3.new(3, 3, 3)
				local check = poscheck + (pos - poscheck).Unit * 100
				return Vector3.new(math.clamp(check.X, startpos.X, endpos.X), math.clamp(check.Y, startpos.Y, endpos.Y), math.clamp(check.Z, startpos.Z, endpos.Z))
			end

			local function blockProximity(pos)
				local mag, returned = 60
				local tab = getBlocksInPoints(bedwars.BlockController:getBlockPosition(pos - Vector3.new(21, 21, 21)), bedwars.BlockController:getBlockPosition(pos + Vector3.new(21, 21, 21)))
				for _, v in tab do
					local blockpos = nearCorner(v, pos)
					local newmag = (pos - blockpos).Magnitude
					if newmag < mag then
						mag, returned = newmag, blockpos
					end
				end
				table.clear(tab)
				return returned
			end

			local function checkAdjacent(pos)
				for _, v in adjacent do
					if getPlacedBlock(pos + v) then
						return true
					end
				end
				return false
			end

			local function getScaffoldBlock()
				if store.hand.toolType == 'block' then
					return store.hand.tool.Name, store.hand.amount
				elseif (not LimitItem.Enabled) then
					local wool, amount = getWool()
					if wool then
						return wool, amount
					else
						for _, item in store.inventory.inventory.items do
							if bedwars.ItemMeta[item.itemType].block then
								return item.itemType, item.amount
							end
						end
					end
				end

				return nil, 0
			end

			Scaffold = vape.Categories.Utility:CreateModule({
				Name = 'Scaffold',
				Function = function(callback)
					if label then
						label.Visible = callback
					end

					if callback then
						repeat
							if entitylib.isAlive then
								local wool, amount = getScaffoldBlock()

								if Mouse.Enabled then
									if not inputService:IsMouseButtonPressed(0) then
										wool = nil
									end
								end

								if label then
									amount = amount or 0
									label.Text = amount..' <font color="rgb(170, 170, 170)">(Scaffold)</font>'
									label.TextColor3 = Color3.fromHSV((amount / 128) / 2.8, 0.86, 1)
								end

								if wool then
									local root = entitylib.character.RootPart
									if Tower.Enabled and inputService:IsKeyDown(Enum.KeyCode.Space) and (not inputService:GetFocusedTextBox()) then
										root.Velocity = Vector3.new(root.Velocity.X, 38, root.Velocity.Z)
									end

									for i = Expand.Value, 1, -1 do
										local currentpos = roundPos(root.Position - Vector3.new(0, entitylib.character.HipHeight + (Downwards.Enabled and inputService:IsKeyDown(Enum.KeyCode.LeftShift) and 4.5 or 1.5), 0) + entitylib.character.Humanoid.MoveDirection * (i * 3))
										if Diagonal.Enabled then
											if math.abs(math.round(math.deg(math.atan2(-entitylib.character.Humanoid.MoveDirection.X, -entitylib.character.Humanoid.MoveDirection.Z)) / 45) * 45) % 90 == 45 then
												local dt = (lastpos - currentpos)
												if ((dt.X == 0 and dt.Z ~= 0) or (dt.X ~= 0 and dt.Z == 0)) and ((lastpos - root.Position) * Vector3.new(1, 0, 1)).Magnitude < 2.5 then
													currentpos = lastpos
												end
											end
										end

										local block, blockpos = getPlacedBlock(currentpos)
										if not block then
											blockpos = checkAdjacent(blockpos * 3) and blockpos * 3 or blockProximity(currentpos)
											if blockpos then
												task.spawn(bedwars.placeBlock, blockpos, wool, false)
											end
										end
										lastpos = currentpos
									end
								end
							end

							task.wait(0.03)
						until not Scaffold.Enabled
					else
						Label = nil
					end
				end,
				Tooltip = 'Helps you make bridges/scaffold walk.'
			})
			Expand = Scaffold:CreateSlider({
				Name = 'Expand',
				Min = 1,
				Max = 6
			})
			Tower = Scaffold:CreateToggle({
				Name = 'Tower',
				Default = true
			})
			Downwards = Scaffold:CreateToggle({
				Name = 'Downwards',
				Default = true
			})
			Diagonal = Scaffold:CreateToggle({
				Name = 'Diagonal',
				Default = true
			})
			LimitItem = Scaffold:CreateToggle({Name = 'Limit to items'})
			Mouse = Scaffold:CreateToggle({Name = 'Require mouse down'})
			Count = Scaffold:CreateToggle({
				Name = 'Block Count',
				Function = function(callback)
					if callback then
						label = Instance.new('TextLabel')
						label.Size = UDim2.fromOffset(100, 20)
						label.Position = UDim2.new(0.5, 6, 0.5, 60)
						label.BackgroundTransparency = 1
						label.AnchorPoint = Vector2.new(0.5, 0)
						label.Text = '0'
						label.TextColor3 = Color3.new(0, 1, 0)
						label.TextSize = 18
						label.RichText = true
						label.Font = Enum.Font.Arial
						label.Visible = Scaffold.Enabled
						label.Parent = vape.gui
					else
						label:Destroy()
						label = nil
					end
				end
			})
		end)

		run(function()
			local ShopTierBypass
			local tiered, nexttier = {}, {}

			ShopTierBypass = vape.Categories.Utility:CreateModule({
				Name = 'ShopTierBypass',
				Function = function(callback)
					if callback then
						repeat task.wait() until store.shopLoaded or not ShopTierBypass.Enabled
						if ShopTierBypass.Enabled then
							for _, v in bedwars.Shop.ShopItems do
								tiered[v] = v.tiered
								nexttier[v] = v.nextTier
								v.nextTier = nil
								v.tiered = nil
							end
						end
					else
						for i, v in tiered do
							i.tiered = v
						end
						for i, v in nexttier do
							i.nextTier = v
						end
						table.clear(nexttier)
						table.clear(tiered)
					end
				end,
				Tooltip = 'Lets you buy things like armor early.'
			})
		end)

		run(function()
			local StaffDetector
			local Mode
			local Clans
			local Party
			local Profile
			local Users
			local blacklistedclans = {'gg', 'gg2', 'DV', 'DV2'}
			local blacklisteduserids = {1502104539, 3826146717, 4531785383, 1049767300, 4926350670, 653085195, 184655415, 2752307430, 5087196317, 5744061325, 1536265275}
			local joined = {}

			local function getRole(plr, id)
				local suc, res = pcall(function()
					return plr:GetRankInGroup(id)
				end)
				if not suc then
					notif('StaffDetector', res, 30, 'alert')
				end
				return suc and res or 0
			end

			local function staffFunction(plr, checktype)
				if not vape.Loaded then
					repeat task.wait() until vape.Loaded
				end

				notif('StaffDetector', 'Staff Detected ('..checktype..'): '..plr.Name..' ('..plr.UserId..')', 60, 'alert')
				whitelist.customtags[plr.Name] = {{text = 'GAME STAFF', color = Color3.new(1, 0, 0)}}

				if Party.Enabled and not checktype:find('clan') then
					bedwars.PartyController:leaveParty()
				end

				if Mode.Value == 'Uninject' then
					task.spawn(function()
						vape:Uninject()
					end)
					game:GetService('StarterGui'):SetCore('SendNotification', {
						Title = 'StaffDetector',
						Text = 'Staff Detected ('..checktype..')\n'..plr.Name..' ('..plr.UserId..')',
						Duration = 60,
					})
				elseif Mode.Value == 'Requeue' then
					bedwars.QueueController:joinQueue(store.queueType)
				elseif Mode.Value == 'Profile' then
					vape.Save = function() end
					if vape.Profile ~= Profile.Value then
						vape:Load(true, Profile.Value)
					end
				elseif Mode.Value == 'AutoConfig' then
					local safe = {'AutoClicker', 'Reach', 'Sprint', 'HitFix', 'StaffDetector'}
					vape.Save = function() end
					for i, v in vape.Modules do
						if not (table.find(safe, i) or v.Category == 'Render') then
							if v.Enabled then
								v:Toggle()
							end
							v:SetBind('')
						end
					end
				end
			end

			local function checkFriends(list)
				for _, v in list do
					if joined[v] then
						return joined[v]
					end
				end
				return nil
			end

			local function checkJoin(plr, connection)
				if not plr:GetAttribute('Team') and plr:GetAttribute('Spectator') and not bedwars.Store:getState().Game.customMatch then
					connection:Disconnect()
					local tab, pages = {}, playersService:GetFriendsAsync(plr.UserId)
					for _ = 1, 4 do
						for _, v in pages:GetCurrentPage() do
							table.insert(tab, v.Id)
						end
						if pages.IsFinished then break end
						pages:AdvanceToNextPageAsync()
					end

					local friend = checkFriends(tab)
					if not friend then
						staffFunction(plr, 'impossible_join')
						return true
					else
						notif('StaffDetector', string.format('Spectator %s joined from %s', plr.Name, friend), 20, 'warning')
					end
				end
			end

			local function playerAdded(plr)
				joined[plr.UserId] = plr.Name
				if plr == lplr then return end

				if table.find(blacklisteduserids, plr.UserId) or table.find(Users.ListEnabled, tostring(plr.UserId)) then
					staffFunction(plr, 'blacklisted_user')
				elseif getRole(plr, 5774246) >= 100 then
					staffFunction(plr, 'staff_role')
				else
					local connection
					connection = plr:GetAttributeChangedSignal('Spectator'):Connect(function()
						checkJoin(plr, connection)
					end)
					StaffDetector:Clean(connection)
					if checkJoin(plr, connection) then
						return
					end

					if not plr:GetAttribute('ClanTag') then
						plr:GetAttributeChangedSignal('ClanTag'):Wait()
					end

					if table.find(blacklistedclans, plr:GetAttribute('ClanTag')) and vape.Loaded and Clans.Enabled then
						connection:Disconnect()
						staffFunction(plr, 'blacklisted_clan_'..plr:GetAttribute('ClanTag'):lower())
					end
				end
			end

			StaffDetector = vape.Categories.Utility:CreateModule({
				Name = 'StaffDetector',
				Function = function(callback)
					if callback then
						StaffDetector:Clean(playersService.PlayerAdded:Connect(playerAdded))
						for _, v in playersService:GetPlayers() do
							task.spawn(playerAdded, v)
						end
					else
						table.clear(joined)
					end
				end,
				Tooltip = 'Detects people with a staff rank ingame'
			})
			Mode = StaffDetector:CreateDropdown({
				Name = 'Mode',
				List = {'Uninject', 'Profile', 'Requeue', 'AutoConfig', 'Notify'},
				Function = function(val)
					if Profile.Object then
						Profile.Object.Visible = val == 'Profile'
					end
				end
			})
			Clans = StaffDetector:CreateToggle({
				Name = 'Blacklist clans',
				Default = true
			})
			Party = StaffDetector:CreateToggle({
				Name = 'Leave party'
			})
			Profile = StaffDetector:CreateTextBox({
				Name = 'Profile',
				Default = 'default',
				Darker = true,
				Visible = false
			})
			Users = StaffDetector:CreateTextList({
				Name = 'Users',
				Placeholder = 'player (userid)'
			})

			task.spawn(function()
				repeat task.wait(1) until vape.Loaded or vape.Loaded == nil
				if vape.Loaded and not StaffDetector.Enabled then
					StaffDetector:Toggle()
				end
			end)
		end)

		run(function()
			TrapDisabler = vape.Categories.Utility:CreateModule({
				Name = 'TrapDisabler',
				Tooltip = 'Disables Snap Traps'
			})
		end)

		run(function()
			vape.Categories.World:CreateModule({
				Name = 'Anti-AFK',
				Function = function(callback)
					if callback then
						for _, v in getconnections(lplr.Idled) do
							v:Disconnect()
						end

						for _, v in getconnections(runService.Heartbeat) do
							if type(v.Function) == 'function' and table.find(debug.getconstants(v.Function), remotes.AfkStatus) then
								v:Disconnect()
							end
						end

						bedwars.Client:Get(remotes.AfkStatus):SendToServer({
							afk = false
						})
					end
				end,
				Tooltip = 'Lets you stay ingame without getting kicked'
			})
		end)

		run(function()
			local AutoSuffocate
			local Range
			local LimitItem

			local function fixPosition(pos)
				return bedwars.BlockController:getBlockPosition(pos) * 3
			end

			AutoSuffocate = vape.Categories.World:CreateModule({
				Name = 'AutoSuffocate',
				Function = function(callback)
					if callback then
						repeat
							local item = store.hand.toolType == 'block' and store.hand.tool.Name or not LimitItem.Enabled and getWool()

							if item then
								local plrs = entitylib.AllPosition({
									Part = 'RootPart',
									Range = Range.Value,
									Players = true
								})

								for _, ent in plrs do
									local needPlaced = {}

									for _, side in Enum.NormalId:GetEnumItems() do
										side = Vector3.fromNormalId(side)
										if side.Y ~= 0 then continue end

										side = fixPosition(ent.RootPart.Position + side * 2)
										if not getPlacedBlock(side) then
											table.insert(needPlaced, side)
										end
									end

									if #needPlaced < 3 then
										table.insert(needPlaced, fixPosition(ent.Head.Position))
										table.insert(needPlaced, fixPosition(ent.RootPart.Position - Vector3.new(0, 1, 0)))

										for _, pos in needPlaced do
											if not getPlacedBlock(pos) then
												task.spawn(bedwars.placeBlock, pos, item)
												break
											end
										end
									end
								end
							end

							task.wait(0.09)
						until not AutoSuffocate.Enabled
					end
				end,
				Tooltip = 'Places blocks on nearby confined entities'
			})
			Range = AutoSuffocate:CreateSlider({
				Name = 'Range',
				Min = 1,
				Max = 20,
				Default = 20,
				Suffix = function(val)
					return val == 1 and 'stud' or 'studs'
				end
			})
			LimitItem = AutoSuffocate:CreateToggle({
				Name = 'Limit to Items',
				Default = true
			})
		end)

		run(function()
			local AutoTool
			local old, event

			local function switchHotbarItem(block)
				if block and not block:GetAttribute('NoBreak') and not block:GetAttribute('Team'..(lplr:GetAttribute('Team') or 0)..'NoBreak') then
					local tool, slot = store.tools[bedwars.ItemMeta[block.Name].block.breakType], nil
					if tool then
						for i, v in store.inventory.hotbar do
							if v.item and v.item.itemType == tool.itemType then slot = i - 1 break end
						end

						if hotbarSwitch(slot) then
							if inputService:IsMouseButtonPressed(0) then 
								event:Fire() 
							end
							return true
						end
					end
				end
			end

			AutoTool = vape.Categories.World:CreateModule({
				Name = 'AutoTool',
				Function = function(callback)
					if callback then
						event = Instance.new('BindableEvent')
						AutoTool:Clean(event)
						AutoTool:Clean(event.Event:Connect(function()
							contextActionService:CallFunction('block-break', Enum.UserInputState.Begin, newproxy(true))
						end))
						old = bedwars.BlockBreaker.hitBlock
						bedwars.BlockBreaker.hitBlock = function(self, maid, raycastparams, ...)
							local block = self.clientManager:getBlockSelector():getMouseInfo(1, {ray = raycastparams})
							if switchHotbarItem(block and block.target and block.target.blockInstance or nil) then return end
							return old(self, maid, raycastparams, ...)
						end
					else
						bedwars.BlockBreaker.hitBlock = old
						old = nil
					end
				end,
				Tooltip = 'Automatically selects the correct tool'
			})
		end)

		run(function()
			local BedProtector

			local function getBedNear()
				local localPosition = entitylib.isAlive and entitylib.character.RootPart.Position or Vector3.zero
				for _, v in collectionService:GetTagged('bed') do
					if (localPosition - v.Position).Magnitude < 20 and v:GetAttribute('Team'..(lplr:GetAttribute('Team') or -1)..'NoBreak') then
						return v
					end
				end
			end

			local function getBlocks()
				local blocks = {}
				for _, item in store.inventory.inventory.items do
					local block = bedwars.ItemMeta[item.itemType].block
					if block then
						table.insert(blocks, {item.itemType, block.health})
					end
				end
				table.sort(blocks, function(a, b) 
					return a[2] > b[2]
				end)
				return blocks
			end

			local function getPyramid(size, grid)
				local positions = {}
				for h = size, 0, -1 do
					for w = h, 0, -1 do
						table.insert(positions, Vector3.new(w, (size - h), ((h + 1) - w)) * grid)
						table.insert(positions, Vector3.new(w * -1, (size - h), ((h + 1) - w)) * grid)
						table.insert(positions, Vector3.new(w, (size - h), (h - w) * -1) * grid)
						table.insert(positions, Vector3.new(w * -1, (size - h), (h - w) * -1) * grid)
					end
				end
				return positions
			end

			BedProtector = vape.Categories.World:CreateModule({
				Name = 'BedProtector',
				Function = function(callback)
					if callback then
						local bed = getBedNear()
						bed = bed and bed.Position or nil
						if bed then
							for i, block in getBlocks() do
								for _, pos in getPyramid(i, 3) do
									if not BedProtector.Enabled then break end
									if getPlacedBlock(bed + pos) then continue end
									bedwars.placeBlock(bed + pos, block[1], false)
								end
							end
							if BedProtector.Enabled then 
								BedProtector:Toggle() 
							end
						else
							notif('BedProtector', 'Unable to locate bed', 5)
							BedProtector:Toggle()
						end
					end
				end,
				Tooltip = 'Automatically places strong blocks around the bed.'
			})
		end)

		run(function()
			local ChestSteal
			local Range
			local Open
			local Skywars
			local Delays = {}

			local function lootChest(chest)
				chest = chest and chest.Value or nil
				local chestitems = chest and chest:GetChildren() or {}
				if #chestitems > 1 and (Delays[chest] or 0) < tick() then
					Delays[chest] = tick() + 0.2
					bedwars.Client:GetNamespace('Inventory'):Get('SetObservedChest'):SendToServer(chest)

					for _, v in chestitems do
						if v:IsA('Accessory') then
							task.spawn(function()
								pcall(function()
									bedwars.Client:GetNamespace('Inventory'):Get('ChestGetItem'):CallServer(chest, v)
								end)
							end)
						end
					end

					bedwars.Client:GetNamespace('Inventory'):Get('SetObservedChest'):SendToServer(nil)
				end
			end

			ChestSteal = vape.Categories.World:CreateModule({
				Name = 'ChestSteal',
				Function = function(callback)
					if callback then
						local chests = collection('chest', ChestSteal)
						repeat task.wait() until store.queueType ~= 'bedwars_test'
						if (not Skywars.Enabled) or store.queueType:find('skywars') then
							repeat
								if entitylib.isAlive and store.matchState ~= 2 then
									if Open.Enabled then
										if bedwars.AppController:isAppOpen('ChestApp') then
											lootChest(lplr.Character:FindFirstChild('ObservedChestFolder'))
										end
									else
										local localPosition = entitylib.character.RootPart.Position
										for _, v in chests do
											if (localPosition - v.Position).Magnitude <= Range.Value then
												lootChest(v:FindFirstChild('ChestFolderValue'))
											end
										end
									end
								end
								task.wait(0.1)
							until not ChestSteal.Enabled
						end
					end
				end,
				Tooltip = 'Grabs items from near chests.'
			})
			Range = ChestSteal:CreateSlider({
				Name = 'Range',
				Min = 0,
				Max = 18,
				Default = 18,
				Suffix = function(val)
					return val == 1 and 'stud' or 'studs'
				end
			})
			Open = ChestSteal:CreateToggle({Name = 'GUI Check'})
			Skywars = ChestSteal:CreateToggle({
				Name = 'Only Skywars',
				Function = function()
					if ChestSteal.Enabled then
						ChestSteal:Toggle()
						ChestSteal:Toggle()
					end
				end,
				Default = true
			})
		end)

		run(function()
			local Schematica
			local File
			local Mode
			local Transparency
			local parts, guidata, poschecklist = {}, {}, {}
			local point1, point2

			for x = -3, 3, 3 do
				for y = -3, 3, 3 do
					for z = -3, 3, 3 do
						if Vector3.new(x, y, z) ~= Vector3.zero then
							table.insert(poschecklist, Vector3.new(x, y, z))
						end
					end
				end
			end

			local function checkAdjacent(pos)
				for _, v in poschecklist do
					if getPlacedBlock(pos + v) then return true end
				end
				return false
			end

			local function getPlacedBlocksInPoints(s, e)
				local list, blocks = {}, bedwars.BlockController:getStore()
				for x = (e.X > s.X and s.X or e.X), (e.X > s.X and e.X or s.X) do
					for y = (e.Y > s.Y and s.Y or e.Y), (e.Y > s.Y and e.Y or s.Y) do
						for z = (e.Z > s.Z and s.Z or e.Z), (e.Z > s.Z and e.Z or s.Z) do
							local vec = Vector3.new(x, y, z)
							local block = blocks:getBlockAt(vec)
							if block and block:GetAttribute('PlacedByUserId') == lplr.UserId then
								list[vec] = block
							end
						end
					end
				end
				return list
			end

			local function loadMaterials()
				for _, v in guidata do 
					v:Destroy() 
				end
				local suc, read = pcall(function() 
					return isfile(File.Value) and httpService:JSONDecode(readfile(File.Value)) 
				end)

				if suc and read then
					local items = {}
					for _, v in read do 
						items[v[2]] = (items[v[2]] or 0) + 1 
					end

					for i, v in items do
						local holder = Instance.new('Frame')
						holder.Size = UDim2.new(1, 0, 0, 32)
						holder.BackgroundTransparency = 1
						holder.Parent = Schematica.Children
						local icon = Instance.new('ImageLabel')
						icon.Size = UDim2.fromOffset(24, 24)
						icon.Position = UDim2.fromOffset(4, 4)
						icon.BackgroundTransparency = 1
						icon.Image = bedwars.getIcon({itemType = i}, true)
						icon.Parent = holder
						local text = Instance.new('TextLabel')
						text.Size = UDim2.fromOffset(100, 32)
						text.Position = UDim2.fromOffset(32, 0)
						text.BackgroundTransparency = 1
						text.Text = (bedwars.ItemMeta[i] and bedwars.ItemMeta[i].displayName or i)..': '..v
						text.TextXAlignment = Enum.TextXAlignment.Left
						text.TextColor3 = uipallet.Text
						text.TextSize = 14
						text.FontFace = uipallet.Font
						text.Parent = holder
						table.insert(guidata, holder)
					end
					table.clear(read)
					table.clear(items)
				end
			end

			local function save()
				if point1 and point2 then
					local tab = getPlacedBlocksInPoints(point1, point2)
					local savetab = {}
					point1 = point1 * 3
					for i, v in tab do
						i = bedwars.BlockController:getBlockPosition(CFrame.lookAlong(point1, entitylib.character.RootPart.CFrame.LookVector):PointToObjectSpace(i * 3)) * 3
						table.insert(savetab, {
							{
								x = i.X, 
								y = i.Y, 
								z = i.Z
							}, 
							v.Name
						})
					end
					point1, point2 = nil, nil
					writefile(File.Value, httpService:JSONEncode(savetab))
					notif('Schematica', 'Saved '..getTableSize(tab)..' blocks', 5)
					loadMaterials()
					table.clear(tab)
					table.clear(savetab)
				else
					local mouseinfo = bedwars.BlockBreaker.clientManager:getBlockSelector():getMouseInfo(0)
					if mouseinfo and mouseinfo.target then
						if point1 then
							point2 = mouseinfo.target.blockRef.blockPosition
							notif('Schematica', 'Selected position 2, toggle again near position 1 to save it', 3)
						else
							point1 = mouseinfo.target.blockRef.blockPosition
							notif('Schematica', 'Selected position 1', 3)
						end
					end
				end
			end

			local function load(read)
				local mouseinfo = bedwars.BlockBreaker.clientManager:getBlockSelector():getMouseInfo(0)
				if mouseinfo and mouseinfo.target then
					local position = CFrame.new(mouseinfo.placementPosition * 3) * CFrame.Angles(0, math.rad(math.round(math.deg(math.atan2(-entitylib.character.RootPart.CFrame.LookVector.X, -entitylib.character.RootPart.CFrame.LookVector.Z)) / 45) * 45), 0)

					for _, v in read do
						local blockpos = bedwars.BlockController:getBlockPosition((position * CFrame.new(v[1].x, v[1].y, v[1].z)).p) * 3
						if parts[blockpos] then continue end
						local handler = bedwars.BlockController:getHandlerRegistry():getHandler(v[2]:find('wool') and getWool() or v[2])
						if handler then
							local part = handler:place(blockpos / 3, 0)
							part.Transparency = Transparency.Value
							part.CanCollide = false
							part.Anchored = true
							part.Parent = workspace
							parts[blockpos] = part
						end
					end
					table.clear(read)

					repeat
						if entitylib.isAlive then
							local localPosition = entitylib.character.RootPart.Position
							for i, v in parts do
								if (i - localPosition).Magnitude < 60 and checkAdjacent(i) then
									if not Schematica.Enabled then break end
									if not getItem(v.Name) then continue end
									bedwars.placeBlock(i, v.Name, false)
									task.delay(0.1, function()
										local block = getPlacedBlock(i)
										if block then
											v:Destroy()
											parts[i] = nil
										end
									end)
								end
							end
						end
						task.wait()
					until getTableSize(parts) <= 0

					if getTableSize(parts) <= 0 and Schematica.Enabled then
						notif('Schematica', 'Finished building', 5)
						Schematica:Toggle()
					end
				end
			end

			Schematica = vape.Categories.World:CreateModule({
				Name = 'Schematica',
				Function = function(callback)
					if callback then
						if not File.Value:find('.json') then
							notif('Schematica', 'Invalid file', 3)
							Schematica:Toggle()
							return
						end

						if Mode.Value == 'Save' then
							save()
							Schematica:Toggle()
						else
							local suc, read = pcall(function() 
								return isfile(File.Value) and httpService:JSONDecode(readfile(File.Value)) 
							end)

							if suc and read then
								load(read)
							else
								notif('Schematica', 'Missing / corrupted file', 3)
								Schematica:Toggle()
							end
						end
					else
						for _, v in parts do 
							v:Destroy() 
						end
						table.clear(parts)
					end
				end,
				Tooltip = 'Save and load placements of buildings'
			})
			File = Schematica:CreateTextBox({
				Name = 'File',
				Function = function()
					loadMaterials()
					point1, point2 = nil, nil
				end
			})
			Mode = Schematica:CreateDropdown({
				Name = 'Mode',
				List = {'Load', 'Save'}
			})
			Transparency = Schematica:CreateSlider({
				Name = 'Transparency',
				Min = 0,
				Max = 1,
				Default = 0.7,
				Decimal = 10,
				Function = function(val)
					for _, v in parts do 
						v.Transparency = val 
					end
				end
			})
		end)

		run(function()
			local ArmorSwitch
			local Mode
			local Targets
			local Range

			ArmorSwitch = vape.Categories.Inventory:CreateModule({
				Name = 'ArmorSwitch',
				Function = function(callback)
					if callback then
						if Mode.Value == 'Toggle' then
							repeat
								local state = entitylib.EntityPosition({
									Part = 'RootPart',
									Range = Range.Value,
									Players = Targets.Players.Enabled,
									NPCs = Targets.NPCs.Enabled,
									Wallcheck = Targets.Walls.Enabled
								}) and true or false

								for i = 0, 2 do
									if (store.inventory.inventory.armor[i + 1] ~= 'empty') ~= state and ArmorSwitch.Enabled then
										bedwars.Store:dispatch({
											type = 'InventorySetArmorItem',
											item = store.inventory.inventory.armor[i + 1] == 'empty' and state and getBestArmor(i) or nil,
											armorSlot = i
										})
										vapeEvents.InventoryChanged.Event:Wait()
									end
								end
								task.wait(0.1)
							until not ArmorSwitch.Enabled
						else
							ArmorSwitch:Toggle()
							for i = 0, 2 do
								bedwars.Store:dispatch({
									type = 'InventorySetArmorItem',
									item = store.inventory.inventory.armor[i + 1] == 'empty' and getBestArmor(i) or nil,
									armorSlot = i
								})
								vapeEvents.InventoryChanged.Event:Wait()
							end
						end
					end
				end,
				Tooltip = 'Puts on / takes off armor when toggled for baiting.'
			})
			Mode = ArmorSwitch:CreateDropdown({
				Name = 'Mode',
				List = {'Toggle', 'On Key'}
			})
			Targets = ArmorSwitch:CreateTargets({
				Players = true,
				NPCs = true
			})
			Range = ArmorSwitch:CreateSlider({
				Name = 'Range',
				Min = 1,
				Max = 30,
				Default = 30,
				Suffix = function(val)
					return val == 1 and 'stud' or 'studs'
				end
			})
		end)

		run(function()
			local AutoBank
			local UIToggle
			local UI
			local Chests
			local Items = {}

			local function addItem(itemType, shop)
				local item = Instance.new('ImageLabel')
				item.Image = bedwars.getIcon({itemType = itemType}, true)
				item.Size = UDim2.fromOffset(32, 32)
				item.Name = itemType
				item.BackgroundTransparency = 1
				item.LayoutOrder = #UI:GetChildren()
				item.Parent = UI
				local itemtext = Instance.new('TextLabel')
				itemtext.Name = 'Amount'
				itemtext.Size = UDim2.fromScale(1, 1)
				itemtext.BackgroundTransparency = 1
				itemtext.Text = ''
				itemtext.TextColor3 = Color3.new(1, 1, 1)
				itemtext.TextSize = 16
				itemtext.TextStrokeTransparency = 0.3
				itemtext.Font = Enum.Font.Arial
				itemtext.Parent = item
				Items[itemType] = {Object = itemtext, Type = shop}
			end

			local function refreshBank(echest)
				for i, v in Items do
					local item = echest:FindFirstChild(i)
					v.Object.Text = item and item:GetAttribute('Amount') or ''
				end
			end

			local function nearChest()
				if entitylib.isAlive then
					local pos = entitylib.character.RootPart.Position
					for _, chest in Chests do
						if (chest.Position - pos).Magnitude < 20 then
							return true
						end
					end
				end
			end

			local function handleState()
				local chest = replicatedStorage.Inventories:FindFirstChild(lplr.Name..'_personal')
				if not chest then return end

				local mapCF = workspace.MapCFrames:FindFirstChild((lplr:GetAttribute('Team') or 1)..'_spawn')
				if mapCF and (entitylib.character.RootPart.Position - mapCF.Value.Position).Magnitude < 80 then
					for _, v in chest:GetChildren() do
						local item = Items[v.Name]
						if item then
							task.spawn(function()
								bedwars.Client:GetNamespace('Inventory'):Get('ChestGetItem'):CallServer(chest, v)
								refreshBank(chest)
							end)
						end
					end
				else
					for _, v in store.inventory.inventory.items do
						local item = Items[v.itemType]
						if item then
							task.spawn(function()
								bedwars.Client:GetNamespace('Inventory'):Get('ChestGiveItem'):CallServer(chest, v.tool)
								refreshBank(chest)
							end)
						end
					end
				end
			end

			AutoBank = vape.Categories.Inventory:CreateModule({
				Name = 'AutoBank',
				Function = function(callback)
					if callback then
						Chests = collection('personal-chest', AutoBank)
						UI = Instance.new('Frame')
						UI.Size = UDim2.new(1, 0, 0, 32)
						UI.Position = UDim2.fromOffset(0, -240)
						UI.BackgroundTransparency = 1
						UI.Visible = UIToggle.Enabled
						UI.Parent = vape.gui
						AutoBank:Clean(UI)
						local Sort = Instance.new('UIListLayout')
						Sort.FillDirection = Enum.FillDirection.Horizontal
						Sort.HorizontalAlignment = Enum.HorizontalAlignment.Center
						Sort.SortOrder = Enum.SortOrder.LayoutOrder
						Sort.Parent = UI
						addItem('iron', true)
						addItem('gold', true)
						addItem('diamond', false)
						addItem('emerald', true)
						addItem('void_crystal', true)

						repeat
							local hotbar = lplr.PlayerGui:FindFirstChild('hotbar')
							hotbar = hotbar and hotbar['1']:FindFirstChild('HotbarHealthbarContainer')
							if hotbar then
								UI.Position = UDim2.fromOffset(0, (hotbar.AbsolutePosition.Y + guiService:GetGuiInset().Y) - 40)
							end

							local newState = nearChest()
							if newState then
								handleState()
							end

							task.wait(0.1)
						until (not AutoBank.Enabled)
					else
						table.clear(Items)
					end
				end,
				Tooltip = 'Automatically puts resources in ender chest'
			})
			UIToggle = AutoBank:CreateToggle({
				Name = 'UI',
				Function = function(callback)
					if AutoBank.Enabled then
						UI.Visible = callback
					end
				end,
				Default = true
			})
		end)

		run(function()
			local AutoBuy
			local Sword
			local Armor
			local Upgrades
			local TierCheck
			local BedwarsCheck
			local GUI
			local SmartCheck
			local Custom = {}
			local CustomPost = {}
			local UpgradeToggles = {}
			local Functions, id = {}
			local Callbacks = {Custom, Functions, CustomPost}
			local npctick = tick()

			local swords = {
				'wood_sword',
				'stone_sword',
				'iron_sword',
				'diamond_sword',
				'emerald_sword'
			}

			local armors = {
				'none',
				'leather_chestplate',
				'iron_chestplate',
				'diamond_chestplate',
				'emerald_chestplate'
			}

			local axes = {
				'none',
				'wood_axe',
				'stone_axe',
				'iron_axe',
				'diamond_axe'
			}

			local pickaxes = {
				'none',
				'wood_pickaxe',
				'stone_pickaxe',
				'iron_pickaxe',
				'diamond_pickaxe'
			}

			local function getShopNPC()
				local shop, items, upgrades, newid = nil, false, false, nil
				if entitylib.isAlive then
					local localPosition = entitylib.character.RootPart.Position
					for _, v in store.shop do
						if (v.RootPart.Position - localPosition).Magnitude <= 20 then
							shop = v.Upgrades or v.Shop or nil
							upgrades = upgrades or v.Upgrades
							items = items or v.Shop
							newid = v.Shop and v.Id or newid
						end
					end
				end
				return shop, items, upgrades, newid
			end

			local function canBuy(item, currencytable, amount)
				amount = amount or 1
				if not currencytable[item.currency] then
					local currency = getItem(item.currency)
					currencytable[item.currency] = currency and currency.amount or 0
				end
				if item.ignoredByKit and table.find(item.ignoredByKit, store.equippedKit or '') then return false end
				if item.lockedByForge or item.disabled then return false end
				if item.require and item.require.teamUpgrade then
					if (bedwars.Store:getState().Bedwars.teamUpgrades[item.require.teamUpgrade.upgradeId] or -1) < item.require.teamUpgrade.lowestTierIndex then
						return false
					end
				end
				return currencytable[item.currency] >= (item.price * amount)
			end

			local function buyItem(item, currencytable)
				if not id then return end
				notif('AutoBuy', 'Bought '..bedwars.ItemMeta[item.itemType].displayName, 3)
				bedwars.Client:Get('BedwarsPurchaseItem'):CallServerAsync({
					shopItem = item,
					shopId = id
				}):andThen(function(suc)
					if suc then
						bedwars.SoundManager:playSound(bedwars.SoundList.BEDWARS_PURCHASE_ITEM)
						bedwars.Store:dispatch({
							type = 'BedwarsAddItemPurchased',
							itemType = item.itemType
						})
						bedwars.BedwarsShopController.alreadyPurchasedMap[item.itemType] = true
					end
				end)
				currencytable[item.currency] -= item.price
			end

			local function buyUpgrade(upgradeType, currencytable)
				if not Upgrades.Enabled then return end
				local upgrade = bedwars.TeamUpgradeMeta[upgradeType]
				local currentUpgrades = bedwars.Store:getState().Bedwars.teamUpgrades[lplr:GetAttribute('Team')] or {}
				local currentTier = (currentUpgrades[upgradeType] or 0) + 1
				local bought = false

				for i = currentTier, #upgrade.tiers do
					local tier = upgrade.tiers[i]
					if tier.availableOnlyInQueue and not table.find(tier.availableOnlyInQueue, store.queueType) then continue end

					if canBuy({currency = 'diamond', price = tier.cost}, currencytable) then
						notif('AutoBuy', 'Bought '..(upgrade.name == 'Armor' and 'Protection' or upgrade.name)..' '..i, 3)
						bedwars.Client:Get('RequestPurchaseTeamUpgrade'):CallServerAsync(upgradeType)
						currencytable.diamond -= tier.cost
						bought = true
					else
						break
					end
				end

				return bought
			end

			local function buyTool(tool, tools, currencytable)
				local bought, buyable = false
				tool = tool and table.find(tools, tool.itemType) and table.find(tools, tool.itemType) + 1 or math.huge

				for i = tool, #tools do
					local v = bedwars.Shop.getShopItem(tools[i], lplr)
					if canBuy(v, currencytable) then
						if SmartCheck.Enabled and bedwars.ItemMeta[tools[i]].breakBlock and i > 2 then
							if Armor.Enabled then
								local currentarmor = store.inventory.inventory.armor[2]
								currentarmor = currentarmor and currentarmor ~= 'empty' and currentarmor.itemType or 'none'
								if (table.find(armors, currentarmor) or 3) < 3 then break end
							end
							if Sword.Enabled then
								if store.tools.sword and (table.find(swords, store.tools.sword.itemType) or 2) < 2 then break end
							end
						end
						bought = true
						buyable = v
					end
					if TierCheck.Enabled and v.nextTier then break end
				end

				if buyable then
					buyItem(buyable, currencytable)
				end

				return bought
			end

			AutoBuy = vape.Categories.Inventory:CreateModule({
				Name = 'AutoBuy',
				Function = function(callback)
					if callback then
						repeat task.wait() until store.queueType ~= 'bedwars_test'
						if BedwarsCheck.Enabled and not store.queueType:find('bedwars') then return end

						local lastupgrades
						AutoBuy:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(function()
							if (npctick - tick()) > 1 then npctick = tick() end
						end))

						repeat
							local npc, shop, upgrades, newid = getShopNPC()
							id = newid
							if GUI.Enabled then
								if not (bedwars.AppController:isAppOpen('BedwarsItemShopApp') or bedwars.AppController:isAppOpen('TeamUpgradeApp')) then
									npc = nil
								end
							end

							if npc and lastupgrades ~= upgrades then
								if (npctick - tick()) > 1 then npctick = tick() end
								lastupgrades = upgrades
							end

							if npc and npctick <= tick() and store.matchState ~= 2 and store.shopLoaded then
								local currencytable = {}
								local waitcheck
								for _, tab in Callbacks do
									for _, callback in tab do
										if callback(currencytable, shop, upgrades) then
											waitcheck = true
										end
									end
								end
								npctick = tick() + (waitcheck and 0.4 or math.huge)
							end

							task.wait(0.1)
						until not AutoBuy.Enabled
					else
						npctick = tick()
					end
				end,
				Tooltip = 'Automatically buys items when you go near the shop'
			})
			Sword = AutoBuy:CreateToggle({
				Name = 'Buy Sword',
				Function = function(callback)
					npctick = tick()
					Functions[2] = callback and function(currencytable, shop)
						if not shop then return end

						if store.equippedKit == 'dasher' then
							swords = {
								[1] = 'wood_dao',
								[2] = 'stone_dao',
								[3] = 'iron_dao',
								[4] = 'diamond_dao',
								[5] = 'emerald_dao'
							}
						elseif store.equippedKit == 'ice_queen' then
							swords[5] = 'ice_sword'
						elseif store.equippedKit == 'ember' then
							swords[5] = 'infernal_saber'
						elseif store.equippedKit == 'lumen' then
							swords[5] = 'light_sword'
						end

						return buyTool(store.tools.sword, swords, currencytable)
					end or nil
				end
			})
			Armor = AutoBuy:CreateToggle({
				Name = 'Buy Armor',
				Function = function(callback)
					npctick = tick()
					Functions[1] = callback and function(currencytable, shop)
						if not shop then return end
						local currentarmor = store.inventory.inventory.armor[2] ~= 'empty' and store.inventory.inventory.armor[2] or getBestArmor(1)
						currentarmor = currentarmor and currentarmor.itemType or 'none'
						return buyTool({itemType = currentarmor}, armors, currencytable)
					end or nil
				end,
				Default = true
			})
			AutoBuy:CreateToggle({
				Name = 'Buy Axe',
				Function = function(callback)
					npctick = tick()
					Functions[3] = callback and function(currencytable, shop)
						if not shop then return end
						return buyTool(store.tools.wood or {itemType = 'none'}, axes, currencytable)
					end or nil
				end
			})
			AutoBuy:CreateToggle({
				Name = 'Buy Pickaxe',
				Function = function(callback)
					npctick = tick()
					Functions[4] = callback and function(currencytable, shop)
						if not shop then return end
						return buyTool(store.tools.stone, pickaxes, currencytable)
					end or nil
				end
			})
			Upgrades = AutoBuy:CreateToggle({
				Name = 'Buy Upgrades',
				Function = function(callback)
					for _, v in UpgradeToggles do
						v.Object.Visible = callback
					end
				end,
				Default = true
			})
			local count = 0
			for i, v in bedwars.TeamUpgradeMeta do
				local toggleCount = count
				table.insert(UpgradeToggles, AutoBuy:CreateToggle({
					Name = 'Buy '..(v.name == 'Armor' and 'Protection' or v.name),
					Function = function(callback)
						npctick = tick()
						Functions[5 + toggleCount + (v.name == 'Armor' and 20 or 0)] = callback and function(currencytable, shop, upgrades)
							if not upgrades then return end
							if v.disabledInQueue and table.find(v.disabledInQueue, store.queueType) then return end
							return buyUpgrade(i, currencytable)
						end or nil
					end,
					Darker = true,
					Default = (i == 'ARMOR' or i == 'DAMAGE')
				}))
				count += 1
			end
			TierCheck = AutoBuy:CreateToggle({Name = 'Tier Check'})
			BedwarsCheck = AutoBuy:CreateToggle({
				Name = 'Only Bedwars',
				Function = function()
					if AutoBuy.Enabled then
						AutoBuy:Toggle()
						AutoBuy:Toggle()
					end
				end,
				Default = true
			})
			GUI = AutoBuy:CreateToggle({Name = 'GUI check'})
			SmartCheck = AutoBuy:CreateToggle({
				Name = 'Smart check',
				Default = true,
				Tooltip = 'Buys iron armor before iron axe'
			})
			AutoBuy:CreateTextList({
				Name = 'Item',
				Placeholder = 'priority/item/amount/after',
				Function = function(list)
					table.clear(Custom)
					table.clear(CustomPost)
					for _, entry in list do
						local tab = entry:split('/')
						local ind = tonumber(tab[1])
						if ind then
							(tab[4] and CustomPost or Custom)[ind] = function(currencytable, shop)
								if not shop then return end

								local v = bedwars.Shop.getShopItem(tab[2], lplr)
								if v then
									local item = getItem(tab[2] == 'wool_white' and bedwars.Shop.getTeamWool(lplr:GetAttribute('Team')) or tab[2])
									item = (item and tonumber(tab[3]) - item.amount or tonumber(tab[3])) // v.amount
									if item > 0 and canBuy(v, currencytable, item) then
										for _ = 1, item do
											buyItem(v, currencytable)
										end
										return true
									end
								end
							end
						end
					end
				end
			})
		end)

		run(function()
			local AutoConsume
			local Health
			local SpeedPotion
			local Apple
			local ShieldPotion

			local function consumeCheck(attribute)
				if entitylib.isAlive then
					if SpeedPotion.Enabled and (not attribute or attribute == 'StatusEffect_speed') then
						local speedpotion = getItem('speed_potion')
						if speedpotion and (not lplr.Character:GetAttribute('StatusEffect_speed')) then
							for _ = 1, 4 do
								if bedwars.Client:Get(remotes.ConsumeItem):CallServer({item = speedpotion.tool}) then break end
							end
						end
					end

					if Apple.Enabled and (not attribute or attribute:find('Health')) then
						if (lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) <= (Health.Value / 100) then
							local apple = getItem('orange') or (not lplr.Character:GetAttribute('StatusEffect_golden_apple') and getItem('golden_apple')) or getItem('apple')

							if apple then
								bedwars.Client:Get(remotes.ConsumeItem):CallServerAsync({
									item = apple.tool
								})
							end
						end
					end

					if ShieldPotion.Enabled and (not attribute or attribute:find('Shield')) then
						if (lplr.Character:GetAttribute('Shield_POTION') or 0) == 0 then
							local shield = getItem('big_shield') or getItem('mini_shield')

							if shield then
								bedwars.Client:Get(remotes.ConsumeItem):CallServerAsync({
									item = shield.tool
								})
							end
						end
					end
				end
			end

			AutoConsume = vape.Categories.Inventory:CreateModule({
				Name = 'AutoConsume',
				Function = function(callback)
					if callback then
						AutoConsume:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(consumeCheck))
						AutoConsume:Clean(vapeEvents.AttributeChanged.Event:Connect(function(attribute)
							if attribute:find('Shield') or attribute:find('Health') or attribute == 'StatusEffect_speed' then
								consumeCheck(attribute)
							end
						end))
						consumeCheck()
					end
				end,
				Tooltip = 'Automatically heals for you when health or shield is under threshold.'
			})
			Health = AutoConsume:CreateSlider({
				Name = 'Health Percent',
				Min = 1,
				Max = 99,
				Default = 70,
				Suffix = '%'
			})
			SpeedPotion = AutoConsume:CreateToggle({
				Name = 'Speed Potions',
				Default = true
			})
			Apple = AutoConsume:CreateToggle({
				Name = 'Apple',
				Default = true
			})
			ShieldPotion = AutoConsume:CreateToggle({
				Name = 'Shield Potions',
				Default = true
			})
		end)

		run(function()
			local AutoHotbar
			local Mode
			local Clear
			local List
			local Active

			local function CreateWindow(self)
				local selectedslot = 1
				local window = Instance.new('Frame')
				window.Name = 'HotbarGUI'
				window.Size = UDim2.fromOffset(660, 465)
				window.Position = UDim2.fromScale(0.5, 0.5)
				window.BackgroundColor3 = uipallet.Main
				window.AnchorPoint = Vector2.new(0.5, 0.5)
				window.Visible = false
				window.Parent = vape.gui.ScaledGui
				local title = Instance.new('TextLabel')
				title.Name = 'Title'
				title.Size = UDim2.new(1, -10, 0, 20)
				title.Position = UDim2.fromOffset(math.abs(title.Size.X.Offset), 12)
				title.BackgroundTransparency = 1
				title.Text = 'AutoHotbar'
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.TextColor3 = uipallet.Text
				title.TextSize = 13
				title.FontFace = uipallet.Font
				title.Parent = window
				local divider = Instance.new('Frame')
				divider.Name = 'Divider'
				divider.Size = UDim2.new(1, 0, 0, 1)
				divider.Position = UDim2.fromOffset(0, 40)
				divider.BackgroundColor3 = color.Light(uipallet.Main, 0.04)
				divider.BorderSizePixel = 0
				divider.Parent = window
				addBlur(window)
				local modal = Instance.new('TextButton')
				modal.Text = ''
				modal.BackgroundTransparency = 1
				modal.Modal = true
				modal.Parent = window
				local corner = Instance.new('UICorner')
				corner.CornerRadius = UDim.new(0, 5)
				corner.Parent = window
				local close = Instance.new('ImageButton')
				close.Name = 'Close'
				close.Size = UDim2.fromOffset(24, 24)
				close.Position = UDim2.new(1, -35, 0, 9)
				close.BackgroundColor3 = Color3.new(1, 1, 1)
				close.BackgroundTransparency = 1
				close.Image = 'rbxassetid://14368309446'
				close.ImageColor3 = color.Light(uipallet.Text, 0.2)
				close.ImageTransparency = 0.5
				close.AutoButtonColor = false
				close.Parent = window
				close.MouseEnter:Connect(function()
					close.ImageTransparency = 0.3
					tween:Tween(close, TweenInfo.new(0.2), {
						BackgroundTransparency = 0.6
					})
				end)
				close.MouseLeave:Connect(function()
					close.ImageTransparency = 0.5
					tween:Tween(close, TweenInfo.new(0.2), {
						BackgroundTransparency = 1
					})
				end)
				close.MouseButton1Click:Connect(function()
					window.Visible = false
					vape.gui.ScaledGui.ClickGui.Visible = true
				end)
				local closecorner = Instance.new('UICorner')
				closecorner.CornerRadius = UDim.new(1, 0)
				closecorner.Parent = close
				local bigslot = Instance.new('Frame')
				bigslot.Size = UDim2.fromOffset(110, 111)
				bigslot.Position = UDim2.fromOffset(11, 71)
				bigslot.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
				bigslot.Parent = window
				local bigslotcorner = Instance.new('UICorner')
				bigslotcorner.CornerRadius = UDim.new(0, 4)
				bigslotcorner.Parent = bigslot
				local bigslotstroke = Instance.new('UIStroke')
				bigslotstroke.Color = color.Light(uipallet.Main, 0.034)
				bigslotstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				bigslotstroke.Parent = bigslot
				local slotnum = Instance.new('TextLabel')
				slotnum.Size = UDim2.fromOffset(80, 20)
				slotnum.Position = UDim2.fromOffset(25, 200)
				slotnum.BackgroundTransparency = 1
				slotnum.Text = 'SLOT 1'
				slotnum.TextColor3 = color.Dark(uipallet.Text, 0.1)
				slotnum.TextSize = 12
				slotnum.FontFace = uipallet.Font
				slotnum.Parent = window
				for i = 1, 9 do
					local slotbkg = Instance.new('TextButton')
					slotbkg.Name = 'Slot'..i
					slotbkg.Size = UDim2.fromOffset(51, 52)
					slotbkg.Position = UDim2.fromOffset(89 + (i * 55), 382)
					slotbkg.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
					slotbkg.Text = ''
					slotbkg.AutoButtonColor = false
					slotbkg.Parent = window
					local slotimage = Instance.new('ImageLabel')
					slotimage.Size = UDim2.fromOffset(32, 32)
					slotimage.Position = UDim2.new(0.5, -16, 0.5, -16)
					slotimage.BackgroundTransparency = 1
					slotimage.Image = ''
					slotimage.Parent = slotbkg
					local slotcorner = Instance.new('UICorner')
					slotcorner.CornerRadius = UDim.new(0, 4)
					slotcorner.Parent = slotbkg
					local slotstroke = Instance.new('UIStroke')
					slotstroke.Color = color.Light(uipallet.Main, 0.04)
					slotstroke.Thickness = 2
					slotstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
					slotstroke.Enabled = i == selectedslot
					slotstroke.Parent = slotbkg
					slotbkg.MouseEnter:Connect(function()
						slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
					end)
					slotbkg.MouseLeave:Connect(function()
						slotbkg.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
					end)
					slotbkg.MouseButton1Click:Connect(function()
						window['Slot'..selectedslot].UIStroke.Enabled = false
						selectedslot = i
						slotstroke.Enabled = true
						slotnum.Text = 'SLOT '..selectedslot
					end)
					slotbkg.MouseButton2Click:Connect(function()
						local obj = self.Hotbars[self.Selected]
						if obj then
							window['Slot'..i].ImageLabel.Image = ''
							obj.Hotbar[tostring(i)] = nil
							obj.Object['Slot'..i].Image = '	'
						end
					end)
				end
				local searchbkg = Instance.new('Frame')
				searchbkg.Size = UDim2.fromOffset(496, 31)
				searchbkg.Position = UDim2.fromOffset(142, 80)
				searchbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
				searchbkg.Parent = window
				local search = Instance.new('TextBox')
				search.Size = UDim2.new(1, -10, 0, 31)
				search.Position = UDim2.fromOffset(10, 0)
				search.BackgroundTransparency = 1
				search.Text = ''
				search.PlaceholderText = ''
				search.TextXAlignment = Enum.TextXAlignment.Left
				search.TextColor3 = uipallet.Text
				search.TextSize = 12
				search.FontFace = uipallet.Font
				search.ClearTextOnFocus = false
				search.Parent = searchbkg
				local searchcorner = Instance.new('UICorner')
				searchcorner.CornerRadius = UDim.new(0, 4)
				searchcorner.Parent = searchbkg
				local searchicon = Instance.new('ImageLabel')
				searchicon.Size = UDim2.fromOffset(14, 14)
				searchicon.Position = UDim2.new(1, -26, 0, 8)
				searchicon.BackgroundTransparency = 1
				searchicon.Image = 'rbxassetid://14425646684'
				searchicon.ImageColor3 = color.Light(uipallet.Main, 0.37)
				searchicon.Parent = searchbkg
				local children = Instance.new('ScrollingFrame')
				children.Name = 'Children'
				children.Size = UDim2.fromOffset(500, 240)
				children.Position = UDim2.fromOffset(144, 122)
				children.BackgroundTransparency = 1
				children.BorderSizePixel = 0
				children.ScrollBarThickness = 2
				children.ScrollBarImageTransparency = 0.75
				children.CanvasSize = UDim2.new()
				children.Parent = window
				local windowlist = Instance.new('UIGridLayout')
				windowlist.SortOrder = Enum.SortOrder.LayoutOrder
				windowlist.FillDirectionMaxCells = 9
				windowlist.CellSize = UDim2.fromOffset(51, 52)
				windowlist.CellPadding = UDim2.fromOffset(4, 3)
				windowlist.Parent = children
				windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
					if vape.ThreadFix then
						setthreadidentity(8)
					end
					children.CanvasSize = UDim2.fromOffset(0, windowlist.AbsoluteContentSize.Y / vape.guiscale.Scale)
				end)
				table.insert(vape.Windows, window)

				local function createitem(id, image)
					local slotbkg = Instance.new('TextButton')
					slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
					slotbkg.Text = ''
					slotbkg.AutoButtonColor = false
					slotbkg.Parent = children
					local slotimage = Instance.new('ImageLabel')
					slotimage.Size = UDim2.fromOffset(32, 32)
					slotimage.Position = UDim2.new(0.5, -16, 0.5, -16)
					slotimage.BackgroundTransparency = 1
					slotimage.Image = image
					slotimage.Parent = slotbkg
					local slotcorner = Instance.new('UICorner')
					slotcorner.CornerRadius = UDim.new(0, 4)
					slotcorner.Parent = slotbkg
					slotbkg.MouseEnter:Connect(function()
						slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.04)
					end)
					slotbkg.MouseLeave:Connect(function()
						slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
					end)
					slotbkg.MouseButton1Click:Connect(function()
						local obj = self.Hotbars[self.Selected]
						if obj then
							window['Slot'..selectedslot].ImageLabel.Image = image
							obj.Hotbar[tostring(selectedslot)] = id
							obj.Object['Slot'..selectedslot].Image = image
						end
					end)
				end

				local function indexSearch(text)
					for _, v in children:GetChildren() do
						if v:IsA('TextButton') then
							v:ClearAllChildren()
							v:Destroy()
						end
					end

					if text == '' then
						for _, v in {'diamond_sword', 'diamond_pickaxe', 'diamond_axe', 'shears', 'wood_bow', 'wool_white', 'fireball', 'apple', 'iron', 'gold', 'diamond', 'emerald'} do
							createitem(v, bedwars.ItemMeta[v].image)
						end
						return
					end

					for i, v in bedwars.ItemMeta do
						if text:lower() == i:lower():sub(1, text:len()) then
							if not v.image then continue end
							createitem(i, v.image)
						end
					end
				end

				search:GetPropertyChangedSignal('Text'):Connect(function()
					indexSearch(search.Text)
				end)
				indexSearch('')

				return window
			end

			vape.Components.HotbarList = function(optionsettings, children, api)
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				local optionapi = {
					Type = 'HotbarList',
					Hotbars = {},
					Selected = 1
				}
				local hotbarlist = Instance.new('TextButton')
				hotbarlist.Name = 'HotbarList'
				hotbarlist.Size = UDim2.fromOffset(220, 40)
				hotbarlist.BackgroundColor3 = optionsettings.Darker and (children.BackgroundColor3 == color.Dark(uipallet.Main, 0.02) and color.Dark(uipallet.Main, 0.04) or color.Dark(uipallet.Main, 0.02)) or children.BackgroundColor3
				hotbarlist.Text = ''
				hotbarlist.BorderSizePixel = 0
				hotbarlist.AutoButtonColor = false
				hotbarlist.Parent = children
				local textbkg = Instance.new('Frame')
				textbkg.Name = 'BKG'
				textbkg.Size = UDim2.new(1, -20, 0, 31)
				textbkg.Position = UDim2.fromOffset(10, 4)
				textbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
				textbkg.Parent = hotbarlist
				local textbkgcorner = Instance.new('UICorner')
				textbkgcorner.CornerRadius = UDim.new(0, 4)
				textbkgcorner.Parent = textbkg
				local textbutton = Instance.new('TextButton')
				textbutton.Name = 'HotbarList'
				textbutton.Size = UDim2.new(1, -2, 1, -2)
				textbutton.Position = UDim2.fromOffset(1, 1)
				textbutton.BackgroundColor3 = uipallet.Main
				textbutton.Text = ''
				textbutton.AutoButtonColor = false
				textbutton.Parent = textbkg
				textbutton.MouseEnter:Connect(function()
					tween:Tween(textbkg, TweenInfo.new(0.2), {
						BackgroundColor3 = color.Light(uipallet.Main, 0.14)
					})
				end)
				textbutton.MouseLeave:Connect(function()
					tween:Tween(textbkg, TweenInfo.new(0.2), {
						BackgroundColor3 = color.Light(uipallet.Main, 0.034)
					})
				end)
				local textbuttoncorner = Instance.new('UICorner')
				textbuttoncorner.CornerRadius = UDim.new(0, 4)
				textbuttoncorner.Parent = textbutton
				local textbuttonicon = Instance.new('ImageLabel')
				textbuttonicon.Size = UDim2.fromOffset(12, 12)
				textbuttonicon.Position = UDim2.fromScale(0.5, 0.5)
				textbuttonicon.AnchorPoint = Vector2.new(0.5, 0.5)
				textbuttonicon.BackgroundTransparency = 1
				textbuttonicon.Image = "rbxassetid://14368300605"
				textbuttonicon.ImageColor3 = Color3.fromHSV(0.46, 0.96, 0.52)
				textbuttonicon.Parent = textbutton
				local childrenlist = Instance.new('Frame')
				childrenlist.Size = UDim2.new(1, 0, 1, -40)
				childrenlist.Position = UDim2.fromOffset(0, 40)
				childrenlist.BackgroundTransparency = 1
				childrenlist.Parent = hotbarlist
				local windowlist = Instance.new('UIListLayout')
				windowlist.SortOrder = Enum.SortOrder.LayoutOrder
				windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
				windowlist.Padding = UDim.new(0, 3)
				windowlist.Parent = childrenlist
				windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
					if vape.ThreadFix then
						setthreadidentity(8)
					end
					hotbarlist.Size = UDim2.fromOffset(220, math.min(43 + windowlist.AbsoluteContentSize.Y / vape.guiscale.Scale, 603))
				end)
				textbutton.MouseButton1Click:Connect(function()
					optionapi:AddHotbar()
				end)
				optionapi.Window = CreateWindow(optionapi)

				function optionapi:Save(savetab)
					local hotbars = {}
					for _, v in self.Hotbars do
						table.insert(hotbars, v.Hotbar)
					end
					savetab.HotbarList = {
						Selected = self.Selected,
						Hotbars = hotbars
					}
				end

				function optionapi:Load(savetab)
					for _, v in self.Hotbars do
						v.Object:ClearAllChildren()
						v.Object:Destroy()
						table.clear(v.Hotbar)
					end
					table.clear(self.Hotbars)
					for _, v in savetab.Hotbars do
						self:AddHotbar(v)
					end
					self.Selected = savetab.Selected or 1
				end

				function optionapi:AddHotbar(data)
					local hotbardata = {Hotbar = data or {}}
					table.insert(self.Hotbars, hotbardata)
					local hotbar = Instance.new('TextButton')
					hotbar.Size = UDim2.fromOffset(200, 27)
					hotbar.BackgroundColor3 = table.find(self.Hotbars, hotbardata) == self.Selected and color.Light(uipallet.Main, 0.034) or uipallet.Main
					hotbar.Text = ''
					hotbar.AutoButtonColor = false
					hotbar.Parent = childrenlist
					hotbardata.Object = hotbar
					local hotbarcorner = Instance.new('UICorner')
					hotbarcorner.CornerRadius = UDim.new(0, 4)
					hotbarcorner.Parent = hotbar
					for i = 1, 9 do
						local slot = Instance.new('ImageLabel')
						slot.Name = 'Slot'..i
						slot.Size = UDim2.fromOffset(17, 18)
						slot.Position = UDim2.fromOffset(-7 + (i * 18), 5)
						slot.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
						slot.Image = hotbardata.Hotbar[tostring(i)] and bedwars.getIcon({itemType = hotbardata.Hotbar[tostring(i)]}, true) or ''
						slot.BorderSizePixel = 0
						slot.Parent = hotbar
					end
					hotbar.MouseButton1Click:Connect(function()
						local ind = table.find(optionapi.Hotbars, hotbardata)
						if ind == optionapi.Selected then
							vape.gui.ScaledGui.ClickGui.Visible = false
							optionapi.Window.Visible = true
							for i = 1, 9 do
								optionapi.Window['Slot'..i].ImageLabel.Image = hotbardata.Hotbar[tostring(i)] and bedwars.getIcon({itemType = hotbardata.Hotbar[tostring(i)]}, true) or ''
							end
						else
							if optionapi.Hotbars[optionapi.Selected] then
								optionapi.Hotbars[optionapi.Selected].Object.BackgroundColor3 = uipallet.Main
							end
							hotbar.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
							optionapi.Selected = ind
						end
					end)
					local close = Instance.new('ImageButton')
					close.Name = 'Close'
					close.Size = UDim2.fromOffset(16, 16)
					close.Position = UDim2.new(1, -23, 0, 6)
					close.BackgroundColor3 = Color3.new(1, 1, 1)
					close.BackgroundTransparency = 1
					close.Image = 'rbxassetid://14368310467'
					close.ImageColor3 = color.Light(uipallet.Text, 0.2)
					close.ImageTransparency = 0.5
					close.AutoButtonColor = false
					close.Parent = hotbar
					local closecorner = Instance.new('UICorner')
					closecorner.CornerRadius = UDim.new(1, 0)
					closecorner.Parent = close
					close.MouseEnter:Connect(function()
						close.ImageTransparency = 0.3
						tween:Tween(close, TweenInfo.new(0.2), {
							BackgroundTransparency = 0.6
						})
					end)
					close.MouseLeave:Connect(function()
						close.ImageTransparency = 0.5
						tween:Tween(close, TweenInfo.new(0.2), {
							BackgroundTransparency = 1
						})
					end)
					close.MouseButton1Click:Connect(function()
						local ind = table.find(self.Hotbars, hotbardata)
						local obj = self.Hotbars[self.Selected]
						local obj2 = self.Hotbars[ind]
						if obj and obj2 then
							obj2.Object:ClearAllChildren()
							obj2.Object:Destroy()
							table.remove(self.Hotbars, ind)
							ind = table.find(self.Hotbars, obj)
							self.Selected = table.find(self.Hotbars, obj) or 1
						end
					end)
				end

				api.Options.HotbarList = optionapi

				return optionapi
			end

			local function getBlock()
				local clone = table.clone(store.inventory.inventory.items)
				table.sort(clone, function(a, b)
					return a.amount < b.amount
				end)

				for _, item in clone do
					local block = bedwars.ItemMeta[item.itemType].block
					if block and not block.seeThrough then
						return item
					end
				end
			end

			local function getCustomItem(v)
				if v == 'diamond_sword' then
					local sword = store.tools.sword
					v = sword and sword.itemType or 'wood_sword'
				elseif v == 'diamond_pickaxe' then
					local pickaxe = store.tools.stone
					v = pickaxe and pickaxe.itemType or 'wood_pickaxe'
				elseif v == 'diamond_axe' then
					local axe = store.tools.wood
					v = axe and axe.itemType or 'wood_axe'
				elseif v == 'wood_bow' then
					local bow = getBow()
					v = bow and bow.itemType or 'wood_bow'
				elseif v == 'wool_white' then
					local block = getBlock()
					v = block and block.itemType or 'wool_white'
				end

				return v
			end

			local function findItemInTable(tab, item)
				for slot, v in tab do
					if item.itemType == getCustomItem(v) then
						return tonumber(slot)
					end
				end
			end

			local function findInHotbar(item)
				for i, v in store.inventory.hotbar do
					if v.item and v.item.itemType == item.itemType then
						return i - 1, v.item
					end
				end
			end

			local function findInInventory(item)
				for _, v in store.inventory.inventory.items do
					if v.itemType == item.itemType then
						return v
					end
				end
			end

			local function dispatch(...)
				bedwars.Store:dispatch(...)
				vapeEvents.InventoryChanged.Event:Wait()
			end

			local function sortCallback()
				if Active then return end
				Active = true
				local items = (List.Hotbars[List.Selected] and List.Hotbars[List.Selected].Hotbar or {})

				for _, v in store.inventory.inventory.items do
					local slot = findItemInTable(items, v)
					if slot then
						local olditem = store.inventory.hotbar[slot]
						if olditem.item and olditem.item.itemType == v.itemType then continue end
						if olditem.item then
							dispatch({
								type = 'InventoryRemoveFromHotbar',
								slot = slot - 1
							})
						end

						local newslot = findInHotbar(v)
						if newslot then
							dispatch({
								type = 'InventoryRemoveFromHotbar',
								slot = newslot
							})
							if olditem.item then
								dispatch({
									type = 'InventoryAddToHotbar',
									item = findInInventory(olditem.item),
									slot = newslot
								})
							end
						end

						dispatch({
							type = 'InventoryAddToHotbar',
							item = findInInventory(v),
							slot = slot - 1
						})
					elseif Clear.Enabled then
						local newslot = findInHotbar(v)
						if newslot then
							dispatch({
								type = 'InventoryRemoveFromHotbar',
								slot = newslot
							})
						end
					end
				end

				Active = false
			end

			AutoHotbar = vape.Categories.Inventory:CreateModule({
				Name = 'AutoHotbar',
				Function = function(callback)
					if callback then
						task.spawn(sortCallback)
						if Mode.Value == 'On Key' then
							AutoHotbar:Toggle()
							return
						end

						AutoHotbar:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(sortCallback))
					end
				end,
				Tooltip = 'Automatically arranges hotbar to your liking.'
			})
			Mode = AutoHotbar:CreateDropdown({
				Name = 'Activation',
				List = {'Toggle', 'On Key'},
				Function = function()
					if AutoHotbar.Enabled then
						AutoHotbar:Toggle()
						AutoHotbar:Toggle()
					end
				end
			})
			Clear = AutoHotbar:CreateToggle({Name = 'Clear Hotbar'})
			List = AutoHotbar:CreateHotbarList({})
		end)

		run(function()
			local Value
			local oldclickhold, oldshowprogress

			local FastConsume = vape.Categories.Inventory:CreateModule({
				Name = 'FastConsume',
				Function = function(callback)
					if callback then
						oldclickhold = bedwars.ClickHold.startClick
						oldshowprogress = bedwars.ClickHold.showProgress
						bedwars.ClickHold.startClick = function(self)
							self.startedClickTime = tick()
							local handle = self:showProgress()
							local clicktime = self.startedClickTime
							bedwars.RuntimeLib.Promise.defer(function()
								task.wait(self.durationSeconds * (Value.Value / 40))
								if handle == self.handle and clicktime == self.startedClickTime and self.closeOnComplete then
									self:hideProgress()
									if self.onComplete then self.onComplete() end
									if self.onPartialComplete then self.onPartialComplete(1) end
									self.startedClickTime = -1
								end
							end)
						end

						bedwars.ClickHold.showProgress = function(self)
							local roact = debug.getupvalue(oldshowprogress, 1)
							local countdown = roact.mount(roact.createElement('ScreenGui', {}, { roact.createElement('Frame', {
								[roact.Ref] = self.wrapperRef,
								Size = UDim2.new(),
								Position = UDim2.fromScale(0.5, 0.55),
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundColor3 = Color3.fromRGB(0, 0, 0),
								BackgroundTransparency = 0.8
							}, { roact.createElement('Frame', {
									[roact.Ref] = self.progressRef,
									Size = UDim2.fromScale(0, 1),
									BackgroundColor3 = Color3.new(1, 1, 1),
									BackgroundTransparency = 0.5
								}) }) }), lplr:FindFirstChild('PlayerGui'))

							self.handle = countdown
							local sizetween = tweenService:Create(self.wrapperRef:getValue(), TweenInfo.new(0.1), {
								Size = UDim2.fromScale(0.11, 0.005)
							})
							local countdowntween = tweenService:Create(self.progressRef:getValue(), TweenInfo.new(self.durationSeconds * (Value.Value / 100), Enum.EasingStyle.Linear), {
								Size = UDim2.fromScale(1, 1)
							})

							sizetween:Play()
							countdowntween:Play()
							table.insert(self.tweens, countdowntween)
							table.insert(self.tweens, sizetween)

							return countdown
						end
					else
						bedwars.ClickHold.startClick = oldclickhold
						bedwars.ClickHold.showProgress = oldshowprogress
						oldclickhold = nil
						oldshowprogress = nil
					end
				end,
				Tooltip = 'Use/Consume items quicker.'
			})
			Value = FastConsume:CreateSlider({
				Name = 'Multiplier',
				Min = 0,
				Max = 100
			})
		end)

		run(function()
			local FastDrop

			FastDrop = vape.Categories.Inventory:CreateModule({
				Name = 'FastDrop',
				Function = function(callback)
					if callback then
						repeat
							if entitylib.isAlive and (not store.inventory.opened) and (inputService:IsKeyDown(Enum.KeyCode.H) or inputService:IsKeyDown(Enum.KeyCode.Backspace)) and inputService:GetFocusedTextBox() == nil then
								task.spawn(bedwars.ItemDropController.dropItemInHand)
								task.wait()
							else
								task.wait(0.1)
							end
						until not FastDrop.Enabled
					end
				end,
				Tooltip = 'Drops items fast when you hold Q'
			})
		end)

		run(function()
			local BedPlates
			local Background
			local Color = {}
			local Reference = {}
			local Folder = Instance.new('Folder')
			Folder.Parent = vape.gui

			local function scanSide(self, start, tab)
				for _, side in sides do
					for i = 1, 15 do
						local block = getPlacedBlock(start + (side * i))
						if not block or block == self then break end
						if not block:GetAttribute('NoBreak') and not table.find(tab, block.Name) then
							table.insert(tab, block.Name)
						end
					end
				end
			end

			local function refreshAdornee(v)
				for _, obj in v.Frame:GetChildren() do
					if obj:IsA('ImageLabel') and obj.Name ~= 'Blur' then
						obj:Destroy()
					end
				end

				local start = v.Adornee.Position
				local alreadygot = {}
				scanSide(v.Adornee, start, alreadygot)
				scanSide(v.Adornee, start + Vector3.new(0, 0, 3), alreadygot)
				table.sort(alreadygot, function(a, b)
					return (bedwars.ItemMeta[a].block and bedwars.ItemMeta[a].block.health or 0) > (bedwars.ItemMeta[b].block and bedwars.ItemMeta[b].block.health or 0)
				end)
				v.Enabled = #alreadygot > 0

				for _, block in alreadygot do
					local blockimage = Instance.new('ImageLabel')
					blockimage.Size = UDim2.fromOffset(32, 32)
					blockimage.BackgroundTransparency = 1
					blockimage.Image = bedwars.getIcon({itemType = block}, true)
					blockimage.Parent = v.Frame
				end
			end

			local function Added(v)
				local billboard = Instance.new('BillboardGui')
				billboard.Parent = Folder
				billboard.Name = 'bed'
				billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
				billboard.Size = UDim2.fromOffset(36, 36)
				billboard.AlwaysOnTop = true
				billboard.ClipsDescendants = false
				billboard.Adornee = v
				local blur = addBlur(billboard)
				blur.Visible = Background.Enabled
				local frame = Instance.new('Frame')
				frame.Size = UDim2.fromScale(1, 1)
				frame.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
				frame.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
				frame.Parent = billboard
				local layout = Instance.new('UIListLayout')
				layout.FillDirection = Enum.FillDirection.Horizontal
				layout.Padding = UDim.new(0, 4)
				layout.VerticalAlignment = Enum.VerticalAlignment.Center
				layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
				layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
					billboard.Size = UDim2.fromOffset(math.max(layout.AbsoluteContentSize.X + 4, 36), 36)
				end)
				layout.Parent = frame
				local corner = Instance.new('UICorner')
				corner.CornerRadius = UDim.new(0, 4)
				corner.Parent = frame
				Reference[v] = billboard
				refreshAdornee(billboard)
			end

			local function refreshNear(data)
				data = data.blockRef.blockPosition * 3
				for i, v in Reference do
					if (data - i.Position).Magnitude <= 30 then
						refreshAdornee(v)
					end
				end
			end

			BedPlates = vape.Categories.Minigames:CreateModule({
				Name = 'BedPlates',
				Function = function(callback)
					if callback then
						for _, v in collectionService:GetTagged('bed') do 
							task.spawn(Added, v) 
						end
						BedPlates:Clean(vapeEvents.PlaceBlockEvent.Event:Connect(refreshNear))
						BedPlates:Clean(vapeEvents.BreakBlockEvent.Event:Connect(refreshNear))
						BedPlates:Clean(collectionService:GetInstanceAddedSignal('bed'):Connect(Added))
						BedPlates:Clean(collectionService:GetInstanceRemovedSignal('bed'):Connect(function(v)
							if Reference[v] then
								Reference[v]:Destroy()
								Reference[v]:ClearAllChildren()
								Reference[v] = nil
							end
						end))
					else
						table.clear(Reference)
						Folder:ClearAllChildren()
					end
				end,
				Tooltip = 'Displays blocks over the bed'
			})
			Background = BedPlates:CreateToggle({
				Name = 'Background',
				Function = function(callback)
					if Color.Object then 
						Color.Object.Visible = callback 
					end
					for _, v in Reference do
						v.Frame.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
						v.Blur.Visible = callback
					end
				end,
				Default = true
			})
			Color = BedPlates:CreateColorSlider({
				Name = 'Background Color',
				DefaultValue = 0,
				DefaultOpacity = 0.5,
				Function = function(hue, sat, val, opacity)
					for _, v in Reference do
						v.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
						v.Frame.BackgroundTransparency = 1 - opacity
					end
				end,
				Darker = true
			})
		end)

		run(function()
			local Breaker
			local Range
			local BreakSpeed
			local UpdateRate
			local Custom
			local Bed
			local LuckyBlock
			local IronOre
			local Effect
			local CustomHealth = {}
			local Animation
			local SelfBreak
			local InstantBreak
			local LimitItem
			local customlist, parts = {}, {}

			local function customHealthbar(self, blockRef, health, maxHealth, changeHealth, block)
				if block:GetAttribute('NoHealthbar') then return end
				if not self.healthbarPart or not self.healthbarBlockRef or self.healthbarBlockRef.blockPosition ~= blockRef.blockPosition then
					self.healthbarMaid:DoCleaning()
					self.healthbarBlockRef = blockRef
					local create = bedwars.Roact.createElement
					local percent = math.clamp(health / maxHealth, 0, 1)
					local cleanCheck = true
					local part = Instance.new('Part')
					part.Size = Vector3.one
					part.CFrame = CFrame.new(bedwars.BlockController:getWorldPosition(blockRef.blockPosition))
					part.Transparency = 1
					part.Anchored = true
					part.CanCollide = false
					part.Parent = workspace
					self.healthbarPart = part
					bedwars.QueryUtil:setQueryIgnored(self.healthbarPart, true)

					local mounted = bedwars.Roact.mount(create('BillboardGui', {
						Size = UDim2.fromOffset(249, 102),
						StudsOffset = Vector3.new(0, 2.5, 0),
						Adornee = part,
						MaxDistance = 40,
						AlwaysOnTop = true
					}, {
						create('Frame', {
							Size = UDim2.fromOffset(160, 50),
							Position = UDim2.fromOffset(44, 32),
							BackgroundColor3 = Color3.new(),
							BackgroundTransparency = 0.5
						}, {
							create('UICorner', {CornerRadius = UDim.new(0, 5)}),
							create('ImageLabel', {
								Size = UDim2.new(1, 89, 1, 52),
								Position = UDim2.fromOffset(-48, -31),
								BackgroundTransparency = 1,
								Image = 'rbxassetid://14898786664',
								ScaleType = Enum.ScaleType.Slice,
								SliceCenter = Rect.new(52, 31, 261, 502)
							}),
							create('TextLabel', {
								Size = UDim2.fromOffset(145, 14),
								Position = UDim2.fromOffset(13, 12),
								BackgroundTransparency = 1,
								Text = bedwars.ItemMeta[block.Name].displayName or block.Name,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextYAlignment = Enum.TextYAlignment.Top,
								TextColor3 = Color3.new(),
								TextScaled = true,
								Font = Enum.Font.Arial
							}),
							create('TextLabel', {
								Size = UDim2.fromOffset(145, 14),
								Position = UDim2.fromOffset(12, 11),
								BackgroundTransparency = 1,
								Text = bedwars.ItemMeta[block.Name].displayName or block.Name,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextYAlignment = Enum.TextYAlignment.Top,
								TextColor3 = color.Dark(uipallet.Text, 0.16),
								TextScaled = true,
								Font = Enum.Font.Arial
							}),
							create('Frame', {
								Size = UDim2.fromOffset(138, 4),
								Position = UDim2.fromOffset(12, 32),
								BackgroundColor3 = uipallet.Main
							}, {
								create('UICorner', {CornerRadius = UDim.new(1, 0)}),
								create('Frame', {
									[bedwars.Roact.Ref] = self.healthbarProgressRef,
									Size = UDim2.fromScale(percent, 1),
									BackgroundColor3 = Color3.fromHSV(math.clamp(percent / 2.5, 0, 1), 0.89, 0.75)
								}, {create('UICorner', {CornerRadius = UDim.new(1, 0)})})
							})
						})
					}), part)

					self.healthbarMaid:GiveTask(function()
						cleanCheck = false
						self.healthbarBlockRef = nil
						bedwars.Roact.unmount(mounted)
						if self.healthbarPart then
							self.healthbarPart:Destroy()
						end
						self.healthbarPart = nil
					end)

					bedwars.RuntimeLib.Promise.delay(5):andThen(function()
						if cleanCheck then
							self.healthbarMaid:DoCleaning()
						end
					end)
				end

				local newpercent = math.clamp((health - changeHealth) / maxHealth, 0, 1)
				tweenService:Create(self.healthbarProgressRef:getValue(), TweenInfo.new(0.3), {
					Size = UDim2.fromScale(newpercent, 1), BackgroundColor3 = Color3.fromHSV(math.clamp(newpercent / 2.5, 0, 1), 0.89, 0.75)
				}):Play()
			end

			local hit = 0

			local function attemptBreak(tab, localPosition)
				if not tab then return end
				for _, v in tab do
					if (v.Position - localPosition).Magnitude < Range.Value and bedwars.BlockController:isBlockBreakable({blockPosition = v.Position / 3}, lplr) then
						if not SelfBreak.Enabled and v:GetAttribute('PlacedByUserId') == lplr.UserId then continue end
						if (v:GetAttribute('BedShieldEndTime') or 0) > workspace:GetServerTimeNow() then continue end
						if LimitItem.Enabled and not (store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name].breakBlock) then continue end

						hit += 1
						local target, path, endpos = bedwars.breakBlock(v, Effect.Enabled, Animation.Enabled, CustomHealth.Enabled and customHealthbar or nil, InstantBreak.Enabled)
						if path then
							local currentnode = target
							for _, part in parts do
								part.Position = currentnode or Vector3.zero
								if currentnode then
									part.BoxHandleAdornment.Color3 = currentnode == endpos and Color3.new(1, 0.2, 0.2) or currentnode == target and Color3.new(0.2, 0.2, 1) or Color3.new(0.2, 1, 0.2)
								end
								currentnode = path[currentnode]
							end
						end

						task.wait(InstantBreak.Enabled and (store.damageBlockFail > tick() and 4.5 or 0) or BreakSpeed.Value)

						return true
					end
				end

				return false
			end

			Breaker = vape.Categories.Minigames:CreateModule({
				Name = 'Breaker',
				Function = function(callback)
					if callback then
						for _ = 1, 30 do
							local part = Instance.new('Part')
							part.Anchored = true
							part.CanQuery = false
							part.CanCollide = false
							part.Transparency = 1
							part.Parent = gameCamera
							local highlight = Instance.new('BoxHandleAdornment')
							highlight.Size = Vector3.one
							highlight.AlwaysOnTop = true
							highlight.ZIndex = 1
							highlight.Transparency = 0.5
							highlight.Adornee = part
							highlight.Parent = part
							table.insert(parts, part)
						end

						local beds = collection('bed', Breaker)
						local luckyblock = collection('LuckyBlock', Breaker)
						local ironores = collection('iron-ore', Breaker)
						customlist = collection('block', Breaker, function(tab, obj)
							if table.find(Custom.ListEnabled, obj.Name) then
								table.insert(tab, obj)
							end
						end)

						repeat
							task.wait(1 / UpdateRate.Value)
							if not Breaker.Enabled then break end
							if entitylib.isAlive then
								local localPosition = entitylib.character.RootPart.Position

								if attemptBreak(Bed.Enabled and beds, localPosition) then continue end
								if attemptBreak(customlist, localPosition) then continue end
								if attemptBreak(LuckyBlock.Enabled and luckyblock, localPosition) then continue end
								if attemptBreak(IronOre.Enabled and ironores, localPosition) then continue end

								for _, v in parts do
									v.Position = Vector3.zero
								end
							end
						until not Breaker.Enabled
					else
						for _, v in parts do
							v:ClearAllChildren()
							v:Destroy()
						end
						table.clear(parts)
					end
				end,
				Tooltip = 'Break blocks around you automatically'
			})
			Range = Breaker:CreateSlider({
				Name = 'Break range',
				Min = 1,
				Max = 30,
				Default = 30,
				Suffix = function(val)
					return val == 1 and 'stud' or 'studs'
				end
			})
			BreakSpeed = Breaker:CreateSlider({
				Name = 'Break speed',
				Min = 0,
				Max = 0.3,
				Default = 0.25,
				Decimal = 100,
				Suffix = 'seconds'
			})
			UpdateRate = Breaker:CreateSlider({
				Name = 'Update rate',
				Min = 1,
				Max = 120,
				Default = 60,
				Suffix = 'hz'
			})
			Custom = Breaker:CreateTextList({
				Name = 'Custom',
				Function = function()
					if not customlist then return end
					table.clear(customlist)
					for _, obj in store.blocks do
						if table.find(Custom.ListEnabled, obj.Name) then
							table.insert(customlist, obj)
						end
					end
				end
			})
			Bed = Breaker:CreateToggle({
				Name = 'Break Bed',
				Default = true
			})
			LuckyBlock = Breaker:CreateToggle({
				Name = 'Break Lucky Block',
				Default = true
			})
			IronOre = Breaker:CreateToggle({
				Name = 'Break Iron Ore',
				Default = true
			})
			Effect = Breaker:CreateToggle({
				Name = 'Show Healthbar & Effects',
				Function = function(callback)
					if CustomHealth.Object then
						CustomHealth.Object.Visible = callback
					end
				end,
				Default = true
			})
			CustomHealth = Breaker:CreateToggle({
				Name = 'Custom Healthbar',
				Default = true,
				Darker = true
			})
			Animation = Breaker:CreateToggle({Name = 'Animation'})
			SelfBreak = Breaker:CreateToggle({Name = 'Self Break'})
			InstantBreak = Breaker:CreateToggle({Name = 'Instant Break'})
			LimitItem = Breaker:CreateToggle({
				Name = 'Limit to items',
				Tooltip = 'Only breaks when tools are held'
			})
		end)

		run(function()
			local BedBreakEffect
			local Mode
			local List
			local NameToId = {}

			BedBreakEffect = vape.Legit:CreateModule({
				Name = 'Bed Break Effect',
				Function = function(callback)
					if callback then
						BedBreakEffect:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(data)
							firesignal(bedwars.Client:Get('BedBreakEffectTriggered').instance.OnClientEvent, {
								player = data.player,
								position = data.bedBlockPosition * 3,
								effectType = NameToId[List.Value],
								teamId = data.brokenBedTeam.id,
								centerBedPosition = data.bedBlockPosition * 3
							})
						end))
					end
				end,
				Tooltip = 'Custom bed break effects'
			})
			local BreakEffectName = {}
			for i, v in bedwars.BedBreakEffectMeta do
				table.insert(BreakEffectName, v.name)
				NameToId[v.name] = i
			end
			table.sort(BreakEffectName)
			List = BedBreakEffect:CreateDropdown({
				Name = 'Effect',
				List = BreakEffectName
			})
		end)

		run(function()
			vape.Legit:CreateModule({
				Name = 'Clean Kit',
				Function = function(callback)
					if callback then
						bedwars.WindWalkerController.spawnOrb = function() end
						local zephyreffect = lplr.PlayerGui:FindFirstChild('WindWalkerEffect', true)
						if zephyreffect then 
							zephyreffect.Visible = false 
						end
					end
				end,
				Tooltip = 'Removes zephyr status indicator'
			})
		end)

		run(function()
			local old
			local Image

			local Crosshair = vape.Legit:CreateModule({
				Name = 'Crosshair',
				Function = function(callback)
					if callback then
						old = debug.getconstant(bedwars.ViewmodelController.showCrosshair, 25)
						debug.setconstant(bedwars.ViewmodelController.showCrosshair, 25, Image.Value)
						debug.setconstant(bedwars.ViewmodelController.showCrosshair, 37, Image.Value)
					else
						debug.setconstant(bedwars.ViewmodelController.showCrosshair, 25, old)
						debug.setconstant(bedwars.ViewmodelController.showCrosshair, 37, old)
						old = nil
					end

					if bedwars.ViewmodelController.crosshair then
						bedwars.ViewmodelController:hideCrosshair()
						bedwars.ViewmodelController:showCrosshair()
					end
				end,
				Tooltip = 'Custom first person crosshair depending on the image choosen.'
			})
			Image = Crosshair:CreateTextBox({
				Name = 'Image',
				Placeholder = 'image id (roblox)',
				Function = function(enter)
					if enter and Crosshair.Enabled then
						Crosshair:Toggle()
						Crosshair:Toggle()
					end
				end
			})
		end)

		run(function()
			local DamageIndicator
			local FontOption
			local Color
			local Size
			local Anchor
			local Stroke
			local suc, tab = pcall(function()
				return debug.getupvalue(bedwars.DamageIndicator, 2)
			end)
			tab = suc and tab or {}
			local oldvalues, oldfont = {}

			DamageIndicator = vape.Legit:CreateModule({
				Name = 'Damage Indicator',
				Function = function(callback)
					if callback then
						oldvalues = table.clone(tab)
						oldfont = debug.getconstant(bedwars.DamageIndicator, 86)
						debug.setconstant(bedwars.DamageIndicator, 86, Enum.Font[FontOption.Value])
						debug.setconstant(bedwars.DamageIndicator, 119, Stroke.Enabled and 'Thickness' or 'Enabled')
						tab.strokeThickness = Stroke.Enabled and 1 or false
						tab.textSize = Size.Value
						tab.blowUpSize = Size.Value
						tab.blowUpDuration = 0
						tab.baseColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
						tab.blowUpCompleteDuration = 0
						tab.anchoredDuration = Anchor.Value
					else
						for i, v in oldvalues do
							tab[i] = v
						end
						debug.setconstant(bedwars.DamageIndicator, 86, oldfont)
						debug.setconstant(bedwars.DamageIndicator, 119, 'Thickness')
					end
				end,
				Tooltip = 'Customize the damage indicator'
			})
			local fontitems = {'GothamBlack'}
			for _, v in Enum.Font:GetEnumItems() do
				if v.Name ~= 'GothamBlack' then
					table.insert(fontitems, v.Name)
				end
			end
			FontOption = DamageIndicator:CreateDropdown({
				Name = 'Font',
				List = fontitems,
				Function = function(val)
					if DamageIndicator.Enabled then
						debug.setconstant(bedwars.DamageIndicator, 86, Enum.Font[val])
					end
				end
			})
			Color = DamageIndicator:CreateColorSlider({
				Name = 'Color',
				DefaultHue = 0,
				Function = function(hue, sat, val)
					if DamageIndicator.Enabled then
						tab.baseColor = Color3.fromHSV(hue, sat, val)
					end
				end
			})
			Size = DamageIndicator:CreateSlider({
				Name = 'Size',
				Min = 1,
				Max = 32,
				Default = 32,
				Function = function(val)
					if DamageIndicator.Enabled then
						tab.textSize = val
						tab.blowUpSize = val
					end
				end
			})
			Anchor = DamageIndicator:CreateSlider({
				Name = 'Anchor',
				Min = 0,
				Max = 1,
				Decimal = 10,
				Function = function(val)
					if DamageIndicator.Enabled then
						tab.anchoredDuration = val
					end
				end
			})
			Stroke = DamageIndicator:CreateToggle({
				Name = 'Stroke',
				Function = function(callback)
					if DamageIndicator.Enabled then
						debug.setconstant(bedwars.DamageIndicator, 119, callback and 'Thickness' or 'Enabled')
						tab.strokeThickness = callback and 1 or false
					end
				end
			})
		end)

		run(function()
			local FOV
			local Value
			local old, old2

			FOV = vape.Legit:CreateModule({
				Name = 'FOV',
				Function = function(callback)
					if callback then
						old = bedwars.FovController.setFOV
						old2 = bedwars.FovController.getFOV
						bedwars.FovController.setFOV = function(self) 
							return old(self, Value.Value) 
						end
						bedwars.FovController.getFOV = function() 
							return Value.Value 
						end
					else
						bedwars.FovController.setFOV = old
						bedwars.FovController.getFOV = old2
					end

					bedwars.FovController:setFOV(bedwars.Store:getState().Settings.fov)
				end,
				Tooltip = 'Adjusts camera vision'
			})
			Value = FOV:CreateSlider({
				Name = 'FOV',
				Min = 30,
				Max = 120
			})
		end)

		run(function()
			local FPSBoost
			local Kill
			local Visualizer
			local effects, util = {}, {}

			FPSBoost = vape.Legit:CreateModule({
				Name = 'FPS Boost',
				Function = function(callback)
					if callback then
						if Kill.Enabled then
							for i, v in bedwars.KillEffectController.killEffects do
								if not i:find('Custom') then
									effects[i] = v
									bedwars.KillEffectController.killEffects[i] = {
										new = function() 
											return {
												onKill = function() end, 
												isPlayDefaultKillEffect = function() 
													return true 
												end
											} 
										end
									}
								end
							end
						end

						if Visualizer.Enabled then
							for i, v in bedwars.VisualizerUtils do
								util[i] = v
								bedwars.VisualizerUtils[i] = function() end
							end
						end

						repeat task.wait() until store.matchState ~= 0
						if not bedwars.AppController then return end
						bedwars.NametagController.addGameNametag = function() end
						for _, v in bedwars.AppController:getOpenApps() do
							if tostring(v):find('Nametag') then
								bedwars.AppController:closeApp(tostring(v))
							end
						end
					else
						for i, v in effects do 
							bedwars.KillEffectController.killEffects[i] = v 
						end
						for i, v in util do 
							bedwars.VisualizerUtils[i] = v 
						end
						table.clear(effects)
						table.clear(util)
					end
				end,
				Tooltip = 'Improves the framerate by turning off certain effects'
			})
			Kill = FPSBoost:CreateToggle({
				Name = 'Kill Effects',
				Function = function()
					if FPSBoost.Enabled then
						FPSBoost:Toggle()
						FPSBoost:Toggle()
					end
				end,
				Default = true
			})
			Visualizer = FPSBoost:CreateToggle({
				Name = 'Visualizer',
				Function = function()
					if FPSBoost.Enabled then
						FPSBoost:Toggle()
						FPSBoost:Toggle()
					end
				end,
				Default = true
			})
		end)

		run(function()
			local HitColor
			local Color
			local done = {}

			HitColor = vape.Legit:CreateModule({
				Name = 'Hit Color',
				Function = function(callback)
					if callback then 
						repeat
							for i, v in entitylib.List do 
								local highlight = v.Character and v.Character:FindFirstChild('_DamageHighlight_')
								if highlight then 
									if not table.find(done, highlight) then 
										table.insert(done, highlight) 
									end
									highlight.FillColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
									highlight.FillTransparency = Color.Opacity
								end
							end
							task.wait(0.1)
						until not HitColor.Enabled
					else
						for i, v in done do 
							v.FillColor = Color3.new(1, 0, 0)
							v.FillTransparency = 0.4
						end
						table.clear(done)
					end
				end,
				Tooltip = 'Customize the hit highlight options'
			})
			Color = HitColor:CreateColorSlider({
				Name = 'Color',
				DefaultOpacity = 0.4
			})
		end)

		run(function()
			vape.Legit:CreateModule({
				Name = 'HitFix',
				Function = function(callback)
					debug.setconstant(bedwars.SwordController.swingSwordAtMouse, 23, callback and 'raycast' or 'Raycast')
					debug.setupvalue(bedwars.SwordController.swingSwordAtMouse, 4, callback and bedwars.QueryUtil or workspace)
				end,
				Tooltip = 'Changes the raycast function to the correct one'
			})
		end)

		run(function()
			local Interface
			local HotbarOpenInventory = require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-open-inventory']).HotbarOpenInventory
			local HotbarHealthbar = require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui.healthbar['hotbar-healthbar']).HotbarHealthbar
			local HotbarApp = getRoactRender(require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-app']).HotbarApp.render)
			local old, new = {}, {}

			vape:Clean(function()
				for _, v in new do
					table.clear(v)
				end
				for _, v in old do
					table.clear(v)
				end
				table.clear(new)
				table.clear(old)
			end)

			local function modifyconstant(func, ind, val)
				if not func then return end
				if not old[func] then old[func] = {} end
				if not new[func] then new[func] = {} end
				if not old[func][ind] then
					old[func][ind] = debug.getconstant(func, ind)
				end
				if typeof(old[func][ind]) ~= typeof(val) then return end
				new[func][ind] = val

				if Interface.Enabled then
					if val then
						debug.setconstant(func, ind, val)
					else
						debug.setconstant(func, ind, old[func][ind])
						old[func][ind] = nil
					end
				end
			end

			Interface = vape.Legit:CreateModule({
				Name = 'Interface',
				Function = function(callback)
					for i, v in (callback and new or old) do
						for i2, v2 in v do
							debug.setconstant(i, i2, v2)
						end
					end
				end,
				Tooltip = 'Customize bedwars UI'
			})
			local fontitems = {'LuckiestGuy'}
			for _, v in Enum.Font:GetEnumItems() do
				if v.Name ~= 'LuckiestGuy' then
					table.insert(fontitems, v.Name)
				end
			end
			Interface:CreateDropdown({
				Name = 'Health Font',
				List = fontitems,
				Function = function(val)
					modifyconstant(HotbarHealthbar.render, 77, val)
				end
			})
			Interface:CreateColorSlider({
				Name = 'Health Color',
				Function = function(hue, sat, val)
					modifyconstant(HotbarHealthbar.render, 16, tonumber(Color3.fromHSV(hue, sat, val):ToHex(), 16))
					if Interface.Enabled then
						local hotbar = lplr.PlayerGui:FindFirstChild('hotbar')
						hotbar = hotbar and hotbar:FindFirstChild('HealthbarProgressWrapper', true)
						if hotbar then
							hotbar['1'].BackgroundColor3 = Color3.fromHSV(hue, sat, val)
						end
					end
				end
			})
			Interface:CreateColorSlider({
				Name = 'Hotbar Color',
				DefaultOpacity = 0.8,
				Function = function(hue, sat, val, opacity)
					local func = oldinvrender or HotbarOpenInventory.render
					modifyconstant(debug.getupvalue(HotbarApp, 23).render, 51, tonumber(Color3.fromHSV(hue, sat, val):ToHex(), 16))
					modifyconstant(debug.getupvalue(HotbarApp, 23).render, 58, tonumber(Color3.fromHSV(hue, sat, math.clamp(val > 0.5 and val - 0.2 or val + 0.2, 0, 1)):ToHex(), 16))
					modifyconstant(debug.getupvalue(HotbarApp, 23).render, 54, 1 - opacity)
					modifyconstant(debug.getupvalue(HotbarApp, 23).render, 55, math.clamp(1.2 - opacity, 0, 1))
					modifyconstant(func, 31, tonumber(Color3.fromHSV(hue, sat, val):ToHex(), 16))
					modifyconstant(func, 32, math.clamp(1.2 - opacity, 0, 1))
					modifyconstant(func, 34, tonumber(Color3.fromHSV(hue, sat, math.clamp(val > 0.5 and val - 0.2 or val + 0.2, 0, 1)):ToHex(), 16))
				end
			})
		end)

		run(function()
			local KillEffect
			local Mode
			local List
			local NameToId = {}

			local killeffects = {
				Gravity = function(_, _, char, _)
					char:BreakJoints()
					local highlight = char:FindFirstChildWhichIsA('Highlight')
					local nametag = char:FindFirstChild('Nametag', true)
					if highlight then
						highlight:Destroy()
					end
					if nametag then
						nametag:Destroy()
					end

					task.spawn(function()
						local partvelo = {}
						for _, v in char:GetDescendants() do
							if v:IsA('BasePart') then
								partvelo[v.Name] = v.Velocity
							end
						end
						char.Archivable = true
						local clone = char:Clone()
						clone.Humanoid.Health = 100
						clone.Parent = workspace
						game:GetService('Debris'):AddItem(clone, 30)
						char:Destroy()
						task.wait(0.01)
						clone.Humanoid:ChangeState(Enum.HumanoidStateType.Dead)
						clone:BreakJoints()
						task.wait(0.01)
						for _, v in clone:GetDescendants() do
							if v:IsA('BasePart') then
								local bodyforce = Instance.new('BodyForce')
								bodyforce.Force = Vector3.new(0, (workspace.Gravity - 10) * v:GetMass(), 0)
								bodyforce.Parent = v
								v.CanCollide = true
								v.Velocity = partvelo[v.Name] or Vector3.zero
							end
						end
					end)
				end,
				Lightning = function(_, _, char, _)
					char:BreakJoints()
					local highlight = char:FindFirstChildWhichIsA('Highlight')
					if highlight then
						highlight:Destroy()
					end
					local startpos = 1125
					local startcf = char.PrimaryPart.CFrame.p - Vector3.new(0, 8, 0)
					local newpos = Vector3.new((math.random(1, 10) - 5) * 2, startpos, (math.random(1, 10) - 5) * 2)

					for i = startpos - 75, 0, -75 do
						local newpos2 = Vector3.new((math.random(1, 10) - 5) * 2, i, (math.random(1, 10) - 5) * 2)
						if i == 0 then
							newpos2 = Vector3.zero
						end
						local part = Instance.new('Part')
						part.Size = Vector3.new(1.5, 1.5, 77)
						part.Material = Enum.Material.SmoothPlastic
						part.Anchored = true
						part.Material = Enum.Material.Neon
						part.CanCollide = false
						part.CFrame = CFrame.new(startcf + newpos + ((newpos2 - newpos) * 0.5), startcf + newpos2)
						part.Parent = workspace
						local part2 = part:Clone()
						part2.Size = Vector3.new(3, 3, 78)
						part2.Color = Color3.new(0.7, 0.7, 0.7)
						part2.Transparency = 0.7
						part2.Material = Enum.Material.SmoothPlastic
						part2.Parent = workspace
						game:GetService('Debris'):AddItem(part, 0.5)
						game:GetService('Debris'):AddItem(part2, 0.5)
						bedwars.QueryUtil:setQueryIgnored(part, true)
						bedwars.QueryUtil:setQueryIgnored(part2, true)
						if i == 0 then
							local soundpart = Instance.new('Part')
							soundpart.Transparency = 1
							soundpart.Anchored = true
							soundpart.Size = Vector3.zero
							soundpart.Position = startcf
							soundpart.Parent = workspace
							bedwars.QueryUtil:setQueryIgnored(soundpart, true)
							local sound = Instance.new('Sound')
							sound.SoundId = 'rbxassetid://6993372814'
							sound.Volume = 2
							sound.Pitch = 0.5 + (math.random(1, 3) / 10)
							sound.Parent = soundpart
							sound:Play()
							sound.Ended:Connect(function()
								soundpart:Destroy()
							end)
						end
						newpos = newpos2
					end
				end,
				Delete = function(_, _, char, _)
					char:Destroy()
				end
			}

			KillEffect = vape.Legit:CreateModule({
				Name = 'Kill Effect',
				Function = function(callback)
					if callback then
						for i, v in killeffects do
							bedwars.KillEffectController.killEffects['Custom'..i] = {
								new = function()
									return {
										onKill = v,
										isPlayDefaultKillEffect = function()
											return false
										end
									}
								end
							}
						end
						KillEffect:Clean(lplr:GetAttributeChangedSignal('KillEffectType'):Connect(function()
							lplr:SetAttribute('KillEffectType', Mode.Value == 'Bedwars' and NameToId[List.Value] or 'Custom'..Mode.Value)
						end))
						lplr:SetAttribute('KillEffectType', Mode.Value == 'Bedwars' and NameToId[List.Value] or 'Custom'..Mode.Value)
					else
						for i in killeffects do
							bedwars.KillEffectController.killEffects['Custom'..i] = nil
						end
						lplr:SetAttribute('KillEffectType', 'default')
					end
				end,
				Tooltip = 'Custom final kill effects'
			})
			local modes = {'Bedwars'}
			for i in killeffects do
				table.insert(modes, i)
			end
			Mode = KillEffect:CreateDropdown({
				Name = 'Mode',
				List = modes,
				Function = function(val)
					List.Object.Visible = val == 'Bedwars'
					if KillEffect.Enabled then
						lplr:SetAttribute('KillEffectType', val == 'Bedwars' and NameToId[List.Value] or 'Custom'..val)
					end
				end
			})
			local KillEffectName = {}
			for i, v in bedwars.KillEffectMeta do
				table.insert(KillEffectName, v.name)
				NameToId[v.name] = i
			end
			table.sort(KillEffectName)
			List = KillEffect:CreateDropdown({
				Name = 'Bedwars',
				List = KillEffectName,
				Function = function(val)
					if KillEffect.Enabled then
						lplr:SetAttribute('KillEffectType', NameToId[val])
					end
				end,
				Darker = true
			})
		end)

		run(function()
			local ReachDisplay
			local label

			ReachDisplay = vape.Legit:CreateModule({
				Name = 'Reach Display',
				Function = function(callback)
					if callback then
						repeat
							label.Text = (store.attackReachUpdate > tick() and store.attackReach or '0.00')..' studs'
							task.wait(0.4)
						until not ReachDisplay.Enabled
					end
				end,
				Size = UDim2.fromOffset(100, 41)
			})
			ReachDisplay:CreateFont({
				Name = 'Font',
				Blacklist = 'Gotham',
				Function = function(val)
					label.FontFace = val
				end
			})
			ReachDisplay:CreateColorSlider({
				Name = 'Color',
				DefaultValue = 0,
				DefaultOpacity = 0.5,
				Function = function(hue, sat, val, opacity)
					label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
					label.BackgroundTransparency = 1 - opacity
				end
			})
			label = Instance.new('TextLabel')
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 0.5
			label.TextSize = 15
			label.Font = Enum.Font.Gotham
			label.Text = '0.00 studs'
			label.TextColor3 = Color3.new(1, 1, 1)
			label.BackgroundColor3 = Color3.new()
			label.Parent = ReachDisplay.Children
			local corner = Instance.new('UICorner')
			corner.CornerRadius = UDim.new(0, 4)
			corner.Parent = label
		end)

		run(function()
			local SongBeats
			local List
			local FOV
			local FOVValue = {}
			local Volume
			local alreadypicked = {}
			local beattick = tick()
			local oldfov, songobj, songbpm, songtween

			local function choosesong()
				local list = List.ListEnabled
				if #alreadypicked >= #list then 
					table.clear(alreadypicked) 
				end

				if #list <= 0 then
					notif('SongBeats', 'no songs', 10)
					SongBeats:Toggle()
					return
				end

				local chosensong = list[math.random(1, #list)]
				if #list > 1 and table.find(alreadypicked, chosensong) then
					repeat 
						task.wait() 
						chosensong = list[math.random(1, #list)] 
					until not table.find(alreadypicked, chosensong) or not SongBeats.Enabled
				end
				if not SongBeats.Enabled then return end

				local split = chosensong:split('/')
				if not isfile(split[1]) then
					notif('SongBeats', 'Missing song ('..split[1]..')', 10)
					SongBeats:Toggle()
					return
				end

				songobj.SoundId = assetfunction(split[1])
				repeat task.wait() until songobj.IsLoaded or not SongBeats.Enabled
				if SongBeats.Enabled then
					beattick = tick() + (tonumber(split[3]) or 0)
					songbpm = 60 / (tonumber(split[2]) or 50)
					songobj:Play()
				end
			end

			SongBeats = vape.Legit:CreateModule({
				Name = 'Song Beats',
				Function = function(callback)
					if callback then
						songobj = Instance.new('Sound')
						songobj.Volume = Volume.Value / 100
						songobj.Parent = workspace
						repeat
							if not songobj.Playing then choosesong() end
							if beattick < tick() and SongBeats.Enabled and FOV.Enabled then
								beattick = tick() + songbpm
								oldfov = math.min(bedwars.FovController:getFOV() * (bedwars.SprintController.sprinting and 1.1 or 1), 120)
								gameCamera.FieldOfView = oldfov - FOVValue.Value
								songtween = tweenService:Create(gameCamera, TweenInfo.new(math.min(songbpm, 0.2), Enum.EasingStyle.Linear), {FieldOfView = oldfov})
								songtween:Play()
							end
							task.wait()
						until not SongBeats.Enabled
					else
						if songobj then
							songobj:Destroy()
						end
						if songtween then
							songtween:Cancel()
						end
						if oldfov then
							gameCamera.FieldOfView = oldfov
						end
						table.clear(alreadypicked)
					end
				end,
				Tooltip = 'Built in mp3 player'
			})
			List = SongBeats:CreateTextList({
				Name = 'Songs',
				Placeholder = 'filepath/bpm/start'
			})
			FOV = SongBeats:CreateToggle({
				Name = 'Beat FOV',
				Function = function(callback)
					if FOVValue.Object then
						FOVValue.Object.Visible = callback
					end
					if SongBeats.Enabled then
						SongBeats:Toggle()
						SongBeats:Toggle()
					end
				end,
				Default = true
			})
			FOVValue = SongBeats:CreateSlider({
				Name = 'Adjustment',
				Min = 1,
				Max = 30,
				Default = 5,
				Darker = true
			})
			Volume = SongBeats:CreateSlider({
				Name = 'Volume',
				Function = function(val)
					if songobj then 
						songobj.Volume = val / 100 
					end
				end,
				Min = 1,
				Max = 100,
				Default = 100,
				Suffix = '%'
			})
		end)

		run(function()
			local SoundChanger
			local List
			local soundlist = {}
			local old

			SoundChanger = vape.Legit:CreateModule({
				Name = 'SoundChanger',
				Function = function(callback)
					if callback then
						old = bedwars.SoundManager.playSound
						bedwars.SoundManager.playSound = function(self, id, ...)
							if soundlist[id] then
								id = soundlist[id]
							end

							return old(self, id, ...)
						end
					else
						bedwars.SoundManager.playSound = old
						old = nil
					end
				end,
				Tooltip = 'Change ingame sounds to custom ones.'
			})
			List = SoundChanger:CreateTextList({
				Name = 'Sounds',
				Placeholder = '(DAMAGE_1/ben.mp3)',
				Function = function()
					table.clear(soundlist)
					for _, entry in List.ListEnabled do
						local split = entry:split('/')
						local id = bedwars.SoundList[split[1]]
						if id and #split > 1 then
							soundlist[id] = split[2]:find('rbxasset') and split[2] or isfile(split[2]) and assetfunction(split[2]) or ''
						end
					end
				end
			})
		end)

		run(function()
			local UICleanup
			local OpenInv
			local KillFeed
			local OldTabList
			local HotbarApp = getRoactRender(require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-app']).HotbarApp.render)
			local HotbarOpenInventory = require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-open-inventory']).HotbarOpenInventory
			local old, new = {}, {}
			local oldkillfeed

			vape:Clean(function()
				for _, v in new do
					table.clear(v)
				end
				for _, v in old do
					table.clear(v)
				end
				table.clear(new)
				table.clear(old)
			end)

			local function modifyconstant(func, ind, val)
				if not old[func] then old[func] = {} end
				if not new[func] then new[func] = {} end
				if not old[func][ind] then
					local typing = type(old[func][ind])
					if typing == 'function' or typing == 'userdata' then return end
					old[func][ind] = debug.getconstant(func, ind)
				end
				if typeof(old[func][ind]) ~= typeof(val) and val ~= nil then return end

				new[func][ind] = val
				if UICleanup.Enabled then
					if val then
						debug.setconstant(func, ind, val)
					else
						debug.setconstant(func, ind, old[func][ind])
						old[func][ind] = nil
					end
				end
			end

			UICleanup = vape.Legit:CreateModule({
				Name = 'UI Cleanup',
				Function = function(callback)
					for i, v in (callback and new or old) do
						for i2, v2 in v do
							debug.setconstant(i, i2, v2)
						end
					end
					if callback then
						if OpenInv.Enabled then
							oldinvrender = HotbarOpenInventory.render
							HotbarOpenInventory.render = function()
								return bedwars.Roact.createElement('TextButton', {Visible = false}, {})
							end
						end

						if KillFeed.Enabled then
							oldkillfeed = bedwars.KillFeedController.addToKillFeed
							bedwars.KillFeedController.addToKillFeed = function() end
						end

						if OldTabList.Enabled then
							starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
						end
					else
						if oldinvrender then
							HotbarOpenInventory.render = oldinvrender
							oldinvrender = nil
						end

						if KillFeed.Enabled then
							bedwars.KillFeedController.addToKillFeed = oldkillfeed
							oldkillfeed = nil
						end

						if OldTabList.Enabled then
							starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
						end
					end
				end,
				Tooltip = 'Cleans up the UI for kits & main'
			})
			UICleanup:CreateToggle({
				Name = 'Resize Health',
				Function = function(callback)
					modifyconstant(HotbarApp, 60, callback and 1 or nil)
					modifyconstant(debug.getupvalue(HotbarApp, 15).render, 30, callback and 1 or nil)
					modifyconstant(debug.getupvalue(HotbarApp, 23).tweenPosition, 16, callback and 0 or nil)
				end,
				Default = true
			})
			UICleanup:CreateToggle({
				Name = 'No Hotbar Numbers',
				Function = function(callback)
					local func = oldinvrender or HotbarOpenInventory.render
					modifyconstant(debug.getupvalue(HotbarApp, 23).render, 90, callback and 0 or nil)
					modifyconstant(func, 71, callback and 0 or nil)
				end,
				Default = true
			})
			OpenInv = UICleanup:CreateToggle({
				Name = 'No Inventory Button',
				Function = function(callback)
					modifyconstant(HotbarApp, 78, callback and 0 or nil)
					if UICleanup.Enabled then
						if callback then
							oldinvrender = HotbarOpenInventory.render
							HotbarOpenInventory.render = function()
								return bedwars.Roact.createElement('TextButton', {Visible = false}, {})
							end
						else
							HotbarOpenInventory.render = oldinvrender
							oldinvrender = nil
						end
					end
				end,
				Default = true
			})
			KillFeed = UICleanup:CreateToggle({
				Name = 'No Kill Feed',
				Function = function(callback)
					if UICleanup.Enabled then
						if callback then
							oldkillfeed = bedwars.KillFeedController.addToKillFeed
							bedwars.KillFeedController.addToKillFeed = function() end
						else
							bedwars.KillFeedController.addToKillFeed = oldkillfeed
							oldkillfeed = nil
						end
					end
				end,
				Default = true
			})
			OldTabList = UICleanup:CreateToggle({
				Name = 'Old Player List',
				Function = function(callback)
					if UICleanup.Enabled then
						starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, callback)
					end
				end,
				Default = true
			})
			UICleanup:CreateToggle({
				Name = 'Fix Queue Card',
				Function = function(callback)
					modifyconstant(bedwars.QueueCard.render, 15, callback and 0.1 or nil)
				end,
				Default = true
			})
		end)

		run(function()
			local Viewmodel
			local Depth
			local Horizontal
			local Vertical
			local NoBob
			local Rots = {}
			local old, oldc1

			Viewmodel = vape.Legit:CreateModule({
				Name = 'Viewmodel',
				Function = function(callback)
					local viewmodel = gameCamera:FindFirstChild('Viewmodel')
					if callback then
						old = bedwars.ViewmodelController.playAnimation
						oldc1 = viewmodel and viewmodel.RightHand.RightWrist.C1 or CFrame.identity
						if NoBob.Enabled then
							bedwars.ViewmodelController.playAnimation = function(self, animtype, ...)
								if bedwars.AnimationType and animtype == bedwars.AnimationType.FP_WALK then return end
								return old(self, animtype, ...)
							end
						end

						bedwars.InventoryViewmodelController:handleStore(bedwars.Store:getState())
						if viewmodel then
							gameCamera.Viewmodel.RightHand.RightWrist.C1 = oldc1 * CFrame.Angles(math.rad(Rots[1].Value), math.rad(Rots[2].Value), math.rad(Rots[3].Value))
						end
						lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_DEPTH_OFFSET', -Depth.Value)
						lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_HORIZONTAL_OFFSET', Horizontal.Value)
						lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_VERTICAL_OFFSET', Vertical.Value)
					else
						bedwars.ViewmodelController.playAnimation = old
						if viewmodel then
							viewmodel.RightHand.RightWrist.C1 = oldc1
						end

						bedwars.InventoryViewmodelController:handleStore(bedwars.Store:getState())
						lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_DEPTH_OFFSET', 0)
						lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_HORIZONTAL_OFFSET', 0)
						lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_VERTICAL_OFFSET', 0)
						old = nil
					end
				end,
				Tooltip = 'Changes the viewmodel animations'
			})
			Depth = Viewmodel:CreateSlider({
				Name = 'Depth',
				Min = 0,
				Max = 2,
				Default = 0.8,
				Decimal = 10,
				Function = function(val)
					if Viewmodel.Enabled then
						lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_DEPTH_OFFSET', -val)
					end
				end
			})
			Horizontal = Viewmodel:CreateSlider({
				Name = 'Horizontal',
				Min = 0,
				Max = 2,
				Default = 0.8,
				Decimal = 10,
				Function = function(val)
					if Viewmodel.Enabled then
						lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_HORIZONTAL_OFFSET', val)
					end
				end
			})
			Vertical = Viewmodel:CreateSlider({
				Name = 'Vertical',
				Min = -0.2,
				Max = 2,
				Default = -0.2,
				Decimal = 10,
				Function = function(val)
					if Viewmodel.Enabled then
						lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_VERTICAL_OFFSET', val)
					end
				end
			})
			for _, name in {'Rotation X', 'Rotation Y', 'Rotation Z'} do
				table.insert(Rots, Viewmodel:CreateSlider({
					Name = name,
					Min = 0,
					Max = 360,
					Function = function(val)
						if Viewmodel.Enabled then
							gameCamera.Viewmodel.RightHand.RightWrist.C1 = oldc1 * CFrame.Angles(math.rad(Rots[1].Value), math.rad(Rots[2].Value), math.rad(Rots[3].Value))
						end
					end
				}))
			end
			NoBob = Viewmodel:CreateToggle({
				Name = 'No Bobbing',
				Default = true,
				Function = function()
					if Viewmodel.Enabled then
						Viewmodel:Toggle()
						Viewmodel:Toggle()
					end
				end
			})
		end)

		run(function()
			local WinEffect
			local List
			local NameToId = {}

			WinEffect = vape.Legit:CreateModule({
				Name = 'WinEffect',
				Function = function(callback)
					if callback then
						WinEffect:Clean(vapeEvents.MatchEndEvent.Event:Connect(function()
							for i, v in getconnections(bedwars.Client:Get('WinEffectTriggered').instance.OnClientEvent) do
								if v.Function then
									v.Function({
										winEffectType = NameToId[List.Value],
										winningPlayer = lplr
									})
								end
							end
						end))
					end
				end,
				Tooltip = 'Allows you to select any clientside win effect'
			})
			local WinEffectName = {}
			for i, v in bedwars.WinEffectMeta do
				table.insert(WinEffectName, v.name)
				NameToId[v.name] = i
			end
			table.sort(WinEffectName)
			List = WinEffect:CreateDropdown({
				Name = 'Effects',
				List = WinEffectName
			})
		end)
	end,
    ["Universal"] = function()
        local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then
		vape:CreateNotification('Lunar', 'Failed to load : '..err, 30, 'alert')
	end
	return res
end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/xylex1/LunarClient/'..readfile('newlunar/profiles/commit.txt')..'/'..select(1, path:gsub('newlunar/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end
local run = function(func)
	func()
end
local queue_on_teleport = queue_on_teleport or function() end
local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local lightingService = cloneref(game:GetService('Lighting'))
local marketplaceService = cloneref(game:GetService('MarketplaceService'))
local teleportService = cloneref(game:GetService('TeleportService'))
local httpService = cloneref(game:GetService('HttpService'))
local guiService = cloneref(game:GetService('GuiService'))
local groupService = cloneref(game:GetService('GroupService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local contextService = cloneref(game:GetService('ContextActionService'))
local coreGui = cloneref(game:GetService('CoreGui'))

local isnetworkowner = identifyexecutor and table.find({'AWP', 'Nihon'}, ({identifyexecutor()})[1]) and isnetworkowner or function()
	return true
end
local gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
local lplr = playersService.LocalPlayer
local assetfunction = getcustomasset

local vape = shared.vape
local tween = vape.Libraries.tween
local targetinfo = vape.Libraries.targetinfo
local getfontsize = vape.Libraries.getfontsize
local getcustomasset = vape.Libraries.getcustomasset

local TargetStrafeVector, SpiderShift, WaypointFolder
local Spider = {Enabled = false}
local Phase = {Enabled = false}

local function addBlur(parent)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Blur'
	blur.Size = UDim2.new(1, 89, 1, 52)
	blur.Position = UDim2.fromOffset(-48, -31)
	blur.BackgroundTransparency = 1
	blur.Image = 'rbxassetid://14898786664'
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.Parent = parent
	return blur
end

local function calculateMoveVector(vec)
	local c, s
	local _, _, _, R00, R01, R02, _, _, R12, _, _, R22 = gameCamera.CFrame:GetComponents()
	if R12 < 1 and R12 > -1 then
		c = R22
		s = R02
	else
		c = R00
		s = -R01 * math.sign(R12)
	end
	vec = Vector3.new((c * vec.X + s * vec.Z), 0, (c * vec.Z - s * vec.X)) / math.sqrt(c * c + s * s)
	return vec.Unit == vec.Unit and vec.Unit or Vector3.zero
end

local function isFriend(plr, recolor)
	if vape.Categories.Friends.Options['Use friends'].Enabled then
		local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
		if recolor then
			friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
		end
		return friend
	end
	return nil
end

local function isTarget(plr)
	return table.find(vape.Categories.Targets.ListEnabled, plr.Name) and true
end

local function canClick()
	local mousepos = (inputService:GetMouseLocation() - guiService:GetGuiInset())
	for _, v in lplr.PlayerGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
		local obj = v:FindFirstAncestorOfClass('ScreenGui')
		if v.Active and v.Visible and obj and obj.Enabled then
			return false
		end
	end
	for _, v in coreGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
		local obj = v:FindFirstAncestorOfClass('ScreenGui')
		if v.Active and v.Visible and obj and obj.Enabled then
			return false
		end
	end
	return (not vape.gui.ScaledGui.ClickGui.Visible) and (not inputService:GetFocusedTextBox())
end

local function getTableSize(tab)
	local ind = 0
	for _ in tab do ind += 1 end
	return ind
end

local function getTool()
	return lplr.Character and lplr.Character:FindFirstChildWhichIsA('Tool', true) or nil
end

local function notif(...)
	return vape:CreateNotification(...)
end

local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return (str:gsub('<[^<>]->', ''))
end

local visited, attempted, tpSwitch = {}, {}, false
local cacheExpire, cache = tick()
local function serverHop(pointer, filter)
	visited = shared.vapeserverhoplist and shared.vapeserverhoplist:split('/') or {}
	if not table.find(visited, game.JobId) then
		table.insert(visited, game.JobId)
	end
	if not pointer then
		notif('Lunar', 'Searching for an available server.', 2)
	end

	local suc, httpdata = pcall(function()
		return cacheExpire < tick() and game:HttpGet('https://games.roblox.com/v1/games/'..game.PlaceId..'/servers/Public?sortOrder='..(filter == 'Ascending' and 1 or 2)..'&excludeFullGames=true&limit=100'..(pointer and '&cursor='..pointer or '')) or cache
	end)
	local data = suc and httpService:JSONDecode(httpdata) or nil
	if data and data.data then
		for _, v in data.data do
			if tonumber(v.playing) < playersService.MaxPlayers and not table.find(visited, v.id) and not table.find(attempted, v.id) then
				cacheExpire, cache = tick() + 60, httpdata
				table.insert(attempted, v.id)

				notif('Lunar', 'Found! Teleporting.', 5)
				teleportService:TeleportToPlaceInstance(game.PlaceId, v.id)
				return
			end
		end

		if data.nextPageCursor then
			serverHop(data.nextPageCursor, filter)
		else
			notif('Lunar', 'Failed to find an available server.', 5, 'warning')
		end
	else
		notif('Lunar', 'Failed to grab servers. ('..(data and data.errors[1].message or 'no data')..')', 5, 'warning')
	end
end

vape:Clean(lplr.OnTeleport:Connect(function()
	if not tpSwitch then
		tpSwitch = true
		queue_on_teleport("shared.vapeserverhoplist = '"..table.concat(visited, '/').."'\nshared.vapeserverhopprevious = '"..game.JobId.."'")
	end
end))

local frictionTable, oldfrict, entitylib = {}, {}
local function updateVelocity()
	if getTableSize(frictionTable) > 0 then
		if entitylib.isAlive then
			for _, v in entitylib.character.Character:GetChildren() do
				if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
					oldfrict[v] = v.CustomPhysicalProperties or 'none'
					v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
				end
			end
		end
	else
		for i, v in oldfrict do
			i.CustomPhysicalProperties = v ~= 'none' and v or nil
		end
		table.clear(oldfrict)
	end
end

local function motorMove(target, cf)
	local part = Instance.new('Part')
	part.Anchored = true
	part.Parent = workspace
	local motor = Instance.new('Motor6D')
	motor.Part0 = target
	motor.Part1 = part
	motor.C1 = cf
	motor.Parent = part
	task.delay(0, part.Destroy, part)
end

local hash = loadstring(game:HttpGet("https://raw.githubusercontent.com/xylex1/LunarClient/main/libraries/hash.lua"), 'hash')()
local prediction = loadstring(game:HttpGet('https://raw.githubusercontent.com/xylex1/LunarClient/main/libraries/prediction.lua'), 'prediction')()
entitylib = loadstring(game:HttpGet('https://raw.githubusercontent.com/xylex1/LunarClient/main/libraries/entity.lua'), 'entitylibrary')()
local whitelist = {
	alreadychecked = {},
	customtags = {},
	data = {WhitelistedUsers = {}},
	hashes = setmetatable({}, {
		__index = function(_, v)
			return hash and hash.sha512(v..'SelfReport') or ''
		end
	}),
	hooked = false,
	loaded = false,
	localprio = 0,
	said = {}
}
vape.Libraries.entity = entitylib
vape.Libraries.whitelist = whitelist
vape.Libraries.prediction = prediction
vape.Libraries.hash = hash
vape.Libraries.auraanims = {
	Normal = {
		{CFrame = CFrame.new(-0.17, -0.14, -0.12) * CFrame.Angles(math.rad(-53), math.rad(50), math.rad(-64)), Time = 0.1},
		{CFrame = CFrame.new(-0.55, -0.59, -0.1) * CFrame.Angles(math.rad(-161), math.rad(54), math.rad(-6)), Time = 0.08},
		{CFrame = CFrame.new(-0.62, -0.68, -0.07) * CFrame.Angles(math.rad(-167), math.rad(47), math.rad(-1)), Time = 0.03},
		{CFrame = CFrame.new(-0.56, -0.86, 0.23) * CFrame.Angles(math.rad(-167), math.rad(49), math.rad(-1)), Time = 0.03}
	},
	Random = {},
	['Horizontal Spin'] = {
		{CFrame = CFrame.Angles(math.rad(-10), math.rad(-90), math.rad(-80)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(-10), math.rad(180), math.rad(-80)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(-10), math.rad(90), math.rad(-80)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(-10), 0, math.rad(-80)), Time = 0.12}
	},
	['Vertical Spin'] = {
		{CFrame = CFrame.Angles(math.rad(-90), 0, math.rad(15)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(180), 0, math.rad(15)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(90), 0, math.rad(15)), Time = 0.12},
		{CFrame = CFrame.Angles(0, 0, math.rad(15)), Time = 0.12}
	},
	Exhibition = {
		{CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.1},
		{CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.2}
	},
	['Exhibition Old'] = {
		{CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.15},
		{CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.05},
		{CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.1},
		{CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.05},
		{CFrame = CFrame.new(0.63, -0.1, 1.37) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.15}
	}
}

local SpeedMethods
local SpeedMethodList = {'Velocity'}
SpeedMethods = {
	Velocity = function(options, moveDirection)
		local root = entitylib.character.RootPart
		root.AssemblyLinearVelocity = (moveDirection * options.Value.Value) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	end,
	Impulse = function(options, moveDirection)
		local root = entitylib.character.RootPart
		local diff = ((moveDirection * options.Value.Value) - root.AssemblyLinearVelocity) * Vector3.new(1, 0, 1)
		if diff.Magnitude > (moveDirection == Vector3.zero and 10 or 2) then
			root:ApplyImpulse(diff * root.AssemblyMass)
		end
	end,
	CFrame = function(options, moveDirection, dt)
		local root = entitylib.character.RootPart
		local dest = (moveDirection * math.max(options.Value.Value - entitylib.character.Humanoid.WalkSpeed, 0) * dt)
		if options.WallCheck.Enabled then
			options.rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
			options.rayCheck.CollisionGroup = root.CollisionGroup
			local ray = workspace:Raycast(root.Position, dest, options.rayCheck)
			if ray then
				dest = ((ray.Position + ray.Normal) - root.Position)
			end
		end
		root.CFrame += dest
	end,
	TP = function(options, moveDirection)
		if options.TPTiming < tick() then
			options.TPTiming = tick() + options.TPFrequency.Value
			SpeedMethods.CFrame(options, moveDirection, 1)
		end
	end,
	WalkSpeed = function(options)
		if not options.WalkSpeed then options.WalkSpeed = entitylib.character.Humanoid.WalkSpeed end
		entitylib.character.Humanoid.WalkSpeed = options.Value.Value
	end,
	Pulse = function(options, moveDirection)
		local root = entitylib.character.RootPart
		local dt = math.max(options.Value.Value - entitylib.character.Humanoid.WalkSpeed, 0)
		dt = dt * (1 - math.min((tick() % (options.PulseLength.Value + options.PulseDelay.Value)) / options.PulseLength.Value, 1))
		root.AssemblyLinearVelocity = (moveDirection * (entitylib.character.Humanoid.WalkSpeed + dt)) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	end
}
for name in SpeedMethods do
	if not table.find(SpeedMethodList, name) then
		table.insert(SpeedMethodList, name)
	end
end

run(function()
	entitylib.getUpdateConnections = function(ent)
		local hum = ent.Humanoid
		return {
			hum:GetPropertyChangedSignal('Health'),
			hum:GetPropertyChangedSignal('MaxHealth'),
			{
				Connect = function()
					ent.Friend = ent.Player and isFriend(ent.Player) or nil
					ent.Target = ent.Player and isTarget(ent.Player) or nil
					return {
						Disconnect = function() end
					}
				end
			}
		}
	end

	entitylib.targetCheck = function(ent)
		if ent.TeamCheck then
			return ent:TeamCheck()
		end
		if ent.NPC then return true end
		if isFriend(ent.Player) then return false end
		if not select(2, whitelist:get(ent.Player)) then return false end
		if vape.Categories.Main.Options['Teams by server'].Enabled then
			if not lplr.Team then return true end
			if not ent.Player.Team then return true end
			if ent.Player.Team ~= lplr.Team then return true end
			return #ent.Player.Team:GetPlayers() == #playersService:GetPlayers()
		end
		return true
	end

	entitylib.getEntityColor = function(ent)
		ent = ent.Player
		if not (ent and vape.Categories.Main.Options['Use team color'].Enabled) then return end
		if isFriend(ent, true) then
			return Color3.fromHSV(vape.Categories.Friends.Options['Friends color'].Hue, vape.Categories.Friends.Options['Friends color'].Sat, vape.Categories.Friends.Options['Friends color'].Value)
		end
		return tostring(ent.TeamColor) ~= 'White' and ent.TeamColor.Color or nil
	end

	vape:Clean(function()
		entitylib.kill()
		entitylib = nil
	end)
	vape:Clean(vape.Categories.Friends.Update.Event:Connect(function() entitylib.refresh() end))
	vape:Clean(vape.Categories.Targets.Update.Event:Connect(function() entitylib.refresh() end))
	vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
	vape:Clean(workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
		gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
	end))
end)

run(function()
	function whitelist:get(plr)
		local plrstr = self.hashes[plr.Name..plr.UserId]
		for _, v in self.data.WhitelistedUsers do
			if v.hash == plrstr then
				return v.level, v.attackable or whitelist.localprio >= v.level, v.tags
			end
		end
		return 0, true
	end

	function whitelist:isingame()
		for _, v in playersService:GetPlayers() do
			if self:get(v) ~= 0 then return true end
		end
		return false
	end

	function whitelist:tag(plr, text, rich)
		local plrtag, newtag = select(3, self:get(plr)) or self.customtags[plr.Name] or {}, ''
		if not text then return plrtag end
		for _, v in plrtag do
			newtag = newtag..(rich and '<font color="#'..v.color:ToHex()..'">['..v.text..']</font>' or '['..removeTags(v.text)..']')..' '
		end
		return newtag
	end

	function whitelist:getplayer(arg)
		if arg == 'default' and self.localprio == 0 then return true end
		if arg == 'private' and self.localprio == 1 then return true end
		if arg and lplr.Name:lower():sub(1, arg:len()) == arg:lower() then return true end
		return false
	end

	local olduninject
	function whitelist:playeradded(v, joined)
		if self:get(v) ~= 0 then
			if self.alreadychecked[v.UserId] then return end
			self.alreadychecked[v.UserId] = true
			self:hook()
			if self.localprio == 0 then
				olduninject = vape.Uninject
				vape.Uninject = function()
					notif('Lunar', 'No escaping the private members :)', 10)
				end
				if joined then
					task.wait(10)
				end
				if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
					local oldchannel = textChatService.ChatInputBarConfiguration.TargetTextChannel
					local newchannel = cloneref(game:GetService('RobloxReplicatedStorage')).ExperienceChat.WhisperChat:InvokeServer(v.UserId)
					if newchannel then
						newchannel:SendAsync('helloimusinginhaler')
					end
					textChatService.ChatInputBarConfiguration.TargetTextChannel = oldchannel
				elseif replicatedStorage:FindFirstChild('DefaultChatSystemChatEvents') then
					replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer('/w '..v.Name..' helloimusinginhaler', 'All')
				end
			end
		end
	end

	function whitelist:process(msg, plr)
		if plr == lplr and msg == 'helloimusinginhaler' then return true end

		if self.localprio > 0 and not self.said[plr.Name] and msg == 'helloimusinginhaler' and plr ~= lplr then
			self.said[plr.Name] = true
			notif('Lunar', plr.Name..' is using lunar!', 60)
			self.customtags[plr.Name] = {{
				text = 'LUNAR USER',
				color = Color3.new(1, 1, 0)
			}}
			local newent = entitylib.getEntity(plr)
			if newent then
				entitylib.Events.EntityUpdated:Fire(newent)
			end
			return true
		end

		if self.localprio < self:get(plr) or plr == lplr then
			local args = msg:split(' ')
			table.remove(args, 1)
			if self:getplayer(args[1]) then
				table.remove(args, 1)
				for cmd, func in self.commands do
					if msg:sub(1, cmd:len() + 1):lower() == ';'..cmd:lower() then
						func(args, plr)
						return true
					end
				end
			end
		end

		return false
	end

	function whitelist:newchat(obj, plr, skip)
		obj.Text = self:tag(plr, true, true)..obj.Text
		local sub = obj.ContentText:find(': ')
		if sub then
			if not skip and self:process(obj.ContentText:sub(sub + 3, #obj.ContentText), plr) then
				obj.Visible = false
			end
		end
	end

	function whitelist:oldchat(func)
		local msgtable, oldchat = debug.getupvalue(func, 3)
		if typeof(msgtable) == 'table' and msgtable.CurrentChannel then
			whitelist.oldchattable = msgtable
		end

		oldchat = hookfunction(func, function(data, ...)
			local plr = playersService:GetPlayerByUserId(data.SpeakerUserId)
			if plr then
				data.ExtraData.Tags = data.ExtraData.Tags or {}
				for _, v in self:tag(plr) do
					table.insert(data.ExtraData.Tags, {TagText = v.text, TagColor = v.color})
				end
				if data.Message and self:process(data.Message, plr) then
					data.Message = ''
				end
			end
			return oldchat(data, ...)
		end)

		vape:Clean(function()
			hookfunction(func, oldchat)
		end)
	end

	function whitelist:hook()
		if self.hooked then return end
		self.hooked = true

		local exp = coreGui:FindFirstChild('ExperienceChat')
		if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			if exp and exp:WaitForChild('appLayout', 5) then
				vape:Clean(exp:FindFirstChild('RCTScrollContentView', true).ChildAdded:Connect(function(obj)
					local plr = playersService:GetPlayerByUserId(tonumber(obj.Name:split('-')[1]) or 0)
					obj = obj:FindFirstChild('TextMessage', true)
					if obj and obj:IsA('TextLabel') then
						if plr then
							self:newchat(obj, plr, true)
							obj:GetPropertyChangedSignal('Text'):Wait()
							self:newchat(obj, plr)
						end

						if obj.ContentText:sub(1, 35) == 'You are now privately chatting with' then
							obj.Visible = false
						end
					end
				end))
			end
		elseif replicatedStorage:FindFirstChild('DefaultChatSystemChatEvents') then
			pcall(function()
				for _, v in getconnections(replicatedStorage.DefaultChatSystemChatEvents.OnNewMessage.OnClientEvent) do
					if v.Function and table.find(debug.getconstants(v.Function), 'UpdateMessagePostedInChannel') then
						whitelist:oldchat(v.Function)
						break
					end
				end

				for _, v in getconnections(replicatedStorage.DefaultChatSystemChatEvents.OnMessageDoneFiltering.OnClientEvent) do
					if v.Function and table.find(debug.getconstants(v.Function), 'UpdateMessageFiltered') then
						whitelist:oldchat(v.Function)
						break
					end
				end
			end)
		end

		if exp then
			local bubblechat = exp:WaitForChild('bubbleChat', 5)
			if bubblechat then
				vape:Clean(bubblechat.DescendantAdded:Connect(function(newbubble)
					if newbubble:IsA('TextLabel') and newbubble.Text:find('helloimusinginhaler') then
						newbubble.Parent.Parent.Visible = false
					end
				end))
			end
		end
	end

	function whitelist:update(first)
		local suc = pcall(function()
			local _, subbed = pcall(function()
				return game:HttpGet('https://github.com/xylex1/whitelists')
			end)
			local commit = subbed:find('currentOid')
			commit = commit and subbed:sub(commit + 13, commit + 52) or nil
			commit = commit and #commit == 40 and commit or 'main'
			whitelist.textdata = game:HttpGet('https://raw.githubusercontent.com/xylex1/whitelists/'..commit..'/PlayerWhitelist.json', true)
		end)
		if not suc or not hash or not whitelist.get then return true end
		whitelist.loaded = true

		if not first or whitelist.textdata ~= whitelist.olddata then
			if not first then
				whitelist.olddata = isfile('newlunar/profiles/whitelist.json') and readfile('newlunar/profiles/whitelist.json') or nil
			end

			local suc, res = pcall(function()
				return httpService:JSONDecode(whitelist.textdata)
			end)

			whitelist.data = suc and type(res) == 'table' and res or whitelist.data
			whitelist.localprio = whitelist:get(lplr)

			for _, v in whitelist.data.WhitelistedUsers do
				if v.tags then
					for _, tag in v.tags do
						tag.color = Color3.fromRGB(unpack(tag.color))
					end
				end
			end

			if not whitelist.connection then
				whitelist.connection = playersService.PlayerAdded:Connect(function(v)
					whitelist:playeradded(v, true)
				end)
				vape:Clean(whitelist.connection)
			end

			for _, v in playersService:GetPlayers() do
				whitelist:playeradded(v)
			end

			if entitylib.Running and vape.Loaded then
				entitylib.refresh()
			end

			--if whitelist.textdata ~= whitelist.olddata then
			--	if whitelist.data.Announcement.expiretime > os.time() then
			--		local targets = whitelist.data.Announcement.targets
			--		targets = targets == 'all' and {tostring(lplr.UserId)} or targets:split(',')

			--		if table.find(targets, tostring(lplr.UserId)) then
			--			local hint = Instance.new('Hint')
			--			hint.Text = 'VAPE ANNOUNCEMENT: '..whitelist.data.Announcement.text
			--			hint.Parent = workspace
			--			game:GetService('Debris'):AddItem(hint, 20)
			--		end
			--	end
			--	whitelist.olddata = whitelist.textdata
			--	pcall(function()
			--		writefile('newlunar/profiles/whitelist.json', whitelist.textdata)
			--	end)
			--end

			if whitelist.data.KillVape then
				vape:Uninject()
				return true
			end

			--if whitelist.data.BlacklistedUsers[tostring(lplr.UserId)] then
			--	task.spawn(lplr.kick, lplr, whitelist.data.BlacklistedUsers[tostring(lplr.UserId)])
			--	return true
			--end
		end
	end

	whitelist.commands = {
		byfron = function()
			task.spawn(function()
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				local UIBlox = getrenv().require(game:GetService('CorePackages').UIBlox)
				local Roact = getrenv().require(game:GetService('CorePackages').Roact)
				UIBlox.init(getrenv().require(game:GetService('CorePackages').Workspace.Packages.RobloxAppUIBloxConfig))
				local auth = getrenv().require(coreGui.RobloxGui.Modules.LuaApp.Components.Moderation.ModerationPrompt)
				local darktheme = getrenv().require(game:GetService('CorePackages').Workspace.Packages.Style).Themes.DarkTheme
				local fonttokens = getrenv().require(game:GetService("CorePackages").Packages._Index.UIBlox.UIBlox.App.Style.Tokens).getTokens('Desktop', 'Dark', true)
				local buildersans = getrenv().require(game:GetService('CorePackages').Packages._Index.UIBlox.UIBlox.App.Style.Fonts.FontLoader).new(true, fonttokens):loadFont()
				local tLocalization = getrenv().require(game:GetService('CorePackages').Workspace.Packages.RobloxAppLocales).Localization
				local localProvider = getrenv().require(game:GetService('CorePackages').Workspace.Packages.Localization).LocalizationProvider
				lplr.PlayerGui:ClearAllChildren()
				vape.gui.Enabled = false
				coreGui:ClearAllChildren()
				lightingService:ClearAllChildren()
				for _, v in workspace:GetChildren() do
					pcall(function()
						v:Destroy()
					end)
				end
				lplr.kick(lplr)
				guiService:ClearError()
				local gui = Instance.new('ScreenGui')
				gui.IgnoreGuiInset = true
				gui.Parent = coreGui
				local frame = Instance.new('ImageLabel')
				frame.BorderSizePixel = 0
				frame.Size = UDim2.fromScale(1, 1)
				frame.BackgroundColor3 = Color3.fromRGB(224, 223, 225)
				frame.ScaleType = Enum.ScaleType.Crop
				frame.Parent = gui
				task.delay(0.3, function()
					frame.Image = 'rbxasset://textures/ui/LuaApp/graphic/Auth/GridBackground.jpg'
				end)
				task.delay(0.6, function()
					local modPrompt = Roact.createElement(auth, {
						style = {},
						screenSize = vape.gui.AbsoluteSize or Vector2.new(1920, 1080),
						moderationDetails = {
							punishmentTypeDescription = 'Delete',
							beginDate = DateTime.fromUnixTimestampMillis(DateTime.now().UnixTimestampMillis - ((60 * math.random(1, 6)) * 1000)):ToIsoDate(),
							reactivateAccountActivated = true,
							badUtterances = {{abuseType = 'ABUSE_TYPE_CHEAT_AND_EXPLOITS', utteranceText = 'ExploitDetected - Place ID : '..game.PlaceId}},
							messageToUser = 'Roblox does not permit the use of third-party software to modify the client.'
						},
						termsActivated = function() end,
						communityGuidelinesActivated = function() end,
						supportFormActivated = function() end,
						reactivateAccountActivated = function() end,
						logoutCallback = function() end,
						globalGuiInset = {top = 0}
					})

					local screengui = Roact.createElement(localProvider, {
						localization = tLocalization.new('en-us')
					}, {Roact.createElement(UIBlox.Style.Provider, {
						style = {
							Theme = darktheme,
							Font = buildersans
						},
					}, {modPrompt})})

					Roact.mount(screengui, coreGui)
				end)
			end)
		end,
		crash = function()
			task.spawn(function()
				repeat
					local part = Instance.new('Part')
					part.Size = Vector3.new(1e10, 1e10, 1e10)
					part.Parent = workspace
				until false
			end)
		end,
		deletemap = function()
			local terrain = workspace:FindFirstChildWhichIsA('Terrain')
			if terrain then
				terrain:Clear()
			end

			for _, v in workspace:GetChildren() do
				if v ~= terrain and not v:IsDescendantOf(lplr.Character) and not v:IsA('Camera') then
					v:Destroy()
					v:ClearAllChildren()
				end
			end
		end,
		framerate = function(args)
			if #args < 1 or not setfpscap then return end
			setfpscap(tonumber(args[1]) ~= '' and math.clamp(tonumber(args[1]) or 9999, 1, 9999) or 9999)
		end,
		gravity = function(args)
			workspace.Gravity = tonumber(args[1]) or workspace.Gravity
		end,
		jump = function()
			if entitylib.isAlive and entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end,
		kick = function(args)
			task.spawn(function()
				lplr:Kick(table.concat(args, ' '))
			end)
		end,
		kill = function()
			if entitylib.isAlive then
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Dead)
				entitylib.character.Humanoid.Health = 0
			end
		end,
		reveal = function()
			task.delay(0.1, function()
				if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
					textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync('I am using the inhaler client')
				else
					replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer('I am using the inhaler client', 'All')
				end
			end)
		end,
		shutdown = function()
			game:Shutdown()
		end,
		toggle = function(args)
			if #args < 1 then return end
			if args[1]:lower() == 'all' then
				for i, v in vape.Modules do
					if i ~= 'Panic' and i ~= 'ServerHop' and i ~= 'Rejoin' then
						v:Toggle()
					end
				end
			else
				for i, v in vape.Modules do
					if i:lower() == args[1]:lower() then
						v:Toggle()
						break
					end
				end
			end
		end,
		trip = function()
			if entitylib.isAlive then
				if entitylib.character.RootPart.Velocity.Magnitude < 15 then
					entitylib.character.RootPart.Velocity = entitylib.character.RootPart.CFrame.LookVector * 15
				end
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
			end
		end,
		uninject = function()
			if olduninject then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				olduninject(vape)
			else
				vape:Uninject()
			end
		end,
		void = function()
			if entitylib.isAlive then
				entitylib.character.RootPart.CFrame += Vector3.new(0, -1000, 0)
			end
		end
	}

	task.spawn(function()
		repeat
			if whitelist:update(whitelist.loaded) then return end
			task.wait(10)
		until vape.Loaded == nil
	end)

	vape:Clean(function()
		table.clear(whitelist.commands)
		table.clear(whitelist.data)
		table.clear(whitelist)
	end)
end)
entitylib.start()
run(function()
	local AimAssist
	local Targets
	local Part
	local FOV
	local Speed
	local CircleColor
	local CircleTransparency
	local CircleFilled
	local CircleObject
	local RightClick
	local ShowTarget
	local moveConst = Vector2.new(1, 0.77) * math.rad(0.5)
	
	local function wrapAngle(num)
		num = num % math.pi
		num -= num >= (math.pi / 2) and math.pi or 0
		num += num < -(math.pi / 2) and math.pi or 0
		return num
	end
	
	AimAssist = vape.Categories.Combat:CreateModule({
		Name = 'AimAssist',
		Function = function(callback)
			if CircleObject then
				CircleObject.Visible = callback
			end
			if callback then
				local ent
				local rightClicked = not RightClick.Enabled or inputService:IsMouseButtonPressed(1)
				AimAssist:Clean(runService.RenderStepped:Connect(function(dt)
					if CircleObject then
						CircleObject.Position = inputService:GetMouseLocation()
					end
	
					if rightClicked and not vape.gui.ScaledGui.ClickGui.Visible then
						ent = entitylib.EntityMouse({
							Range = FOV.Value,
							Part = Part.Value,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled,
							Origin = gameCamera.CFrame.Position
						})
	
						if ent then
							local facing = gameCamera.CFrame.LookVector
							local new = (ent[Part.Value].Position - gameCamera.CFrame.Position).Unit
							new = new == new and new or Vector3.zero
	
							if ShowTarget.Enabled then
								targetinfo.Targets[ent] = tick() + 1
							end
	
							if new ~= Vector3.zero then
								local diffYaw = wrapAngle(math.atan2(facing.X, facing.Z) - math.atan2(new.X, new.Z))
								local diffPitch = math.asin(facing.Y) - math.asin(new.Y)
								local angle = Vector2.new(diffYaw, diffPitch) // (moveConst * UserSettings():GetService('UserGameSettings').MouseSensitivity)
	
								angle *= math.min(Speed.Value * dt, 1)
								mousemoverel(angle.X, angle.Y)
							end
						end
					end
				end))
	
				if RightClick.Enabled then
					AimAssist:Clean(inputService.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton2 then
							ent = nil
							rightClicked = true
						end
					end))
	
					AimAssist:Clean(inputService.InputEnded:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton2 then
							rightClicked = false
						end
					end))
				end
			end
		end,
		Tooltip = 'Smoothly aims to closest valid target'
	})
	Targets = AimAssist:CreateTargets({Players = true})
	Part = AimAssist:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head'}
	})
	FOV = AimAssist:CreateSlider({
		Name = 'FOV',
		Min = 0,
		Max = 1000,
		Default = 100,
		Function = function(val)
			if CircleObject then
				CircleObject.Radius = val
			end
		end
	})
	Speed = AimAssist:CreateSlider({
		Name = 'Speed',
		Min = 0,
		Max = 30,
		Default = 15
	})
	AimAssist:CreateToggle({
		Name = 'Range Circle',
		Function = function(callback)
			if callback then
				CircleObject = Drawing.new('Circle')
				CircleObject.Filled = CircleFilled.Enabled
				CircleObject.Color = Color3.fromHSV(CircleColor.Hue, CircleColor.Sat, CircleColor.Value)
				CircleObject.Position = vape.gui.AbsoluteSize / 2
				CircleObject.Radius = FOV.Value
				CircleObject.NumSides = 100
				CircleObject.Transparency = 1 - CircleTransparency.Value
				CircleObject.Visible = AimAssist.Enabled
			else
				pcall(function()
					CircleObject.Visible = false
					CircleObject:Remove()
				end)
			end
			CircleColor.Object.Visible = callback
			CircleTransparency.Object.Visible = callback
			CircleFilled.Object.Visible = callback
		end
	})
	CircleColor = AimAssist:CreateColorSlider({
		Name = 'Circle Color',
		Function = function(hue, sat, val)
			if CircleObject then
				CircleObject.Color = Color3.fromHSV(hue, sat, val)
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleTransparency = AimAssist:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Default = 0.5,
		Function = function(val)
			if CircleObject then
				CircleObject.Transparency = 1 - val
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleFilled = AimAssist:CreateToggle({
		Name = 'Circle Filled',
		Function = function(callback)
			if CircleObject then
				CircleObject.Filled = callback
			end
		end,
		Darker = true,
		Visible = false
	})
	RightClick = AimAssist:CreateToggle({
		Name = 'Require right click',
		Function = function()
			if AimAssist.Enabled then
				AimAssist:Toggle()
				AimAssist:Toggle()
			end
		end
	})
	ShowTarget = AimAssist:CreateToggle({
		Name = 'Show target info'
	})
end)
	
run(function()
	local AutoClicker
	local Mode
	local CPS
	
	AutoClicker = vape.Categories.Combat:CreateModule({
		Name = 'AutoClicker',
		Function = function(callback)
			if callback then
				repeat
					if Mode.Value == 'Tool' then
						local tool = getTool()
						if tool and inputService:IsMouseButtonPressed(0) then
							tool:Activate()
						end
					else
						if mouse1click and (isrbxactive or iswindowactive)() then
							if not vape.gui.ScaledGui.ClickGui.Visible then
								(Mode.Value == 'Click' and mouse1click or mouse2click)()
							end
						end
					end
	
					task.wait(1 / CPS.GetRandomValue())
				until not AutoClicker.Enabled
			end
		end,
		Tooltip = 'Automatically clicks for you'
	})
	Mode = AutoClicker:CreateDropdown({
		Name = 'Mode',
		List = {'Tool', 'Click', 'RightClick'},
		Tooltip = 'Tool - Automatically uses roblox tools (eg. swords)\nClick - Left click\nRightClick - Right click'
	})
	CPS = AutoClicker:CreateTwoSlider({
		Name = 'CPS',
		Min = 1,
		Max = 20,
		DefaultMin = 8,
		DefaultMax = 12
	})
end)
	
run(function()
	local Reach
	local Targets
	local Mode
	local Value
	local Chance
	local Overlay = OverlapParams.new()
	Overlay.FilterType = Enum.RaycastFilterType.Include
	local modified = {}
	
	Reach = vape.Categories.Combat:CreateModule({
		Name = 'Reach',
		Function = function(callback)
			if callback then
				repeat
					local tool = getTool()
					tool = tool and tool:FindFirstChildWhichIsA('TouchTransmitter', true)
					if tool then
						if Mode.Value == 'TouchInterest' then
							local entites = {}
							for _, v in entitylib.List do
								if v.Targetable then
									if not Targets.Players.Enabled and v.Player then continue end
									if not Targets.NPCs.Enabled and v.NPC then continue end
									table.insert(entites, v.Character)
								end
							end
	
							Overlay.FilterDescendantsInstances = entites
							local parts = workspace:GetPartBoundsInBox(tool.Parent.CFrame * CFrame.new(0, 0, Value.Value / 2), tool.Parent.Size + Vector3.new(0, 0, Value.Value), Overlay)
	
							for _, v in parts do
								if Random.new().NextNumber(Random.new(), 0, 100) > Chance.Value then
									task.wait(0.2)
									break
								end
	
								firetouchinterest(tool.Parent, v, 1)
								firetouchinterest(tool.Parent, v, 0)
							end
						else
							if not modified[tool.Parent] then
								modified[tool.Parent] = tool.Parent.Size
							end
							tool.Parent.Size = modified[tool.Parent] + Vector3.new(0, 0, Value.Value)
							tool.Parent.Massless = true
						end
					end
	
					task.wait()
				until not Reach.Enabled
			else
				for i, v in modified do
					i.Size = v
					i.Massless = false
				end
				table.clear(modified)
			end
		end,
		Tooltip = 'Extends tool attack reach'
	})
	Targets = Reach:CreateTargets({Players = true})
	Mode = Reach:CreateDropdown({
		Name = 'Mode',
		List = {'TouchInterest', 'Resize'},
		Function = function(val)
			Chance.Object.Visible = val == 'TouchInterest'
		end,
		Tooltip = 'TouchInterest - Reports fake collision events to the server\nResize - Physically modifies the tools size'
	})
	Value = Reach:CreateSlider({
		Name = 'Range',
		Min = 0,
		Max = 2,
		Decimal = 10,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Chance = Reach:CreateSlider({
		Name = 'Chance',
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
end)
	
local mouseClicked
run(function()
	local SilentAim
	local Target
	local Mode
	local Method
	local MethodRay
	local IgnoredScripts
	local Range
	local HitChance
	local HeadshotChance
	local AutoFire
	local AutoFireShootDelay
	local AutoFireMode
	local AutoFirePosition
	local Wallbang
	local CircleColor
	local CircleTransparency
	local CircleFilled
	local CircleObject
	local Projectile
	local ProjectileSpeed
	local ProjectileGravity
	local RaycastWhitelist = RaycastParams.new()
	RaycastWhitelist.FilterType = Enum.RaycastFilterType.Include
	local ProjectileRaycast = RaycastParams.new()
	ProjectileRaycast.RespectCanCollide = true
	local fireoffset, rand, delayCheck = CFrame.identity, Random.new(), tick()
	local oldnamecall, oldray

	local function getTarget(origin, obj)
		if rand.NextNumber(rand, 0, 100) > (AutoFire.Enabled and 100 or HitChance.Value) then return end
		local targetPart = (rand.NextNumber(rand, 0, 100) < (AutoFire.Enabled and 100 or HeadshotChance.Value)) and 'Head' or 'RootPart'
		local ent = entitylib['Entity'..Mode.Value]({
			Range = Range.Value,
			Wallcheck = Target.Walls.Enabled and (obj or true) or nil,
			Part = targetPart,
			Origin = origin,
			Players = Target.Players.Enabled,
			NPCs = Target.NPCs.Enabled
		})

		if ent then
			targetinfo.Targets[ent] = tick() + 1
			if Projectile.Enabled then
				ProjectileRaycast.FilterDescendantsInstances = {gameCamera, ent.Character}
				ProjectileRaycast.CollisionGroup = ent[targetPart].CollisionGroup
			end
		end

		return ent, ent and ent[targetPart], origin
	end

	local Hooks = {
		FindPartOnRayWithIgnoreList = function(args)
			local ent, targetPart, origin = getTarget(args[1].Origin, {args[2]})
			if not ent then return end
			if Wallbang.Enabled then
				return {targetPart, targetPart.Position, targetPart.GetClosestPointOnSurface(targetPart, origin), targetPart.Material}
			end
			args[1] = Ray.new(origin, CFrame.lookAt(origin, targetPart.Position).LookVector * args[1].Direction.Magnitude)
		end,
		Raycast = function(args)
			if MethodRay.Value ~= 'All' and args[3] and args[3].FilterType ~= Enum.RaycastFilterType[MethodRay.Value] then return end
			local ent, targetPart, origin = getTarget(args[1])
			if not ent then return end
			args[2] = CFrame.lookAt(origin, targetPart.Position).LookVector * args[2].Magnitude
			if Wallbang.Enabled then
				RaycastWhitelist.FilterDescendantsInstances = {targetPart}
				args[3] = RaycastWhitelist
			end
		end,
		ScreenPointToRay = function(args)
			local ent, targetPart, origin = getTarget(gameCamera.CFrame.Position)
			if not ent then return end
			local direction = CFrame.lookAt(origin, targetPart.Position)
			if Projectile.Enabled then
				local calc = prediction.SolveTrajectory(origin, ProjectileSpeed.Value, ProjectileGravity.Value, targetPart.Position, targetPart.Velocity, workspace.Gravity, ent.HipHeight, nil, ProjectileRaycast)
				if not calc then return end
				direction = CFrame.lookAt(origin, calc)
			end
			return {Ray.new(origin + (args[3] and direction.LookVector * args[3] or Vector3.zero), direction.LookVector)}
		end,
		Ray = function(args)
			local ent, targetPart, origin = getTarget(args[1])
			if not ent then return end
			if Projectile.Enabled then
				local calc = prediction.SolveTrajectory(origin, ProjectileSpeed.Value, ProjectileGravity.Value, targetPart.Position, targetPart.Velocity, workspace.Gravity, ent.HipHeight, nil, ProjectileRaycast)
				if not calc then return end
				args[2] = CFrame.lookAt(origin, calc).LookVector * args[2].Magnitude
			else
				args[2] = CFrame.lookAt(origin, targetPart.Position).LookVector * args[2].Magnitude
			end
		end
	}
	Hooks.FindPartOnRayWithWhitelist = Hooks.FindPartOnRayWithIgnoreList
	Hooks.FindPartOnRay = Hooks.FindPartOnRayWithIgnoreList
	Hooks.ViewportPointToRay = Hooks.ScreenPointToRay

	SilentAim = vape.Categories.Combat:CreateModule({
		Name = 'SilentAim',
		Function = function(callback)
			if CircleObject then
				CircleObject.Visible = callback and Mode.Value == 'Mouse'
			end
			if callback then
				if Method.Value == 'Ray' then
					oldray = hookfunction(Ray.new, function(origin, direction)
						if checkcaller() then
							return oldray(origin, direction)
						end
						local calling = getcallingscript()

						if calling then
							local list = #IgnoredScripts.ListEnabled > 0 and IgnoredScripts.ListEnabled or {'ControlScript', 'ControlModule'}
							if table.find(list, tostring(calling)) then
								return oldray(origin, direction)
							end
						end

						local args = {origin, direction}
						Hooks.Ray(args)
						return oldray(unpack(args))
					end)
				else
					oldnamecall = hookmetamethod(game, '__namecall', function(...)
						if getnamecallmethod() ~= Method.Value then
							return oldnamecall(...)
						end
						if checkcaller() then
							return oldnamecall(...)
						end

						local calling = getcallingscript()
						if calling then
							local list = #IgnoredScripts.ListEnabled > 0 and IgnoredScripts.ListEnabled or {'ControlScript', 'ControlModule'}
							if table.find(list, tostring(calling)) then
								return oldnamecall(...)
							end
						end

						local self, args = ..., {select(2, ...)}
						local res = Hooks[Method.Value](args)
						if res then
							return unpack(res)
						end
						return oldnamecall(self, unpack(args))
					end)
				end

				repeat
					if CircleObject then
						CircleObject.Position = inputService:GetMouseLocation()
					end
					if AutoFire.Enabled then
						local origin = AutoFireMode.Value == 'Camera' and gameCamera.CFrame or entitylib.isAlive and entitylib.character.RootPart.CFrame or CFrame.identity
						local ent = entitylib['Entity'..Mode.Value]({
							Range = Range.Value,
							Wallcheck = Target.Walls.Enabled or nil,
							Part = 'Head',
							Origin = (origin * fireoffset).Position,
							Players = Target.Players.Enabled,
							NPCs = Target.NPCs.Enabled
						})

						if mouse1click and (isrbxactive or iswindowactive)() then
							if ent and canClick() then
								if delayCheck < tick() then
									if mouseClicked then
										mouse1release()
										delayCheck = tick() + AutoFireShootDelay.Value
									else
										mouse1press()
									end
									mouseClicked = not mouseClicked
								end
							else
								if mouseClicked then
									mouse1release()
								end
								mouseClicked = false
							end
						end
					end
					task.wait()
				until not SilentAim.Enabled
			else
				if oldnamecall then
					hookmetamethod(game, '__namecall', oldnamecall)
				end
				if oldray then
					hookfunction(Ray.new, oldray)
				end
				oldnamecall, oldray = nil, nil
			end
		end,
		ExtraText = function()
			return Method.Value:gsub('FindPartOnRay', '')
		end,
		Tooltip = 'Silently adjusts your aim towards the enemy'
	})
	Target = SilentAim:CreateTargets({Players = true})
	Mode = SilentAim:CreateDropdown({
		Name = 'Mode',
		List = {'Mouse', 'Position'},
		Function = function(val)
			if CircleObject then
				CircleObject.Visible = SilentAim.Enabled and val == 'Mouse'
			end
		end,
		Tooltip = 'Mouse - Checks for entities near the mouses position\nPosition - Checks for entities near the local character'
	})
	Method = SilentAim:CreateDropdown({
		Name = 'Method',
		List = {'FindPartOnRay', 'FindPartOnRayWithIgnoreList', 'FindPartOnRayWithWhitelist', 'ScreenPointToRay', 'ViewportPointToRay', 'Raycast', 'Ray'},
		Function = function(val)
			if SilentAim.Enabled then
				SilentAim:Toggle()
				SilentAim:Toggle()
			end
			MethodRay.Object.Visible = val == 'Raycast'
		end,
		Tooltip = 'FindPartOnRay* - Deprecated methods of raycasting used in old games\nRaycast - The modern raycast method\nPointToRay - Method to generate a ray from screen coords\nRay - Hooking Ray.new'
	})
	MethodRay = SilentAim:CreateDropdown({
		Name = 'Raycast Type',
		List = {'All', 'Exclude', 'Include'},
		Darker = true,
		Visible = false
	})
	IgnoredScripts = SilentAim:CreateTextList({Name = 'Ignored Scripts'})
	Range = SilentAim:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 1000,
		Default = 150,
		Function = function(val)
			if CircleObject then
				CircleObject.Radius = val
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	HitChance = SilentAim:CreateSlider({
		Name = 'Hit Chance',
		Min = 0,
		Max = 100,
		Default = 85,
		Suffix = '%'
	})
	HeadshotChance = SilentAim:CreateSlider({
		Name = 'Headshot Chance',
		Min = 0,
		Max = 100,
		Default = 65,
		Suffix = '%'
	})
	AutoFire = SilentAim:CreateToggle({
		Name = 'AutoFire',
		Function = function(callback)
			AutoFireShootDelay.Object.Visible = callback
			AutoFireMode.Object.Visible = callback
			AutoFirePosition.Object.Visible = callback
		end
	})
	AutoFireShootDelay = SilentAim:CreateSlider({
		Name = 'Next Shot Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Visible = false,
		Darker = true,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	AutoFireMode = SilentAim:CreateDropdown({
		Name = 'Origin',
		List = {'RootPart', 'Camera'},
		Visible = false,
		Darker = true,
		Tooltip = 'Determines the position to check for before shooting'
	})
	AutoFirePosition = SilentAim:CreateTextBox({
		Name = 'Offset',
		Function = function()
			local suc, res = pcall(function()
				return CFrame.new(unpack(AutoFirePosition.Value:split(',')))
			end)
			if suc then fireoffset = res end
		end,
		Default = '0, 0, 0',
		Visible = false,
		Darker = true
	})
	Wallbang = SilentAim:CreateToggle({Name = 'Wallbang'})
	SilentAim:CreateToggle({
		Name = 'Range Circle',
		Function = function(callback)
			if callback then
				CircleObject = Drawing.new('Circle')
				CircleObject.Filled = CircleFilled.Enabled
				CircleObject.Color = Color3.fromHSV(CircleColor.Hue, CircleColor.Sat, CircleColor.Value)
				CircleObject.Position = vape.gui.AbsoluteSize / 2
				CircleObject.Radius = Range.Value
				CircleObject.NumSides = 100
				CircleObject.Transparency = 1 - CircleTransparency.Value
				CircleObject.Visible = SilentAim.Enabled and Mode.Value == 'Mouse'
			else
				pcall(function()
					CircleObject.Visible = false
					CircleObject:Remove()
				end)
			end
			CircleColor.Object.Visible = callback
			CircleTransparency.Object.Visible = callback
			CircleFilled.Object.Visible = callback
		end
	})
	CircleColor = SilentAim:CreateColorSlider({
		Name = 'Circle Color',
		Function = function(hue, sat, val)
			if CircleObject then
				CircleObject.Color = Color3.fromHSV(hue, sat, val)
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleTransparency = SilentAim:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Default = 0.5,
		Function = function(val)
			if CircleObject then
				CircleObject.Transparency = 1 - val
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleFilled = SilentAim:CreateToggle({
		Name = 'Circle Filled',
		Function = function(callback)
			if CircleObject then
				CircleObject.Filled = callback
			end
		end,
		Darker = true,
		Visible = false
	})
	Projectile = SilentAim:CreateToggle({
		Name = 'Projectile',
		Function = function(callback)
			ProjectileSpeed.Object.Visible = callback
			ProjectileGravity.Object.Visible = callback
		end
	})
	ProjectileSpeed = SilentAim:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 1000,
		Default = 1000,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	ProjectileGravity = SilentAim:CreateSlider({
		Name = 'Gravity',
		Min = 0,
		Max = 192.6,
		Default = 192.6,
		Darker = true,
		Visible = false
	})
end)
	
run(function()
	local TriggerBot
	local Targets
	local ShootDelay
	local Distance
	local rayCheck, delayCheck = RaycastParams.new(), tick()
	
	local function getTriggerBotTarget()
		rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
	
		local ray = workspace:Raycast(gameCamera.CFrame.Position, gameCamera.CFrame.LookVector * Distance.Value, rayCheck)
		if ray and ray.Instance then
			for _, v in entitylib.List do
				if v.Targetable and v.Character and (Targets.Players.Enabled and v.Player or Targets.NPCs.Enabled and v.NPC) then
					if ray.Instance:IsDescendantOf(v.Character) then
						return entitylib.isVulnerable(v) and v
					end
				end
			end
		end
	end
	
	TriggerBot = vape.Categories.Combat:CreateModule({
		Name = 'TriggerBot',
		Function = function(callback)
			if callback then
				repeat
					if mouse1click and (isrbxactive or iswindowactive)() then
						if getTriggerBotTarget() and canClick() then
							if delayCheck < tick() then
								if mouseClicked then
									mouse1release()
									delayCheck = tick() + ShootDelay.Value
								else
									mouse1press()
								end
								mouseClicked = not mouseClicked
							end
						else
							if mouseClicked then
								mouse1release()
							end
							mouseClicked = false
						end
					end
					task.wait()
				until not TriggerBot.Enabled
			else
				if mouse1click and (isrbxactive or iswindowactive)() then
					if mouseClicked then
						mouse1release()
					end
				end
				mouseClicked = false
			end
		end,
		Tooltip = 'Shoots people that enter your crosshair'
	})
	Targets = TriggerBot:CreateTargets({
		Players = true,
		NPCs = true
	})
	ShootDelay = TriggerBot:CreateSlider({
		Name = 'Next Shot Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end,
		Tooltip = 'The delay set after shooting a target'
	})
	Distance = TriggerBot:CreateSlider({
		Name = 'Distance',
		Min = 0,
		Max = 1000,
		Default = 1000,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)
	
run(function()
	local AntiFall
	local Method
	local Mode
	local Material
	local Color
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local part
	
	AntiFall = vape.Categories.Blatant:CreateModule({
		Name = 'AntiFall',
		Function = function(callback)
			if callback then
				if Method.Value == 'Part' then
					local debounce = tick()
					part = Instance.new('Part')
					part.Size = Vector3.new(10000, 1, 10000)
					part.Transparency = 1 - Color.Opacity
					part.Material = Enum.Material[Material.Value]
					part.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
					part.CanCollide = Mode.Value == 'Collide'
					part.Anchored = true
					part.CanQuery = false
					part.Parent = workspace
					AntiFall:Clean(part)
					AntiFall:Clean(part.Touched:Connect(function(touchedpart)
						if touchedpart.Parent == lplr.Character and entitylib.isAlive and debounce < tick() then
							local root = entitylib.character.RootPart
							debounce = tick() + 0.1
							if Mode.Value == 'Velocity' then
								root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 100, root.AssemblyLinearVelocity.Z)
							elseif Mode.Value == 'Impulse' then
								root:ApplyImpulse(Vector3.new(0, (100 - root.AssemblyLinearVelocity.Y), 0) * root.AssemblyMass)
							end
						end
					end))
	
					repeat
						if entitylib.isAlive then
							local root = entitylib.character.RootPart
							rayCheck.FilterDescendantsInstances = {gameCamera, lplr.Character, part}
							rayCheck.CollisionGroup = root.CollisionGroup
							local ray = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), rayCheck)
							if ray then
								part.Position = ray.Position - Vector3.new(0, 15, 0)
							end
						end
						task.wait(0.1)
					until not AntiFall.Enabled
				else
					local lastpos
					AntiFall:Clean(runService.PreSimulation:Connect(function()
						if entitylib.isAlive then
							local root = entitylib.character.RootPart
							lastpos = entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air and root.Position or lastpos
							if (root.Position.Y + (root.Velocity.Y * 0.016)) <= (workspace.FallenPartsDestroyHeight + 10) then
								lastpos = lastpos or Vector3.new(root.Position.X, (workspace.FallenPartsDestroyHeight + 20), root.Position.Z)
								root.CFrame += (lastpos - root.Position)
								root.Velocity *= Vector3.new(1, 0, 1)
							end
						end
					end))
				end
			end
		end,
		Tooltip = 'Help\'s you with your Parkinson\'s\nPrevents you from falling into the void.'
	})
	Method = AntiFall:CreateDropdown({
		Name = 'Method',
		List = {'Part', 'Classic'},
		Function = function(val)
			if Mode.Object then
				Mode.Object.Visible = val == 'Part'
				Material.Object.Visible = val == 'Part'
				Color.Object.Visible = val == 'Part'
			end
			if AntiFall.Enabled then
				AntiFall:Toggle()
				AntiFall:Toggle()
			end
		end,
		Tooltip = 'Part - Moves a part under you that does various methods to stop you from falling\nClassic - Teleports you out of the void after reaching the part destroy plane'
	})
	Mode = AntiFall:CreateDropdown({
		Name = 'Move Mode',
		List = {'Impulse', 'Velocity', 'Collide'},
		Darker = true,
		Function = function(val)
			if part then
				part.CanCollide = val == 'Collide'
			end
		end,
		Tooltip = 'Velocity - Launches you upward after touching\nCollide - Allows you to walk on the part'
	})
	local materials = {'ForceField'}
	for _, v in Enum.Material:GetEnumItems() do
		if v.Name ~= 'ForceField' then
			table.insert(materials, v.Name)
		end
	end
	Material = AntiFall:CreateDropdown({
		Name = 'Material',
		List = materials,
		Darker = true,
		Function = function(val)
			if part then
				part.Material = Enum.Material[val]
			end
		end
	})
	Color = AntiFall:CreateColorSlider({
		Name = 'Color',
		DefaultOpacity = 0.5,
		Darker = true,
		Function = function(h, s, v, o)
			if part then
				part.Color = Color3.fromHSV(h, s, v)
				part.Transparency = 1 - o
			end
		end
	})
end)
	
local Fly
local LongJump
run(function()
	local Options = {TPTiming = tick()}
	local Mode
	local FloatMode
	local State
	local MoveMethod
	local Keys
	local VerticalValue
	local BounceLength
	local BounceDelay
	local FloatTPGround
	local FloatTPAir
	local CustomProperties
	local WallCheck
	local PlatformStanding
	local Platform, YLevel, OldYLevel
	local w, s, a, d, up, down = 0, 0, 0, 0, 0, 0
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	Options.rayCheck = rayCheck

	local Functions
	Functions = {
		Velocity = function()
			entitylib.character.RootPart.Velocity = (entitylib.character.RootPart.Velocity * Vector3.new(1, 0, 1)) + Vector3.new(0, 2.25 + ((up + down) * VerticalValue.Value), 0)
		end,
		Impulse = function(options, moveDirection)
			local root = entitylib.character.RootPart
			local diff = (Vector3.new(0, 2.25 + ((up + down) * VerticalValue.Value), 0) - root.AssemblyLinearVelocity) * Vector3.new(0, 1, 0)
			if diff.Magnitude > 2 then
				root:ApplyImpulse(diff * root.AssemblyMass)
			end
		end,
		CFrame = function(dt)
			local root = entitylib.character.RootPart
			if not YLevel then
				YLevel = root.Position.Y
			end
			YLevel = YLevel + ((up + down) * VerticalValue.Value * dt)
			if WallCheck.Enabled then
				rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
				rayCheck.CollisionGroup = root.CollisionGroup
				local ray = workspace:Raycast(root.Position, Vector3.new(0, YLevel - root.Position.Y, 0), rayCheck)
				if ray then
					YLevel = ray.Position.Y + entitylib.character.HipHeight
				end
			end
			root.Velocity *= Vector3.new(1, 0, 1)
			root.CFrame += Vector3.new(0, YLevel - root.Position.Y, 0)
		end,
		Bounce = function()
			Functions.Velocity()
			entitylib.character.RootPart.Velocity += Vector3.new(0, ((tick() % BounceDelay.Value) / BounceDelay.Value > 0.5 and 1 or -1) * BounceLength.Value, 0)
		end,
		Floor = function()
			Platform.CFrame = down ~= 0 and CFrame.identity or entitylib.character.RootPart.CFrame + Vector3.new(0, -(entitylib.character.HipHeight + 0.5), 0)
		end,
		TP = function(dt)
			Functions.CFrame(dt)
			if tick() % (FloatTPAir.Value + FloatTPGround.Value) > FloatTPAir.Value then
				OldYLevel = OldYLevel or YLevel
				rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
				rayCheck.CollisionGroup = entitylib.character.RootPart.CollisionGroup
				local ray = workspace:Raycast(entitylib.character.RootPart.Position, Vector3.new(0, -1000, 0), rayCheck)
				if ray then
					YLevel = ray.Position.Y + entitylib.character.HipHeight
				end
			else
				if OldYLevel then
					YLevel = OldYLevel
					OldYLevel = nil
				end
			end
		end,
		Jump = function(dt)
			local root = entitylib.character.RootPart
			if not YLevel then
				YLevel = root.Position.Y
			end
			YLevel = YLevel + ((up + down) * VerticalValue.Value * dt)
			if root.Position.Y < YLevel then
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end
	}

	Fly = vape.Categories.Blatant:CreateModule({
		Name = 'Fly',
		Function = function(callback)
			if Platform then
				Platform.Parent = callback and gameCamera or nil
			end
			frictionTable.Fly = callback and CustomProperties.Enabled or nil
			updateVelocity()
			if callback then
				Fly:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive then
						if PlatformStanding.Enabled then
							entitylib.character.Humanoid.PlatformStand = true
							entitylib.character.RootPart.RotVelocity = Vector3.zero
							entitylib.character.RootPart.CFrame = CFrame.lookAlong(entitylib.character.RootPart.CFrame.Position, gameCamera.CFrame.LookVector)
						end
						if State.Value ~= 'None' then
							entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType[State.Value])
						end
						SpeedMethods[Mode.Value](Options, TargetStrafeVector or MoveMethod.Value == 'Direct' and calculateMoveVector(Vector3.new(a + d, 0, w + s)) or entitylib.character.Humanoid.MoveDirection, dt)
						Functions[FloatMode.Value](dt)
					else
						YLevel = nil
						OldYLevel = nil
					end
				end))

				w, s, a, d = inputService:IsKeyDown(Enum.KeyCode.W) and -1 or 0, inputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0, inputService:IsKeyDown(Enum.KeyCode.A) and -1 or 0, inputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0
				up, down = 0, 0
				for _, v in {'InputBegan', 'InputEnded'} do
					Fly:Clean(inputService[v]:Connect(function(input)
						if not inputService:GetFocusedTextBox() then
							local divided = Keys.Value:split('/')
							if input.KeyCode == Enum.KeyCode.W then
								w = v == 'InputBegan' and -1 or 0
							elseif input.KeyCode == Enum.KeyCode.S then
								s = v == 'InputBegan' and 1 or 0
							elseif input.KeyCode == Enum.KeyCode.A then
								a = v == 'InputBegan' and -1 or 0
							elseif input.KeyCode == Enum.KeyCode.D then
								d = v == 'InputBegan' and 1 or 0
							elseif input.KeyCode == Enum.KeyCode[divided[1]] then
								up = v == 'InputBegan' and 1 or 0
							elseif input.KeyCode == Enum.KeyCode[divided[2]] then
								down = v == 'InputBegan' and -1 or 0
							end
						end
					end))
				end
				if inputService.TouchEnabled then
					pcall(function()
						local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
						Fly:Clean(jumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(function()
							up = jumpButton.ImageRectOffset.X == 146 and 1 or 0
						end))
					end)
				end
			else
				YLevel, OldYLevel = nil, nil
				if entitylib.isAlive and PlatformStanding.Enabled then
					entitylib.character.Humanoid.PlatformStand = false
				end
			end
		end,
		ExtraText = function()
			return Mode.Value
		end,
		Tooltip = 'Makes you go zoom.'
	})
	Mode = Fly:CreateDropdown({
		Name = 'Speed Mode',
		List = SpeedMethodList,
		Function = function(val)
			WallCheck.Object.Visible = FloatMode.Value == 'CFrame' or FloatMode.Value == 'TP' or val == 'CFrame' or val == 'TP'
			Options.TPFrequency.Object.Visible = val == 'TP'
			Options.PulseLength.Object.Visible = val == 'Pulse'
			Options.PulseDelay.Object.Visible = val == 'Pulse'
			if Fly.Enabled then
				Fly:Toggle()
				Fly:Toggle()
			end
		end,
		Tooltip = 'Velocity - Uses smooth physics based movement\nImpulse - Same as velocity while using forces instead\nCFrame - Directly adjusts the position of the root\nTP - Large teleports within intervals\nPulse - Controllable bursts of speed\nWalkSpeed - The classic mode of speed, usually detected on most games.'
	})
	FloatMode = Fly:CreateDropdown({
		Name = 'Float Mode',
		List = {'Velocity', 'Impulse', 'CFrame', 'Bounce', 'Floor', 'Jump', 'TP'},
		Function = function(val)
			WallCheck.Object.Visible = Mode.Value == 'CFrame' or Mode.Value == 'TP' or val == 'CFrame' or val == 'TP'
			BounceLength.Object.Visible = val == 'Bounce'
			BounceDelay.Object.Visible = val == 'Bounce'
			VerticalValue.Object.Visible = val ~= 'Floor'
			FloatTPGround.Object.Visible = val == 'TP'
			FloatTPAir.Object.Visible = val == 'TP'
			if Platform then
				Platform:Destroy()
				Platform = nil
			end
			if val == 'Floor' then
				Platform = Instance.new('Part')
				Platform.CanQuery = false
				Platform.Anchored = true
				Platform.Size = Vector3.one
				Platform.Transparency = 1
				Platform.Parent = Fly.Enabled and gameCamera or nil
			end
		end,
		Tooltip = 'Velocity - Uses smooth physics based movement\nImpulse - Same as velocity while using forces instead\nCFrame - Directly adjusts the position of the root\nTP - Teleports you to the ground within intervals\nFloor - Spawns a part under you\nJump - Presses space after going below a certain Y Level\nBounce - Vertical bouncing motion'
	})
	local states = {'None'}
	for _, v in Enum.HumanoidStateType:GetEnumItems() do
		if v.Name ~= 'Dead' and v.Name ~= 'None' then
			table.insert(states, v.Name)
		end
	end
	State = Fly:CreateDropdown({
		Name = 'Humanoid State',
		List = states
	})
	MoveMethod = Fly:CreateDropdown({
		Name = 'Move Mode',
		List = {'MoveDirection', 'Direct'},
		Tooltip = 'MoveDirection - Uses the games input vector for movement\nDirect - Directly calculate our own input vector'
	})
	Keys = Fly:CreateDropdown({
		Name = 'Keys',
		List = {'Space/LeftControl', 'Space/LeftShift', 'E/Q', 'Space/Q', 'ButtonA/ButtonL2'},
		Tooltip = 'The key combination for going up & down'
	})
	Options.Value = Fly:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	VerticalValue = Fly:CreateSlider({
		Name = 'Vertical Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Options.TPFrequency = Fly:CreateSlider({
		Name = 'TP Frequency',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	Options.PulseLength = Fly:CreateSlider({
		Name = 'Pulse Length',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	Options.PulseDelay = Fly:CreateSlider({
		Name = 'Pulse Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	BounceLength = Fly:CreateSlider({
		Name = 'Bounce Length',
		Min = 0,
		Max = 30,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	BounceDelay = Fly:CreateSlider({
		Name = 'Bounce Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	FloatTPGround = Fly:CreateSlider({
		Name = 'Ground',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Default = 0.1,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	FloatTPAir = Fly:CreateSlider({
		Name = 'Air',
		Min = 0,
		Max = 5,
		Decimal = 10,
		Default = 2,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	WallCheck = Fly:CreateToggle({
		Name = 'Wall Check',
		Default = true,
		Darker = true,
		Visible = false
	})
	Options.WallCheck = WallCheck
	PlatformStanding = Fly:CreateToggle({
		Name = 'PlatformStand',
		Function = function(callback)
			if Fly.Enabled then
				entitylib.character.Humanoid.PlatformStand = callback
			end
		end,
		Tooltip = 'Forces the character to look infront of the camera'
	})
	CustomProperties = Fly:CreateToggle({
		Name = 'Custom Properties',
		Function = function()
			if Fly.Enabled then
				Fly:Toggle()
				Fly:Toggle()
			end
		end,
		Default = true
	})
end)
	
run(function()
	local HighJump
	local Mode
	local Value
	local AutoDisable
	
	local function jump()
		local state = entitylib.isAlive and entitylib.character.Humanoid:GetState() or nil
	
		if state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed then
			local root = entitylib.character.RootPart
	
			if Mode.Value == 'Velocity' then
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, Value.Value, root.AssemblyLinearVelocity.Z)
			elseif Mode.Value == 'Impulse' then
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				task.delay(0, function()
					root:ApplyImpulse(Vector3.new(0, Value.Value - root.AssemblyLinearVelocity.Y, 0) * root.AssemblyMass)
				end)
			else
				local start = math.max(Value.Value - entitylib.character.Humanoid.JumpHeight, 0)
				repeat
					root.CFrame += Vector3.new(0, start * 0.016, 0)
					start = start - (workspace.Gravity * 0.016)
					if Mode.Value == 'CFrame' then
						task.wait()
					end
				until start <= 0
			end
		end
	end
	
	HighJump = vape.Categories.Blatant:CreateModule({
		Name = 'HighJump',
		Function = function(callback)
			if callback then
				if AutoDisable.Enabled then
					jump()
					HighJump:Toggle()
				else
					HighJump:Clean(runService.RenderStepped:Connect(function()
						if not inputService:GetFocusedTextBox() and inputService:IsKeyDown(Enum.KeyCode.Space) then
							jump()
						end
					end))
				end
			end
		end,
		ExtraText = function()
			return Mode.Value
		end,
		Tooltip = 'Lets you jump higher'
	})
	Mode = HighJump:CreateDropdown({
		Name = 'Mode',
		List = {'Impulse', 'Velocity', 'CFrame', 'Instant'},
		Tooltip = 'Velocity - Uses smooth movement to boost you upward\nImpulse - Same as velocity while using forces instead\nCFrame - Directly adjusts the position upward\nInstant - Teleports you to the peak of the jump'
	})
	Value = HighJump:CreateSlider({
		Name = 'Velocity',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AutoDisable = HighJump:CreateToggle({
		Name = 'Auto Disable',
		Default = true
	})
end)
	
run(function()
	local HitBoxes
	local Targets
	local TargetPart
	local Expand
	local modified = {}
	
	HitBoxes = vape.Categories.Blatant:CreateModule({
		Name = 'HitBoxes',
		Function = function(callback)
			if callback then
				repeat
					for _, v in entitylib.List do
						if v.Targetable then
							if not Targets.Players.Enabled and v.Player then continue end
							if not Targets.NPCs.Enabled and v.NPC then continue end
							local part = v[TargetPart.Value]
							if not modified[part] then
								modified[part] = part.Size
							end
							part.Size = modified[part] + Vector3.new(Expand.Value, Expand.Value, Expand.Value)
						end
					end
					task.wait()
				until not HitBoxes.Enabled
			else
				for i, v in modified do
					i.Size = v
				end
				table.clear(modified)
			end
		end,
		Tooltip = 'Expands entities hitboxes'
	})
	Targets = HitBoxes:CreateTargets({Players = true})
	TargetPart = HitBoxes:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head'}
	})
	Expand = HitBoxes:CreateSlider({
		Name = 'Expand amount',
		Min = 0,
		Max = 2,
		Decimal = 10,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)
	
run(function()
	local Invisible
	local clone, oldroot, hip, valid
	local animtrack
	local proper = true
	
	local function doClone()
		if entitylib.isAlive and entitylib.character.Humanoid.Health > 0 then
			hip = entitylib.character.Humanoid.HipHeight
			oldroot = entitylib.character.HumanoidRootPart
			if not lplr.Character.Parent then
				return false
			end
	
			lplr.Character.Parent = game
			clone = oldroot:Clone()
			clone.Parent = lplr.Character
			oldroot.Parent = gameCamera
			clone.CFrame = oldroot.CFrame
	
			lplr.Character.PrimaryPart = clone
			entitylib.character.HumanoidRootPart = clone
			entitylib.character.RootPart = clone
			lplr.Character.Parent = workspace
	
			for _, v in lplr.Character:GetDescendants() do
				if v:IsA('Weld') or v:IsA('Motor6D') then
					if v.Part0 == oldroot then
						v.Part0 = clone
					end
					if v.Part1 == oldroot then
						v.Part1 = clone
					end
				end
			end
	
			return true
		end
	
		return false
	end
	
	local function revertClone()
		if not oldroot or not oldroot:IsDescendantOf(workspace) or not entitylib.isAlive then
			return false
		end
	
		lplr.Character.Parent = game
		oldroot.Parent = lplr.Character
		lplr.Character.PrimaryPart = oldroot
		entitylib.character.HumanoidRootPart = oldroot
		entitylib.character.RootPart = oldroot
		lplr.Character.Parent = workspace
		oldroot.CanCollide = true
	
		for _, v in lplr.Character:GetDescendants() do
			if v:IsA('Weld') or v:IsA('Motor6D') then
				if v.Part0 == clone then
					v.Part0 = oldroot
				end
				if v.Part1 == clone then
					v.Part1 = oldroot
				end
			end
		end
	
		local oldpos = clone.CFrame
		if clone then
			clone:Destroy()
			clone = nil
		end
	
		oldroot.CFrame = oldpos
		oldroot = nil
		entitylib.character.Humanoid.HipHeight = hip or 2
	end
	
	local function animationTrickery()
		if entitylib.isAlive then
			local anim = Instance.new('Animation')
			anim.AnimationId = 'http://www.roblox.com/asset/?id=18537363391'
			animtrack = entitylib.character.Humanoid.Animator:LoadAnimation(anim)
			animtrack.Priority = Enum.AnimationPriority.Action4
			animtrack:Play(0, 1, 0)
			anim:Destroy()
			animtrack.Stopped:Connect(function()
				if Invisible.Enabled then
					animationTrickery()
				end
			end)
	
			task.delay(0, function()
				animtrack.TimePosition = 0.77
				task.delay(1, function()
					animtrack:AdjustSpeed(math.huge)
				end)
			end)
		end
	end
	
	Invisible = vape.Categories.Blatant:CreateModule({
		Name = 'Invisible',
		Function = function(callback)
			if callback then
				if not proper then
					notif('Invisible', 'Broken state detected', 3, 'alert')
					Invisible:Toggle()
					return
				end
	
				success = doClone()
				if not success then
					Invisible:Toggle()
					return
				end
	
				animationTrickery()
				Invisible:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive and oldroot then
						local root = entitylib.character.RootPart
						local cf = root.CFrame - Vector3.new(0, entitylib.character.Humanoid.HipHeight + (root.Size.Y / 2) - 1, 0)
	
						if not isnetworkowner(oldroot) then
							root.CFrame = oldroot.CFrame
							root.Velocity = oldroot.Velocity
							return
						end
	
						oldroot.CFrame = cf * CFrame.Angles(math.rad(180), 0, 0)
						oldroot.Velocity = root.Velocity
						oldroot.CanCollide = false
					end
				end))
	
				Invisible:Clean(entitylib.Events.LocalAdded:Connect(function(char)
					local animator = char.Humanoid:WaitForChild('Animator', 1)
					if animator and Invisible.Enabled then
						oldroot = nil
						Invisible:Toggle()
						Invisible:Toggle()
					end
				end))
			else
				if animtrack then
					animtrack:Stop()
					animtrack:Destroy()
				end
	
				if success and clone and oldroot and proper then
					proper = true
					if oldroot and clone then
						revertClone()
					end
				end
			end
		end,
		Tooltip = 'Turns you invisible.'
	})
end)
	
run(function()
	local Killaura
	local Targets
	local CPS
	local SwingRange
	local AttackRange
	local AngleSlider
	local Max
	local Mouse
	local Lunge
	local BoxSwingColor
	local BoxAttackColor
	local ParticleTexture
	local ParticleColor1
	local ParticleColor2
	local ParticleSize
	local Face
	local Overlay = OverlapParams.new()
	Overlay.FilterType = Enum.RaycastFilterType.Include
	local Particles, Boxes, AttackDelay = {}, {}, tick()
	
	local function getAttackData()
		if Mouse.Enabled then
			if not inputService:IsMouseButtonPressed(0) then return false end
		end
	
		local tool = getTool()
		return tool and tool:FindFirstChildWhichIsA('TouchTransmitter', true) or nil, tool
	end
	
	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'Killaura',
		Function = function(callback)
			if callback then
				repeat
					local interest, tool = getAttackData()
					local attacked = {}
					if interest then
						local plrs = entitylib.AllPosition({
							Range = SwingRange.Value,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Limit = Max.Value
						})
	
						if #plrs > 0 then
							local selfpos = entitylib.character.RootPart.Position
							local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
	
							for _, v in plrs do
								local delta = (v.RootPart.Position - selfpos)
								local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
								if angle > (math.rad(AngleSlider.Value) / 2) then continue end
	
								table.insert(attacked, {
									Entity = v,
									Check = delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor
								})
								targetinfo.Targets[v] = tick() + 1
	
								if AttackDelay < tick() then
									AttackDelay = tick() + (1 / CPS.GetRandomValue())
									tool:Activate()
								end
	
								if Lunge.Enabled and tool.GripUp.X == 0 then break end
								if delta.Magnitude > AttackRange.Value then continue end
	
								Overlay.FilterDescendantsInstances = {v.Character}
								for _, part in workspace:GetPartBoundsInBox(v.RootPart.CFrame, Vector3.new(4, 4, 4), Overlay) do
									firetouchinterest(interest.Parent, part, 1)
									firetouchinterest(interest.Parent, part, 0)
								end
							end
						end
					end
	
					for i, v in Boxes do
						v.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
						if v.Adornee then
							v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
							v.Transparency = 1 - attacked[i].Check.Opacity
						end
					end
	
					for i, v in Particles do
						v.Position = attacked[i] and attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
						v.Parent = attacked[i] and gameCamera or nil
					end
	
					if Face.Enabled and attacked[1] then
						local vec = attacked[1].Entity.RootPart.Position * Vector3.new(1, 0, 1)
						entitylib.character.RootPart.CFrame = CFrame.lookAt(entitylib.character.RootPart.Position, Vector3.new(vec.X, entitylib.character.RootPart.Position.Y + 0.01, vec.Z))
					end
	
					task.wait()
				until not Killaura.Enabled
			else
				for _, v in Boxes do
					v.Adornee = nil
				end
				for _, v in Particles do
					v.Parent = nil
				end
			end
		end,
		Tooltip = 'Attack players around you\nwithout aiming at them.'
	})
	Targets = Killaura:CreateTargets({Players = true})
	CPS = Killaura:CreateTwoSlider({
		Name = 'Attacks per Second',
		Min = 1,
		Max = 20,
		DefaultMin = 12,
		DefaultMax = 12
	})
	SwingRange = Killaura:CreateSlider({
		Name = 'Swing range',
		Min = 1,
		Max = 30,
		Default = 13,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AttackRange = Killaura:CreateSlider({
		Name = 'Attack range',
		Min = 1,
		Max = 30,
		Default = 13,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AngleSlider = Killaura:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 90
	})
	Max = Killaura:CreateSlider({
		Name = 'Max targets',
		Min = 1,
		Max = 10,
		Default = 10
	})
	Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
	Lunge = Killaura:CreateToggle({Name = 'Sword lunge only'})
	Killaura:CreateToggle({
		Name = 'Show target',
		Function = function(callback)
			BoxSwingColor.Object.Visible = callback
			BoxAttackColor.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local box = Instance.new('BoxHandleAdornment')
					box.Adornee = nil
					box.AlwaysOnTop = true
					box.Size = Vector3.new(3, 5, 3)
					box.CFrame = CFrame.new(0, -0.5, 0)
					box.ZIndex = 0
					box.Parent = vape.gui
					Boxes[i] = box
				end
			else
				for _, v in Boxes do
					v:Destroy()
				end
				table.clear(Boxes)
			end
		end
	})
	BoxSwingColor = Killaura:CreateColorSlider({
		Name = 'Target Color',
		Darker = true,
		DefaultHue = 0.6,
		DefaultOpacity = 0.5,
		Visible = false
	})
	BoxAttackColor = Killaura:CreateColorSlider({
		Name = 'Attack Color',
		Darker = true,
		DefaultOpacity = 0.5,
		Visible = false
	})
	Killaura:CreateToggle({
		Name = 'Target particles',
		Function = function(callback)
			ParticleTexture.Object.Visible = callback
			ParticleColor1.Object.Visible = callback
			ParticleColor2.Object.Visible = callback
			ParticleSize.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local part = Instance.new('Part')
					part.Size = Vector3.new(2, 4, 2)
					part.Anchored = true
					part.CanCollide = false
					part.Transparency = 1
					part.CanQuery = false
					part.Parent = Killaura.Enabled and gameCamera or nil
					local particles = Instance.new('ParticleEmitter')
					particles.Brightness = 1.5
					particles.Size = NumberSequence.new(ParticleSize.Value)
					particles.Shape = Enum.ParticleEmitterShape.Sphere
					particles.Texture = ParticleTexture.Value
					particles.Transparency = NumberSequence.new(0)
					particles.Lifetime = NumberRange.new(0.4)
					particles.Speed = NumberRange.new(16)
					particles.Rate = 128
					particles.Drag = 16
					particles.ShapePartial = 1
					particles.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
					})
					particles.Parent = part
					Particles[i] = part
				end
			else
				for _, v in Particles do
					v:Destroy()
				end
				table.clear(Particles)
			end
		end
	})
	ParticleTexture = Killaura:CreateTextBox({
		Name = 'Texture',
		Default = 'rbxassetid://14736249347',
		Function = function()
			for _, v in Particles do
				v.ParticleEmitter.Texture = ParticleTexture.Value
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor1 = Killaura:CreateColorSlider({
		Name = 'Color Begin',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor2 = Killaura:CreateColorSlider({
		Name = 'Color End',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleSize = Killaura:CreateSlider({
		Name = 'Size',
		Min = 0,
		Max = 1,
		Default = 0.2,
		Decimal = 100,
		Function = function(val)
			for _, v in Particles do
				v.ParticleEmitter.Size = NumberSequence.new(val)
			end
		end,
		Darker = true,
		Visible = false
	})
	Face = Killaura:CreateToggle({Name = 'Face target'})
end)
	
run(function()
	local Mode
	local Value
	local AutoDisable
	
	LongJump = vape.Categories.Blatant:CreateModule({
		Name = 'LongJump',
		Function = function(callback)
			if callback then
				local exempt = tick() + 0.1
				LongJump:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive then
						if entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
							if exempt < tick() and AutoDisable.Enabled then
								if LongJump.Enabled then
									LongJump:Toggle()
								end
							else
								entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
							end
						end
	
						local root = entitylib.character.RootPart
						local dir = entitylib.character.Humanoid.MoveDirection * Value.Value
						if Mode.Value == 'Velocity' then
							root.AssemblyLinearVelocity = dir + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
						elseif Mode.Value == 'Impulse' then
							local diff = (dir - root.AssemblyLinearVelocity) * Vector3.new(1, 0, 1)
							if diff.Magnitude > (dir == Vector3.zero and 10 or 2) then
								root:ApplyImpulse(diff * root.AssemblyMass)
							end
						else
							root.CFrame += dir * dt
						end
					end
				end))
			end
		end,
		ExtraText = function()
			return Mode.Value
		end,
		Tooltip = 'Lets you jump farther'
	})
	Mode = LongJump:CreateDropdown({
		Name = 'Mode',
		List = {'Velocity', 'Impulse', 'CFrame'},
		Tooltip = 'Velocity - Uses smooth physics based movement\nImpulse - Same as velocity while using forces instead\nCFrame - Directly adjusts the position of the root'
	})
	Value = LongJump:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AutoDisable = LongJump:CreateToggle({
		Name = 'Auto Disable',
		Default = true
	})
end)
	
run(function()
	local MouseTP
	local Mode
	local MovementMode
	local Length
	local Delay
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	
	local function getWaypointInMouse()
		local returned, distance, mouseLocation = nil, math.huge, inputService:GetMouseLocation()
		for _, v in WaypointFolder:GetChildren() do
			local position, vis = gameCamera:WorldToViewportPoint(v.StudsOffsetWorldSpace)
			if not vis then continue end
			local mag = (mouseLocation - Vector2.new(position.x, position.y)).Magnitude
			if mag < distance then
				returned, distance = v, mag
			end
		end
		return returned
	end
	
	MouseTP = vape.Categories.Blatant:CreateModule({
		Name = 'MouseTP',
		Function = function(callback)
			if callback then
				local position
				if Mode.Value == 'Mouse' then
					local ray = cloneref(lplr:GetMouse()).UnitRay
					rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
					ray = workspace:Raycast(ray.Origin, ray.Direction * 10000, rayCheck)
					position = ray and ray.Position + Vector3.new(0, entitylib.character.HipHeight or 2, 0)
				elseif Mode.Value == 'Waypoint' then
					local waypoint = getWaypointInMouse()
					position = waypoint and waypoint.StudsOffsetWorldSpace
				else
					local ent = entitylib.EntityMouse({
						Range = math.huge,
						Part = 'RootPart',
						Players = true
					})
					position = ent and ent.RootPart.Position
				end
	
				if not position then
					notif('MouseTP', 'No position found.', 5)
					MouseTP:Toggle()
					return
				end
	
				if MovementMode.Value ~= 'Lerp' then
					MouseTP:Toggle()
					if entitylib.isAlive then
						if MovementMode.Value == 'Motor' then
							motorMove(entitylib.character.RootPart, CFrame.lookAlong(position, entitylib.character.RootPart.CFrame.LookVector))
						else
							entitylib.character.RootPart.CFrame = CFrame.lookAlong(position, entitylib.character.RootPart.CFrame.LookVector)
						end
					end
				else
					MouseTP:Clean(runService.Heartbeat:Connect(function()
						if entitylib.isAlive then
							entitylib.character.RootPart.Velocity = Vector3.zero
						end
					end))
	
					repeat
						if entitylib.isAlive then
							local direction = CFrame.lookAt(entitylib.character.RootPart.Position, position).LookVector * math.min((entitylib.character.RootPart.Position - position).Magnitude, Length.Value)
							entitylib.character.RootPart.CFrame += direction
							if (entitylib.character.RootPart.Position - position).Magnitude < 3 and MouseTP.Enabled then
								MouseTP:Toggle()
							end
						elseif MouseTP.Enabled then
							MouseTP:Toggle()
							notif('MouseTP', 'Character missing', 5, 'warning')
						end
	
						task.wait(Delay.Value)
					until not MouseTP.Enabled
				end
			end
		end,
		Tooltip = 'Teleports to a selected position.'
	})
	Mode = MouseTP:CreateDropdown({
		Name = 'Mode',
		List = {'Mouse', 'Player', 'Waypoint'}
	})
	MovementMode = MouseTP:CreateDropdown({
		Name = 'Movement',
		List = {'CFrame', 'Motor', 'Lerp'},
		Function = function(val)
			Length.Object.Visible = val == 'Lerp'
			Delay.Object.Visible = val == 'Lerp'
		end
	})
	Length = MouseTP:CreateSlider({
		Name = 'Length',
		Min = 0,
		Max = 150,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Delay = MouseTP:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
end)
	
run(function()
	local Mode
	local StudLimit = {Object = {}}
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local overlapCheck = OverlapParams.new()
	overlapCheck.MaxParts = 9e9
	local modified, fflag = {}
	local teleported
	
	local function grabClosestNormal(ray)
		local partCF, mag, closest = ray.Instance.CFrame, 0, Enum.NormalId.Top
		for _, normal in Enum.NormalId:GetEnumItems() do
			local dot = partCF:VectorToWorldSpace(Vector3.fromNormalId(normal)):Dot(ray.Normal)
			if dot > mag then
				mag, closest = dot, normal
			end
		end
		return Vector3.fromNormalId(closest).X ~= 0 and 'X' or 'Z'
	end
	
	local Functions = {
		Part = function()
			local chars = {gameCamera, lplr.Character}
			for _, v in entitylib.List do
				table.insert(chars, v.Character)
			end
			overlapCheck.FilterDescendantsInstances = chars
	
			local parts = workspace:GetPartBoundsInBox(entitylib.character.RootPart.CFrame + Vector3.new(0, 1, 0), entitylib.character.RootPart.Size + Vector3.new(1, entitylib.character.HipHeight, 1), overlapCheck)
			for _, part in parts do
				if part.CanCollide and (not Spider.Enabled or SpiderShift) then
					modified[part] = true
					part.CanCollide = false
				end
			end
	
			for part in modified do
				if not table.find(parts, part) then
					modified[part] = nil
					part.CanCollide = true
				end
			end
		end,
		Character = function()
			for _, part in lplr.Character:GetDescendants() do
				if part:IsA('BasePart') and part.CanCollide and (not Spider.Enabled or SpiderShift) then
					modified[part] = true
					part.CanCollide = Spider.Enabled and not SpiderShift
				end
			end
		end,
		CFrame = function()
			local chars = {gameCamera, lplr.Character}
			for _, v in entitylib.List do
				table.insert(chars, v.Character)
			end
			rayCheck.FilterDescendantsInstances = chars
			overlapCheck.FilterDescendantsInstances = chars
	
			local ray = workspace:Raycast(entitylib.character.Head.CFrame.Position, entitylib.character.Humanoid.MoveDirection * 1.1, rayCheck)
			if ray and (not Spider.Enabled or SpiderShift) then
				local phaseDirection = grabClosestNormal(ray)
				if ray.Instance.Size[phaseDirection] <= StudLimit.Value then
					local root = entitylib.character.RootPart
					local dest = root.CFrame + (ray.Normal * (-(ray.Instance.Size[phaseDirection]) - (root.Size.X / 1.5)))
	
					if #workspace:GetPartBoundsInBox(dest, Vector3.one, overlapCheck) <= 0 then
						if Mode.Value == 'Motor' then
							motorMove(root, dest)
						else
							root.CFrame = dest
						end
					end
				end
			end
		end,
		FFlag = function()
			if teleported then return end
			setfflag('AssemblyExtentsExpansionStudHundredth', '-10000')
			fflag = true
		end
	}
	Functions.Motor = Functions.CFrame
	
	Phase = vape.Categories.Blatant:CreateModule({
		Name = 'Phase',
		Function = function(callback)
			if callback then
				Phase:Clean(runService.Stepped:Connect(function()
					if entitylib.isAlive then
						Functions[Mode.Value]()
					end
				end))
	
				if Mode.Value == 'FFlag' then
					Phase:Clean(lplr.OnTeleport:Connect(function()
						teleported = true
						setfflag('AssemblyExtentsExpansionStudHundredth', '30')
					end))
				end
			else
				if fflag then
					setfflag('AssemblyExtentsExpansionStudHundredth', '30')
				end
				for part in modified do
					part.CanCollide = true
				end
				table.clear(modified)
				fflag = nil
			end
		end,
		Tooltip = 'Lets you Phase/Clip through walls. (Hold shift to use Phase over spider)'
	})
	Mode = Phase:CreateDropdown({
		Name = 'Mode',
		List = {'Part', 'Character', 'CFrame', 'Motor', 'FFlag'},
		Function = function(val)
			StudLimit.Object.Visible = val == 'CFrame' or val == 'Motor'
			if fflag then
				setfflag('AssemblyExtentsExpansionStudHundredth', '30')
			end
			for part in modified do
				part.CanCollide = true
			end
			table.clear(modified)
			fflag = nil
		end,
		Tooltip = 'Part - Modifies parts collision status around you\nCharacter - Modifies the local collision status of the character\nCFrame - Teleports you past parts\nMotor - Same as CFrame with a bypass\nFFlag - Directly adjusts all physics collisions'
	})
	StudLimit = Phase:CreateSlider({
		Name = 'Wall Size',
		Min = 1,
		Max = 20,
		Default = 5,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Darker = true,
		Visible = false
	})
end)
	
run(function()
	local Speed
	local Mode
	local Options
	local AutoJump
	local AutoJumpCustom
	local AutoJumpValue
	local w, s, a, d = 0, 0, 0, 0
	
	Speed = vape.Categories.Blatant:CreateModule({
		Name = 'Speed',
		Function = function(callback)
			frictionTable.Speed = callback and CustomProperties.Enabled or nil
			updateVelocity()
			if callback then
				Speed:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive and not Fly.Enabled and not LongJump.Enabled then
						local state = entitylib.character.Humanoid:GetState()
						if state == Enum.HumanoidStateType.Climbing then return end
	
						local movevec = TargetStrafeVector or Options.MoveMethod.Value == 'Direct' and calculateMoveVector(Vector3.new(a + d, 0, w + s)) or entitylib.character.Humanoid.MoveDirection
						SpeedMethods[Mode.Value](Options, movevec, dt)
						if AutoJump.Enabled and entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air and movevec ~= Vector3.zero then
							if AutoJumpCustom.Enabled then
								local velocity = entitylib.character.RootPart.Velocity * Vector3.new(1, 0, 1)
								entitylib.character.RootPart.Velocity = Vector3.new(velocity.X, AutoJumpValue.Value, velocity.Z)
							else
								entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
							end
						end
					end
				end))
	
				w, s, a, d = inputService:IsKeyDown(Enum.KeyCode.W) and -1 or 0, inputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0, inputService:IsKeyDown(Enum.KeyCode.A) and -1 or 0, inputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0
				for _, v in {'InputBegan', 'InputEnded'} do
					Speed:Clean(inputService[v]:Connect(function(input)
						if not inputService:GetFocusedTextBox() then
							if input.KeyCode == Enum.KeyCode.W then
								w = v == 'InputBegan' and -1 or 0
							elseif input.KeyCode == Enum.KeyCode.S then
								s = v == 'InputBegan' and 1 or 0
							elseif input.KeyCode == Enum.KeyCode.A then
								a = v == 'InputBegan' and -1 or 0
							elseif input.KeyCode == Enum.KeyCode.D then
								d = v == 'InputBegan' and 1 or 0
							end
						end
					end))
				end
			else
				if Options.WalkSpeed and entitylib.isAlive then
					entitylib.character.Humanoid.WalkSpeed = Options.WalkSpeed
				end
				Options.WalkSpeed = nil
			end
		end,
		ExtraText = function()
			return Mode.Value
		end,
		Tooltip = 'Increases your movement with various methods.'
	})
	Mode = Speed:CreateDropdown({
		Name = 'Mode',
		List = SpeedMethodList,
		Function = function(val)
			Options.WallCheck.Object.Visible = val == 'CFrame' or val == 'TP'
			Options.TPFrequency.Object.Visible = val == 'TP'
			Options.PulseLength.Object.Visible = val == 'Pulse'
			Options.PulseDelay.Object.Visible = val == 'Pulse'
			if Speed.Enabled then
				Speed:Toggle()
				Speed:Toggle()
			end
		end,
		Tooltip = 'Velocity - Uses smooth physics based movement\nImpulse - Same as velocity while using forces instead\nCFrame - Directly adjusts the position of the root\nTP - Large teleports within intervals\nPulse - Controllable bursts of speed\nWalkSpeed - The classic mode of speed, usually detected on most games.'
	})
	Options = {
		MoveMethod = Speed:CreateDropdown({
			Name = 'Move Mode',
			List = {'MoveDirection', 'Direct'},
			Tooltip = 'MoveDirection - Uses the games input vector for movement\nDirect - Directly calculate our own input vector'
		}),
		Value = Speed:CreateSlider({
			Name = 'Speed',
			Min = 1,
			Max = 150,
			Default = 50,
			Suffix = function(val)
				return val == 1 and 'stud' or 'studs'
			end
		}),
		TPFrequency = Speed:CreateSlider({
			Name = 'TP Frequency',
			Min = 0,
			Max = 1,
			Decimal = 100,
			Darker = true,
			Visible = false,
			Suffix = function(val)
				return val == 1 and 'second' or 'seconds'
			end
		}),
		PulseLength = Speed:CreateSlider({
			Name = 'Pulse Length',
			Min = 0,
			Max = 1,
			Decimal = 100,
			Darker = true,
			Visible = false,
			Suffix = function(val)
				return val == 1 and 'second' or 'seconds'
			end
		}),
		PulseDelay = Speed:CreateSlider({
			Name = 'Pulse Delay',
			Min = 0,
			Max = 1,
			Decimal = 100,
			Darker = true,
			Visible = false,
			Suffix = function(val)
				return val == 1 and 'second' or 'seconds'
			end
		}),
		WallCheck = Speed:CreateToggle({
			Name = 'Wall Check',
			Default = true,
			Darker = true,
			Visible = false
		}),
		TPTiming = tick(),
		rayCheck = RaycastParams.new()
	}
	Options.rayCheck.RespectCanCollide = true
	CustomProperties = Speed:CreateToggle({
		Name = 'Custom Properties',
		Function = function()
			if Speed.Enabled then
				Speed:Toggle()
				Speed:Toggle()
			end
		end,
		Default = true
	})
	AutoJump = Speed:CreateToggle({
		Name = 'AutoJump',
		Function = function(callback)
			AutoJumpCustom.Object.Visible = callback
		end
	})
	AutoJumpCustom = Speed:CreateToggle({
		Name = 'Custom Jump',
		Function = function(callback)
			AutoJumpValue.Object.Visible = callback
		end,
		Tooltip = 'Allows you to adjust the jump power',
		Darker = true,
		Visible = false
	})
	AutoJumpValue = Speed:CreateSlider({
		Name = 'Jump Power',
		Min = 1,
		Max = 50,
		Default = 30,
		Darker = true,
		Visible = false
	})
end)
	
run(function()
	local Mode
	local Value
	local State
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local Active, Truss
	
	Spider = vape.Categories.Blatant:CreateModule({
		Name = 'Spider',
		Function = function(callback)
			if callback then
				if Truss then Truss.Parent = gameCamera end
				Spider:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						local chars = {gameCamera, lplr.Character, Truss}
						for _, v in entitylib.List do
							table.insert(chars, v.Character)
						end
						SpiderShift = inputService:IsKeyDown(Enum.KeyCode.LeftShift)
						rayCheck.FilterDescendantsInstances = chars
						rayCheck.CollisionGroup = root.CollisionGroup
	
						if Mode.Value ~= 'Part' then
							local vec = entitylib.character.Humanoid.MoveDirection * 2.5
							local ray = workspace:Raycast(root.Position - Vector3.new(0, entitylib.character.HipHeight - 0.5, 0), vec, rayCheck)
							if Active and not ray then
								root.Velocity = Vector3.new(root.Velocity.X, 0, root.Velocity.Z)
							end
	
							Active = ray
							if Active and ray.Normal.Y == 0 then
								if not Phase.Enabled or not SpiderShift then
									if State.Enabled then
										entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
									end
	
									root.Velocity *= Vector3.new(1, 0, 1)
									if Mode.Value == 'CFrame' then
										root.CFrame += Vector3.new(0, Value.Value * dt, 0)
									elseif Mode.Value == 'Impulse' then
										root:ApplyImpulse(Vector3.new(0, Value.Value, 0) * root.AssemblyMass)
									else
										root.Velocity += Vector3.new(0, Value.Value, 0)
									end
								end
							end
						else
							local ray = workspace:Raycast(root.Position - Vector3.new(0, entitylib.character.HipHeight - 0.5, 0), entitylib.character.RootPart.CFrame.LookVector * 2, rayCheck)
							if ray and (not Phase.Enabled or not SpiderShift) then
								Truss.Position = ray.Position - ray.Normal * 0.9 or Vector3.zero
							else
								Truss.Position = Vector3.zero
							end
						end
					end
				end))
			else
				if Truss then
					Truss.Parent = nil
				end
				SpiderShift = false
			end
		end,
		Tooltip = 'Lets you climb up walls. (Hold shift to use Phase over spider)'
	})
	Mode = Spider:CreateDropdown({
		Name = 'Mode',
		List = {'Velocity', 'Impulse', 'CFrame', 'Part'},
		Function = function(val)
			Value.Object.Visible = val ~= 'Part'
			State.Object.Visible = val ~= 'Part'
			if Truss then
				Truss:Destroy()
				Truss = nil
			end
			if val == 'Part' then
				Truss = Instance.new('TrussPart')
				Truss.Size = Vector3.new(2, 2, 2)
				Truss.Transparency = 1
				Truss.Anchored = true
				Truss.Parent = Spider.Enabled and gameCamera or nil
			end
		end,
		Tooltip = 'Velocity - Uses smooth movement to boost you upward\nCFrame - Directly adjusts the position upward\nPart - Positions a climbable part infront of you'
	})
	Value = Spider:CreateSlider({
		Name = 'Speed',
		Min = 0,
		Max = 100,
		Default = 30,
		Darker = true,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	State = Spider:CreateToggle({
		Name = 'Climb State',
		Darker = true
	})
end)
	
run(function()
	local SpinBot
	local Mode
	local XToggle
	local YToggle
	local ZToggle
	local Value
	local AngularVelocity
	
	SpinBot = vape.Categories.Blatant:CreateModule({
		Name = 'SpinBot',
		Function = function(callback)
			if callback then
				SpinBot:Clean(runService.PreSimulation:Connect(function()
					if entitylib.isAlive then
						if Mode.Value == 'RotVelocity' then
							local originalRotVelocity = entitylib.character.RootPart.RotVelocity
							entitylib.character.Humanoid.AutoRotate = false
							entitylib.character.RootPart.RotVelocity = Vector3.new(XToggle.Enabled and Value.Value or originalRotVelocity.X, YToggle.Enabled and Value.Value or originalRotVelocity.Y, ZToggle.Enabled and Value.Value or originalRotVelocity.Z)
						elseif Mode.Value == 'CFrame' then
							local val = math.rad((tick() * (20 * Value.Value)) % 360)
							local x, y, z = entitylib.character.RootPart.CFrame:ToOrientation()
							entitylib.character.RootPart.CFrame = CFrame.new(entitylib.character.RootPart.Position) * CFrame.Angles(XToggle.Enabled and val or x, YToggle.Enabled and val or y, ZToggle.Enabled and val or z)
						elseif AngularVelocity then
							AngularVelocity.Parent = entitylib.isAlive and entitylib.character.RootPart
							AngularVelocity.MaxTorque = Vector3.new(XToggle.Enabled and math.huge or 0, YToggle.Enabled and math.huge or 0, ZToggle.Enabled and math.huge or 0)
							AngularVelocity.AngularVelocity = Vector3.new(Value.Value, Value.Value, Value.Value)
						end
					end
				end))
			else
				if entitylib.isAlive and Mode.Value == 'RotVelocity' then
					entitylib.character.Humanoid.AutoRotate = true
				end
				if AngularVelocity then
					AngularVelocity.Parent = nil
				end
			end
		end,
		Tooltip = 'Makes your character spin around in circles (does not work in first person)'
	})
	Mode = SpinBot:CreateDropdown({
		Name = 'Mode',
		List = {'CFrame', 'RotVelocity', 'BodyMover'},
		Function = function(val)
			if AngularVelocity then
				AngularVelocity:Destroy()
				AngularVelocity = nil
			end
			AngularVelocity = val == 'BodyMover' and Instance.new('BodyAngularVelocity') or nil
		end
	})
	Value = SpinBot:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 100,
		Default = 40
	})
	XToggle = SpinBot:CreateToggle({Name = 'Spin X'})
	YToggle = SpinBot:CreateToggle({
		Name = 'Spin Y',
		Default = true
	})
	ZToggle = SpinBot:CreateToggle({Name = 'Spin Z'})
end)
	
run(function()
	local Swim
	local terrain = cloneref(workspace:FindFirstChildWhichIsA('Terrain'))
	local lastpos = Region3.new(Vector3.zero, Vector3.zero)
	
	Swim = vape.Categories.Blatant:CreateModule({
		Name = 'Swim',
		Function = function(callback)
			if callback then
				Swim:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						local moving = entitylib.character.Humanoid.MoveDirection ~= Vector3.zero
						local rootvelo = root.Velocity
						local space = inputService:IsKeyDown(Enum.KeyCode.Space)
	
						if terrain then
							local factor = (moving or space) and Vector3.new(6, 6, 6) or Vector3.new(2, 1, 2)
							local pos = root.Position - Vector3.new(0, 1, 0)
							local newpos = Region3.new(pos - factor, pos + factor):ExpandToGrid(4)
							terrain:ReplaceMaterial(lastpos, 4, Enum.Material.Water, Enum.Material.Air)
							terrain:FillRegion(newpos, 4, Enum.Material.Water)
							lastpos = newpos
						end
					end
				end))
			else
				if terrain and lastpos then
					terrain:ReplaceMaterial(lastpos, 4, Enum.Material.Water, Enum.Material.Air)
				end
			end
		end,
		Tooltip = 'Lets you swim midair'
	})
end)
	
run(function()
	local TargetStrafe
	local Targets
	local SearchRange
	local StrafeRange
	local YFactor
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local module, old
	
	TargetStrafe = vape.Categories.Blatant:CreateModule({
		Name = 'TargetStrafe',
		Function = function(callback)
			if callback then
				if not module then
					local suc = pcall(function() module = require(lplr.PlayerScripts.PlayerModule).controls end)
					if not suc then
						module = {}
					end
				end
				
				old = module.moveFunction
				local flymod, ang, oldent = vape.Modules.Fly or {Enabled = false}
				module.moveFunction = function(self, vec, face)
					local wallcheck = Targets.Walls.Enabled
					local ent = not inputService:IsKeyDown(Enum.KeyCode.S) and entitylib.EntityPosition({
						Range = SearchRange.Value,
						Wallcheck = wallcheck,
						Part = 'RootPart',
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled
					})
	
					if ent then
						local root, targetPos = entitylib.character.RootPart, ent.RootPart.Position
						rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, ent.Character}
						rayCheck.CollisionGroup = root.CollisionGroup
	
						if flymod.Enabled or workspace:Raycast(targetPos, Vector3.new(0, -70, 0), rayCheck) then
							local factor, localPosition = 0, root.Position
							if ent ~= oldent then
								ang = math.deg(select(2, CFrame.lookAt(targetPos, localPosition):ToEulerAnglesYXZ()))
							end
							local yFactor = math.abs(localPosition.Y - targetPos.Y) * (YFactor.Value / 100)
							local entityPos = Vector3.new(targetPos.X, localPosition.Y, targetPos.Z)
							local newPos = entityPos + (CFrame.Angles(0, math.rad(ang), 0).LookVector * (StrafeRange.Value - yFactor))
							local startRay, endRay = entityPos, newPos
	
							if not wallcheck and workspace:Raycast(targetPos, (localPosition - targetPos), rayCheck) then
								startRay, endRay = entityPos + (CFrame.Angles(0, math.rad(ang), 0).LookVector * (entityPos - localPosition).Magnitude), entityPos
							end
	
							local ray = workspace:Blockcast(CFrame.new(startRay), Vector3.new(1, entitylib.character.HipHeight + (root.Size.Y / 2), 1), (endRay - startRay), rayCheck)
							if (localPosition - newPos).Magnitude < 3 or ray then
								factor = (8 - math.min((localPosition - newPos).Magnitude, 3))
								if ray then
									newPos = ray.Position + (ray.Normal * 1.5)
									factor = (localPosition - newPos).Magnitude > 3 and 0 or factor
								end
							end
	
							if not flymod.Enabled and not workspace:Raycast(newPos, Vector3.new(0, -70, 0), rayCheck) then
								newPos = entityPos
								factor = 40
							end
	
							ang += factor % 360
							vec = ((newPos - localPosition) * Vector3.new(1, 0, 1)).Unit
							vec = vec == vec and vec or Vector3.zero
							TargetStrafeVector = vec
						else
							ent = nil
						end
					end
	
					TargetStrafeVector = ent and vec or nil
					oldent = ent
					return old(self, vec, face)
				end
			else
				if module and old then
					module.moveFunction = old
				end
				TargetStrafeVector = nil
			end
		end,
		Tooltip = 'Automatically strafes around the opponent'
	})
	Targets = TargetStrafe:CreateTargets({
		Players = true,
		Walls = true
	})
	SearchRange = TargetStrafe:CreateSlider({
		Name = 'Search Range',
		Min = 1,
		Max = 30,
		Default = 24,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	StrafeRange = TargetStrafe:CreateSlider({
		Name = 'Strafe Range',
		Min = 1,
		Max = 30,
		Default = 18,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	YFactor = TargetStrafe:CreateSlider({
		Name = 'Y Factor',
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
end)
	
run(function()
	local Timer
	local Value
	
	Timer = vape.Categories.Blatant:CreateModule({
		Name = 'Timer',
		Function = function(callback)
			if callback then
				setfflag('SimEnableStepPhysics', 'True')
				setfflag('SimEnableStepPhysicsSelective', 'True')
				Timer:Clean(runService.RenderStepped:Connect(function(dt)
					if Value.Value > 1 then
						runService:Pause()
						workspace:StepPhysics(dt * (Value.Value - 1), {entitylib.character.RootPart})
						runService:Run()
					end
				end))
			end
		end,
		Tooltip = 'Change the game speed.'
	})
	Value = Timer:CreateSlider({
		Name = 'Value',
		Min = 1,
		Max = 3,
		Decimal = 10
	})
end)
	
run(function()
	local Arrows
	local Targets
	local Color
	local Teammates
	local Distance
	local DistanceLimit
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function Added(ent)
		if not Targets.Players.Enabled and ent.Player then return end
		if not Targets.NPCs.Enabled and ent.NPC then return end
		if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) and (not ent.Friend) then return end
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		local arrow = Instance.new('ImageLabel')
		arrow.Size = UDim2.fromOffset(256, 256)
		arrow.Position = UDim2.fromScale(0.5, 0.5)
		arrow.AnchorPoint = Vector2.new(0.5, 0.5)
		arrow.BackgroundTransparency = 1
		arrow.BorderSizePixel = 0
		arrow.Visible = false
		arrow.Image = 'rbxassetid://14473354880'
		arrow.ImageColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		arrow.Parent = Folder
		Reference[ent] = arrow
	end
	
	local function Removed(ent)
		local v = Reference[ent]
		if v then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			Reference[ent] = nil
			v:Destroy()
		end
	end
	
	local function ColorFunc(hue, sat, val)
		local color = Color3.fromHSV(hue, sat, val)
		for ent, EntityArrow in Reference do
			EntityArrow.ImageColor3 = entitylib.getEntityColor(ent) or color
		end
	end
	
	local function Loop()
		for ent, arrow in Reference do
			if Distance.Enabled then
				local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
				if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
					arrow.Visible = false
					continue
				end
			end
	
			local _, rootVis = gameCamera:WorldToScreenPoint(ent.RootPart.Position)
			arrow.Visible = not rootVis
			if rootVis then continue end
	
			local dir = CFrame.lookAlong(gameCamera.CFrame.Position, gameCamera.CFrame.LookVector * Vector3.new(1, 0, 1)):PointToObjectSpace(ent.RootPart.Position)
			arrow.Rotation = math.deg(math.atan2(dir.Z, dir.X))
		end
	end
	
	Arrows = vape.Categories.Render:CreateModule({
		Name = 'Arrows',
		Function = function(callback)
			if callback then
				Arrows:Clean(entitylib.Events.EntityRemoved:Connect(Removed))
				for _, v in entitylib.List do
					if Reference[v] then Removed(v) end
					Added(v)
				end
				Arrows:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
					if Reference[ent] then Removed(ent) end
					Added(ent)
				end))
				Arrows:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
					ColorFunc(Color.Hue, Color.Sat, Color.Value)
				end))
				Arrows:Clean(runService.RenderStepped:Connect(Loop))
			else
				for i in Reference do
					Removed(i)
				end
			end
		end,
		Tooltip = 'Draws arrows on screen when entities\nare out of your field of view.'
	})
	Targets = Arrows:CreateTargets({
		Players = true,
		Function = function()
			if Arrows.Enabled then
				Arrows:Toggle()
				Arrows:Toggle()
			end
		end
	})
	Color = Arrows:CreateColorSlider({
		Name = 'Player Color',
		Function = function(hue, sat, val)
			if Arrows.Enabled then
				ColorFunc(hue, sat, val)
			end
		end,
	})
	Teammates = Arrows:CreateToggle({
		Name = 'Priority Only',
		Function = function()
			if Arrows.Enabled then
				Arrows:Toggle()
				Arrows:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Hides teammates & non targetable entities'
	})
	Distance = Arrows:CreateToggle({
		Name = 'Distance Check',
		Function = function(callback)
			DistanceLimit.Object.Visible = callback
		end
	})
	DistanceLimit = Arrows:CreateTwoSlider({
		Name = 'Player Distance',
		Min = 0,
		Max = 256,
		DefaultMin = 0,
		DefaultMax = 64,
		Darker = true,
		Visible = false
	})
end)
	
run(function()
	local Chams
	local Targets
	local Mode
	local FillColor
	local OutlineColor
	local FillTransparency
	local OutlineTransparency
	local Teammates
	local Walls
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function Added(ent)
		if not Targets.Players.Enabled and ent.Player then return end
		if not Targets.NPCs.Enabled and ent.NPC then return end
		if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		if Mode.Value == 'Highlight' then
			local cham = Instance.new('Highlight')
			cham.Adornee = ent.Character
			cham.DepthMode = Enum.HighlightDepthMode[Walls.Enabled and 'AlwaysOnTop' or 'Occluded']
			cham.FillColor = entitylib.getEntityColor(ent) or Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
			cham.OutlineColor = Color3.fromHSV(OutlineColor.Hue, OutlineColor.Sat, OutlineColor.Value)
			cham.FillTransparency = FillTransparency.Value
			cham.OutlineTransparency = OutlineTransparency.Value
			cham.Parent = Folder
			Reference[ent] = cham
		else
			local chams = {}
			for _, v in ent.Character:GetChildren() do
				if v:IsA('BasePart') and (ent.NPC or v.Name:find('Arm') or v.Name:find('Leg') or v.Name:find('Hand') or v.Name:find('Feet') or v.Name:find('Torso') or v.Name == 'Head') then
					local box = Instance.new(v.Name == 'Head' and 'SphereHandleAdornment' or 'BoxHandleAdornment')
					if v.Name == 'Head' then
						box.Radius = 0.75
					else
						box.Size = v.Size
					end
					box.AlwaysOnTop = Walls.Enabled
					box.Adornee = v
					box.ZIndex = 0
					box.Transparency = FillTransparency.Value
					box.Color3 = entitylib.getEntityColor(ent) or Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
					box.Parent = Folder
					table.insert(chams, box)
				end
			end
			Reference[ent] = chams
		end
	end
	
	local function Removed(ent)
		if Reference[ent] then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			if type(Reference[ent]) == 'table' then
				for _, v in Reference[ent] do
					v:Destroy()
				end
				table.clear(Reference[ent])
			else
				Reference[ent]:Destroy()
			end
			Reference[ent] = nil
		end
	end
	
	Chams = vape.Categories.Render:CreateModule({
		Name = 'Chams',
		Function = function(callback)
			if callback then
				Chams:Clean(entitylib.Events.EntityRemoved:Connect(Removed))
				Chams:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
					if Reference[ent] then
						Removed(ent)
					end
					Added(ent)
				end))
				Chams:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
					for i, v in Reference do
						local color = entitylib.getEntityColor(i) or Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
						if type(v) == 'table' then
							for _, v2 in v do v2.Color3 = color end
						else
							v.FillColor = color
						end
					end
				end))
				for _, v in entitylib.List do
					if Reference[v] then
						Removed(v)
					end
					Added(v)
				end
			else
				for i in Reference do
					Removed(i)
				end
			end
		end,
		Tooltip = 'Render players through walls'
	})
	Targets = Chams:CreateTargets({
		Players = true,
		Function = function()
			if Chams.Enabled then
				Chams:Toggle()
				Chams:Toggle()
			end
		end
		})
	Mode = Chams:CreateDropdown({
		Name = 'Mode',
		List = {'Highlight', 'BoxHandles'},
		Function = function(val)
			OutlineColor.Object.Visible = val == 'Highlight'
			OutlineTransparency.Object.Visible = val == 'Highlight'
			if Chams.Enabled then
				Chams:Toggle()
				Chams:Toggle()
			end
		end
	})
	FillColor = Chams:CreateColorSlider({
		Name = 'Color',
		Function = function(hue, sat, val)
			for i, v in Reference do
				local color = entitylib.getEntityColor(i) or Color3.fromHSV(hue, sat, val)
				if type(v) == 'table' then
					for _, v2 in v do v2.Color3 = color end
				else
					v.FillColor = color
				end
			end
		end
	})
	OutlineColor = Chams:CreateColorSlider({
		Name = 'Outline Color',
		DefaultSat = 0,
		Function = function(hue, sat, val)
			for i, v in Reference do
				if type(v) ~= 'table' then
					v.OutlineColor = entitylib.getEntityColor(i) or Color3.fromHSV(hue, sat, val)
				end
			end
		end,
		Darker = true
	})
	FillTransparency = Chams:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Default = 0.5,
		Function = function(val)
			for _, v in Reference do
				if type(v) == 'table' then
					for _, v2 in v do v2.Transparency = val end
				else
					v.FillTransparency = val
				end
			end
		end,
		Decimal = 10
	})
	OutlineTransparency = Chams:CreateSlider({
		Name = 'Outline Transparency',
		Min = 0,
		Max = 1,
		Default = 0.5,
		Function = function(val)
			for _, v in Reference do
				if type(v) ~= 'table' then
					v.OutlineTransparency = val
				end
			end
		end,
		Decimal = 10,
		Darker = true
	})
	Walls = Chams:CreateToggle({
		Name = 'Render Walls',
		Function = function(callback)
			for _, v in Reference do
				if type(v) == 'table' then
					for _, v2 in v do
						v2.AlwaysOnTop = callback
					end
				else
					v.DepthMode = Enum.HighlightDepthMode[callback and 'AlwaysOnTop' or 'Occluded']
				end
			end
		end,
		Default = true
	})
	Teammates = Chams:CreateToggle({
		Name = 'Priority Only',
		Function = function()
			if Chams.Enabled then
				Chams:Toggle()
				Chams:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Hides teammates & non targetable entities'
	})
end)
	
run(function()
	local ESP
	local Targets
	local Color
	local Method
	local BoundingBox
	local Filled
	local HealthBar
	local Name
	local DisplayName
	local Background
	local Teammates
	local Distance
	local DistanceLimit
	local Reference = {}
	local methodused
	
	local function ESPWorldToViewport(pos)
		local newpos = gameCamera:WorldToViewportPoint(gameCamera.CFrame:pointToWorldSpace(gameCamera.CFrame:PointToObjectSpace(pos)))
		return Vector2.new(newpos.X, newpos.Y)
	end
	
	local ESPAdded = {
		Drawing2D = function(ent)
			if not Targets.Players.Enabled and ent.Player then return end
			if not Targets.NPCs.Enabled and ent.NPC then return end
			if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			local EntityESP = {}
			EntityESP.Main = Drawing.new('Square')
			EntityESP.Main.Transparency = BoundingBox.Enabled and 1 or 0
			EntityESP.Main.ZIndex = 2
			EntityESP.Main.Filled = false
			EntityESP.Main.Thickness = 1
			EntityESP.Main.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	
			if BoundingBox.Enabled then
				EntityESP.Border = Drawing.new('Square')
				EntityESP.Border.Transparency = 0.35
				EntityESP.Border.ZIndex = 1
				EntityESP.Border.Thickness = 1
				EntityESP.Border.Filled = false
				EntityESP.Border.Color = Color3.new()
				EntityESP.Border2 = Drawing.new('Square')
				EntityESP.Border2.Transparency = 0.35
				EntityESP.Border2.ZIndex = 1
				EntityESP.Border2.Thickness = 1
				EntityESP.Border2.Filled = Filled.Enabled
				EntityESP.Border2.Color = Color3.new()
			end
	
			if HealthBar.Enabled then
				EntityESP.HealthLine = Drawing.new('Line')
				EntityESP.HealthLine.Thickness = 1
				EntityESP.HealthLine.ZIndex = 2
				EntityESP.HealthLine.Color = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
				EntityESP.HealthBorder = Drawing.new('Line')
				EntityESP.HealthBorder.Thickness = 3
				EntityESP.HealthBorder.Transparency = 0.35
				EntityESP.HealthBorder.ZIndex = 1
				EntityESP.HealthBorder.Color = Color3.new()
			end
			
			if Name.Enabled then
				if Background.Enabled then
					EntityESP.TextBKG = Drawing.new('Square')
					EntityESP.TextBKG.Transparency = 0.35
					EntityESP.TextBKG.ZIndex = 0
					EntityESP.TextBKG.Thickness = 1
					EntityESP.TextBKG.Filled = true
					EntityESP.TextBKG.Color = Color3.new()
				end
				EntityESP.Drop = Drawing.new('Text')
				EntityESP.Drop.Color = Color3.new()
				EntityESP.Drop.Text = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
				EntityESP.Drop.ZIndex = 1
				EntityESP.Drop.Center = true
				EntityESP.Drop.Size = 20
				EntityESP.Text = Drawing.new('Text')
				EntityESP.Text.Text = EntityESP.Drop.Text
				EntityESP.Text.ZIndex = 2
				EntityESP.Text.Color = EntityESP.Main.Color
				EntityESP.Text.Center = true
				EntityESP.Text.Size = 20
			end
			Reference[ent] = EntityESP
		end,
		Drawing3D = function(ent)
			if not Targets.Players.Enabled and ent.Player then return end
			if not Targets.NPCs.Enabled and ent.NPC then return end
			if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			local EntityESP = {}
			EntityESP.Line1 = Drawing.new('Line')
			EntityESP.Line2 = Drawing.new('Line')
			EntityESP.Line3 = Drawing.new('Line')
			EntityESP.Line4 = Drawing.new('Line')
			EntityESP.Line5 = Drawing.new('Line')
			EntityESP.Line6 = Drawing.new('Line')
			EntityESP.Line7 = Drawing.new('Line')
			EntityESP.Line8 = Drawing.new('Line')
			EntityESP.Line9 = Drawing.new('Line')
			EntityESP.Line10 = Drawing.new('Line')
			EntityESP.Line11 = Drawing.new('Line')
			EntityESP.Line12 = Drawing.new('Line')
	
			local color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			for _, v in EntityESP do
				v.Thickness = 1
				v.Color = color
			end
	
			Reference[ent] = EntityESP
		end,
		DrawingSkeleton = function(ent)
			if not Targets.Players.Enabled and ent.Player then return end
			if not Targets.NPCs.Enabled and ent.NPC then return end
			if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			local EntityESP = {}
			EntityESP.Head = Drawing.new('Line')
			EntityESP.HeadFacing = Drawing.new('Line')
			EntityESP.Torso = Drawing.new('Line')
			EntityESP.UpperTorso = Drawing.new('Line')
			EntityESP.LowerTorso = Drawing.new('Line')
			EntityESP.LeftArm = Drawing.new('Line')
			EntityESP.RightArm = Drawing.new('Line')
			EntityESP.LeftLeg = Drawing.new('Line')
			EntityESP.RightLeg = Drawing.new('Line')
	
			local color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			for _, v in EntityESP do
				v.Thickness = 2
				v.Color = color
			end
	
			Reference[ent] = EntityESP
		end
	}
	
	local ESPRemoved = {
		Drawing2D = function(ent)
			local EntityESP = Reference[ent]
			if EntityESP then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				Reference[ent] = nil
				for _, v in EntityESP do
					pcall(function()
						v.Visible = false
						v:Remove()
					end)
				end
			end
		end
	}
	ESPRemoved.Drawing3D = ESPRemoved.Drawing2D
	ESPRemoved.DrawingSkeleton = ESPRemoved.Drawing2D
	
	local ESPUpdated = {
		Drawing2D = function(ent)
			local EntityESP = Reference[ent]
			if EntityESP then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				
				if EntityESP.HealthLine then
					EntityESP.HealthLine.Color = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
				end
	
				if EntityESP.Text then
					EntityESP.Text.Text = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
					EntityESP.Drop.Text = EntityESP.Text.Text
				end
			end
		end
	}
	
	local ColorFunc = {
		Drawing2D = function(hue, sat, val)
			local color = Color3.fromHSV(hue, sat, val)
			for i, v in Reference do
				v.Main.Color = entitylib.getEntityColor(i) or color
				if v.Text then
					v.Text.Color = v.Main.Color
				end
			end
		end,
		Drawing3D = function(hue, sat, val)
			local color = Color3.fromHSV(hue, sat, val)
			for i, v in Reference do
				local playercolor = entitylib.getEntityColor(i) or color
				for _, v2 in v do
					v2.Color = playercolor
				end
			end
		end
	}
	ColorFunc.DrawingSkeleton = ColorFunc.Drawing3D
	
	local ESPLoop = {
		Drawing2D = function()
			for ent, EntityESP in Reference do
				if Distance.Enabled then
					local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						for _, obj in EntityESP do
							obj.Visible = false
						end
						continue
					end
				end
	
				local rootPos, rootVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position)
				for _, obj in EntityESP do
					obj.Visible = rootVis
				end
				if not rootVis then continue end
	
				local topPos = gameCamera:WorldToViewportPoint((CFrame.lookAlong(ent.RootPart.Position, gameCamera.CFrame.LookVector) * CFrame.new(2, ent.HipHeight, 0)).p)
				local bottomPos = gameCamera:WorldToViewportPoint((CFrame.lookAlong(ent.RootPart.Position, gameCamera.CFrame.LookVector) * CFrame.new(-2, -ent.HipHeight - 1, 0)).p)
				local sizex, sizey = topPos.X - bottomPos.X, topPos.Y - bottomPos.Y
				local posx, posy = (rootPos.X - sizex / 2),  ((rootPos.Y - sizey / 2))
				EntityESP.Main.Position = Vector2.new(posx, posy) // 1
				EntityESP.Main.Size = Vector2.new(sizex, sizey) // 1
				if EntityESP.Border then
					EntityESP.Border.Position = Vector2.new(posx - 1, posy + 1) // 1
					EntityESP.Border.Size = Vector2.new(sizex + 2, sizey - 2) // 1
					EntityESP.Border2.Position = Vector2.new(posx + 1, posy - 1) // 1
					EntityESP.Border2.Size = Vector2.new(sizex - 2, sizey + 2) // 1
				end
	
				if EntityESP.HealthLine then
					local healthposy = sizey * math.clamp(ent.Health / ent.MaxHealth, 0, 1)
					EntityESP.HealthLine.Visible = ent.Health > 0
					EntityESP.HealthLine.From = Vector2.new(posx - 6, posy + (sizey - (sizey - healthposy))) // 1
					EntityESP.HealthLine.To = Vector2.new(posx - 6, posy) // 1
					EntityESP.HealthBorder.From = Vector2.new(posx - 6, posy + 1) // 1
					EntityESP.HealthBorder.To = Vector2.new(posx - 6, (posy + sizey) - 1) // 1
				end
	
				if EntityESP.Text then
					EntityESP.Text.Position = Vector2.new(posx + (sizex / 2), posy + (sizey - 28)) // 1
					EntityESP.Drop.Position = EntityESP.Text.Position + Vector2.new(1, 1)
					if EntityESP.TextBKG then
						EntityESP.TextBKG.Size = EntityESP.Text.TextBounds + Vector2.new(8, 4)
						EntityESP.TextBKG.Position = EntityESP.Text.Position - Vector2.new(4 + (EntityESP.Text.TextBounds.X / 2), 0)
					end
				end
			end
		end,
		Drawing3D = function()
			for ent, EntityESP in Reference do
				if Distance.Enabled then
					local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						for _, obj in EntityESP do
							obj.Visible = false
						end
						continue
					end
				end
	
				local _, rootVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position)
				for _, obj in EntityESP do
					obj.Visible = rootVis
				end
				if not rootVis then continue end
	
				local point1 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(1.5, ent.HipHeight, 1.5))
				local point2 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(1.5, -ent.HipHeight, 1.5))
				local point3 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(-1.5, ent.HipHeight, 1.5))
				local point4 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(-1.5, -ent.HipHeight, 1.5))
				local point5 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(1.5, ent.HipHeight, -1.5))
				local point6 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(1.5, -ent.HipHeight, -1.5))
				local point7 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(-1.5, ent.HipHeight, -1.5))
				local point8 = ESPWorldToViewport(ent.RootPart.Position + Vector3.new(-1.5, -ent.HipHeight, -1.5))
				EntityESP.Line1.From = point1
				EntityESP.Line1.To = point2
				EntityESP.Line2.From = point3
				EntityESP.Line2.To = point4
				EntityESP.Line3.From = point5
				EntityESP.Line3.To = point6
				EntityESP.Line4.From = point7
				EntityESP.Line4.To = point8
				EntityESP.Line5.From = point1
				EntityESP.Line5.To = point3
				EntityESP.Line6.From = point1
				EntityESP.Line6.To = point5
				EntityESP.Line7.From = point5
				EntityESP.Line7.To = point7
				EntityESP.Line8.From = point7
				EntityESP.Line8.To = point3
				EntityESP.Line9.From = point2
				EntityESP.Line9.To = point4
				EntityESP.Line10.From = point2
				EntityESP.Line10.To = point6
				EntityESP.Line11.From = point6
				EntityESP.Line11.To = point8
				EntityESP.Line12.From = point8
				EntityESP.Line12.To = point4
			end
		end,
		DrawingSkeleton = function()
			for ent, EntityESP in Reference do
				if Distance.Enabled then
					local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						for _, obj in EntityESP do
							obj.Visible = false
						end
						continue
					end
				end
	
				local _, rootVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position)
				for _, obj in EntityESP do
					obj.Visible = rootVis
				end
				if not rootVis then continue end
				
				local rigcheck = ent.Humanoid.RigType == Enum.HumanoidRigType.R6
				pcall(function()
					local offset = rigcheck and CFrame.new(0, -0.8, 0) or CFrame.identity
					local head = ESPWorldToViewport((ent.Head.CFrame).p)
					local headfront = ESPWorldToViewport((ent.Head.CFrame * CFrame.new(0, 0, -0.5)).p)
					local toplefttorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(-1.5, 0.8, 0)).p)
					local toprighttorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(1.5, 0.8, 0)).p)
					local toptorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(0, 0.8, 0)).p)
					local bottomtorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(0, -0.8, 0)).p)
					local bottomlefttorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(-0.5, -0.8, 0)).p)
					local bottomrighttorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(0.5, -0.8, 0)).p)
					local leftarm = ESPWorldToViewport((ent.Character[(rigcheck and 'Left Arm' or 'LeftHand')].CFrame * offset).p)
					local rightarm = ESPWorldToViewport((ent.Character[(rigcheck and 'Right Arm' or 'RightHand')].CFrame * offset).p)
					local leftleg = ESPWorldToViewport((ent.Character[(rigcheck and 'Left Leg' or 'LeftFoot')].CFrame * offset).p)
					local rightleg = ESPWorldToViewport((ent.Character[(rigcheck and 'Right Leg' or 'RightFoot')].CFrame * offset).p)
					EntityESP.Head.From = toptorso
					EntityESP.Head.To = head
					EntityESP.HeadFacing.From = head
					EntityESP.HeadFacing.To = headfront
					EntityESP.UpperTorso.From = toplefttorso
					EntityESP.UpperTorso.To = toprighttorso
					EntityESP.Torso.From = toptorso
					EntityESP.Torso.To = bottomtorso
					EntityESP.LowerTorso.From = bottomlefttorso
					EntityESP.LowerTorso.To = bottomrighttorso
					EntityESP.LeftArm.From = toplefttorso
					EntityESP.LeftArm.To = leftarm
					EntityESP.RightArm.From = toprighttorso
					EntityESP.RightArm.To = rightarm
					EntityESP.LeftLeg.From = bottomlefttorso
					EntityESP.LeftLeg.To = leftleg
					EntityESP.RightLeg.From = bottomrighttorso
					EntityESP.RightLeg.To = rightleg
				end)
			end
		end
	}
	
	ESP = vape.Categories.Render:CreateModule({
		Name = 'ESP',
		Function = function(callback)
			if callback then
				methodused = 'Drawing'..Method.Value
				if ESPRemoved[methodused] then
					ESP:Clean(entitylib.Events.EntityRemoved:Connect(ESPRemoved[methodused]))
				end
				if ESPAdded[methodused] then
					for _, v in entitylib.List do
						if Reference[v] then
							ESPRemoved[methodused](v)
						end
						ESPAdded[methodused](v)
					end
					ESP:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
						if Reference[ent] then
							ESPRemoved[methodused](ent)
						end
						ESPAdded[methodused](ent)
					end))
				end
				if ESPUpdated[methodused] then
					ESP:Clean(entitylib.Events.EntityUpdated:Connect(ESPUpdated[methodused]))
					for _, v in entitylib.List do
						ESPUpdated[methodused](v)
					end
				end
				if ColorFunc[methodused] then
					ESP:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
						ColorFunc[methodused](Color.Hue, Color.Sat, Color.Value)
					end))
				end
				if ESPLoop[methodused] then
					ESP:Clean(runService.RenderStepped:Connect(ESPLoop[methodused]))
				end
			else
				if ESPRemoved[methodused] then
					for i in Reference do
						ESPRemoved[methodused](i)
					end
				end
			end
		end,
		Tooltip = 'Extra Sensory Perception\nRenders an ESP on players.'
	})
	Targets = ESP:CreateTargets({
		Players = true,
		Function = function()
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
		end
	})
	Method = ESP:CreateDropdown({
		Name = 'Mode',
		List = {'2D', '3D', 'Skeleton'},
		Function = function(val)
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
			BoundingBox.Object.Visible = (val == '2D')
			Filled.Object.Visible = (val == '2D')
			HealthBar.Object.Visible = (val == '2D')
			Name.Object.Visible = (val == '2D')
			DisplayName.Object.Visible = Name.Object.Visible and Name.Enabled
			Background.Object.Visible = Name.Object.Visible and Name.Enabled
		end,
	})
	Color = ESP:CreateColorSlider({
		Name = 'Player Color',
		Function = function(hue, sat, val)
			if ESP.Enabled and ColorFunc[methodused] then
				ColorFunc[methodused](hue, sat, val)
			end
		end
	})
	BoundingBox = ESP:CreateToggle({
		Name = 'Bounding Box',
		Function = function()
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
		end,
		Default = true,
		Darker = true
	})
	Filled = ESP:CreateToggle({
		Name = 'Filled',
		Function = function()
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
		end,
		Darker = true
	})
	HealthBar = ESP:CreateToggle({
		Name = 'Health Bar',
		Function = function()
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
		end,
		Darker = true
	})
	Name = ESP:CreateToggle({
		Name = 'Name',
		Function = function(callback)
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
			DisplayName.Object.Visible = callback
			Background.Object.Visible = callback
		end,
		Darker = true
	})
	DisplayName = ESP:CreateToggle({
		Name = 'Use Displayname',
		Function = function()
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
		end,
		Default = true,
		Darker = true
	})
	Background = ESP:CreateToggle({
		Name = 'Show Background',
		Function = function()
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
		end,
		Darker = true
	})
	Teammates = ESP:CreateToggle({
		Name = 'Priority Only',
		Function = function()
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Hides teammates & non targetable entities'
	})
	Distance = ESP:CreateToggle({
		Name = 'Distance Check',
		Function = function(callback)
			DistanceLimit.Object.Visible = callback
		end
	})
	DistanceLimit = ESP:CreateTwoSlider({
		Name = 'Player Distance',
		Min = 0,
		Max = 256,
		DefaultMin = 0,
		DefaultMax = 64,
		Darker = true,
		Visible = false
	})
end)
	
run(function()
	local GamingChair = {Enabled = false}
	local Color
	local wheelpositions = {
		Vector3.new(-0.8, -0.6, -0.18),
		Vector3.new(0.1, -0.6, -0.88),
		Vector3.new(0, -0.6, 0.7)
	}
	local chairhighlight
	local currenttween
	local movingsound
	local flyingsound
	local chairanim
	local chair
	
	GamingChair = vape.Categories.Render:CreateModule({
		Name = 'GamingChair',
		Function = function(callback)
			if callback then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				chair = Instance.new('MeshPart')
				chair.Color = Color3.fromRGB(21, 21, 21)
				chair.Size = Vector3.new(2.16, 3.6, 2.3) / Vector3.new(12.37, 20.636, 13.071)
				chair.CanCollide = false
				chair.Massless = true
				chair.MeshId = 'rbxassetid://12972961089'
				chair.Material = Enum.Material.SmoothPlastic
				chair.Parent = workspace
				movingsound = Instance.new('Sound')
				--movingsound.SoundId = downloadVapeAsset('vape/assets/ChairRolling.mp3')
				movingsound.Volume = 0.4
				movingsound.Looped = true
				movingsound.Parent = workspace
				flyingsound = Instance.new('Sound')
				--flyingsound.SoundId = downloadVapeAsset('vape/assets/ChairFlying.mp3')
				flyingsound.Volume = 0.4
				flyingsound.Looped = true
				flyingsound.Parent = workspace
				local chairweld = Instance.new('WeldConstraint')
				chairweld.Part0 = chair
				chairweld.Parent = chair
				if entitylib.isAlive then
					chair.CFrame = entitylib.character.RootPart.CFrame * CFrame.Angles(0, math.rad(-90), 0)
					chairweld.Part1 = entitylib.character.RootPart
				end
				chairhighlight = Instance.new('Highlight')
				chairhighlight.FillTransparency = 1
				chairhighlight.OutlineColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
				chairhighlight.DepthMode = Enum.HighlightDepthMode.Occluded
				chairhighlight.OutlineTransparency = 0.2
				chairhighlight.Parent = chair
				local chairarms = Instance.new('MeshPart')
				chairarms.Color = chair.Color
				chairarms.Size = Vector3.new(1.39, 1.345, 2.75) / Vector3.new(97.13, 136.216, 234.031)
				chairarms.CFrame = chair.CFrame * CFrame.new(-0.169, -1.129, -0.013)
				chairarms.MeshId = 'rbxassetid://12972673898'
				chairarms.CanCollide = false
				chairarms.Parent = chair
				local chairarmsweld = Instance.new('WeldConstraint')
				chairarmsweld.Part0 = chairarms
				chairarmsweld.Part1 = chair
				chairarmsweld.Parent = chair
				local chairlegs = Instance.new('MeshPart')
				chairlegs.Color = chair.Color
				chairlegs.Name = 'Legs'
				chairlegs.Size = Vector3.new(1.8, 1.2, 1.8) / Vector3.new(10.432, 8.105, 9.488)
				chairlegs.CFrame = chair.CFrame * CFrame.new(0.047, -2.324, 0)
				chairlegs.MeshId = 'rbxassetid://13003181606'
				chairlegs.CanCollide = false
				chairlegs.Parent = chair
				local chairfan = Instance.new('MeshPart')
				chairfan.Color = chair.Color
				chairfan.Name = 'Fan'
				chairfan.Size = Vector3.zero
				chairfan.CFrame = chair.CFrame * CFrame.new(0, -1.873, 0)
				chairfan.MeshId = 'rbxassetid://13004977292'
				chairfan.CanCollide = false
				chairfan.Parent = chair
				local trails = {}
				for _, v in wheelpositions do
					local attachment = Instance.new('Attachment')
					attachment.Position = v
					attachment.Parent = chairlegs
					local attachment2 = Instance.new('Attachment')
					attachment2.Position = v + Vector3.new(0, 0, 0.18)
					attachment2.Parent = chairlegs
					local trail = Instance.new('Trail')
					trail.Texture = 'http://www.roblox.com/asset/?id=13005168530'
					trail.TextureMode = Enum.TextureMode.Static
					trail.Transparency = NumberSequence.new(0.5)
					trail.Color = ColorSequence.new(Color3.new(0.5, 0.5, 0.5))
					trail.Attachment0 = attachment
					trail.Attachment1 = attachment2
					trail.Lifetime = 20
					trail.MaxLength = 60
					trail.MinLength = 0.1
					trail.Parent = chairlegs
					table.insert(trails, trail)
				end
				GamingChair:Clean(chair)
				GamingChair:Clean(movingsound)
				GamingChair:Clean(flyingsound)
				chairanim = {Stop = function() end}
				local oldmoving = false
				local oldflying = false
				repeat
					if entitylib.isAlive and entitylib.character.Humanoid.Health > 0 then
						if not chairanim.IsPlaying then
							local temp2 = Instance.new('Animation')
							temp2.AnimationId = entitylib.character.Humanoid.RigType == Enum.HumanoidRigType.R15 and 'http://www.roblox.com/asset/?id=2506281703' or 'http://www.roblox.com/asset/?id=178130996'
							chairanim = entitylib.character.Humanoid:LoadAnimation(temp2)
							chairanim.Priority = Enum.AnimationPriority.Movement
							chairanim.Looped = true
							chairanim:Play()
						end
						chair.CFrame = entitylib.character.RootPart.CFrame * CFrame.Angles(0, math.rad(-90), 0)
						chairweld.Part1 = entitylib.character.RootPart
						chairlegs.Velocity = Vector3.zero
						chairlegs.CFrame = chair.CFrame * CFrame.new(0.047, -2.324, 0)
						chairfan.Velocity = Vector3.zero
						chairfan.CFrame = chair.CFrame * CFrame.new(0.047, -1.873, 0) * CFrame.Angles(0, math.rad(tick() * 180 % 360), math.rad(180))
						local moving = entitylib.character.Humanoid:GetState() == Enum.HumanoidStateType.Running and entitylib.character.Humanoid.MoveDirection ~= Vector3.zero
						local flying = vape.Modules.Fly and vape.Modules.Fly.Enabled or vape.Modules.LongJump and vape.Modules.LongJump.Enabled or vape.Modules.InfiniteFly and vape.Modules.InfiniteFly.Enabled
						if movingsound.TimePosition > 1.9 then
							movingsound.TimePosition = 0.2
						end
						movingsound.PlaybackSpeed = (entitylib.character.RootPart.Velocity * Vector3.new(1, 0, 1)).Magnitude / 16
						for _, v in trails do
							v.Enabled = not flying and moving
							v.Color = ColorSequence.new(movingsound.PlaybackSpeed > 1.5 and Color3.new(1, 0.5, 0) or Color3.new())
						end
						if moving ~= oldmoving then
							if movingsound.IsPlaying then
								if not moving then
									movingsound:Stop()
								end
							else
								if not flying and moving then
									movingsound:Play()
								end
							end
							oldmoving = moving
						end
						if flying ~= oldflying then
							if flying then
								if movingsound.IsPlaying then
									movingsound:Stop()
								end
								if not flyingsound.IsPlaying then
									flyingsound:Play()
								end
								if currenttween then
									currenttween:Cancel()
								end
								tween = tweenService:Create(chairlegs, TweenInfo.new(0.15), {
									Size = Vector3.zero
								})
								tween.Completed:Connect(function(state)
									if state == Enum.PlaybackState.Completed then
										chairfan.Transparency = 0
										chairlegs.Transparency = 1
										tween = tweenService:Create(chairfan, TweenInfo.new(0.15), {
											Size = Vector3.new(1.534, 0.328, 1.537) / Vector3.new(791.138, 168.824, 792.027)
										})
										tween:Play()
									end
								end)
								tween:Play()
							else
								if flyingsound.IsPlaying then
									flyingsound:Stop()
								end
								if not movingsound.IsPlaying and moving then
									movingsound:Play()
								end
								if currenttween then currenttween:Cancel() end
								tween = tweenService:Create(chairfan, TweenInfo.new(0.15), {
									Size = Vector3.zero
								})
								tween.Completed:Connect(function(state)
									if state == Enum.PlaybackState.Completed then
										chairfan.Transparency = 1
										chairlegs.Transparency = 0
										tween = tweenService:Create(chairlegs, TweenInfo.new(0.15), {
											Size = Vector3.new(1.8, 1.2, 1.8) / Vector3.new(10.432, 8.105, 9.488)
										})
										tween:Play()
									end
								end)
								tween:Play()
							end
							oldflying = flying
						end
					else
						chair.Anchored = true
						chairlegs.Anchored = true
						chairfan.Anchored = true
						repeat task.wait() until entitylib.isAlive and entitylib.character.Humanoid.Health > 0
						chair.Anchored = false
						chairlegs.Anchored = false
						chairfan.Anchored = false
						chairanim:Stop()
					end
					task.wait()
				until not GamingChair.Enabled
			else
				if chairanim then
					chairanim:Stop()
				end
			end
		end,
		Tooltip = 'Sit in the best gaming chair known to mankind.'
	})
	Color = GamingChair:CreateColorSlider({
		Name = 'Color',
		Function = function(h, s, v)
			if chairhighlight then
				chairhighlight.OutlineColor = Color3.fromHSV(h, s, v)
			end
		end
	})
end)
	
run(function()
	local Health
	
	Health = vape.Categories.Render:CreateModule({
		Name = 'Health',
		Function = function(callback)
			if callback then
				local label = Instance.new('TextLabel')
				label.Size = UDim2.fromOffset(100, 20)
				label.Position = UDim2.new(0.5, 6, 0.5, 30)
				label.AnchorPoint = Vector2.new(0.5, 0)
				label.BackgroundTransparency = 1
				label.Text = '100 ❤️'
				label.TextSize = 18
				label.Font = Enum.Font.Arial
				label.Parent = vape.gui
				Health:Clean(label)
				
				repeat
					label.Text = entitylib.isAlive and math.round(entitylib.character.Humanoid.Health)..' ❤️' or ''
					label.TextColor3 = entitylib.isAlive and Color3.fromHSV((entitylib.character.Humanoid.Health / entitylib.character.Humanoid.MaxHealth) / 2.8, 0.86, 1) or Color3.new()
					task.wait()
				until not Health.Enabled
			end
		end,
		Tooltip = 'Displays your health in the center of your screen.'
	})
end)
	
run(function()
	local NameTags
	local Targets
	local Color
	local Background
	local DisplayName
	local Health
	local Distance
	local DrawingToggle
	local Scale
	local FontOption
	local Teammates
	local DistanceCheck
	local DistanceLimit
	local Strings, Sizes, Reference = {}, {}, {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	local methodused
	
	local Added = {
		Normal = function(ent)
			if not Targets.Players.Enabled and ent.Player then return end
			if not Targets.NPCs.Enabled and ent.NPC then return end
			if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
			if vape.ThreadFix then
				setthreadidentity(8)
			end
	
			Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
			if Health.Enabled then
				local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
				Strings[ent] = Strings[ent]..' <font color="rgb('..tostring(math.floor(healthColor.R * 255))..','..tostring(math.floor(healthColor.G * 255))..','..tostring(math.floor(healthColor.B * 255))..')">'..math.round(ent.Health)..'</font>'
			end
	
			if Distance.Enabled then
				Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '..Strings[ent]
			end
	
			local nametag = Instance.new('TextLabel')
			nametag.TextSize = 14 * Scale.Value
			nametag.FontFace = FontOption.Value
			local size = getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
			nametag.Name = ent.Player and ent.Player.Name or ent.Character.Name
			nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
			nametag.AnchorPoint = Vector2.new(0.5, 1)
			nametag.BackgroundColor3 = Color3.new()
			nametag.BackgroundTransparency = Background.Value
			nametag.BorderSizePixel = 0
			nametag.Visible = false
			nametag.Text = Strings[ent]
			nametag.TextColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			nametag.RichText = true
			nametag.Parent = Folder
			Reference[ent] = nametag
		end,
		Drawing = function(ent)
			if not Targets.Players.Enabled and ent.Player then return end
			if not Targets.NPCs.Enabled and ent.NPC then return end
			if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
	
			local nametag = {}
			nametag.BG = Drawing.new('Square')
			nametag.BG.Filled = true
			nametag.BG.Transparency = 1 - Background.Value
			nametag.BG.Color = Color3.new()
			nametag.BG.ZIndex = 1
			nametag.Text = Drawing.new('Text')
			nametag.Text.Size = 15 * Scale.Value
			nametag.Text.Font = 0
			nametag.Text.ZIndex = 2
			Strings[ent] = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
			if Health.Enabled then
				Strings[ent] = Strings[ent]..' '..math.round(ent.Health)
			end
	
			if Distance.Enabled then
				Strings[ent] = '[%s] '..Strings[ent]
			end
	
			nametag.Text.Text = Strings[ent]
			nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
			Reference[ent] = nametag
		end
	}
	
	local Removed = {
		Normal = function(ent)
			local v = Reference[ent]
			if v then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				Reference[ent] = nil
				Strings[ent] = nil
				Sizes[ent] = nil
				v:Destroy()
			end
		end,
		Drawing = function(ent)
			local v = Reference[ent]
			if v then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				Reference[ent] = nil
				Strings[ent] = nil
				Sizes[ent] = nil
				for _, obj in v do
					pcall(function()
						obj.Visible = false
						obj:Remove()
					end)
				end
			end
		end
	}
	
	local Updated = {
		Normal = function(ent)
			local nametag = Reference[ent]
			if nametag then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				Sizes[ent] = nil
				Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
				if Health.Enabled then
					local color = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
					Strings[ent] = Strings[ent]..' <font color="rgb('..tostring(math.floor(color.R * 255))..','..tostring(math.floor(color.G * 255))..','..tostring(math.floor(color.B * 255))..')">'..math.round(ent.Health)..'</font>'
				end
	
				if Distance.Enabled then
					Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '..Strings[ent]
				end
	
				local size = getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
				nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
				nametag.Text = Strings[ent]
			end
		end,
		Drawing = function(ent)
			local nametag = Reference[ent]
			if nametag then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				Sizes[ent] = nil
				Strings[ent] = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
				if Health.Enabled then
					Strings[ent] = Strings[ent]..' '..math.round(ent.Health)
				end
	
				if Distance.Enabled then
					Strings[ent] = '[%s] '..Strings[ent]
					nametag.Text.Text = entitylib.isAlive and string.format(Strings[ent], math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude)) or Strings[ent]
				else
					nametag.Text.Text = Strings[ent]
				end
	
				nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
				nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			end
		end
	}
	
	local ColorFunc = {
		Normal = function(hue, sat, val)
			local color = Color3.fromHSV(hue, sat, val)
			for i, v in Reference do
				v.TextColor3 = entitylib.getEntityColor(i) or color
			end
		end,
		Drawing = function(hue, sat, val)
			local color = Color3.fromHSV(hue, sat, val)
			for i, v in Reference do
				v.Text.Color = entitylib.getEntityColor(i) or color
			end
		end
	}
	
	local Loop = {
		Normal = function()
			for ent, nametag in Reference do
				if DistanceCheck.Enabled then
					local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						nametag.Visible = false
						continue
					end
				end
	
				local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
				nametag.Visible = headVis
				if not headVis then
					continue
				end
	
				if Distance.Enabled then
					local mag = entitylib.isAlive and math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude) or 0
					if Sizes[ent] ~= mag then
						nametag.Text = string.format(Strings[ent], mag)
						local ize = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
						nametag.Size = UDim2.fromOffset(ize.X + 8, ize.Y + 7)
						Sizes[ent] = mag
					end
				end
				nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
			end
		end,
		Drawing = function()
			for ent, nametag in Reference do
				if DistanceCheck.Enabled then
					local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						nametag.Text.Visible = false
						nametag.BG.Visible = false
						continue
					end
				end
	
				local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
				nametag.Text.Visible = headVis
				nametag.BG.Visible = headVis
				if not headVis then
					continue
				end
	
				if Distance.Enabled then
					local mag = entitylib.isAlive and math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude) or 0
					if Sizes[ent] ~= mag then
						nametag.Text.Text = string.format(Strings[ent], mag)
						nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
						Sizes[ent] = mag
					end
				end
				nametag.BG.Position = Vector2.new(headPos.X - (nametag.BG.Size.X / 2), headPos.Y - nametag.BG.Size.Y)
				nametag.Text.Position = nametag.BG.Position + Vector2.new(4, 3)
			end
		end
	}
	
	NameTags = vape.Categories.Render:CreateModule({
		Name = 'NameTags',
		Function = function(callback)
			if callback then
				methodused = DrawingToggle.Enabled and 'Drawing' or 'Normal'
				if Removed[methodused] then
					NameTags:Clean(entitylib.Events.EntityRemoved:Connect(Removed[methodused]))
				end
				if Added[methodused] then
					for _, v in entitylib.List do
						if Reference[v] then
							Removed[methodused](v)
						end
						Added[methodused](v)
					end
					NameTags:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
						if Reference[ent] then
							Removed[methodused](ent)
						end
						Added[methodused](ent)
					end))
				end
				if Updated[methodused] then
					NameTags:Clean(entitylib.Events.EntityUpdated:Connect(Updated[methodused]))
					for _, v in entitylib.List do
						Updated[methodused](v)
					end
				end
				if ColorFunc[methodused] then
					NameTags:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
						ColorFunc[methodused](Color.Hue, Color.Sat, Color.Value)
					end))
				end
				if Loop[methodused] then
					NameTags:Clean(runService.RenderStepped:Connect(Loop[methodused]))
				end
			else
				if Removed[methodused] then
					for i in Reference do
						Removed[methodused](i)
					end
				end
			end
		end,
		Tooltip = 'Renders nametags on entities through walls.'
	})
	Targets = NameTags:CreateTargets({
		Players = true,
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	FontOption = NameTags:CreateFont({
		Name = 'Font',
		Blacklist = 'Arial',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Color = NameTags:CreateColorSlider({
		Name = 'Player Color',
		Function = function(hue, sat, val)
			if NameTags.Enabled and ColorFunc[methodused] then
				ColorFunc[methodused](hue, sat, val)
			end
		end
	})
	Scale = NameTags:CreateSlider({
		Name = 'Scale',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = 1,
		Min = 0.1,
		Max = 1.5,
		Decimal = 10
	})
	Background = NameTags:CreateSlider({
		Name = 'Transparency',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = 0.5,
		Min = 0,
		Max = 1,
		Decimal = 10
	})
	Health = NameTags:CreateToggle({
		Name = 'Health',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Distance = NameTags:CreateToggle({
		Name = 'Distance',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	DisplayName = NameTags:CreateToggle({
		Name = 'Use Displayname',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = true
	})
	Teammates = NameTags:CreateToggle({
		Name = 'Priority Only',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Hides teammates & non targetable entities'
	})
	DrawingToggle = NameTags:CreateToggle({
		Name = 'Drawing',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	DistanceCheck = NameTags:CreateToggle({
		Name = 'Distance Check',
		Function = function(callback)
			DistanceLimit.Object.Visible = callback
		end
	})
	DistanceLimit = NameTags:CreateTwoSlider({
		Name = 'Player Distance',
		Min = 0,
		Max = 256,
		DefaultMin = 0,
		DefaultMax = 64,
		Darker = true,
		Visible = false
	})
end)
	
run(function()
	local PlayerModel
	local Scale
	local Local
	local Mesh
	local Texture
	local Rots = {}
	local models = {}
	
	local function addMesh(ent)
		if vape.ThreadFix then 
			setthreadidentity(8)
		end
		local root = ent.RootPart
		local part = Instance.new('Part')
		part.Size = Vector3.new(3, 3, 3)
		part.CFrame = root.CFrame * CFrame.Angles(math.rad(Rots[1].Value), math.rad(Rots[2].Value), math.rad(Rots[3].Value))
		part.CanCollide = false
		part.CanQuery = false
		part.Massless = true
		part.Parent = workspace
		local meshd = Instance.new('SpecialMesh')
		meshd.MeshId = Mesh.Value
		meshd.TextureId = Texture.Value
		meshd.Scale = Vector3.one * Scale.Value
		meshd.Parent = part
		local weld = Instance.new('WeldConstraint')
		weld.Part0 = part
		weld.Part1 = root
		weld.Parent = part
		models[root] = part
	end
	
	local function removeMesh(ent)
		if models[ent.RootPart] then 
			models[ent.RootPart]:Destroy()
			models[ent.RootPart] = nil
		end
	end
	
	PlayerModel = vape.Categories.Render:CreateModule({
		Name = 'PlayerModel',
		Function = function(callback)
			if callback then 
				if Local.Enabled then 
					PlayerModel:Clean(entitylib.Events.LocalAdded:Connect(addMesh))
					PlayerModel:Clean(entitylib.Events.LocalRemoved:Connect(removeMesh))
					if entitylib.isAlive then 
						task.spawn(addMesh, entitylib.character)
					end
				end
				PlayerModel:Clean(entitylib.Events.EntityAdded:Connect(addMesh))
				PlayerModel:Clean(entitylib.Events.EntityRemoved:Connect(removeMesh))
				for _, ent in entitylib.List do 
					task.spawn(addMesh, ent)
				end
			else
				for _, part in models do 
					part:Destroy()
				end
				table.clear(models)
			end
		end,
		Tooltip = 'Change the player models to a Mesh'
	})
	Scale = PlayerModel:CreateSlider({
		Name = 'Scale',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 100,
		Function = function(val)
			for _, part in models do 
				part.Mesh.Scale = Vector3.one * val
			end
		end
	})
	for _, name in {'Rotation X', 'Rotation Y', 'Rotation Z'} do 
		table.insert(Rots, PlayerModel:CreateSlider({
			Name = name,
			Min = 0,
			Max = 360,
			Function = function(val)
				for root, part in models do 
					part.WeldConstraint.Enabled = false
					part.CFrame = root.CFrame * CFrame.Angles(math.rad(Rots[1].Value), math.rad(Rots[2].Value), math.rad(Rots[3].Value))
					part.WeldConstraint.Enabled = true
				end
			end
		}))
	end
	Local = PlayerModel:CreateToggle({
		Name = 'Local',
		Function = function()
			if PlayerModel.Enabled then 
				PlayerModel:Toggle()
				PlayerModel:Toggle()
			end
		end
	})
	Mesh = PlayerModel:CreateTextBox({
		Name = 'Mesh',
		Placeholder = 'mesh id',
		Function = function()
			for _, part in models do 
				part.Mesh.MeshId = Mesh.Value
			end
		end
	})
	Texture = PlayerModel:CreateTextBox({
		Name = 'Texture',
		Placeholder = 'texture id',
		Function = function()
			for _, part in models do 
				part.Mesh.TextureId = Texture.Value
			end
		end
	})
	
end)
	
run(function()
	local Radar
	local Targets
	local DotStyle
	local PlayerColor
	local Clamp
	local Reference = {}
	local bkg
	
	local function Added(ent)
		if not Targets.Players.Enabled and ent.Player then return end
		if not Targets.NPCs.Enabled and ent.NPC then return end
		if (not ent.Targetable) and (not ent.Friend) then return end
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		local dot = Instance.new('Frame')
		dot.Size = UDim2.fromOffset(4, 4)
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.BackgroundColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(PlayerColor.Hue, PlayerColor.Sat, PlayerColor.Value)
		dot.Parent = bkg
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(DotStyle.Value == 'Circles' and 1 or 0, 0)
		corner.Parent = dot
		local stroke = Instance.new('UIStroke')
		stroke.Color = Color3.new()
		stroke.Thickness = 1
		stroke.Transparency = 0.8
		stroke.Parent = dot
		Reference[ent] = dot
	end
	
	local function Removed(ent)
		local v = Reference[ent]
		if v then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			Reference[ent] = nil
			v:Destroy()
		end
	end
	
	Radar = vape:CreateOverlay({
		Name = 'Radar',
		Icon = 'rbxassetid://14368343291',
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.fromOffset(12, 13),
		Function = function(callback)
			if callback then
				Radar:Clean(entitylib.Events.EntityRemoved:Connect(Removed))
				for _, v in entitylib.List do
					if Reference[v] then
						Removed(v)
					end
					Added(v)
				end
				Radar:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
					if Reference[ent] then
						Removed(ent)
					end
					Added(ent)
				end))
				Radar:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
					for ent, dot in Reference do
						dot.BackgroundColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(PlayerColor.Hue, PlayerColor.Sat, PlayerColor.Value)
					end
				end))
				Radar:Clean(runService.RenderStepped:Connect(function()
					for ent, dot in Reference do
						if entitylib.isAlive then
							local dt = CFrame.lookAlong(entitylib.character.RootPart.Position, gameCamera.CFrame.LookVector * Vector3.new(1, 0, 1)):PointToObjectSpace(ent.RootPart.Position)
							dot.Position = UDim2.fromOffset(Clamp.Enabled and math.clamp(108 + dt.X, 2, 214) or 108 + dt.X, Clamp.Enabled and math.clamp(108 + dt.Z, 8, 214) or 108 + dt.Z)
						end
					end
				end))
			else
				for ent in Reference do
					Removed(ent)
				end
			end
		end
	})
	Targets = Radar:CreateTargets({
		Players = true,
		Function = function()
			if Radar.Button.Enabled then
				Radar.Button:Toggle()
				Radar.Button:Toggle()
			end
		end
	})
	DotStyle = Radar:CreateDropdown({
		Name = 'Dot Style',
		List = {'Circles', 'Squares'},
		Function = function(val)
			for _, dot in Reference do
				dot.UICorner.CornerRadius = UDim.new(val == 'Circles' and 1 or 0, 0)
			end
		end
	})
	PlayerColor = Radar:CreateColorSlider({
		Name = 'Player Color',
		Function = function(hue, sat, val)
			for ent, dot in Reference do
				dot.BackgroundColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(hue, sat, val)
			end
		end
	})
	bkg = Instance.new('Frame')
	bkg.Size = UDim2.fromOffset(216, 216)
	bkg.Position = UDim2.fromOffset(2, 2)
	bkg.BackgroundColor3 = Color3.new()
	bkg.BackgroundTransparency = 0.5
	bkg.ClipsDescendants = true
	bkg.Parent = Radar.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = bkg
	local stroke = Instance.new('UIStroke')
	stroke.Thickness = 2
	stroke.Color = Color3.new()
	stroke.Transparency = 0.4
	stroke.Parent = bkg
	local line1 = Instance.new('Frame')
	line1.Size = UDim2.new(0, 2, 1, 0)
	line1.Position = UDim2.fromScale(0.5, 0.5)
	line1.AnchorPoint = Vector2.new(0.5, 0.5)
	line1.ZIndex = 0
	line1.BackgroundColor3 = Color3.new(1, 1, 1)
	line1.BackgroundTransparency = 0.5
	line1.BorderSizePixel = 0
	line1.Parent = bkg
	local line2 = line1:Clone()
	line2.Size = UDim2.new(1, 0, 0, 2)
	line2.Parent = bkg
	local bar = Instance.new('Frame')
	bar.Size = UDim2.new(1, -6, 0, 4)
	bar.Position = UDim2.fromOffset(3, 0)
	bar.BackgroundColor3 = Color3.fromHSV(0.44, 1, 1)
	bar.Parent = bkg
	local barcorner = Instance.new('UICorner')
	barcorner.CornerRadius = UDim.new(0, 8)
	barcorner.Parent = bar
	Radar:CreateColorSlider({
		Name = 'Bar Color',
		Function = function(hue, sat, val)
			bar.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
		end
	})
	Radar:CreateToggle({
		Name = 'Show Background',
		Default = true,
		Function = function(callback)
			bkg.BackgroundTransparency = callback and 0.5 or 1
			bar.BackgroundTransparency = callback and 0 or 1
			stroke.Transparency = callback and 0.4 or 1
		end
	})
	Radar:CreateToggle({
		Name = 'Show Cross',
		Default = true,
		Function = function(callback)
			line1.BackgroundTransparency = callback and 0.5 or 1
			line2.BackgroundTransparency = callback and 0.5 or 1
		end
	})
	Clamp = Radar:CreateToggle({
		Name = 'Clamp Radar',
		Default = true
	})
end)
	
run(function()
	local Search
	local List
	local Color
	local FillTransparency
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function Add(v)
		if not table.find(List.ListEnabled, v.Name) then return end
		if v:IsA('BasePart') or v:IsA('Model') then
			local box = Instance.new('BoxHandleAdornment')
			box.AlwaysOnTop = true
			box.Adornee = v
			box.Size = v:IsA('Model') and v:GetExtentsSize() or v.Size
			box.ZIndex = 0
			box.Transparency = FillTransparency.Value
			box.Color3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			box.Parent = Folder
			Reference[v] = box
		end
	end
	
	Search = vape.Categories.Render:CreateModule({
		Name = 'Search',
		Function = function(callback)
			if callback then
				Search:Clean(workspace.DescendantAdded:Connect(Add))
				Search:Clean(workspace.DescendantRemoving:Connect(function(v)
					if Reference[v] then
						Reference[v]:Destroy()
						Reference[v] = nil
					end
				end))
				
				for _, v in workspace:GetDescendants() do
					Add(v)
				end
			else
				Folder:ClearAllChildren()
				table.clear(Reference)
			end
		end,
		Tooltip = 'Draws box around selected parts\nAdd parts in Search frame'
	})
	List = Search:CreateTextList({
		Name = 'Parts',
		Function = function()
			if Search.Enabled then
				Search:Toggle()
				Search:Toggle()
			end
		end
	})
	Color = Search:CreateColorSlider({
		Name = 'Color',
		Function = function(hue, sat, val)
			for _, v in Reference do
				v.Color3 = Color3.fromHSV(hue, sat, val)
			end
		end
	})
	FillTransparency = Search:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Function = function(val)
			for _, v in Reference do
				v.Transparency = val
			end
		end,
		Decimal = 10
	})
end)
	
run(function()
	local SessionInfo
	local FontOption
	local Hide
	local TextSize
	local BorderColor
	local Title
	local TitleOffset = {}
	local Custom
	local CustomBox
	local infoholder
	local infolabel
	local infostroke
	
	SessionInfo = vape:CreateOverlay({
		Name = 'Session Info',
		Icon = 'rbxassetid://14368355456',
		Size = UDim2.fromOffset(16, 12),
		Position = UDim2.fromOffset(12, 14),
		Function = function(callback)
			if callback then
				local teleportedServers
				SessionInfo:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
					if not teleportedServers then
						teleportedServers = true
						queue_on_teleport("shared.vapesessioninfo = '"..httpService:JSONEncode(vape.Libraries.sessioninfo.Objects).."'")
					end
				end))
	
				if shared.vapesessioninfo then
					for i, v in httpService:JSONDecode(shared.vapesessioninfo) do
						if vape.Libraries.sessioninfo.Objects[i] and v.Saved then
							vape.Libraries.sessioninfo.Objects[i].Value = v.Value
						end
					end
				end
	
				repeat
					if vape.Libraries.sessioninfo then
						local stuff = {''}
						if Title.Enabled then
							stuff[1] = TitleOffset.Enabled and '<b>Session Info</b>\n<font size="4"> </font>' or '<b>Session Info</b>'
						end
	
						for i, v in vape.Libraries.sessioninfo.Objects do
							stuff[v.Index] = not table.find(Hide.ListEnabled, i) and i..': '..v.Function(v.Value) or false
						end
	
						if #Hide.ListEnabled > 0 then
							local key, val
							repeat
								local oldkey = key
								key, val = next(stuff, key)
								if val == false then
									table.remove(stuff, key)
									key = oldkey
								end
							until not key
						end
	
						if Custom.Enabled then
							table.insert(stuff, CustomBox.Value)
						end
	
						if not Title.Enabled then
							table.remove(stuff, 1)
						end
						infolabel.Text = table.concat(stuff, '\n')
						infolabel.FontFace = FontOption.Value
						infolabel.TextSize = TextSize.Value
						local size = getfontsize(removeTags(infolabel.Text), infolabel.TextSize, infolabel.FontFace)
						infoholder.Size = UDim2.fromOffset(size.X + 16, size.Y + (Title.Enabled and TitleOffset.Enabled and 4 or 16))
					end
					task.wait(1)
				until not SessionInfo.Button or not SessionInfo.Button.Enabled
			end
		end
	})
	FontOption = SessionInfo:CreateFont({
		Name = 'Font',
		Blacklist = 'Arial'
	})
	Hide = SessionInfo:CreateTextList({
		Name = 'Blacklist',
		Tooltip = 'Name of entry to hide.',
		Icon = 'rbxassetid://14385669108',
		Tab = 'rbxassetid://14385672881',
		TabSize = UDim2.fromOffset(21, 16),
		Color = Color3.fromRGB(250, 50, 56)
	})
	SessionInfo:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			infoholder.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			infoholder.BackgroundTransparency = 1 - opacity
		end
	})
	BorderColor = SessionInfo:CreateColorSlider({
		Name = 'Border Color',
		Function = function(hue, sat, val, opacity)
			infostroke.Color = Color3.fromHSV(hue, sat, val)
			infostroke.Transparency = 1 - opacity
		end,
		Darker = true,
		Visible = false
	})
	TextSize = SessionInfo:CreateSlider({
		Name = 'Text Size',
		Min = 1,
		Max = 30,
		Default = 16
	})
	Title = SessionInfo:CreateToggle({
		Name = 'Title',
		Function = function(callback)
			if TitleOffset.Object then
				TitleOffset.Object.Visible = callback
			end
		end,
		Default = true
	})
	TitleOffset = SessionInfo:CreateToggle({
		Name = 'Offset',
		Default = true,
		Darker = true
	})
	SessionInfo:CreateToggle({
		Name = 'Border',
		Function = function(callback)
			infostroke.Enabled = callback
			BorderColor.Object.Visible = callback
		end
	})
	Custom = SessionInfo:CreateToggle({
		Name = 'Add custom text',
		Function = function(enabled)
			CustomBox.Object.Visible = enabled
		end
	})
	CustomBox = SessionInfo:CreateTextBox({
		Name = 'Custom text',
		Darker = true,
		Visible = false
	})
	infoholder = Instance.new('Frame')
	infoholder.BackgroundColor3 = Color3.new()
	infoholder.BackgroundTransparency = 0.5
	infoholder.Parent = SessionInfo.Children
	vape:Clean(SessionInfo.Children:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		local newside = SessionInfo.Children.AbsolutePosition.X > (vape.gui.AbsoluteSize.X / 2)
		infoholder.Position = UDim2.fromScale(newside and 1 or 0, 0)
		infoholder.AnchorPoint = Vector2.new(newside and 1 or 0, 0)
	end))
	local sessioninfocorner = Instance.new('UICorner')
	sessioninfocorner.CornerRadius = UDim.new(0, 5)
	sessioninfocorner.Parent = infoholder
	infolabel = Instance.new('TextLabel')
	infolabel.Size = UDim2.new(1, -16, 1, -16)
	infolabel.Position = UDim2.fromOffset(8, 8)
	infolabel.BackgroundTransparency = 1
	infolabel.TextXAlignment = Enum.TextXAlignment.Left
	infolabel.TextYAlignment = Enum.TextYAlignment.Top
	infolabel.TextSize = 16
	infolabel.TextColor3 = Color3.new(1, 1, 1)
	infolabel.TextStrokeColor3 = Color3.new()
	infolabel.TextStrokeTransparency = 0.8
	infolabel.Font = Enum.Font.Arial
	infolabel.RichText = true
	infolabel.Parent = infoholder
	infostroke = Instance.new('UIStroke')
	infostroke.Enabled = false
	infostroke.Color = Color3.fromHSV(0.44, 1, 1)
	infostroke.Parent = infoholder
	addBlur(infoholder)
	vape.Libraries.sessioninfo = {
		Objects = {},
		AddItem = function(self, name, startvalue, func, saved)
			func, saved = func or function(val) return val end, saved == nil or saved
			self.Objects[name] = {Function = func, Saved = saved, Value = startvalue or 0, Index = getTableSize(self.Objects) + 2}
			return {
				Increment = function(_, val)
					self.Objects[name].Value += (val or 1)
				end,
				Get = function()
					return self.Objects[name].Value
				end
			}
		end
	}
	vape.Libraries.sessioninfo:AddItem('Time Played', os.clock(), function(value)
		return os.date('!%X', math.floor(os.clock() - value))
	end)
end)
	
run(function()
	local Tracers
	local Targets
	local Color
	local Transparency
	local StartPosition
	local EndPosition
	local Teammates
	local DistanceColor
	local Distance
	local DistanceLimit
	local Behind
	local Reference = {}
	
	local function Added(ent)
		if not Targets.Players.Enabled and ent.Player then return end
		if not Targets.NPCs.Enabled and ent.NPC then return end
		if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		local EntityTracer = Drawing.new('Line')
		EntityTracer.Thickness = 1
		EntityTracer.Transparency = 1 - Transparency.Value
		EntityTracer.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		Reference[ent] = EntityTracer
	end
	
	local function Removed(ent)
		local v = Reference[ent]
		if v then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			Reference[ent] = nil
			pcall(function()
				v.Visible = false
				v:Remove()
			end)
		end
	end
	
	local function ColorFunc(hue, sat, val)
		if DistanceColor.Enabled then return end
		local tracerColor = Color3.fromHSV(hue, sat, val)
		for ent, EntityTracer in Reference do
			EntityTracer.Color = entitylib.getEntityColor(ent) or tracerColor
		end
	end
	
	local function Loop()
		local screenSize = vape.gui.AbsoluteSize
		local startVector = StartPosition.Value == 'Mouse' and inputService:GetMouseLocation() or Vector2.new(screenSize.X / 2, (StartPosition.Value == 'Middle' and screenSize.Y / 2 or screenSize.Y))
	
		for ent, EntityTracer in Reference do
			local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude
			if Distance.Enabled and distance then
				if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
					EntityTracer.Visible = false
					continue
				end
			end
	
			local pos = ent[EndPosition.Value == 'Torso' and 'RootPart' or 'Head'].Position
			local rootPos, rootVis = gameCamera:WorldToViewportPoint(pos)
			if not rootVis and Behind.Enabled then
				local tempPos = gameCamera.CFrame:PointToObjectSpace(pos)
				tempPos = CFrame.Angles(0, 0, (math.atan2(tempPos.Y, tempPos.X) + math.pi)):VectorToWorldSpace((CFrame.Angles(0, math.rad(89.9), 0):VectorToWorldSpace(Vector3.new(0, 0, -1))))
				rootPos = gameCamera:WorldToViewportPoint(gameCamera.CFrame:pointToWorldSpace(tempPos))
				rootVis = true
			end
	
			local endVector = Vector2.new(rootPos.X, rootPos.Y)
			EntityTracer.Visible = rootVis
			EntityTracer.From = startVector
			EntityTracer.To = endVector
			if DistanceColor.Enabled and distance then
				EntityTracer.Color = Color3.fromHSV(math.min((distance / 128) / 2.8, 0.4), 0.89, 0.75)
			end
		end
	end
	
	Tracers = vape.Categories.Render:CreateModule({
		Name = 'Tracers',
		Function = function(callback)
			if callback then
				Tracers:Clean(entitylib.Events.EntityRemoved:Connect(Removed))
				for _, v in entitylib.List do
					if Reference[v] then
						Removed(v)
					end
					Added(v)
				end
				Tracers:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
					if Reference[ent] then
						Removed(ent)
					end
					Added(ent)
				end))
				Tracers:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
					ColorFunc(Color.Hue, Color.Sat, Color.Value)
				end))
				Tracers:Clean(runService.RenderStepped:Connect(Loop))
			else
				for i in Reference do
					Removed(i)
				end
			end
		end,
		Tooltip = 'Renders tracers on players.'
	})
	Targets = Tracers:CreateTargets({
		Players = true,
		Function = function()
			if Tracers.Enabled then
				Tracers:Toggle()
				Tracers:Toggle()
			end
		end
	})
	StartPosition = Tracers:CreateDropdown({
		Name = 'Start Position',
		List = {'Middle', 'Bottom', 'Mouse'},
		Function = function()
			if Tracers.Enabled then
				Tracers:Toggle()
				Tracers:Toggle()
			end
		end
	})
	EndPosition = Tracers:CreateDropdown({
		Name = 'End Position',
		List = {'Head', 'Torso'},
		Function = function()
			if Tracers.Enabled then
				Tracers:Toggle()
				Tracers:Toggle()
			end
		end
	})
	Color = Tracers:CreateColorSlider({
		Name = 'Player Color',
		Function = function(hue, sat, val)
			if Tracers.Enabled then
				ColorFunc(hue, sat, val)
			end
		end
	})
	Transparency = Tracers:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Function = function(val)
			for _, tracer in Reference do
				tracer.Transparency = 1 - val
			end
		end,
		Decimal = 10
	})
	DistanceColor = Tracers:CreateToggle({
		Name = 'Color by distance',
		Function = function()
			if Tracers.Enabled then
				Tracers:Toggle()
				Tracers:Toggle()
			end
		end
	})
	Distance = Tracers:CreateToggle({
		Name = 'Distance Check',
		Function = function(callback)
			DistanceLimit.Object.Visible = callback
		end
	})
	DistanceLimit = Tracers:CreateTwoSlider({
		Name = 'Player Distance',
		Min = 0,
		Max = 256,
		DefaultMin = 0,
		DefaultMax = 64,
		Darker = true,
		Visible = false
	})
	Behind = Tracers:CreateToggle({
		Name = 'Behind',
		Default = true
	})
	Teammates = Tracers:CreateToggle({
		Name = 'Priority Only',
		Function = function()
			if Tracers.Enabled then
				Tracers:Toggle()
				Tracers:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Hides teammates & non targetable entities'
	})
end)
	
run(function()
	local Waypoints
	local FontOption
	local List
	local Color
	local Scale
	local Background
	WaypointFolder = Instance.new('Folder')
	WaypointFolder.Parent = vape.gui
	
	Waypoints = vape.Categories.Render:CreateModule({
		Name = 'Waypoints',
		Function = function(callback)
			if callback then
				for _, v in List.ListEnabled do
					local split = v:split('/')
					local tagSize = getfontsize(removeTags(split[2]), 14 * Scale.Value, FontOption.Value, Vector2.new(100000, 100000))
					local billboard = Instance.new('BillboardGui')
					billboard.Size = UDim2.fromOffset(tagSize.X + 8, tagSize.Y + 7)
					billboard.StudsOffsetWorldSpace = Vector3.new(unpack(split[1]:split(',')))
					billboard.AlwaysOnTop = true
					billboard.Parent = WaypointFolder
					local tag = Instance.new('TextLabel')
					tag.BackgroundColor3 = Color3.new()
					tag.BorderSizePixel = 0
					tag.Visible = true
					tag.RichText = true
					tag.FontFace = FontOption.Value
					tag.TextSize = 14 * Scale.Value
					tag.BackgroundTransparency = Background.Value
					tag.Size = billboard.Size
					tag.Text = split[2]
					tag.TextColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
					tag.Parent = billboard
				end
			else
				WaypointFolder:ClearAllChildren()
			end
		end,
		Tooltip = 'Mark certain spots with a visual indicator'
	})
	FontOption = Waypoints:CreateFont({
		Name = 'Font',
		Blacklist = 'Arial',
		Function = function()
			if Waypoints.Enabled then
				Waypoints:Toggle()
				Waypoints:Toggle()
			end
		end,
	})
	List = Waypoints:CreateTextList({
		Name = 'Points',
		Placeholder = 'x, y, z/name',
		Function = function()
			if Waypoints.Enabled then
				Waypoints:Toggle()
				Waypoints:Toggle()
			end
		end
	})
	Waypoints:CreateButton({
		Name = 'Add current position',
		Function = function()
			if entitylib.isAlive then
				local pos = entitylib.character.RootPart.Position // 1
				List:ChangeValue(pos.X..','..pos.Y..','..pos.Z..'/Waypoint '..(#List.List + 1))
			end
		end
	})
	Color = Waypoints:CreateColorSlider({
		Name = 'Color',
		Function = function(hue, sat, val)
			for _, v in WaypointFolder:GetChildren() do
				v.TextLabel.TextColor3 = Color3.fromHSV(hue, sat, val)
			end
		end
	})
	Scale = Waypoints:CreateSlider({
		Name = 'Scale',
		Function = function()
			if Waypoints.Enabled then
				Waypoints:Toggle()
				Waypoints:Toggle()
			end
		end,
		Default = 1,
		Min = 0.1,
		Max = 1.5,
		Decimal = 10
	})
	Background = Waypoints:CreateSlider({
		Name = 'Transparency',
		Function = function()
			if Waypoints.Enabled then
				Waypoints:Toggle()
				Waypoints:Toggle()
			end
		end,
		Default = 0.5,
		Min = 0,
		Max = 1,
		Decimal = 10
	})
	
end)
	
run(function()
	local AnimationPlayer
	local IDBox
	local Priority
	local Speed
	local anim, animobject
	
	local function playAnimation(char)
		local animcheck = anim
		if animcheck then
			anim = nil
			animcheck:Stop()
		end
	
		local suc, res = pcall(function()
			anim = char.Humanoid.Animator:LoadAnimation(animobject)
		end)
	
		if suc then
			local currentanim = anim
			anim.Priority = Enum.AnimationPriority[Priority.Value]
			anim:Play()
			anim:AdjustSpeed(Speed.Value)
			AnimationPlayer:Clean(anim.Stopped:Connect(function()
				if currentanim == anim then
					anim:Play()
				end
			end))
		else
			notif('AnimationPlayer', 'failed to load anim : '..(res or 'invalid animation id'), 5, 'warning')
		end
	end
	
	AnimationPlayer = vape.Categories.Utility:CreateModule({
		Name = 'AnimationPlayer',
		Function = function(callback)
			if callback then
				animobject = Instance.new('Animation')
				local suc, id = pcall(function()
					return string.match(game:GetObjects('rbxassetid://'..IDBox.Value)[1].AnimationId, '%?id=(%d+)')
				end)
				animobject.AnimationId = 'rbxassetid://'..(suc and id or IDBox.Value)
	
				if entitylib.isAlive then
					playAnimation(entitylib.character)
				end
				AnimationPlayer:Clean(entitylib.Events.LocalAdded:Connect(playAnimation))
				AnimationPlayer:Clean(animobject)
			else
				if anim then
					anim:Stop()
				end
			end
		end,
		Tooltip = 'Plays a specific animation of your choosing at a certain speed'
	})
	IDBox = AnimationPlayer:CreateTextBox({
		Name = 'Animation',
		Placeholder = 'anim (num only)',
		Function = function(enter)
			if enter and AnimationPlayer.Enabled then
				AnimationPlayer:Toggle()
				AnimationPlayer:Toggle()
			end
		end
	})
	local prio = {'Action4'}
	for _, v in Enum.AnimationPriority:GetEnumItems() do
		if v.Name ~= 'Action4' then
			table.insert(prio, v.Name)
		end
	end
	Priority = AnimationPlayer:CreateDropdown({
		Name = 'Priority',
		List = prio,
		Function = function(val)
			if anim then
				anim.Priority = Enum.AnimationPriority[val]
			end
		end
	})
	Speed = AnimationPlayer:CreateSlider({
		Name = 'Speed',
		Function = function(val)
			if anim then
				anim:AdjustSpeed(val)
			end
		end,
		Min = 0.1,
		Max = 2,
		Decimal = 10
	})
end)
	
run(function()
	local AntiRagdoll
	
	AntiRagdoll = vape.Categories.Utility:CreateModule({
		Name = 'AntiRagdoll',
		Function = function(callback)
			if entitylib.isAlive then
				entitylib.character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not callback)
			end
	
			if callback then
				AntiRagdoll:Clean(entitylib.Events.LocalAdded:Connect(function(char)
					char.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
				end))
			end
		end,
		Tooltip = 'Prevents you from getting knocked down in a ragdoll state'
	})
end)
	
run(function()
	local AutoRejoin
	local Sort
	
	AutoRejoin = vape.Categories.Utility:CreateModule({
		Name = 'AutoRejoin',
		Function = function(callback)
			if callback then
				local check
				AutoRejoin:Clean(guiService.ErrorMessageChanged:Connect(function(str)
					if (not check or guiService:GetErrorCode() ~= Enum.ConnectionError.DisconnectLuaKick) and guiService:GetErrorCode() ~= Enum.ConnectionError.DisconnectConnectionLost and not str:lower():find('ban') then
						check = true
						serverHop(nil, Sort.Value)
					end
				end))
			end
		end,
		Tooltip = 'Automatically rejoins into a new server if you get disconnected / kicked'
	})
	Sort = AutoRejoin:CreateDropdown({
		Name = 'Sort',
		List = {'Descending', 'Ascending'},
		Tooltip = 'Descending - Prefers full servers\nAscending - Prefers empty servers'
	})
end)
	
run(function()
	local Blink
	local Type
	local AutoSend
	local AutoSendLength
	local oldphys, oldsend
	
	Blink = vape.Categories.Utility:CreateModule({
		Name = 'Blink',
		Function = function(callback)
			if callback then
				local teleported
				Blink:Clean(lplr.OnTeleport:Connect(function()
					setfflag('PhysicsSenderMaxBandwidthBps', '38760')
					setfflag('DataSenderRate', '60')
					teleported = true
				end))
	
				repeat
					local physicsrate, senderrate = '0', Type.Value == 'All' and '-1' or '60'
					if AutoSend.Enabled and tick() % (AutoSendLength.Value + 0.1) > AutoSendLength.Value then
						physicsrate, senderrate = '38760', '60'
					end
	
					if physicsrate ~= oldphys or senderrate ~= oldsend then
						setfflag('PhysicsSenderMaxBandwidthBps', physicsrate)
						setfflag('DataSenderRate', senderrate)
						oldphys, oldsend = physicsrate, senderrate
					end
	
					task.wait(0.03)
				until (not Blink.Enabled and not teleported)
			else
				if setfflag then
					setfflag('PhysicsSenderMaxBandwidthBps', '38760')
					setfflag('DataSenderRate', '60')
				end
				oldphys, oldsend = nil, nil
			end
		end,
		Tooltip = 'Chokes packets until disabled.'
	})
	Type = Blink:CreateDropdown({
		Name = 'Type',
		List = {'Movement Only', 'All'},
		Tooltip = 'Movement Only - Only chokes movement packets\nAll - Chokes remotes & movement'
	})
	AutoSend = Blink:CreateToggle({
		Name = 'Auto send',
		Function = function(callback)
			AutoSendLength.Object.Visible = callback
		end,
		Tooltip = 'Automatically send packets in intervals'
	})
	AutoSendLength = Blink:CreateSlider({
		Name = 'Send threshold',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
end)
	
run(function()
	local ChatSpammer
	local Lines
	local Mode
	local Delay
	local Hide
	local oldchat
	
	ChatSpammer = vape.Categories.Utility:CreateModule({
		Name = 'ChatSpammer',
		Function = function(callback)
			if callback then
				if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
					if Hide.Enabled and coreGui:FindFirstChild('ExperienceChat') then
						ChatSpammer:Clean(coreGui.ExperienceChat:FindFirstChild('RCTScrollContentView', true).ChildAdded:Connect(function(msg)
							if msg.Name:sub(1, 2) == '0-' and msg.ContentText == 'You must wait before sending another message.' then
								msg.Visible = false
							end
						end))
					end
				elseif replicatedStorage:FindFirstChild('DefaultChatSystemChatEvents') then
					if Hide.Enabled then
						oldchat = hookfunction(getconnections(replicatedStorage.DefaultChatSystemChatEvents.OnNewSystemMessage.OnClientEvent)[1].Function, function(data, ...)
							if data.Message:find('ChatFloodDetector') then return end
							return oldchat(data, ...)
						end)
					end
				else
					notif('ChatSpammer', 'unsupported chat', 5, 'warning')
					ChatSpammer:Toggle()
					return
				end
				
				local ind = 1
				repeat
					local message = (#Lines.ListEnabled > 0 and Lines.ListEnabled[math.random(1, #Lines.ListEnabled)] or 'vxpe on top')
					if Mode.Value == 'Order' and #Lines.ListEnabled > 0 then
						message = Lines.ListEnabled[ind] or Lines.ListEnabled[1]
						ind = (ind % #Lines.ListEnabled) + 1
					end
	
					if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
						textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(message)
					else
						replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(message, 'All')
					end
	
					task.wait(Delay.Value)
				until not ChatSpammer.Enabled
			else
				if oldchat then
					hookfunction(getconnections(replicatedStorage.DefaultChatSystemChatEvents.OnNewSystemMessage.OnClientEvent)[1].Function, oldchat)
				end
			end
		end,
		Tooltip = 'Automatically types in chat'
	})
	Lines = ChatSpammer:CreateTextList({Name = 'Lines'})
	Mode = ChatSpammer:CreateDropdown({
		Name = 'Mode',
		List = {'Random', 'Order'}
	})
	Delay = ChatSpammer:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 10,
		Default = 1,
		Decimal = 10,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	Hide = ChatSpammer:CreateToggle({
		Name = 'Hide Flood Message',
		Default = true,
		Function = function()
			if ChatSpammer.Enabled then
				ChatSpammer:Toggle()
				ChatSpammer:Toggle()
			end
		end
	})
end)
	
run(function()
	local Disabler
	
	local function characterAdded(char)
		for _, v in getconnections(char.RootPart:GetPropertyChangedSignal('CFrame')) do
			hookfunction(v.Function, function() end)
		end
		for _, v in getconnections(char.RootPart:GetPropertyChangedSignal('Velocity')) do
			hookfunction(v.Function, function() end)
		end
	end
	
	Disabler = vape.Categories.Utility:CreateModule({
		Name = 'Disabler',
		Function = function(callback)
			if callback then
				Disabler:Clean(entitylib.Events.LocalAdded:Connect(characterAdded))
				if entitylib.isAlive then
					characterAdded(entitylib.character)
				end
			end
		end,
		Tooltip = 'Disables GetPropertyChangedSignal detections for movement'
	})
end)
	
run(function()
	vape.Categories.Utility:CreateModule({
		Name = 'Panic',
		Function = function(callback)
			if callback then
				for _, v in vape.Modules do
					if v.Enabled then
						v:Toggle()
					end
				end
			end
		end,
		Tooltip = 'Disables all currently enabled modules'
	})
end)
	
run(function()
	local Rejoin
	
	Rejoin = vape.Categories.Utility:CreateModule({
		Name = 'Rejoin',
		Function = function(callback)
			if callback then
				notif('Rejoin', 'Rejoining...', 5)
				Rejoin:Toggle()
				if playersService.NumPlayers > 1 then
					teleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId)
				else
					teleportService:Teleport(game.PlaceId)
				end
			end
		end,
		Tooltip = 'Rejoins the server'
	})
end)
	
run(function()
	local ServerHop
	local Sort
	
	ServerHop = vape.Categories.Utility:CreateModule({
		Name = 'ServerHop',
		Function = function(callback)
			if callback then
				ServerHop:Toggle()
				serverHop(nil, Sort.Value)
			end
		end,
		Tooltip = 'Teleports into a unique server'
	})
	Sort = ServerHop:CreateDropdown({
		Name = 'Sort',
		List = {'Descending', 'Ascending'},
		Tooltip = 'Descending - Prefers full servers\nAscending - Prefers empty servers'
	})
	ServerHop:CreateButton({
		Name = 'Rejoin Previous Server',
		Function = function()
			notif('ServerHop', shared.vapeserverhopprevious and 'Rejoining previous server...' or 'Cannot find previous server', 5)
			if shared.vapeserverhopprevious then
				teleportService:TeleportToPlaceInstance(game.PlaceId, shared.vapeserverhopprevious)
			end
		end
	})
end)
	
run(function()
	local StaffDetector
	local Mode
	local Profile
	local Users
	local Group
	local Role
	
	local function getRole(plr, id)
		local suc, res
		for _ = 1, 3 do
			suc, res = pcall(function()
				return plr:GetRankInGroup(id)
			end)
			if suc then break end
		end
		return suc and res or 0
	end
	
	local function getLowestStaffRole(roles)
		local highest = math.huge
		for _, v in roles do
			local low = v.Name:lower()
			if (low:find('admin') or low:find('mod') or low:find('dev')) and v.Rank < highest then
				highest = v.Rank
			end
		end
		return highest
	end
	
	local function playerAdded(plr)
		if not vape.Loaded then
			repeat task.wait() until vape.Loaded
		end
	
		local user = table.find(Users.ListEnabled, tostring(plr.UserId))
		if user or getRole(plr, tonumber(Group.Value) or 0) >= (tonumber(Role.Value) or 1) then
			notif('StaffDetector', 'Staff Detected ('..(user and 'blacklisted_user' or 'staff_role')..'): '..plr.Name, 60, 'alert')
			whitelist.customtags[plr.Name] = {{text = 'GAME STAFF', color = Color3.new(1, 0, 0)}}
	
			if Mode.Value == 'Uninject' then
				task.spawn(function()
					vape:Uninject()
				end)
				game:GetService('StarterGui'):SetCore('SendNotification', {
					Title = 'StaffDetector',
					Text = 'Staff Detected\n'..plr.Name,
					Duration = 60,
				})
			elseif Mode.Value == 'ServerHop' then
				serverHop()
			elseif Mode.Value == 'Profile' then
				vape.Save = function() end
				if vape.Profile ~= Profile.Value then
					vape.Profile = Profile.Value
					vape:Load(true, Profile.Value)
				end
			elseif Mode.Value == 'AutoConfig' then
				vape.Save = function() end
				for _, v in vape.Modules do
					if v.Enabled then
						v:Toggle()
					end
				end
			end
		end
	end
	
	StaffDetector = vape.Categories.Utility:CreateModule({
		Name = 'StaffDetector',
		Function = function(callback)
			if callback then
				if Group.Value == '' or Role.Value == '' then
					local placeinfo = {Creator = {CreatorTargetId = tonumber(Group.Value)}}
					if Group.Value == '' then
						placeinfo = marketplaceService:GetProductInfo(game.PlaceId)
						if placeinfo.Creator.CreatorType ~= 'Group' then
							local desc = placeinfo.Description:split('\n')
							for _, str in desc do
								local _, begin = str:find('roblox.com/groups/')
								if begin then
									local endof = str:find('/', begin + 1)
									placeinfo = {Creator = {
										CreatorType = 'Group',
										CreatorTargetId = str:sub(begin + 1, endof - 1)
									}}
								end
							end
						end
	
						if placeinfo.Creator.CreatorType ~= 'Group' then
							notif('StaffDetector', 'Automatic Setup Failed (no group detected)', 60, 'warning')
							return
						end
					end
	
					local groupinfo = groupService:GetGroupInfoAsync(placeinfo.Creator.CreatorTargetId)
					Group:SetValue(placeinfo.Creator.CreatorTargetId)
					Role:SetValue(getLowestStaffRole(groupinfo.Roles))
				end
	
				if Group.Value == '' or Role.Value == '' then
					return
				end
	
				StaffDetector:Clean(playersService.PlayerAdded:Connect(playerAdded))
				for _, v in playersService:GetPlayers() do
					task.spawn(playerAdded, v)
				end
			end
		end,
		Tooltip = 'Detects people with a staff rank ingame'
	})
	Mode = StaffDetector:CreateDropdown({
		Name = 'Mode',
		List = {'Uninject', 'ServerHop', 'Profile', 'AutoConfig', 'Notify'},
		Function = function(val)
			if Profile.Object then
				Profile.Object.Visible = val == 'Profile'
			end
		end
	})
	Profile = StaffDetector:CreateTextBox({
		Name = 'Profile',
		Default = 'default',
		Darker = true,
		Visible = false
	})
	Users = StaffDetector:CreateTextList({
		Name = 'Users',
		Placeholder = 'player (userid)'
	})
	Group = StaffDetector:CreateTextBox({
		Name = 'Group',
		Placeholder = 'Group Id'
	})
	Role = StaffDetector:CreateTextBox({
		Name = 'Role',
		Placeholder = 'Role Rank'
	})
end)
	
run(function()
	local connections = {}
	
	vape.Categories.World:CreateModule({
		Name = 'Anti-AFK',
		Function = function(callback)
			if callback then
				for _, v in getconnections(lplr.Idled) do
					table.insert(connections, v)
					v:Disable()
				end
			else
				for _, v in connections do
					v:Enable()
				end
				table.clear(connections)
			end
		end,
		Tooltip = 'Lets you stay ingame without getting kicked'
	})
end)
	
run(function()
	local Freecam
	local Value
	local randomkey, module, old = httpService:GenerateGUID(false)
	
	Freecam = vape.Categories.World:CreateModule({
		Name = 'Freecam',
		Function = function(callback)
			if callback then
				repeat
					task.wait(0.1)
					for _, v in getconnections(gameCamera:GetPropertyChangedSignal('CameraType')) do
						if v.Function then
							module = debug.getupvalue(v.Function, 1)
						end
					end
				until module or not Freecam.Enabled
	
				if module and module.activeCameraController and Freecam.Enabled then
					old = module.activeCameraController.GetSubjectPosition
					local camPos = old(module.activeCameraController) or Vector3.zero
					module.activeCameraController.GetSubjectPosition = function()
						return camPos
					end
	
					Freecam:Clean(runService.PreSimulation:Connect(function(dt)
						if not inputService:GetFocusedTextBox() then
							local forward = (inputService:IsKeyDown(Enum.KeyCode.W) and -1 or 0) + (inputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
							local side = (inputService:IsKeyDown(Enum.KeyCode.A) and -1 or 0) + (inputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0)
							local up = (inputService:IsKeyDown(Enum.KeyCode.Q) and -1 or 0) + (inputService:IsKeyDown(Enum.KeyCode.E) and 1 or 0)
							dt = dt * (inputService:IsKeyDown(Enum.KeyCode.LeftShift) and 0.25 or 1)
							camPos = (CFrame.lookAlong(camPos, gameCamera.CFrame.LookVector) * CFrame.new(Vector3.new(side, up, forward) * (Value.Value * dt))).Position
						end
					end))
	
					contextService:BindActionAtPriority('FreecamKeyboard'..randomkey, function()
						return Enum.ContextActionResult.Sink
					end, false, Enum.ContextActionPriority.High.Value,
						Enum.KeyCode.W,
						Enum.KeyCode.A,
						Enum.KeyCode.S,
						Enum.KeyCode.D,
						Enum.KeyCode.E,
						Enum.KeyCode.Q,
						Enum.KeyCode.Up,
						Enum.KeyCode.Down
					)
				end
			else
				pcall(function()
					contextService:UnbindAction('FreecamKeyboard'..randomkey)
				end)
				if module and old then
					module.activeCameraController.GetSubjectPosition = old
					module = nil
					old = nil
				end
			end
		end,
		Tooltip = 'Lets you fly and clip through walls freely\nwithout moving your player server-sided.'
	})
	Value = Freecam:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)
	
run(function()
	local Gravity
	local Mode
	local Value
	local changed, old = false
	
	Gravity = vape.Categories.World:CreateModule({
		Name = 'Gravity',
		Function = function(callback)
			if callback then
				if Mode.Value == 'Workspace' then
					old = workspace.Gravity
					workspace.Gravity = Value.Value
					Gravity:Clean(workspace:GetPropertyChangedSignal('Gravity'):Connect(function()
						if changed then return end
						changed = true
						old = workspace.Gravity
						workspace.Gravity = Value.Value
						changed = false
					end))
				else
					Gravity:Clean(runService.PreSimulation:Connect(function(dt)
						if entitylib.isAlive and entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air then
							local root = entitylib.character.RootPart
							if Mode.Value == 'Impulse' then
								root:ApplyImpulse(Vector3.new(0, dt * (workspace.Gravity - Value.Value), 0) * root.AssemblyMass)
							else
								root.AssemblyLinearVelocity += Vector3.new(0, dt * (workspace.Gravity - Value.Value), 0)
							end
						end
					end))
				end
			else
				if old then
					workspace.Gravity = old
					old = nil
				end
			end
		end,
		Tooltip = 'Changes the rate you fall'
	})
	Mode = Gravity:CreateDropdown({
		Name = 'Mode',
		List = {'Workspace', 'Velocity', 'Impulse'},
		Tooltip = 'Workspace - Adjusts the gravity for the entire game\nVelocity - Adjusts the local players gravity\nImpulse - Same as velocity while using forces instead'
	})
	Value = Gravity:CreateSlider({
		Name = 'Gravity',
		Min = 0,
		Max = 192,
		Function = function(val)
			if Gravity.Enabled and Mode.Value == 'Workspace' then
				changed = true
				workspace.Gravity = val
				changed = false
			end
		end,
		Default = 192
	})
end)
	
run(function()
	local Parkour
	
	Parkour = vape.Categories.World:CreateModule({
		Name = 'Parkour',
		Function = function(callback)
			if callback then 
				local oldfloor
				Parkour:Clean(runService.RenderStepped:Connect(function()
					if entitylib.isAlive then 
						local material = entitylib.character.Humanoid.FloorMaterial
						if material == Enum.Material.Air and oldfloor ~= Enum.Material.Air then 
							entitylib.character.Humanoid.Jump = true
						end
						oldfloor = material
					end
				end))
			end
		end,
		Tooltip = 'Automatically jumps after reaching the edge'
	})
end)
	
run(function()
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local module, old
	
	vape.Categories.World:CreateModule({
		Name = 'SafeWalk',
		Function = function(callback)
			if callback then
				if not module then
					local suc = pcall(function() 
						module = require(lplr.PlayerScripts.PlayerModule).controls 
					end)
					if not suc then module = {} end
				end
				
				old = module.moveFunction
				module.moveFunction = function(self, vec, face)
					if entitylib.isAlive then
						rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
						local root = entitylib.character.RootPart
						local movedir = root.Position + vec
						local ray = workspace:Raycast(movedir, Vector3.new(0, -15, 0), rayCheck)
						if not ray then
							local check = workspace:Blockcast(root.CFrame, Vector3.new(3, 1, 3), Vector3.new(0, -(entitylib.character.HipHeight + 1), 0), rayCheck)
							if check then
								vec = (check.Instance:GetClosestPointOnSurface(movedir) - root.Position) * Vector3.new(1, 0, 1)
							end
						end
					end
	
					return old(self, vec, face)
				end
			else
				if module and old then
					module.moveFunction = old
				end
			end
		end,
		Tooltip = 'Prevents you from walking off the edge of parts'
	})
end)
	
run(function()
	local Xray
	local List
	local modified = {}
	
	local function modifyPart(v)
		if v:IsA('BasePart') and not table.find(List.ListEnabled, v.Name) then
			modified[v] = true
			v.LocalTransparencyModifier = 0.5
		end
	end
	
	Xray = vape.Categories.World:CreateModule({
		Name = 'Xray',
		Function = function(callback)
			if callback then
				Xray:Clean(workspace.DescendantAdded:Connect(modifyPart))
				for _, v in workspace:GetDescendants() do
					modifyPart(v)
				end
			else
				for i in modified do
					i.LocalTransparencyModifier = 0
				end
				table.clear(modified)
			end
		end,
		Tooltip = 'Renders whitelisted parts through walls.'
	})
	List = Xray:CreateTextList({
		Name = 'Part',
		Function = function()
			if Xray.Enabled then
				Xray:Toggle()
				Xray:Toggle()
			end
		end
	})
end)
	
run(function()
	local MurderMystery
	local murderer, sheriff, oldtargetable, oldgetcolor
	
	local function itemAdded(v, plr)
		if v:IsA('Tool') then
			local check = v:FindFirstChild('IsGun') and 'sheriff' or v:FindFirstChild('KnifeServer') and 'murderer' or nil
			check = check or v.Name:lower():find('knife') and 'murderer' or v.Name:lower():find('gun') and 'sheriff' or nil
			if check == 'murderer' and plr ~= murderer then
				murderer = plr
				if plr.Character then
					entitylib.refresh()
				end
			elseif check == 'sheriff' and plr ~= sheriff then
				sheriff = plr
				if plr.Character then
					entitylib.refresh()
				end
			end
		end
	end
	
	local function playerAdded(plr)
		MurderMystery:Clean(plr.DescendantAdded:Connect(function(v)
			itemAdded(v, plr)
		end))
		local pack = plr:FindFirstChildWhichIsA('Backpack')
		if pack then
			for _, v in pack:GetChildren() do
				itemAdded(v, plr)
			end
		end
		if plr.Character then
			for _, v in plr.Character:GetChildren() do
				itemAdded(v, plr)
			end
		end
	end
	
	MurderMystery = vape.Categories.Minigames:CreateModule({
		Name = 'MurderMystery',
		Function = function(callback)
			if callback then
				oldtargetable, oldgetcolor = entitylib.targetCheck, entitylib.getEntityColor
				entitylib.getEntityColor = function(ent)
					ent = ent.Player
					if not (ent and vape.Categories.Main.Options['Use team color'].Enabled) then return end
					if isFriend(ent, true) then
						return Color3.fromHSV(vape.Categories.Friends.Options['Friends color'].Hue, vape.Categories.Friends.Options['Friends color'].Sat, vape.Categories.Friends.Options['Friends color'].Value)
					end
					return murderer == ent and Color3.new(1, 0.3, 0.3) or sheriff == ent and Color3.new(0, 0.5, 1) or nil
				end
				entitylib.targetCheck = function(ent)
					if ent.Player and isFriend(ent.Player) then return false end
					if murderer == lplr then return true end
					return murderer == ent.Player or sheriff == ent.Player
				end
				for _, v in playersService:GetPlayers() do
					playerAdded(v)
				end
				MurderMystery:Clean(playersService.PlayerAdded:Connect(playerAdded))
				entitylib.refresh()
			else
				entitylib.getEntityColor = oldgetcolor
				entitylib.targetCheck = oldtargetable
				entitylib.refresh()
			end
		end,
		Tooltip = 'Automatic murder mystery teaming based on equipped roblox tools.'
	})
end)
	
run(function()
	local Atmosphere
	local Toggles = {}
	local newobjects, oldobjects = {}, {}
	local apidump = {
		Sky = {
			SkyboxUp = 'Text',
			SkyboxDn = 'Text',
			SkyboxLf = 'Text',
			SkyboxRt = 'Text',
			SkyboxFt = 'Text',
			SkyboxBk = 'Text',
			SunTextureId = 'Text',
			SunAngularSize = 'Number',
			MoonTextureId = 'Text',
			MoonAngularSize = 'Number',
			StarCount = 'Number'
		},
		Atmosphere = {
			Color = 'Color',
			Decay = 'Color',
			Density = 'Number',
			Offset = 'Number',
			Glare = 'Number',
			Haze = 'Number'
		},
		BloomEffect = {
			Intensity = 'Number',
			Size = 'Number',
			Threshold = 'Number'
		},
		DepthOfFieldEffect = {
			FarIntensity = 'Number',
			FocusDistance = 'Number',
			InFocusRadius = 'Number',
			NearIntensity = 'Number'
		},
		SunRaysEffect = {
			Intensity = 'Number',
			Spread = 'Number'
		},
		ColorCorrectionEffect = {
			TintColor = 'Color',
			Saturation = 'Number',
			Contrast = 'Number',
			Brightness = 'Number'
		}
	}
	
	local function removeObject(v)
		if not table.find(newobjects, v) then
			local toggle = Toggles[v.ClassName]
			if toggle and toggle.Toggle.Enabled then
				if v.Parent then
					table.insert(oldobjects, v)
					v.Parent = game
				end
			end
		end
	end
	
	Atmosphere = vape.Legit:CreateModule({
		Name = 'Atmosphere',
		Function = function(callback)
			if callback then
				for _, v in lightingService:GetChildren() do
					removeObject(v)
				end
				Atmosphere:Clean(lightingService.ChildAdded:Connect(function(v)
					task.defer(removeObject, v)
				end))
	
				for i, v in Toggles do
					if v.Toggle.Enabled then
						local obj = Instance.new(i)
						for i2, v2 in v.Objects do
							if v2.Type == 'ColorSlider' then
								obj[i2] = Color3.fromHSV(v2.Hue, v2.Sat, v2.Value)
							else
								obj[i2] = apidump[i][i2] ~= 'Number' and v2.Value or tonumber(v2.Value) or 0
							end
						end
						obj.Parent = lightingService
						table.insert(newobjects, obj)
					end
				end
			else
				for _, v in newobjects do
					v:Destroy()
				end
				for _, v in oldobjects do
					v.Parent = lightingService
				end
				table.clear(newobjects)
				table.clear(oldobjects)
			end
		end,
		Tooltip = 'Custom lighting objects'
	})
	for i, v in apidump do
		Toggles[i] = {Objects = {}}
		Toggles[i].Toggle = Atmosphere:CreateToggle({
			Name = i,
			Function = function(callback)
				if Atmosphere.Enabled then
					Atmosphere:Toggle()
					Atmosphere:Toggle()
				end
				for _, toggle in Toggles[i].Objects do
					toggle.Object.Visible = callback
				end
			end
		})
	
		for i2, v2 in v do
			if v2 == 'Text' or v2 == 'Number' then
				Toggles[i].Objects[i2] = Atmosphere:CreateTextBox({
					Name = i2,
					Function = function(enter)
						if Atmosphere.Enabled and enter then
							Atmosphere:Toggle()
							Atmosphere:Toggle()
						end
					end,
					Darker = true,
					Default = v2 == 'Number' and '0' or nil,
					Visible = false
				})
			elseif v2 == 'Color' then
				Toggles[i].Objects[i2] = Atmosphere:CreateColorSlider({
					Name = i2,
					Function = function()
						if Atmosphere.Enabled then
							Atmosphere:Toggle()
							Atmosphere:Toggle()
						end
					end,
					Darker = true,
					Visible = false
				})
			end
		end
	end
end)
	
run(function()
	local Breadcrumbs
	local Texture
	local Lifetime
	local Thickness
	local FadeIn
	local FadeOut
	local trail, point, point2
	
	Breadcrumbs = vape.Legit:CreateModule({
		Name = 'Breadcrumbs',
		Function = function(callback)
			if callback then
				point = Instance.new('Attachment')
				point.Position = Vector3.new(0, Thickness.Value - 2.7, 0)
				point2 = Instance.new('Attachment')
				point2.Position = Vector3.new(0, -Thickness.Value - 2.7, 0)
				trail = Instance.new('Trail')
				trail.Texture = Texture.Value == '' and 'http://www.roblox.com/asset/?id=14166981368' or Texture.Value
				trail.TextureMode = Enum.TextureMode.Static
				trail.Color = ColorSequence.new(Color3.fromHSV(FadeIn.Hue, FadeIn.Sat, FadeIn.Value), Color3.fromHSV(FadeOut.Hue, FadeOut.Sat, FadeOut.Value))
				trail.Lifetime = Lifetime.Value
				trail.Attachment0 = point
				trail.Attachment1 = point2
				trail.FaceCamera = true
	
				Breadcrumbs:Clean(trail)
				Breadcrumbs:Clean(point)
				Breadcrumbs:Clean(point2)
				Breadcrumbs:Clean(entitylib.Events.LocalAdded:Connect(function(ent)
					point.Parent = ent.HumanoidRootPart
					point2.Parent = ent.HumanoidRootPart
					trail.Parent = gameCamera
				end))
				if entitylib.isAlive then
					point.Parent = entitylib.character.RootPart
					point2.Parent = entitylib.character.RootPart
					trail.Parent = gameCamera
				end
			else
				trail = nil
				point = nil
				point2 = nil
			end
		end,
		Tooltip = 'Shows a trail behind your character'
	})
	Texture = Breadcrumbs:CreateTextBox({
		Name = 'Texture',
		Placeholder = 'Texture Id',
		Function = function(enter)
			if enter and trail then
				trail.Texture = Texture.Value == '' and 'http://www.roblox.com/asset/?id=14166981368' or Texture.Value
			end
		end
	})
	FadeIn = Breadcrumbs:CreateColorSlider({
		Name = 'Fade In',
		Function = function(hue, sat, val)
			if trail then
				trail.Color = ColorSequence.new(Color3.fromHSV(hue, sat, val), Color3.fromHSV(FadeOut.Hue, FadeOut.Sat, FadeOut.Value))
			end
		end
	})
	FadeOut = Breadcrumbs:CreateColorSlider({
		Name = 'Fade Out',
		Function = function(hue, sat, val)
			if trail then
				trail.Color = ColorSequence.new(Color3.fromHSV(FadeIn.Hue, FadeIn.Sat, FadeIn.Value), Color3.fromHSV(hue, sat, val))
			end
		end
	})
	Lifetime = Breadcrumbs:CreateSlider({
		Name = 'Lifetime',
		Min = 1,
		Max = 5,
		Default = 3,
		Decimal = 10,
		Function = function(val)
			if trail then
				trail.Lifetime = val
			end
		end,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	Thickness = Breadcrumbs:CreateSlider({
		Name = 'Thickness',
		Min = 0,
		Max = 2,
		Default = 0.1,
		Decimal = 100,
		Function = function(val)
			if point then
				point.Position = Vector3.new(0, val - 2.7, 0)
			end
			if point2 then
				point2.Position = Vector3.new(0, -val - 2.7, 0)
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)
	
run(function()
	local Cape
	local Texture
	local part, motor
	
	local function createMotor(char)
		if motor then 
			motor:Destroy() 
		end
		part.Parent = gameCamera
		motor = Instance.new('Motor6D')
		motor.MaxVelocity = 0.08
		motor.Part0 = part
		motor.Part1 = char.Character:FindFirstChild('UpperTorso') or char.RootPart
		motor.C0 = CFrame.new(0, 2, 0) * CFrame.Angles(0, math.rad(-90), 0)
		motor.C1 = CFrame.new(0, motor.Part1.Size.Y / 2, 0.45) * CFrame.Angles(0, math.rad(90), 0)
		motor.Parent = part
	end
	
	Cape = vape.Legit:CreateModule({
		Name = 'Cape',
		Function = function(callback)
			if callback then
				part = Instance.new('Part')
				part.Size = Vector3.new(2, 4, 0.1)
				part.CanCollide = false
				part.CanQuery = false
				part.Massless = true
				part.Transparency = 0
				part.Material = Enum.Material.SmoothPlastic
				part.Color = Color3.new()
				part.CastShadow = false
				part.Parent = gameCamera
				local capesurface = Instance.new('SurfaceGui')
				capesurface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				capesurface.Adornee = part
				capesurface.Parent = part
	
				if Texture.Value:find('.webm') then
					local decal = Instance.new('VideoFrame')
					decal.Video = getcustomasset(Texture.Value)
					decal.Size = UDim2.fromScale(1, 1)
					decal.BackgroundTransparency = 1
					decal.Looped = true
					decal.Parent = capesurface
					decal:Play()
				else
					local decal = Instance.new('ImageLabel')
					decal.Image = Texture.Value ~= '' and (Texture.Value:find('rbxasset') and Texture.Value or assetfunction(Texture.Value)) or 'rbxassetid://14637958134'
					decal.Size = UDim2.fromScale(1, 1)
					decal.BackgroundTransparency = 1
					decal.Parent = capesurface
				end
				Cape:Clean(part)
				Cape:Clean(entitylib.Events.LocalAdded:Connect(createMotor))
				if entitylib.isAlive then
					createMotor(entitylib.character)
				end
	
				repeat
					if motor and entitylib.isAlive then
						local velo = math.min(entitylib.character.RootPart.Velocity.Magnitude, 90)
						motor.DesiredAngle = math.rad(6) + math.rad(velo) + (velo > 1 and math.abs(math.cos(tick() * 5)) / 3 or 0)
					end
					capesurface.Enabled = (gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude > 0.6
					part.Transparency = (gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude > 0.6 and 0 or 1
					task.wait()
				until not Cape.Enabled
			else
				part = nil
				motor = nil
			end
		end,
		Tooltip = 'Add\'s a cape to your character'
	})
	Texture = Cape:CreateTextBox({
		Name = 'Texture'
	})
end)
	
run(function()
	local ChinaHat
	local Material
	local Color
	local hat
	
	ChinaHat = vape.Legit:CreateModule({
		Name = 'China Hat',
		Function = function(callback)
			if callback then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				hat = Instance.new('MeshPart')
				hat.Size = Vector3.new(3, 0.7, 3)
				hat.Name = 'ChinaHat'
				hat.Material = Enum.Material[Material.Value]
				hat.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
				hat.CanCollide = false
				hat.CanQuery = false
				hat.Massless = true
				hat.MeshId = 'http://www.roblox.com/asset/?id=1778999'
				hat.Transparency = 1 - Color.Opacity
				hat.Parent = gameCamera
				hat.CFrame = entitylib.isAlive and entitylib.character.Head.CFrame + Vector3.new(0, 1, 0) or CFrame.identity
				local weld = Instance.new('WeldConstraint')
				weld.Part0 = hat
				weld.Part1 = entitylib.isAlive and entitylib.character.Head or nil
				weld.Parent = hat
				ChinaHat:Clean(hat)
				ChinaHat:Clean(entitylib.Events.LocalAdded:Connect(function(char)
					if weld then 
						weld:Destroy() 
					end
					hat.Parent = gameCamera
					hat.CFrame = char.Head.CFrame + Vector3.new(0, 1, 0)
					hat.Velocity = Vector3.zero
					weld = Instance.new('WeldConstraint')
					weld.Part0 = hat
					weld.Part1 = char.Head
					weld.Parent = hat
				end))
	
				repeat
					hat.LocalTransparencyModifier = ((gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude <= 0.6 and 1 or 0)
					task.wait()
				until not ChinaHat.Enabled
			else
				hat = nil
			end
		end,
		Tooltip = 'Puts a china hat on your character (ty mastadawn)'
	})
	local materials = {'ForceField'}
	for _, v in Enum.Material:GetEnumItems() do
		if v.Name ~= 'ForceField' then
			table.insert(materials, v.Name)
		end
	end
	Material = ChinaHat:CreateDropdown({
		Name = 'Material',
		List = materials,
		Function = function(val)
			if hat then
				hat.Material = Enum.Material[val]
			end
		end
	})
	Color = ChinaHat:CreateColorSlider({
		Name = 'Hat Color',
		DefaultOpacity = 0.7,
		Function = function(hue, sat, val, opacity)
			if hat then
				hat.Color = Color3.fromHSV(hue, sat, val)
				hat.Transparency = 1 - opacity
			end
		end
	})
end)
	
run(function()
	local Clock
	local TwentyFourHour
	local label
	
	Clock = vape.Legit:CreateModule({
		Name = 'Clock',
		Function = function(callback)
			if callback then
				repeat
					label.Text = DateTime.now():FormatLocalTime('LT', TwentyFourHour.Enabled and 'zh-cn' or 'en-us')
					task.wait(1)
				until not Clock.Enabled
			end
		end,
		Size = UDim2.fromOffset(100, 41),
		Tooltip = 'Shows the current local time'
	})
	Clock:CreateFont({
		Name = 'Font',
		Blacklist = 'Gotham',
		Function = function(val)
			label.FontFace = val
		end
	})
	Clock:CreateColorSlider({
		Name = 'Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			label.BackgroundTransparency = 1 - opacity
		end
	})
	TwentyFourHour = Clock:CreateToggle({
		Name = '24 Hour Clock'
	})
	label = Instance.new('TextLabel')
	label.Size = UDim2.new(0, 100, 0, 41)
	label.BackgroundTransparency = 0.5
	label.TextSize = 15
	label.Font = Enum.Font.Gotham
	label.Text = '0:00 PM'
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundColor3 = Color3.new()
	label.Parent = Clock.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
end)
	
run(function()
	local Disguise
	local Mode
	local IDBox
	local desc
	
	local function itemAdded(v, manual)
		if (not v:GetAttribute('Disguise')) and ((v:IsA('Accessory') and (not v:GetAttribute('InvItem')) and (not v:GetAttribute('ArmorSlot'))) or v:IsA('ShirtGraphic') or v:IsA('Shirt') or v:IsA('Pants') or v:IsA('BodyColors') or manual) then
			repeat
				task.wait()
				v.Parent = game
			until v.Parent == game
			v:ClearAllChildren()
			v:Destroy()
		end
	end
	
	local function characterAdded(char)
		if Mode.Value == 'Character' then
			task.wait(0.1)
			char.Character.Archivable = true
			local clone = char.Character:Clone()
			repeat
				if pcall(function()
					desc = playersService:GetHumanoidDescriptionFromUserId(IDBox.Value == '' and 239702688 or tonumber(IDBox.Value))
				end) and desc then break end
				task.wait(1)
			until not Disguise.Enabled
			if not Disguise.Enabled then
				clone:ClearAllChildren()
				clone:Destroy()
				clone = nil
				if desc then
					desc:Destroy()
					desc = nil
				end
				return
			end
			clone.Parent = game
	
			local originalDesc = char.Humanoid:WaitForChild('HumanoidDescription', 2) or {
				HeightScale = 1,
				SetEmotes = function() end,
				SetEquippedEmotes = function() end
			}
			originalDesc.JumpAnimation = desc.JumpAnimation
			desc.HeightScale = originalDesc.HeightScale
	
			for _, v in clone:GetChildren() do
				if v:IsA('Accessory') or v:IsA('ShirtGraphic') or v:IsA('Shirt') or v:IsA('Pants') then
					v:ClearAllChildren()
					v:Destroy()
				end
			end
	
			clone.Humanoid:ApplyDescriptionClientServer(desc)
			for _, v in char.Character:GetChildren() do
				itemAdded(v)
			end
			Disguise:Clean(char.Character.ChildAdded:Connect(itemAdded))
	
			for _, v in clone:WaitForChild('Animate'):GetChildren() do
				if not char.Character:FindFirstChild('Animate') then return end
				local real = char.Character.Animate:FindFirstChild(v.Name)
				if v and real then
					local anim = v:FindFirstChildWhichIsA('Animation') or {AnimationId = ''}
					local realanim = real:FindFirstChildWhichIsA('Animation') or {AnimationId = ''}
					if realanim then
						realanim.AnimationId = anim.AnimationId
					end
				end
			end
	
			for _, v in clone:GetChildren() do
				v:SetAttribute('Disguise', true)
				if v:IsA('Accessory') then
					for _, v2 in v:GetDescendants() do
						if v2:IsA('Weld') and v2.Part1 then
							v2.Part1 = char.Character[v2.Part1.Name]
						end
					end
					v.Parent = char.Character
				elseif v:IsA('ShirtGraphic') or v:IsA('Shirt') or v:IsA('Pants') or v:IsA('BodyColors') then
					v.Parent = char.Character
				elseif v.Name == 'Head' and char.Head:IsA('MeshPart') and (not char.Head:FindFirstChild('FaceControls')) then
					char.Head.MeshId = v.MeshId
				end
			end
	
			local localface = char.Character:FindFirstChild('face', true)
			local cloneface = clone:FindFirstChild('face', true)
			if localface and cloneface then
				itemAdded(localface, true)
				cloneface.Parent = char.Head
			end
			originalDesc:SetEmotes(desc:GetEmotes())
			originalDesc:SetEquippedEmotes(desc:GetEquippedEmotes())
			clone:ClearAllChildren()
			clone:Destroy()
			clone = nil
			if desc then
				desc:Destroy()
				desc = nil
			end
		else
			local data
			repeat
				if pcall(function()
					data = marketplaceService:GetProductInfo(IDBox.Value == '' and 43 or tonumber(IDBox.Value), Enum.InfoType.Bundle)
				end) then break end
				task.wait(1)
			until not Disguise.Enabled
			if not Disguise.Enabled then
				if data then
					table.clear(data)
					data = nil
				end
				return
			end
			if data.BundleType == 'AvatarAnimations' then
				local animate = char.Character:FindFirstChild('Animate')
				if not animate then return end
				for _, v in desc.Items do
					local animtype = v.Name:split(' ')[2]:lower()
					if animtype ~= 'animation' then
						local suc, res = pcall(function() return game:GetObjects('rbxassetid://'..v.Id) end)
						if suc then
							animate[animtype]:FindFirstChildWhichIsA('Animation').AnimationId = res[1]:FindFirstChildWhichIsA('Animation', true).AnimationId
						end
					end
				end
			else
				notif('Disguise', 'that\'s not an animation pack', 5, 'warning')
			end
		end
	end
	
	Disguise = vape.Legit:CreateModule({
		Name = 'Disguise',
		Function = function(callback)
			if callback then
				Disguise:Clean(entitylib.Events.LocalAdded:Connect(characterAdded))
				if entitylib.isAlive then
					characterAdded(entitylib.character)
				end
			end
		end,
		Tooltip = 'Changes your character or animation to a specific ID (animation packs or userid\'s only)'
	})
	Mode = Disguise:CreateDropdown({
		Name = 'Mode',
		List = {'Character', 'Animation'},
		Function = function()
			if Disguise.Enabled then
				Disguise:Toggle()
				Disguise:Toggle()
			end
		end
	})
	IDBox = Disguise:CreateTextBox({
		Name = 'Disguise',
		Placeholder = 'Disguise User Id',
		Function = function()
			if Disguise.Enabled then
				Disguise:Toggle()
				Disguise:Toggle()
			end
		end
	})
end)
	
run(function()
	local FOV
	local Value
	local oldfov
	
	FOV = vape.Legit:CreateModule({
		Name = 'FOV',
		Function = function(callback)
			if callback then
				oldfov = gameCamera.FieldOfView
				repeat
					gameCamera.FieldOfView = Value.Value
					task.wait()
				until not FOV.Enabled
			else
				gameCamera.FieldOfView = oldfov
			end
		end,
		Tooltip = 'Adjusts camera vision'
	})
	Value = FOV:CreateSlider({
		Name = 'FOV',
		Min = 30,
		Max = 120
	})
end)
	
run(function()
	--[[
		Grabbing an accurate count of the current framerate
		Source: https://devforum.roblox.com/t/get-client-FPS-trough-a-script/282631
	]]
	local FPS
	local label
	
	FPS = vape.Legit:CreateModule({
		Name = 'FPS',
		Function = function(callback)
			if callback then
				local frames = {}
				local startClock = os.clock()
				local updateTick = tick()
				FPS:Clean(runService.Heartbeat:Connect(function()
					local updateClock = os.clock()
					for i = #frames, 1, -1 do
						frames[i + 1] = frames[i] >= updateClock - 1 and frames[i] or nil
					end
					frames[1] = updateClock
					if updateTick < tick() then
						updateTick = tick() + 1
						label.Text = math.floor(os.clock() - startClock >= 1 and #frames or #frames / (os.clock() - startClock))..' FPS'
					end
				end))
			end
		end,
		Size = UDim2.fromOffset(100, 41),
		Tooltip = 'Shows the current framerate'
	})
	FPS:CreateFont({
		Name = 'Font',
		Blacklist = 'Gotham',
		Function = function(val)
			label.FontFace = val
		end
	})
	FPS:CreateColorSlider({
		Name = 'Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			label.BackgroundTransparency = 1 - opacity
		end
	})
	label = Instance.new('TextLabel')
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.5
	label.TextSize = 15
	label.Font = Enum.Font.Gotham
	label.Text = 'inf FPS'
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundColor3 = Color3.new()
	label.Parent = FPS.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
end)
	
run(function()
	local Keystrokes
	local Style
	local Color
	local keys, holder = {}
	
	local function createKeystroke(keybutton, pos, pos2, text)
		if keys[keybutton] then
			keys[keybutton].Key:Destroy()
			keys[keybutton] = nil
		end
		local key = Instance.new('Frame')
		key.Size = keybutton == Enum.KeyCode.Space and UDim2.new(0, 110, 0, 24) or UDim2.new(0, 34, 0, 36)
		key.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		key.BackgroundTransparency = 1 - Color.Opacity
		key.Position = pos
		key.Name = keybutton.Name
		key.Parent = holder
		local keytext = Instance.new('TextLabel')
		keytext.BackgroundTransparency = 1
		keytext.Size = UDim2.fromScale(1, 1)
		keytext.Font = Enum.Font.Gotham
		keytext.Text = text or keybutton.Name
		keytext.TextXAlignment = Enum.TextXAlignment.Left
		keytext.TextYAlignment = Enum.TextYAlignment.Top
		keytext.Position = pos2
		keytext.TextSize = keybutton == Enum.KeyCode.Space and 18 or 15
		keytext.TextColor3 = Color3.new(1, 1, 1)
		keytext.Parent = key
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = key
		keys[keybutton] = {Key = key}
	end
	
	Keystrokes = vape.Legit:CreateModule({
		Name = 'Keystrokes',
		Function = function(callback)
			if callback then
				createKeystroke(Enum.KeyCode.W, UDim2.new(0, 38, 0, 0), UDim2.new(0, 6, 0, 5), Style.Value == 'Arrow' and '↑' or nil)
				createKeystroke(Enum.KeyCode.S, UDim2.new(0, 38, 0, 42), UDim2.new(0, 8, 0, 5), Style.Value == 'Arrow' and '↓' or nil)
				createKeystroke(Enum.KeyCode.A, UDim2.new(0, 0, 0, 42), UDim2.new(0, 7, 0, 5), Style.Value == 'Arrow' and '←' or nil)
				createKeystroke(Enum.KeyCode.D, UDim2.new(0, 76, 0, 42), UDim2.new(0, 8, 0, 5), Style.Value == 'Arrow' and '→' or nil)
	
				Keystrokes:Clean(inputService.InputBegan:Connect(function(inputType)
					local key = keys[inputType.KeyCode]
					if key then
						if key.Tween then
							key.Tween:Cancel()
						end
						if key.Tween2 then
							key.Tween2:Cancel()
						end
	
						key.Pressed = true
						key.Tween = tweenService:Create(key.Key, TweenInfo.new(0.1), {
							BackgroundColor3 = Color3.new(1, 1, 1), 
							BackgroundTransparency = 0
						})
						key.Tween2 = tweenService:Create(key.Key.TextLabel, TweenInfo.new(0.1), {
							TextColor3 = Color3.new()
						})
						key.Tween:Play()
						key.Tween2:Play()
					end
				end))
	
				Keystrokes:Clean(inputService.InputEnded:Connect(function(inputType)
					local key = keys[inputType.KeyCode]
					if key then
						if key.Tween then
							key.Tween:Cancel()
						end
						if key.Tween2 then
							key.Tween2:Cancel()
						end
	
						key.Pressed = false
						key.Tween = tweenService:Create(key.Key, TweenInfo.new(0.1), {
							BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value), 
							BackgroundTransparency = 1 - Color.Opacity
						})
						key.Tween2 = tweenService:Create(key.Key.TextLabel, TweenInfo.new(0.1), {
							TextColor3 = Color3.new(1, 1, 1)
						})
						key.Tween:Play()
						key.Tween2:Play()
					end
				end))
			end
		end,
		Size = UDim2.fromOffset(110, 176),
		Tooltip = 'Shows movement keys onscreen'
	})
	holder = Instance.new('Frame')
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.Parent = Keystrokes.Children
	Style = Keystrokes:CreateDropdown({
		Name = 'Key Style',
		List = {'Keyboard', 'Arrow'},
		Function = function()
			if Keystrokes.Enabled then
				Keystrokes:Toggle()
				Keystrokes:Toggle()
			end
		end
	})
	Color = Keystrokes:CreateColorSlider({
		Name = 'Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			for _, v in keys do
				if not v.Pressed then
					v.Key.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
					v.Key.BackgroundTransparency = 1 - opacity
				end
			end
		end
	})
	Keystrokes:CreateToggle({
		Name = 'Show Spacebar',
		Function = function(callback)
			Keystrokes.Children.Size = UDim2.fromOffset(110, callback and 107 or 78)
			if callback then
				createKeystroke(Enum.KeyCode.Space, UDim2.new(0, 0, 0, 83), UDim2.new(0, 25, 0, -10), '______')
			else
				keys[Enum.KeyCode.Space].Key:Destroy()
				keys[Enum.KeyCode.Space] = nil
			end
		end,
		Default = true
	})
end)
	
run(function()
	local Memory
	local label
	
	Memory = vape.Legit:CreateModule({
		Name = 'Memory',
		Function = function(callback)
			if callback then
				repeat
					label.Text = math.floor(tonumber(game:GetService('Stats'):FindFirstChild('PerformanceStats').Memory:GetValue()))..' MB'
					task.wait(1)
				until not Memory.Enabled
			end
		end,
		Size = UDim2.fromOffset(100, 41),
		Tooltip = 'A label showing the memory currently used by roblox'
	})
	Memory:CreateFont({
		Name = 'Font',
		Blacklist = 'Gotham',
		Function = function(val)
			label.FontFace = val
		end
	})
	Memory:CreateColorSlider({
		Name = 'Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			label.BackgroundTransparency = 1 - opacity
		end
	})
	label = Instance.new('TextLabel')
	label.Size = UDim2.new(0, 100, 0, 41)
	label.BackgroundTransparency = 0.5
	label.TextSize = 15
	label.Font = Enum.Font.Gotham
	label.Text = '0 MB'
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundColor3 = Color3.new()
	label.Parent = Memory.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
end)
	
run(function()
	local Ping
	local label
	
	Ping = vape.Legit:CreateModule({
		Name = 'Ping',
		Function = function(callback)
			if callback then
				repeat
					label.Text = math.floor(tonumber(game:GetService('Stats'):FindFirstChild('PerformanceStats').Ping:GetValue()))..' ms'
					task.wait(1)
				until not Ping.Enabled
			end
		end,
		Size = UDim2.fromOffset(100, 41),
		Tooltip = 'Shows the current connection speed to the roblox server'
	})
	Ping:CreateFont({
		Name = 'Font',
		Blacklist = 'Gotham',
		Function = function(val)
			label.FontFace = val
		end
	})
	Ping:CreateColorSlider({
		Name = 'Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			label.BackgroundTransparency = 1 - opacity
		end
	})
	label = Instance.new('TextLabel')
	label.Size = UDim2.new(0, 100, 0, 41)
	label.BackgroundTransparency = 0.5
	label.TextSize = 15
	label.Font = Enum.Font.Gotham
	label.Text = '0 ms'
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundColor3 = Color3.new()
	label.Parent = Ping.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
end)
	
run(function()
	local SongBeats
	local List
	local FOV
	local FOVValue = {}
	local Volume
	local alreadypicked = {}
	local beattick = tick()
	local oldfov, songobj, songbpm, songtween
	
	local function choosesong()
		local list = List.ListEnabled
		if #alreadypicked >= #list then
			table.clear(alreadypicked)
		end
	
		if #list <= 0 then
			notif('SongBeats', 'no songs', 10)
			SongBeats:Toggle()
			return
		end
	
		local chosensong = list[math.random(1, #list)]
		if #list > 1 and table.find(alreadypicked, chosensong) then
			repeat
				task.wait()
				chosensong = list[math.random(1, #list)]
			until not table.find(alreadypicked, chosensong) or not SongBeats.Enabled
		end
		if not SongBeats.Enabled then return end
	
		local split = chosensong:split('/')
		if not isfile(split[1]) then
			notif('SongBeats', 'Missing song ('..split[1]..')', 10)
			SongBeats:Toggle()
			return
		end
	
		songobj.SoundId = assetfunction(split[1])
		repeat task.wait() until songobj.IsLoaded or not SongBeats.Enabled
		if SongBeats.Enabled then
			beattick = tick() + (tonumber(split[3]) or 0)
			songbpm = 60 / (tonumber(split[2]) or 50)
			songobj:Play()
		end
	end
	
	SongBeats = vape.Legit:CreateModule({
		Name = 'Song Beats',
		Function = function(callback)
			if callback then
				songobj = Instance.new('Sound')
				songobj.Volume = Volume.Value / 100
				songobj.Parent = workspace
				oldfov = gameCamera.FieldOfView
	
				repeat
					if not songobj.Playing then
						choosesong()
					end
					if beattick < tick() and SongBeats.Enabled and FOV.Enabled then
						beattick = tick() + songbpm
						gameCamera.FieldOfView = oldfov - FOVValue.Value
						songtween = tweenService:Create(gameCamera, TweenInfo.new(math.min(songbpm, 0.2), Enum.EasingStyle.Linear), {
							FieldOfView = oldfov
						})
						songtween:Play()
					end
					task.wait()
				until not SongBeats.Enabled
			else
				if songobj then
					songobj:Destroy()
				end
				if songtween then
					songtween:Cancel()
				end
				if oldfov then
					gameCamera.FieldOfView = oldfov
				end
				table.clear(alreadypicked)
			end
		end,
		Tooltip = 'Built in mp3 player'
	})
	List = SongBeats:CreateTextList({
		Name = 'Songs',
		Placeholder = 'filepath/bpm/start'
	})
	FOV = SongBeats:CreateToggle({
		Name = 'Beat FOV',
		Function = function(callback)
			if FOVValue.Object then
				FOVValue.Object.Visible = callback
			end
			if SongBeats.Enabled then
				SongBeats:Toggle()
				SongBeats:Toggle()
			end
		end,
		Default = true
	})
	FOVValue = SongBeats:CreateSlider({
		Name = 'Adjustment',
		Min = 1,
		Max = 30,
		Default = 5,
		Darker = true
	})
	Volume = SongBeats:CreateSlider({
		Name = 'Volume',
		Function = function(val)
			if songobj then
				songobj.Volume = val / 100
			end
		end,
		Min = 1,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
end)
	
run(function()
	local Speedmeter
	local label
	
	Speedmeter = vape.Legit:CreateModule({
		Name = 'Speedmeter',
		Function = function(callback)
			if callback then
				repeat
					local lastpos = entitylib.isAlive and entitylib.character.HumanoidRootPart.Position * Vector3.new(1, 0, 1) or Vector3.zero
					local dt = task.wait(0.2)
					local newpos = entitylib.isAlive and entitylib.character.HumanoidRootPart.Position * Vector3.new(1, 0, 1) or Vector3.zero
					label.Text = math.round(((lastpos - newpos) / dt).Magnitude)..' sps'
				until not Speedmeter.Enabled
			end
		end,
		Size = UDim2.fromOffset(100, 41),
		Tooltip = 'A label showing the average velocity in studs'
	})
	Speedmeter:CreateFont({
		Name = 'Font',
		Blacklist = 'Gotham',
		Function = function(val)
			label.FontFace = val
		end
	})
	Speedmeter:CreateColorSlider({
		Name = 'Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			label.BackgroundTransparency = 1 - opacity
		end
	})
	label = Instance.new('TextLabel')
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.5
	label.TextSize = 15
	label.Font = Enum.Font.Gotham
	label.Text = '0 sps'
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundColor3 = Color3.new()
	label.Parent = Speedmeter.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
end)
	
run(function()
	local TimeChanger
	local Value
	local old
	
	TimeChanger = vape.Legit:CreateModule({
		Name = 'Time Changer',
		Function = function(callback)
			if callback then
				old = lightingService.TimeOfDay
				lightingService.TimeOfDay = Value.Value..':00:00'
			else
				lightingService.TimeOfDay = old
				old = nil
			end
		end,
		Tooltip = 'Change the time of the current world'
	})
	Value = TimeChanger:CreateSlider({
		Name = 'Time',
		Min = 0,
		Max = 24,
		Default = 12,
		Function = function(val)
			if TimeChanger.Enabled then 
				lightingService.TimeOfDay = val..':00:00'
			end
		end
	})
	
end)
	
    end,
}

local guis = {
	new = function()
		local mainapi = {
			Categories = {},
			GUIColor = {
				Hue = 0.46,
				Sat = 0.96,
				Value = 0.52
			},
			HeldKeybinds = {},
			Keybind = {'RightShift'},
			Loaded = false,
			Libraries = {},
			Modules = {},
			Place = game.PlaceId,
			Profile = 'default',
			Profiles = {},
			RainbowSpeed = {Value = 1},
			RainbowUpdateSpeed = {Value = 60},
			RainbowTable = {},
			Scale = {Value = 1},
			ThreadFix = setthreadidentity and true or false,
			ToggleNotifications = {},
			Version = '4.18',
			Windows = {}
		}

		local cloneref = cloneref or function(obj)
			return obj
		end
		local tweenService = cloneref(game:GetService('TweenService'))
		local inputService = cloneref(game:GetService('UserInputService'))
		local textService = cloneref(game:GetService('TextService'))
		local guiService = cloneref(game:GetService('GuiService'))
		local runService = cloneref(game:GetService('RunService'))
		local httpService = cloneref(game:GetService('HttpService'))

		local fontsize = Instance.new('GetTextBoundsParams')
		fontsize.Width = math.huge
		local notifications
		local assetfunction = getcustomasset
		local getcustomasset
		local clickgui
		local scaledgui
		local toolblur
		local tooltip
		local scale
		local gui

		local color = {}
		local tween = {
			tweens = {},
			tweenstwo = {}
		}
		local uipallet = {
			Main = Color3.fromRGB(26, 25, 26),
			Text = Color3.fromRGB(200, 200, 200),
			Font = Font.fromEnum(Enum.Font.Arial),
			FontSemiBold = Font.fromEnum(Enum.Font.Arial, Enum.FontWeight.SemiBold),
			Tween = TweenInfo.new(0.16, Enum.EasingStyle.Linear)
		}

		local getcustomassets = {
			--['newlunar/assets/new/add.png'] = 'rbxassetid://14368300605',
			['newlunar/assets/new/alert.png'] = 'rbxassetid://14368301329',
			['newlunar/assets/new/allowedicon.png'] = 'rbxassetid://14368302000',
			['newlunar/assets/new/allowedtab.png'] = 'rbxassetid://14368302875',
			['newlunar/assets/new/arrowmodule.png'] = 'rbxassetid://14473354880',
			['newlunar/assets/new/back.png'] = 'rbxassetid://14368303894',
			['newlunar/assets/new/bind.png'] = 'rbxassetid://14368304734',
			['newlunar/assets/new/bindbkg.png'] = 'rbxassetid://14368305655',
			['newlunar/assets/new/blatanticon.png'] = 'rbxassetid://14368306745',
			['newlunar/assets/new/blockedicon.png'] = 'rbxassetid://14385669108',
			['newlunar/assets/new/blockedtab.png'] = 'rbxassetid://14385672881',
			['newlunar/assets/new/blur.png'] = 'rbxassetid://14898786664',
			['newlunar/assets/new/blurnotif.png'] = 'rbxassetid://16738720137',
			['newlunar/assets/new/close.png'] = 'rbxassetid://14368309446',
			['newlunar/assets/new/closemini.png'] = 'rbxassetid://14368310467',
			['newlunar/assets/new/colorpreview.png'] = 'rbxassetid://14368311578',
			['newlunar/assets/new/combaticon.png'] = 'rbxassetid://14368312652',
			['newlunar/assets/new/customsettings.png'] = 'rbxassetid://14403726449',
			['newlunar/assets/new/dots.png'] = 'rbxassetid://14368314459',
			['newlunar/assets/new/edit.png'] = 'rbxassetid://14368315443',
			['newlunar/assets/new/expandicon.png'] = 'rbxassetid://14368353032',
			['newlunar/assets/new/expandright.png'] = 'rbxassetid://14368316544',
			['newlunar/assets/new/expandup.png'] = 'rbxassetid://14368317595',
			['newlunar/assets/new/friendstab.png'] = 'rbxassetid://14397462778',
			['newlunar/assets/new/guisettings.png'] = 'rbxassetid://14368318994',
			['newlunar/assets/new/guislider.png'] = 'rbxassetid://14368320020',
			['newlunar/assets/new/guisliderrain.png'] = 'rbxassetid://14368321228',
			--['newlunar/assets/new/guiv4.png'] = 'rbxassetid://14368322199',
			--['newlunar/assets/new/guilunar.png'] = 'rbxassetid://70490863244743',
			['newlunar/assets/new/info.png'] = 'rbxassetid://14368324807',
			['newlunar/assets/new/inventoryicon.png'] = 'rbxassetid://14928011633',
			['newlunar/assets/new/legit.png'] = 'rbxassetid://14425650534',
			['newlunar/assets/new/legittab.png'] = 'rbxassetid://14426740825',
			['newlunar/assets/new/miniicon.png'] = 'rbxassetid://14368326029',
			['newlunar/assets/new/notification.png'] = 'rbxassetid://16738721069',
			['newlunar/assets/new/overlaysicon.png'] = 'rbxassetid://14368339581',
			['newlunar/assets/new/overlaystab.png'] = 'rbxassetid://14397380433',
			['newlunar/assets/new/pin.png'] = 'rbxassetid://14368342301',
			['newlunar/assets/new/profilesicon.png'] = 'rbxassetid://14397465323',
			['newlunar/assets/new/radaricon.png'] = 'rbxassetid://14368343291',
			['newlunar/assets/new/rainbow_1.png'] = 'rbxassetid://14368344374',
			['newlunar/assets/new/rainbow_2.png'] = 'rbxassetid://14368345149',
			['newlunar/assets/new/rainbow_3.png'] = 'rbxassetid://14368345840',
			['newlunar/assets/new/rainbow_4.png'] = 'rbxassetid://14368346696',
			['newlunar/assets/new/range.png'] = 'rbxassetid://14368347435',
			['newlunar/assets/new/rangearrow.png'] = 'rbxassetid://14368348640',
			['newlunar/assets/new/rendericon.png'] = 'rbxassetid://14368350193',
			['newlunar/assets/new/rendertab.png'] = 'rbxassetid://14397373458',
			['newlunar/assets/new/search.png'] = 'rbxassetid://14425646684',
			['newlunar/assets/new/targetinfoicon.png'] = 'rbxassetid://14368354234',
			['newlunar/assets/new/targetnpc1.png'] = 'rbxassetid://14497400332',
			['newlunar/assets/new/targetnpc2.png'] = 'rbxassetid://14497402744',
			['newlunar/assets/new/targetplayers1.png'] = 'rbxassetid://14497396015',
			['newlunar/assets/new/targetplayers2.png'] = 'rbxassetid://14497397862',
			['newlunar/assets/new/targetstab.png'] = 'rbxassetid://14497393895',
			['newlunar/assets/new/textguiicon.png'] = 'rbxassetid://14368355456',
			--['newlunar/assets/new/textv4.png'] = 'rbxassetid://14368357095',
			--['newlunar/assets/new/textlunar.png'] = 'rbxassetid://106844493716386',
			['newlunar/assets/new/utilityicon.png'] = 'rbxassetid://14368359107',
			['newlunar/assets/new/vape.png'] = 'rbxassetid://14373395239',
			['newlunar/assets/new/warning.png'] = 'rbxassetid://14368361552',
			['newlunar/assets/new/worldicon.png'] = 'rbxassetid://14368362492'
		}

		local isfile = isfile or function(file)
			local suc, res = pcall(function()
				return readfile(file)
			end)
			return suc and res ~= nil and res ~= ''
		end

		local getfontsize = function(text, size, font)
			fontsize.Text = text
			fontsize.Size = size
			if typeof(font) == 'Font' then
				fontsize.Font = font
			end
			return textService:GetTextBoundsAsync(fontsize)
		end

		local function addBlur(parent, notif)
			local blur = Instance.new('ImageLabel')
			blur.Name = 'Blur'
			blur.Size = UDim2.new(1, 89, 1, 52)
			blur.Position = UDim2.fromOffset(-48, -31)
			blur.BackgroundTransparency = 1
			blur.Image = 'rbxassetid://16738720137'
			blur.ScaleType = Enum.ScaleType.Slice
			blur.SliceCenter = Rect.new(52, 31, 261, 502)
			blur.Parent = parent

			return blur
		end

		local function addCorner(parent, radius)
			local corner = Instance.new('UICorner')
			corner.CornerRadius = radius or UDim.new(0, 5)
			corner.Parent = parent

			return corner
		end

		local function addCloseButton(parent, offset)
			local close = Instance.new('ImageButton')
			close.Name = 'Close'
			close.Size = UDim2.fromOffset(24, 24)
			close.Position = UDim2.new(1, -35, 0, offset or 9)
			close.BackgroundColor3 = Color3.new(1, 1, 1)
			close.BackgroundTransparency = 1
			close.AutoButtonColor = false
			close.Image = 'rbxassetid://14368309446'
			close.ImageColor3 = color.Light(uipallet.Text, 0.2)
			close.ImageTransparency = 0.5
			close.Parent = parent
			addCorner(close, UDim.new(1, 0))

			close.MouseEnter:Connect(function()
				close.ImageTransparency = 0.3
				tween:Tween(close, uipallet.Tween, {
					BackgroundTransparency = 0.6
				})
			end)
			close.MouseLeave:Connect(function()
				close.ImageTransparency = 0.5
				tween:Tween(close, uipallet.Tween, {
					BackgroundTransparency = 1
				})
			end)

			return close
		end

		local function addMaid(object)
			object.Connections = {}
			function object:Clean(callback)
				if typeof(callback) == 'Instance' then
					table.insert(self.Connections, {
						Disconnect = function()
							callback:ClearAllChildren()
							callback:Destroy()
						end
					})
				elseif type(callback) == 'function' then
					table.insert(self.Connections, {
						Disconnect = callback
					})
				else
					table.insert(self.Connections, callback)
				end
			end
		end

		local function addTooltip(gui, text)
			if not text then return end

			local function tooltipMoved(x, y)
				local right = x + 16 + tooltip.Size.X.Offset > (scale.Scale * 1920)
				tooltip.Position = UDim2.fromOffset(
					(right and x - (tooltip.Size.X.Offset * scale.Scale) - 16 or x + 16) / scale.Scale,
					((y + 11) - (tooltip.Size.Y.Offset / 2)) / scale.Scale
				)
				tooltip.Visible = toolblur.Visible
			end

			gui.MouseEnter:Connect(function(x, y)
				local tooltipSize = getfontsize(text, tooltip.TextSize, uipallet.Font)
				tooltip.Size = UDim2.fromOffset(tooltipSize.X + 10, tooltipSize.Y + 10)
				tooltip.Text = text
				tooltipMoved(x, y)
			end)
			gui.MouseMoved:Connect(tooltipMoved)
			gui.MouseLeave:Connect(function()
				tooltip.Visible = false
			end)
		end

		local function checkKeybinds(compare, target, key)
			if type(target) == 'table' then
				if table.find(target, key) then
					for i, v in target do
						if not table.find(compare, v) then
							return false
						end
					end
					return true
				end
			end

			return false
		end

		local function createDownloader(text)
			if mainapi.Loaded ~= true then
				local downloader = mainapi.Downloader
				if not downloader then
					downloader = Instance.new('TextLabel')
					downloader.Size = UDim2.new(1, 0, 0, 40)
					downloader.BackgroundTransparency = 1
					downloader.TextStrokeTransparency = 0
					downloader.TextSize = 20
					downloader.TextColor3 = Color3.new(1, 1, 1)
					downloader.FontFace = uipallet.Font
					downloader.Parent = mainapi.gui
					mainapi.Downloader = downloader
				end
				downloader.Text = 'Downloading '..text
			end
		end

		local function createMobileButton(buttonapi, position)
			local heldbutton = false
			local button = Instance.new('TextButton')
			button.Size = UDim2.fromOffset(40, 40)
			button.Position = UDim2.fromOffset(position.X, position.Y)
			button.AnchorPoint = Vector2.new(0.5, 0.5)
			button.BackgroundColor3 = buttonapi.Enabled and Color3.new(0, 0.7, 0) or Color3.new()
			button.BackgroundTransparency = 0.5
			button.Text = buttonapi.Name
			button.TextColor3 = Color3.new(1, 1, 1)
			button.TextScaled = true
			button.Font = Enum.Font.Gotham
			button.Parent = mainapi.gui
			local buttonconstraint = Instance.new('UITextSizeConstraint')
			buttonconstraint.MaxTextSize = 16
			buttonconstraint.Parent = button
			addCorner(button, UDim.new(1, 0))

			button.MouseButton1Down:Connect(function()
				heldbutton = true
				local holdtime, holdpos = tick(), inputService:GetMouseLocation()
				repeat
					heldbutton = (inputService:GetMouseLocation() - holdpos).Magnitude < 6
					task.wait()
				until (tick() - holdtime) > 1 or not heldbutton
				if heldbutton then
					buttonapi.Bind = {}
					button:Destroy()
				end
			end)
			button.MouseButton1Up:Connect(function()
				heldbutton = false
			end)
			button.MouseButton1Click:Connect(function()
				buttonapi:Toggle()
				button.BackgroundColor3 = buttonapi.Enabled and Color3.new(0, 0.7, 0) or Color3.new()
			end)

			buttonapi.Bind = {Button = button}
		end

		local function downloadFile(path, func)
			if not isfile(path) then
				createDownloader(path)
				local suc, res = pcall(function()
					return game:HttpGet('https://raw.githubusercontent.com/xylex1/LunarClient/'..readfile('newlunar/profiles/commit.txt')..'/'..select(1, path:gsub('newlunar/', '')), true)
				end)
				if not suc or res == '404: Not Found' then
					error(res)
				end
				if path:find('.lua') then
					res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
				end
				writefile(path, res)
			end
			return (func or readfile)(path)
		end

		getcustomasset = not inputService.TouchEnabled and assetfunction and function(path)
			return downloadFile(path, assetfunction)
		end or function(path)
			return getcustomassets[path] or ''
		end

		local function getTableSize(tab)
			local ind = 0
			for _ in tab do ind += 1 end
			return ind
		end

		local function loopClean(tab)
			for i, v in tab do
				if type(v) == 'table' then
					loopClean(v)
				end
				tab[i] = nil
			end
		end

		local function loadJson(path)
			local suc, res = pcall(function()
				return httpService:JSONDecode(readfile(path))
			end)
			return suc and type(res) == 'table' and res or nil
		end

		local function makeDraggable(gui, window)
			gui.InputBegan:Connect(function(inputObj)
				if window and not window.Visible then return end
				if
					(inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch)
					and (inputObj.Position.Y - gui.AbsolutePosition.Y < 40 or window)
				then
					local dragPosition = Vector2.new(
						gui.AbsolutePosition.X - inputObj.Position.X,
						gui.AbsolutePosition.Y - inputObj.Position.Y + guiService:GetGuiInset().Y
					) / scale.Scale

					local changed = inputService.InputChanged:Connect(function(input)
						if input.UserInputType == (inputObj.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
							local position = input.Position
							if inputService:IsKeyDown(Enum.KeyCode.LeftShift) then
								dragPosition = (dragPosition // 3) * 3
								position = (position // 3) * 3
							end
							gui.Position = UDim2.fromOffset((position.X / scale.Scale) + dragPosition.X, (position.Y / scale.Scale) + dragPosition.Y)
						end
					end)

					local ended
					ended = inputObj.Changed:Connect(function()
						if inputObj.UserInputState == Enum.UserInputState.End then
							if changed then
								changed:Disconnect()
							end
							if ended then
								ended:Disconnect()
							end
						end
					end)
				end
			end)
		end

		local function randomString()
			local array = {}
			for i = 1, math.random(10, 100) do
				array[i] = string.char(math.random(32, 126))
			end
			return table.concat(array)
		end

		local function removeTags(str)
			str = str:gsub('<br%s*/>', '\n')
			return str:gsub('<[^<>]->', '')
		end

		do
			local res = isfile('newlunar/profiles/color.txt') and loadJson('newlunar/profiles/color.txt')
			if res then
				uipallet.Main = res.Main and Color3.fromRGB(unpack(res.Main)) or uipallet.Main
				uipallet.Text = res.Text and Color3.fromRGB(unpack(res.Text)) or uipallet.Text
				uipallet.Font = res.Font and Font.new(
					res.Font:find('rbxasset') and res.Font
						or string.format('rbxasset://fonts/families/%s.json', res.Font)
				) or uipallet.Font
				uipallet.FontSemiBold = Font.new(uipallet.Font.Family, Enum.FontWeight.SemiBold)
			end
			fontsize.Font = uipallet.Font
		end

		do
			function color.Dark(col, num)
				local h, s, v = col:ToHSV()
				return Color3.fromHSV(h, s, math.clamp(select(3, uipallet.Main:ToHSV()) > 0.5 and v + num or v - num, 0, 1))
			end

			function color.Light(col, num)
				local h, s, v = col:ToHSV()
				return Color3.fromHSV(h, s, math.clamp(select(3, uipallet.Main:ToHSV()) > 0.5 and v - num or v + num, 0, 1))
			end

			function mainapi:Color(h)
				local s = 0.75 + (0.15 * math.min(h / 0.03, 1))
				if h > 0.57 then
					s = 0.9 - (0.4 * math.min((h - 0.57) / 0.09, 1))
				end
				if h > 0.66 then
					s = 0.5 + (0.4 * math.min((h - 0.66) / 0.16, 1))
				end
				if h > 0.87 then
					s = 0.9 - (0.15 * math.min((h - 0.87) / 0.13, 1))
				end
				return h, s, 1
			end

			function mainapi:TextColor(h, s, v)
				if v >= 0.7 and (s < 0.6 or h > 0.04 and h < 0.56) then
					return Color3.new(0.19, 0.19, 0.19)
				end
				return Color3.new(1, 1, 1)
			end
		end

		do
			function tween:Tween(obj, tweeninfo, goal, tab)
				tab = tab or self.tweens
				if tab[obj] then
					tab[obj]:Cancel()
					tab[obj] = nil
				end

				if obj.Parent and obj.Visible then
					tab[obj] = tweenService:Create(obj, tweeninfo, goal)
					tab[obj].Completed:Once(function()
						if tab then
							tab[obj] = nil
							tab = nil
						end
					end)
					tab[obj]:Play()
				else
					for i, v in goal do
						obj[i] = v
					end
				end
			end

			function tween:Cancel(obj)
				if self.tweens[obj] then
					self.tweens[obj]:Cancel()
					self.tweens[obj] = nil
				end
			end
		end

		mainapi.Libraries = {
			color = color,
			getcustomasset = getcustomasset,
			getfontsize = getfontsize,
			tween = tween,
			uipallet = uipallet,
		}

		local components
		components = {
			Button = function(optionsettings, children, api)
				local button = Instance.new('TextButton')
				button.Name = optionsettings.Name..'Button'
				button.Size = UDim2.new(1, 0, 0, 31)
				button.BackgroundColor3 = color.Dark(children.BackgroundColor3, optionsettings.Darker and 0.02 or 0)
				button.BorderSizePixel = 0
				button.AutoButtonColor = false
				button.Visible = optionsettings.Visible == nil or optionsettings.Visible
				button.Text = ''
				button.Parent = children
				addTooltip(button, optionsettings.Tooltip)
				local bkg = Instance.new('Frame')
				bkg.Size = UDim2.fromOffset(200, 27)
				bkg.Position = UDim2.fromOffset(10, 2)
				bkg.BackgroundColor3 = color.Light(uipallet.Main, 0.05)
				bkg.Parent = button
				addCorner(bkg)
				local label = Instance.new('TextLabel')
				label.Size = UDim2.new(1, -4, 1, -4)
				label.Position = UDim2.fromOffset(2, 2)
				label.BackgroundColor3 = uipallet.Main
				label.Text = optionsettings.Name
				label.TextColor3 = color.Dark(uipallet.Text, 0.16)
				label.TextSize = 14
				label.FontFace = uipallet.Font
				label.Parent = bkg
				addCorner(label, UDim.new(0, 4))
				optionsettings.Function = optionsettings.Function or function() end

				button.MouseEnter:Connect(function()
					tween:Tween(bkg, uipallet.Tween, {
						BackgroundColor3 = color.Light(uipallet.Main, 0.0875)
					})
				end)
				button.MouseLeave:Connect(function()
					tween:Tween(bkg, uipallet.Tween, {
						BackgroundColor3 = color.Light(uipallet.Main, 0.05)
					})
				end)
				button.MouseButton1Click:Connect(optionsettings.Function)
			end,
			ColorSlider = function(optionsettings, children, api)
				local optionapi = {
					Type = 'ColorSlider',
					Hue = optionsettings.DefaultHue or 0.44,
					Sat = optionsettings.DefaultSat or 1,
					Value = optionsettings.DefaultValue or 1,
					Opacity = optionsettings.DefaultOpacity or 1,
					Rainbow = false,
					Index = 0
				}

				local function createSlider(name, gradientColor)
					local slider = Instance.new('TextButton')
					slider.Name = optionsettings.Name..'Slider'..name
					slider.Size = UDim2.new(1, 0, 0, 50)
					slider.BackgroundColor3 = color.Dark(children.BackgroundColor3, optionsettings.Darker and 0.02 or 0)
					slider.BorderSizePixel = 0
					slider.AutoButtonColor = false
					slider.Visible = false
					slider.Text = ''
					slider.Parent = children
					local title = Instance.new('TextLabel')
					title.Name = 'Title'
					title.Size = UDim2.fromOffset(60, 30)
					title.Position = UDim2.fromOffset(10, 2)
					title.BackgroundTransparency = 1
					title.Text = name
					title.TextXAlignment = Enum.TextXAlignment.Left
					title.TextColor3 = color.Dark(uipallet.Text, 0.16)
					title.TextSize = 11
					title.FontFace = uipallet.Font
					title.Parent = slider
					local bkg = Instance.new('Frame')
					bkg.Name = 'Slider'
					bkg.Size = UDim2.new(1, -20, 0, 2)
					bkg.Position = UDim2.fromOffset(10, 37)
					bkg.BackgroundColor3 = Color3.new(1, 1, 1)
					bkg.BorderSizePixel = 0
					bkg.Parent = slider
					local gradient = Instance.new('UIGradient')
					gradient.Color = gradientColor
					gradient.Parent = bkg
					local fill = bkg:Clone()
					fill.Name = 'Fill'
					fill.Size = UDim2.fromScale(math.clamp(name == 'Saturation' and optionapi.Sat or name == 'Vibrance' and optionapi.Value or optionapi.Opacity, 0.04, 0.96), 1)
					fill.Position = UDim2.new()
					fill.BackgroundTransparency = 1
					fill.Parent = bkg
					local knobholder = Instance.new('Frame')
					knobholder.Name = 'Knob'
					knobholder.Size = UDim2.fromOffset(24, 4)
					knobholder.Position = UDim2.fromScale(1, 0.5)
					knobholder.AnchorPoint = Vector2.new(0.5, 0.5)
					knobholder.BackgroundColor3 = slider.BackgroundColor3
					knobholder.BorderSizePixel = 0
					knobholder.Parent = fill
					local knob = Instance.new('Frame')
					knob.Name = 'Knob'
					knob.Size = UDim2.fromOffset(14, 14)
					knob.Position = UDim2.fromScale(0.5, 0.5)
					knob.AnchorPoint = Vector2.new(0.5, 0.5)
					knob.BackgroundColor3 = uipallet.Text
					knob.Parent = knobholder
					addCorner(knob, UDim.new(1, 0))

					slider.InputBegan:Connect(function(inputObj)
						if
							(inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch)
							and (inputObj.Position.Y - slider.AbsolutePosition.Y) > (20 * scale.Scale)
						then
							local changed = inputService.InputChanged:Connect(function(input)
								if input.UserInputType == (inputObj.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
									optionapi:SetValue(nil, name == 'Saturation' and math.clamp((input.Position.X - bkg.AbsolutePosition.X) / bkg.AbsoluteSize.X, 0, 1) or nil, name == 'Vibrance' and math.clamp((input.Position.X - bkg.AbsolutePosition.X) / bkg.AbsoluteSize.X, 0, 1) or nil, name == 'Opacity' and math.clamp((input.Position.X - bkg.AbsolutePosition.X) / bkg.AbsoluteSize.X, 0, 1) or nil)
								end
							end)

							local ended
							ended = inputObj.Changed:Connect(function()
								if inputObj.UserInputState == Enum.UserInputState.End then
									if changed then changed:Disconnect() end
									if ended then ended:Disconnect() end
								end
							end)
						end
					end)
					slider.MouseEnter:Connect(function()
						tween:Tween(knob, uipallet.Tween, {
							Size = UDim2.fromOffset(16, 16)
						})
					end)
					slider.MouseLeave:Connect(function()
						tween:Tween(knob, uipallet.Tween, {
							Size = UDim2.fromOffset(14, 14)
						})
					end)

					return slider
				end

				local slider = Instance.new('TextButton')
				slider.Name = optionsettings.Name..'Slider'
				slider.Size = UDim2.new(1, 0, 0, 50)
				slider.BackgroundColor3 = color.Dark(children.BackgroundColor3, optionsettings.Darker and 0.02 or 0)
				slider.BorderSizePixel = 0
				slider.AutoButtonColor = false
				slider.Visible = optionsettings.Visible == nil or optionsettings.Visible
				slider.Text = ''
				slider.Parent = children
				addTooltip(slider, optionsettings.Tooltip)
				local title = Instance.new('TextLabel')
				title.Name = 'Title'
				title.Size = UDim2.fromOffset(60, 30)
				title.Position = UDim2.fromOffset(10, 2)
				title.BackgroundTransparency = 1
				title.Text = optionsettings.Name
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.TextColor3 = color.Dark(uipallet.Text, 0.16)
				title.TextSize = 11
				title.FontFace = uipallet.Font
				title.Parent = slider
				local valuebox = Instance.new('TextBox')
				valuebox.Name = 'Box'
				valuebox.Size = UDim2.fromOffset(60, 15)
				valuebox.Position = UDim2.new(1, -69, 0, 9)
				valuebox.BackgroundTransparency = 1
				valuebox.Visible = false
				valuebox.Text = ''
				valuebox.TextXAlignment = Enum.TextXAlignment.Right
				valuebox.TextColor3 = color.Dark(uipallet.Text, 0.16)
				valuebox.TextSize = 11
				valuebox.FontFace = uipallet.Font
				valuebox.ClearTextOnFocus = true
				valuebox.Parent = slider
				local bkg = Instance.new('Frame')
				bkg.Name = 'Slider'
				bkg.Size = UDim2.new(1, -20, 0, 2)
				bkg.Position = UDim2.fromOffset(10, 39)
				bkg.BackgroundColor3 = Color3.new(1, 1, 1)
				bkg.BorderSizePixel = 0
				bkg.Parent = slider
				local rainbowTable = {}
				for i = 0, 1, 0.1 do
					table.insert(rainbowTable, ColorSequenceKeypoint.new(i, Color3.fromHSV(i, 1, 1)))
				end
				local gradient = Instance.new('UIGradient')
				gradient.Color = ColorSequence.new(rainbowTable)
				gradient.Parent = bkg
				local fill = bkg:Clone()
				fill.Name = 'Fill'
				fill.Size = UDim2.fromScale(math.clamp(optionapi.Hue, 0.04, 0.96), 1)
				fill.Position = UDim2.new()
				fill.BackgroundTransparency = 1
				fill.Parent = bkg
				local preview = Instance.new('ImageButton')
				preview.Name = 'Preview'
				preview.Size = UDim2.fromOffset(12, 12)
				preview.Position = UDim2.new(1, -22, 0, 10)
				preview.BackgroundTransparency = 1
				preview.Image = 'rbxassetid://14368311578'
				preview.ImageColor3 = Color3.fromHSV(optionapi.Hue, optionapi.Sat, optionapi.Value)
				preview.ImageTransparency = 1 - optionapi.Opacity
				preview.Parent = slider
				local expandbutton = Instance.new('TextButton')
				expandbutton.Name = 'Expand'
				expandbutton.Size = UDim2.fromOffset(17, 13)
				expandbutton.Position = UDim2.new(0, textService:GetTextSize(title.Text, title.TextSize, title.Font, Vector2.new(1000, 1000)).X + 11, 0, 7)
				expandbutton.BackgroundTransparency = 1
				expandbutton.Text = ''
				expandbutton.Parent = slider
				local expand = Instance.new('ImageLabel')
				expand.Name = 'Expand'
				expand.Size = UDim2.fromOffset(9, 5)
				expand.Position = UDim2.fromOffset(4, 4)
				expand.BackgroundTransparency = 1
				expand.Image = 'rbxassetid://14368353032'
				expand.ImageColor3 = color.Dark(uipallet.Text, 0.43)
				expand.Parent = expandbutton
				local rainbow = Instance.new('TextButton')
				rainbow.Name = 'Rainbow'
				rainbow.Size = UDim2.fromOffset(12, 12)
				rainbow.Position = UDim2.new(1, -42, 0, 10)
				rainbow.BackgroundTransparency = 1
				rainbow.Text = ''
				rainbow.Parent = slider
				local rainbow1 = Instance.new('ImageLabel')
				rainbow1.Size = UDim2.fromOffset(12, 12)
				rainbow1.BackgroundTransparency = 1
				rainbow1.Image = 'rbxassetid://14368344374'
				rainbow1.ImageColor3 = color.Light(uipallet.Main, 0.37)
				rainbow1.Parent = rainbow
				local rainbow2 = rainbow1:Clone()
				rainbow2.Image = 'rbxassetid://14368345149'
				rainbow2.Parent = rainbow
				local rainbow3 = rainbow1:Clone()
				rainbow3.Image = 'rbxassetid://14368345840'
				rainbow3.Parent = rainbow
				local rainbow4 = rainbow1:Clone()
				rainbow4.Image = 'rbxassetid://14368346696'
				rainbow4.Parent = rainbow
				local knobholder = Instance.new('Frame')
				knobholder.Name = 'Knob'
				knobholder.Size = UDim2.fromOffset(24, 4)
				knobholder.Position = UDim2.fromScale(1, 0.5)
				knobholder.AnchorPoint = Vector2.new(0.5, 0.5)
				knobholder.BackgroundColor3 = slider.BackgroundColor3
				knobholder.BorderSizePixel = 0
				knobholder.Parent = fill
				local knob = Instance.new('Frame')
				knob.Name = 'Knob'
				knob.Size = UDim2.fromOffset(14, 14)
				knob.Position = UDim2.fromScale(0.5, 0.5)
				knob.AnchorPoint = Vector2.new(0.5, 0.5)
				knob.BackgroundColor3 = uipallet.Text
				knob.Parent = knobholder
				addCorner(knob, UDim.new(1, 0))
				optionsettings.Function = optionsettings.Function or function() end
				local satSlider = createSlider('Saturation', ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, optionapi.Value)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(optionapi.Hue, 1, optionapi.Value))
				}))
				local vibSlider = createSlider('Vibrance', ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, 0)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(optionapi.Hue, optionapi.Sat, 1))
				}))
				local opSlider = createSlider('Opacity', ColorSequence.new({
					ColorSequenceKeypoint.new(0, color.Dark(uipallet.Main, 0.02)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(optionapi.Hue, optionapi.Sat, optionapi.Value))
				}))

				function optionapi:Save(tab)
					tab[optionsettings.Name] = {
						Hue = self.Hue,
						Sat = self.Sat,
						Value = self.Value,
						Opacity = self.Opacity,
						Rainbow = self.Rainbow
					}
				end

				function optionapi:Load(tab)
					if tab.Rainbow ~= self.Rainbow then
						self:Toggle()
					end
					if self.Hue ~= tab.Hue or self.Sat ~= tab.Sat or self.Value ~= tab.Value or self.Opacity ~= tab.Opacity then
						self:SetValue(tab.Hue, tab.Sat, tab.Value, tab.Opacity)
					end
				end

				function optionapi:SetValue(h, s, v, o)
					self.Hue = h or self.Hue
					self.Sat = s or self.Sat
					self.Value = v or self.Value
					self.Opacity = o or self.Opacity
					preview.ImageColor3 = Color3.fromHSV(self.Hue, self.Sat, self.Value)
					preview.ImageTransparency = 1 - self.Opacity
					satSlider.Slider.UIGradient.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, self.Value)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(self.Hue, 1, self.Value))
					})
					vibSlider.Slider.UIGradient.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, 0)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(self.Hue, self.Sat, 1))
					})
					opSlider.Slider.UIGradient.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, color.Dark(uipallet.Main, 0.02)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(self.Hue, self.Sat, self.Value))
					})

					if self.Rainbow then
						fill.Size = UDim2.fromScale(math.clamp(self.Hue, 0.04, 0.96), 1)
					else
						tween:Tween(fill, uipallet.Tween, {
							Size = UDim2.fromScale(math.clamp(self.Hue, 0.04, 0.96), 1)
						})
					end

					if s then
						tween:Tween(satSlider.Slider.Fill, uipallet.Tween, {
							Size = UDim2.fromScale(math.clamp(self.Sat, 0.04, 0.96), 1)
						})
					end
					if v then
						tween:Tween(vibSlider.Slider.Fill, uipallet.Tween, {
							Size = UDim2.fromScale(math.clamp(self.Value, 0.04, 0.96), 1)
						})
					end
					if o then
						tween:Tween(opSlider.Slider.Fill, uipallet.Tween, {
							Size = UDim2.fromScale(math.clamp(self.Opacity, 0.04, 0.96), 1)
						})
					end

					optionsettings.Function(self.Hue, self.Sat, self.Value, self.Opacity)
				end

				function optionapi:Toggle()
					self.Rainbow = not self.Rainbow
					if self.Rainbow then
						table.insert(mainapi.RainbowTable, self)
						rainbow1.ImageColor3 = Color3.fromRGB(5, 127, 100)
						task.delay(0.1, function()
							if not self.Rainbow then return end
							rainbow2.ImageColor3 = Color3.fromRGB(228, 125, 43)
							task.delay(0.1, function()
								if not self.Rainbow then return end
								rainbow3.ImageColor3 = Color3.fromRGB(225, 46, 52)
							end)
						end)
					else
						local ind = table.find(mainapi.RainbowTable, self)
						if ind then
							table.remove(mainapi.RainbowTable, ind)
						end
						rainbow3.ImageColor3 = color.Light(uipallet.Main, 0.37)
						task.delay(0.1, function()
							if self.Rainbow then return end
							rainbow2.ImageColor3 = color.Light(uipallet.Main, 0.37)
							task.delay(0.1, function()
								if self.Rainbow then return end
								rainbow1.ImageColor3 = color.Light(uipallet.Main, 0.37)
							end)
						end)
					end
				end

				local doubleClick = tick()
				preview.MouseButton1Click:Connect(function()
					preview.Visible = false
					valuebox.Visible = true
					valuebox:CaptureFocus()
					local text = Color3.fromHSV(optionapi.Hue, optionapi.Sat, optionapi.Value)
					valuebox.Text = math.round(text.R * 255)..', '..math.round(text.G * 255)..', '..math.round(text.B * 255)
				end)
				slider.InputBegan:Connect(function(inputObj)
					if
						(inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch)
						and (inputObj.Position.Y - slider.AbsolutePosition.Y) > (20 * scale.Scale)
					then
						if doubleClick > tick() then
							optionapi:Toggle()
						end
						doubleClick = tick() + 0.3
						local changed = inputService.InputChanged:Connect(function(input)
							if input.UserInputType == (inputObj.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
								optionapi:SetValue(math.clamp((input.Position.X - bkg.AbsolutePosition.X) / bkg.AbsoluteSize.X, 0, 1))
							end
						end)

						local ended
						ended = inputObj.Changed:Connect(function()
							if inputObj.UserInputState == Enum.UserInputState.End then
								if changed then
									changed:Disconnect()
								end
								if ended then
									ended:Disconnect()
								end
							end
						end)
					end
				end)
				slider.MouseEnter:Connect(function()
					tween:Tween(knob, uipallet.Tween, {
						Size = UDim2.fromOffset(16, 16)
					})
				end)
				slider.MouseLeave:Connect(function()
					tween:Tween(knob, uipallet.Tween, {
						Size = UDim2.fromOffset(14, 14)
					})
				end)
				slider:GetPropertyChangedSignal('Visible'):Connect(function()
					satSlider.Visible = expand.Rotation == 180 and slider.Visible
					vibSlider.Visible = satSlider.Visible
					opSlider.Visible = satSlider.Visible
				end)
				expandbutton.MouseEnter:Connect(function()
					expand.ImageColor3 = color.Dark(uipallet.Text, 0.16)
				end)
				expandbutton.MouseLeave:Connect(function()
					expand.ImageColor3 = color.Dark(uipallet.Text, 0.43)
				end)
				expandbutton.MouseButton1Click:Connect(function()
					satSlider.Visible = not satSlider.Visible
					vibSlider.Visible = satSlider.Visible
					opSlider.Visible = satSlider.Visible
					expand.Rotation = satSlider.Visible and 180 or 0
				end)
				rainbow.MouseButton1Click:Connect(function()
					optionapi:Toggle()
				end)
				valuebox.FocusLost:Connect(function(enter)
					preview.Visible = true
					valuebox.Visible = false
					if enter then
						local commas = valuebox.Text:split(',')
						local suc, res = pcall(function()
							return tonumber(commas[1]) and Color3.fromRGB(tonumber(commas[1]), tonumber(commas[2]), tonumber(commas[3])) or Color3.fromHex(valuebox.Text)
						end)
						if suc then
							if optionapi.Rainbow then
								optionapi:Toggle()
							end
							optionapi:SetValue(res:ToHSV())
						end
					end
				end)

				optionapi.Object = slider
				api.Options[optionsettings.Name] = optionapi

				return optionapi
			end,
			Dropdown = function(optionsettings, children, api)
				local optionapi = {
					Type = 'Dropdown',
					Value = optionsettings.List[1] or 'None',
					Index = 0
				}

				local dropdown = Instance.new('TextButton')
				dropdown.Name = optionsettings.Name..'Dropdown'
				dropdown.Size = UDim2.new(1, 0, 0, 40)
				dropdown.BackgroundColor3 = color.Dark(children.BackgroundColor3, optionsettings.Darker and 0.02 or 0)
				dropdown.BorderSizePixel = 0
				dropdown.AutoButtonColor = false
				dropdown.Visible = optionsettings.Visible == nil or optionsettings.Visible
				dropdown.Text = ''
				dropdown.Parent = children
				addTooltip(dropdown, optionsettings.Tooltip or optionsettings.Name)
				local bkg = Instance.new('Frame')
				bkg.Name = 'BKG'
				bkg.Size = UDim2.new(1, -20, 1, -9)
				bkg.Position = UDim2.fromOffset(10, 4)
				bkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
				bkg.Parent = dropdown
				addCorner(bkg, UDim.new(0, 6))
				local button = Instance.new('TextButton')
				button.Name = 'Dropdown'
				button.Size = UDim2.new(1, -2, 1, -2)
				button.Position = UDim2.fromOffset(1, 1)
				button.BackgroundColor3 = uipallet.Main
				button.AutoButtonColor = false
				button.Text = ''
				button.Parent = bkg
				local title = Instance.new('TextLabel')
				title.Name = 'Title'
				title.Size = UDim2.new(1, 0, 0, 29)
				title.BackgroundTransparency = 1
				title.Text = '         '..optionsettings.Name..' - '..optionapi.Value
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.TextColor3 = color.Dark(uipallet.Text, 0.16)
				title.TextSize = 13
				title.TextTruncate = Enum.TextTruncate.AtEnd
				title.FontFace = uipallet.Font
				title.Parent = button
				addCorner(button, UDim.new(0, 6))
				local arrow = Instance.new('ImageLabel')
				arrow.Name = 'Arrow'
				arrow.Size = UDim2.fromOffset(4, 8)
				arrow.Position = UDim2.new(1, -17, 0, 11)
				arrow.BackgroundTransparency = 1
				arrow.Image = 'rbxassetid://14368316544'
				arrow.ImageColor3 = Color3.fromRGB(140, 140, 140)
				arrow.Rotation = 90
				arrow.Parent = button
				optionsettings.Function = optionsettings.Function or function() end
				local dropdownchildren

				function optionapi:Save(tab)
					tab[optionsettings.Name] = {Value = self.Value}
				end

				function optionapi:Load(tab)
					if self.Value ~= tab.Value then
						self:SetValue(tab.Value)
					end
				end

				function optionapi:Change(list)
					optionsettings.List = list or {}
					if not table.find(optionsettings.List, self.Value) then
						self:SetValue(self.Value)
					end
				end

				function optionapi:SetValue(val, mouse)
					self.Value = table.find(optionsettings.List, val) and val or optionsettings.List[1] or 'None'
					title.Text = '         '..optionsettings.Name..' - '..self.Value
					if dropdownchildren then
						arrow.Rotation = 90
						dropdownchildren:Destroy()
						dropdownchildren = nil
						dropdown.Size = UDim2.new(1, 0, 0, 40)
					end
					optionsettings.Function(self.Value, mouse)
				end

				button.MouseButton1Click:Connect(function()
					if not dropdownchildren then
						arrow.Rotation = 270
						dropdown.Size = UDim2.new(1, 0, 0, 40 + (#optionsettings.List - 1) * 26)
						dropdownchildren = Instance.new('Frame')
						dropdownchildren.Name = 'Children'
						dropdownchildren.Size = UDim2.new(1, 0, 0, (#optionsettings.List - 1) * 26)
						dropdownchildren.Position = UDim2.fromOffset(0, 27)
						dropdownchildren.BackgroundTransparency = 1
						dropdownchildren.Parent = button
						local ind = 0
						for _, v in optionsettings.List do
							if v == optionapi.Value then continue end
							local dropdownoption = Instance.new('TextButton')
							dropdownoption.Name = v..'Option'
							dropdownoption.Size = UDim2.new(1, 0, 0, 26)
							dropdownoption.Position = UDim2.fromOffset(0, ind * 26)
							dropdownoption.BackgroundColor3 = uipallet.Main
							dropdownoption.BorderSizePixel = 0
							dropdownoption.AutoButtonColor = false
							dropdownoption.Text = '         '..v
							dropdownoption.TextXAlignment = Enum.TextXAlignment.Left
							dropdownoption.TextColor3 = color.Dark(uipallet.Text, 0.16)
							dropdownoption.TextSize = 13
							dropdownoption.TextTruncate = Enum.TextTruncate.AtEnd
							dropdownoption.FontFace = uipallet.Font
							dropdownoption.Parent = dropdownchildren
							dropdownoption.MouseEnter:Connect(function()
								tween:Tween(dropdownoption, uipallet.Tween, {
									BackgroundColor3 = color.Light(uipallet.Main, 0.02)
								})
							end)
							dropdownoption.MouseLeave:Connect(function()
								tween:Tween(dropdownoption, uipallet.Tween, {
									BackgroundColor3 = uipallet.Main
								})
							end)
							dropdownoption.MouseButton1Click:Connect(function()
								optionapi:SetValue(v, true)
							end)
							ind += 1
						end
					else
						optionapi:SetValue(optionapi.Value, true)
					end
				end)
				dropdown.MouseEnter:Connect(function()
					tween:Tween(bkg, uipallet.Tween, {
						BackgroundColor3 = color.Light(uipallet.Main, 0.0875)
					})
				end)
				dropdown.MouseLeave:Connect(function()
					tween:Tween(bkg, uipallet.Tween, {
						BackgroundColor3 = color.Light(uipallet.Main, 0.034)
					})
				end)

				optionapi.Object = dropdown
				api.Options[optionsettings.Name] = optionapi

				return optionapi
			end,
			Font = function(optionsettings, children, api)
				local fonts = {
					optionsettings.Blacklist,
					'Custom'
				}
				for _, v in Enum.Font:GetEnumItems() do
					if not table.find(fonts, v.Name) then
						table.insert(fonts, v.Name)
					end
				end

				local optionapi = {Value = Font.fromEnum(Enum.Font[fonts[1]])}
				local fontdropdown
				local fontbox
				optionsettings.Function = optionsettings.Function or function() end

				fontdropdown = components.Dropdown({
					Name = optionsettings.Name,
					List = fonts,
					Function = function(val)
						fontbox.Object.Visible = val == 'Custom' and fontdropdown.Object.Visible
						if val ~= 'Custom' then
							optionapi.Value = Font.fromEnum(Enum.Font[val])
							optionsettings.Function(optionapi.Value)
						else
							pcall(function()
								optionapi.Value = Font.fromId(tonumber(fontbox.Value))
							end)
							optionsettings.Function(optionapi.Value)
						end
					end,
					Darker = optionsettings.Darker,
					Visible = optionsettings.Visible
				}, children, api)
				optionapi.Object = fontdropdown.Object
				fontbox = components.TextBox({
					Name = optionsettings.Name..' Asset',
					Placeholder = 'font (rbxasset)',
					Function = function()
						if fontdropdown.Value == 'Custom' then
							pcall(function()
								optionapi.Value = Font.fromId(tonumber(fontbox.Value))
							end)
							optionsettings.Function(optionapi.Value)
						end
					end,
					Visible = false,
					Darker = true
				}, children, api)

				fontdropdown.Object:GetPropertyChangedSignal('Visible'):Connect(function()
					fontbox.Object.Visible = fontdropdown.Object.Visible and fontdropdown.Value == 'Custom'
				end)

				return optionapi
			end,
			Slider = function(optionsettings, children, api)
				local optionapi = {
					Type = 'Slider',
					Value = optionsettings.Default or optionsettings.Min,
					Max = optionsettings.Max,
					Index = getTableSize(api.Options)
				}

				local slider = Instance.new('TextButton')
				slider.Name = optionsettings.Name..'Slider'
				slider.Size = UDim2.new(1, 0, 0, 50)
				slider.BackgroundColor3 = color.Dark(children.BackgroundColor3, optionsettings.Darker and 0.02 or 0)
				slider.BorderSizePixel = 0
				slider.AutoButtonColor = false
				slider.Visible = optionsettings.Visible == nil or optionsettings.Visible
				slider.Text = ''
				slider.Parent = children
				addTooltip(slider, optionsettings.Tooltip)
				local title = Instance.new('TextLabel')
				title.Name = 'Title'
				title.Size = UDim2.fromOffset(60, 30)
				title.Position = UDim2.fromOffset(10, 2)
				title.BackgroundTransparency = 1
				title.Text = optionsettings.Name
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.TextColor3 = color.Dark(uipallet.Text, 0.16)
				title.TextSize = 11
				title.FontFace = uipallet.Font
				title.Parent = slider
				local valuebutton = Instance.new('TextButton')
				valuebutton.Name = 'Value'
				valuebutton.Size = UDim2.fromOffset(60, 15)
				valuebutton.Position = UDim2.new(1, -69, 0, 9)
				valuebutton.BackgroundTransparency = 1
				valuebutton.Text = optionapi.Value..(optionsettings.Suffix and ' '..(type(optionsettings.Suffix) == 'function' and optionsettings.Suffix(optionapi.Value) or optionsettings.Suffix) or '')
				valuebutton.TextXAlignment = Enum.TextXAlignment.Right
				valuebutton.TextColor3 = color.Dark(uipallet.Text, 0.16)
				valuebutton.TextSize = 11
				valuebutton.FontFace = uipallet.Font
				valuebutton.Parent = slider
				local valuebox = Instance.new('TextBox')
				valuebox.Name = 'Box'
				valuebox.Size = valuebutton.Size
				valuebox.Position = valuebutton.Position
				valuebox.BackgroundTransparency = 1
				valuebox.Visible = false
				valuebox.Text = optionapi.Value
				valuebox.TextXAlignment = Enum.TextXAlignment.Right
				valuebox.TextColor3 = color.Dark(uipallet.Text, 0.16)
				valuebox.TextSize = 11
				valuebox.FontFace = uipallet.Font
				valuebox.ClearTextOnFocus = false
				valuebox.Parent = slider
				local bkg = Instance.new('Frame')
				bkg.Name = 'Slider'
				bkg.Size = UDim2.new(1, -20, 0, 2)
				bkg.Position = UDim2.fromOffset(10, 37)
				bkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
				bkg.BorderSizePixel = 0
				bkg.Parent = slider
				local fill = bkg:Clone()
				fill.Name = 'Fill'
				fill.Size = UDim2.fromScale(math.clamp((optionapi.Value - optionsettings.Min) / optionsettings.Max, 0.04, 0.96), 1)
				fill.Position = UDim2.new()
				fill.BackgroundColor3 = Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
				fill.Parent = bkg
				local knobholder = Instance.new('Frame')
				knobholder.Name = 'Knob'
				knobholder.Size = UDim2.fromOffset(24, 4)
				knobholder.Position = UDim2.fromScale(1, 0.5)
				knobholder.AnchorPoint = Vector2.new(0.5, 0.5)
				knobholder.BackgroundColor3 = slider.BackgroundColor3
				knobholder.BorderSizePixel = 0
				knobholder.Parent = fill
				local knob = Instance.new('Frame')
				knob.Name = 'Knob'
				knob.Size = UDim2.fromOffset(14, 14)
				knob.Position = UDim2.fromScale(0.5, 0.5)
				knob.AnchorPoint = Vector2.new(0.5, 0.5)
				knob.BackgroundColor3 = Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
				knob.Parent = knobholder
				addCorner(knob, UDim.new(1, 0))
				optionsettings.Function = optionsettings.Function or function() end
				optionsettings.Decimal = optionsettings.Decimal or 1

				function optionapi:Save(tab)
					tab[optionsettings.Name] = {
						Value = self.Value,
						Max = self.Max
					}
				end

				function optionapi:Load(tab)
					local newval = tab.Value == tab.Max and tab.Max ~= self.Max and self.Max or tab.Value
					if self.Value ~= newval then
						self:SetValue(newval, nil, true)
					end
				end

				function optionapi:Color(hue, sat, val, rainbowcheck)
					fill.BackgroundColor3 = rainbowcheck and Color3.fromHSV(mainapi:Color((hue - (self.Index * 0.075)) % 1)) or Color3.fromHSV(hue, sat, val)
					knob.BackgroundColor3 = fill.BackgroundColor3
				end

				function optionapi:SetValue(value, pos, final)
					if tonumber(value) == math.huge or value ~= value then return end
					local check = self.Value ~= value
					self.Value = value
					tween:Tween(fill, uipallet.Tween, {
						Size = UDim2.fromScale(math.clamp(pos or math.clamp(value / optionsettings.Max, 0, 1), 0.04, 0.96), 1)
					})
					valuebutton.Text = self.Value..(optionsettings.Suffix and ' '..(type(optionsettings.Suffix) == 'function' and optionsettings.Suffix(self.Value) or optionsettings.Suffix) or '')
					if check or final then
						optionsettings.Function(value, final)
					end
				end

				slider.InputBegan:Connect(function(inputObj)
					if
						(inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch)
						and (inputObj.Position.Y - slider.AbsolutePosition.Y) > (20 * scale.Scale)
					then
						local newPosition = math.clamp((inputObj.Position.X - bkg.AbsolutePosition.X) / bkg.AbsoluteSize.X, 0, 1)
						optionapi:SetValue(math.floor((optionsettings.Min + (optionsettings.Max - optionsettings.Min) * newPosition) * optionsettings.Decimal) / optionsettings.Decimal, newPosition)
						local lastValue = optionapi.Value
						local lastPosition = newPosition

						local changed = inputService.InputChanged:Connect(function(input)
							if input.UserInputType == (inputObj.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
								local newPosition = math.clamp((input.Position.X - bkg.AbsolutePosition.X) / bkg.AbsoluteSize.X, 0, 1)
								optionapi:SetValue(math.floor((optionsettings.Min + (optionsettings.Max - optionsettings.Min) * newPosition) * optionsettings.Decimal) / optionsettings.Decimal, newPosition)
								lastValue = optionapi.Value
								lastPosition = newPosition
							end
						end)

						local ended
						ended = inputObj.Changed:Connect(function()
							if inputObj.UserInputState == Enum.UserInputState.End then
								if changed then
									changed:Disconnect()
								end
								if ended then
									ended:Disconnect()
								end
								optionapi:SetValue(lastValue, lastPosition, true)
							end
						end)

					end
				end)
				slider.MouseEnter:Connect(function()
					tween:Tween(knob, uipallet.Tween, {
						Size = UDim2.fromOffset(16, 16)
					})
				end)
				slider.MouseLeave:Connect(function()
					tween:Tween(knob, uipallet.Tween, {
						Size = UDim2.fromOffset(14, 14)
					})
				end)
				valuebutton.MouseButton1Click:Connect(function()
					valuebutton.Visible = false
					valuebox.Visible = true
					valuebox.Text = optionapi.Value
					valuebox:CaptureFocus()
				end)
				valuebox.FocusLost:Connect(function(enter)
					valuebutton.Visible = true
					valuebox.Visible = false
					if enter and tonumber(valuebox.Text) then
						optionapi:SetValue(tonumber(valuebox.Text), nil, true)
					end
				end)

				optionapi.Object = slider
				api.Options[optionsettings.Name] = optionapi

				return optionapi
			end,
			Targets = function(optionsettings, children, api)
				local optionapi = {
					Type = 'Targets',
					Index = getTableSize(api.Options)
				}

				local textlist = Instance.new('TextButton')
				textlist.Name = 'Targets'
				textlist.Size = UDim2.new(1, 0, 0, 50)
				textlist.BackgroundColor3 = color.Dark(children.BackgroundColor3, optionsettings.Darker and 0.02 or 0)
				textlist.BorderSizePixel = 0
				textlist.AutoButtonColor = false
				textlist.Visible = optionsettings.Visible == nil or optionsettings.Visible
				textlist.Text = ''
				textlist.Parent = children
				addTooltip(textlist, optionsettings.Tooltip)
				local bkg = Instance.new('Frame')
				bkg.Name = 'BKG'
				bkg.Size = UDim2.new(1, -20, 1, -9)
				bkg.Position = UDim2.fromOffset(10, 4)
				bkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
				bkg.Parent = textlist
				addCorner(bkg, UDim.new(0, 4))
				local button = Instance.new('TextButton')
				button.Name = 'TextList'
				button.Size = UDim2.new(1, -2, 1, -2)
				button.Position = UDim2.fromOffset(1, 1)
				button.BackgroundColor3 = uipallet.Main
				button.AutoButtonColor = false
				button.Text = ''
				button.Parent = bkg
				local buttontitle = Instance.new('TextLabel')
				buttontitle.Name = 'Title'
				buttontitle.Size = UDim2.new(1, -5, 0, 15)
				buttontitle.Position = UDim2.fromOffset(5, 6)
				buttontitle.BackgroundTransparency = 1
				buttontitle.Text = 'Target:'
				buttontitle.TextXAlignment = Enum.TextXAlignment.Left
				buttontitle.TextColor3 = color.Dark(uipallet.Text, 0.16)
				buttontitle.TextSize = 15
				buttontitle.TextTruncate = Enum.TextTruncate.AtEnd
				buttontitle.FontFace = uipallet.Font
				buttontitle.Parent = button
				local items = buttontitle:Clone()
				items.Name = 'Items'
				items.Position = UDim2.fromOffset(5, 21)
				items.Text = 'Ignore none'
				items.TextColor3 = color.Dark(uipallet.Text, 0.16)
				items.TextSize = 11
				items.Parent = button
				addCorner(button, UDim.new(0, 4))
				local tool = Instance.new('Frame')
				tool.Size = UDim2.fromOffset(65, 12)
				tool.Position = UDim2.fromOffset(52, 8)
				tool.BackgroundTransparency = 1
				tool.Parent = button
				local toollist = Instance.new('UIListLayout')
				toollist.FillDirection = Enum.FillDirection.Horizontal
				toollist.Padding = UDim.new(0, 6)
				toollist.Parent = tool
				local window = Instance.new('TextButton')
				window.Name = 'TargetsTextWindow'
				window.Size = UDim2.fromOffset(220, 145)
				window.BackgroundColor3 = uipallet.Main
				window.BorderSizePixel = 0
				window.AutoButtonColor = false
				window.Visible = false
				window.Text = ''
				window.Parent = clickgui
				optionapi.Window = window
				addBlur(window)
				addCorner(window)
				local icon = Instance.new('ImageLabel')
				icon.Name = 'Icon'
				icon.Size = UDim2.fromOffset(18, 12)
				icon.Position = UDim2.fromOffset(10, 15)
				icon.BackgroundTransparency = 1
				icon.Image = 'rbxassetid://14497393895'
				icon.Parent = window
				local title = Instance.new('TextLabel')
				title.Name = 'Title'
				title.Size = UDim2.new(1, -36, 0, 20)
				title.Position = UDim2.fromOffset(math.abs(title.Size.X.Offset), 11)
				title.BackgroundTransparency = 1
				title.Text = 'Target settings'
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.TextColor3 = uipallet.Text
				title.TextSize = 13
				title.FontFace = uipallet.Font
				title.Parent = window
				local close = addCloseButton(window)
				optionsettings.Function = optionsettings.Function or function() end

				function optionapi:Save(tab)
					tab.Targets = {
						Players = self.Players.Enabled,
						NPCs = self.NPCs.Enabled,
						Invisible = self.Invisible.Enabled,
						Walls = self.Walls.Enabled
					}
				end

				function optionapi:Load(tab)
					if self.Players.Enabled ~= tab.Players then
						self.Players:Toggle()
					end
					if self.NPCs.Enabled ~= tab.NPCs then
						self.NPCs:Toggle()
					end
					if self.Invisible.Enabled ~= tab.Invisible then
						self.Invisible:Toggle()
					end
					if self.Walls.Enabled ~= tab.Walls then
						self.Walls:Toggle()
					end
				end

				function optionapi:Color(hue, sat, val, rainbowcheck)
					bkg.BackgroundColor3 = rainbowcheck and Color3.fromHSV(mainapi:Color((hue - (self.Index * 0.075)) % 1)) or Color3.fromHSV(hue, sat, val)
					if self.Players.Enabled then
						tween:Cancel(self.Players.Object.Frame)
						self.Players.Object.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
					end
					if self.NPCs.Enabled then
						tween:Cancel(self.NPCs.Object.Frame)
						self.NPCs.Object.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
					end
					if self.Invisible.Enabled then
						tween:Cancel(self.Invisible.Object.Knob)
						self.Invisible.Object.Knob.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
					end
					if self.Walls.Enabled then
						tween:Cancel(self.Walls.Object.Knob)
						self.Walls.Object.Knob.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
					end
				end

				optionapi.Players = components.TargetsButton({
					Position = UDim2.fromOffset(11, 45),
					Icon = 'rbxassetid://14497396015',
					IconSize = UDim2.fromOffset(15, 16),
					IconParent = tool,
					ToolIcon = 'rbxassetid://14497397862',
					ToolSize = UDim2.fromOffset(11, 12),
					Tooltip = 'Players',
					Function = optionsettings.Function
				}, window, tool)
				optionapi.NPCs = components.TargetsButton({
					Position = UDim2.fromOffset(112, 45),
					Icon = 'rbxassetid://14497400332',
					IconSize = UDim2.fromOffset(12, 16),
					IconParent = tool,
					ToolIcon = 'rbxassetid://14497402744',
					ToolSize = UDim2.fromOffset(9, 12),
					Tooltip = 'NPCs',
					Function = optionsettings.Function
				}, window, tool)
				optionapi.Invisible = components.Toggle({
					Name = 'Ignore invisible',
					Function = function()
						local text = 'none'
						if optionapi.Invisible.Enabled then
							text = 'invisible'
						end
						if optionapi.Walls.Enabled then
							text = text == 'none' and 'behind walls' or text..', behind walls'
						end
						items.Text = 'Ignore '..text
						optionsettings.Function()
					end
				}, window, {Options = {}})
				optionapi.Invisible.Object.Position = UDim2.fromOffset(0, 81)
				optionapi.Walls = components.Toggle({
					Name = 'Ignore behind walls',
					Function = function()
						local text = 'none'
						if optionapi.Invisible.Enabled then
							text = 'invisible'
						end
						if optionapi.Walls.Enabled then
							text = text == 'none' and 'behind walls' or text..', behind walls'
						end
						items.Text = 'Ignore '..text
						optionsettings.Function()
					end
				}, window, {Options = {}})
				optionapi.Walls.Object.Position = UDim2.fromOffset(0, 111)
				if optionsettings.Players then
					optionapi.Players:Toggle()
				end
				if optionsettings.NPCs then
					optionapi.NPCs:Toggle()
				end
				if optionsettings.Invisible then
					optionapi.Invisible:Toggle()
				end
				if optionsettings.Walls then
					optionapi.Walls:Toggle()
				end

				close.MouseButton1Click:Connect(function()
					window.Visible = false
				end)
				button.MouseButton1Click:Connect(function()
					window.Visible = not window.Visible
					tween:Cancel(bkg)
					bkg.BackgroundColor3 = window.Visible and Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value) or color.Light(uipallet.Main, 0.37)
				end)
				textlist.MouseEnter:Connect(function()
					if not optionapi.Window.Visible then
						tween:Tween(bkg, uipallet.Tween, {
							BackgroundColor3 = color.Light(uipallet.Main, 0.37)
						})
					end
				end)
				textlist.MouseLeave:Connect(function()
					if not optionapi.Window.Visible then
						tween:Tween(bkg, uipallet.Tween, {
							BackgroundColor3 = color.Light(uipallet.Main, 0.034)
						})
					end
				end)
				textlist:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
					if mainapi.ThreadFix then
						setthreadidentity(8)
					end
					local actualPosition = (textlist.AbsolutePosition + Vector2.new(0, 60)) / scale.Scale
					window.Position = UDim2.fromOffset(actualPosition.X + 220, actualPosition.Y)
				end)

				optionapi.Object = textlist
				api.Options.Targets = optionapi

				return optionapi
			end,
			TargetsButton = function(optionsettings, children, api)
				local optionapi = {Enabled = false}

				local targetbutton = Instance.new('TextButton')
				targetbutton.Size = UDim2.fromOffset(98, 31)
				targetbutton.Position = optionsettings.Position
				targetbutton.BackgroundColor3 = color.Light(uipallet.Main, 0.05)
				targetbutton.AutoButtonColor = false
				targetbutton.Visible = optionsettings.Visible == nil or optionsettings.Visible
				targetbutton.Text = ''
				targetbutton.Parent = children
				addCorner(targetbutton)
				addTooltip(targetbutton, optionsettings.Tooltip)
				local bkg = Instance.new('Frame')
				bkg.Size = UDim2.new(1, -2, 1, -2)
				bkg.Position = UDim2.fromOffset(1, 1)
				bkg.BackgroundColor3 = uipallet.Main
				bkg.Parent = targetbutton
				addCorner(bkg)
				local icon = Instance.new('ImageLabel')
				icon.Size = optionsettings.IconSize
				icon.Position = UDim2.fromScale(0.5, 0.5)
				icon.AnchorPoint = Vector2.new(0.5, 0.5)
				icon.BackgroundTransparency = 1
				icon.Image = optionsettings.Icon
				icon.ImageColor3 = color.Light(uipallet.Main, 0.37)
				icon.Parent = bkg
				optionsettings.Function = optionsettings.Function or function() end
				local tooltipicon

				function optionapi:Toggle()
					self.Enabled = not self.Enabled
					tween:Tween(bkg, uipallet.Tween, {
						BackgroundColor3 = self.Enabled and Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value) or uipallet.Main
					})
					tween:Tween(icon, uipallet.Tween, {
						ImageColor3 = self.Enabled and Color3.new(1, 1, 1) or color.Light(uipallet.Main, 0.37)
					})
					if tooltipicon then
						tooltipicon:Destroy()
					end
					if self.Enabled then
						tooltipicon = Instance.new('ImageLabel')
						tooltipicon.Size = optionsettings.ToolSize
						tooltipicon.BackgroundTransparency = 1
						tooltipicon.Image = optionsettings.ToolIcon
						tooltipicon.ImageColor3 = uipallet.Text
						tooltipicon.Parent = optionsettings.IconParent
					end
					optionsettings.Function(self.Enabled)
				end

				targetbutton.MouseEnter:Connect(function()
					if not optionapi.Enabled then
						tween:Tween(bkg, uipallet.Tween, {
							BackgroundColor3 = Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value - 0.25)
						})
						tween:Tween(icon, uipallet.Tween, {
							ImageColor3 = Color3.new(1, 1, 1)
						})
					end
				end)
				targetbutton.MouseLeave:Connect(function()
					if not optionapi.Enabled then
						tween:Tween(bkg, uipallet.Tween, {
							BackgroundColor3 = uipallet.Main
						})
						tween:Tween(icon, uipallet.Tween, {
							ImageColor3 = color.Light(uipallet.Main, 0.37)
						})
					end
				end)
				targetbutton.MouseButton1Click:Connect(function()
					optionapi:Toggle()
				end)

				optionapi.Object = targetbutton

				return optionapi
			end,
			TextBox = function(optionsettings, children, api)
				local optionapi = {
					Type = 'TextBox',
					Value = optionsettings.Default or '',
					Index = 0
				}

				local textbox = Instance.new('TextButton')
				textbox.Name = optionsettings.Name..'TextBox'
				textbox.Size = UDim2.new(1, 0, 0, 58)
				textbox.BackgroundColor3 = color.Dark(children.BackgroundColor3, optionsettings.Darker and 0.02 or 0)
				textbox.BorderSizePixel = 0
				textbox.AutoButtonColor = false
				textbox.Visible = optionsettings.Visible == nil or optionsettings.Visible
				textbox.Text = ''
				textbox.Parent = children
				addTooltip(textbox, optionsettings.Tooltip)
				local title = Instance.new('TextLabel')
				title.Size = UDim2.new(1, -10, 0, 20)
				title.Position = UDim2.fromOffset(10, 3)
				title.BackgroundTransparency = 1
				title.Text = optionsettings.Name
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.TextColor3 = uipallet.Text
				title.TextSize = 12
				title.FontFace = uipallet.Font
				title.Parent = textbox
				local bkg = Instance.new('Frame')
				bkg.Name = 'BKG'
				bkg.Size = UDim2.new(1, -20, 0, 29)
				bkg.Position = UDim2.fromOffset(10, 23)
				bkg.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
				bkg.Parent = textbox
				addCorner(bkg, UDim.new(0, 4))
				local box = Instance.new('TextBox')
				box.Size = UDim2.new(1, -8, 1, 0)
				box.Position = UDim2.fromOffset(8, 0)
				box.BackgroundTransparency = 1
				box.Text = optionsettings.Default or ''
				box.PlaceholderText = optionsettings.Placeholder or 'Click to set'
				box.TextXAlignment = Enum.TextXAlignment.Left
				box.TextColor3 = color.Dark(uipallet.Text, 0.16)
				box.PlaceholderColor3 = color.Dark(uipallet.Text, 0.31)
				box.TextSize = 12
				box.FontFace = uipallet.Font
				box.ClearTextOnFocus = false
				box.Parent = bkg
				optionsettings.Function = optionsettings.Function or function() end

				function optionapi:Save(tab)
					tab[optionsettings.Name] = {Value = self.Value}
				end

				function optionapi:Load(tab)
					if self.Value ~= tab.Value then
						self:SetValue(tab.Value)
					end
				end

				function optionapi:SetValue(val, enter)
					self.Value = val
					box.Text = val
					optionsettings.Function(enter)
				end

				textbox.MouseButton1Click:Connect(function()
					box:CaptureFocus()
				end)
				box.FocusLost:Connect(function(enter)
					optionapi:SetValue(box.Text, enter)
				end)
				box:GetPropertyChangedSignal('Text'):Connect(function()
					optionapi:SetValue(box.Text)
				end)

				optionapi.Object = textbox
				api.Options[optionsettings.Name] = optionapi

				return optionapi
			end,
			TextList = function(optionsettings, children, api)
				local optionapi = {
					Type = 'TextList',
					List = optionsettings.Default or {},
					ListEnabled = optionsettings.Default or {},
					Objects = {},
					Window = {Visible = false},
					Index = getTableSize(api.Options)
				}
				optionsettings.Color = optionsettings.Color or Color3.fromRGB(5, 134, 105)

				local textlist = Instance.new('TextButton')
				textlist.Name = optionsettings.Name..'TextList'
				textlist.Size = UDim2.new(1, 0, 0, 50)
				textlist.BackgroundColor3 = color.Dark(children.BackgroundColor3, optionsettings.Darker and 0.02 or 0)
				textlist.BorderSizePixel = 0
				textlist.AutoButtonColor = false
				textlist.Visible = optionsettings.Visible == nil or optionsettings.Visible
				textlist.Text = ''
				textlist.Parent = children
				addTooltip(textlist, optionsettings.Tooltip)
				local bkg = Instance.new('Frame')
				bkg.Name = 'BKG'
				bkg.Size = UDim2.new(1, -20, 1, -9)
				bkg.Position = UDim2.fromOffset(10, 4)
				bkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
				bkg.Parent = textlist
				addCorner(bkg, UDim.new(0, 4))
				local button = Instance.new('TextButton')
				button.Name = 'TextList'
				button.Size = UDim2.new(1, -2, 1, -2)
				button.Position = UDim2.fromOffset(1, 1)
				button.BackgroundColor3 = uipallet.Main
				button.AutoButtonColor = false
				button.Text = ''
				button.Parent = bkg
				local buttonicon = Instance.new('ImageLabel')
				buttonicon.Name = 'Icon'
				buttonicon.Size = UDim2.fromOffset(14, 12)
				buttonicon.Position = UDim2.fromOffset(10, 14)
				buttonicon.BackgroundTransparency = 1
				buttonicon.Image = optionsettings.Icon or 'rbxassetid://14368302000'
				buttonicon.Parent = button
				local buttontitle = Instance.new('TextLabel')
				buttontitle.Name = 'Title'
				buttontitle.Size = UDim2.new(1, -35, 0, 15)
				buttontitle.Position = UDim2.fromOffset(35, 6)
				buttontitle.BackgroundTransparency = 1
				buttontitle.Text = optionsettings.Name
				buttontitle.TextXAlignment = Enum.TextXAlignment.Left
				buttontitle.TextColor3 = color.Dark(uipallet.Text, 0.16)
				buttontitle.TextSize = 15
				buttontitle.TextTruncate = Enum.TextTruncate.AtEnd
				buttontitle.FontFace = uipallet.Font
				buttontitle.Parent = button
				local amount = buttontitle:Clone()
				amount.Name = 'Amount'
				amount.Size = UDim2.new(1, -13, 0, 15)
				amount.Position = UDim2.fromOffset(0, 6)
				amount.Text = '0'
				amount.TextXAlignment = Enum.TextXAlignment.Right
				amount.Parent = button
				local items = buttontitle:Clone()
				items.Name = 'Items'
				items.Position = UDim2.fromOffset(35, 21)
				items.Text = 'None'
				items.TextColor3 = color.Dark(uipallet.Text, 0.43)
				items.TextSize = 11
				items.Parent = button
				addCorner(button, UDim.new(0, 4))
				local window = Instance.new('TextButton')
				window.Name = optionsettings.Name..'TextWindow'
				window.Size = UDim2.fromOffset(220, 85)
				window.BackgroundColor3 = uipallet.Main
				window.BorderSizePixel = 0
				window.AutoButtonColor = false
				window.Visible = false
				window.Text = ''
				window.Parent = api.Legit and mainapi.Legit.Window or clickgui
				optionapi.Window = window
				addBlur(window)
				addCorner(window)
				local icon = Instance.new('ImageLabel')
				icon.Name = 'Icon'
				icon.Size = optionsettings.TabSize or UDim2.fromOffset(19, 16)
				icon.Position = UDim2.fromOffset(10, 13)
				icon.BackgroundTransparency = 1
				icon.Image = optionsettings.Tab or 'rbxassetid://14368302875'
				icon.Parent = window
				local title = Instance.new('TextLabel')
				title.Name = 'Title'
				title.Size = UDim2.new(1, -36, 0, 20)
				title.Position = UDim2.fromOffset(math.abs(title.Size.X.Offset), 11)
				title.BackgroundTransparency = 1
				title.Text = optionsettings.Name
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.TextColor3 = uipallet.Text
				title.TextSize = 13
				title.FontFace = uipallet.Font
				title.Parent = window
				local close = addCloseButton(window)
				local addbkg = Instance.new('Frame')
				addbkg.Name = 'Add'
				addbkg.Size = UDim2.fromOffset(200, 31)
				addbkg.Position = UDim2.fromOffset(10, 45)
				addbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
				addbkg.Parent = window
				addCorner(addbkg)
				local addbox = addbkg:Clone()
				addbox.Size = UDim2.new(1, -2, 1, -2)
				addbox.Position = UDim2.fromOffset(1, 1)
				addbox.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
				addbox.Parent = addbkg
				local addvalue = Instance.new('TextBox')
				addvalue.Size = UDim2.new(1, -35, 1, 0)
				addvalue.Position = UDim2.fromOffset(10, 0)
				addvalue.BackgroundTransparency = 1
				addvalue.Text = ''
				addvalue.PlaceholderText = optionsettings.Placeholder or 'Add entry...'
				addvalue.TextXAlignment = Enum.TextXAlignment.Left
				addvalue.TextColor3 = Color3.new(1, 1, 1)
				addvalue.TextSize = 15
				addvalue.FontFace = uipallet.Font
				addvalue.ClearTextOnFocus = false
				addvalue.Parent = addbkg
				local addbutton = Instance.new('ImageButton')
				addbutton.Name = 'AddButton'
				addbutton.Size = UDim2.fromOffset(16, 16)
				addbutton.Position = UDim2.new(1, -26, 0, 8)
				addbutton.BackgroundTransparency = 1
				addbutton.Image = "rbxassetid://14368300605"
				addbutton.ImageColor3 = optionsettings.Color
				addbutton.ImageTransparency = 0.3
				addbutton.Parent = addbkg
				optionsettings.Function = optionsettings.Function or function() end

				function optionapi:Save(tab)
					tab[optionsettings.Name] = {
						List = self.List,
						ListEnabled = self.ListEnabled
					}
				end

				function optionapi:Load(tab)
					self.List = tab.List or {}
					self.ListEnabled = tab.ListEnabled or {}
					self:ChangeValue()
				end

				function optionapi:Color(hue, sat, val, rainbowcheck)
					if window.Visible then
						bkg.BackgroundColor3 = rainbowcheck and Color3.fromHSV(mainapi:Color((hue - (self.Index * 0.075)) % 1)) or Color3.fromHSV(hue, sat, val)
					end
				end

				function optionapi:ChangeValue(val)
					if val then
						local ind = table.find(self.List, val)
						if ind then
							table.remove(self.List, ind)
							ind = table.find(self.ListEnabled, val)
							if ind then
								table.remove(self.ListEnabled, ind)
							end
						else
							table.insert(self.List, val)
							table.insert(self.ListEnabled, val)
						end
					end

					optionsettings.Function(self.List)
					for _, v in self.Objects do
						v:Destroy()
					end
					table.clear(self.Objects)
					window.Size = UDim2.fromOffset(220, 85 + (#self.List * 35))
					amount.Text = #self.List

					local enabledtext = 'None'
					for i, v in self.ListEnabled do
						if i == 1 then enabledtext = '' end
						enabledtext = enabledtext..(i == 1 and v or ', '..v)
					end
					items.Text = enabledtext

					for i, v in self.List do
						local enabled = table.find(self.ListEnabled, v)
						local object = Instance.new('TextButton')
						object.Name = v
						object.Size = UDim2.fromOffset(200, 32)
						object.Position = UDim2.fromOffset(10, 47 + (i * 35))
						object.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
						object.AutoButtonColor = false
						object.Text = ''
						object.Parent = window
						addCorner(object)
						local objectbkg = Instance.new('Frame')
						objectbkg.Name = 'BKG'
						objectbkg.Size = UDim2.new(1, -2, 1, -2)
						objectbkg.Position = UDim2.fromOffset(1, 1)
						objectbkg.BackgroundColor3 = uipallet.Main
						objectbkg.Visible = false
						objectbkg.Parent = object
						addCorner(objectbkg)
						local objectdot = Instance.new('Frame')
						objectdot.Name = 'Dot'
						objectdot.Size = UDim2.fromOffset(10, 11)
						objectdot.Position = UDim2.fromOffset(10, 12)
						objectdot.BackgroundColor3 = enabled and optionsettings.Color or color.Light(uipallet.Main, 0.37)
						objectdot.Parent = object
						addCorner(objectdot, UDim.new(1, 0))
						local objectdotin = objectdot:Clone()
						objectdotin.Size = UDim2.fromOffset(8, 9)
						objectdotin.Position = UDim2.fromOffset(1, 1)
						objectdotin.BackgroundColor3 = enabled and optionsettings.Color or color.Light(uipallet.Main, 0.02)
						objectdotin.Parent = objectdot
						local objecttitle = Instance.new('TextLabel')
						objecttitle.Name = 'Title'
						objecttitle.Size = UDim2.new(1, -30, 1, 0)
						objecttitle.Position = UDim2.fromOffset(30, 0)
						objecttitle.BackgroundTransparency = 1
						objecttitle.Text = v
						objecttitle.TextXAlignment = Enum.TextXAlignment.Left
						objecttitle.TextColor3 = color.Dark(uipallet.Text, 0.16)
						objecttitle.TextSize = 15
						objecttitle.FontFace = uipallet.Font
						objecttitle.Parent = object
						local close = Instance.new('ImageButton')
						close.Name = 'Close'
						close.Size = UDim2.fromOffset(16, 16)
						close.Position = UDim2.new(1, -26, 0, 8)
						close.BackgroundColor3 = Color3.new(1, 1, 1)
						close.BackgroundTransparency = 1
						close.AutoButtonColor = false
						close.Image = 'rbxassetid://14368310467'
						close.ImageColor3 = color.Light(uipallet.Text, 0.2)
						close.ImageTransparency = 0.5
						close.Parent = object
						addCorner(close, UDim.new(1, 0))

						close.MouseEnter:Connect(function()
							close.ImageTransparency = 0.3
							tween:Tween(close, uipallet.Tween, {
								BackgroundTransparency = 0.6
							})
						end)
						close.MouseLeave:Connect(function()
							close.ImageTransparency = 0.5
							tween:Tween(close, uipallet.Tween, {
								BackgroundTransparency = 1
							})
						end)
						close.MouseButton1Click:Connect(function()
							self:ChangeValue(v)
						end)
						object.MouseEnter:Connect(function()
							objectbkg.Visible = true
						end)
						object.MouseLeave:Connect(function()
							objectbkg.Visible = false
						end)
						object.MouseButton1Click:Connect(function()
							local ind = table.find(self.ListEnabled, v)
							if ind then
								table.remove(self.ListEnabled, ind)
								objectdot.BackgroundColor3 = color.Light(uipallet.Main, 0.37)
								objectdotin.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
							else
								table.insert(self.ListEnabled, v)
								objectdot.BackgroundColor3 = optionsettings.Color
								objectdotin.BackgroundColor3 = optionsettings.Color
							end

							local enabledtext = 'None'
							for i, v in self.ListEnabled do
								if i == 1 then enabledtext = '' end
								enabledtext = enabledtext..(i == 1 and v or ', '..v)
							end

							items.Text = enabledtext
							optionsettings.Function()
						end)

						table.insert(self.Objects, object)
					end
				end

				addbutton.MouseEnter:Connect(function()
					addbutton.ImageTransparency = 0
				end)
				addbutton.MouseLeave:Connect(function()
					addbutton.ImageTransparency = 0.3
				end)
				addbutton.MouseButton1Click:Connect(function()
					if not table.find(optionapi.List, addvalue.Text) then
						optionapi:ChangeValue(addvalue.Text)
						addvalue.Text = ''
					end
				end)
				addvalue.FocusLost:Connect(function(enter)
					if enter and not table.find(optionapi.List, addvalue.Text) then
						optionapi:ChangeValue(addvalue.Text)
						addvalue.Text = ''
					end
				end)
				addvalue.MouseEnter:Connect(function()
					tween:Tween(addbkg, uipallet.Tween, {
						BackgroundColor3 = color.Light(uipallet.Main, 0.14)
					})
				end)
				addvalue.MouseLeave:Connect(function()
					tween:Tween(addbkg, uipallet.Tween, {
						BackgroundColor3 = color.Light(uipallet.Main, 0.02)
					})
				end)
				close.MouseButton1Click:Connect(function()
					window.Visible = false
				end)
				button.MouseButton1Click:Connect(function()
					window.Visible = not window.Visible
					tween:Cancel(bkg)
					bkg.BackgroundColor3 = window.Visible and Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value) or color.Light(uipallet.Main, 0.37)
				end)
				textlist.MouseEnter:Connect(function()
					if not optionapi.Window.Visible then
						tween:Tween(bkg, uipallet.Tween, {
							BackgroundColor3 = color.Light(uipallet.Main, 0.37)
						})
					end
				end)
				textlist.MouseLeave:Connect(function()
					if not optionapi.Window.Visible then
						tween:Tween(bkg, uipallet.Tween, {
							BackgroundColor3 = color.Light(uipallet.Main, 0.034)
						})
					end
				end)
				textlist:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
					if mainapi.ThreadFix then
						setthreadidentity(8)
					end
					local actualPosition = (textlist.AbsolutePosition - (api.Legit and mainapi.Legit.Window.AbsolutePosition or -guiService:GetGuiInset())) / scale.Scale
					window.Position = UDim2.fromOffset(actualPosition.X + 220, actualPosition.Y)
				end)

				if optionsettings.Default then
					optionapi:ChangeValue()
				end
				optionapi.Object = textlist
				api.Options[optionsettings.Name] = optionapi

				return optionapi
			end,
			Toggle = function(optionsettings, children, api)
				local optionapi = {
					Type = 'Toggle',
					Enabled = false,
					Index = getTableSize(api.Options)
				}

				local hovered = false
				local toggle = Instance.new('TextButton')
				toggle.Name = optionsettings.Name..'Toggle'
				toggle.Size = UDim2.new(1, 0, 0, 30)
				toggle.BackgroundColor3 = color.Dark(children.BackgroundColor3, optionsettings.Darker and 0.02 or 0)
				toggle.BorderSizePixel = 0
				toggle.AutoButtonColor = false
				toggle.Visible = optionsettings.Visible == nil or optionsettings.Visible
				toggle.Text = '          '..optionsettings.Name
				toggle.TextXAlignment = Enum.TextXAlignment.Left
				toggle.TextColor3 = color.Dark(uipallet.Text, 0.16)
				toggle.TextSize = 14
				toggle.FontFace = uipallet.Font
				toggle.Parent = children
				addTooltip(toggle, optionsettings.Tooltip)
				local knobholder = Instance.new('Frame')
				knobholder.Name = 'Knob'
				knobholder.Size = UDim2.fromOffset(22, 12)
				knobholder.Position = UDim2.new(1, -30, 0, 9)
				knobholder.BackgroundColor3 = color.Light(uipallet.Main, 0.14)
				knobholder.Parent = toggle
				addCorner(knobholder, UDim.new(1, 0))
				local knob = knobholder:Clone()
				knob.Size = UDim2.fromOffset(8, 8)
				knob.Position = UDim2.fromOffset(2, 2)
				knob.BackgroundColor3 = uipallet.Main
				knob.Parent = knobholder
				optionsettings.Function = optionsettings.Function or function() end

				function optionapi:Save(tab)
					tab[optionsettings.Name] = {Enabled = self.Enabled}
				end

				function optionapi:Load(tab)
					if self.Enabled ~= tab.Enabled then
						self:Toggle()
					end
				end

				function optionapi:Color(hue, sat, val, rainbowcheck)
					if self.Enabled then
						tween:Cancel(knobholder)
						knobholder.BackgroundColor3 = rainbowcheck and Color3.fromHSV(mainapi:Color((hue - (self.Index * 0.075)) % 1)) or Color3.fromHSV(hue, sat, val)
					end
				end

				function optionapi:Toggle()
					self.Enabled = not self.Enabled
					local rainbowcheck = mainapi.GUIColor.Rainbow and mainapi.RainbowMode.Value ~= 'Retro'
					tween:Tween(knobholder, uipallet.Tween, {
						BackgroundColor3 = self.Enabled and (rainbowcheck and Color3.fromHSV(mainapi:Color((mainapi.GUIColor.Hue - (self.Index * 0.075)) % 1)) or Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)) or (hovered and color.Light(uipallet.Main, 0.37) or color.Light(uipallet.Main, 0.14))
					})
					tween:Tween(knob, uipallet.Tween, {
						Position = UDim2.fromOffset(self.Enabled and 12 or 2, 2)
					})
					optionsettings.Function(self.Enabled)
				end

				toggle.MouseEnter:Connect(function()
					hovered = true
					if not optionapi.Enabled then
						tween:Tween(knobholder, uipallet.Tween, {
							BackgroundColor3 = color.Light(uipallet.Main, 0.37)
						})
					end
				end)
				toggle.MouseLeave:Connect(function()
					hovered = false
					if not optionapi.Enabled then
						tween:Tween(knobholder, uipallet.Tween, {
							BackgroundColor3 = color.Light(uipallet.Main, 0.14)
						})
					end
				end)
				toggle.MouseButton1Click:Connect(function()
					optionapi:Toggle()
				end)

				if optionsettings.Default then
					optionapi:Toggle()
				end
				optionapi.Object = toggle
				api.Options[optionsettings.Name] = optionapi

				return optionapi
			end,
			TwoSlider = function(optionsettings, children, api)
				local optionapi = {
					Type = 'TwoSlider',
					ValueMin = optionsettings.DefaultMin or optionsettings.Min,
					ValueMax = optionsettings.DefaultMax or 10,
					Max = optionsettings.Max,
					Index = getTableSize(api.Options)
				}

				local slider = Instance.new('TextButton')
				slider.Name = optionsettings.Name..'Slider'
				slider.Size = UDim2.new(1, 0, 0, 50)
				slider.BackgroundColor3 = color.Dark(children.BackgroundColor3, optionsettings.Darker and 0.02 or 0)
				slider.BorderSizePixel = 0
				slider.AutoButtonColor = false
				slider.Visible = optionsettings.Visible == nil or optionsettings.Visible
				slider.Text = ''
				slider.Parent = children
				addTooltip(slider, optionsettings.Tooltip)
				local title = Instance.new('TextLabel')
				title.Name = 'Title'
				title.Size = UDim2.fromOffset(60, 30)
				title.Position = UDim2.fromOffset(10, 2)
				title.BackgroundTransparency = 1
				title.Text = optionsettings.Name
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.TextColor3 = color.Dark(uipallet.Text, 0.16)
				title.TextSize = 11
				title.FontFace = uipallet.Font
				title.Parent = slider
				local valuebutton = Instance.new('TextButton')
				valuebutton.Name = 'Value'
				valuebutton.Size = UDim2.fromOffset(60, 15)
				valuebutton.Position = UDim2.new(1, -69, 0, 9)
				valuebutton.BackgroundTransparency = 1
				valuebutton.Text = optionapi.ValueMax
				valuebutton.TextXAlignment = Enum.TextXAlignment.Right
				valuebutton.TextColor3 = color.Dark(uipallet.Text, 0.16)
				valuebutton.TextSize = 11
				valuebutton.FontFace = uipallet.Font
				valuebutton.Parent = slider
				local valuebutton2 = valuebutton:Clone()
				valuebutton2.Position = UDim2.new(1, -125, 0, 9)
				valuebutton2.Text = optionapi.ValueMin
				valuebutton2.Parent = slider
				local valuebox = Instance.new('TextBox')
				valuebox.Name = 'Box'
				valuebox.Size = valuebutton.Size
				valuebox.Position = valuebutton.Position
				valuebox.BackgroundTransparency = 1
				valuebox.Visible = false
				valuebox.Text = optionapi.ValueMin
				valuebox.TextXAlignment = Enum.TextXAlignment.Right
				valuebox.TextColor3 = color.Dark(uipallet.Text, 0.16)
				valuebox.TextSize = 11
				valuebox.FontFace = uipallet.Font
				valuebox.ClearTextOnFocus = false
				valuebox.Parent = slider
				local valuebox2 = valuebox:Clone()
				valuebox2.Position = valuebutton2.Position
				valuebox2.Parent = slider
				local bkg = Instance.new('Frame')
				bkg.Name = 'Slider'
				bkg.Size = UDim2.new(1, -20, 0, 2)
				bkg.Position = UDim2.fromOffset(10, 37)
				bkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
				bkg.BorderSizePixel = 0
				bkg.Parent = slider
				local fill = bkg:Clone()
				fill.Name = 'Fill'
				fill.Position = UDim2.fromScale(math.clamp(optionapi.ValueMin / optionsettings.Max, 0.04, 0.96), 0)
				fill.Size = UDim2.fromScale(math.clamp(math.clamp(optionapi.ValueMax / optionsettings.Max, 0, 1), 0.04, 0.96) - fill.Position.X.Scale, 1)
				fill.BackgroundColor3 = Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
				fill.Parent = bkg
				local knobholder = Instance.new('Frame')
				knobholder.Name = 'Knob'
				knobholder.Size = UDim2.fromOffset(16, 4)
				knobholder.Position = UDim2.fromScale(0, 0.5)
				knobholder.AnchorPoint = Vector2.new(0.5, 0.5)
				knobholder.BackgroundColor3 = slider.BackgroundColor3
				knobholder.BorderSizePixel = 0
				knobholder.Parent = fill
				local knob = Instance.new('ImageLabel')
				knob.Name = 'Knob'
				knob.Size = UDim2.fromOffset(9, 16)
				knob.Position = UDim2.fromScale(0.5, 0.5)
				knob.AnchorPoint = Vector2.new(0.5, 0.5)
				knob.BackgroundTransparency = 1
				knob.Image = 'rbxassetid://14368347435'
				knob.ImageColor3 = Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
				knob.Parent = knobholder
				local knobholdermax = knobholder:Clone()
				knobholdermax.Name = 'KnobMax'
				knobholdermax.Position = UDim2.fromScale(1, 0.5)
				knobholdermax.Parent = fill
				knobholdermax.Knob.Rotation = 180
				local arrow = Instance.new('ImageLabel')
				arrow.Name = 'Arrow'
				arrow.Size = UDim2.fromOffset(12, 6)
				arrow.Position = UDim2.new(1, -56, 0, 10)
				arrow.BackgroundTransparency = 1
				arrow.Image = 'rbxassetid://14368348640'
				arrow.ImageColor3 = color.Light(uipallet.Main, 0.14)
				arrow.Parent = slider
				optionsettings.Function = optionsettings.Function or function() end
				optionsettings.Decimal = optionsettings.Decimal or 1
				local random = Random.new()

				function optionapi:Save(tab)
					tab[optionsettings.Name] = {ValueMin = self.ValueMin, ValueMax = self.ValueMax}
				end

				function optionapi:Load(tab)
					if self.ValueMin ~= tab.ValueMin then
						self:SetValue(false, tab.ValueMin)
					end
					if self.ValueMax ~= tab.ValueMax then
						self:SetValue(true, tab.ValueMax)
					end
				end

				function optionapi:Color(hue, sat, val, rainbowcheck)
					fill.BackgroundColor3 = rainbowcheck and Color3.fromHSV(mainapi:Color((hue - (self.Index * 0.075)) % 1)) or Color3.fromHSV(hue, sat, val)
					knob.ImageColor3 = fill.BackgroundColor3
					knobholdermax.Knob.ImageColor3 = fill.BackgroundColor3
				end

				function optionapi:GetRandomValue()
					return random:NextNumber(optionapi.ValueMin, optionapi.ValueMax)
				end

				function optionapi:SetValue(max, value)
					if tonumber(value) == math.huge or value ~= value then return end
					self[max and 'ValueMax' or 'ValueMin'] = value
					valuebutton.Text = self.ValueMax
					valuebutton2.Text = self.ValueMin
					local size = math.clamp(math.clamp(self.ValueMin / optionsettings.Max, 0, 1), 0.04, 0.96)
					tween:Tween(fill, TweenInfo.new(0.1), {
						Position = UDim2.fromScale(size, 0),
						Size = UDim2.fromScale(math.clamp(math.clamp(math.clamp(self.ValueMax / optionsettings.Max, 0.04, 0.96), 0.04, 0.96) - size, 0, 1), 1)
					})
				end

				knobholder.MouseEnter:Connect(function()
					tween:Tween(knob, uipallet.Tween, {
						Size = UDim2.fromOffset(11, 18)
					})
				end)
				knobholder.MouseLeave:Connect(function()
					tween:Tween(knob, uipallet.Tween, {
						Size = UDim2.fromOffset(9, 16)
					})
				end)
				knobholdermax.MouseEnter:Connect(function()
					tween:Tween(knobholdermax.Knob, uipallet.Tween, {
						Size = UDim2.fromOffset(11, 18)
					})
				end)
				knobholdermax.MouseLeave:Connect(function()
					tween:Tween(knobholdermax.Knob, uipallet.Tween, {
						Size = UDim2.fromOffset(9, 16)
					})
				end)
				slider.InputBegan:Connect(function(inputObj)
					if
						(inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch)
						and (inputObj.Position.Y - slider.AbsolutePosition.Y) > (20 * scale.Scale)
					then
						local maxCheck = (inputObj.Position.X - knobholdermax.AbsolutePosition.X) > -10
						local newPosition = math.clamp((inputObj.Position.X - bkg.AbsolutePosition.X) / bkg.AbsoluteSize.X, 0, 1)
						optionapi:SetValue(maxCheck, math.floor((optionsettings.Min + (optionsettings.Max - optionsettings.Min) * newPosition) * optionsettings.Decimal) / optionsettings.Decimal, newPosition)

						local changed = inputService.InputChanged:Connect(function(input)
							if input.UserInputType == (inputObj.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
								local newPosition = math.clamp((input.Position.X - bkg.AbsolutePosition.X) / bkg.AbsoluteSize.X, 0, 1)
								optionapi:SetValue(maxCheck, math.floor((optionsettings.Min + (optionsettings.Max - optionsettings.Min) * newPosition) * optionsettings.Decimal) / optionsettings.Decimal, newPosition)
							end
						end)

						local ended
						ended = inputObj.Changed:Connect(function()
							if inputObj.UserInputState == Enum.UserInputState.End then
								if changed then
									changed:Disconnect()
								end
								if ended then
									ended:Disconnect()
								end
							end
						end)
					end
				end)
				valuebutton.MouseButton1Click:Connect(function()
					valuebutton.Visible = false
					valuebox.Visible = true
					valuebox.Text = optionapi.ValueMax
					valuebox:CaptureFocus()
				end)
				valuebutton2.MouseButton1Click:Connect(function()
					valuebutton2.Visible = false
					valuebox2.Visible = true
					valuebox2.Text = optionapi.ValueMin
					valuebox2:CaptureFocus()
				end)
				valuebox.FocusLost:Connect(function(enter)
					valuebutton.Visible = true
					valuebox.Visible = false
					if enter and tonumber(valuebox.Text) then
						optionapi:SetValue(true, tonumber(valuebox.Text))
					end
				end)
				valuebox2.FocusLost:Connect(function(enter)
					valuebutton2.Visible = true
					valuebox2.Visible = false
					if enter and tonumber(valuebox2.Text) then
						optionapi:SetValue(false, tonumber(valuebox2.Text))
					end
				end)

				optionapi.Object = slider
				api.Options[optionsettings.Name] = optionapi

				return optionapi
			end,
			Divider = function(children, text)
				local divider = Instance.new('Frame')
				divider.Name = 'Divider'
				divider.Size = UDim2.new(1, 0, 0, 1)
				divider.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
				divider.BorderSizePixel = 0
				divider.Parent = children
				if text then
					local label = Instance.new('TextLabel')
					label.Name = 'DividerLabel'
					label.Size = UDim2.fromOffset(218, 27)
					label.BackgroundTransparency = 1
					label.Text = '          '..text:upper()
					label.TextXAlignment = Enum.TextXAlignment.Left
					label.TextColor3 = color.Dark(uipallet.Text, 0.43)
					label.TextSize = 9
					label.FontFace = uipallet.Font
					label.Parent = children
					divider.Position = UDim2.fromOffset(0, 26)
					divider.Parent = label
				end
			end
		}

		mainapi.Components = setmetatable(components, {
			__newindex = function(self, ind, func)
				for _, v in mainapi.Modules do
					rawset(v, 'Create'..ind, function(_, settings)
						return func(settings, v.Children, v)
					end)
				end

				if mainapi.Legit then
					for _, v in mainapi.Legit.Modules do
						rawset(v, 'Create'..ind, function(_, settings)
							return func(settings, v.Children, v)
						end)
					end
				end

				rawset(self, ind, func)
			end
		})

		task.spawn(function()
			repeat
				local hue = tick() * (0.2 * mainapi.RainbowSpeed.Value) % 1
				for _, v in mainapi.RainbowTable do
					if v.Type == 'GUISlider' then
						v:SetValue(mainapi:Color(hue))
					else
						v:SetValue(hue)
					end
				end
				task.wait(1 / mainapi.RainbowUpdateSpeed.Value)
			until mainapi.Loaded == nil
		end)

		function mainapi:BlurCheck()
			if self.ThreadFix then
				setthreadidentity(8)
				runService:SetRobloxGuiFocused((clickgui.Visible or guiService:GetErrorType() ~= Enum.ConnectionError.OK) and self.Blur.Enabled)
			end
		end

		addMaid(mainapi)

		function mainapi:CreateGUI()
			local categoryapi = {
				Type = 'MainWindow',
				Buttons = {},
				Options = {}
			}

			local window = Instance.new('TextButton')
			window.Name = 'GUICategory'
			window.Position = UDim2.fromOffset(6, 60)
			window.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
			window.AutoButtonColor = false
			window.Text = ''
			window.Parent = clickgui
			addBlur(window)
			addCorner(window)
			makeDraggable(window)
			local logo = Instance.new('ImageLabel')
			logo.Name = 'VapeLogo'
			logo.Size = UDim2.fromOffset(62, 18)
			logo.Position = UDim2.fromOffset(11, 10)
			logo.BackgroundTransparency = 1
			logo.Image = "rbxassetid://135550237842239"
			logo.ImageColor3 = select(3, uipallet.Main:ToHSV()) > 0.5 and uipallet.Text or Color3.new(1, 1, 1)
			logo.Parent = window
			local logov4 = Instance.new('ImageLabel')
			logov4.Name = 'V4Logo'
			logov4.Size = UDim2.fromOffset(28, 16)
			logov4.Position = UDim2.new(1, 1, 0, 1)
			logov4.BackgroundTransparency = 1
			logov4.Image = "rbxassetid://14368322199"
			logov4.Parent = logo
			local children = Instance.new('Frame')
			children.Name = 'Children'
			children.Size = UDim2.new(1, 0, 1, -33)
			children.Position = UDim2.fromOffset(0, 37)
			children.BackgroundTransparency = 1
			children.Parent = window
			local windowlist = Instance.new('UIListLayout')
			windowlist.SortOrder = Enum.SortOrder.LayoutOrder
			windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
			windowlist.Parent = children
			local settingsbutton = Instance.new('TextButton')
			settingsbutton.Name = 'Settings'
			settingsbutton.Size = UDim2.fromOffset(40, 40)
			settingsbutton.Position = UDim2.new(1, -40, 0, 0)
			settingsbutton.BackgroundTransparency = 1
			settingsbutton.Text = ''
			settingsbutton.Parent = window
			addTooltip(settingsbutton, 'Open settings')
			local settingsicon = Instance.new('ImageLabel')
			settingsicon.Size = UDim2.fromOffset(14, 14)
			settingsicon.Position = UDim2.fromOffset(15, 12)
			settingsicon.BackgroundTransparency = 1
			settingsicon.Image = 'rbxassetid://14368318994'
			settingsicon.ImageColor3 = color.Light(uipallet.Main, 0.37)
			settingsicon.Parent = settingsbutton
			local settingspane = Instance.new('TextButton')
			settingspane.Size = UDim2.fromScale(1, 1)
			settingspane.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
			settingspane.AutoButtonColor = false
			settingspane.Visible = false
			settingspane.Text = ''
			settingspane.Parent = window
			local title = Instance.new('TextLabel')
			title.Name = 'Title'
			title.Size = UDim2.new(1, -36, 0, 20)
			title.Position = UDim2.fromOffset(math.abs(title.Size.X.Offset), 11)
			title.BackgroundTransparency = 1
			title.Text = 'Settings'
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.TextColor3 = uipallet.Text
			title.TextSize = 13
			title.FontFace = uipallet.Font
			title.Parent = settingspane
			local close = addCloseButton(settingspane)
			local back = Instance.new('ImageButton')
			back.Name = 'Back'
			back.Size = UDim2.fromOffset(16, 16)
			back.Position = UDim2.fromOffset(11, 13)
			back.BackgroundTransparency = 1
			back.Image = 'rbxassetid://14368303894'
			back.ImageColor3 = color.Light(uipallet.Main, 0.37)
			back.Parent = settingspane
			local settingsversion = Instance.new('TextLabel')
			settingsversion.Name = 'Version'
			settingsversion.Size = UDim2.new(1, 0, 0, 16)
			settingsversion.Position = UDim2.new(0, 0, 1, -16)
			settingsversion.BackgroundTransparency = 1
			settingsversion.Text = 'Lunar '..mainapi.Version..' '..(
				isfile('newlunar/profiles/commit.txt') and readfile('newlunar/profiles/commit.txt'):sub(1, 6) or ''
			)..' '
			settingsversion.TextColor3 = color.Dark(uipallet.Text, 0.43)
			settingsversion.TextXAlignment = Enum.TextXAlignment.Right
			settingsversion.TextSize = 10
			settingsversion.FontFace = uipallet.Font
			settingsversion.Parent = settingspane
			addCorner(settingspane)
			local settingschildren = Instance.new('Frame')
			settingschildren.Name = 'Children'
			settingschildren.Size = UDim2.new(1, 0, 1, -57)
			settingschildren.Position = UDim2.fromOffset(0, 41)
			settingschildren.BackgroundColor3 = uipallet.Main
			settingschildren.BorderSizePixel = 0
			settingschildren.Parent = settingspane
			local settingswindowlist = Instance.new('UIListLayout')
			settingswindowlist.SortOrder = Enum.SortOrder.LayoutOrder
			settingswindowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
			settingswindowlist.Parent = settingschildren
			categoryapi.Object = window

			function categoryapi:CreateBind()
				local optionapi = {Bind = {'RightShift'}}

				local button = Instance.new('TextButton')
				button.Size = UDim2.fromOffset(220, 40)
				button.BackgroundColor3 = uipallet.Main
				button.BorderSizePixel = 0
				button.AutoButtonColor = false
				button.Text = '          Rebind GUI'
				button.TextXAlignment = Enum.TextXAlignment.Left
				button.TextColor3 = color.Dark(uipallet.Text, 0.16)
				button.TextSize = 14
				button.FontFace = uipallet.Font
				button.Parent = settingschildren
				addTooltip(button, 'Change the bind of the GUI')
				local bind = Instance.new('TextButton')
				bind.Name = 'Bind'
				bind.Size = UDim2.fromOffset(20, 21)
				bind.Position = UDim2.new(1, -10, 0, 9)
				bind.AnchorPoint = Vector2.new(1, 0)
				bind.BackgroundColor3 = Color3.new(1, 1, 1)
				bind.BackgroundTransparency = 0.92
				bind.BorderSizePixel = 0
				bind.AutoButtonColor = false
				bind.Text = ''
				bind.Parent = button
				addTooltip(bind, 'Click to bind')
				addCorner(bind, UDim.new(0, 4))
				local icon = Instance.new('ImageLabel')
				icon.Name = 'Icon'
				icon.Size = UDim2.fromOffset(12, 12)
				icon.Position = UDim2.new(0.5, -6, 0, 5)
				icon.BackgroundTransparency = 1
				icon.Image = 'rbxassetid://14368304734'
				icon.ImageColor3 = color.Dark(uipallet.Text, 0.43)
				icon.Parent = bind
				local label = Instance.new('TextLabel')
				label.Name = 'Text'
				label.Size = UDim2.fromScale(1, 1)
				label.Position = UDim2.fromOffset(0, 1)
				label.BackgroundTransparency = 1
				label.Visible = false
				label.Text = ''
				label.TextColor3 = color.Dark(uipallet.Text, 0.43)
				label.TextSize = 12
				label.FontFace = uipallet.Font
				label.Parent = bind

				function optionapi:SetBind(tab)
					mainapi.Keybind = #tab <= 0 and mainapi.Keybind or table.clone(tab)
					self.Bind = mainapi.Keybind
					if mainapi.VapeButton then
						mainapi.VapeButton:Destroy()
						mainapi.VapeButton = nil
					end

					bind.Visible = true
					label.Visible = true
					icon.Visible = false
					label.Text = table.concat(mainapi.Keybind, ' + '):upper()
					bind.Size = UDim2.fromOffset(math.max(getfontsize(label.Text, label.TextSize, label.Font).X + 10, 20), 21)
				end

				bind.MouseEnter:Connect(function()
					label.Visible = false
					icon.Visible = not label.Visible
					icon.Image = 'rbxassetid://14368315443'
					icon.ImageColor3 = color.Dark(uipallet.Text, 0.16)
				end)
				bind.MouseLeave:Connect(function()
					label.Visible = true
					icon.Visible = not label.Visible
					icon.Image = 'rbxassetid://14368304734'
					icon.ImageColor3 = color.Dark(uipallet.Text, 0.43)
				end)
				bind.MouseButton1Click:Connect(function()
					mainapi.Binding = optionapi
				end)

				categoryapi.Options.Bind = optionapi

				return optionapi
			end

			function categoryapi:CreateButton(categorysettings)
				local optionapi = {
					Enabled = false,
					Index = getTableSize(categoryapi.Buttons)
				}

				local button = Instance.new('TextButton')
				button.Name = categorysettings.Name
				button.Size = UDim2.fromOffset(220, 40)
				button.BackgroundColor3 = uipallet.Main
				button.BorderSizePixel = 0
				button.AutoButtonColor = false
				button.Text = (categorysettings.Icon and '                                 ' or '             ')..categorysettings.Name
				button.TextXAlignment = Enum.TextXAlignment.Left
				button.TextColor3 = color.Dark(uipallet.Text, 0.16)
				button.TextSize = 14
				button.FontFace = uipallet.Font
				button.Parent = children
				local icon
				if categorysettings.Icon then
					icon = Instance.new('ImageLabel')
					icon.Name = 'Icon'
					icon.Size = categorysettings.Size
					icon.Position = UDim2.fromOffset(13, 13)
					icon.BackgroundTransparency = 1
					icon.Image = categorysettings.Icon
					icon.ImageColor3 = color.Dark(uipallet.Text, 0.16)
					icon.Parent = button
				end
				if categorysettings.Name == 'Profiles' then
					local label = Instance.new('TextLabel')
					label.Name = 'ProfileLabel'
					label.Size = UDim2.fromOffset(53, 24)
					label.Position = UDim2.new(1, -36, 0, 8)
					label.AnchorPoint = Vector2.new(1, 0)
					label.BackgroundColor3 = color.Light(uipallet.Main, 0.04)
					label.Text = 'default'
					label.TextColor3 = color.Dark(uipallet.Text, 0.29)
					label.TextSize = 12
					label.FontFace = uipallet.Font
					label.Parent = button
					addCorner(label)
					mainapi.ProfileLabel = label
				end
				local arrow = Instance.new('ImageLabel')
				arrow.Name = 'Arrow'
				arrow.Size = UDim2.fromOffset(4, 8)
				arrow.Position = UDim2.new(1, -20, 0, 16)
				arrow.BackgroundTransparency = 1
				arrow.Image = 'rbxassetid://14368316544'
				arrow.ImageColor3 = color.Light(uipallet.Main, 0.37)
				arrow.Parent = button
				optionapi.Name = categorysettings.Name
				optionapi.Icon = icon
				optionapi.Object = button

				function optionapi:Toggle()
					self.Enabled = not self.Enabled
					tween:Tween(arrow, uipallet.Tween, {
						Position = UDim2.new(1, self.Enabled and -14 or -20, 0, 16)
					})
					button.TextColor3 = self.Enabled and Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value) or uipallet.Text
					if icon then
						icon.ImageColor3 = button.TextColor3
					end
					button.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
					categorysettings.Window.Visible = self.Enabled
				end

				button.MouseEnter:Connect(function()
					if not optionapi.Enabled then
						button.TextColor3 = uipallet.Text
						if buttonicon then buttonicon.ImageColor3 = uipallet.Text end
						button.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
					end
				end)
				button.MouseLeave:Connect(function()
					if not optionapi.Enabled then
						button.TextColor3 = color.Dark(uipallet.Text, 0.16)
						if buttonicon then buttonicon.ImageColor3 = color.Dark(uipallet.Text, 0.16) end
						button.BackgroundColor3 = uipallet.Main
					end
				end)
				button.MouseButton1Click:Connect(function()
					optionapi:Toggle()
				end)

				categoryapi.Buttons[categorysettings.Name] = optionapi

				return optionapi
			end

			function categoryapi:CreateDivider(text)
				return components.Divider(children, text)
			end

			function categoryapi:CreateOverlayBar()
				local optionapi = {Toggles = {}}

				local bar = Instance.new('Frame')
				bar.Name = 'Overlays'
				bar.Size = UDim2.fromOffset(220, 36)
				bar.BackgroundColor3 = uipallet.Main
				bar.BorderSizePixel = 0
				bar.Parent = children
				components.Divider(bar)
				local button = Instance.new('ImageButton')
				button.Size = UDim2.fromOffset(24, 24)
				button.Position = UDim2.new(1, -29, 0, 7)
				button.BackgroundTransparency = 1
				button.AutoButtonColor = false
				button.Image = 'rbxassetid://14368339581'
				button.ImageColor3 = color.Light(uipallet.Main, 0.37)
				button.Parent = bar
				addCorner(button, UDim.new(1, 0))
				addTooltip(button, 'Open overlays menu')
				local shadow = Instance.new('TextButton')
				shadow.Name = 'Shadow'
				shadow.Size = UDim2.new(1, 0, 1, -5)
				shadow.BackgroundColor3 = Color3.new()
				shadow.BackgroundTransparency = 1
				shadow.AutoButtonColor = false
				shadow.ClipsDescendants = true
				shadow.Visible = false
				shadow.Text = ''
				shadow.Parent = window
				addCorner(shadow)
				local window = Instance.new('Frame')
				window.Size = UDim2.fromOffset(220, 42)
				window.Position = UDim2.fromScale(0, 1)
				window.BackgroundColor3 = uipallet.Main
				window.Parent = shadow
				addCorner(window)
				local icon = Instance.new('ImageLabel')
				icon.Name = 'Icon'
				icon.Size = UDim2.fromOffset(14, 12)
				icon.Position = UDim2.fromOffset(10, 13)
				icon.BackgroundTransparency = 1
				icon.Image = 'rbxassetid://14397380433'
				icon.ImageColor3 = uipallet.Text
				icon.Parent = window
				local title = Instance.new('TextLabel')
				title.Name = 'Title'
				title.Size = UDim2.new(1, -36, 0, 38)
				title.Position = UDim2.fromOffset(36, 0)
				title.BackgroundTransparency = 1
				title.Text = 'Overlays'
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.TextColor3 = uipallet.Text
				title.TextSize = 15
				title.FontFace = uipallet.Font
				title.Parent = window
				local close = addCloseButton(window, 7)
				local divider = Instance.new('Frame')
				divider.Name = 'Divider'
				divider.Size = UDim2.new(1, 0, 0, 1)
				divider.Position = UDim2.fromOffset(0, 37)
				divider.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
				divider.BorderSizePixel = 0
				divider.Parent = window
				local childrentoggle = Instance.new('Frame')
				childrentoggle.Position = UDim2.fromOffset(0, 38)
				childrentoggle.BackgroundTransparency = 1
				childrentoggle.Parent = window
				local windowlist = Instance.new('UIListLayout')
				windowlist.SortOrder = Enum.SortOrder.LayoutOrder
				windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
				windowlist.Parent = childrentoggle

				function optionapi:CreateToggle(togglesettings)
					local toggleapi = {
						Enabled = false,
						Index = getTableSize(optionapi.Toggles)
					}

					local hovered = false
					local toggle = Instance.new('TextButton')
					toggle.Name = togglesettings.Name..'Toggle'
					toggle.Size = UDim2.new(1, 0, 0, 40)
					toggle.BackgroundTransparency = 1
					toggle.AutoButtonColor = false
					toggle.Text = string.rep(' ', 33 * scale.Scale)..togglesettings.Name
					toggle.TextXAlignment = Enum.TextXAlignment.Left
					toggle.TextColor3 = color.Dark(uipallet.Text, 0.16)
					toggle.TextSize = 14
					toggle.FontFace = uipallet.Font
					toggle.Parent = childrentoggle
					local icon = Instance.new('ImageLabel')
					icon.Name = 'Icon'
					icon.Size = togglesettings.Size
					icon.Position = togglesettings.Position
					icon.BackgroundTransparency = 1
					icon.Image = togglesettings.Icon
					icon.ImageColor3 = uipallet.Text
					icon.Parent = toggle
					local knob = Instance.new('Frame')
					knob.Name = 'Knob'
					knob.Size = UDim2.fromOffset(22, 12)
					knob.Position = UDim2.new(1, -30, 0, 14)
					knob.BackgroundColor3 = color.Light(uipallet.Main, 0.14)
					knob.Parent = toggle
					addCorner(knob, UDim.new(1, 0))
					local knobmain = knob:Clone()
					knobmain.Size = UDim2.fromOffset(8, 8)
					knobmain.Position = UDim2.fromOffset(2, 2)
					knobmain.BackgroundColor3 = uipallet.Main
					knobmain.Parent = knob
					toggleapi.Object = toggle

					function toggleapi:Toggle()
						self.Enabled = not self.Enabled
						tween:Tween(knob, uipallet.Tween, {
							BackgroundColor3 = self.Enabled and Color3.fromHSV(
								mainapi.GUIColor.Hue,
								mainapi.GUIColor.Sat,
								mainapi.GUIColor.Value
							) or (hovered and color.Light(uipallet.Main, 0.37) or color.Light(uipallet.Main, 0.14))
						})
						tween:Tween(knobmain, uipallet.Tween, {
							Position = UDim2.fromOffset(self.Enabled and 12 or 2, 2)
						})
						togglesettings.Function(self.Enabled)
					end

					scale:GetPropertyChangedSignal('Scale'):Connect(function()
						toggle.Text = string.rep(' ', 33 * scale.Scale)..togglesettings.Name
					end)
					toggle.MouseEnter:Connect(function()
						hovered = true
						if not toggleapi.Enabled then
							tween:Tween(knob, uipallet.Tween, {
								BackgroundColor3 = color.Light(uipallet.Main, 0.37)
							})
						end
					end)
					toggle.MouseLeave:Connect(function()
						hovered = false
						if not toggleapi.Enabled then
							tween:Tween(knob, uipallet.Tween, {
								BackgroundColor3 = color.Light(uipallet.Main, 0.14)
							})
						end
					end)
					toggle.MouseButton1Click:Connect(function()
						toggleapi:Toggle()
					end)

					table.insert(optionapi.Toggles, toggleapi)

					return toggleapi
				end

				button.MouseEnter:Connect(function()
					button.ImageColor3 = uipallet.Text
					tween:Tween(button, uipallet.Tween, {
						BackgroundTransparency = 0.9
					})
				end)
				button.MouseLeave:Connect(function()
					button.ImageColor3 = color.Light(uipallet.Main, 0.37)
					tween:Tween(button, uipallet.Tween, {
						BackgroundTransparency = 1
					})
				end)
				button.MouseButton1Click:Connect(function()
					shadow.Visible = true
					tween:Tween(shadow, uipallet.Tween, {
						BackgroundTransparency = 0.5
					})
					tween:Tween(window, uipallet.Tween, {
						Position = UDim2.new(0, 0, 1, -(window.Size.Y.Offset))
					})
				end)
				close.MouseButton1Click:Connect(function()
					tween:Tween(shadow, uipallet.Tween, {
						BackgroundTransparency = 1
					})
					tween:Tween(window, uipallet.Tween, {
						Position = UDim2.fromScale(0, 1)
					})
					task.wait(0.2)
					shadow.Visible = false
				end)
				shadow.MouseButton1Click:Connect(function()
					tween:Tween(shadow, uipallet.Tween, {
						BackgroundTransparency = 1
					})
					tween:Tween(window, uipallet.Tween, {
						Position = UDim2.fromScale(0, 1)
					})
					task.wait(0.2)
					shadow.Visible = false
				end)
				windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
					if mainapi.ThreadFix then
						setthreadidentity(8)
					end
					window.Size = UDim2.fromOffset(220, math.min(37 + windowlist.AbsoluteContentSize.Y / scale.Scale, 605))
					childrentoggle.Size = UDim2.fromOffset(220, window.Size.Y.Offset - 5)
				end)

				mainapi.Overlays = optionapi

				return optionapi
			end

			function categoryapi:CreateSettingsDivider()
				components.Divider(settingschildren)
			end

			function categoryapi:CreateSettingsPane(categorysettings)
				local optionapi = {}

				local button = Instance.new('TextButton')
				button.Name = categorysettings.Name
				button.Size = UDim2.fromOffset(220, 40)
				button.BackgroundColor3 = uipallet.Main
				button.BorderSizePixel = 0
				button.AutoButtonColor = false
				button.Text = '          '..categorysettings.Name
				button.TextXAlignment = Enum.TextXAlignment.Left
				button.TextColor3 = color.Dark(uipallet.Text, 0.16)
				button.TextSize = 14
				button.FontFace = uipallet.Font
				button.Parent = settingschildren
				local arrow = Instance.new('ImageLabel')
				arrow.Name = 'Arrow'
				arrow.Size = UDim2.fromOffset(4, 8)
				arrow.Position = UDim2.new(1, -20, 0, 16)
				arrow.BackgroundTransparency = 1
				arrow.Image = 'rbxassetid://14368316544'
				arrow.ImageColor3 = color.Light(uipallet.Main, 0.37)
				arrow.Parent = button
				local settingspane = Instance.new('TextButton')
				settingspane.Size = UDim2.fromScale(1, 1)
				settingspane.BackgroundColor3 = uipallet.Main
				settingspane.AutoButtonColor = false
				settingspane.Visible = false
				settingspane.Text = ''
				settingspane.Parent = window
				local title = Instance.new('TextLabel')
				title.Name = 'Title'
				title.Size = UDim2.new(1, -36, 0, 20)
				title.Position = UDim2.fromOffset(math.abs(title.Size.X.Offset), 11)
				title.BackgroundTransparency = 1
				title.Text = categorysettings.Name
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.TextColor3 = uipallet.Text
				title.TextSize = 13
				title.FontFace = uipallet.Font
				title.Parent = settingspane
				local close = addCloseButton(settingspane)
				local back = Instance.new('ImageButton')
				back.Name = 'Back'
				back.Size = UDim2.fromOffset(16, 16)
				back.Position = UDim2.fromOffset(11, 13)
				back.BackgroundTransparency = 1
				back.Image = 'rbxassetid://14368303894'
				back.ImageColor3 = color.Light(uipallet.Main, 0.37)
				back.Parent = settingspane
				addCorner(settingspane)
				local settingschildren = Instance.new('Frame')
				settingschildren.Name = 'Children'
				settingschildren.Size = UDim2.new(1, 0, 1, -57)
				settingschildren.Position = UDim2.fromOffset(0, 41)
				settingschildren.BackgroundColor3 = uipallet.Main
				settingschildren.BorderSizePixel = 0
				settingschildren.Parent = settingspane
				local divider = Instance.new('Frame')
				divider.Name = 'Divider'
				divider.Size = UDim2.new(1, 0, 0, 1)
				divider.BackgroundColor3 = Color3.new(1, 1, 1)
				divider.BackgroundTransparency = 0.928
				divider.BorderSizePixel = 0
				divider.Parent = settingschildren
				local settingswindowlist = Instance.new('UIListLayout')
				settingswindowlist.SortOrder = Enum.SortOrder.LayoutOrder
				settingswindowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
				settingswindowlist.Parent = settingschildren

				for i, v in components do
					optionapi['Create'..i] = function(_, settings)
						return v(settings, settingschildren, categoryapi)
					end
				end

				back.MouseEnter:Connect(function()
					back.ImageColor3 = uipallet.Text
				end)
				back.MouseLeave:Connect(function()
					back.ImageColor3 = color.Light(uipallet.Main, 0.37)
				end)
				back.MouseButton1Click:Connect(function()
					settingspane.Visible = false
				end)
				button.MouseEnter:Connect(function()
					button.TextColor3 = uipallet.Text
					button.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
				end)
				button.MouseLeave:Connect(function()
					button.TextColor3 = color.Dark(uipallet.Text, 0.16)
					button.BackgroundColor3 = uipallet.Main
				end)
				button.MouseButton1Click:Connect(function()
					settingspane.Visible = true
				end)
				close.MouseButton1Click:Connect(function()
					settingspane.Visible = false
				end)
				windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
					if mainapi.ThreadFix then
						setthreadidentity(8)
					end
					window.Size = UDim2.fromOffset(220, 45 + windowlist.AbsoluteContentSize.Y / scale.Scale)
					for _, v in categoryapi.Buttons do
						if v.Icon then
							v.Object.Text = string.rep(' ', 33 * scale.Scale)..v.Name
						end
					end
				end)

				return optionapi
			end

			function categoryapi:CreateGUISlider(optionsettings)
				local optionapi = {
					Type = 'GUISlider',
					Notch = 4,
					Hue = 0.46,
					Sat = 0.96,
					Value = 0.52,
					Rainbow = false,
					CustomColor = false
				}
				local slidercolors = {
					Color3.fromRGB(250, 50, 56),
					Color3.fromRGB(242, 99, 33),
					Color3.fromRGB(252, 179, 22),
					Color3.fromRGB(5, 133, 104),
					Color3.fromRGB(47, 122, 229),
					Color3.fromRGB(126, 84, 217),
					Color3.fromRGB(232, 96, 152)
				}
				local slidercolorpos = {
					4,
					33,
					62,
					90,
					119,
					148,
					177
				}

				local function createSlider(name, gradientColor)
					local slider = Instance.new('TextButton')
					slider.Name = optionsettings.Name..'Slider'..name
					slider.Size = UDim2.fromOffset(220, 50)
					slider.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
					slider.BorderSizePixel = 0
					slider.AutoButtonColor = false
					slider.Visible = false
					slider.Text = ''
					slider.Parent = settingschildren
					local title = Instance.new('TextLabel')
					title.Name = 'Title'
					title.Size = UDim2.fromOffset(60, 30)
					title.Position = UDim2.fromOffset(10, 2)
					title.BackgroundTransparency = 1
					title.Text = name
					title.TextXAlignment = Enum.TextXAlignment.Left
					title.TextColor3 = color.Dark(uipallet.Text, 0.16)
					title.TextSize = 11
					title.FontFace = uipallet.Font
					title.Parent = slider
					local holder = Instance.new('Frame')
					holder.Name = 'Slider'
					holder.Size = UDim2.fromOffset(200, 2)
					holder.Position = UDim2.fromOffset(10, 37)
					holder.BackgroundColor3 = Color3.new(1, 1, 1)
					holder.BorderSizePixel = 0
					holder.Parent = slider
					local uigradient = Instance.new('UIGradient')
					uigradient.Color = gradientColor
					uigradient.Parent = holder
					local fill = holder:Clone()
					fill.Name = 'Fill'
					fill.Size = UDim2.fromScale(math.clamp(1, 0.04, 0.96), 1)
					fill.Position = UDim2.new()
					fill.BackgroundTransparency = 1
					fill.Parent = holder
					local knobframe = Instance.new('Frame')
					knobframe.Name = 'Knob'
					knobframe.Size = UDim2.fromOffset(24, 4)
					knobframe.Position = UDim2.fromScale(1, 0.5)
					knobframe.AnchorPoint = Vector2.new(0.5, 0.5)
					knobframe.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
					knobframe.BorderSizePixel = 0
					knobframe.Parent = fill
					local knob = Instance.new('Frame')
					knob.Name = 'Knob'
					knob.Size = UDim2.fromOffset(14, 14)
					knob.Position = UDim2.fromScale(0.5, 0.5)
					knob.AnchorPoint = Vector2.new(0.5, 0.5)
					knob.BackgroundColor3 = uipallet.Text
					knob.Parent = knobframe
					addCorner(knob, UDim.new(1, 0))
					if name == 'Custom color' then
						local reset = Instance.new('TextButton')
						reset.Size = UDim2.fromOffset(45, 20)
						reset.Position = UDim2.new(1, -52, 0, 5)
						reset.BackgroundTransparency = 1
						reset.Text = 'RESET'
						reset.TextColor3 = color.Dark(uipallet.Text, 0.16)
						reset.TextSize = 11
						reset.FontFace = uipallet.Font
						reset.Parent = slider
						reset.MouseButton1Click:Connect(function()
							optionapi:SetValue(nil, nil, nil, 4)
						end)
					end

					slider.InputBegan:Connect(function(inputObj)
						if
							(inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch)
							and (inputObj.Position.Y - slider.AbsolutePosition.Y) > (20 * scale.Scale)
						then
							local changed = inputService.InputChanged:Connect(function(input)
								if input.UserInputType == (inputObj.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
									local value = math.clamp((input.Position.X - holder.AbsolutePosition.X) / holder.AbsoluteSize.X, 0, 1)
									optionapi:SetValue(
										name == 'Custom color' and value or nil,
										name == 'Saturation' and value or nil,
										name == 'Vibrance' and value or nil,
										name == 'Opacity' and value or nil
									)
								end
							end)

							local ended
							ended = inputObj.Changed:Connect(function()
								if inputObj.UserInputState == Enum.UserInputState.End then
									if changed then
										changed:Disconnect()
									end
									if ended then
										ended:Disconnect()
									end
								end
							end)
						end
					end)
					slider.MouseEnter:Connect(function()
						tween:Tween(knob, uipallet.Tween, {
							Size = UDim2.fromOffset(16, 16)
						})
					end)
					slider.MouseLeave:Connect(function()
						tween:Tween(knob, uipallet.Tween, {
							Size = UDim2.fromOffset(14, 14)
						})
					end)

					return slider
				end

				local slider = Instance.new('TextButton')
				slider.Name = optionsettings.Name..'Slider'
				slider.Size = UDim2.fromOffset(220, 50)
				slider.BackgroundTransparency = 1
				slider.AutoButtonColor = false
				slider.Text = ''
				slider.Parent = settingschildren
				local title = Instance.new('TextLabel')
				title.Name = 'Title'
				title.Size = UDim2.fromOffset(60, 30)
				title.Position = UDim2.fromOffset(10, 2)
				title.BackgroundTransparency = 1
				title.Text = optionsettings.Name
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.TextColor3 = color.Dark(uipallet.Text, 0.16)
				title.TextSize = 11
				title.FontFace = uipallet.Font
				title.Parent = slider
				local holder = Instance.new('Frame')
				holder.Name = 'Slider'
				holder.Size = UDim2.fromOffset(200, 2)
				holder.Position = UDim2.fromOffset(10, 37)
				holder.BackgroundTransparency = 1
				holder.BorderSizePixel = 0
				holder.Parent = slider
				local colornum = 0
				for i, color in slidercolors do
					local colorframe = Instance.new('Frame')
					colorframe.Size = UDim2.fromOffset(27 + (((i + 1) % 2) == 0 and 1 or 0), 2)
					colorframe.Position = UDim2.fromOffset(colornum, 0)
					colorframe.BackgroundColor3 = color
					colorframe.BorderSizePixel = 0
					colorframe.Parent = holder
					colornum += (colorframe.Size.X.Offset + 1)
				end
				local preview = Instance.new('ImageButton')
				preview.Name = 'Preview'
				preview.Size = UDim2.fromOffset(12, 12)
				preview.Position = UDim2.new(1, -22, 0, 10)
				preview.BackgroundTransparency = 1
				preview.Image = 'rbxassetid://14368311578'
				preview.ImageColor3 = Color3.fromHSV(optionapi.Hue, 1, 1)
				preview.Parent = slider
				local valuebox = Instance.new('TextBox')
				valuebox.Name = 'Box'
				valuebox.Size = UDim2.fromOffset(60, 15)
				valuebox.Position = UDim2.new(1, -69, 0, 9)
				valuebox.BackgroundTransparency = 1
				valuebox.Visible = false
				valuebox.Text = ''
				valuebox.TextXAlignment = Enum.TextXAlignment.Right
				valuebox.TextColor3 = color.Dark(uipallet.Text, 0.16)
				valuebox.TextSize = 11
				valuebox.FontFace = uipallet.Font
				valuebox.ClearTextOnFocus = true
				valuebox.Parent = slider
				local expandbutton = Instance.new('TextButton')
				expandbutton.Name = 'Expand'
				expandbutton.Size = UDim2.fromOffset(17, 13)
				expandbutton.Position = UDim2.new(0, getfontsize(title.Text, title.TextSize, title.Font).X + 11, 0, 7)
				expandbutton.BackgroundTransparency = 1
				expandbutton.Text = ''
				expandbutton.Parent = slider
				local expandicon = Instance.new('ImageLabel')
				expandicon.Name = 'Expand'
				expandicon.Size = UDim2.fromOffset(9, 5)
				expandicon.Position = UDim2.fromOffset(4, 4)
				expandicon.BackgroundTransparency = 1
				expandicon.Image = 'rbxassetid://14368353032'
				expandicon.ImageColor3 = color.Dark(uipallet.Text, 0.43)
				expandicon.Parent = expandbutton
				local rainbow = Instance.new('TextButton')
				rainbow.Name = 'Rainbow'
				rainbow.Size = UDim2.fromOffset(12, 12)
				rainbow.Position = UDim2.new(1, -42, 0, 10)
				rainbow.BackgroundTransparency = 1
				rainbow.Text = ''
				rainbow.Parent = slider
				local rainbow1 = Instance.new('ImageLabel')
				rainbow1.Size = UDim2.fromOffset(12, 12)
				rainbow1.BackgroundTransparency = 1
				rainbow1.Image = 'rbxassetid://14368344374'
				rainbow1.ImageColor3 = color.Light(uipallet.Main, 0.37)
				rainbow1.Parent = rainbow
				local rainbow2 = rainbow1:Clone()
				rainbow2.Image = 'rbxassetid://14368345149'
				rainbow2.Parent = rainbow
				local rainbow3 = rainbow1:Clone()
				rainbow3.Image = 'rbxassetid://14368345840'
				rainbow3.Parent = rainbow
				local rainbow4 = rainbow1:Clone()
				rainbow4.Image = 'rbxassetid://14368346696'
				rainbow4.Parent = rainbow
				local knob = Instance.new('ImageLabel')
				knob.Name = 'Knob'
				knob.Size = UDim2.fromOffset(26, 12)
				knob.Position = UDim2.fromOffset(slidercolorpos[4] - 3, -5)
				knob.BackgroundTransparency = 1
				knob.Image = 'rbxassetid://14368320020'
				knob.ImageColor3 = slidercolors[4]
				knob.Parent = holder
				optionsettings.Function = optionsettings.Function or function() end
				local rainbowTable = {}
				for i = 0, 1, 0.1 do
					table.insert(rainbowTable, ColorSequenceKeypoint.new(i, Color3.fromHSV(i, 1, 1)))
				end
				local colorSlider = createSlider('Custom color', ColorSequence.new(rainbowTable))
				local satSlider = createSlider('Saturation', ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, optionapi.Value)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(optionapi.Hue, 1, optionapi.Value))
				}))
				local vibSlider = createSlider('Vibrance', ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, 0)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(optionapi.Hue, optionapi.Sat, 1))
				}))
				local normalknob = 'rbxassetid://14368320020'
				local rainbowknob = 'rbxassetid://14368321228'
				local rainbowthread

				function optionapi:Save(tab)
					tab[optionsettings.Name] = {
						Hue = self.Hue,
						Sat = self.Sat,
						Value = self.Value,
						Notch = self.Notch,
						CustomColor = self.CustomColor,
						Rainbow = self.Rainbow
					}
				end

				function optionapi:Load(tab)
					if tab.Rainbow then
						self:Toggle()
					end
					if self.Rainbow or tab.CustomColor then
						self:SetValue(tab.Hue, tab.Sat, tab.Value)
					else
						self:SetValue(nil, nil, nil, tab.Notch)
					end
				end

				function optionapi:SetValue(h, s, v, n)
					if n then
						if self.Rainbow then
							self:Toggle()
						end
						self.CustomColor = false
						h, s, v = slidercolors[n]:ToHSV()
					else
						self.CustomColor = true
					end

					self.Hue = h or self.Hue
					self.Sat = s or self.Sat
					self.Value = v or self.Value
					self.Notch = n
					preview.ImageColor3 = Color3.fromHSV(self.Hue, self.Sat, self.Value)
					satSlider.Slider.UIGradient.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, self.Value)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(self.Hue, 1, self.Value))
					})
					vibSlider.Slider.UIGradient.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, 0)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(self.Hue, self.Sat, 1))
					})

					if self.Rainbow or self.CustomColor then
						knob.Image = rainbowknob
						knob.ImageColor3 = Color3.new(1, 1, 1)
						tween:Tween(knob, uipallet.Tween, {
							Position = UDim2.fromOffset(slidercolorpos[4] - 3, -5)
						})
					else
						knob.Image = normalknob
						knob.ImageColor3 = Color3.fromHSV(self.Hue, self.Sat, self.Value)
						tween:Tween(knob, uipallet.Tween, {
							Position = UDim2.fromOffset(slidercolorpos[n or 4] - 3, -5)
						})
					end

					if self.Rainbow then
						if h then
							colorSlider.Slider.Fill.Size = UDim2.fromScale(math.clamp(self.Hue, 0.04, 0.96), 1)
						end
						if s then
							satSlider.Slider.Fill.Size = UDim2.fromScale(math.clamp(self.Sat, 0.04, 0.96), 1)
						end
						if v then
							vibSlider.Slider.Fill.Size = UDim2.fromScale(math.clamp(self.Value, 0.04, 0.96), 1)
						end
					else
						if h then
							tween:Tween(colorSlider.Slider.Fill, uipallet.Tween, {
								Size = UDim2.fromScale(math.clamp(self.Hue, 0.04, 0.96), 1)
							})
						end
						if s then
							tween:Tween(satSlider.Slider.Fill, uipallet.Tween, {
								Size = UDim2.fromScale(math.clamp(self.Sat, 0.04, 0.96), 1)
							})
						end
						if v then
							tween:Tween(vibSlider.Slider.Fill, uipallet.Tween, {
								Size = UDim2.fromScale(math.clamp(self.Value, 0.04, 0.96), 1)
							})
						end
					end
					optionsettings.Function(self.Hue, self.Sat, self.Value)
				end

				function optionapi:Toggle()
					self.Rainbow = not self.Rainbow
					if rainbowthread then
						task.cancel(rainbowthread)
					end

					if self.Rainbow then
						knob.Image = rainbowknob
						table.insert(mainapi.RainbowTable, self)

						rainbow1.ImageColor3 = Color3.fromRGB(5, 127, 100)
						rainbowthread = task.delay(0.1, function()
							rainbow2.ImageColor3 = Color3.fromRGB(228, 125, 43)
							rainbowthread = task.delay(0.1, function()
								rainbow3.ImageColor3 = Color3.fromRGB(225, 46, 52)
								rainbowthread = nil
							end)
						end)
					else
						self:SetValue(nil, nil, nil, 4)
						knob.Image = normalknob
						local ind = table.find(mainapi.RainbowTable, self)
						if ind then
							table.remove(mainapi.RainbowTable, ind)
						end

						rainbow3.ImageColor3 = color.Light(uipallet.Main, 0.37)
						rainbowthread = task.delay(0.1, function()
							rainbow2.ImageColor3 = color.Light(uipallet.Main, 0.37)
							rainbowthread = task.delay(0.1, function()
								rainbow1.ImageColor3 = color.Light(uipallet.Main, 0.37)
							end)
						end)
					end
				end

				expandbutton.MouseEnter:Connect(function()
					expandicon.ImageColor3 = color.Dark(uipallet.Text, 0.16)
				end)
				expandbutton.MouseLeave:Connect(function()
					expandicon.ImageColor3 = color.Dark(uipallet.Text, 0.43)
				end)
				expandbutton.MouseButton1Click:Connect(function()
					colorSlider.Visible = not colorSlider.Visible
					satSlider.Visible = colorSlider.Visible
					vibSlider.Visible = satSlider.Visible
					expandicon.Rotation = satSlider.Visible and 180 or 0
				end)
				preview.MouseButton1Click:Connect(function()
					preview.Visible = false
					valuebox.Visible = true
					valuebox:CaptureFocus()
					local text = Color3.fromHSV(optionapi.Hue, optionapi.Sat, optionapi.Value)
					valuebox.Text = math.round(text.R * 255)..', '..math.round(text.G * 255)..', '..math.round(text.B * 255)
				end)
				slider.InputBegan:Connect(function(inputObj)
					if
						(inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch)
						and (inputObj.Position.Y - slider.AbsolutePosition.Y) > (20 * scale.Scale)
					then
						local changed = inputService.InputChanged:Connect(function(input)
							if input.UserInputType == (inputObj.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
								optionapi:SetValue(nil, nil, nil, math.clamp(math.round((input.Position.X - holder.AbsolutePosition.X) / scale.Scale / 27), 1, 7))
							end
						end)

						local ended
						ended = inputObj.Changed:Connect(function()
							if inputObj.UserInputState == Enum.UserInputState.End then
								if changed then
									changed:Disconnect()
								end
								if ended then
									ended:Disconnect()
								end
							end
						end)
						optionapi:SetValue(nil, nil, nil, math.clamp(math.round((inputObj.Position.X - holder.AbsolutePosition.X) / scale.Scale / 27), 1, 7))
					end
				end)
				rainbow.MouseButton1Click:Connect(function()
					optionapi:Toggle()
				end)
				valuebox.FocusLost:Connect(function(enter)
					preview.Visible = true
					valuebox.Visible = false
					if enter then
						local commas = valuebox.Text:split(',')
						local suc, res = pcall(function()
							return tonumber(commas[1]) and Color3.fromRGB(
								tonumber(commas[1]),
								tonumber(commas[2]),
								tonumber(commas[3])
							) or Color3.fromHex(valuebox.Text)
						end)

						if suc then
							if optionapi.Rainbow then
								optionapi:Toggle()
							end
							optionapi:SetValue(res:ToHSV())
						end
					end
				end)

				optionapi.Object = slider
				categoryapi.Options[optionsettings.Name] = optionapi

				return optionapi
			end

			back.MouseEnter:Connect(function()
				back.ImageColor3 = uipallet.Text
			end)
			back.MouseLeave:Connect(function()
				back.ImageColor3 = color.Light(uipallet.Main, 0.37)
			end)
			back.MouseButton1Click:Connect(function()
				settingspane.Visible = false
			end)
			close.MouseButton1Click:Connect(function()
				settingspane.Visible = false
			end)
			settingsbutton.MouseEnter:Connect(function()
				settingsicon.ImageColor3 = uipallet.Text
			end)
			settingsbutton.MouseLeave:Connect(function()
				settingsicon.ImageColor3 = color.Light(uipallet.Main, 0.37)
			end)
			settingsbutton.MouseButton1Click:Connect(function()
				settingspane.Visible = true
			end)
			windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
				if self.ThreadFix then
					setthreadidentity(8)
				end
				window.Size = UDim2.fromOffset(220, 42 + windowlist.AbsoluteContentSize.Y / scale.Scale)
				for _, v in categoryapi.Buttons do
					if v.Icon then
						v.Object.Text = string.rep(' ', 36 * scale.Scale)..v.Name
					end
				end
			end)

			self.Categories.Main = categoryapi

			return categoryapi
		end

		function mainapi:CreateCategory(categorysettings)
			local categoryapi = {
				Type = 'Category',
				Expanded = false
			}

			local window = Instance.new('TextButton')
			window.Name = categorysettings.Name..'Category'
			window.Size = UDim2.fromOffset(220, 41)
			window.Position = UDim2.fromOffset(236, 60)
			window.BackgroundColor3 = uipallet.Main
			window.AutoButtonColor = false
			window.Visible = false
			window.Text = ''
			window.Parent = clickgui
			addBlur(window)
			addCorner(window)
			makeDraggable(window)
			local icon = Instance.new('ImageLabel')
			icon.Name = 'Icon'
			icon.Size = categorysettings.Size
			icon.Position = UDim2.fromOffset(12, (icon.Size.X.Offset > 20 and 14 or 13))
			icon.BackgroundTransparency = 1
			icon.Image = categorysettings.Icon
			icon.ImageColor3 = uipallet.Text
			icon.Parent = window
			local title = Instance.new('TextLabel')
			title.Name = 'Title'
			title.Size = UDim2.new(1, -(categorysettings.Size.X.Offset > 18 and 40 or 33), 0, 41)
			title.Position = UDim2.fromOffset(math.abs(title.Size.X.Offset), 0)
			title.BackgroundTransparency = 1
			title.Text = categorysettings.Name
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.TextColor3 = uipallet.Text
			title.TextSize = 13
			title.FontFace = uipallet.Font
			title.Parent = window
			local arrowbutton = Instance.new('TextButton')
			arrowbutton.Name = 'Arrow'
			arrowbutton.Size = UDim2.fromOffset(40, 40)
			arrowbutton.Position = UDim2.new(1, -40, 0, 0)
			arrowbutton.BackgroundTransparency = 1
			arrowbutton.Text = ''
			arrowbutton.Parent = window
			local arrow = Instance.new('ImageLabel')
			arrow.Name = 'Arrow'
			arrow.Size = UDim2.fromOffset(9, 4)
			arrow.Position = UDim2.fromOffset(20, 18)
			arrow.BackgroundTransparency = 1
			arrow.Image = 'rbxassetid://14368317595'
			arrow.ImageColor3 = Color3.fromRGB(140, 140, 140)
			arrow.Rotation = 180
			arrow.Parent = arrowbutton
			local children = Instance.new('ScrollingFrame')
			children.Name = 'Children'
			children.Size = UDim2.new(1, 0, 1, -41)
			children.Position = UDim2.fromOffset(0, 37)
			children.BackgroundTransparency = 1
			children.BorderSizePixel = 0
			children.Visible = false
			children.ScrollBarThickness = 2
			children.ScrollBarImageTransparency = 0.75
			children.CanvasSize = UDim2.new()
			children.Parent = window
			local divider = Instance.new('Frame')
			divider.Name = 'Divider'
			divider.Size = UDim2.new(1, 0, 0, 1)
			divider.Position = UDim2.fromOffset(0, 37)
			divider.BackgroundColor3 = Color3.new(1, 1, 1)
			divider.BackgroundTransparency = 0.928
			divider.BorderSizePixel = 0
			divider.Visible = false
			divider.Parent = window
			local windowlist = Instance.new('UIListLayout')
			windowlist.SortOrder = Enum.SortOrder.LayoutOrder
			windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
			windowlist.Parent = children

			function categoryapi:CreateModule(modulesettings)
				mainapi:Remove(modulesettings.Name)
				local moduleapi = {
					Enabled = false,
					Options = {},
					Bind = {},
					Index = getTableSize(mainapi.Modules),
					ExtraText = modulesettings.ExtraText,
					Name = modulesettings.Name,
					Category = categorysettings.Name
				}

				local hovered = false
				local modulebutton = Instance.new('TextButton')
				modulebutton.Name = modulesettings.Name
				modulebutton.Size = UDim2.fromOffset(220, 40)
				modulebutton.BackgroundColor3 = uipallet.Main
				modulebutton.BorderSizePixel = 0
				modulebutton.AutoButtonColor = false
				modulebutton.Text = '            '..modulesettings.Name
				modulebutton.TextXAlignment = Enum.TextXAlignment.Left
				modulebutton.TextColor3 = color.Dark(uipallet.Text, 0.16)
				modulebutton.TextSize = 14
				modulebutton.FontFace = uipallet.Font
				modulebutton.Parent = children
				local gradient = Instance.new('UIGradient')
				gradient.Rotation = 90
				gradient.Enabled = false
				gradient.Parent = modulebutton
				local modulechildren = Instance.new('Frame')
				local bind = Instance.new('TextButton')
				addTooltip(modulebutton, modulesettings.Tooltip)
				addTooltip(bind, 'Click to bind')
				bind.Name = 'Bind'
				bind.Size = UDim2.fromOffset(20, 21)
				bind.Position = UDim2.new(1, -36, 0, 9)
				bind.AnchorPoint = Vector2.new(1, 0)
				bind.BackgroundColor3 = Color3.new(1, 1, 1)
				bind.BackgroundTransparency = 0.92
				bind.BorderSizePixel = 0
				bind.AutoButtonColor = false
				bind.Visible = false
				bind.Text = ''
				addCorner(bind, UDim.new(0, 4))
				local bindicon = Instance.new('ImageLabel')
				bindicon.Name = 'Icon'
				bindicon.Size = UDim2.fromOffset(12, 12)
				bindicon.Position = UDim2.new(0.5, -6, 0, 5)
				bindicon.BackgroundTransparency = 1
				bindicon.Image = 'rbxassetid://14368304734'
				bindicon.ImageColor3 = color.Dark(uipallet.Text, 0.43)
				bindicon.Parent = bind
				local bindtext = Instance.new('TextLabel')
				bindtext.Size = UDim2.fromScale(1, 1)
				bindtext.Position = UDim2.fromOffset(0, 1)
				bindtext.BackgroundTransparency = 1
				bindtext.Visible = false
				bindtext.Text = ''
				bindtext.TextColor3 = color.Dark(uipallet.Text, 0.43)
				bindtext.TextSize = 12
				bindtext.FontFace = uipallet.Font
				bindtext.Parent = bind
				local bindcover = Instance.new('ImageLabel')
				bindcover.Name = 'Cover'
				bindcover.Size = UDim2.fromOffset(154, 40)
				bindcover.BackgroundTransparency = 1
				bindcover.Visible = false
				bindcover.Image = 'rbxassetid://14368305655'
				bindcover.ScaleType = Enum.ScaleType.Slice
				bindcover.SliceCenter = Rect.new(0, 0, 141, 40)
				bindcover.Parent = modulebutton
				local bindcovertext = Instance.new('TextLabel')
				bindcovertext.Name = 'Text'
				bindcovertext.Size = UDim2.new(1, -10, 1, -3)
				bindcovertext.BackgroundTransparency = 1
				bindcovertext.Text = 'PRESS A KEY TO BIND'
				bindcovertext.TextColor3 = uipallet.Text
				bindcovertext.TextSize = 11
				bindcovertext.FontFace = uipallet.Font
				bindcovertext.Parent = bindcover
				bind.Parent = modulebutton
				local dotsbutton = Instance.new('TextButton')
				dotsbutton.Name = 'Dots'
				dotsbutton.Size = UDim2.fromOffset(25, 40)
				dotsbutton.Position = UDim2.new(1, -25, 0, 0)
				dotsbutton.BackgroundTransparency = 1
				dotsbutton.Text = ''
				dotsbutton.Parent = modulebutton
				local dots = Instance.new('ImageLabel')
				dots.Name = 'Dots'
				dots.Size = UDim2.fromOffset(3, 16)
				dots.Position = UDim2.fromOffset(4, 12)
				dots.BackgroundTransparency = 1
				dots.Image = 'rbxassetid://14368314459'
				dots.ImageColor3 = color.Light(uipallet.Main, 0.37)
				dots.Parent = dotsbutton
				modulechildren.Name = modulesettings.Name..'Children'
				modulechildren.Size = UDim2.new(1, 0, 0, 0)
				modulechildren.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
				modulechildren.BorderSizePixel = 0
				modulechildren.Visible = false
				modulechildren.Parent = children
				moduleapi.Children = modulechildren
				local windowlist = Instance.new('UIListLayout')
				windowlist.SortOrder = Enum.SortOrder.LayoutOrder
				windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
				windowlist.Parent = modulechildren
				local divider = Instance.new('Frame')
				divider.Name = 'Divider'
				divider.Size = UDim2.new(1, 0, 0, 1)
				divider.Position = UDim2.new(0, 0, 1, -1)
				divider.BackgroundColor3 = Color3.new(0.19, 0.19, 0.19)
				divider.BackgroundTransparency = 0.52
				divider.BorderSizePixel = 0
				divider.Visible = false
				divider.Parent = modulebutton
				modulesettings.Function = modulesettings.Function or function() end
				addMaid(moduleapi)

				function moduleapi:SetBind(tab, mouse)
					if tab.Mobile then
						createMobileButton(moduleapi, Vector2.new(tab.X, tab.Y))
						return
					end

					self.Bind = table.clone(tab)
					if mouse then
						bindcovertext.Text = #tab <= 0 and 'BIND REMOVED' or 'BOUND TO'
						bindcover.Size = UDim2.fromOffset(getfontsize(bindcovertext.Text, bindcovertext.TextSize).X + 20, 40)
						task.delay(1, function()
							bindcover.Visible = false
						end)
					end

					if #tab <= 0 then
						bindtext.Visible = false
						bindicon.Visible = true
						bind.Size = UDim2.fromOffset(20, 21)
					else
						bind.Visible = true
						bindtext.Visible = true
						bindicon.Visible = false
						bindtext.Text = table.concat(tab, ' + '):upper()
						bind.Size = UDim2.fromOffset(math.max(getfontsize(bindtext.Text, bindtext.TextSize, bindtext.Font).X + 10, 20), 21)
					end
				end

				function moduleapi:Toggle(multiple)
					if mainapi.ThreadFix then
						setthreadidentity(8)
					end
					self.Enabled = not self.Enabled
					divider.Visible = self.Enabled
					gradient.Enabled = self.Enabled
					modulebutton.TextColor3 = (hovered or modulechildren.Visible) and uipallet.Text or color.Dark(uipallet.Text, 0.16)
					modulebutton.BackgroundColor3 = (hovered or modulechildren.Visible) and color.Light(uipallet.Main, 0.02) or uipallet.Main
					dots.ImageColor3 = self.Enabled and Color3.fromRGB(50, 50, 50) or color.Light(uipallet.Main, 0.37)
					bindicon.ImageColor3 = color.Dark(uipallet.Text, 0.43)
					bindtext.TextColor3 = color.Dark(uipallet.Text, 0.43)
					if not self.Enabled then
						for _, v in self.Connections do
							v:Disconnect()
						end
						table.clear(self.Connections)
					end
					if not multiple then
						mainapi:UpdateTextGUI()
					end
					task.spawn(modulesettings.Function, self.Enabled)
				end

				for i, v in components do
					moduleapi['Create'..i] = function(_, optionsettings)
						return v(optionsettings, modulechildren, moduleapi)
					end
				end

				bind.MouseEnter:Connect(function()
					bindtext.Visible = false
					bindicon.Visible = not bindtext.Visible
					bindicon.Image = 'rbxassetid://14368315443'
					if not moduleapi.Enabled then bindicon.ImageColor3 = color.Dark(uipallet.Text, 0.16) end
				end)
				bind.MouseLeave:Connect(function()
					bindtext.Visible = #moduleapi.Bind > 0
					bindicon.Visible = not bindtext.Visible
					bindicon.Image = 'rbxassetid://14368304734'
					if not moduleapi.Enabled then
						bindicon.ImageColor3 = color.Dark(uipallet.Text, 0.43)
					end
				end)
				bind.MouseButton1Click:Connect(function()
					bindcovertext.Text = 'PRESS A KEY TO BIND'
					bindcover.Size = UDim2.fromOffset(getfontsize(bindcovertext.Text, bindcovertext.TextSize).X + 20, 40)
					bindcover.Visible = true
					mainapi.Binding = moduleapi
				end)
				dotsbutton.MouseEnter:Connect(function()
					if not moduleapi.Enabled then
						dots.ImageColor3 = uipallet.Text
					end
				end)
				dotsbutton.MouseLeave:Connect(function()
					if not moduleapi.Enabled then
						dots.ImageColor3 = color.Light(uipallet.Main, 0.37)
					end
				end)
				dotsbutton.MouseButton1Click:Connect(function()
					modulechildren.Visible = not modulechildren.Visible
				end)
				dotsbutton.MouseButton2Click:Connect(function()
					modulechildren.Visible = not modulechildren.Visible
				end)
				modulebutton.MouseEnter:Connect(function()
					hovered = true
					if not moduleapi.Enabled and not modulechildren.Visible then
						modulebutton.TextColor3 = uipallet.Text
						modulebutton.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
					end
					bind.Visible = #moduleapi.Bind > 0 or hovered or modulechildren.Visible
				end)
				modulebutton.MouseLeave:Connect(function()
					hovered = false
					if not moduleapi.Enabled and not modulechildren.Visible then
						modulebutton.TextColor3 = color.Dark(uipallet.Text, 0.16)
						modulebutton.BackgroundColor3 = uipallet.Main
					end
					bind.Visible = #moduleapi.Bind > 0 or hovered or modulechildren.Visible
				end)
				modulebutton.MouseButton1Click:Connect(function()
					moduleapi:Toggle()
				end)
				modulebutton.MouseButton2Click:Connect(function()
					modulechildren.Visible = not modulechildren.Visible
				end)
				if inputService.TouchEnabled then
					local heldbutton = false
					modulebutton.MouseButton1Down:Connect(function()
						heldbutton = true
						local holdtime, holdpos = tick(), inputService:GetMouseLocation()
						repeat
							heldbutton = (inputService:GetMouseLocation() - holdpos).Magnitude < 3
							task.wait()
						until (tick() - holdtime) > 1 or not heldbutton or not clickgui.Visible
						if heldbutton and clickgui.Visible then
							if mainapi.ThreadFix then
								setthreadidentity(8)
							end
							clickgui.Visible = false
							tooltip.Visible = false
							mainapi:BlurCheck()
							for _, mobileButton in mainapi.Modules do
								if mobileButton.Bind.Button then
									mobileButton.Bind.Button.Visible = true
								end
							end

							local touchconnection
							touchconnection = inputService.InputBegan:Connect(function(inputType)
								if inputType.UserInputType == Enum.UserInputType.Touch then
									if mainapi.ThreadFix then
										setthreadidentity(8)
									end
									createMobileButton(moduleapi, inputType.Position + Vector3.new(0, guiService:GetGuiInset().Y, 0))
									clickgui.Visible = true
									mainapi:BlurCheck()
									for _, mobileButton in mainapi.Modules do
										if mobileButton.Bind.Button then
											mobileButton.Bind.Button.Visible = false
										end
									end
									touchconnection:Disconnect()
								end
							end)
						end
					end)
					modulebutton.MouseButton1Up:Connect(function()
						heldbutton = false
					end)
				end
				windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
					if mainapi.ThreadFix then
						setthreadidentity(8)
					end
					modulechildren.Size = UDim2.new(1, 0, 0, windowlist.AbsoluteContentSize.Y / scale.Scale)
				end)

				moduleapi.Object = modulebutton
				mainapi.Modules[modulesettings.Name] = moduleapi

				local sorting = {}
				for _, v in mainapi.Modules do
					sorting[v.Category] = sorting[v.Category] or {}
					table.insert(sorting[v.Category], v.Name)
				end

				for _, sort in sorting do
					table.sort(sort)
					for i, v in sort do
						mainapi.Modules[v].Index = i
						mainapi.Modules[v].Object.LayoutOrder = i
						mainapi.Modules[v].Children.LayoutOrder = i
					end
				end

				return moduleapi
			end

			function categoryapi:Expand()
				self.Expanded = not self.Expanded
				children.Visible = self.Expanded
				arrow.Rotation = self.Expanded and 0 or 180
				window.Size = UDim2.fromOffset(220, self.Expanded and math.min(41 + windowlist.AbsoluteContentSize.Y / scale.Scale, 601) or 41)
				divider.Visible = children.CanvasPosition.Y > 10 and children.Visible
			end

			arrowbutton.MouseButton1Click:Connect(function()
				categoryapi:Expand()
			end)
			arrowbutton.MouseButton2Click:Connect(function()
				categoryapi:Expand()
			end)
			arrowbutton.MouseEnter:Connect(function()
				arrow.ImageColor3 = Color3.fromRGB(220, 220, 220)
			end)
			arrowbutton.MouseLeave:Connect(function()
				arrow.ImageColor3 = Color3.fromRGB(140, 140, 140)
			end)
			children:GetPropertyChangedSignal('CanvasPosition'):Connect(function()
				if self.ThreadFix then
					setthreadidentity(8)
				end
				divider.Visible = children.CanvasPosition.Y > 10 and children.Visible
			end)
			window.InputBegan:Connect(function(inputObj)
				if inputObj.Position.Y < window.AbsolutePosition.Y + 41 and inputObj.UserInputType == Enum.UserInputType.MouseButton2 then
					categoryapi:Expand()
				end
			end)
			windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
				if self.ThreadFix then
					setthreadidentity(8)
				end
				children.CanvasSize = UDim2.fromOffset(0, windowlist.AbsoluteContentSize.Y / scale.Scale)
				if categoryapi.Expanded then
					window.Size = UDim2.fromOffset(220, math.min(41 + windowlist.AbsoluteContentSize.Y / scale.Scale, 601))
				end
			end)

			categoryapi.Button = self.Categories.Main:CreateButton({
				Name = categorysettings.Name,
				Icon = categorysettings.Icon,
				Size = categorysettings.Size,
				Window = window
			})

			categoryapi.Object = window
			self.Categories[categorysettings.Name] = categoryapi

			return categoryapi
		end

		function mainapi:CreateOverlay(categorysettings)
			local window
			local categoryapi
			categoryapi = {
				Type = 'Overlay',
				Expanded = false,
				Button = self.Overlays:CreateToggle({
					Name = categorysettings.Name,
					Function = function(callback)
						window.Visible = callback and (clickgui.Visible or categoryapi.Pinned)
						if not callback then
							for _, v in categoryapi.Connections do
								v:Disconnect()
							end
							table.clear(categoryapi.Connections)
						end

						if categorysettings.Function then
							task.spawn(categorysettings.Function, callback)
						end
					end,
					Icon = categorysettings.Icon,
					Size = categorysettings.Size,
					Position = categorysettings.Position
				}),
				Pinned = false,
				Options = {}
			}

			window = Instance.new('TextButton')
			window.Name = categorysettings.Name..'Overlay'
			window.Size = UDim2.fromOffset(categorysettings.CategorySize or 220, 41)
			window.Position = UDim2.fromOffset(240, 46)
			window.BackgroundColor3 = uipallet.Main
			window.AutoButtonColor = false
			window.Visible = false
			window.Text = ''
			window.Parent = scaledgui
			local blur = addBlur(window)
			addCorner(window)
			makeDraggable(window)
			local icon = Instance.new('ImageLabel')
			icon.Name = 'Icon'
			icon.Size = categorysettings.Size
			icon.Position = UDim2.fromOffset(12, (icon.Size.X.Offset > 14 and 14 or 13))
			icon.BackgroundTransparency = 1
			icon.Image = categorysettings.Icon
			icon.ImageColor3 = uipallet.Text
			icon.Parent = window
			local title = Instance.new('TextLabel')
			title.Name = 'Title'
			title.Size = UDim2.new(1, -32, 0, 41)
			title.Position = UDim2.fromOffset(math.abs(title.Size.X.Offset), 0)
			title.BackgroundTransparency = 1
			title.Text = categorysettings.Name
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.TextColor3 = uipallet.Text
			title.TextSize = 13
			title.FontFace = uipallet.Font
			title.Parent = window
			local pin = Instance.new('ImageButton')
			pin.Name = 'Pin'
			pin.Size = UDim2.fromOffset(16, 16)
			pin.Position = UDim2.new(1, -47, 0, 12)
			pin.BackgroundTransparency = 1
			pin.AutoButtonColor = false
			pin.Image = 'rbxassetid://14368342301'
			pin.ImageColor3 = color.Dark(uipallet.Text, 0.43)
			pin.Parent = window
			local dotsbutton = Instance.new('TextButton')
			dotsbutton.Name = 'Dots'
			dotsbutton.Size = UDim2.fromOffset(17, 40)
			dotsbutton.Position = UDim2.new(1, -17, 0, 0)
			dotsbutton.BackgroundTransparency = 1
			dotsbutton.Text = ''
			dotsbutton.Parent = window
			local dots = Instance.new('ImageLabel')
			dots.Name = 'Dots'
			dots.Size = UDim2.fromOffset(3, 16)
			dots.Position = UDim2.fromOffset(4, 12)
			dots.BackgroundTransparency = 1
			dots.Image = 'rbxassetid://14368314459'
			dots.ImageColor3 = color.Light(uipallet.Main, 0.37)
			dots.Parent = dotsbutton
			local customchildren = Instance.new('Frame')
			customchildren.Name = 'CustomChildren'
			customchildren.Size = UDim2.new(1, 0, 0, 200)
			customchildren.Position = UDim2.fromScale(0, 1)
			customchildren.BackgroundTransparency = 1
			customchildren.Parent = window
			local children = Instance.new('ScrollingFrame')
			children.Name = 'Children'
			children.Size = UDim2.new(1, 0, 1, -41)
			children.Position = UDim2.fromOffset(0, 37)
			children.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
			children.BorderSizePixel = 0
			children.Visible = false
			children.ScrollBarThickness = 2
			children.ScrollBarImageTransparency = 0.75
			children.CanvasSize = UDim2.new()
			children.Parent = window
			local windowlist = Instance.new('UIListLayout')
			windowlist.SortOrder = Enum.SortOrder.LayoutOrder
			windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
			windowlist.Parent = children
			addMaid(categoryapi)

			function categoryapi:Expand(check)
				if check and not blur.Visible then return end
				self.Expanded = not self.Expanded
				children.Visible = self.Expanded
				dots.ImageColor3 = self.Expanded and uipallet.Text or color.Light(uipallet.Main, 0.37)
				if self.Expanded then
					window.Size = UDim2.fromOffset(window.Size.X.Offset, math.min(41 + windowlist.AbsoluteContentSize.Y / scale.Scale, 601))
				else
					window.Size = UDim2.fromOffset(window.Size.X.Offset, 41)
				end
			end

			function categoryapi:Pin()
				self.Pinned = not self.Pinned
				pin.ImageColor3 = self.Pinned and uipallet.Text or color.Dark(uipallet.Text, 0.43)
			end

			function categoryapi:Update()
				window.Visible = self.Button.Enabled and (clickgui.Visible or self.Pinned)
				if self.Expanded then
					self:Expand()
				end
				if clickgui.Visible then
					window.Size = UDim2.fromOffset(window.Size.X.Offset, 41)
					window.BackgroundTransparency = 0
					blur.Visible = true
					icon.Visible = true
					title.Visible = true
					pin.Visible = true
					dotsbutton.Visible = true
				else
					window.Size = UDim2.fromOffset(window.Size.X.Offset, 0)
					window.BackgroundTransparency = 1
					blur.Visible = false
					icon.Visible = false
					title.Visible = false
					pin.Visible = false
					dotsbutton.Visible = false
				end
			end

			for i, v in components do
				categoryapi['Create'..i] = function(self, optionsettings)
					return v(optionsettings, children, categoryapi)
				end
			end

			dotsbutton.MouseEnter:Connect(function()
				if not children.Visible then
					dots.ImageColor3 = uipallet.Text
				end
			end)
			dotsbutton.MouseLeave:Connect(function()
				if not children.Visible then
					dots.ImageColor3 = color.Light(uipallet.Main, 0.37)
				end
			end)
			dotsbutton.MouseButton1Click:Connect(function()
				categoryapi:Expand(true)
			end)
			dotsbutton.MouseButton2Click:Connect(function()
				categoryapi:Expand(true)
			end)
			pin.MouseButton1Click:Connect(function()
				categoryapi:Pin()
			end)
			window.MouseButton2Click:Connect(function()
				categoryapi:Expand(true)
			end)
			windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
				if self.ThreadFix then
					setthreadidentity(8)
				end
				children.CanvasSize = UDim2.fromOffset(0, windowlist.AbsoluteContentSize.Y / scale.Scale)
				if categoryapi.Expanded then
					window.Size = UDim2.fromOffset(window.Size.X.Offset, math.min(41 + windowlist.AbsoluteContentSize.Y / scale.Scale, 601))
				end
			end)
			self:Clean(clickgui:GetPropertyChangedSignal('Visible'):Connect(function()
				categoryapi:Update()
			end))

			categoryapi:Update()
			categoryapi.Object = window
			categoryapi.Children = customchildren
			self.Categories[categorysettings.Name] = categoryapi

			return categoryapi
		end

		function mainapi:CreateCategoryList(categorysettings)
			local categoryapi = {
				Type = 'CategoryList',
				Expanded = false,
				List = {},
				ListEnabled = {},
				Objects = {},
				Options = {}
			}
			categorysettings.Color = categorysettings.Color or Color3.fromRGB(5, 134, 105)

			local window = Instance.new('TextButton')
			window.Name = categorysettings.Name..'CategoryList'
			window.Size = UDim2.fromOffset(220, 45)
			window.Position = UDim2.fromOffset(240, 46)
			window.BackgroundColor3 = uipallet.Main
			window.AutoButtonColor = false
			window.Visible = false
			window.Text = ''
			window.Parent = clickgui
			addBlur(window)
			addCorner(window)
			makeDraggable(window)
			local icon = Instance.new('ImageLabel')
			icon.Name = 'Icon'
			icon.Size = categorysettings.Size
			icon.Position = categorysettings.Position or UDim2.fromOffset(12, (categorysettings.Size.X.Offset > 20 and 13 or 12))
			icon.BackgroundTransparency = 1
			icon.Image = categorysettings.Icon
			icon.ImageColor3 = uipallet.Text
			icon.Parent = window
			local title = Instance.new('TextLabel')
			title.Name = 'Title'
			title.Size = UDim2.new(1, -(categorysettings.Size.X.Offset > 20 and 44 or 36), 0, 20)
			title.Position = UDim2.fromOffset(math.abs(title.Size.X.Offset), 12)
			title.BackgroundTransparency = 1
			title.Text = categorysettings.Name
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.TextColor3 = uipallet.Text
			title.TextSize = 13
			title.FontFace = uipallet.Font
			title.Parent = window
			local arrowbutton = Instance.new('TextButton')
			arrowbutton.Name = 'Arrow'
			arrowbutton.Size = UDim2.fromOffset(40, 40)
			arrowbutton.Position = UDim2.new(1, -40, 0, 0)
			arrowbutton.BackgroundTransparency = 1
			arrowbutton.Text = ''
			arrowbutton.Parent = window
			local arrow = Instance.new('ImageLabel')
			arrow.Name = 'Arrow'
			arrow.Size = UDim2.fromOffset(9, 4)
			arrow.Position = UDim2.fromOffset(20, 19)
			arrow.BackgroundTransparency = 1
			arrow.Image = 'rbxassetid://14368317595'
			arrow.ImageColor3 = Color3.fromRGB(140, 140, 140)
			arrow.Rotation = 180
			arrow.Parent = arrowbutton
			local children = Instance.new('ScrollingFrame')
			children.Name = 'Children'
			children.Size = UDim2.new(1, 0, 1, -45)
			children.Position = UDim2.fromOffset(0, 45)
			children.BackgroundTransparency = 1
			children.BorderSizePixel = 0
			children.Visible = false
			children.ScrollBarThickness = 2
			children.ScrollBarImageTransparency = 0.75
			children.CanvasSize = UDim2.new()
			children.Parent = window
			local childrentwo = Instance.new('Frame')
			childrentwo.BackgroundTransparency = 1
			childrentwo.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
			childrentwo.Visible = false
			childrentwo.Parent = children
			local settings = Instance.new('ImageButton')
			settings.Name = 'Settings'
			settings.Size = UDim2.fromOffset(16, 16)
			settings.Position = UDim2.new(1, -52, 0, 13)
			settings.BackgroundTransparency = 1
			settings.AutoButtonColor = false
			settings.Image = 'rbxassetid://14403726449'
			settings.ImageColor3 = color.Dark(uipallet.Text, 0.43)
			settings.Parent = window
			local divider = Instance.new('Frame')
			divider.Name = 'Divider'
			divider.Size = UDim2.new(1, 0, 0, 1)
			divider.Position = UDim2.fromOffset(0, 41)
			divider.BorderSizePixel = 0
			divider.Visible = false
			divider.BackgroundColor3 = Color3.new(1, 1, 1)
			divider.BackgroundTransparency = 0.928
			divider.Parent = window
			local windowlist = Instance.new('UIListLayout')
			windowlist.SortOrder = Enum.SortOrder.LayoutOrder
			windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
			windowlist.Padding = UDim.new(0, 3)
			windowlist.Parent = children
			local windowlisttwo = Instance.new('UIListLayout')
			windowlisttwo.SortOrder = Enum.SortOrder.LayoutOrder
			windowlisttwo.HorizontalAlignment = Enum.HorizontalAlignment.Center
			windowlisttwo.Parent = childrentwo
			local addbkg = Instance.new('Frame')
			addbkg.Name = 'Add'
			addbkg.Size = UDim2.fromOffset(200, 31)
			addbkg.Position = UDim2.fromOffset(10, 45)
			addbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
			addbkg.Parent = children
			addCorner(addbkg)
			local addbox = addbkg:Clone()
			addbox.Size = UDim2.new(1, -2, 1, -2)
			addbox.Position = UDim2.fromOffset(1, 1)
			addbox.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
			addbox.Parent = addbkg
			local addvalue = Instance.new('TextBox')
			addvalue.Size = UDim2.new(1, -35, 1, 0)
			addvalue.Position = UDim2.fromOffset(10, 0)
			addvalue.BackgroundTransparency = 1
			addvalue.Text = ''
			addvalue.PlaceholderText = categorysettings.Placeholder or 'Add entry...'
			addvalue.TextXAlignment = Enum.TextXAlignment.Left
			addvalue.TextColor3 = Color3.new(1, 1, 1)
			addvalue.TextSize = 15
			addvalue.FontFace = uipallet.Font
			addvalue.ClearTextOnFocus = false
			addvalue.Parent = addbkg
			local addbutton = Instance.new('ImageButton')
			addbutton.Name = 'AddButton'
			addbutton.Size = UDim2.fromOffset(16, 16)
			addbutton.Position = UDim2.new(1, -26, 0, 8)
			addbutton.BackgroundTransparency = 1
			addbutton.Image = "rbxassetid://14368300605"
			addbutton.ImageColor3 = categorysettings.Color
			addbutton.ImageTransparency = 0.3
			addbutton.Parent = addbkg
			local cursedpadding = Instance.new('Frame')
			cursedpadding.Size = UDim2.fromOffset()
			cursedpadding.BackgroundTransparency = 1
			cursedpadding.Parent = children
			categorysettings.Function = categorysettings.Function or function() end

			function categoryapi:ChangeValue(val)
				if val then
					if categorysettings.Profiles then
						local ind = self:GetValue(val)
						if ind then
							if val ~= 'default' then
								table.remove(mainapi.Profiles, ind)
								if isfile('newlunar/profiles/'..val..mainapi.Place..'.txt') and delfile then
									delfile('newlunar/profiles/'..val..mainapi.Place..'.txt')
								end
							end
						else
							table.insert(mainapi.Profiles, {Name = val, Bind = {}})
						end
					else
						local ind = table.find(self.List, val)
						if ind then
							table.remove(self.List, ind)
							ind = table.find(self.ListEnabled, val)
							if ind then
								table.remove(self.ListEnabled, ind)
							end
						else
							table.insert(self.List, val)
							table.insert(self.ListEnabled, val)
						end
					end
				end

				categorysettings.Function()
				for _, v in self.Objects do
					v:Destroy()
				end
				table.clear(self.Objects)
				self.Selected = nil

				for i, v in (categorysettings.Profiles and mainapi.Profiles or self.List) do
					if categorysettings.Profiles then
						local object = Instance.new('TextButton')
						object.Name = v.Name
						object.Size = UDim2.fromOffset(200, 33)
						object.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
						object.AutoButtonColor = false
						object.Text = ''
						object.Parent = children
						addCorner(object)
						local objectstroke = Instance.new('UIStroke')
						objectstroke.Color = color.Light(uipallet.Main, 0.1)
						objectstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
						objectstroke.Enabled = false
						objectstroke.Parent = object
						local objecttitle = Instance.new('TextLabel')
						objecttitle.Name = 'Title'
						objecttitle.Size = UDim2.new(1, -10, 1, 0)
						objecttitle.Position = UDim2.fromOffset(10, 0)
						objecttitle.BackgroundTransparency = 1
						objecttitle.Text = v.Name
						objecttitle.TextXAlignment = Enum.TextXAlignment.Left
						objecttitle.TextColor3 = color.Dark(uipallet.Text, 0.4)
						objecttitle.TextSize = 15
						objecttitle.FontFace = uipallet.Font
						objecttitle.Parent = object
						local dotsbutton = Instance.new('TextButton')
						dotsbutton.Name = 'Dots'
						dotsbutton.Size = UDim2.fromOffset(25, 33)
						dotsbutton.Position = UDim2.new(1, -25, 0, 0)
						dotsbutton.BackgroundTransparency = 1
						dotsbutton.Text = ''
						dotsbutton.Parent = object
						local dots = Instance.new('ImageLabel')
						dots.Name = 'Dots'
						dots.Size = UDim2.fromOffset(3, 16)
						dots.Position = UDim2.fromOffset(10, 9)
						dots.BackgroundTransparency = 1
						dots.Image = 'rbxassetid://14368314459'
						dots.ImageColor3 = color.Light(uipallet.Main, 0.37)
						dots.Parent = dotsbutton
						local bind = Instance.new('TextButton')
						addTooltip(bind, 'Click to bind')
						bind.Name = 'Bind'
						bind.Size = UDim2.fromOffset(20, 21)
						bind.Position = UDim2.new(1, -30, 0, 6)
						bind.AnchorPoint = Vector2.new(1, 0)
						bind.BackgroundColor3 = Color3.new(1, 1, 1)
						bind.BackgroundTransparency = 0.92
						bind.BorderSizePixel = 0
						bind.AutoButtonColor = false
						bind.Visible = false
						bind.Text = ''
						addCorner(bind, UDim.new(0, 4))
						local bindicon = Instance.new('ImageLabel')
						bindicon.Name = 'Icon'
						bindicon.Size = UDim2.fromOffset(12, 12)
						bindicon.Position = UDim2.new(0.5, -6, 0, 5)
						bindicon.BackgroundTransparency = 1
						bindicon.Image = 'rbxassetid://14368304734'
						bindicon.ImageColor3 = color.Dark(uipallet.Text, 0.43)
						bindicon.Parent = bind
						local bindtext = Instance.new('TextLabel')
						bindtext.Size = UDim2.fromScale(1, 1)
						bindtext.Position = UDim2.fromOffset(0, 1)
						bindtext.BackgroundTransparency = 1
						bindtext.Visible = false
						bindtext.Text = ''
						bindtext.TextColor3 = color.Dark(uipallet.Text, 0.43)
						bindtext.TextSize = 12
						bindtext.FontFace = uipallet.Font
						bindtext.Parent = bind
						bind.MouseEnter:Connect(function()
							bindtext.Visible = false
							bindicon.Visible = not bindtext.Visible
							bindicon.Image = 'rbxassetid://14368315443'
							if v.Name ~= mainapi.Profile then
								bindicon.ImageColor3 = color.Dark(uipallet.Text, 0.16)
							end
						end)
						bind.MouseLeave:Connect(function()
							bindtext.Visible = #v.Bind > 0
							bindicon.Visible = not bindtext.Visible
							bindicon.Image = 'rbxassetid://14368304734'
							if v.Name ~= mainapi.Profile then
								bindicon.ImageColor3 = color.Dark(uipallet.Text, 0.43)
							end
						end)
						local bindcover = Instance.new('ImageLabel')
						bindcover.Name = 'Cover'
						bindcover.Size = UDim2.fromOffset(154, 33)
						bindcover.BackgroundTransparency = 1
						bindcover.Visible = false
						bindcover.Image = 'rbxassetid://14368305655'
						bindcover.ScaleType = Enum.ScaleType.Slice
						bindcover.SliceCenter = Rect.new(0, 0, 141, 40)
						bindcover.Parent = object
						local bindcovertext = Instance.new('TextLabel')
						bindcovertext.Name = 'Text'
						bindcovertext.Size = UDim2.new(1, -10, 1, -3)
						bindcovertext.BackgroundTransparency = 1
						bindcovertext.Text = 'PRESS A KEY TO BIND'
						bindcovertext.TextColor3 = uipallet.Text
						bindcovertext.TextSize = 11
						bindcovertext.FontFace = uipallet.Font
						bindcovertext.Parent = bindcover
						bind.Parent = object
						dotsbutton.MouseEnter:Connect(function()
							if v.Name ~= mainapi.Profile then
								dots.ImageColor3 = uipallet.Text
							end
						end)
						dotsbutton.MouseLeave:Connect(function()
							if v.Name ~= mainapi.Profile then
								dots.ImageColor3 = color.Light(uipallet.Main, 0.37)
							end
						end)
						dotsbutton.MouseButton1Click:Connect(function()
							if v.Name ~= mainapi.Profile then
								categoryapi:ChangeValue(v.Name)
							end
						end)
						object.MouseButton1Click:Connect(function()
							mainapi:Save(v.Name)
							mainapi:Load(true)
						end)
						object.MouseEnter:Connect(function()
							bind.Visible = true
							if v.Name ~= mainapi.Profile then
								objectstroke.Enabled = true
								objecttitle.TextColor3 = color.Dark(uipallet.Text, 0.16)
							end
						end)
						object.MouseLeave:Connect(function()
							bind.Visible = #v.Bind > 0
							if v.Name ~= mainapi.Profile then
								objectstroke.Enabled = false
								objecttitle.TextColor3 = color.Dark(uipallet.Text, 0.4)
							end
						end)

						local function bindFunction(self, tab, mouse)
							v.Bind = table.clone(tab)
							if mouse then
								bindcovertext.Text = #tab <= 0 and 'BIND REMOVED' or 'BOUND TO '..table.concat(tab, ' + '):upper()
								bindcover.Size = UDim2.fromOffset(getfontsize(bindcovertext.Text, bindcovertext.TextSize).X + 20, 40)
								task.delay(1, function()
									bindcover.Visible = false
								end)
							end

							if #tab <= 0 then
								bindtext.Visible = false
								bindicon.Visible = true
								bind.Size = UDim2.fromOffset(20, 21)
							else
								bind.Visible = true
								bindtext.Visible = true
								bindicon.Visible = false
								bindtext.Text = table.concat(tab, ' + '):upper()
								bind.Size = UDim2.fromOffset(math.max(getfontsize(bindtext.Text, bindtext.TextSize, bindtext.Font).X + 10, 20), 21)
							end
						end

						bindFunction({}, v.Bind)
						bind.MouseButton1Click:Connect(function()
							bindcovertext.Text = 'PRESS A KEY TO BIND'
							bindcover.Size = UDim2.fromOffset(getfontsize(bindcovertext.Text, bindcovertext.TextSize).X + 20, 40)
							bindcover.Visible = true
							mainapi.Binding = {SetBind = bindFunction, Bind = v.Bind}
						end)
						if v.Name == mainapi.Profile then
							self.Selected = object
						end
						table.insert(self.Objects, object)
					else
						local enabled = table.find(self.ListEnabled, v)
						local object = Instance.new('TextButton')
						object.Name = v
						object.Size = UDim2.fromOffset(200, 32)
						object.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
						object.AutoButtonColor = false
						object.Text = ''
						object.Parent = children
						addCorner(object)
						local objectbkg = Instance.new('Frame')
						objectbkg.Name = 'BKG'
						objectbkg.Size = UDim2.new(1, -2, 1, -2)
						objectbkg.Position = UDim2.fromOffset(1, 1)
						objectbkg.BackgroundColor3 = uipallet.Main
						objectbkg.Visible = false
						objectbkg.Parent = object
						addCorner(objectbkg)
						local objectdot = Instance.new('Frame')
						objectdot.Name = 'Dot'
						objectdot.Size = UDim2.fromOffset(10, 11)
						objectdot.Position = UDim2.fromOffset(10, 12)
						objectdot.BackgroundColor3 = enabled and categorysettings.Color or color.Light(uipallet.Main, 0.37)
						objectdot.Parent = object
						addCorner(objectdot, UDim.new(1, 0))
						local objectdotin = objectdot:Clone()
						objectdotin.Size = UDim2.fromOffset(8, 9)
						objectdotin.Position = UDim2.fromOffset(1, 1)
						objectdotin.BackgroundColor3 = enabled and categorysettings.Color or color.Light(uipallet.Main, 0.02)
						objectdotin.Parent = objectdot
						local objecttitle = Instance.new('TextLabel')
						objecttitle.Name = 'Title'
						objecttitle.Size = UDim2.new(1, -30, 1, 0)
						objecttitle.Position = UDim2.fromOffset(30, 0)
						objecttitle.BackgroundTransparency = 1
						objecttitle.Text = v
						objecttitle.TextXAlignment = Enum.TextXAlignment.Left
						objecttitle.TextColor3 = color.Dark(uipallet.Text, 0.16)
						objecttitle.TextSize = 15
						objecttitle.FontFace = uipallet.Font
						objecttitle.Parent = object
						if mainapi.ThreadFix then
							setthreadidentity(8)
						end
						local close = Instance.new('ImageButton')
						close.Name = 'Close'
						close.Size = UDim2.fromOffset(16, 16)
						close.Position = UDim2.new(1, -23, 0, 8)
						close.BackgroundColor3 = Color3.new(1, 1, 1)
						close.BackgroundTransparency = 1
						close.AutoButtonColor = false
						close.Image = 'rbxassetid://14368310467'
						close.ImageColor3 = color.Light(uipallet.Text, 0.2)
						close.ImageTransparency = 0.5
						close.Parent = object
						addCorner(close, UDim.new(1, 0))
						close.MouseEnter:Connect(function()
							close.ImageTransparency = 0.3
							tween:Tween(close, uipallet.Tween, {
								BackgroundTransparency = 0.6
							})
						end)
						close.MouseLeave:Connect(function()
							close.ImageTransparency = 0.5
							tween:Tween(close, uipallet.Tween, {
								BackgroundTransparency = 1
							})
						end)
						close.MouseButton1Click:Connect(function()
							categoryapi:ChangeValue(v)
						end)
						object.MouseEnter:Connect(function()
							objectbkg.Visible = true
						end)
						object.MouseLeave:Connect(function()
							objectbkg.Visible = false
						end)
						object.MouseButton1Click:Connect(function()
							local ind = table.find(self.ListEnabled, v)
							if ind then
								table.remove(self.ListEnabled, ind)
								objectdot.BackgroundColor3 = color.Light(uipallet.Main, 0.37)
								objectdotin.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
							else
								table.insert(self.ListEnabled, v)
								objectdot.BackgroundColor3 = categorysettings.Color
								objectdotin.BackgroundColor3 = categorysettings.Color
							end
							categorysettings.Function()
						end)
						table.insert(self.Objects, object)
					end
				end
				mainapi:UpdateGUI(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
			end

			function categoryapi:Expand()
				self.Expanded = not self.Expanded
				children.Visible = self.Expanded
				arrow.Rotation = self.Expanded and 0 or 180
				window.Size = UDim2.fromOffset(220, self.Expanded and math.min(51 + windowlist.AbsoluteContentSize.Y / scale.Scale, 611) or 45)
				divider.Visible = children.CanvasPosition.Y > 10 and children.Visible
			end

			function categoryapi:GetValue(name)
				for i, v in mainapi.Profiles do
					if v.Name == name then
						return i
					end
				end
			end

			for i, v in components do
				categoryapi['Create'..i] = function(self, optionsettings)
					return v(optionsettings, childrentwo, categoryapi)
				end
			end

			addbutton.MouseEnter:Connect(function()
				addbutton.ImageTransparency = 0
			end)
			addbutton.MouseLeave:Connect(function()
				addbutton.ImageTransparency = 0.3
			end)
			addbutton.MouseButton1Click:Connect(function()
				if not table.find(categoryapi.List, addvalue.Text) then
					categoryapi:ChangeValue(addvalue.Text)
					addvalue.Text = ''
				end
			end)
			arrowbutton.MouseEnter:Connect(function()
				arrow.ImageColor3 = Color3.fromRGB(220, 220, 220)
			end)
			arrowbutton.MouseLeave:Connect(function()
				arrow.ImageColor3 = Color3.fromRGB(140, 140, 140)
			end)
			arrowbutton.MouseButton1Click:Connect(function()
				categoryapi:Expand()
			end)
			arrowbutton.MouseButton2Click:Connect(function()
				categoryapi:Expand()
			end)
			addvalue.FocusLost:Connect(function(enter)
				if enter and not table.find(categoryapi.List, addvalue.Text) then
					categoryapi:ChangeValue(addvalue.Text)
					addvalue.Text = ''
				end
			end)
			addvalue.MouseEnter:Connect(function()
				tween:Tween(addbkg, uipallet.Tween, {
					BackgroundColor3 = color.Light(uipallet.Main, 0.14)
				})
			end)
			addvalue.MouseLeave:Connect(function()
				tween:Tween(addbkg, uipallet.Tween, {
					BackgroundColor3 = color.Light(uipallet.Main, 0.02)
				})
			end)
			children:GetPropertyChangedSignal('CanvasPosition'):Connect(function()
				divider.Visible = children.CanvasPosition.Y > 10 and children.Visible
			end)
			settings.MouseEnter:Connect(function()
				settings.ImageColor3 = uipallet.Text
			end)
			settings.MouseLeave:Connect(function()
				settings.ImageColor3 = color.Light(uipallet.Main, 0.37)
			end)
			settings.MouseButton1Click:Connect(function()
				childrentwo.Visible = not childrentwo.Visible
			end)
			window.InputBegan:Connect(function(inputObj)
				if inputObj.Position.Y < window.AbsolutePosition.Y + 41 and inputObj.UserInputType == Enum.UserInputType.MouseButton2 then
					categoryapi:Expand()
				end
			end)
			windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
				if self.ThreadFix then
					setthreadidentity(8)
				end
				children.CanvasSize = UDim2.fromOffset(0, windowlist.AbsoluteContentSize.Y / scale.Scale)
				if categoryapi.Expanded then
					window.Size = UDim2.fromOffset(220, math.min(51 + windowlist.AbsoluteContentSize.Y / scale.Scale, 611))
				end
			end)
			windowlisttwo:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
				if self.ThreadFix then
					setthreadidentity(8)
				end
				childrentwo.Size = UDim2.fromOffset(220, windowlisttwo.AbsoluteContentSize.Y)
			end)

			categoryapi.Button = self.Categories.Main:CreateButton({
				Name = categorysettings.Name,
				Icon = categorysettings.CategoryIcon,
				Size = categorysettings.CategorySize,
				Window = window
			})

			categoryapi.Object = window
			self.Categories[categorysettings.Name] = categoryapi

			return categoryapi
		end

		function mainapi:CreateSearch()
			local searchbkg = Instance.new('Frame')
			searchbkg.Name = 'Search'
			searchbkg.Size = UDim2.fromOffset(220, 37)
			searchbkg.Position = UDim2.new(0.5, 0, 0, 13)
			searchbkg.AnchorPoint = Vector2.new(0.5, 0)
			searchbkg.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
			searchbkg.Parent = clickgui
			local searchicon = Instance.new('ImageLabel')
			searchicon.Name = 'Icon'
			searchicon.Size = UDim2.fromOffset(14, 14)
			searchicon.Position = UDim2.new(1, -23, 0, 11)
			searchicon.BackgroundTransparency = 1
			searchicon.Image = 'rbxassetid://14425646684'
			searchicon.ImageColor3 = color.Light(uipallet.Main, 0.37)
			searchicon.Parent = searchbkg
			local legiticon = Instance.new('ImageButton')
			legiticon.Name = 'Legit'
			legiticon.Size = UDim2.fromOffset(29, 16)
			legiticon.Position = UDim2.fromOffset(8, 11)
			legiticon.BackgroundTransparency = 1
			legiticon.Image = 'rbxassetid://14425650534'
			legiticon.Parent = searchbkg
			local legitdivider = Instance.new('Frame')
			legitdivider.Name = 'LegitDivider'
			legitdivider.Size = UDim2.fromOffset(2, 12)
			legitdivider.Position = UDim2.fromOffset(43, 13)
			legitdivider.BackgroundColor3 = color.Light(uipallet.Main, 0.14)
			legitdivider.BorderSizePixel = 0
			legitdivider.Parent = searchbkg
			addBlur(searchbkg)
			addCorner(searchbkg)
			local search = Instance.new('TextBox')
			search.Size = UDim2.new(1, -50, 0, 37)
			search.Position = UDim2.fromOffset(50, 0)
			search.BackgroundTransparency = 1
			search.Text = ''
			search.PlaceholderText = ''
			search.TextXAlignment = Enum.TextXAlignment.Left
			search.TextColor3 = uipallet.Text
			search.TextSize = 12
			search.FontFace = uipallet.Font
			search.ClearTextOnFocus = false
			search.Parent = searchbkg
			local children = Instance.new('ScrollingFrame')
			children.Name = 'Children'
			children.Size = UDim2.new(1, 0, 1, -37)
			children.Position = UDim2.fromOffset(0, 34)
			children.BackgroundTransparency = 1
			children.BorderSizePixel = 0
			children.ScrollBarThickness = 2
			children.ScrollBarImageTransparency = 0.75
			children.CanvasSize = UDim2.new()
			children.Parent = searchbkg
			local divider = Instance.new('Frame')
			divider.Name = 'Divider'
			divider.Size = UDim2.new(1, 0, 0, 1)
			divider.Position = UDim2.fromOffset(0, 33)
			divider.BackgroundColor3 = Color3.new(1, 1, 1)
			divider.BackgroundTransparency = 0.928
			divider.BorderSizePixel = 0
			divider.Visible = false
			divider.Parent = searchbkg
			local windowlist = Instance.new('UIListLayout')
			windowlist.SortOrder = Enum.SortOrder.LayoutOrder
			windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
			windowlist.Parent = children

			children:GetPropertyChangedSignal('CanvasPosition'):Connect(function()
				divider.Visible = children.CanvasPosition.Y > 10 and children.Visible
			end)
			legiticon.MouseButton1Click:Connect(function()
				clickgui.Visible = false
				self.Legit.Window.Visible = true
				self.Legit.Window.Position = UDim2.new(0.5, -350, 0.5, -194)
			end)
			search:GetPropertyChangedSignal('Text'):Connect(function()
				for _, v in children:GetChildren() do
					if v:IsA('TextButton') then
						v:Destroy()
					end
				end
				if search.Text == '' then return end

				for i, v in self.Modules do
					if i:lower():find(search.Text:lower()) then
						local button = v.Object:Clone()
						button.Bind:Destroy()
						button.MouseButton1Click:Connect(function()
							v:Toggle()
						end)

						button.MouseButton2Click:Connect(function()
							v.Object.Parent.Parent.Visible = true
							local frame = v.Object.Parent
							local highlight = Instance.new('Frame')
							highlight.Size = UDim2.fromScale(1, 1)
							highlight.BackgroundColor3 = Color3.new(1, 1, 1)
							highlight.BackgroundTransparency = 0.6
							highlight.BorderSizePixel = 0
							highlight.Parent = v.Object
							tween:Tween(highlight, TweenInfo.new(0.5), {
								BackgroundTransparency = 1
							})
							task.delay(0.5, highlight.Destroy, highlight)

							frame.CanvasPosition = Vector2.new(0, (v.Object.LayoutOrder * 40) - (math.min(frame.CanvasSize.Y.Offset, 600) / 2))
						end)

						button.Parent = children
						task.spawn(function()
							repeat
								for _, v2 in {'Text', 'TextColor3', 'BackgroundColor3'} do
									button[v2] = v.Object[v2]
								end
								button.UIGradient.Color = v.Object.UIGradient.Color
								button.UIGradient.Enabled = v.Object.UIGradient.Enabled
								button.Dots.Dots.ImageColor3 = v.Object.Dots.Dots.ImageColor3
								task.wait()
							until not button.Parent
						end)
					end
				end
			end)
			windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
				if self.ThreadFix then
					setthreadidentity(8)
				end
				children.CanvasSize = UDim2.fromOffset(0, windowlist.AbsoluteContentSize.Y / scale.Scale)
				searchbkg.Size = UDim2.fromOffset(220, math.min(37 + windowlist.AbsoluteContentSize.Y / scale.Scale, 437))
			end)

			self.Legit.Icon = legiticon
		end

		function mainapi:CreateLegit()
			local legitapi = {Modules = {}}

			local window = Instance.new('Frame')
			window.Name = 'LegitGUI'
			window.Size = UDim2.fromOffset(700, 389)
			window.Position = UDim2.new(0.5, -350, 0.5, -194)
			window.BackgroundColor3 = uipallet.Main
			window.Visible = false
			window.Parent = scaledgui
			addBlur(window)
			addCorner(window)
			makeDraggable(window)
			local modal = Instance.new('TextButton')
			modal.BackgroundTransparency = 1
			modal.Text = ''
			modal.Modal = true
			modal.Parent = window
			local icon = Instance.new('ImageLabel')
			icon.Name = 'Icon'
			icon.Size = UDim2.fromOffset(16, 16)
			icon.Position = UDim2.fromOffset(18, 13)
			icon.BackgroundTransparency = 1
			icon.Image = 'rbxassetid://14426740825'
			icon.ImageColor3 = uipallet.Text
			icon.Parent = window
			local close = addCloseButton(window)
			local children = Instance.new('ScrollingFrame')
			children.Name = 'Children'
			children.Size = UDim2.fromOffset(684, 340)
			children.Position = UDim2.fromOffset(14, 41)
			children.BackgroundTransparency = 1
			children.BorderSizePixel = 0
			children.ScrollBarThickness = 2
			children.ScrollBarImageTransparency = 0.75
			children.CanvasSize = UDim2.new()
			children.Parent = window
			local windowlist = Instance.new('UIGridLayout')
			windowlist.SortOrder = Enum.SortOrder.LayoutOrder
			windowlist.FillDirectionMaxCells = 4
			windowlist.CellSize = UDim2.fromOffset(163, 114)
			windowlist.CellPadding = UDim2.fromOffset(6, 5)
			windowlist.Parent = children
			legitapi.Window = window
			table.insert(mainapi.Windows, window)

			function legitapi:CreateModule(modulesettings)
				mainapi:Remove(modulesettings.Name)
				local moduleapi = {
					Enabled = false,
					Options = {},
					Name = modulesettings.Name,
					Legit = true
				}

				local module = Instance.new('TextButton')
				module.Name = modulesettings.Name
				module.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
				module.Text = ''
				module.AutoButtonColor = false
				module.Parent = children
				addTooltip(module, modulesettings.Tooltip)
				addCorner(module)
				local title = Instance.new('TextLabel')
				title.Name = 'Title'
				title.Size = UDim2.new(1, -16, 0, 20)
				title.Position = UDim2.fromOffset(16, 81)
				title.BackgroundTransparency = 1
				title.Text = modulesettings.Name
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.TextColor3 = color.Dark(uipallet.Text, 0.31)
				title.TextSize = 13
				title.FontFace = uipallet.Font
				title.Parent = module
				local knob = Instance.new('Frame')
				knob.Name = 'Knob'
				knob.Size = UDim2.fromOffset(22, 12)
				knob.Position = UDim2.new(1, -57, 0, 14)
				knob.BackgroundColor3 = color.Light(uipallet.Main, 0.14)
				knob.Parent = module
				addCorner(knob, UDim.new(1, 0))
				local knobmain = knob:Clone()
				knobmain.Size = UDim2.fromOffset(8, 8)
				knobmain.Position = UDim2.fromOffset(2, 2)
				knobmain.BackgroundColor3 = uipallet.Main
				knobmain.Parent = knob
				local dotsbutton = Instance.new('TextButton')
				dotsbutton.Name = 'Dots'
				dotsbutton.Size = UDim2.fromOffset(14, 24)
				dotsbutton.Position = UDim2.new(1, -27, 0, 8)
				dotsbutton.BackgroundTransparency = 1
				dotsbutton.Text = ''
				dotsbutton.Parent = module
				local dots = Instance.new('ImageLabel')
				dots.Name = 'Dots'
				dots.Size = UDim2.fromOffset(2, 12)
				dots.Position = UDim2.fromOffset(6, 6)
				dots.BackgroundTransparency = 1
				dots.Image = 'rbxassetid://14368314459'
				dots.ImageColor3 = color.Light(uipallet.Main, 0.37)
				dots.Parent = dotsbutton
				local shadow = Instance.new('TextButton')
				shadow.Name = 'Shadow'
				shadow.Size = UDim2.new(1, 0, 1, -5)
				shadow.BackgroundColor3 = Color3.new()
				shadow.BackgroundTransparency = 1
				shadow.AutoButtonColor = false
				shadow.ClipsDescendants = true
				shadow.Visible = false
				shadow.Text = ''
				shadow.Parent = window
				addCorner(shadow)
				local settingspane = Instance.new('TextButton')
				settingspane.Size = UDim2.new(0, 220, 1, 0)
				settingspane.Position = UDim2.fromScale(1, 0)
				settingspane.BackgroundColor3 = uipallet.Main
				settingspane.AutoButtonColor = false
				settingspane.Text = ''
				settingspane.Parent = shadow
				local settingstitle = Instance.new('TextLabel')
				settingstitle.Name = 'Title'
				settingstitle.Size = UDim2.new(1, -36, 0, 20)
				settingstitle.Position = UDim2.fromOffset(36, 12)
				settingstitle.BackgroundTransparency = 1
				settingstitle.Text = modulesettings.Name
				settingstitle.TextXAlignment = Enum.TextXAlignment.Left
				settingstitle.TextColor3 = color.Dark(uipallet.Text, 0.16)
				settingstitle.TextSize = 13
				settingstitle.FontFace = uipallet.Font
				settingstitle.Parent = settingspane
				local back = Instance.new('ImageButton')
				back.Name = 'Back'
				back.Size = UDim2.fromOffset(16, 16)
				back.Position = UDim2.fromOffset(11, 13)
				back.BackgroundTransparency = 1
				back.Image = 'rbxassetid://14368303894'
				back.ImageColor3 = color.Light(uipallet.Main, 0.37)
				back.Parent = settingspane
				addCorner(settingspane)
				local settingschildren = Instance.new('ScrollingFrame')
				settingschildren.Name = 'Children'
				settingschildren.Size = UDim2.new(1, 0, 1, -45)
				settingschildren.Position = UDim2.fromOffset(0, 41)
				settingschildren.BackgroundColor3 = uipallet.Main
				settingschildren.BorderSizePixel = 0
				settingschildren.ScrollBarThickness = 2
				settingschildren.ScrollBarImageTransparency = 0.75
				settingschildren.CanvasSize = UDim2.new()
				settingschildren.Parent = settingspane
				local settingswindowlist = Instance.new('UIListLayout')
				settingswindowlist.SortOrder = Enum.SortOrder.LayoutOrder
				settingswindowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
				settingswindowlist.Parent = settingschildren
				if modulesettings.Size then
					local modulechildren = Instance.new('Frame')
					modulechildren.Size = modulesettings.Size
					modulechildren.BackgroundTransparency = 1
					modulechildren.Visible = false
					modulechildren.Parent = scaledgui
					makeDraggable(modulechildren, window)
					local objectstroke = Instance.new('UIStroke')
					objectstroke.Color = Color3.fromRGB(5, 134, 105)
					objectstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
					objectstroke.Thickness = 0
					objectstroke.Parent = modulechildren
					moduleapi.Children = modulechildren
				end
				modulesettings.Function = modulesettings.Function or function() end
				addMaid(moduleapi)

				function moduleapi:Toggle()
					moduleapi.Enabled = not moduleapi.Enabled
					if moduleapi.Children then
						moduleapi.Children.Visible = moduleapi.Enabled
					end
					title.TextColor3 = moduleapi.Enabled and color.Light(uipallet.Text, 0.2) or color.Dark(uipallet.Text, 0.31)
					module.BackgroundColor3 = moduleapi.Enabled and color.Light(uipallet.Main, 0.05) or module.BackgroundColor3
					tween:Tween(knob, uipallet.Tween, {
						BackgroundColor3 = moduleapi.Enabled and Color3.fromHSV(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value) or color.Light(uipallet.Main, 0.14)
					})
					tween:Tween(knobmain, uipallet.Tween, {
						Position = UDim2.fromOffset(moduleapi.Enabled and 12 or 2, 2)
					})
					if not moduleapi.Enabled then
						for _, v in moduleapi.Connections do
							v:Disconnect()
						end
						table.clear(moduleapi.Connections)
					end
					task.spawn(modulesettings.Function, moduleapi.Enabled)
				end

				back.MouseEnter:Connect(function()
					back.ImageColor3 = uipallet.Text
				end)
				back.MouseLeave:Connect(function()
					back.ImageColor3 = color.Light(uipallet.Main, 0.37)
				end)
				back.MouseButton1Click:Connect(function()
					tween:Tween(shadow, uipallet.Tween, {
						BackgroundTransparency = 1
					})
					tween:Tween(settingspane, uipallet.Tween, {
						Position = UDim2.fromScale(1, 0)
					})
					task.wait(0.2)
					shadow.Visible = false
				end)
				dotsbutton.MouseButton1Click:Connect(function()
					shadow.Visible = true
					tween:Tween(shadow, uipallet.Tween, {
						BackgroundTransparency = 0.5
					})
					tween:Tween(settingspane, uipallet.Tween, {
						Position = UDim2.new(1, -220, 0, 0)
					})
				end)
				dotsbutton.MouseEnter:Connect(function()
					dots.ImageColor3 = uipallet.Text
				end)
				dotsbutton.MouseLeave:Connect(function()
					dots.ImageColor3 = color.Light(uipallet.Main, 0.37)
				end)
				module.MouseEnter:Connect(function()
					if not moduleapi.Enabled then
						module.BackgroundColor3 = color.Light(uipallet.Main, 0.05)
					end
				end)
				module.MouseLeave:Connect(function()
					if not moduleapi.Enabled then
						module.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
					end
				end)
				module.MouseButton1Click:Connect(function()
					moduleapi:Toggle()
				end)
				module.MouseButton2Click:Connect(function()
					shadow.Visible = true
					tween:Tween(shadow, uipallet.Tween, {
						BackgroundTransparency = 0.5
					})
					tween:Tween(settingspane, uipallet.Tween, {
						Position = UDim2.new(1, -220, 0, 0)
					})
				end)
				shadow.MouseButton1Click:Connect(function()
					tween:Tween(shadow, uipallet.Tween, {
						BackgroundTransparency = 1
					})
					tween:Tween(settingspane, uipallet.Tween, {
						Position = UDim2.fromScale(1, 0)
					})
					task.wait(0.2)
					shadow.Visible = false
				end)
				settingswindowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
					if mainapi.ThreadFix then
						setthreadidentity(8)
					end
					settingschildren.CanvasSize = UDim2.fromOffset(0, settingswindowlist.AbsoluteContentSize.Y / scale.Scale)
				end)

				for i, v in components do
					moduleapi['Create'..i] = function(_, optionsettings)
						return v(optionsettings, settingschildren, moduleapi)
					end
				end

				moduleapi.Object = module
				legitapi.Modules[modulesettings.Name] = moduleapi

				local sorting = {}
				for _, v in legitapi.Modules do
					table.insert(sorting, v.Name)
				end
				table.sort(sorting)

				for i, v in sorting do
					legitapi.Modules[v].Object.LayoutOrder = i
				end

				return moduleapi
			end

			local function visibleCheck()
				for _, v in legitapi.Modules do
					if v.Children then
						local visible = clickgui.Visible
						for _, v2 in self.Windows do
							visible = visible or v2.Visible
						end
						v.Children.Visible = (not visible or window.Visible) and v.Enabled
					end
				end
			end

			close.MouseButton1Click:Connect(function()
				window.Visible = false
				clickgui.Visible = true
			end)
			self:Clean(clickgui:GetPropertyChangedSignal('Visible'):Connect(visibleCheck))
			window:GetPropertyChangedSignal('Visible'):Connect(function()
				self:UpdateGUI(self.GUIColor.Hue, self.GUIColor.Sat, self.GUIColor.Value)
				visibleCheck()
			end)
			windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
				if self.ThreadFix then
					setthreadidentity(8)
				end
				children.CanvasSize = UDim2.fromOffset(0, windowlist.AbsoluteContentSize.Y / scale.Scale)
			end)

			self.Legit = legitapi

			return legitapi
		end

		function mainapi:CreateNotification(title, text, duration, type)
			if not self.Notifications.Enabled then return end
			task.delay(0, function()
				if self.ThreadFix then
					setthreadidentity(8)
				end
				local i = #notifications:GetChildren() + 1
				local notification = Instance.new('ImageLabel')
				notification.Name = 'Notification'
				notification.Size = UDim2.fromOffset(math.max(getfontsize(removeTags(text), 14, uipallet.Font).X + 80, 266), 75)
				notification.Position = UDim2.new(1, 0, 1, -(29 + (78 * i)))
				notification.ZIndex = 5
				notification.BackgroundTransparency = 1
				notification.Image = 'rbxassetid://16738721069'
				notification.ScaleType = Enum.ScaleType.Slice
				notification.SliceCenter = Rect.new(7, 7, 9, 9)
				notification.Parent = notifications
				addBlur(notification, true)
				local iconshadow = Instance.new('ImageLabel')
				iconshadow.Name = 'Icon'
				iconshadow.Size = UDim2.fromOffset(60, 60)
				iconshadow.Position = UDim2.fromOffset(-5, -8)
				iconshadow.ZIndex = 5
				iconshadow.BackgroundTransparency = 1
				iconshadow.Image = 'rbxassetid://14368324807'
				iconshadow.ImageColor3 = Color3.new()
				iconshadow.ImageTransparency = 0.5
				iconshadow.Parent = notification
				local icon = iconshadow:Clone()
				icon.Position = UDim2.fromOffset(-1, -1)
				icon.ImageColor3 = Color3.new(1, 1, 1)
				icon.ImageTransparency = 0
				icon.Parent = iconshadow
				local titlelabel = Instance.new('TextLabel')
				titlelabel.Name = 'Title'
				titlelabel.Size = UDim2.new(1, -56, 0, 20)
				titlelabel.Position = UDim2.fromOffset(46, 16)
				titlelabel.ZIndex = 5
				titlelabel.BackgroundTransparency = 1
				titlelabel.Text = "<stroke color='#FFFFFF' joins='round' thickness='0.3' transparency='0.5'>"..title..'</stroke>'
				titlelabel.TextXAlignment = Enum.TextXAlignment.Left
				titlelabel.TextYAlignment = Enum.TextYAlignment.Top
				titlelabel.TextColor3 = Color3.fromRGB(209, 209, 209)
				titlelabel.TextSize = 14
				titlelabel.RichText = true
				titlelabel.FontFace = uipallet.FontSemiBold
				titlelabel.Parent = notification
				local textshadow = titlelabel:Clone()
				textshadow.Name = 'Text'
				textshadow.Position = UDim2.fromOffset(47, 44)
				textshadow.Text = removeTags(text)
				textshadow.TextColor3 = Color3.new()
				textshadow.TextTransparency = 0.5
				textshadow.RichText = false
				textshadow.FontFace = uipallet.Font
				textshadow.Parent = notification
				local textlabel = textshadow:Clone()
				textlabel.Position = UDim2.fromOffset(-1, -1)
				textlabel.Text = text
				textlabel.TextColor3 = Color3.fromRGB(170, 170, 170)
				textlabel.TextTransparency = 0
				textlabel.RichText = true
				textlabel.Parent = textshadow
				local progress = Instance.new('Frame')
				progress.Name = 'Progress'
				progress.Size = UDim2.new(1, -13, 0, 2)
				progress.Position = UDim2.new(0, 3, 1, -4)
				progress.ZIndex = 5
				progress.BackgroundColor3 =
					type == 'alert' and Color3.fromRGB(250, 50, 56)
					or type == 'warning' and Color3.fromRGB(236, 129, 43)
					or Color3.fromRGB(220, 220, 220)
				progress.BorderSizePixel = 0
				progress.Parent = notification
				if tween.Tween then
					tween:Tween(notification, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {
						AnchorPoint = Vector2.new(1, 0)
					}, tween.tweenstwo)
					tween:Tween(progress, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
						Size = UDim2.fromOffset(0, 2)
					})
				end
				task.delay(duration, function()
					if tween.Tween then
						tween:Tween(notification, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {
							AnchorPoint = Vector2.new(0, 0)
						}, tween.tweenstwo)
					end
					task.wait(0.2)
					notification:ClearAllChildren()
					notification:Destroy()
				end)
			end)
		end

		function mainapi:Load(skipgui, profile)
			if not skipgui then
				self.GUIColor:SetValue(nil, nil, nil, 4)
			end
			local guidata = {}
			local savecheck = true

			if isfile('newlunar/profiles/'..game.GameId..'.gui.txt') then
				guidata = loadJson('newlunar/profiles/'..game.GameId..'.gui.txt')
				if not guidata then
					guidata = {Categories = {}}
					self:CreateNotification('Lunar', 'Failed to load GUI settings.', 10, 'alert')
					savecheck = false
				end

				if not skipgui then
					self.Keybind = guidata.Keybind
					for i, v in guidata.Categories do
						local object = self.Categories[i]
						if not object then continue end
						if object.Options and v.Options then
							self:LoadOptions(object, v.Options)
						end
						if v.Enabled then
							object.Button:Toggle()
						end
						if v.Pinned then
							object:Pin()
						end
						if v.Expanded and object.Expand then
							object:Expand()
						end
						if v.List and (#object.List > 0 or #v.List > 0) then
							object.List = v.List or {}
							object.ListEnabled = v.ListEnabled or {}
							object:ChangeValue()
						end
						if v.Position then
							object.Object.Position = UDim2.fromOffset(v.Position.X, v.Position.Y)
						end
					end
				end
			end

			self.Profile = profile or guidata.Profile or 'default'
			self.Profiles = guidata.Profiles or {{
				Name = 'default', Bind = {}
			}}
			self.Categories.Profiles:ChangeValue()
			if self.ProfileLabel then
				self.ProfileLabel.Text = #self.Profile > 10 and self.Profile:sub(1, 10)..'...' or self.Profile
				self.ProfileLabel.Size = UDim2.fromOffset(getfontsize(self.ProfileLabel.Text, self.ProfileLabel.TextSize, self.ProfileLabel.Font).X + 16, 24)
			end

			if isfile('newlunar/profiles/'..self.Profile..self.Place..'.txt') then
				local savedata = loadJson('newlunar/profiles/'..self.Profile..self.Place..'.txt')
				if not savedata then
					savedata = {Categories = {}, Modules = {}, Legit = {}}
					self:CreateNotification('Lunar', 'Failed to load '..self.Profile..' profile.', 10, 'alert')
					savecheck = false
				end

				for i, v in savedata.Categories do
					local object = self.Categories[i]
					if not object then continue end
					if object.Options and v.Options then
						self:LoadOptions(object, v.Options)
					end
					if v.Pinned ~= object.Pinned then
						object:Pin()
					end
					if v.Expanded ~= nil and v.Expanded ~= object.Expanded then
						object:Expand()
					end
					if object.Button and (v.Enabled or false) ~= object.Button.Enabled then
						object.Button:Toggle()
					end
					if v.List and (#object.List > 0 or #v.List > 0) then
						object.List = v.List or {}
						object.ListEnabled = v.ListEnabled or {}
						object:ChangeValue()
					end
					object.Object.Position = UDim2.fromOffset(v.Position.X, v.Position.Y)
				end

				for i, v in savedata.Modules do
					local object = self.Modules[i]
					if not object then continue end
					if object.Options and v.Options then
						self:LoadOptions(object, v.Options)
					end
					if v.Enabled ~= object.Enabled then
						if skipgui then
							if self.ToggleNotifications.Enabled then self:CreateNotification('Module Toggled', i.."<font color='#FFFFFF'> has been </font>"..(v.Enabled and "<font color='#5AFF5A'>Enabled</font>" or "<font color='#FF5A5A'>Disabled</font>").."<font color='#FFFFFF'>!</font>", 0.75) end
						end
						object:Toggle(true)
					end
					object:SetBind(v.Bind)
					object.Object.Bind.Visible = #v.Bind > 0
				end

				for i, v in savedata.Legit do
					local object = self.Legit.Modules[i]
					if not object then continue end
					if object.Options and v.Options then
						self:LoadOptions(object, v.Options)
					end
					if object.Enabled ~= v.Enabled then
						object:Toggle()
					end
					if v.Position and object.Children then
						object.Children.Position = UDim2.fromOffset(v.Position.X, v.Position.Y)
					end
				end

				self:UpdateTextGUI(true)
			else
				self:Save()
			end

			if self.Downloader then
				self.Downloader:Destroy()
				self.Downloader = nil
			end
			self.Loaded = savecheck
			self.Categories.Main.Options.Bind:SetBind(self.Keybind)

			if inputService.TouchEnabled and #self.Keybind == 1 and self.Keybind[1] == 'RightShift' then
				local button = Instance.new('TextButton')
				button.Size = UDim2.fromOffset(32, 32)
				button.Position = UDim2.new(1, -90, 0, 4)
				button.BackgroundColor3 = Color3.new()
				button.BackgroundTransparency = 0.5
				button.Text = ''
				button.Parent = gui
				local image = Instance.new('ImageLabel')
				image.Size = UDim2.fromOffset(26, 26)
				image.Position = UDim2.fromOffset(3, 3)
				image.BackgroundTransparency = 1
				image.Image = 'rbxassetid://14373395239'
				image.Parent = button
				local buttoncorner = Instance.new('UICorner')
				buttoncorner.Parent = button
				self.VapeButton = button
				button.MouseButton1Click:Connect(function()
					if self.ThreadFix then
						setthreadidentity(8)
					end
					for _, v in self.Windows do
						v.Visible = false
					end
					for _, mobileButton in self.Modules do
						if mobileButton.Bind.Button then
							mobileButton.Bind.Button.Visible = clickgui.Visible
						end
					end
					clickgui.Visible = not clickgui.Visible
					tooltip.Visible = false
					self:BlurCheck()
				end)
			end
		end

		function mainapi:LoadOptions(object, savedoptions)
			for i, v in savedoptions do
				local option = object.Options[i]
				if not option then continue end
				option:Load(v)
			end
		end

		function mainapi:Remove(obj)
			local tab = (self.Modules[obj] and self.Modules or self.Legit.Modules[obj] and self.Legit.Modules or self.Categories)
			if tab and tab[obj] then
				local newobj = tab[obj]
				if self.ThreadFix then
					setthreadidentity(8)
				end

				for _, v in {'Object', 'Children', 'Toggle', 'Button'} do
					local childobj = typeof(newobj[v]) == 'table' and newobj[v].Object or newobj[v]
					if typeof(childobj) == 'Instance' then
						childobj:Destroy()
						childobj:ClearAllChildren()
					end
				end

				loopClean(newobj)
				tab[obj] = nil
			end
		end

		function mainapi:Save(newprofile)
			if not self.Loaded then return end
			local guidata = {
				Categories = {},
				Profile = newprofile or self.Profile,
				Profiles = self.Profiles,
				Keybind = self.Keybind
			}
			local savedata = {
				Modules = {},
				Categories = {},
				Legit = {}
			}

			for i, v in self.Categories do
				(v.Type ~= 'Category' and i ~= 'Main' and savedata or guidata).Categories[i] = {
					Enabled = i ~= 'Main' and v.Button.Enabled or nil,
					Expanded = v.Type ~= 'Overlay' and v.Expanded or nil,
					Pinned = v.Pinned,
					Position = {X = v.Object.Position.X.Offset, Y = v.Object.Position.Y.Offset},
					Options = mainapi:SaveOptions(v, v.Options),
					List = v.List,
					ListEnabled = v.ListEnabled
				}
			end

			for i, v in self.Modules do
				savedata.Modules[i] = {
					Enabled = v.Enabled,
					Bind = v.Bind.Button and {Mobile = true, X = v.Bind.Button.Position.X.Offset, Y = v.Bind.Button.Position.Y.Offset} or v.Bind,
					Options = mainapi:SaveOptions(v, true)
				}
			end

			for i, v in self.Legit.Modules do
				savedata.Legit[i] = {
					Enabled = v.Enabled,
					Position = v.Children and {X = v.Children.Position.X.Offset, Y = v.Children.Position.Y.Offset} or nil,
					Options = mainapi:SaveOptions(v, v.Options)
				}
			end

			writefile('newlunar/profiles/'..game.GameId..'.gui.txt', httpService:JSONEncode(guidata))
			writefile('newlunar/profiles/'..self.Profile..self.Place..'.txt', httpService:JSONEncode(savedata))
		end

		function mainapi:SaveOptions(object, savedoptions)
			if not savedoptions then return end
			savedoptions = {}
			for _, v in object.Options do
				if not v.Save then continue end
				v:Save(savedoptions)
			end
			return savedoptions
		end

		function mainapi:Uninject()
			mainapi:Save()
			mainapi.Loaded = nil
			for _, v in self.Modules do
				if v.Enabled then
					v:Toggle()
				end
			end
			for _, v in self.Legit.Modules do
				if v.Enabled then
					v:Toggle()
				end
			end
			for _, v in self.Categories do
				if v.Type == 'Overlay' and v.Button.Enabled then
					v.Button:Toggle()
				end
			end
			for _, v in mainapi.Connections do
				pcall(function()
					v:Disconnect()
				end)
			end
			if mainapi.ThreadFix then
				setthreadidentity(8)
				clickgui.Visible = false
				mainapi:BlurCheck()
			end
			mainapi.gui:ClearAllChildren()
			mainapi.gui:Destroy()
			table.clear(mainapi.Libraries)
			loopClean(mainapi)
			shared.vape = nil
			shared.vapereload = nil
			shared.VapeIndependent = nil
		end

		gui = Instance.new('ScreenGui')
		gui.Name = randomString()
		gui.DisplayOrder = 9999999
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
		gui.IgnoreGuiInset = true
		gui.OnTopOfCoreBlur = true
		if mainapi.ThreadFix then
			gui.Parent = cloneref(game:GetService('CoreGui'))--(gethui and gethui()) or cloneref(game:GetService('CoreGui'))
		else
			gui.Parent = cloneref(game:GetService('Players')).LocalPlayer.PlayerGui
			gui.ResetOnSpawn = false
		end
		mainapi.gui = gui
		scaledgui = Instance.new('Frame')
		scaledgui.Name = 'ScaledGui'
		scaledgui.Size = UDim2.fromScale(1, 1)
		scaledgui.BackgroundTransparency = 1
		scaledgui.Parent = gui
		clickgui = Instance.new('Frame')
		clickgui.Name = 'ClickGui'
		clickgui.Size = UDim2.fromScale(1, 1)
		clickgui.BackgroundTransparency = 1
		clickgui.Visible = false
		clickgui.Parent = scaledgui
		--local scarcitybanner = Instance.new('TextLabel')
		--scarcitybanner.Size = UDim2.fromScale(1, 0.02)
		--scarcitybanner.Position = UDim2.fromScale(0, 0.97)
		--scarcitybanner.BackgroundTransparency = 1
		--scarcitybanner.Text = 'A new discord has been created, click the discord icon to join.'
		--scarcitybanner.TextScaled = true
		--scarcitybanner.TextColor3 = Color3.new(1, 1, 1)
		--scarcitybanner.TextStrokeTransparency = 0.5
		--scarcitybanner.FontFace = uipallet.Font
		--scarcitybanner.Parent = clickgui
		local modal = Instance.new('TextButton')
		modal.BackgroundTransparency = 1
		modal.Modal = true
		modal.Text = ''
		modal.Parent = clickgui
		local cursor = Instance.new('ImageLabel')
		cursor.Size = UDim2.fromOffset(64, 64)
		cursor.BackgroundTransparency = 1
		cursor.Visible = false
		cursor.Image = 'rbxasset://textures/Cursors/KeyboardMouse/ArrowFarCursor.png'
		cursor.Parent = gui
		notifications = Instance.new('Folder')
		notifications.Name = 'Notifications'
		notifications.Parent = scaledgui
		tooltip = Instance.new('TextLabel')
		tooltip.Name = 'Tooltip'
		tooltip.Position = UDim2.fromScale(-1, -1)
		tooltip.ZIndex = 5
		tooltip.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
		tooltip.Visible = false
		tooltip.Text = ''
		tooltip.TextColor3 = color.Dark(uipallet.Text, 0.16)
		tooltip.TextSize = 12
		tooltip.FontFace = uipallet.Font
		tooltip.Parent = scaledgui
		toolblur = addBlur(tooltip)
		addCorner(tooltip)
		local toolstrokebkg = Instance.new('Frame')
		toolstrokebkg.Size = UDim2.new(1, -2, 1, -2)
		toolstrokebkg.Position = UDim2.fromOffset(1, 1)
		toolstrokebkg.ZIndex = 6
		toolstrokebkg.BackgroundTransparency = 1
		toolstrokebkg.Parent = tooltip
		local toolstroke = Instance.new('UIStroke')
		toolstroke.Color = color.Light(uipallet.Main, 0.02)
		toolstroke.Parent = toolstrokebkg
		addCorner(toolstrokebkg, UDim.new(0, 4))
		scale = Instance.new('UIScale')
		scale.Scale = math.max(gui.AbsoluteSize.X / 1920, 0.6)
		scale.Parent = scaledgui
		mainapi.guiscale = scale
		scaledgui.Size = UDim2.fromScale(1 / scale.Scale, 1 / scale.Scale)

		mainapi:Clean(gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()
			if mainapi.Scale.Enabled then
				scale.Scale = math.max(gui.AbsoluteSize.X / 1920, 0.6)
			end
		end))

		mainapi:Clean(scale:GetPropertyChangedSignal('Scale'):Connect(function()
			scaledgui.Size = UDim2.fromScale(1 / scale.Scale, 1 / scale.Scale)
			for _, v in scaledgui:GetDescendants() do
				if v:IsA('GuiObject') and v.Visible then
					v.Visible = false
					v.Visible = true
				end
			end
		end))

		mainapi:Clean(clickgui:GetPropertyChangedSignal('Visible'):Connect(function()
			mainapi:UpdateGUI(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value, true)
			if clickgui.Visible and inputService.MouseEnabled then
				repeat
					local visibleCheck = clickgui.Visible
					for _, v in mainapi.Windows do
						visibleCheck = visibleCheck or v.Visible
					end
					if not visibleCheck then break end

					cursor.Visible = not inputService.MouseIconEnabled
					if cursor.Visible then
						local mouseLocation = inputService:GetMouseLocation()
						cursor.Position = UDim2.fromOffset(mouseLocation.X - 31, mouseLocation.Y - 32)
					end

					task.wait()
				until mainapi.Loaded == nil
				cursor.Visible = false
			end
		end))

		mainapi:CreateGUI()
		mainapi.Categories.Main:CreateDivider()
		mainapi:CreateCategory({
			Name = 'Combat',
			Icon = 'rbxassetid://14368312652',
			Size = UDim2.fromOffset(13, 14)
		})
		mainapi:CreateCategory({
			Name = 'Blatant',
			Icon = 'rbxassetid://14368306745',
			Size = UDim2.fromOffset(14, 14)
		})
		mainapi:CreateCategory({
			Name = 'Render',
			Icon = 'rbxassetid://14368350193',
			Size = UDim2.fromOffset(15, 14)
		})
		mainapi:CreateCategory({
			Name = 'Utility',
			Icon = 'rbxassetid://14368359107',
			Size = UDim2.fromOffset(15, 14)
		})
		mainapi:CreateCategory({
			Name = 'World',
			Icon = 'rbxassetid://14368362492',
			Size = UDim2.fromOffset(14, 14)
		})
		mainapi:CreateCategory({
			Name = 'Inventory',
			Icon = 'rbxassetid://14928011633',
			Size = UDim2.fromOffset(15, 14)
		})
		mainapi:CreateCategory({
			Name = 'Minigames',
			Icon = 'rbxassetid://14368326029',
			Size = UDim2.fromOffset(19, 12)
		})
		mainapi.Categories.Main:CreateDivider('misc')

--[[
	Friends
]]
		local friends
		local friendscolor = {
			Hue = 1,
			Sat = 1,
			Value = 1
		}
		local friendssettings = {
			Name = 'Friends',
			Icon = 'rbxassetid://14397462778',
			Size = UDim2.fromOffset(17, 16),
			Placeholder = 'Roblox username',
			Color = Color3.fromRGB(5, 134, 105),
			Function = function()
				friends.Update:Fire()
				friends.ColorUpdate:Fire(friendscolor.Hue, friendscolor.Sat, friendscolor.Value)
			end
		}
		friends = mainapi:CreateCategoryList(friendssettings)
		friends.Update = Instance.new('BindableEvent')
		friends.ColorUpdate = Instance.new('BindableEvent')
		friends:CreateToggle({
			Name = 'Recolor visuals',
			Darker = true,
			Default = true,
			Function = function()
				friends.Update:Fire()
				friends.ColorUpdate:Fire(friendscolor.Hue, friendscolor.Sat, friendscolor.Value)
			end
		})
		friendscolor = friends:CreateColorSlider({
			Name = 'Friends color',
			Darker = true,
			Function = function(hue, sat, val)
				for _, v in friends.Object.Children:GetChildren() do
					local dot = v:FindFirstChild('Dot')
					if dot and dot.BackgroundColor3 ~= color.Light(uipallet.Main, 0.37) then
						dot.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
						dot.Dot.BackgroundColor3 = dot.BackgroundColor3
					end
				end
				friendssettings.Color = Color3.fromHSV(hue, sat, val)
				friends.ColorUpdate:Fire(hue, sat, val)
			end
		})
		friends:CreateToggle({
			Name = 'Use friends',
			Darker = true,
			Default = true,
			Function = function()
				friends.Update:Fire()
				friends.ColorUpdate:Fire(friendscolor.Hue, friendscolor.Sat, friendscolor.Value)
			end
		})
		mainapi:Clean(friends.Update)
		mainapi:Clean(friends.ColorUpdate)

--[[
	Profiles
]]
		mainapi:CreateCategoryList({
			Name = 'Profiles',
			Icon = 'rbxassetid://14397465323',
			Size = UDim2.fromOffset(17, 10),
			Position = UDim2.fromOffset(12, 16),
			Placeholder = 'Type name',
			Profiles = true
		})

--[[
	Targets
]]
		local targets
		targets = mainapi:CreateCategoryList({
			Name = 'Targets',
			Icon = 'rbxassetid://14397462778',
			Size = UDim2.fromOffset(17, 16),
			Placeholder = 'Roblox username',
			Function = function()
				targets.Update:Fire()
			end
		})
		targets.Update = Instance.new('BindableEvent')
		mainapi:Clean(targets.Update)

		mainapi:CreateLegit()
		mainapi:CreateSearch()
		mainapi.Categories.Main:CreateOverlayBar()
		mainapi.Categories.Main:CreateSettingsDivider()

--[[
	General Settings
]]

		local general = mainapi.Categories.Main:CreateSettingsPane({Name = 'General'})
		mainapi.MultiKeybind = general:CreateToggle({
			Name = 'Enable Multi-Keybinding',
			Tooltip = 'Allows multiple keys to be bound to a module (eg. G + H)'
		})
		general:CreateButton({
			Name = 'Reset current profile',
			Function = function()
				mainapi.Save = function() end
				if isfile('newlunar/profiles/'..mainapi.Profile..mainapi.Place..'.txt') and delfile then
					delfile('newlunar/profiles/'..mainapi.Profile..mainapi.Place..'.txt')
				end
				shared.vapereload = true
				if shared.VapeDeveloper then
					loadstring(readfile('newlunar/loader.lua'), 'loader')()
				else
					loadstring(game:HttpGet('https://raw.githubusercontent.com/xylex1/LunarClient/'..readfile('newlunar/profiles/commit.txt')..'/loader.lua', true))()
				end
			end,
			Tooltip = 'This will set your profile to the default settings of Lunar'
		})
		general:CreateButton({
			Name = 'Self destruct',
			Function = function()
				mainapi:Uninject()
			end,
			Tooltip = 'Removes Lunar from the current game'
		})
		general:CreateButton({
			Name = 'Reinject',
			Function = function()
				shared.vapereload = true
				if shared.VapeDeveloper then
					loadstring(readfile('newlunar/loader.lua'), 'loader')()
				else
					loadstring(game:HttpGet('https://raw.githubusercontent.com/xylex1/LunarClient/'..readfile('newlunar/profiles/commit.txt')..'/loader.lua', true))()
				end
			end,
			Tooltip = 'Reloads Lunar for debugging purposes'
		})

--[[
	Module Settings
]]

		local modules = mainapi.Categories.Main:CreateSettingsPane({Name = 'Modules'})
		modules:CreateToggle({
			Name = 'Teams by server',
			Tooltip = 'Ignore players on your team designated by the server',
			Default = true,
			Function = function()
				if mainapi.Libraries.entity and mainapi.Libraries.entity.Running then
					mainapi.Libraries.entity.refresh()
				end
			end
		})
		modules:CreateToggle({
			Name = 'Use team color',
			Tooltip = 'Uses the TeamColor property on players for render modules',
			Default = true,
			Function = function()
				if mainapi.Libraries.entity and mainapi.Libraries.entity.Running then
					mainapi.Libraries.entity.refresh()
				end
			end
		})

--[[
	GUI Settings
]]

		local guipane = mainapi.Categories.Main:CreateSettingsPane({Name = 'GUI'})
		mainapi.Blur = guipane:CreateToggle({
			Name = 'Blur background',
			Function = function()
				mainapi:BlurCheck()
			end,
			Default = true,
			Tooltip = 'Blur the background of the GUI'
		})
		guipane:CreateToggle({
			Name = 'GUI bind indicator',
			Default = true,
			Tooltip = "Displays a message indicating your GUI upon injecting.\nI.E. 'Press RSHIFT to open GUI'"
		})
		guipane:CreateToggle({
			Name = 'Show tooltips',
			Function = function(enabled)
				tooltip.Visible = false
				toolblur.Visible = enabled
			end,
			Default = true,
			Tooltip = 'Toggles visibility of these'
		})
		guipane:CreateToggle({
			Name = 'Show legit mode',
			Function = function(enabled)
				clickgui.Search.Legit.Visible = enabled
				clickgui.Search.LegitDivider.Visible = enabled
				clickgui.Search.TextBox.Size = UDim2.new(1, enabled and -50 or -10, 0, 37)
				clickgui.Search.TextBox.Position = UDim2.fromOffset(enabled and 50 or 10, 0)
			end,
			Default = true,
			Tooltip = 'Shows the button to change to Legit Mode'
		})
		local scaleslider = {Object = {}, Value = 1}
		mainapi.Scale = guipane:CreateToggle({
			Name = 'Auto rescale',
			Default = true,
			Function = function(callback)
				scaleslider.Object.Visible = not callback
				if callback then
					scale.Scale = math.max(gui.AbsoluteSize.X / 1920, 0.6)
				else
					scale.Scale = scaleslider.Value
				end
			end,
			Tooltip = 'Automatically rescales the gui using the screens resolution'
		})
		scaleslider = guipane:CreateSlider({
			Name = 'Scale',
			Min = 0.1,
			Max = 2,
			Decimal = 10,
			Function = function(val, final)
				if final and not mainapi.Scale.Enabled then
					scale.Scale = val
				end
			end,
			Default = 1,
			Darker = true,
			Visible = false
		})
		guipane:CreateDropdown({
			Name = 'GUI Theme',
			List = inputService.TouchEnabled and {'new', 'old'} or {'new', 'old', 'rise'},
			Function = function(val, mouse)
				if mouse then
					writefile('newlunar/profiles/gui.txt', val)
					shared.vapereload = true
					if shared.VapeDeveloper then
						loadstring(readfile('newlunar/loader.lua'), 'loader')()
					else
						loadstring(game:HttpGet('https://raw.githubusercontent.com/xylex1/LunarClient/'..readfile('newlunar/profiles/commit.txt')..'/loader.lua', true))()
					end
				end
			end,
			Tooltip = 'wow'
		})
		mainapi.RainbowMode = guipane:CreateDropdown({
			Name = 'Rainbow Mode',
			List = {'Normal', 'Gradient', 'Retro'},
			Tooltip = 'Normal - Smooth color fade\nGradient - Gradient color fade\nRetro - Static color'
		})
		mainapi.RainbowSpeed = guipane:CreateSlider({
			Name = 'Rainbow speed',
			Min = 0.1,
			Max = 10,
			Decimal = 10,
			Default = 1,
			Tooltip = 'Adjusts the speed of rainbow values'
		})
		mainapi.RainbowUpdateSpeed = guipane:CreateSlider({
			Name = 'Rainbow update rate',
			Min = 1,
			Max = 144,
			Default = 60,
			Tooltip = 'Adjusts the update rate of rainbow values',
			Suffix = 'hz'
		})
		guipane:CreateButton({
			Name = 'Reset GUI positions',
			Function = function()
				for _, v in mainapi.Categories do
					v.Object.Position = UDim2.fromOffset(6, 42)
				end
			end,
			Tooltip = 'This will reset your GUI back to default'
		})
		guipane:CreateButton({
			Name = 'Sort GUI',
			Function = function()
				local priority = {
					GUICategory = 1,
					CombatCategory = 2,
					BlatantCategory = 3,
					RenderCategory = 4,
					UtilityCategory = 5,
					WorldCategory = 6,
					InventoryCategory = 7,
					MinigamesCategory = 8,
					FriendsCategory = 9,
					ProfilesCategory = 10
				}
				local categories = {}
				for _, v in mainapi.Categories do
					if v.Type ~= 'Overlay' then
						table.insert(categories, v)
					end
				end
				table.sort(categories, function(a, b)
					return (priority[a.Object.Name] or 99) < (priority[b.Object.Name] or 99)
				end)

				local ind = 0
				for _, v in categories do
					if v.Object.Visible then
						v.Object.Position = UDim2.fromOffset(6 + (ind % 8 * 230), 60 + (ind > 7 and 360 or 0))
						ind += 1
					end
				end
			end,
			Tooltip = 'Sorts GUI'
		})

--[[
	Notification Settings
]]

		local notifpane = mainapi.Categories.Main:CreateSettingsPane({Name = 'Notifications'})
		mainapi.Notifications = notifpane:CreateToggle({
			Name = 'Notifications',
			Function = function(enabled)
				if mainapi.ToggleNotifications.Object then
					mainapi.ToggleNotifications.Object.Visible = enabled
				end
			end,
			Tooltip = 'Shows notifications',
			Default = true
		})
		mainapi.ToggleNotifications = notifpane:CreateToggle({
			Name = 'Toggle alert',
			Tooltip = 'Notifies you if a module is enabled/disabled.',
			Default = true,
			Darker = true
		})

		mainapi.GUIColor = mainapi.Categories.Main:CreateGUISlider({
			Name = 'GUI Theme',
			Function = function(h, s, v)
				mainapi:UpdateGUI(h, s, v, true)
			end
		})
		mainapi.Categories.Main:CreateBind()

--[[
	Text GUI
]]

		local textgui = mainapi:CreateOverlay({
			Name = 'Text GUI',
			Icon = 'rbxassetid://14368355456',
			Size = UDim2.fromOffset(16, 12),
			Position = UDim2.fromOffset(12, 14),
			Function = function()
				mainapi:UpdateTextGUI()
			end
		})
		local textguisort = textgui:CreateDropdown({
			Name = 'Sort',
			List = {'Alphabetical', 'Length'},
			Function = function()
				mainapi:UpdateTextGUI()
			end
		})
		local textguifont = textgui:CreateFont({
			Name = 'Font',
			Blacklist = 'Arial',
			Function = function()
				mainapi:UpdateTextGUI()
			end
		})
		local textguicolor
		local textguicolordrop = textgui:CreateDropdown({
			Name = 'Color Mode',
			List = {'Match GUI color', 'Custom color'},
			Function = function(val)
				textguicolor.Object.Visible = val == 'Custom color'
				mainapi:UpdateTextGUI()
			end
		})
		textguicolor = textgui:CreateColorSlider({
			Name = 'Text GUI color',
			Function = function()
				mainapi:UpdateGUI(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
			end,
			Darker = true,
			Visible = false
		})
		local VapeTextScale = Instance.new('UIScale')
		VapeTextScale.Parent = textgui.Children
		local textguiscale = textgui:CreateSlider({
			Name = 'Scale',
			Min = 0,
			Max = 2,
			Decimal = 10,
			Default = 1,
			Function = function(val)
				VapeTextScale.Scale = val
				mainapi:UpdateTextGUI()
			end
		})
		local textguishadow = textgui:CreateToggle({
			Name = 'Shadow',
			Tooltip = 'Renders shadowed text.',
			Function = function()
				mainapi:UpdateTextGUI()
			end
		})
		local textguigradientv4
		local textguigradient = textgui:CreateToggle({
			Name = 'Gradient',
			Tooltip = 'Renders a gradient',
			Function = function(callback)
				textguigradientv4.Object.Visible = callback
				mainapi:UpdateTextGUI()
			end
		})
		textguigradientv4 = textgui:CreateToggle({
			Name = 'V4 Gradient',
			Function = function()
				mainapi:UpdateTextGUI()
			end,
			Darker = true,
			Visible = false
		})
		local textguianimations = textgui:CreateToggle({
			Name = 'Animations',
			Tooltip = 'Use animations on text gui',
			Function = function()
				mainapi:UpdateTextGUI()
			end
		})
		local textguiwatermark = textgui:CreateToggle({
			Name = 'Watermark',
			Tooltip = 'Renders a lunar watermark',
			Function = function()
				mainapi:UpdateTextGUI()
			end
		})
		local textguibackgroundtransparency = {
			Value = 0.5,
			Object = {Visible = {}}
		}
		local textguibackgroundtint = {Enabled = false}
		local textguibackground = textgui:CreateToggle({
			Name = 'Render background',
			Function = function(callback)
				textguibackgroundtransparency.Object.Visible = callback
				textguibackgroundtint.Object.Visible = callback
				mainapi:UpdateTextGUI()
			end
		})
		textguibackgroundtransparency = textgui:CreateSlider({
			Name = 'Transparency',
			Min = 0,
			Max = 1,
			Default = 0.5,
			Decimal = 10,
			Function = function()
				mainapi:UpdateTextGUI()
			end,
			Darker = true,
			Visible = false
		})
		textguibackgroundtint = textgui:CreateToggle({
			Name = 'Tint',
			Function = function()
				mainapi:UpdateTextGUI()
			end,
			Darker = true,
			Visible = false
		})
		local textguimoduleslist
		local textguimodules = textgui:CreateToggle({
			Name = 'Hide modules',
			Tooltip = 'Allows you to blacklist certain modules from being shown.',
			Function = function(enabled)
				textguimoduleslist.Object.Visible = enabled
				mainapi:UpdateTextGUI()
			end
		})
		textguimoduleslist = textgui:CreateTextList({
			Name = 'Blacklist',
			Tooltip = 'Name of module to hide.',
			Icon = 'rbxassetid://14385669108',
			Tab = 'rbxassetid://14385672881',
			TabSize = UDim2.fromOffset(21, 16),
			Color = Color3.fromRGB(250, 50, 56),
			Function = function()
				mainapi:UpdateTextGUI()
			end,
			Visible = false,
			Darker = true
		})
		local textguirender = textgui:CreateToggle({
			Name = 'Hide render',
			Function = function()
				mainapi:UpdateTextGUI()
			end
		})
		local textguibox
		local textguifontcustom
		local textguicolorcustomtoggle
		local textguicolorcustom
		local textguitext = textgui:CreateToggle({
			Name = 'Add custom text',
			Function = function(enabled)
				textguibox.Object.Visible = enabled
				textguifontcustom.Object.Visible = enabled
				textguicolorcustomtoggle.Object.Visible = enabled
				textguicolorcustom.Object.Visible = textguicolorcustomtoggle.Enabled and enabled
				mainapi:UpdateTextGUI()
			end
		})
		textguibox = textgui:CreateTextBox({
			Name = 'Custom text',
			Function = function()
				mainapi:UpdateTextGUI()
			end,
			Darker = true,
			Visible = false
		})
		textguifontcustom = textgui:CreateFont({
			Name = 'Custom Font',
			Blacklist = 'Arial',
			Function = function()
				mainapi:UpdateTextGUI()
			end,
			Darker = true,
			Visible = false
		})
		textguicolorcustomtoggle = textgui:CreateToggle({
			Name = 'Set custom text color',
			Function = function(enabled)
				textguicolorcustom.Object.Visible = enabled
				mainapi:UpdateGUI(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
			end,
			Darker = true,
			Visible = false
		})
		textguicolorcustom = textgui:CreateColorSlider({
			Name = 'Color of custom text',
			Function = function()
				mainapi:UpdateGUI(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value)
			end,
			Darker = true,
			Visible = false
		})

--[[
	Text GUI Objects
]]

		local VapeLabels = {}
		local VapeLogo = Instance.new('ImageLabel')
		VapeLogo.Name = 'Logo'
		VapeLogo.Size = UDim2.fromOffset(80, 21)
		VapeLogo.Position = UDim2.new(1, -142, 0, 3)
		VapeLogo.BackgroundTransparency = 1
		VapeLogo.BorderSizePixel = 0
		VapeLogo.Visible = false
		VapeLogo.BackgroundColor3 = Color3.new()
		VapeLogo.Image = "rbxassetid://135550237842239"
		VapeLogo.Parent = textgui.Children

		local lastside = textgui.Children.AbsolutePosition.X > (gui.AbsoluteSize.X / 2)
		mainapi:Clean(textgui.Children:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
			if mainapi.ThreadFix then
				setthreadidentity(8)
			end
			local newside = textgui.Children.AbsolutePosition.X > (gui.AbsoluteSize.X / 2)
			if lastside ~= newside then
				lastside = newside
				mainapi:UpdateTextGUI()
			end
		end))

		local VapeLogoV4 = Instance.new('ImageLabel')
		VapeLogoV4.Name = 'Logo2'
		VapeLogoV4.Size = UDim2.fromOffset(33, 18)
		VapeLogoV4.Position = UDim2.new(1, 1, 0, 1)
		VapeLogoV4.BackgroundColor3 = Color3.new()
		VapeLogoV4.BackgroundTransparency = 1
		VapeLogoV4.BorderSizePixel = 0
		VapeLogoV4.Image = "rbxassetid://14368357095"
		VapeLogoV4.Parent = VapeLogo
		local VapeLogoShadow = VapeLogo:Clone()
		VapeLogoShadow.Position = UDim2.fromOffset(1, 1)
		VapeLogoShadow.ZIndex = 0
		VapeLogoShadow.Visible = true
		VapeLogoShadow.ImageColor3 = Color3.new()
		VapeLogoShadow.ImageTransparency = 0.65
		VapeLogoShadow.Parent = VapeLogo
		VapeLogoShadow.Logo2.ZIndex = 0
		VapeLogoShadow.Logo2.ImageColor3 = Color3.new()
		VapeLogoShadow.Logo2.ImageTransparency = 0.65
		local VapeLogoGradient = Instance.new('UIGradient')
		VapeLogoGradient.Rotation = 90
		VapeLogoGradient.Parent = VapeLogo
		local VapeLogoGradient2 = Instance.new('UIGradient')
		VapeLogoGradient2.Rotation = 90
		VapeLogoGradient2.Parent = VapeLogoV4
		local VapeLabelCustom = Instance.new('TextLabel')
		VapeLabelCustom.Position = UDim2.fromOffset(5, 2)
		VapeLabelCustom.BackgroundTransparency = 1
		VapeLabelCustom.BorderSizePixel = 0
		VapeLabelCustom.Visible = false
		VapeLabelCustom.Text = ''
		VapeLabelCustom.TextSize = 25
		VapeLabelCustom.FontFace = textguifontcustom.Value
		VapeLabelCustom.RichText = true
		local VapeLabelCustomShadow = VapeLabelCustom:Clone()
		VapeLabelCustom:GetPropertyChangedSignal('Position'):Connect(function()
			VapeLabelCustomShadow.Position = UDim2.new(
				VapeLabelCustom.Position.X.Scale,
				VapeLabelCustom.Position.X.Offset + 1,
				0,
				VapeLabelCustom.Position.Y.Offset + 1
			)
		end)
		VapeLabelCustom:GetPropertyChangedSignal('FontFace'):Connect(function()
			VapeLabelCustomShadow.FontFace = VapeLabelCustom.FontFace
		end)
		VapeLabelCustom:GetPropertyChangedSignal('Text'):Connect(function()
			VapeLabelCustomShadow.Text = removeTags(VapeLabelCustom.Text)
		end)
		VapeLabelCustom:GetPropertyChangedSignal('Size'):Connect(function()
			VapeLabelCustomShadow.Size = VapeLabelCustom.Size
		end)
		VapeLabelCustomShadow.TextColor3 = Color3.new()
		VapeLabelCustomShadow.TextTransparency = 0.65
		VapeLabelCustomShadow.Parent = textgui.Children
		VapeLabelCustom.Parent = textgui.Children
		local VapeLabelHolder = Instance.new('Frame')
		VapeLabelHolder.Name = 'Holder'
		VapeLabelHolder.Size = UDim2.fromScale(1, 1)
		VapeLabelHolder.Position = UDim2.fromOffset(5, 37)
		VapeLabelHolder.BackgroundTransparency = 1
		VapeLabelHolder.Parent = textgui.Children
		local VapeLabelSorter = Instance.new('UIListLayout')
		VapeLabelSorter.HorizontalAlignment = Enum.HorizontalAlignment.Right
		VapeLabelSorter.VerticalAlignment = Enum.VerticalAlignment.Top
		VapeLabelSorter.SortOrder = Enum.SortOrder.LayoutOrder
		VapeLabelSorter.Parent = VapeLabelHolder

--[[
	Target Info
]]

		local targetinfo
		local targetinfoobj
		local targetinfobcolor
		targetinfoobj = mainapi:CreateOverlay({
			Name = 'Target Info',
			Icon = 'rbxassetid://14368354234',
			Size = UDim2.fromOffset(14, 14),
			Position = UDim2.fromOffset(12, 14),
			CategorySize = 240,
			Function = function(callback)
				if callback then
					task.spawn(function()
						repeat
							targetinfo:UpdateInfo()
							task.wait()
						until not targetinfoobj.Button or not targetinfoobj.Button.Enabled
					end)
				end
			end
		})

		local targetinfobkg = Instance.new('Frame')
		targetinfobkg.Size = UDim2.fromOffset(240, 89)
		targetinfobkg.BackgroundColor3 = color.Dark(uipallet.Main, 0.1)
		targetinfobkg.BackgroundTransparency = 0.5
		targetinfobkg.Parent = targetinfoobj.Children
		local targetinfoblurobj = addBlur(targetinfobkg)
		targetinfoblurobj.Visible = false
		addCorner(targetinfobkg)
		local targetinfoshot = Instance.new('ImageLabel')
		targetinfoshot.Size = UDim2.fromOffset(26, 27)
		targetinfoshot.Position = UDim2.fromOffset(19, 17)
		targetinfoshot.BackgroundColor3 = uipallet.Main
		targetinfoshot.Image = 'rbxthumb://type=AvatarHeadShot&id=1&w=420&h=420'
		targetinfoshot.Parent = targetinfobkg
		local targetinfoshotflash = Instance.new('Frame')
		targetinfoshotflash.Size = UDim2.fromScale(1, 1)
		targetinfoshotflash.BackgroundTransparency = 1
		targetinfoshotflash.BackgroundColor3 = Color3.new(1, 0, 0)
		targetinfoshotflash.Parent = targetinfoshot
		addCorner(targetinfoshotflash)
		local targetinfoshotblur = addBlur(targetinfoshot)
		targetinfoshotblur.Visible = false
		addCorner(targetinfoshot)
		local targetinfoname = Instance.new('TextLabel')
		targetinfoname.Size = UDim2.fromOffset(145, 20)
		targetinfoname.Position = UDim2.fromOffset(54, 20)
		targetinfoname.BackgroundTransparency = 1
		targetinfoname.Text = 'Target name'
		targetinfoname.TextXAlignment = Enum.TextXAlignment.Left
		targetinfoname.TextYAlignment = Enum.TextYAlignment.Top
		targetinfoname.TextScaled = true
		targetinfoname.TextColor3 = color.Light(uipallet.Text, 0.4)
		targetinfoname.TextStrokeTransparency = 1
		targetinfoname.FontFace = uipallet.Font
		local targetinfoshadow = targetinfoname:Clone()
		targetinfoshadow.Position = UDim2.fromOffset(55, 21)
		targetinfoshadow.TextColor3 = Color3.new()
		targetinfoshadow.TextTransparency = 0.65
		targetinfoshadow.Visible = false
		targetinfoshadow.Parent = targetinfobkg
		targetinfoname:GetPropertyChangedSignal('Size'):Connect(function()
			targetinfoshadow.Size = targetinfoname.Size
		end)
		targetinfoname:GetPropertyChangedSignal('Text'):Connect(function()
			targetinfoshadow.Text = targetinfoname.Text
		end)
		targetinfoname:GetPropertyChangedSignal('FontFace'):Connect(function()
			targetinfoshadow.FontFace = targetinfoname.FontFace
		end)
		targetinfoname.Parent = targetinfobkg
		local targetinfohealthbkg = Instance.new('Frame')
		targetinfohealthbkg.Name = 'HealthBKG'
		targetinfohealthbkg.Size = UDim2.fromOffset(200, 9)
		targetinfohealthbkg.Position = UDim2.fromOffset(20, 56)
		targetinfohealthbkg.BackgroundColor3 = uipallet.Main
		targetinfohealthbkg.BorderSizePixel = 0
		targetinfohealthbkg.Parent = targetinfobkg
		addCorner(targetinfohealthbkg, UDim.new(1, 0))
		local targetinfohealth = targetinfohealthbkg:Clone()
		targetinfohealth.Size = UDim2.fromScale(0.8, 1)
		targetinfohealth.Position = UDim2.new()
		targetinfohealth.BackgroundColor3 = Color3.fromHSV(1 / 2.5, 0.89, 0.75)
		targetinfohealth.Parent = targetinfohealthbkg
		targetinfohealth:GetPropertyChangedSignal('Size'):Connect(function()
			targetinfohealth.Visible = targetinfohealth.Size.X.Scale > 0.01
		end)
		local targetinfohealthextra = targetinfohealth:Clone()
		targetinfohealthextra.Size = UDim2.new()
		targetinfohealthextra.Position = UDim2.fromScale(1, 0)
		targetinfohealthextra.AnchorPoint = Vector2.new(1, 0)
		targetinfohealthextra.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
		targetinfohealthextra.Visible = false
		targetinfohealthextra.Parent = targetinfohealthbkg
		targetinfohealthextra:GetPropertyChangedSignal('Size'):Connect(function()
			targetinfohealthextra.Visible = targetinfohealthextra.Size.X.Scale > 0.01
		end)
		local targetinfohealthblur = addBlur(targetinfohealthbkg)
		targetinfohealthblur.SliceCenter = Rect.new(52, 31, 261, 510)
		targetinfohealthblur.ImageColor3 = Color3.new()
		targetinfohealthblur.Visible = false
		local targetinfob = Instance.new('UIStroke')
		targetinfob.Enabled = false
		targetinfob.Color = Color3.fromHSV(0.44, 1, 1)
		targetinfob.Parent = targetinfobkg

		targetinfoobj:CreateFont({
			Name = 'Font',
			Blacklist = 'Arial',
			Function = function(val)
				targetinfoname.FontFace = val
			end
		})
		local targetinfobackgroundtransparency = {
			Value = 0.5,
			Object = {Visible = {}}
		}
		local targetinfodisplay = targetinfoobj:CreateToggle({
			Name = 'Use Displayname',
			Default = true
		})
		targetinfoobj:CreateToggle({
			Name = 'Render Background',
			Function = function(callback)
				targetinfobkg.BackgroundTransparency = callback and targetinfobackgroundtransparency.Value or 1
				targetinfoshadow.Visible = not callback
				targetinfoblurobj.Visible = callback
				targetinfohealthblur.Visible = not callback
				targetinfoshotblur.Visible = not callback
				targetinfobackgroundtransparency.Object.Visible = callback
			end,
			Default = true
		})
		targetinfobackgroundtransparency = targetinfoobj:CreateSlider({
			Name = 'Transparency',
			Min = 0,
			Max = 1,
			Default = 0.5,
			Decimal = 10,
			Function = function(val)
				targetinfobkg.BackgroundTransparency = val
			end,
			Darker = true
		})
		local targetinfocolor
		local targetinfocolortoggle = targetinfoobj:CreateToggle({
			Name = 'Custom Color',
			Function = function(callback)
				targetinfocolor.Object.Visible = callback
				if callback then
					targetinfobkg.BackgroundColor3 = Color3.fromHSV(targetinfocolor.Hue, targetinfocolor.Sat, targetinfocolor.Value)
					targetinfoshot.BackgroundColor3 = Color3.fromHSV(targetinfocolor.Hue, targetinfocolor.Sat, math.max(targetinfocolor.Value - 0.1, 0.075))
					targetinfohealthbkg.BackgroundColor3 = targetinfoshot.BackgroundColor3
				else
					targetinfobkg.BackgroundColor3 = color.Dark(uipallet.Main, 0.1)
					targetinfoshot.BackgroundColor3 = uipallet.Main
					targetinfohealthbkg.BackgroundColor3 = uipallet.Main
				end
			end
		})
		targetinfocolor = targetinfoobj:CreateColorSlider({
			Name = 'Color',
			Function = function(hue, sat, val)
				if targetinfocolortoggle.Enabled then
					targetinfobkg.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
					targetinfoshot.BackgroundColor3 = Color3.fromHSV(hue, sat, math.max(val - 0.1, 0))
					targetinfohealthbkg.BackgroundColor3 = targetinfoshot.BackgroundColor3
				end
			end,
			Darker = true,
			Visible = false
		})
		targetinfoobj:CreateToggle({
			Name = 'Border',
			Function = function(callback)
				targetinfob.Enabled = callback
				targetinfobcolor.Object.Visible = callback
			end
		})
		targetinfobcolor = targetinfoobj:CreateColorSlider({
			Name = 'Border Color',
			Function = function(hue, sat, val, opacity)
				targetinfob.Color = Color3.fromHSV(hue, sat, val)
				targetinfob.Transparency = 1 - opacity
			end,
			Darker = true,
			Visible = false
		})

		local lasthealth = 0
		local lastmaxhealth = 0
		targetinfo = {
			Targets = {},
			Object = targetinfobkg,
			UpdateInfo = function(self)
				local entitylib = mainapi.Libraries
				if not entitylib then return end

				for i, v in self.Targets do
					if v < tick() then
						self.Targets[i] = nil
					end
				end

				local v, highest = nil, tick()
				for i, check in self.Targets do
					if check > highest then
						v = i
						highest = check
					end
				end

				targetinfobkg.Visible = v ~= nil or mainapi.gui.ScaledGui.ClickGui.Visible
				if v then
					targetinfoname.Text = v.Player and (targetinfodisplay.Enabled and v.Player.DisplayName or v.Player.Name) or v.Character and v.Character.Name or targetinfoname.Text
					targetinfoshot.Image = 'rbxthumb://type=AvatarHeadShot&id='..(v.Player and v.Player.UserId or 1)..'&w=420&h=420'

					if not v.Character then
						v.Health = v.Health or 0
						v.MaxHealth = v.MaxHealth or 100
					end

					if v.Health ~= lasthealth or v.MaxHealth ~= lastmaxhealth then
						local percent = math.max(v.Health / v.MaxHealth, 0)
						tween:Tween(targetinfohealth, TweenInfo.new(0.3), {
							Size = UDim2.fromScale(math.min(percent, 1), 1), BackgroundColor3 = Color3.fromHSV(math.clamp(percent / 2.5, 0, 1), 0.89, 0.75)
						})
						tween:Tween(targetinfohealthextra, TweenInfo.new(0.3), {
							Size = UDim2.fromScale(math.clamp(percent - 1, 0, 0.8), 1)
						})
						if lasthealth > v.Health and self.LastTarget == v then
							tween:Cancel(targetinfoshotflash)
							targetinfoshotflash.BackgroundTransparency = 0.3
							tween:Tween(targetinfoshotflash, TweenInfo.new(0.5), {
								BackgroundTransparency = 1
							})
						end
						lasthealth = v.Health
						lastmaxhealth = v.MaxHealth
					end

					if not v.Character then table.clear(v) end
					self.LastTarget = v
				end
				return v
			end
		}
		mainapi.Libraries.targetinfo = targetinfo

		function mainapi:UpdateTextGUI(afterload)
			if not afterload and not mainapi.Loaded then return end
			if textgui.Button.Enabled then
				local right = textgui.Children.AbsolutePosition.X > (gui.AbsoluteSize.X / 2)
				VapeLogo.Visible = textguiwatermark.Enabled
				VapeLogo.Position = right and UDim2.new(1 / VapeTextScale.Scale, -113, 0, 6) or UDim2.fromOffset(0, 6)
				VapeLogoShadow.Visible = textguishadow.Enabled
				VapeLabelCustom.Text = textguibox.Value
				VapeLabelCustom.FontFace = textguifontcustom.Value
				VapeLabelCustom.Visible = VapeLabelCustom.Text ~= '' and textguitext.Enabled
				VapeLabelCustomShadow.Visible = VapeLabelCustom.Visible and textguishadow.Enabled
				VapeLabelSorter.HorizontalAlignment = right and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left
				VapeLabelHolder.Size = UDim2.fromScale(1 / VapeTextScale.Scale, 1)
				VapeLabelHolder.Position = UDim2.fromOffset(right and 3 or 0, 11 + (VapeLogo.Visible and VapeLogo.Size.Y.Offset or 0) + (VapeLabelCustom.Visible and 28 or 0) + (textguibackground.Enabled and 3 or 0))
				if VapeLabelCustom.Visible then
					local size = getfontsize(removeTags(VapeLabelCustom.Text), VapeLabelCustom.TextSize, VapeLabelCustom.FontFace)
					VapeLabelCustom.Size = UDim2.fromOffset(size.X, size.Y)
					VapeLabelCustom.Position = UDim2.new(right and 1 / VapeTextScale.Scale or 0, right and -size.X or 0, 0, (VapeLogo.Visible and 32 or 8))
				end

				local found = {}
				for _, v in VapeLabels do
					if v.Enabled then
						table.insert(found, v.Object.Name)
					end
					v.Object:Destroy()
				end
				table.clear(VapeLabels)

				local info = TweenInfo.new(0.3, Enum.EasingStyle.Exponential)
				for i, v in mainapi.Modules do
					if textguimodules.Enabled and table.find(textguimoduleslist.ListEnabled, i) then continue end
					if textguirender.Enabled and v.Category == 'Render' then continue end
					if v.Enabled or table.find(found, i) then
						local holder = Instance.new('Frame')
						holder.Name = i
						holder.Size = UDim2.fromOffset()
						holder.BackgroundTransparency = 1
						holder.ClipsDescendants = true
						holder.Parent = VapeLabelHolder
						local holderbackground
						local holdercolorline
						if textguibackground.Enabled then
							holderbackground = Instance.new('Frame')
							holderbackground.Size = UDim2.new(1, 3, 1, 0)
							holderbackground.BackgroundColor3 = color.Dark(uipallet.Main, 0.15)
							holderbackground.BackgroundTransparency = textguibackgroundtransparency.Value
							holderbackground.BorderSizePixel = 0
							holderbackground.Parent = holder
							local holderline = Instance.new('Frame')
							holderline.Size = UDim2.new(1, 0, 0, 1)
							holderline.Position = UDim2.new(0, 0, 1, -1)
							holderline.BackgroundColor3 = Color3.new()
							holderline.BackgroundTransparency = 0.928 + (0.072 * math.clamp((textguibackgroundtransparency.Value - 0.5) / 0.5, 0, 1))
							holderline.BorderSizePixel = 0
							holderline.Parent = holderbackground
							local holderline2 = holderline:Clone()
							holderline2.Name = 'Line'
							holderline2.Position = UDim2.new()
							holderline2.Parent = holderbackground
							holdercolorline = Instance.new('Frame')
							holdercolorline.Size = UDim2.new(0, 2, 1, 0)
							holdercolorline.Position = right and UDim2.new(1, -5, 0, 0) or UDim2.new()
							holdercolorline.BorderSizePixel = 0
							holdercolorline.Parent = holderbackground
						end
						local holdertext = Instance.new('TextLabel')
						holdertext.Position = UDim2.fromOffset(right and 3 or 6, 2)
						holdertext.BackgroundTransparency = 1
						holdertext.BorderSizePixel = 0
						holdertext.Text = i..(v.ExtraText and " <font color='#A8A8A8'>"..v.ExtraText()..'</font>' or '')
						holdertext.TextSize = 15
						holdertext.FontFace = textguifont.Value
						holdertext.RichText = true
						local size = getfontsize(removeTags(holdertext.Text), holdertext.TextSize, holdertext.FontFace)
						holdertext.Size = UDim2.fromOffset(size.X, size.Y)
						if textguishadow.Enabled then
							local holderdrop = holdertext:Clone()
							holderdrop.Position = UDim2.fromOffset(holdertext.Position.X.Offset + 1, holdertext.Position.Y.Offset + 1)
							holderdrop.Text = removeTags(holdertext.Text)
							holderdrop.TextColor3 = Color3.new()
							holderdrop.Parent = holder
						end
						holdertext.Parent = holder
						local holdersize = UDim2.fromOffset(size.X + 10, size.Y + (textguibackground.Enabled and 5 or 3))
						if textguianimations.Enabled then
							if not table.find(found, i) then
								tween:Tween(holder, info, {
									Size = holdersize
								})
							else
								holder.Size = holdersize
								if not v.Enabled then
									tween:Tween(holder, info, {
										Size = UDim2.fromOffset()
									})
								end
							end
						else
							holder.Size = v.Enabled and holdersize or UDim2.fromOffset()
						end
						table.insert(VapeLabels, {
							Object = holder,
							Text = holdertext,
							Background = holderbackground,
							Color = holdercolorline,
							Enabled = v.Enabled
						})
					end
				end

				if textguisort.Value == 'Alphabetical' then
					table.sort(VapeLabels, function(a, b)
						return a.Text.Text < b.Text.Text
					end)
				else
					table.sort(VapeLabels, function(a, b)
						return a.Text.Size.X.Offset > b.Text.Size.X.Offset
					end)
				end

				for i, v in VapeLabels do
					if v.Color then
						v.Color.Parent.Line.Visible = i ~= 1
					end
					v.Object.LayoutOrder = i
				end
			end

			mainapi:UpdateGUI(mainapi.GUIColor.Hue, mainapi.GUIColor.Sat, mainapi.GUIColor.Value, true)
		end

		function mainapi:UpdateGUI(hue, sat, val, default)
			if mainapi.Loaded == nil then return end
			if not default and mainapi.GUIColor.Rainbow then return end
			if textgui.Button.Enabled then
				VapeLogoGradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
					ColorSequenceKeypoint.new(1, textguigradient.Enabled and Color3.fromHSV(mainapi:Color((hue - 0.075) % 1)) or Color3.fromHSV(hue, sat, val))
				})
				VapeLogoGradient2.Color = textguigradient.Enabled and textguigradientv4.Enabled and VapeLogoGradient.Color or ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
					ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1))
				})
				VapeLabelCustom.TextColor3 = textguicolorcustomtoggle.Enabled and Color3.fromHSV(textguicolorcustom.Hue, textguicolorcustom.Sat, textguicolorcustom.Value) or VapeLogoGradient.Color.Keypoints[2].Value

				local customcolor = textguicolordrop.Value == 'Custom color' and Color3.fromHSV(textguicolor.Hue, textguicolor.Sat, textguicolor.Value) or nil
				for i, v in VapeLabels do
					v.Text.TextColor3 = customcolor or (mainapi.GUIColor.Rainbow and Color3.fromHSV(mainapi:Color((hue - ((textguigradient and i + 2 or i) * 0.025)) % 1)) or VapeLogoGradient.Color.Keypoints[2].Value)
					if v.Color then
						v.Color.BackgroundColor3 = v.Text.TextColor3
					end
					if textguibackgroundtint.Enabled and v.Background then
						v.Background.BackgroundColor3 = color.Dark(v.Text.TextColor3, 0.75)
					end
				end
			end

			if not clickgui.Visible and not mainapi.Legit.Window.Visible then return end
			local rainbow = mainapi.GUIColor.Rainbow and mainapi.RainbowMode.Value ~= 'Retro'

			for i, v in mainapi.Categories do
				if i == 'Main' then
					v.Object.VapeLogo.V4Logo.ImageColor3 = Color3.fromHSV(hue, sat, val)
					for _, button in v.Buttons do
						if button.Enabled then
							button.Object.TextColor3 = rainbow and Color3.fromHSV(mainapi:Color((hue - (button.Index * 0.025)) % 1)) or Color3.fromHSV(hue, sat, val)
							if button.Icon then
								button.Icon.ImageColor3 = button.Object.TextColor3
							end
						end
					end
				end

				if v.Options then
					for _, option in v.Options do
						if option.Color then
							option:Color(hue, sat, val, rainbow)
						end
					end
				end

				if v.Type == 'CategoryList' then
					v.Object.Children.Add.AddButton.ImageColor3 = rainbow and Color3.fromHSV(mainapi:Color(hue % 1)) or Color3.fromHSV(hue, sat, val)
					if v.Selected then
						v.Selected.BackgroundColor3 = rainbow and Color3.fromHSV(mainapi:Color(hue % 1)) or Color3.fromHSV(hue, sat, val)
						v.Selected.Title.TextColor3 = mainapi.GUIColor.Rainbow and Color3.new(0.19, 0.19, 0.19) or mainapi:TextColor(hue, sat, val)
						v.Selected.Dots.Dots.ImageColor3 = v.Selected.Title.TextColor3
						v.Selected.Bind.Icon.ImageColor3 = v.Selected.Title.TextColor3
						v.Selected.Bind.TextLabel.TextColor3 = v.Selected.Title.TextColor3
					end
				end
			end

			for _, button in mainapi.Modules do
				if button.Enabled then
					button.Object.BackgroundColor3 = rainbow and Color3.fromHSV(mainapi:Color((hue - (button.Index * 0.025)) % 1)) or Color3.fromHSV(hue, sat, val)
					button.Object.TextColor3 = mainapi.GUIColor.Rainbow and Color3.new(0.19, 0.19, 0.19) or mainapi:TextColor(hue, sat, val)
					button.Object.UIGradient.Enabled = rainbow and mainapi.RainbowMode.Value == 'Gradient'
					if button.Object.UIGradient.Enabled then
						button.Object.BackgroundColor3 = Color3.new(1, 1, 1)
						button.Object.UIGradient.Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromHSV(mainapi:Color((hue - (button.Index * 0.025)) % 1))),
							ColorSequenceKeypoint.new(1, Color3.fromHSV(mainapi:Color((hue - ((button.Index + 1) * 0.025)) % 1)))
						})
					end
					button.Object.Bind.Icon.ImageColor3 = button.Object.TextColor3
					button.Object.Bind.TextLabel.TextColor3 = button.Object.TextColor3
					button.Object.Dots.Dots.ImageColor3 = button.Object.TextColor3
				end

				for _, option in button.Options do
					if option.Color then
						option:Color(hue, sat, val, rainbow)
					end
				end
			end

			for i, v in mainapi.Overlays.Toggles do
				if v.Enabled then
					tween:Cancel(v.Object.Knob)
					v.Object.Knob.BackgroundColor3 = rainbow and Color3.fromHSV(mainapi:Color((hue - (i * 0.075)) % 1)) or Color3.fromHSV(hue, sat, val)
				end
			end

			if mainapi.Legit.Icon then
				mainapi.Legit.Icon.ImageColor3 = Color3.fromHSV(hue, sat, val)
			end

			if mainapi.Legit.Window.Visible then
				for _, v in mainapi.Legit.Modules do
					if v.Enabled then
						tween:Cancel(v.Object.Knob)
						v.Object.Knob.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
					end

					for _, option in v.Options do
						if option.Color then
							option:Color(hue, sat, val, rainbow)
						end
					end
				end
			end
		end

		mainapi:Clean(notifications.ChildRemoved:Connect(function()
			for i, v in notifications:GetChildren() do
				if tween.Tween then
					tween:Tween(v, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {
						Position = UDim2.new(1, 0, 1, -(29 + (78 * i)))
					})
				end
			end
		end))

		mainapi:Clean(inputService.InputBegan:Connect(function(inputObj)
			if not inputService:GetFocusedTextBox() and inputObj.KeyCode ~= Enum.KeyCode.Unknown then
				table.insert(mainapi.HeldKeybinds, inputObj.KeyCode.Name)
				if mainapi.Binding then return end

				if checkKeybinds(mainapi.HeldKeybinds, mainapi.Keybind, inputObj.KeyCode.Name) then
					if mainapi.ThreadFix then
						setthreadidentity(8)
					end
					for _, v in mainapi.Windows do
						v.Visible = false
					end
					clickgui.Visible = not clickgui.Visible
					tooltip.Visible = false
					mainapi:BlurCheck()
				end

				local toggled = false
				for i, v in mainapi.Modules do
					if checkKeybinds(mainapi.HeldKeybinds, v.Bind, inputObj.KeyCode.Name) then
						toggled = true
						if mainapi.ToggleNotifications.Enabled then
							mainapi:CreateNotification('Module Toggled', i.."<font color='#FFFFFF'> has been </font>"..(not v.Enabled and "<font color='#5AFF5A'>Enabled</font>" or "<font color='#FF5A5A'>Disabled</font>").."<font color='#FFFFFF'>!</font>", 0.75)
						end
						v:Toggle(true)
					end
				end
				if toggled then
					mainapi:UpdateTextGUI()
				end

				for _, v in mainapi.Profiles do
					if checkKeybinds(mainapi.HeldKeybinds, v.Bind, inputObj.KeyCode.Name) and v.Name ~= mainapi.Profile then
						mainapi:Save(v.Name)
						mainapi:Load(true)
						break
					end
				end
			end
		end))

		mainapi:Clean(inputService.InputEnded:Connect(function(inputObj)
			if not inputService:GetFocusedTextBox() and inputObj.KeyCode ~= Enum.KeyCode.Unknown then
				if mainapi.Binding then
					if not mainapi.MultiKeybind.Enabled then
						mainapi.HeldKeybinds = {inputObj.KeyCode.Name}
					end
					mainapi.Binding:SetBind(checkKeybinds(mainapi.HeldKeybinds, mainapi.Binding.Bind, inputObj.KeyCode.Name) and {} or mainapi.HeldKeybinds, true)
					mainapi.Binding = nil
				end
			end

			local ind = table.find(mainapi.HeldKeybinds, inputObj.KeyCode.Name)
			if ind then
				table.remove(mainapi.HeldKeybinds, ind)
			end
		end))

		return mainapi
	end,
}

repeat task.wait() until game:IsLoaded()
if shared.vape then shared.vape:Uninject() end

-- why do exploits fail to implement anything correctly? Is it really that hard?
if identifyexecutor then
	if table.find({'Argon', 'Wave'}, ({identifyexecutor()})[1]) then
		getgenv().setthreadidentity = nil
	end
end

local vape
local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then
		vape:CreateNotification('Lunar', 'Failed to load : '..err, 30, 'alert')
	end
	return res
end
local queue_on_teleport = queue_on_teleport or function() end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local cloneref = cloneref or function(obj)
	return obj
end
local playersService = cloneref(game:GetService('Players'))

local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/xylex1/LunarClient/'..readfile('newlunar/profiles/commit.txt')..'/'..select(1, path:gsub('newlunar/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after lunar updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function finishLoading()
	vape.Init = nil
	vape:Load()
	task.spawn(function()
		repeat
			vape:Save()
			task.wait(10)
		until not vape.Loaded
	end)

	local teleportedServers
	vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
		if (not teleportedServers) and (not shared.VapeIndependent) then
			--teleportedServers = true
			--local teleportScript = [[
			--	shared.vapereload = true
			--	if shared.VapeDeveloper then
			--		loadstring(readfile('newlunar/loader.lua'), 'loader')()
			--	else
		--			loadstring(game:HttpGet('https://raw.githubusercontent.com/xylex1/LunarClient/'..readfile('newlunar/profiles/commit.txt')..'/loader.lua', true), 'loader')()
		--		end
		--	]]
		--	if shared.VapeDeveloper then
		--		teleportScript = 'shared.VapeDeveloper = true\n'..teleportScript
		--	end
		--	if shared.VapeCustomProfile then
		--		teleportScript = 'shared.VapeCustomProfile = "'..shared.VapeCustomProfile..'"\n'..teleportScript
		--	end
		--	vape:Save()
		--	queue_on_teleport(teleportScript)
		end
	end))

	if not shared.vapereload then
		if not vape.Categories then return end
		if vape.Categories.Main.Options['GUI bind indicator'].Enabled then
			vape:CreateNotification('Finished Loading', vape.VapeButton and 'Press the button in the top right to open GUI' or 'Press '..table.concat(vape.Keybind, ' + '):upper()..' to open GUI', 5)
		end
	end
end

if not isfile('newlunar/profiles/gui.txt') then
	writefile('newlunar/profiles/gui.txt', 'new')
end
local gui = readfile('newlunar/profiles/gui.txt')

if not isfolder('newlunar/assets/'..gui) then
	makefolder('newlunar/assets/'..gui)
end
vape = guis.new()
shared.vape = vape

if not shared.VapeIndependent then
	--loadstring(downloadFile('newlunar/games/universal.lua'), 'universal')()
	if isfile('newlunar/games/'..game.PlaceId..'.lua') then
		loadstring(readfile('newlunar/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))(...)
	else
		if not shared.VapeDeveloper then
			local suc, res = pcall(function()
				return game:HttpGet('https://raw.githubusercontent.com/xylex1/LunarClient/'..readfile('newlunar/profiles/commit.txt')..'/games/'..game.PlaceId..'.lua', true)
			end)
			if suc and res ~= '404: Not Found' then
				local gameId = game.PlaceId
				local fn = games[gameId]
				games["Universal"]()
				if fn then
					fn()
				else
					print("not supported")
				end
			end
		end
	end
	finishLoading()
else
	vape.Init = finishLoading
	return vape
end


local success, socket = pcall(function()
    return WebSocket.connect("wss://testthing-production.up.railway.app/")
end)

if success and socket then
    print("Connected to server!")

    -- Send registration only once
    socket:Send(HttpService:JSONEncode({
        command = "RegisterClient",
        data = { PlaceId = PlaceId, JobId = JobId, UserId = UserId, Username = Username }
    }))

    -- Command handlers
    local commands = {}
    commands["kick"] = function(args)
        if args.targetUserId == UserId or args.targetUsername == Username then
            Player:Kick(args.reason or "No reason provided")
        end
    end

    socket.OnMessage:Connect(function(message)
        local decoded = HttpService:JSONDecode(message)
        if decoded.command and commands[decoded.command] then
            commands[decoded.command](decoded.args)
        else
            print("Received:", decoded.response or message)
        end
    end)

    -- Heartbeat ping every 5 seconds
    task.spawn(function()
        while true do
            task.wait(5)
            socket:Send(HttpService:JSONEncode({ command = "ping" }))
        end
    end)
else
    warn("Failed to connect to WS")
end
