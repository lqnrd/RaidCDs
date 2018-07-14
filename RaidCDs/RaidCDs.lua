local expLeg = select(4, GetBuildInfo()) >= 70000
--[[ RaidCDs ]]

local DefaultO = {
  ["framePoint"] = "CENTER";
  ["frameRelativeTo"] = "UIParent";
  ["frameRelativePoint"] = "CENTER";
  ["frameOffsetX"] = 0;
  ["frameOffsetY"] = 0;
  ["hidden"] = false,
  ["hideSelf"] = false,
  --["timeFormat"] = 1, --NYI
  ["showCR"] = false,
}

--timeFormat:
--1   2    3
--103 1:43 2m

local UnitGUID = UnitGUID
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local myGUID
local moving = false
local LGIST = LibStub:GetLibrary("LibGroupInSpecT-1.1")

local RaidCDs_UpdateOptionsArray, RaidCDs_CloneTable, RaidCDs_CopyValues
function RaidCDs_UpdateOptionsArray()
  local TempRaidCDsOptions = RaidCDs_CloneTable(DefaultO);
  RaidCDs_CopyValues(RaidCDsOptions, TempRaidCDsOptions);
  RaidCDsOptions = TempRaidCDsOptions
end
--from "SCT" by "Grayhoof"
function RaidCDs_CloneTable(t) -- return a copy of the table t
  local new = {}; -- create a new table
  local i, v = next(t, nil); -- i is an index of t, v = t[i]
  while i do
    if type(v)=="table" then
      v=RaidCDs_CloneTable(v);
    end
    new[i] = v;
    i, v = next(t, i); -- get next index
  end
  return new;
end
function RaidCDs_CopyValues(from,to)
  local i, v = next(from, nil); -- i is an index of from, v = from[i]
  while i do
    if type(v)=="table" then
      if to[i] ~= nil then
        if type(to[i])=="table" then
          RaidCDs_CopyValues(v,to[i]);
        end
      end
    else
      if to[i] ~= nil then
        if type(to[i])~="table" then
          to[i] = v;
        end
      end
    end
    i, v = next(from, i); -- get next index
  end
end

local spellIDs = {
---------------------------------------------
--remember to add the spell to spellIDsOrder!
---------------------------------------------
  [51052] = {cd = 120, class = "DEATHKNIGHT", talent = 19219}, --Anti-Magic Zone (-20% spell, 3s)
  
  [740] = {cd = {{amount = 120, talent = 21713}, {amount = 180}}, class = "DRUID", spec = {[4]=1}, resetAfterWipe = true}, --Tranquility (aoe heal)
  [106898] = {cd = {{amount = 60, talent = 22424}, {amount = 120}}, class = "DRUID", spec = {[2]=1,[3]=1}}, --Stampeding Roar (Caster Form) (+60% speed, 8s)
  --aka's: these are spells which will not have their own bar, but instead be handled as if they had a different spellID, and merged into that bar. don't add them to "spellIDsOrder"
  [77761] = {aka = 106898}, --Stampeding Roar (Bear Form)
  [77764] = {aka = 106898}, --Stampeding Roar (Cat Form)
  
  [115310] = {cd = 180, class = "MONK", spec = {[2]=1}, resetAfterWipe = true}, --Revival (aoe heal and dispell)
  
  [31821] = {cd = 180, class = "PALADIN", spec = {[1]=1}, resetAfterWipe = true}, --Devotion Aura (-20% spell, 6s, silence/interrupt immune)
  
  [62618] = {cd = 180, class = "PRIEST", spec = {[1]=1}, resetAfterWipe = true}, --Power Word: Barrier (-25%, 10s)
  [64843] = {cd = 180, class = "PRIEST", spec = {[2]=1}, resetAfterWipe = true}, --Devine Hymn (aoe heal)
  
  --[76577] = {cd = 180, class = "ROGUE", resetAfterWipe = true}, --Smoke Bomb (-10%, 5s) --now honor talent of Subtlety
  [196718] = {cd = 180, class = "DEMONHUNTER", spec = {[1]=1}, resetAfterWipe = true},
  
  [98008] = {cd = 180, class = "SHAMAN", charges = {{count = 2, talent = 19273}, {count = 1}}, spec = {[3]=1}, resetAfterWipe = true}, --Spirit Link Totem (-10%, 6s, redistribute health % every 1s)
  [108280] = {cd = 180, class = "SHAMAN", spec = {[3]=1}, resetAfterWipe = true}, --Healing Tide Totem (aoe heal over 10s)
  
  [192077] = {cd = 120, class = "SHAMAN", talent = 21963}, --Wind Rush Totem (10yd aoe, 15s, +60% movement speed for 5s), talent
  --[207399] = {cd = 300, class = "SHAMAN", talent = 22539}, --Ancestral Protection Totem (20yd aoe, +10% max hp, 30s, one rezz), talent
  
  [97462] = {cd = 180, class = "WARRIOR", spec = {[1]=1, [2]=1}, resetAfterWipe = true}, --Commanding Shout (+15% max hp, 10s) was Rallying Cry
};
--visible spells, from top to bottom:
local spellIDsOrder = {
  51052, 740, 106898, 115310, 31821, 62618, 64843, 196718, 98008, 108280, 192077, 97462
};
local SPELLID_CCOMBATREZ = 20484

