local L = RI_locale()
local addonName = "RoleIcons"
local LaddonName = L[addonName]
RoleIcons = {}
local addon = RoleIcons
local _G = getfenv(0)
local defaults = { 
  debug = true,
}
local settings = defaults
local maxlvl = MAX_PLAYER_LEVEL_TABLE[#MAX_PLAYER_LEVEL_TABLE] 
RI_svnrev = {}
RI_svnrev["RoleIcons.lua"] = tonumber(("$Revision$"):match("%d+"))

local chats = { 
	CHAT_MSG_SAY = 1, CHAT_MSG_YELL = 1, CHAT_MSG_WHISPER = 1,
	CHAT_MSG_PARTY = 1, CHAT_MSG_PARTY_LEADER = 1,
	CHAT_MSG_RAID = 1, CHAT_MSG_RAID_LEADER = 1, CHAT_MSG_RAID_WARNING = 1, 
	CHAT_MSG_BATTLEGROUND_LEADER = 1, CHAT_MSG_BATTLEGROUND = 1,
	}

local iconsz = 19 
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

local function chatMsg(msg)
     DEFAULT_CHAT_FRAME:AddMessage(LaddonName..": "..msg)
end
local function debug(msg)
  if settings.debug then
     chatMsg(msg)
  end
end

local frame = CreateFrame("Button", addonName.."HiddenFrame", UIParent)
frame:RegisterEvent("ADDON_LOADED");

local function UpdateTT(tt, unit)
  unit = unit or (tt and tt.GetUnit and tt:GetUnit())
  if not unit then return end
  local role = UnitGroupRolesAssigned(unit)
  local leader = (UnitInParty(unit) or UnitInRaid(unit)) and UnitIsPartyLeader(unit)
  if (role and role ~= "NONE") or leader then 
     local name = tt:GetName()
     local line = _G[name.."TextLeft1"]
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

local function UpdateRGF()
  for i=1,40 do
    local btn = _G["RaidGroupButton"..i]
    if btn and btn.unit and btn.subframes and btn.subframes.level and btn:IsVisible() then
       local unit = btn.unit
       if unit then
         local role = UnitGroupRolesAssigned(unit)
         if role and role ~= "NONE" then
           local lvl = UnitLevel(unit)
           if not lvl or lvl == 0 then
             lvl = UnitLevel(btn.name)
           end
           if lvl == maxlvl or lvl == 0 then -- sometimes returns 0 during moves
             btn.subframes.level:SetText(getRoleTex(role,iconsz))
             btn.subframes.level:SetDrawLayer("OVERLAY")
           else
             --print(unit.." "..lvl)
             local class = UnitClass(unit)
             if not class or #class == 0 then
                class = UnitClass(btn.name)
             end
             btn.subframes.class:SetText(getRoleTex(role,iconsz).." "..class)
             btn.subframes.class:SetDrawLayer("OVERLAY")
           end
         end
       end
    end
  end
end

function ChatFilter(self, event, message, sender, ...)
  local role = UnitGroupRolesAssigned(sender)
  if (role and role ~= "NONE") then
    if not string.find(message,role_tex_file,1,true) then
      message = getRoleTex(role,0).." "..message
    end
  end
  return false, message, sender, ...
end

local GetColoredName_orig = _G.GetColoredName
function GetColoredName_hook(event, arg1, arg2, ...)
  local ret = GetColoredName_orig(event, arg1, arg2, ...)
  if chats[event] then
    local role = UnitGroupRolesAssigned(arg2)
    if (role and role ~= "NONE") then
        ret = getRoleTex(role,0)..""..ret
    end
  end
  return ret 
end

local reg = {}
local function RegisterHooks()
  if RaidGroupFrame_Update and not reg["rgb"] then
    debug("Registering RaidGroupFrame_Update")
    hooksecurefunc("RaidGroupFrame_Update",UpdateRGF)
    hooksecurefunc("RaidGroupFrame_UpdateLevel",UpdateRGF)
    reg["rgb"] = true
  end
  if GameTooltip and not reg["gtt"] then
    debug("Registering GameTooltip")
    --hooksecurefunc(GameTooltip,"SetUnit", UpdateTT)
    GameTooltip:HookScript("OnTooltipSetUnit", UpdateTT)
    hooksecurefunc(GameTooltipTextLeft1,"SetFormattedText", function() UpdateTT(GameTooltip) end)
    hooksecurefunc(GameTooltipTextLeft1,"SetText", function() UpdateTT(GameTooltip) end)
    reg["gtt"] = true
  end
  if HealBot_Action_RefreshTooltip and not reg["hb"] then
    hooksecurefunc("HealBot_Action_RefreshTooltip", function(unit) UpdateTT(GameTooltip,unit) end)
    reg["hb"] = true
  end
  if not reg["upm"] then
     -- add the set role menu to the raid screen popup
     table.insert(UnitPopupMenus["RAID"],1,"SELECT_ROLE")
     reg["upm"] = true
  end
  if false and not reg["chats"] then
     for c,_ in pairs(chats) do
       ChatFrame_AddMessageEventFilter(c, ChatFilter)
     end
     reg["chats"] = true
  end
  if GetColoredName and not reg["gcn"] then
     _G.GetColoredName = GetColoredName_hook
     reg["gcn"] = true
  end
end

local function OnEvent(frame, event, name, ...)
  if event == "ADDON_LOADED" and name == addonName then
     debug("ADDON_LOADED: "..name)
     addon:SetupVersion()
     RegisterHooks() 
  elseif event == "ADDON_LOADED" and name == "Blizzard_RaidUI" then
     debug("ADDON_LOADED: "..name)
     RegisterHooks() 
  elseif event == "ADDON_LOADED" then
     --debug("ADDON_LOADED: "..name)
  end
end
frame:SetScript("OnEvent", OnEvent);

SLASH_ROLEICONS1 = L["/ri"]
SlashCmdList["ROLEICONS"] = function(msg)
        local cmd = msg:lower()
        if cmd == L["debug"] then
          chatMsg(L["debug toggled"])
          settings.debug = not settings.debug
        else
          chatMsg(LaddonName.." "..addon.version)
          chatMsg(SLASH_ROLEICONS1.." [ "..L["debug"].." ]")
        end
end

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

