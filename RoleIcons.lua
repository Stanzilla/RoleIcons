local L = RI_locale()
local addonName = "RoleIcons"
local LaddonName = L[addonName]
RoleIcons = {}
local addon = RoleIcons
local _G = getfenv(0)
local defaults = { 
  raid =         { true,  L["Show role icons on the Raid tab"] },
  tooltip =      { true,  L["Show role icons in player tooltips"] },
  chat =         { true,  L["Show role icons in chat windows"] },
  debug =        { false, L["Debug the addon"] },
  classbuttons = { true,  L["Add class summary buttons to the Raid tab"] },
  rolebuttons =  { true,  L["Add role summary buttons to the Raid tab"] },
  autorole =     { true,  L["Automatically set role and respond to role checks based on your spec"] },
  target =       { true,  L["Show role icons on the target frame (default Blizzard frames)"] },
  focus =        { true,  L["Show role icons on the focus frame (default Blizzard frames)"] },
}
local settings
local maxlvl = MAX_PLAYER_LEVEL_TABLE[#MAX_PLAYER_LEVEL_TABLE] 
RI_svnrev = {}
RI_svnrev["RoleIcons.lua"] = tonumber(("$Revision$"):match("%d+"))

local chats = { 
	CHAT_MSG_SAY = 1, CHAT_MSG_YELL = 1, 
	CHAT_MSG_WHISPER = 1, CHAT_MSG_WHISPER_INFORM = 1,
	CHAT_MSG_PARTY = 1, CHAT_MSG_PARTY_LEADER = 1,
	CHAT_MSG_RAID = 1, CHAT_MSG_RAID_LEADER = 1, CHAT_MSG_RAID_WARNING = 1, 
	CHAT_MSG_BATTLEGROUND_LEADER = 1, CHAT_MSG_BATTLEGROUND = 1,
	}

local iconsz = 19 
local riconsz = iconsz
local role_tex_file = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES.blp"
local role_t = "\124T"..role_tex_file..":%d:%d:"
local role_tex = {
   DAMAGER = role_t.."0:0:64:64:20:39:22:41\124t",
   HEALER  = role_t.."0:0:64:64:20:39:1:20\124t",
   TANK    = role_t.."0:0:64:64:0:19:22:41\124t",
   LEADER  = role_t.."0:0:64:64:0:19:1:20\124t",
   NONE    = ""
}
function getRoleTex(role,size)
  local str = role_tex[role]
  if not str or #str == 0 then return "" end
  if not size then size = 0 end
  role_tex[size] = role_tex[size] or {}
  str = role_tex[size][role]
  if not str then
     str = string.format(role_tex[role], size, size)
     role_tex[size][role] = str
  end
  return str
end
function getRoleTexCoord(role)
  local str = role_tex[role]
  if not str or #str == 0 then return nil end
  local a,b,c,d = string.match(str, ":(%d+):(%d+):(%d+):(%d+)%\124t")
  return a/64,b/64,c/64,d/64
end

local function chatMsg(msg)
     DEFAULT_CHAT_FRAME:AddMessage(LaddonName..": "..msg)
end
local function debug(msg)
  if settings and settings.debug then
     chatMsg(msg)
  end
end

local function myDefaultRole()
  local _, class = UnitClass("player")
  if class == "MAGE" or class == "HUNTER" or class == "WARLOCK" or class == "ROGUE" then
    return "DAMAGER"
  end
  local tabIndex = GetPrimaryTalentTree(false, false)
  if not tabIndex then return nil end -- untalented hybrid
  local role1,role2 = GetTalentTreeRoles(tabIndex,false,false)
  if not role2 then
    addon.rolepolloverride = false
    return role1 
  else -- more than one possibility (eg feral druid)
    addon.rolepolloverride = true -- dont hide roll poll for feral druids
    if class == "DRUID" then
      local tanktalents = 0 -- look for tank talents
      for ti = 1, GetNumTalents(tabIndex, nil, nil) do
        --local name, _, _, _, rank, maxrank = GetTalentInfo(tabIndex, ti, nil, nil, nil)
	--if (name == "Thick Hide" or name == "Natural Reaction") and rank == maxrank then
	local link = GetTalentLink(tabIndex, ti, false, nil, nil)
	if link:match("\124Htalent:8293:2\124") or link:match("\124Htalent:8758:1\124") then
	  tanktalents = tanktalents + 1
	end
      end
      if tanktalents >= 2 then
        return "TANK"
      else
        return "DAMAGER"
      end
    end
    return nil 
  end
end

local frame = CreateFrame("Button", addonName.."HiddenFrame", UIParent)
frame:RegisterEvent("ADDON_LOADED");
frame:RegisterEvent("ROLE_POLL_BEGIN");
frame:RegisterEvent("RAID_ROSTER_UPDATE");
frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED");
frame:RegisterEvent("PLAYER_TARGET_CHANGED");
frame:RegisterEvent("PLAYER_FOCUS_CHANGED");

local function UpdateTT(tt, unit, ttline)
  if not settings.tooltip then return end
  unit = unit or (tt and tt.GetUnit and tt:GetUnit())
  if not unit then return end
  local role = UnitGroupRolesAssigned(unit)
  local leader = (UnitInParty(unit) or UnitInRaid(unit)) and UnitIsPartyLeader(unit)
  if (role and role ~= "NONE") or leader then 
     local name = tt:GetName()
     local line = ttline or _G[name.."TextLeft1"]
     if line and line.GetText then
       local txt = line:GetText()
       if txt and not string.find(txt,role_tex_file,1,true) then
         if leader then
           txt = getRoleTex("LEADER",iconsz)..txt
         end
         line:SetText(getRoleTex(role,iconsz)..txt)
       end
     end
  end
end

local function VuhdoHook()
  if VuhDoTooltip and VuhDoTooltipTextL1 then
    local unit = VuhDoTooltipTextL1:GetText()
    UpdateTT(VuhDoTooltip, unit, VuhDoTooltipTextL1)
  end
end

function RoleMenuInitialize(self)
        UnitPopup_ShowMenu(UIDROPDOWNMENU_OPEN_MENU, "SELECT_ROLE", self.unit, self.name, self.id);
end

function ShowRoleMenu(self)
        HideDropDownMenu(1);
        if ( self.id and self.name ) then
                FriendsDropDown.name = self.name;
                FriendsDropDown.id = self.id;
                FriendsDropDown.unit = self.unit;
                FriendsDropDown.initialize = RoleMenuInitialize;
                FriendsDropDown.displayMode = "MENU";
                ToggleDropDownMenu(1, nil, FriendsDropDown, "cursor");
        end
end

local classcnt = {}
local rolecnt = {}
local rolecall = {}

local tokendata = {
  [L["Vanquisher"]] = { { "ROGUE", L["Rogue"] }, { "DEATHKNIGHT", L["DK"] }, { "MAGE", L["Mage"] }, { "DRUID", L["Druid"] } },
  [L["Protector"]] = { { "WARRIOR", L["Warrior"] }, { "HUNTER", L["Hunter"] }, { "SHAMAN", L["Shaman"] } },
  [L["Conqueror"]] = { { "PALADIN", L["Paladin"] }, { "PRIEST", L["Priest"] }, { "WARLOCK", L["Warlock"] } },
}
local function DisplayTokenTooltip()
  if not UnitInRaid("player") then return end

  GameTooltip:ClearLines()
  GameTooltip_SetDefaultAnchor(GameTooltip, UIParent);
  local total = 0
  local summstr = ""
  for _,role in ipairs({"TANK","HEALER","DAMAGER"}) do
    local cnt = rolecnt[role] or 0
    summstr = summstr..cnt.." "..getRoleTex(role).."   "
    total = total + cnt
  end
  local none = rolecnt["NONE"]
  if none and none > 0 then
    summstr = summstr..none.." "..L["Unassigned"]
    total = total + none
  end

  GameTooltip:AddLine(L["Tier token breakdown:"])
  for token, ti in pairs(tokendata) do
    local tokenstr = ""
    local cnt = 0
    for _,ci in ipairs(ti) do
      local class = ci[1]
      local lclass = ci[2]
      cnt = cnt + (classcnt[class] or 0)
      local color = RAID_CLASS_COLORS[class]
      local classstr = string.format("\124cff%.2x%.2x%.2x", color.r*255, color.g*255, color.b*255)..lclass.."\124r"
      if #tokenstr >  0 then tokenstr = tokenstr..", " end
      tokenstr = tokenstr..classstr
    end
    GameTooltip:AddLine("\124cffff0000"..cnt.."\124r".."  \124cffffffff"..token.." (\124r"..tokenstr.."\124cffffffff)\124r")
  end

  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(total.." "..L["Players:"].." "..summstr)
  GameTooltip:Show()

end

local function UpdateRGF()
  if not RaidFrame then return end
  if IsRaidOfficer() then
     if not addon.rolecheckbtn and RaidFrameReadyCheckButton and RaidFrameAllAssistCheckButton then
       local btn = CreateFrame("Button","RaidIconsRoleCheckBtn",RaidFrame,"UIPanelButtonTemplate")
       btn:SetSize(RaidFrameReadyCheckButton:GetSize())
       btn:SetText(ROLE_POLL)
       btn:SetPoint("BOTTOMLEFT", RaidFrameAllAssistCheckButton, "TOPLEFT", 0, 2)
       btn:SetScript("OnClick", function() InitiateRolePoll() end)
       btn:SetNormalFontObject(GameFontNormalSmall)
       btn:SetHighlightFontObject(GameFontHighlightSmall)
       addon.rolecheckbtn = btn
     end
     addon.rolecheckbtn:Show()
  elseif addon.rolecheckbtn then
     addon.rolecheckbtn:Hide()
  end
  wipe(classcnt)
  wipe(rolecnt)
  wipe(rolecall)
  for i=1,40 do
    local btn = _G["RaidGroupButton"..i]
    if btn and btn.unit and btn.subframes and btn.subframes.level and btn:IsVisible() then
       local unit = btn.unit
       if unit then
         local role = UnitGroupRolesAssigned(unit)
	 local name = UnitName(unit)
	 local _,class = UnitClass(unit)
	 if class then
           classcnt[class] = (classcnt[class] or 0) + 1
	 end
	 role = role or "NONE"
	 rolecnt[role] = (rolecnt[role] or 0) + 1
	 rolecall[role] = ((rolecall[role] and rolecall[role]..", ") or "")..name
         if role ~= "NONE" then
	   if class then
	     local color = RAID_CLASS_COLORS[class]
	     name = string.format("\124cff%.2x%.2x%.2x", color.r*255, color.g*255, color.b*255)..name.."\124r"
	   end
           local lvl = UnitLevel(unit)
           if not lvl or lvl == 0 then
             lvl = (btn.name and UnitLevel(btn.name)) or 0
           end
           if settings.raid and lvl == maxlvl or lvl == 0 then -- sometimes returns 0 during moves
             btn.subframes.level:SetDrawLayer("OVERLAY")
	     while true do
               btn.subframes.level:SetText(getRoleTex(role,riconsz))
	       if btn.subframes.level:IsTruncated() then
	         riconsz = riconsz - 1
		 debug("Reduced iconsz to: "..riconsz)
	       else
	         break
	       end
	     end
           elseif settings.raid then
             --print(unit.." "..lvl)
             local class = UnitClass(unit)
             if not class or #class == 0 then
                class = UnitClass(btn.name)
             end
             btn.subframes.class:SetDrawLayer("OVERLAY")
             btn.subframes.class:SetText(getRoleTex(role,riconsz).." "..class)
           end
         end
       end
       if not InCombatLockdown() then
         -- extra bonus, make the secure frames targettable
         btn:SetAttribute("type1", "target")
         btn:SetAttribute("unit", btn.unit)
       end
       addon.btnhook = addon.btnhook or {}
       if not addon.btnhook[btn] then
         btn:RegisterForClicks("AnyUp")
         btn:HookScript("OnClick", function(self, button)
	   if button == "MiddleButton" then
	     ShowRoleMenu(self)
	   end
	 end)
	 addon.btnhook[btn] = true
       end
    end
  end
  if addon.rolebuttons then
  for role,btn in pairs(addon.rolebuttons) do
    if settings.rolebuttons and UnitInRaid("player") and not RaidInfoFrame:IsShown() then  
      btn.rolecnt = rolecnt[role] or 0
      btn.rolecall = rolecall[role]
      _G[btn:GetName().."Count"]:SetText(btn.rolecnt)
      btn:Show()
    else
      btn:Hide()
    end
  end
  end
  for i=1,20 do
    local btn = _G["RaidClassButton"..i]
    if btn then 
      if settings.classbuttons and UnitInRaid("player") and i <= 10 and not RaidInfoFrame:IsShown() then
        btn:Show()
      else
        btn:Hide()
      end
    end
  end
  if not addon.headerFrame then
    addon.headerFrame = CreateFrame("Button", addonName.."HeaderButton", RaidFrame)
    addon.headerFrame:SetPoint("TOPLEFT",RaidFrame,-10,10)
    addon.headerFrame:SetSize(74,74)
    addon.headerFrame:Show()
    addon.headerFrame:SetScript("OnEnter", function() DisplayTokenTooltip() end)
    addon.headerFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
end

function ChatFilter(self, event, message, sender, ...)
  if not settings.chat then return false end
  local role = UnitGroupRolesAssigned(sender)
  if (role and role ~= "NONE") then
    if not string.find(message,role_tex_file,1,true) then
      message = getRoleTex(role,0).." "..message
    end
  end
  return false, message, sender, ...
end

function PratFilter()
  if not settings.chat then return false end
  local sm = Prat.SplitMessageOrg
  --debug("sm.EVENT="..(sm.EVENT or "nil").."  sm.PLAYER="..(sm.PLAYER or "nil"))
  if sm and sm.EVENT and sm.PLAYER and 
     (chats[sm.EVENT] or sm.EVENT == "CHAT_MSG_PARTY_GUIDE") then -- nonevent created by Prat
    local role = UnitGroupRolesAssigned(sm.PLAYER)
    if (role and role ~= "NONE") then
      if not string.find(sm.PLAYER,role_tex_file,1,true) then
        sm.PLAYER = getRoleTex(role,0)..sm.PLAYER
      end
    end
  end
end

local GetColoredName_orig
function GetColoredName_hook(event, arg1, arg2, ...)
  local ret = GetColoredName_orig(event, arg1, arg2, ...)
  if chats[event] and settings.chat then
    local role = UnitGroupRolesAssigned(arg2)
    if (role and role ~= "NONE") then
        ret = getRoleTex(role,0)..""..ret
    end
  end
  return ret 
end

function UpdateTarget(frame) 
  local Frame = frame:gsub("^(.)",string.upper)
  addon.frametex = addon.frametex or {}
  local tex = addon.frametex[frame]
  if tex then tex:Hide() end
  if not settings[frame] or not UnitIsPlayer(frame) or not _G[Frame.."Frame"]:IsVisible() then return end
  local role = UnitGroupRolesAssigned(frame)
  if role == "NONE" then return end
  if not tex then
    tex = _G[Frame.."FrameTextureFrame"]:CreateTexture(addonName..Frame.."FrameRole","OVERLAY")
    tex:ClearAllPoints()
    tex:SetPoint("BOTTOMLEFT", _G[Frame.."FrameTextureFrameName"], "TOPRIGHT",0,-8)
    tex:SetTexture(role_tex_file)
    tex:SetSize(20,20)
    addon.frametex[frame] = tex
  end
  tex:SetTexCoord(getRoleTexCoord(role))
  tex:Show()
end

local reg = {}
local function RegisterHooks()
  if not settings then return end
  if settings.raid and RaidGroupFrame_Update and not reg["rgb"] then
    debug("Registering RaidGroupFrame_Update")
    hooksecurefunc("RaidGroupFrame_Update",UpdateRGF)
    hooksecurefunc("RaidGroupFrame_UpdateLevel",UpdateRGF)
    reg["rgb"] = true
  end
  if settings.raid and RaidInfoFrame and not reg["rif"] then
    debug("Registering RaidInfoframe")
    hooksecurefunc(RaidInfoFrame,"Show",UpdateRGF)
    hooksecurefunc(RaidInfoFrame,"Hide",UpdateRGF)
    reg["rif"] = true
  end
  if settings.tooltip and GameTooltip and not reg["gtt"] then
    debug("Registering GameTooltip")
    --hooksecurefunc(GameTooltip,"SetUnit", UpdateTT)
    GameTooltip:HookScript("OnTooltipSetUnit", UpdateTT)
    hooksecurefunc(GameTooltipTextLeft1,"SetFormattedText", function() UpdateTT(GameTooltip) end)
    hooksecurefunc(GameTooltipTextLeft1,"SetText", function() UpdateTT(GameTooltip) end)
    reg["gtt"] = true
  end
  if settings.tooltip and HealBot_Action_RefreshTooltip and not reg["hb"] then
    hooksecurefunc("HealBot_Action_RefreshTooltip", function(unit) UpdateTT(GameTooltip,unit) end)
    reg["hb"] = true
  end
  -- if settings.tooltip and VUHDO_showTooltip and VUHDO_GLOBAL and VUHDO_GLOBAL["VUHDO_showTooltip"] and not reg["vh"] then
  if settings.tooltip and VUHDO_updateTooltip and not reg["vh"] then
    hooksecurefunc("VUHDO_updateTooltip", VuhdoHook)
    reg["vh"] = true
  end
  if false and settings.raid and not reg["upm"] then
     -- add the set role menu to the raid screen popup CAUSES TAINT
     table.insert(UnitPopupMenus["RAID"],1,"SELECT_ROLE")
     reg["upm"] = true
  end
  if false and settings.chat and not reg["chats"] then
     for c,_ in pairs(chats) do
       ChatFrame_AddMessageEventFilter(c, ChatFilter)
     end
     reg["chats"] = true
  end
  if settings.chat and Prat and not reg["prat"] then
     hooksecurefunc(Prat,"SplitChatMessage",PratFilter)
     reg["prat"] = true
  end
  if settings.chat and GetColoredName and not reg["gcn"] then
     GetColoredName_orig = _G.GetColoredName
     _G.GetColoredName = GetColoredName_hook
     reg["gcn"] = true
  end
  if settings.classbuttons and RaidClassButton10 then
    RaidClassButton10:ClearAllPoints()
    RaidClassButton10:SetPoint("BOTTOMLEFT",RaidFrame,"BOTTOMRIGHT",-1,15)
  end
  if settings.rolebuttons and RaidClassButton1 and not addon.rolebuttons then
    addon.rolebuttons = {}
    local last
    for _,role in ipairs({"TANK","HEALER","DAMAGER"}) do
      local btn = CreateFrame("Button", addonName.."RoleButton"..role, RaidFrame, "RaidClassButtonTemplate")
      local icon = _G[btn:GetName().."IconTexture"];
      icon:SetTexture(role_tex_file)
      icon:SetTexCoord(getRoleTexCoord(role))
      btn:SetScript("OnLoad",function(self) end)
      btn:SetScript("OnEnter",function(self) 
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent);
        GameTooltip:SetText(_G[role] .. " ("..(btn.rolecnt or 0)..")") 
	if btn.rolecall then
          GameTooltip:AddLine(btn.rolecall,1,1,1,true) 
	end
	GameTooltip:Show()
      end)
      btn:ClearAllPoints()
      if last then
        btn:SetPoint("TOPLEFT", last, "BOTTOMLEFT",0,-4)
      end
      btn:SetScale(1.6)
      btn:Show()
      addon.rolebuttons[role] = btn
      last = btn
    end
    addon.rolebuttons["TANK"]:SetPoint("TOPLEFT",FriendsFrameCloseButton,"BOTTOMRIGHT",-4,16)
  end
  if RaidClassButton_OnEnter and not reg["rcboe"] then
    hooksecurefunc("RaidClassButton_OnEnter",function() 
        for i=1,10 do
	  local line = _G["GameTooltipTextLeft"..i]
	  local text = line and line:GetText()
	  if text and string.find(text,TOOLTIP_RAID_CLASS_BUTTON,1,true) then
	    line:SetText("")
	    GameTooltip:Show() -- resize
	    break
	  end
	end
      end)
    reg["rcboe"] = true
  end
  if RolePollPopup_Show and not reg["rpp"] then
     hooksecurefunc("RolePollPopup_Show", function() 
       if settings.autorole and not addon.rolepolloverride and UnitGroupRolesAssigned("player") ~= "NONE" then 
         --RolePollPopup:Hide() 
         StaticPopupSpecial_Hide(RolePollPopup) -- ticket 4
       end
     end)
     reg["rpp"] = true
  end