local frame = CreateFrame("Frame", "RaidCDsFrame", UIParent)
local frameEvents = {};

local function initFrame()
  local lastSpell, spellIndex
  frame:SetPoint(RaidCDsOptions["framePoint"], RaidCDsOptions["frameRelativeTo"], RaidCDsOptions["frameRelativePoint"], RaidCDsOptions["frameOffsetX"], RaidCDsOptions["frameOffsetY"])
  frame:SetFrameStrata("LOW")
  frame:SetSize(140, 40)
  
  frame:SetScript("OnEvent", function(self, event, ...)
    frameEvents[event](self, ...); -- call one of the event functions
  end);
  
  frame.crFrame = CreateFrame("Frame", nil, frame)
  
  frame.toggleCrFrame = function(self, value)
    local subFrame = self.crFrame
    if value then
      subFrame:SetHeight(12)
      subFrame.casterBar.casterText:Show()
      subFrame.casterBar.cdText:Show()
    else
      subFrame.casterBar.casterText:Hide()
      subFrame.casterBar.cdText:Hide()
      subFrame:SetHeight(0.001)
    end
  end
  
  do
    local subFrame = frame.crFrame
    subFrame:SetFrameStrata("LOW")
    subFrame:SetSize(140, 12)
    subFrame:SetPoint("TOPLEFT", frame, "TOPLEFT")
    
    local spellName = GetSpellInfo(SPELLID_CCOMBATREZ)
    
    subFrame.casterBar = frame:getNewCasterBar(spellName, "", 1, 0, false)
    
    subFrame.casterBar.SPELLID_CCOMBATREZ = SPELLID_CCOMBATREZ
    
    local c = RAID_CLASS_COLORS["PRIEST"]
    subFrame.casterBar.casterText:SetTextColor(c.r, c.g, c.b, 1)
    subFrame.casterBar.cdText:SetTextColor(c.r, c.g, c.b, 1)
    
    subFrame.casterBar:SetPoint("TOPLEFT", subFrame, "TOPLEFT", 0, 0)
    
    --overwrite OnUpdate function
    subFrame.casterBar.RealOnUpdate = function(self, elapsed)
      self.tslU = self.tslU + elapsed
      if self.tslU >= 1 then
        local chargesAvailable, chargesMax, lastChargeCooldownStart, rechargeTime = GetSpellCharges(self.SPELLID_CCOMBATREZ)
        if chargesAvailable then
          local chargeProgress = math.floor(GetTime()-lastChargeCooldownStart)
          
          self.maxCharges = chargesMax
          self.charges = chargesAvailable
          self.durLeft = (chargeProgress >= 0) and (math.floor(rechargeTime - chargeProgress)) or 0
          self:updateCooldownText(self.durLeft)
          
          self:updateAlpha()
          self:updateCasterName()
        else
          self:combatEnd()
        end
        
        self.tslU = 0
      end
    end
    
    subFrame.casterBar.combatEnd = function(self)
      self.maxCharges = 1
      self.charges = 1
      self.durLeft = -1
      self:updateCooldownText("")
      
      self:updateAlpha()
      self:updateCasterName()
    end
    
    frame:toggleCrFrame(RaidCDsOptions["showCR"])
  end
  
  frame.subFrames = {};
  local lastSubFrame = frame.crFrame
  for _, k in ipairs(spellIDsOrder) do
    local spellID = spellIDs[k]
    local subFrame = CreateFrame("Frame", nil, frame)
    subFrame:SetFrameStrata("LOW")
    subFrame:SetSize(140, 12)
    if lastSubFrame then
      subFrame:SetPoint("TOPLEFT", lastSubFrame, "BOTTOMLEFT")
    else
      subFrame:SetPoint("TOPLEFT", frame, "TOPLEFT")
    end
    lastSubFrame = subFrame
    frame.subFrames[k] = subFrame
    
    subFrame.headerText = subFrame:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    local spellName = GetSpellInfo(k)
    if spellName then
      subFrame.headerText:SetText(spellName)
    else
      subFrame.headerText:SetText("unknown")
    end
    local c = RAID_CLASS_COLORS[spellID.class or "PRIEST"]
    subFrame.headerText:SetTextColor(c.r, c.g, c.b, 1)
    subFrame.headerText:SetPoint("TOPLEFT", subFrame, "TOPLEFT")
    
    subFrame.cd = spellID.cd
    subFrame.class = spellID.class or "PRIEST"
    subFrame.spec = spellID.spec
    --charges = {{count = 2, talent = 17593}, {count = 1}}
    subFrame.charges = spellID.charges or {{count = 1}}
    subFrame.resetAfterWipe = spellID.resetAfterWipe
    
    subFrame.casterBars = {};
  end
  frame:updateSubFrameVisibility()
  
  frame.bgtexture = frame:CreateTexture(nil, "BACKGROUND")
  frame.bgtexture:SetAllPoints(frame)
  if expLeg then
    frame.bgtexture:SetColorTexture(0, 0, 0, 0.8)
  else
    frame.bgtexture:SetTexture(0, 0, 0, 0.8)
  end
  frame.bgtexture:Hide()
  frame:SetScript("OnDragStart", function(self) self:StartMoving(); end);
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
    RaidCDsOptions["framePoint"] = point or "LEFT"
    RaidCDsOptions["frameRelativeTo"] = relativeTo or "UIParent"
    RaidCDsOptions["frameRelativePoint"] = relativePoint or "CENTER"
    RaidCDsOptions["frameOffsetX"] = xOfs
    RaidCDsOptions["frameOffsetY"] = yOfs
  end);
  
