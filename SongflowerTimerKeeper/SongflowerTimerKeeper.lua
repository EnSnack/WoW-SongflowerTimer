-- - - - - - - - - - - - - - - - - - - - - - - - - -
-- PRE-ADDON STUFF
-- - - - - - - - - - - - - - - - - - - - - - - - - -

-- Global DB
_G.SongflowerTimerDB = _G.SongflowerTimerDB or {}

-- Local variables / arrays
--- Chat listener events
local chatEvents         = {
	["CHAT_MSG_GUILD"]   = true,
	["CHAT_MSG_WHISPER"] = true,
	["CHAT_MSG_RAID"]    = true,
	["CHAT_MSG_PARTY"]   = true,
	["CHAT_MSG_SAY"]     = true,
}

--- Chat command activators
--- **
local chatCommands  = {
	["!sf"]         = true,
	["!sft"]        = true,
	["!songflower"] = true,
	["!fp"]         = true,
}

--- Timezones
local timezone = {
	["est"]    = 0,
	["cst"]    = 3600,
	["mst"]    = 7200,
	["pst"]    = 10800,
}

--- Print errors
local errors = {
	"Missing argument!",
	"Wrong argument!",
}

--- Addon color palette
local palette = {
	"|cffffff1a",
	"|cffff1a1a",
	"|cff8dff1a",
}

local version               = "2.0.0"
local addonKey              = "SongflowerTimer"
local prefix                = "#SFT#: "

local SongflowerTimer       = {}
SongflowerTimer.remind      = {}
SongflowerTimer.reportid    = 1
SongflowerTimer.report      = 1
SongflowerTimer.countdown   = false
SongflowerTimer.cdtoggle    = false
SongflowerTimer.me          = (UnitName("Player"))
SongflowerTimer.duty        = true
SongflowerTimer.warning     = ""


SongflowerTimerDB.last      = 0
SongflowerTimerDB.next      = 0
SongflowerTimerDB.reporters = {}

-- Libraries
--local AceTimer   = LibStub("AceTimer-3.0")
local Serializer = LibStub("AceSerializer-3.0")
local AceComm    = LibStub("AceComm-3.0")

-- Create event frames
local SFTEVT = CreateFrame("FRAME")
--- OBLIGATORY
SFTEVT:RegisterEvent("ADDON_LOADED")
SFTEVT:RegisterEvent("PLAYER_LOGOUT")
--- CHAT
SFTEVT:RegisterEvent("CHAT_MSG_GUILD")
SFTEVT:RegisterEvent("CHAT_MSG_WHISPER")
SFTEVT:RegisterEvent("CHAT_MSG_RAID")
SFTEVT:RegisterEvent("CHAT_MSG_PARTY")
SFTEVT:RegisterEvent("CHAT_MSG_SAY")
--- COMBAT LOG
SFTEVT:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

-- - - - - - - - - - - - - - - - - - - - - - - - - -
-- FUNCTIONS
-- - - - - - - - - - - - - - - - - - - - - - - - - -
function SongflowerTimer:secondsToClock(timer)
    local a,b,c,d = 14400,86400,3600,60
	
    seconds = tonumber(timer-a)
    seconds = seconds-(math.floor(seconds/b)*b)
    hours   = math.floor(seconds/c)
    seconds = seconds-(hours*c)
    minutes = math.floor(seconds/d)
    seconds = math.floor(seconds-(minutes*d))
	
    return hours, minutes, seconds
end

function SongflowerTimer:clockToSeconds(timer)
	local a,b,c,d = 14400,86400,3600,60
	local x = GetServerTime()
	x = x - (x - (math.floor(x/b)*b))
	local h,m,s = strsplit(":",timer)
	x = x + (tonumber(h)*c) + (tonumber(m)*d) + tonumber(s)
	return x+a
end

function SongflowerTimer:ampm(h,m)
    local suffix = "AM"
	
    if h > 12 then
        h      = h%12
        suffix = "PM"
    end
	
    return h..":"..m..suffix