end

local function OnEvent(frame, event, name, ...)
  if event == "ADDON_LOADED" and string.upper(name) == string.upper(addonName) then
     debug("ADDON_LOADED: "..name)
     RoleIconsDB = RoleIconsDB or {}
     settings = RoleIconsDB
     for k,v in pairs(defaults) do
       if settings[k] == nil then
         settings[k] = defaults[k][1]
       end
     end
     addon:SetupVersion()
     RegisterHooks() 
  elseif event == "ADDON_LOADED" and name == "Blizzard_RaidUI" then
     debug("ADDON_LOADED: "..name)
     RegisterHooks() 
  elseif event == "ADDON_LOADED" then
     --debug("ADDON_LOADED: "..name)
  elseif event == "PLAYER_TARGET_CHANGED" then
     UpdateTarget("target")
  elseif event == "PLAYER_FOCUS_CHANGED" then
     UpdateTarget("focus")
  elseif event == "ROLE_POLL_BEGIN" or 
         event == "RAID_ROSTER_UPDATE" or 
	 event == "ACTIVE_TALENT_GROUP_CHANGED" then
     UpdateTarget("target")
     UpdateTarget("focus")
     if settings.autorole then
       local currrole = UnitGroupRolesAssigned("player")
       if (currrole == "NONE" and event ~= "ACTIVE_TALENT_GROUP_CHANGED") or
          (currrole ~= "NONE" and event == "ACTIVE_TALENT_GROUP_CHANGED") then
         local role = myDefaultRole()
	 if role and role ~= "NONE" then
           debug(event.." setting "..role)
           UnitSetRole("player", role)
           --RolePollPopup:Hide() 
           StaticPopupSpecial_Hide(RolePollPopup) -- ticket 4
         end
       end
     end
  end