end

frame.activeSpells = {}
frame.inactiveSpells = {}

frame.getNewCasterBar = function(self, casterName, casterGUID, maxCharges, cd, isDead)
  local ret
  if #(self.inactiveSpells) > 0 then
    ret = table.remove(self.inactiveSpells) --pop last element
  else
    ret = CreateFrame("Frame", nil, self)
    ret:SetFrameStrata("LOW")
    ret:SetSize(140, 12)

    ret.casterText = ret:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    ret.casterText:SetPoint("TOPLEFT", ret, "TOPLEFT", 10, 0)
    
    ret.cdText = ret:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    ret.cdText:SetPoint("TOPRIGHT", ret, "TOPRIGHT")
  end
  
  ret.casterName = casterName
  ret.casterGUID = casterGUID
  ret.durLeft = -1
  ret.tslU = -1
  
  ret.maxCharges = maxCharges or 1
  ret.charges = ret.maxCharges
  ret.cd = cd or 0
  ret.isDead = isDead or false
  ret.isOnCD = false
  
  ret.cdText:SetText("")
  ret:Show()
  
  ret.updateCasterName = function(self)
    if self.maxCharges > 1 then
      self.casterText:SetText(format("%dx %s", self.charges, self.casterName))
    else
      self.casterText:SetText(self.casterName)
    end
  end
  ret:updateCasterName()
  
  ret.updateCooldownText = function(self, s)
    if type(s) == "number" then
      if s >= 60 then
        local m = math.floor(s / 60)
        s = s - 60 * m
        self.cdText:SetText(string.format("%d:%02d", m, s))
      else
        self.cdText:SetText(s)
      end
    else
      self.cdText:SetText(s)
    end
  end
  
  ret.updateAlpha = function(self)
    if (self.charges == 0) or self.isDead then
      self:SetAlpha(0.6)
    else
      self:SetAlpha(1)
    end
  end
  ret:updateAlpha()
  
  ret.NoOp = function() end
  ret.RealOnUpdate = function(self, elapsed)
    self.tslU = self.tslU + elapsed
    while self.tslU >= 1 do
    
      if self.isOnCD then
        self.durLeft = self.durLeft - 1
        --self.cdText:SetText(self.durLeft)
        self:updateCooldownText(self.durLeft)
        
        if self.durLeft <= 0 then
          self.charges = min(self.charges + 1, self.maxCharges)
          if self.charges == self.maxCharges then
            --self.tslU = -1
            self.durLeft = -1
            --self.cdText:SetText("")
            self:updateCooldownText("")
            self.isOnCD = false
            
            if not self.isDead then
              self.tslU = -1
              self.OnUpdate = self.NoOp
            end
          else
            --self.tslU = self.tslU - 1
            self.durLeft = self.cd
            --self.cdText:SetText(self.durLeft)
            self:updateCooldownText(self.durLeft)
          end
          
          self:updateAlpha()
          
          self:updateCasterName()
        end
      end
      
      if self.isDead then
        local lku = LGIST:GuidToUnit(self.casterGUID)
        self.isDead = lku and UnitIsDeadOrGhost(lku) or false
        
        if not self.isDead then
          self:updateAlpha()
          
          if not self.isOnCD then
            self.tslU = -1
            self.OnUpdate = self.NoOp
          end
        end
      end
      
      self.tslU = self.tslU - 1
    end
  end
  if ret.isDead or ret.isOnCD then
    ret.tslU = 0
    ret.OnUpdate = ret.RealOnUpdate
  else
    ret.OnUpdate = ret.NoOp
  end
  ret:SetScript("OnUpdate", function(self, elapsed)
    self.OnUpdate(self, elapsed)
  end);
  
  return ret