end

function SongflowerTimer:leadingZero(number)
    return number < 10 and "0"..number or number
end

function SongflowerTimer:sendTimer(curTimer,tz,c,p)
	if SongflowerTimer.duty then
		local found = false
		if type(tz) == "string" then
			for w,z in pairs(timezone) do
				if string.match(w, tz:lower()) then
					tz = z
					found = true
					break;
				end
			end
		end
		tz = not found and 0 or tz
		curTimer = 1500 - curTimer
		message,timer = "","UP!"
		if Stopwatch_IsPlaying() and curTimer > 0 then
		
			local function formatTimer(t)
				local h,m,s = SongflowerTimer:secondsToClock(t)
				return h..":"..SongflowerTimer:leadingZero(m)..":"..SongflowerTimer:leadingZero(s).." ("..SongflowerTimer:ampm(h,SongflowerTimer:leadingZero(m))..")"
			end

			local sftlast,sftnext = formatTimer(SongflowerTimerDB.last-tz),formatTimer(SongflowerTimerDB.next-tz)
			
			local minutes,seconds = SongflowerTimer:leadingZero(math.floor(curTimer/60)),SongflowerTimer:leadingZero(math.floor(curTimer%60))
			timer = minutes.."m "..seconds.."s"
											
			if approx then
				message = "Flower was picked at approximately: "..sftlast..", time left: "..timer..", expected next flower: "..sftnext
			else
				message = "Flower was picked at exactly: "..sftlast..", time left: "..timer..", next flower: "..sftnext
			end
					
		elseif curTimer < 0 then
			message = "Flower is "..timer
		else
			message = "No timer is currently running!"
		end
	else
		message = "Timer is currently off-duty, sorry for any inconvenience caused!"
	end
	if message ~= "" then
		SongflowerTimer:sendChatMessage(message,c,p)
		if SongflowerTimer.warning ~= "" then
			SongflowerTimer:sendChatMessage("!@! WARNING: "..SongflowerTimer.warning.." !@!",c,p)
		end
	end
end

function SongflowerTimer:errorHandler(c,err)
	if c ~= nil then
		return true
	else
		print(prefix..errors[err])
		return false
	end
end

function SongflowerTimer:sendChatMessage(msg,chn,p)
	chn = chn == nil and "EMOTE" or chn
	SendChatMessage(prefix..msg,chn,GetDefaultLanguage("Player"),p)
end

function SongflowerTimer:regain(lt,nt)
	StopwatchFrame:Show()
	Stopwatch_Play()
	if lt and string.find(lt, ":") then
		local x = SongflowerTimer:clockToSeconds(lt)
		SongflowerTimerDB.last,SongflowerTimerDB.next = x,x+1500
		lt = x
	elseif string.find(nt, ":") then
		local x = SongflowerTimer:clockToSeconds(nt)
		SongflowerTimerDB.last,SongflowerTimerDB.next = x-1500,x
		nt = x
	end
	if nt then
		StopwatchTicker.timer = 1500 - (nt - GetServerTime())
		return
	elseif lt then
		StopwatchTicker.timer = -(lt - GetServerTime())
		return
	end
end

function SongflowerTimer:normID()
	if next(SongflowerTimerDB.reporters) ~= nil then
		for w,z in pairs(SongflowerTimerDB.reporters) do
			if z == SongflowerTimer.me then
				SongflowerTimer.report = w
			end
		end
	end
end

function SongflowerTimer:reportTimer(e,p)
	--if next(SongflowerTimerDB.reporters) == nil or SongflowerTimerDB.reporters[SongflowerTimer.reportid] == SongflowerTimer.me then					  
		-- Send timer (based on stopwatch timer)
		--- + AceTimer?
		SongflowerTimer:sendTimer(StopwatchTicker.timer,0,e,p)
	--end
	--[[if next(SongflowerTimerDB.reporters) ~= nil and e == "EMOTE" then
		if SongflowerTimer.reportid < #SongflowerTimerDB.reporters then
			SongflowerTimer.reportid = SongflowerTimer.reportid + 1
		elseif SongflowerTimer.reportid >= #SongflowerTimerDB.reporters then
			SongflowerTimer.reportid = 1
		end
	end]]
