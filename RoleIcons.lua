local L = RI_locale()
local addonName = "RoleIcons"
local LaddonName = L[addonName]
RoleIcons = {}
local addon = RoleIcons
local _G = getfenv(0)
local defaults = { 
  raid = true,
  tooltip = true,
  chat = true,
  debug = false,
  classbuttons = true,
  rolebuttons = true,
  autorole = true,
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
  local tabIndex = GetPrimaryTalentTree(false, false)
  local role1,role2 = GetTalentTreeRoles(tabIndex,false,false)
  if role2 then return nil -- more than one possibility (eg feral druid)
  else return role1 
  end
end

local frame = CreateFrame("Button", addonName.."HiddenFrame", UIParent)
frame:RegisterEvent("ADDON_LOADED");
frame:RegisterEvent("ROLE_POLL_BEGIN");
frame:RegisterEvent("RAID_ROSTER_UPDATE");
frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED");

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

local rolecnt = {}
local rolecall = {}

local function UpdateRGF()
  if not RaidFrame then return end
  if IsRaidOfficer() then
     if not addon.rolecheckbtn then
       local btn = CreateFrame("Button","RaidIconsRoleCheckBtn",RaidFrame,"UIPanelButtonTemplate")
       btn:SetSize(RaidFrameRaidBrowserButton:GetSize())
       btn:SetText(ROLE_POLL)
       btn:SetPoint("BOTTOMLEFT", RaidFrameRaidBrowserButton, "TOPLEFT", 0, 2)
       btn:SetScript("OnClick", function() InitiateRolePoll() end)
       btn:SetNormalFontObject(GameFontNormalSmall)
       btn:SetHighlightFontObject(GameFontHighlightSmall)
       addon.rolecheckbtn = btn
     end
     addon.rolecheckbtn:Show()
  elseif addon.rolecheckbtn then
     addon.rolecheckbtn:Hide()
  end
  wipe(rolecnt)
  wipe(rolecall)
  for i=1,40 do
    local btn = _G["RaidGroupButton"..i]
    if btn and btn.unit and btn.subframes and btn.subframes.level and btn:IsVisible() then
       local unit = btn.unit
       if unit then
         local role = UnitGroupRolesAssigned(unit)
         if role and role ~= "NONE" then
	   rolecnt[role] = (rolecnt[role] or 0) + 1
	   rolecall[role] = ((rolecall[role] and rolecall[role]..", ") or "")..UnitName(unit)
           local lvl = UnitLevel(unit)
           if not lvl or lvl == 0 then
             lvl = UnitLevel(btn.name)
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
         btn:SetAttribute("type", "target")
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
    if settings.rolebuttons and UnitInRaid("player") then  
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
      if settings.classbuttons and UnitInRaid("player") and i <= 10 then
        btn:Show()
      else
        btn:Hide()
      end
    end
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

local reg = {}
local function RegisterHooks()
  if not settings then return end
  if settings.raid and RaidGroupFrame_Update and not reg["rgb"] then
    debug("Registering RaidGroupFrame_Update")
    hooksecurefunc("RaidGroupFrame_Update",UpdateRGF)
    hooksecurefunc("RaidGroupFrame_UpdateLevel",UpdateRGF)
    reg["rgb"] = true
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
  if settings.chat and GetColoredName and not reg["gcn"] then
     GetColoredName_orig = _G.GetColoredName
     _G.GetColoredName = GetColoredName_hook
     reg["gcn"] = true
  end
  if settings.classbuttons and RaidClassButton10 then
    RaidClassButton10:ClearAllPoints()
    RaidClassButton10:SetPoint("BOTTOMLEFT",RaidFrame,"BOTTOMRIGHT",-36,95)
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
          GameTooltip:AddLine(btn.rolecall) 
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
end

local function OnEvent(frame, event, name, ...)
  if event == "ADDON_LOADED" and string.upper(name) == string.upper(addonName) then
     debug("ADDON_LOADED: "..name)
     RoleIconsDB = RoleIconsDB or {}
     settings = RoleIconsDB
     for k,v in pairs(defaults) do
       if settings[k] == nil then
         settings[k] = defaults[k]
       end
     end
     addon:SetupVersion()
     RegisterHooks() 
  elseif event == "ADDON_LOADED" and name == "Blizzard_RaidUI" then
     debug("ADDON_LOADED: "..name)
     RegisterHooks() 
  elseif event == "ADDON_LOADED" then
     --debug("ADDON_LOADED: "..name)
  elseif event == "ROLE_POLL_BEGIN" or 
         event == "RAID_ROSTER_UPDATE" or 
	 event == "ACTIVE_TALENT_GROUP_CHANGED" then
     if settings.autorole and UnitInRaid("player") then
       local currrole = UnitGroupRolesAssigned("player")
       if currrole == "NONE" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
         local role = myDefaultRole()
         if role and role ~= "NONE" then
           debug(event.." setting "..role)
           UnitSetRole("player", role)
	   RolePollPopup:Hide()
	   if RolePollPopup_Show and not addon.rpreg then
	     hooksecurefunc("RolePollPopup_Show", function() 
	       if settings.autorole then RolePollPopup:Hide() end
	       end)
	     addon.rpreg = true
	   end
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
	  for c,_ in pairs(settings) do
	    usage = usage.." | "..c
	  end
          chatMsg(SLASH_ROLEICONS1.." [ check"..usage.." ]")
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

