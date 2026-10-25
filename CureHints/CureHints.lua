--[[
    CureHints 1.1 by feralpaw
    For World of Warcraft 3.3.5a (Wrath of the Lich King)

    An add-on for Decursive (tested with Decursive 2.4.5.1, 2.5.0, 2.5.1 and 2.5.2.x).
    Unofficial: not made by, endorsed by or affiliated with the author of Decursive.
    This file contains no Decursive code; it only uses Decursive's public objects at run time.

    What it does
      * Puts a small letter on every Decursive square that shows a curable debuff,
        telling you which mouse button cures it:
            L = left click, R = right click, M = middle click
            prefix c / s / a = Ctrl / Shift / Alt (e.g. "cL" = Ctrl + left click)
        The letters follow your own button setup in Decursive's options.
      * Test mode (/curehints test): gives every shown square a fake debuff that
        cycles through all cure types your class has, so you can see every colour
        and letter without a real debuff. Switches itself off when combat starts.

    Commands
      /curehints          help
      /curehints test     toggle test mode
      /curehints on|off   show / hide the letters
--]]

local ADDON_NAME = ...;
local VERSION    = "1.1";

local floor     = math.floor;
local band      = bit.band;
local GetTime   = GetTime;
local UnitExists = UnitExists;
local InCombatLockdown = InCombatLockdown;

local CH = CreateFrame("Frame");
CH.Version = VERSION;
_G.CureHints = CH;

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF33CCFFCureHints:|r " .. msg);
end

-- Decursive 2.4.5.1 keeps its button list in a local table we can't read.
-- This is that list; newer versions store it in D.db.global.AvailableButtons.
local LEGACY_BUTTONS = {
    "%s1", "%s2", "ctrl-%s1", "ctrl-%s2", "shift-%s1", "shift-%s2", "alt-%s1", "alt-%s2",
};

local D, DC, MUF;           -- Decursive objects, filled in Init()
local Hooked = false;

---------------------------------------------------------------------------
-- Click hint letters
---------------------------------------------------------------------------
local ButtonLetters = { ["1"] = "L", ["2"] = "R", ["3"] = "M" };
local ModLetters    = { ctrl = "c", shift = "s", alt = "a" };
local HintCache     = {};

local function GetButtonList()
    local db = D.db and D.db.global;
    if db and type(db.AvailableButtons) == "table" and #db.AvailableButtons > 0 then
        return db.AvailableButtons;
    end
    return LEGACY_BUTTONS;
end

local function GetHint(Prio)
    if not Prio then return ""; end
    local Pattern = GetButtonList()[Prio];
    if not Pattern then return ""; end

    local Hint = HintCache[Pattern];
    if not Hint then
        local Mod, Button = Pattern:match("^(%a*)%-?%%s(%d)$");
        Hint = (Mod and ModLetters[Mod] or "") .. (ButtonLetters[Button or ""] or "?");
        HintCache[Pattern] = Hint;
    end
    return Hint;
end

local function UpdateHint(MF)
    local Frame = MF.Frame;
    if not Frame then return; end

    local FS = MF.CureHintsText;
    if not FS then
        FS = Frame:CreateFontString(nil, "OVERLAY");
        FS:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE");
        FS:SetPoint("TOPLEFT", Frame, "TOPLEFT", 1, -1);
        FS:SetTextColor(1, 1, 1, 1);
        MF.CureHintsText = FS;
        MF.CureHintsShown = "";
    end

    local Text = "";
    if CureHintsDB.Enabled and MF.IsDebuffed and MF.UnitStatus
        and band(MF.UnitStatus, DC.AFFLICTED + DC.AFFLICTED_NIR) ~= 0 then
        Text = GetHint(MF.Debuff1Prio);
    end

    if MF.CureHintsShown ~= Text then
        FS:SetText(Text);
        MF.CureHintsShown = Text;
    end
end

local function RefreshAllHints()
    if not (MUF and MUF.ExistingPerUNIT) then return; end
    for _, MF in pairs(MUF.ExistingPerUNIT) do
        UpdateHint(MF);
    end
end

---------------------------------------------------------------------------
-- Test mode
---------------------------------------------------------------------------
local SWITCH_EVERY = 3;   -- seconds between fake debuff type changes
local TEST_ICON    = "Interface\\Icons\\Spell_Holy_DispelMagic";

local Test = { Active = false, StartTime = 0, Types = {}, UnitOffset = {}, NextOffset = 0, Fake = {} };
CH.Test = Test;