end

-- - - - - - - - - - - - - - - - - - - - - - - - - -
-- ADDON MEAT
-- - - - - - - - - - - - - - - - - - - - - - - - - -
-- Event Handler
local function eventHandler(self, e, arg1, arg2, ...)

	if e == "PLAYER_LOGOUT" then
		local dest = (GetGuildInfo("player")) and "GUILD" or IsInRaid() and "RAID" or IsInGroup("LE_PARTY_CATEGORY_HOME") and "PARTY" or "SAY"
		AceComm:SendCommMessage(addonKey,"RMV",dest)
	end

	--------
	-- ADDON_LOADED
	--------
	-- Handles what to do when the addon loads
	--------
	if e == "ADDON_LOADED" then
		if arg1 == "SongflowerTimerKeeper" then
			local dest = (GetGuildInfo("player")) and "GUILD" or IsInRaid() and "RAID" or IsInGroup("LE_PARTY_CATEGORY_HOME") and "PARTY" or "SAY"
			AceComm:SendCommMessage(addonKey,"ADD",dest)
			-- ** TRY REQUEST IN PLAYER_ENTERING_WORLD INSTEAD?
			AceComm:SendCommMessage(addonKey,"RTV",dest)
			SFTEVT:UnregisterEvent("ADDON_LOADED")
		end
	end
	
	--------
	-- CHAT_MSG_*
	--------
	-- Handles communication from time keepers to users without the user weakaura
	--------
    if chatEvents[e] then
		local msg,p    = arg1:lower(),arg2
		local cmd,para = strsplit(" ",msg,2)
		local args     = (para ~= nil and { strsplit(" ",para) } or nil)
		local cmdl     = (args ~= nil and #args or 0)
				
		local timerq = msg:match("%f[%a]timer%?")
		
		_,_,e = strsplit("_",e)
		
		if not e or e == "SAY" then
			e = "EMOTE"
		end
		
		if chatCommands[cmd] then
			-- Get event to properly send to right channel
					
			--------
			-- !sf
			--------
			-- Posts the current timer.
			--------
			
			if cmdl == 0 then
				SongflowerTimer:reportTimer(e,p)
			elseif cmdl >= 1 then
			
				--------
				-- !sf timer/t [timezone]
				--------
				-- Posts the current timer converted to [timezone].
				--------   
				
				if (args[1] == "timer" or args[1] == "t") then
					if cmdl == 2 then
						SongflowerTimer:sendTimer(StopwatchTicker.timer,args[2],e,p)
					end

				--------
				-- !sf remind/r [timer]
				--------
				-- Reminds the user when there's [timer] left on the timer.
				--------    

				elseif (args[1] == "remind" or args[1] == "r") then 
				
					-- Uses correct format (2m or 2m30s)
				
					if cmdl == 2 or cmdl == 3 then
					
						local function formatRemind(o)
							local m = ""
							local r = 0
							for c in string.gmatch(o, "%S") do
								if c == "m" then
									m = tonumber(m) * 60
									r = r+m
									m = ""
								elseif c == "s" then
									m = tonumber(m)
									r = r+m
									break;
								else
									m = m..c
								end
							end
							return r
						end
						
						local message,input = "",""
						input = args[3] ~= nil and args[2]..args[3] or args[2]
						seconds = formatRemind(input)
						if seconds == nil then
							message = "Please input a correct time format. Example formats: 10m10s, 10m, 10s, 10m 10s"
						elseif seconds >= 1500 or seconds <= 0 then
							message = "Please input a correct time."
						else
							SongflowerTimer.remind[p] = seconds
							message = "You will be reminded when theres "..input.." left"
						end
						SongflowerTimer:sendChatMessage(message,"WHISPER",p)
					end

				--------
				-- !sf countdown/cd
				--------
				-- Counts down once when there's 30, 15, 5, 4, 3, 2 and 1 seconds left on the timer.
				--------  

				elseif (args[1] == "countdown" or args[1] == "cd") then
					if not SongflowerTimer.cdtoggle then
						SongflowerTimer.countdown = not SongflowerTimer.countdown
						SongflowerTimer:sendChatMessage("Countdown "..(SongflowerTimer.countdown and "enabled" or "disabled")..".")
					end
					
				--------
				-- !sf send/s [name]
				--------
				-- Sends current timer to [name] in whispers.
				--------  
				
				elseif (args[1] == "send" or args[1] == "s") then
					if (e ~= "CHAT_MSG_WHISPER" and next(SongflowerTimerDB.reporters) == nil or SongflowerTimerDB.reporters[SongflowerTimer.reportid] == SongflowerTimer.me) or e == "CHAT_MSG_WHISPER" then			
						SongflowerTimer:sendTimer(StopwatchTicker.timer,0,"WHISPER",args[2])
					end
				end
			end
			
			--------
			-- [...] timer?
			--------
			-- Posts the current timer.
			-- **
			-------- 
			
		elseif timerq then
			SongflowerTimer:reportTimer(e,p)
		end
	end
		
	--------
	-- COMBAT_LOG_EVENT_UNFILTERED
	--------
	-- Handles receiving (and/or starting) timer when Songflower Serenade is applied to a user nearby
	--------
	if e == "COMBAT_LOG_EVENT_UNFILTERED" and GetZoneText() == "Felwood" then
		local t,ce = CombatLogGetCurrentEventInfo()
		if ce == "SPELL_AURA_APPLIED" or ce == "SPELL_AURA_REFRESHED" then
			local spn = select(13, CombatLogGetCurrentEventInfo())
			if spn == "Songflower Serenade" and (not Stopwatch_IsPlaying() or StopwatchTicker.timer >= 1500) then
				
				-- START TIMER
				StopwatchTicker.timer = 0
				if not Stopwatch_IsPlaying() then
					Stopwatch_Play()
					StopwatchFrame:Show()
				end

				--C_ChatInfo.SendAddonMessage("SongflowerTimer","SEND,nil;"..StopwatchTicker.timer..","..message,"GUILD")
				SongflowerTimerDB.last,SongflowerTimerDB.next = GetServerTime(),GetServerTime()+1500
			end
		end
	end
end

-- Addon chat message handler
local function addonEvent(p,m,d,s)

	--[[
		Addon Message Handler Payloads:
		NAME        [ABR] - Description
		
		@  TYPES  @
		@@   G   @@
		RETRIEVE    [RTV] - Retrieve (and update) information from other clients.
		CHECK       [CHK] - Check information from other clients.
		
		@@   P   @@
		SEND        [SND] - Send information to other clients through whispers, ONLY requestable.
		- TIMER     [TMR] - Information about current timer.
		- REPORT    [REP] - Information about current report list.
		- COUNTDOWN [CDE] - Information about client's countdown status.
		ADD         [ADD] - Request to be added to the report list.
		REMOVE      [RMV] - Request to be removed from the report list.
	]]

	if p ~= addonKey then return end
	if s == SongflowerTimer.me then return end
	m = { strsplit(",",m,2) }
	local pType   = m[1]
	local payload = m[2] and { strsplit(",",m[2]) } or nil
	if d == "WHISPER" then
		-- we assume ptype is SEND because its the only one we send through whispers
		pType = payload[1]
		if pType == "TMR" and SongflowerTimerDB.last == 0 then
			local l,n = tonumber(payload[2]), tonumber(payload[3])
			SongflowerTimerDB.last,SongflowerTimerDB.next = l,n
			SongflowerTimer:regain(l,n)
		elseif pType == "REP" then
			local b,s = Serializer:Deserialize(payload[2])
			if b then
				SongflowerTimerDB.reporters = s
			end
			SongflowerTimer:normID()
		elseif pType == "CDE" then
			
		end
	end
	if pType == "RTV" then
		if SongflowerTimerDB.last ~= 0 or SongflowerTimerDB.next ~= 0 then
			AceComm:SendCommMessage(addonKey,"SND,TMR,"..SongflowerTimerDB.last..","..SongflowerTimerDB.next,"WHISPER",s)
		end
	elseif pType == "RMV" then
		for w,z in pairs(SongflowerTimerDB.reporters) do
			print(z)
			if z == s then
				table.remove(SongflowerTimerDB.reporters, w)
			end
		end
		SongflowerTimer:normID()
		if #SongflowerTimerDB.reporters == 1 then
			SongflowerTimerDB.reporters = {}
		end
	elseif pType == "ADD" then
		if next(SongflowerTimerDB.reporters) == nil then
			table.insert(SongflowerTimerDB.reporters, SongflowerTimer.me)
		end
		table.insert(SongflowerTimerDB.reporters, s)
		AceComm:SendCommMessage(addonKey,"SND,REP,"..Serializer:Serialize(SongflowerTimerDB.reporters),"WHISPER",s)
	end
end

AceComm:RegisterComm(addonKey, addonEvent)

local function StopwatchTicker_Update(s)
    local left = 1500-math.floor(s)
	
	-- Countdown
	
    if SongflowerTimer.countdown or SongflowerTimer.cdtoggle then
		if left == 60 then
			SongflowerTimer:sendChatMessage("Countdown is enabled for this flower. Countdown will start in 30 seconds.")
        elseif left == 30 or left == 15 or (left <= 5 and left > 0) then
            SongflowerTimer:sendChatMessage("Only "..left.." seconds remaining!")
		end
        if left == 1 then
			SongflowerTimer:sendChatMessage("Have a good raid and may you be blessed with lots of loot! Remember: tips are appreciated!")
			SongflowerTimer.countdown = SongflowerTimer.countdown and false
		end
    end
	
	-- Remind based on timer
	
	if next(SongflowerTimer.remind) ~= nil then
		for w,z in pairs(SongflowerTimer.remind) do
			if left-z == 0 then
				SongflowerTimer:sendChatMessage("Timer is up!", "WHISPER",w)
				SongflowerTimer.remind[w] = nil
			end
		end
	end
		
	-- Stop when timer finishes
	
    if left <= 0 then
        Stopwatch_Pause()
    end

	-- Informational message every 5m
	
	if (left ~= 1500 and left ~= 0) and left%300 == 0 then
		SongflowerTimer:sendChatMessage("Remember! You can type !sf to get the current timer! Tips are appreciated if you enjoy my service!")
	end
end

-- The number of seconds since the last update
local TimeSinceLastUpdate = 0
SFTEVT:SetScript("OnUpdate", function(self, elapsed)
	TimeSinceLastUpdate = TimeSinceLastUpdate + elapsed
	if TimeSinceLastUpdate >= 1 then
		TimeSinceLastUpdate = 0
		StopwatchTicker_Update(StopwatchTicker.timer)
	end
end)

SFTEVT:SetScript("OnEvent", eventHandler)

SFTEVT:SetScript("OnShow", function(self)
	TimeSinceLastUpdate = 0
end)

 -- Slash command(s)
SLASH_SONGFLOWERTIMERKEEPER1,SLASH_SONGFLOWERTIMERKEEPER2 = "/sftk", "/sfk"
function SlashCmdList.SONGFLOWERTIMERKEEPER(cmd, editbox)
	local args = { strsplit(" ",cmd) }
	if args[1] == "" or args[1] == "help" then
		local t = palette[1]
		local m = palette[2]
		local o = palette[3]
		print("=========== SongflowerTimerKeeper "..version.." ===========")
		print("Chat Commands: !sf (command)")
		print(t.."timer/t "..m.."[timezone]|r - Posts the current timer converted to [timezone].")
		print(t.."remind/r "..m.."[timer]|r - Reminds the user when there's [timer] left on the timer.")
		print(t.."countdown/cd|r - Counts down nearing the end of the timer.")
		print(t.."send/s "..m.."[name]|r - Sends current timer to [name] in whispers.")
		print(" ")
		print("Slash Commands: /sfk (command)")
		print(t.."timer "..m.."[next|last|clear] [timer]|r - Tries to regain a lost timer using the last/next pick timer.")
		print(t.."send "..m.."[name]|r - Sends current timer to [name] in whispers.")
		print(t.."cd "..o.."(toggle/t)|r - Counts down nearing the end of the timer.")
		print(t.."remindlist|r - Shows current list of players who have asked to be reminded.")
		print(t.."duty|r - Inform players that you are currently (not) keeping timer.")
		print(t.."warning "..m.."[warning|clear]|r - Gives players a [warning] after every use of the primary command. %t gives current time and %l copies last message.")
	elseif args[1] == "send" then
		if SongflowerTimer:errorHandler(args[2],1) then
			SongflowerTimer:sendTimer(StopwatchTicker.timer,0,"WHISPER",args[2])
		end
	elseif args[1] == "timer" then
		if args[2] == "next" then
			SongflowerTimer:regain(nil,args[3])
		elseif args[2] == "last" then
			SongflowerTimer:regain(args[3])
		elseif args[2] == "clear" then
			SongflowerTimerDB.last      = 0
			SongflowerTimerDB.next      = 0
			SongflowerTimerDB.STl       = ""
			StopwatchTicker.timer       = 0
			Stopwatch_Stop()
			print(prefix.."Data cleared!")
		end
	elseif args[1] == "cd" then
		if args[2] == nil then
			if not SongflowerTimer.cdtoggle then
				SongflowerTimer.countdown = not SongflowerTimer.countdown
				local x = (SongflowerTimer.countdown and "enabled" or "disabled")
				print(prefix.."SongflowerTimer Countdown "..x.." for one-time use!")
				SongflowerTimer:sendChatMessage("Countdown "..x..".")
			end
		elseif (args[2] == "toggle" or args[2] == "t") then
			SongflowerTimer.cdtoggle = not SongflowerTimer.cdtoggle
			print(prefix.."SongflowerTimer Countdown toggled "..(SongflowerTimer.cdtoggle and "on" or "off").."!")
		end
	elseif args[1] == "remindlist" then
		for w,z in pairs(SongflowerTimerDB.reporters) do
			print(w.." "..z)
		end
		if args[2] == "clear" then
			SongflowerTimerDB.reporters = {}
		end
	elseif args[1] == "duty" then
		SongflowerTimer.duty = not SongflowerTimer.duty
		print(prefix.."You are currently "..(SongflowerTimer.duty and "on duty" or "off duty").."!")
	elseif args[1] == "warning" then
		if SongflowerTimer:errorHandler(args[2],1) and args[2] ~= "clear" then
			local t = { strsplit(" ", cmd, 2) }
			local s = t[2]
			if string.find(s, "%%t") then
				local h,m = GetGameTime()
				s = string.gsub(s, "%%t", h..":"..SongflowerTimer:leadingZero(m))
			elseif string.find(s, "%%l") then
				s = string.gsub(s, "%%l", SongflowerTimer.warning)
			end
			SongflowerTimer.warning = s
			print(prefix.."Warning set to: "..s..".")
		elseif args[2] == "clear" then
			SongflowerTimer.warning = ""
			print(prefix.."Warning cleared.")
		end
	else
		print(prefix.."Unknown command.")
	end
end