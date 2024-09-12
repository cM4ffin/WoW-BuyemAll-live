-- hook up BuyEmAllFrame_MerchantShow to MerchantFrame_MerchantShow, so the BuyEmAll frame is shown whenever the Blizzard UI attempts to show the built-in vendor window.
hooksecurefunc('MerchantFrame_MerchantShow', function()
  BuyEmAllFrame_MerchantShow()
  BuyEmAllFrame:SetFrameLevel(2)
  MerchantFrame:SetAlpha(0);

  --position BuyEmAllFrame over MerchantFrame
  local numMerchantFramePoints = MerchantFrame:GetNumPoints();
  if(numMerchantFramePoints == 0) then
    --if MerchantFrame has no points (maybe another addon is overriding it too?), we'll use the default position.
    BuyEmAllFrame:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', 16, -116)
  else
    for i=1,numMerchantFramePoints do
      local point, relativeTo, relativePoint, offsetX, offsetY = MerchantFrame:GetPoint(i);
      if (relativeTo == nil) then relativeTo = UIParent end
      BuyEmAllFrame:SetPoint(point, relativeTo, relativePoint, offsetX, offsetY);
    end
  end
end)

--when blizz UI closes the merchant frame, we'll also close the BuyEmAll frame
hooksecurefunc('MerchantFrame_MerchantClosed', function()
  BuyEmAllFrame_MerchantClosed()
end )

hooksecurefunc('MerchantFrame_Update', function()
  BuyEmAllFrame_Update()
end)

-- when blizzard UI code calls CloseMerchant() to close the merchant window, we'll hide the BuyEmAll frame as well.
hooksecurefunc('CloseMerchant', function() 
  BuyEmAllFrame:Hide();
end)

local compatManager = {
  eventFrame = CreateFrame('Frame');
  entry = function(compatFunc) 
    local entry = { loaded = false };
    entry.onLoaded = function()
      if(entry.loaded) then return end
      compatFunc();
      entry.loaded = true;
    end
    return entry;
  end,
  init = function(self)
    for key, entry in pairs(self) do
      if(key ~= 'entry' and key ~= 'init' and type(entry) == 'table' and type(entry.onLoaded) == 'function') then
        if(select(2, C_AddOns.IsAddOnLoaded(key))) then
          entry.onLoaded()
        end
      end
    end
  end
}
compatManager.eventFrame:RegisterEvent('ADDON_LOADED');
compatManager.eventFrame:SetScript('OnEvent', function(self, event, arg1)
  if(event ~= 'ADDON_LOADED') then return end
  
  local addonName = arg1;
  if(compatManager[addonName] ~= nil and type(compatManager[addonName].onLoaded) == 'function') then
    compatManager[addonName].onLoaded();
  end
end)

compatManager.ArkInventory = compatManager.entry(function()
  local originalHook = ArkInventory.HookOpenAllBags;

  ArkInventory.HookOpenAllBags = function(self, ...)
    local who = ...
    local whoName = who
    if who then
      whoName = who:GetName( )
    end
    if(whoName == 'BuyEmAllFrame') then return end;
  
    originalHook(self, ...);
  end
end)

compatManager.SellJunk = compatManager.entry(function()
  local sellButton = LibStub("AceAddon-3.0"):GetAddon("SellJunk").sellButton;

  sellButton:SetParent(BuyEmAllFrame);
  local point, _, relativePoint, offsetX, offsetY = sellButton:GetPoint();
  sellButton:SetPoint(point, BuyEmAllFrame, relativePoint, offsetX, offsetY);
end)

compatManager.Scrap = compatManager.entry(function()
  hooksecurefunc('BuyEmAllFrame_MerchantShow', function()
    local children = {MerchantBuyBackItem:GetChildren()}
    for _, v in pairs(children) do
      if v.AnyJunk ~= nil then
        v:SetParent(BuyEmAllSellAllJunkButton)
        v:ClearAllPoints();
        v:SetAllPoints(BuyEmAllSellAllJunkButton)
      end
    end
  end)
end)

compatManager.BlizzMove = compatManager.entry(function()
  _G.BlizzMoveAPI:RegisterAddOnFrames({ ['BuyEmAll'] = {['BuyEmAllFrame'] = { MinVersion = 0 }}})
end)

compatManager:init();

local tabsCache = {};

hooksecurefunc('BuyEmAllFrame_MerchantShow', function()
  local tabs = LibStub("SecureTabs-2.0").tabs[MerchantFrame];
  for _, tab in pairs(tabs) do
    if(tabsCache[tab.frame] == nil) then
      LibStub("SecureTabs-2.0"):Add(BuyEmAllFrame, tab.frame, tab:GetText());
      tabsCache[tab.frame] = true;
    end
  end
end)