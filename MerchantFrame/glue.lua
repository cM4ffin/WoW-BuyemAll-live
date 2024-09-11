-- hook up BuyEmAllFrame_MerchantShow to MerchantFrame_MerchantShow, so the BuyEmAll frame is shown whenever the Blizzard UI attempts to show the built-in vendor window.
hooksecurefunc('MerchantFrame_MerchantShow', function()
  BuyEmAllFrame_MerchantShow()
  BuyEmAllFrame:SetFrameLevel(2)
  MerchantFrame:SetAlpha(0);

  --position BuyEmAlLFrame over MerchantFrame
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

-- when blizzard UI code calls CloseMerchant() to close the merchant window, we'll hide the BuyEmAll frame as well.
hooksecurefunc('CloseMerchant', function() 
  BuyEmAllFrame:Hide();
end)