end
frame:SetScript("OnEvent", OnEvent);

SLASH_ROLEICONS1 = L["/ri"]
SlashCmdList["ROLEICONS"] = function(msg)
        local cmd = msg:lower()
	if cmd == "check" then
	  InitiateRolePoll() 
        elseif settings[cmd] ~= nil then
          settings[cmd] = not settings[cmd]
          chatMsg(cmd..L[" set to "]..(settings[cmd] and YES or NO))
	  RegisterHooks()
	  UpdateRGF()
        else
	  local usage = ""
          chatMsg(LaddonName.." "..addon.version)
	  for c,_ in pairs(defaults) do
	    usage = usage.." | "..c
	  end
          chatMsg(SLASH_ROLEICONS1.." [ check"..usage.." ]")
	  chatMsg("  "..SLASH_ROLEICONS1.." check  - "..L["Perform a role check (requires assist or leader)"])
	  for c,v in pairs(defaults) do
	    chatMsg("  "..SLASH_ROLEICONS1.." "..c.."  ["..
	      (settings[c] and "|cff00ff00"..YES or "|cffff0000"..NO).."|r] "..v[2])
	  end
        end
end
SLASH_ROLECHECK1 = L["/rolecheck"]
SlashCmdList["ROLECHECK"] = function(msg) InitiateRolePoll() end

function addon:SetupVersion()
   local svnrev = 0
   local T_svnrev = RI_svnrev
   T_svnrev["X-Build"] = tonumber((GetAddOnMetadata(addonName, "X-Build") or ""):match("%d+"))
   T_svnrev["X-Revision"] = tonumber((GetAddOnMetadata(addonName, "X-Revision") or ""):match("%d+"))
   for _,v in pairs(T_svnrev) do -- determine highest file revision
     if v and v > svnrev then
       svnrev = v
     end
   end
   addon.revision = svnrev

   T_svnrev["X-Curse-Packaged-Version"] = GetAddOnMetadata(addonName, "X-Curse-Packaged-Version")
   T_svnrev["Version"] = GetAddOnMetadata(addonName, "Version")
   addon.version = T_svnrev["X-Curse-Packaged-Version"] or T_svnrev["Version"] or "@"
   if string.find(addon.version, "@") then -- dev copy uses "@.project-version.@"
      addon.version = "r"..svnrev
   end
end