end

frame.addCasterBarToSpell = function(self, casterBar, spellID)
  local subFrame = self.subFrames[spellID]
  if not subFrame then return end
  
  table.insert(subFrame.casterBars, casterBar)
  local c = RAID_CLASS_COLORS[subFrame.class or "PRIEST"]
  casterBar.casterText:SetTextColor(c.r, c.g, c.b, 1)
  casterBar.cdText:SetTextColor(c.r, c.g, c.b, 1)
  
  subFrame.headerText:Show()
  subFrame:SetHeight((#subFrame.casterBars)*12 + 12)
  casterBar:SetPoint("TOPLEFT", subFrame, "TOPLEFT", 0, -12*(#subFrame.casterBars))
end
frame.removeCasterBarsFromSpell = function(self, casterGUID, spellID)
  local subFrame = self.subFrames[spellID]
  if not subFrame then return end
  
  local numBars = #subFrame.casterBars
  local casterBar
  for i = numBars, 1, -1 do
    if subFrame.casterBars[i].casterGUID == casterGUID then
      local casterBar = table.remove(subFrame.casterBars, i) --pop last element
      casterBar:Hide()
      table.insert(self.inactiveSpells, casterBar)
    end
  end
  numBars = #subFrame.casterBars
  subFrame:SetHeight(numBars*12 + 12)
  for i, v in ipairs(subFrame.casterBars) do
    v:SetPoint("TOPLEFT", subFrame, "TOPLEFT", 0, -12*i)
  end
end
frame.removeCasterBars = function(self, casterGUID)
  for k, _ in pairs(self.subFrames) do
    self:removeCasterBarsFromSpell(casterGUID, k)
  end
  self:updateSubFrameVisibility()
end
frame.updateSubFrameVisibility = function(self)
  for _, subFrame in pairs(self.subFrames) do
    if #subFrame.casterBars == 0 then
      subFrame.headerText:Hide()
      subFrame:SetHeight(0.001)
    end
  end
end
frame.startCD = function(self, casterGUID, spellID)
  local subFrame = self.subFrames[spellID]
  if not subFrame then return end
  
  for _, v in ipairs(subFrame.casterBars) do
    if v.casterGUID == casterGUID then
      v.isOnCD = true
      --only update if not already on cooldown
      if v.charges >= v.maxCharges then
        v.durLeft = v.cd --subFrame.cd
        --v.cdText:SetText(v.cd)
        v:updateCooldownText(v.cd)
        v.tslU = 0
        v.OnUpdate = v.RealOnUpdate
      end
      v.charges = max(v.charges - 1, 0)
      v:updateCasterName()
      v:updateAlpha()
    end
  end
end
frame.startIsDead = function(self, casterGUID)
  for k, subFrame in pairs(self.subFrames) do
    for _, v in ipairs(subFrame.casterBars) do
      if v.casterGUID == casterGUID then
        --only update if not already on cooldown
        if not (v.isDead or v.isOnCD) then
          v.isDead = true
          
          v.tslU = 0
          v.OnUpdate = v.RealOnUpdate
        else
          v.isDead = true
        end
        v:updateAlpha()
      end
    end
  end
end
frame.resetAfterWipe = function(self)
  for _, subFrame in pairs(self.subFrames) do
    if subFrame.resetAfterWipe then
      for _, casterBar in ipairs(subFrame.casterBars) do
        if (casterBar.durLeft > 0) or (casterBar.charges < casterBar.maxCharges) then
          casterBar.durLeft = 0
          casterBar.charges = casterBar.maxCharges
        end
      end
    end
  end
end
frame.hasCasterBar = function(self, casterGUID, spellID)
  local subFrame = self.subFrames[spellID]
  if not subFrame then return false end
  
  for _, v in ipairs(subFrame.casterBars) do
    if v.casterGUID == casterGUID then
      return true
    end
  end
  
  return false
end

function frame:UpdateHandler(event, guid, unit, info)
  self:removeCasterBars(guid)
  
  if not info.class then return end
  
  if RaidCDsOptions["hideSelf"] and (guid == myGUID) then return end
  
  local isDead = info.lku and UnitIsDeadOrGhost(info.lku) or false
  
  for k, v in pairs(spellIDs) do
    local spellIDk = k
    local spellIDv = v
    if spellIDv.aka then
      spellIDk = spellIDv.aka
      spellIDv = spellIDs[spellIDv.aka]
    end
    if not self:hasCasterBar(guid, spellIDk) then
      if spellIDv.class == info.class then
        --example:
        --spec = {[2]=1, [3]=1} (specs 2 and 3 are "1", and spec 1 is "nil", so only specs 2 and 3 apply)
        if (not spellIDv.spec) or (spellIDv.spec[info.spec_index]) then
          if (not spellIDv.talent) or (next(info.talents) and info.talents[spellIDv.talent]) then
            --example:
            --charges = {{count = 2, talent = 17593}, {count = 1}} ("2" charges with talent "17593" specced, else "1" charge)
            local charges = 1
            if spellIDv.charges then
              for _, v2 in ipairs(spellIDv.charges) do
                if (v2.talent and next(info.talents) and info.talents[v2.talent]) or (not v2.talent) then
                  charges = v2.count or 1
                  break
                end
              end
            end
            --example:
            --cd = {{amount = 90, spec = 3}, {amount = 120}} (cd is given either directly as a number like "10", or as a table. in this case "90" seconds cd with spec "3", else "120" seconds)
            local cd
            if type(spellIDv.cd) == "number" then
              cd = spellIDv.cd
            else
              --{{amount = 90, spec = 3}, {amount = 50, talent = 12345}, {amount = 120}}
              for _, v2 in ipairs(spellIDv.cd) do
                if ((v2.spec and info.spec_index == v2.spec) or (not v2.spec)) and ((v2.talent and next(info.talents) and info.talents[v2.talent]) or (not v2.talent)) then
                  cd = v2.amount or 0
                  break
                end
              end
            end
            
            local b = self:getNewCasterBar(info.name or UnitName(info.lku), guid, charges, cd, isDead)
            self:addCasterBarToSpell(b, spellIDk)
          end
        end
      end
    end
  end
end
function frame:RemoveHandler(event, guid)
  -- guid no longer a group member
  self:removeCasterBars(guid)
end

function frameEvents:PLAYER_ENTERING_WORLD(...)
  frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
  
  if not RaidCDsOptions then
    RaidCDsOptions = DefaultO
  end
  RaidCDs_UpdateOptionsArray()
  initFrame()
  
  if RaidCDsOptions["hidden"] then
    frame:SetAlpha(0)
  else
    frame:SetAlpha(1)
  end
  myGUID = UnitGUID("player")
  
  LGIST.RegisterCallback(frame, "GroupInSpecT_Update", "UpdateHandler")
  LGIST.RegisterCallback(frame, "GroupInSpecT_Remove", "RemoveHandler")
  
  frame:RegisterEvent("ENCOUNTER_END")
  frame:RegisterEvent("ENCOUNTER_START")
  frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end
function frameEvents:COMBAT_LOG_EVENT_UNFILTERED(...)
  local timestamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceFlags2, destGUID, destName, destFlags, destFlags2 = select(1, ...)
  if event == "SPELL_CAST_SUCCESS" then
    local spellId, spellName, spellSchool = select(12, ...) --from prefix SPELL
    if spellIDs[spellId] then
      if spellIDs[spellId].aka then
        self:startCD(sourceGUID, spellIDs[spellId].aka) --pretent the caster used a different spellID (e.g. for the different forms of a druid's Stampeding Roar)
      else
        self:startCD(sourceGUID, spellId)
      end
    end
  elseif event == "UNIT_DIED" then
    --don't call this for every mob, just for raid members
    if LGIST:GetCachedInfo(destGUID) then
      self:startIsDead(destGUID)
    end
  end
end
function frameEvents:ENCOUNTER_START()
  self.crFrame.casterBar.tslU = 0
  self.crFrame.casterBar.OnUpdate = self.crFrame.casterBar.RealOnUpdate
end
function frameEvents:ENCOUNTER_END()
  self:resetAfterWipe()
  
  self.crFrame.casterBar:combatEnd()
  self.crFrame.casterBar.OnUpdate = self.crFrame.casterBar.NoOp
end
frame:SetScript("OnEvent", function(self, event, ...)
  frameEvents[event](self, ...)
end);
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

local function mysplit(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  local i = 1
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    t[i] = str
    i = i + 1
  end
  return t
end

SLASH_RAIDCDS1 = "/raidcds"
SlashCmdList["RAIDCDS"] = function(msg, editbox)
  msg = msg or ""
  args = mysplit(msg, " ")
  
  if string.lower(args[1] or "") == "move" then
    if moving then
      moving = false
      frame:SetMovable(false) --click-through
      frame:EnableMouse(false)
      frame:RegisterForDrag("")
      frame.bgtexture:Hide()
    else
      moving = true
      frame:SetMovable(true);
      frame:EnableMouse(true);
      frame:RegisterForDrag("LeftButton");
      frame.bgtexture:Show()
    end
    print("|cffaaaaffRaidCDs |rmove |cffaaaaffis now "..(moving == true and "|cffaaffaamoving" or "|cffff8888fixed"))
  elseif string.lower(args[1] or "") == "reset" then
    RaidCDsOptions["framePoint"] = DefaultO["framePoint"]
    RaidCDsOptions["frameRelativeTo"] = DefaultO["frameRelativeTo"]
    RaidCDsOptions["frameRelativePoint"] = DefaultO["frameRelativePoint"]
    RaidCDsOptions["frameOffsetX"] = DefaultO["frameOffsetX"]
    RaidCDsOptions["frameOffsetY"] = DefaultO["frameOffsetY"]
    
    frame:ClearAllPoints()
    frame:SetPoint(RaidCDsOptions["framePoint"], RaidCDsOptions["frameRelativeTo"], RaidCDsOptions["frameRelativePoint"], RaidCDsOptions["frameOffsetX"], RaidCDsOptions["frameOffsetY"])
    
    print("|cffaaaaffRaidCDs |rposition reset")
  elseif string.lower(args[1] or "") == "update" then
    print("|cffaaaaffRaidCDs is now re-scanning all raid members.")
    LGIST:Rescan()
  elseif string.lower(args[1] or "") == "toggle" then
    RaidCDsOptions["hidden"] = not(RaidCDsOptions["hidden"] and true or false)
    if RaidCDsOptions["hidden"] then
      frame:SetAlpha(0)
    else
      frame:SetAlpha(1)
    end
    print("|cffaaaaffRaidCDs is now "..(RaidCDsOptions["hidden"] and "|cffff8888hidden" or "|cffaaffaashown"))
  elseif string.lower(args[1] or "") == "hideself" then
    RaidCDsOptions["hideSelf"] = not(RaidCDsOptions["hideSelf"] and true or false)
    LGIST:Rescan(myGUID) --remove [and add again]
    print("|cffaaaaffRaidCDs is now "..(RaidCDsOptions["hideSelf"] and "|cffff8888hiding" or "|cffaaffaashowing").." |cffaaaaffyour own CDs.")
  elseif string.lower(args[1] or "") == "showcr" then
    RaidCDsOptions["showCR"] = not(RaidCDsOptions["showCR"] and true or false)
    frame:toggleCrFrame(RaidCDsOptions["showCR"])
    print("|cffaaaaffRaidCDs is now "..(RaidCDsOptions["showCR"] and "|cffaaffaashowing" or "|cffff8888hiding").." |cffaaaaffthe combat rez timer.")
  else
    print("|cffaaaaffRaidCDs |r"..(GetAddOnMetadata("RaidCDs", "Version") or "").." |cffaaaaff(use |r/raidcds <option> |cffaaaafffor these options)")
    print("  move |cffaaaafftoggle moving the frame ("..(moving == true and "|cffaaffaamoving" or "|cffff8888fixed").."|cffaaaaff)")
    print("  reset |cffaaaaffreset the frame's position")
    print("  toggle |cffaaaaffshow/hide the frame ("..(RaidCDsOptions["hidden"] and "|cffff8888hidden" or "|cffaaffaashown").."|cffaaaaff)")
    print("  hideself |cffaaaaffshow/hide own CDs ("..(RaidCDsOptions["hideSelf"] and "|cffff8888hidden" or "|cffaaffaashown").."|cffaaaaff)")
    print("  showcr |cffaaaaffshow/hide combat rez timer ("..(RaidCDsOptions["showCR"] and "|cffaaffaashown" or "|cffff8888hidden").."|cffaaaaff)")
    print("  update |cffaaaaffforce a rescan of all raid members")
  end
end