local function BuildTypeList()
    wipe(Test.Types);
    local CuringSpells = D.Status and D.Status.CuringSpells;
    local Order        = D.Status and D.Status.ReversedCureOrder;
    if not (CuringSpells and Order) then return; end

    local Seen = {};
    for i = 1, #Order do
        local Type  = Order[i];
        local Spell = CuringSpells[Type];
        -- "enemy magic" needs a mind-controlled (hostile) unit, it can't be faked on a friend
        if Spell and Type ~= DC.ENEMYMAGIC and not Seen[Spell] then
            Seen[Spell] = true;
            Test.Types[#Test.Types + 1] = Type;
        end
    end
end

local function GetFakeDebuffs(Unit)
    if not Test.UnitOffset[Unit] then
        Test.UnitOffset[Unit] = Test.NextOffset;
        Test.NextOffset = Test.NextOffset + 1;
    end

    local Step = floor((GetTime() - Test.StartTime) / SWITCH_EVERY);
    local Type = Test.Types[((Test.UnitOffset[Unit] + Step) % #Test.Types) + 1];
    local TypeName = DC.TypeNames[Type] or "Magic";

    local List = Test.Fake[Unit];
    if not List then
        List = { {}, {} };
        Test.Fake[Unit] = List;
    end
    local Debuff = List[1];
    Debuff.Name           = "CureHints test (" .. TypeName .. ")";
    Debuff.TypeName       = TypeName;
    Debuff.Type           = Type;
    Debuff.Texture        = TEST_ICON;
    Debuff.Applications   = 1;
    Debuff.expirationTime = GetTime() + 60;
    Debuff.index          = 1;
    List[2].Type = false;   -- end marker, like Decursive's own table

    return List, false;
end

local function RescanAll()
    if not (MUF and MUF.ExistingPerUNIT) then return; end
    for Unit in pairs(MUF.ExistingPerUNIT) do
        MUF:UpdateMUFUnit(Unit);
    end
end

local Ticker = CreateFrame("Frame");
Ticker:Hide();
Ticker.Elapsed = 0;
Ticker:SetScript("OnUpdate", function(self, elapsed)
    self.Elapsed = self.Elapsed + elapsed;
    if self.Elapsed >= SWITCH_EVERY then
        self.Elapsed = 0;
        RescanAll();
    end
end);

function Test:Start()
    if not Hooked then
        Print("|cFFFF5555Decursive is not loaded.|r");
        return;
    end
    if InCombatLockdown() then
        Print("|cFFFF5555Test mode can't be started in combat.|r");
        return;
    end
    if not (D.profile and D.profile.ShowDebuffsFrame) then
        Print("|cFFFF5555The Decursive squares are hidden, show them first (/dcrshow).|r");
        return;
    end

    BuildTypeList();
    if #self.Types == 0 then
        Print("|cFFFF5555Your character has no cure spell Decursive can use.|r");
        return;
    end

    wipe(self.UnitOffset);
    self.NextOffset = 0;
    self.StartTime  = GetTime();
    self.Active     = true;
    Ticker.Elapsed  = 0;
    Ticker:Show();
    RescanAll();

    local Names = {};
    for i, Type in ipairs(self.Types) do Names[i] = DC.TypeNames[Type]; end
    Print("|cFF55FF55Test mode ON|r - fake debuffs: " .. table.concat(Names, ", ") .. ". Type /curehints test again to stop.");
end

function Test:Stop(Reason)
    if not self.Active then return; end
    self.Active = false;
    Ticker:Hide();
    RescanAll();
    Print("|cFFFF5555Test mode OFF|r" .. (Reason and (" (" .. Reason .. ")") or ""));
end

---------------------------------------------------------------------------
-- Hooks into Decursive
---------------------------------------------------------------------------
local function Init()
    if Hooked then return true; end

    D   = _G.Dcr;
    DC  = _G.DcrC;
    MUF = D and D.MicroUnitF;

    if not (D and DC and MUF and MUF.prototype and MUF.prototype.SetColor
            and D.GetUnitDebuffAll and DC.AFFLICTED and DC.AFFLICTED_NIR) then
        return false;
    end

    -- letters: refresh after Decursive has coloured a square
    local Orig_SetColor = MUF.prototype.SetColor;
    MUF.prototype.SetColor = function(self, ...)
        local r = Orig_SetColor(self, ...);
        UpdateHint(self);
        return r;
    end

    -- test mode: hand Decursive fake debuffs while the test is running
    local Orig_GetUnitDebuffAll = D.GetUnitDebuffAll;
    D.GetUnitDebuffAll = function(self, Unit, ...)
        if Test.Active and #Test.Types > 0 and Unit ~= "target" and Unit ~= "mouseover"
            and UnitExists(Unit) then
            return GetFakeDebuffs(Unit);
        end
        return Orig_GetUnitDebuffAll(self, Unit, ...);
    end

    Hooked = true;
    return true;
end

---------------------------------------------------------------------------
-- Events and slash command
---------------------------------------------------------------------------
CH:RegisterEvent("ADDON_LOADED");
CH:RegisterEvent("PLAYER_LOGIN");
CH:RegisterEvent("PLAYER_REGEN_DISABLED");
CH:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            CureHintsDB = CureHintsDB or {};
            if CureHintsDB.Enabled == nil then CureHintsDB.Enabled = true; end
        end
        if arg1 == ADDON_NAME or arg1 == "Decursive" then
            Init();
        end
    elseif event == "PLAYER_LOGIN" then
        if not Init() then
            Print("|cFFFF5555Decursive was not found or is not supported - CureHints is inactive.|r");
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        Test:Stop("entered combat");
    end
end);

SLASH_CUREHINTS1 = "/curehints";
SlashCmdList["CUREHINTS"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$");
    if msg == "test" then
        if Test.Active then Test:Stop(); else Test:Start(); end
    elseif msg == "on" or msg == "off" then
        CureHintsDB.Enabled = (msg == "on");
        RefreshAllHints();
        Print("letters " .. (CureHintsDB.Enabled and "|cFF55FF55shown|r" or "|cFFFF5555hidden|r") .. ".");
    else
        Print("version " .. VERSION .. (Hooked and "" or " |cFFFF5555(Decursive not found)|r"));
        Print("/curehints test - toggle test mode (fake debuffs on all squares)");
        Print("/curehints on | off - show or hide the L / R / M letters");
    end
end
