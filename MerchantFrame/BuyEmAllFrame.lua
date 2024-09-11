local MAX_MONEY_DISPLAY_WIDTH = 120;

function BuyEmAllFrame_OnLoad(self)
	self:RegisterEvent("MERCHANT_UPDATE");
	self:RegisterEvent("GUILDBANK_UPDATE_MONEY");
	self:RegisterEvent("HEIRLOOMS_UPDATED");
	self:RegisterEvent("BAG_UPDATE");
	self:RegisterEvent("MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL");
	self:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player");
	self:RegisterForDrag("LeftButton");
	self.page = 1;
	-- Tab Handling code
	PanelTemplates_SetNumTabs(self, 2);
	PanelTemplates_SetTab(self, 1);

	MoneyFrame_SetMaxDisplayWidth(BuyEmAllMoneyFrame, 160);

	self.FilterDropdown:SetWidth(152);
	self.FilterDropdown:SetSelectionTranslator(function(selection)
		-- "All Specializations" is replaced with the player's class.
		if selection.data == LE_LOOT_FILTER_CLASS then
			return UnitClass("player");
		end

		return selection.text;
	end);

	local function SetSelected(filter)
		SetMerchantFilter(filter);

		BuyEmAllFrame.page = 1;
		BuyEmAllFrame_Update();
	end
	
	local function IsSelected(filter)
		return GetMerchantFilter() == filter;
	end
	
	self.FilterDropdown:SetupMenu(function(dropdown, rootDescription)
		rootDescription:SetTag("MENU_MERCHANT_FRAME");

		local className = UnitClass("player");
		local sex = UnitSex("player");
		
		for index = 1, GetNumSpecializations() do
			local isInspect = nil;
			local isPet = nil;
			local inspectTarget = nil;
			local name = select(2, GetSpecializationInfo(index, isInspect, isPet, inspectTarget, sex));

			local filter = (LE_LOOT_FILTER_SPEC1 + index) - 1;
			rootDescription:CreateRadio(name, IsSelected, SetSelected, filter);
		end

		rootDescription:CreateRadio(ALL_SPECS, IsSelected, SetSelected, LE_LOOT_FILTER_CLASS);
		rootDescription:CreateDivider();
		rootDescription:CreateRadio(ITEM_BIND_ON_EQUIP, IsSelected, SetSelected, LE_LOOT_FILTER_BOE);
		rootDescription:CreateRadio(ALL, IsSelected, SetSelected, LE_LOOT_FILTER_ALL);
	end);
end

function BuyEmAllFrame_MerchantShow()
	ShowUIPanel(BuyEmAllFrame);
	if ( not BuyEmAllFrame:IsShown() ) then
		CloseMerchant();
		return;
	end
	BuyEmAllFrame.page = 1;
	BuyEmAllFrame_UpdateCurrencies();
	BuyEmAllFrame_Update();
end

function BuyEmAllFrame_MerchantClosed()
	BuyEmAllFrame:UnregisterEvent("CURRENCY_DISPLAY_UPDATE");
	StaticPopup_Hide("CONFIRM_MERCHANT_TRADE_TIMER_REMOVAL");
	HideUIPanel(BuyEmAllFrame);
end

function BuyEmAllFrame_OnEvent(self, event, ...)
	if ( event == "MERCHANT_UPDATE" and "MERCHANT_FILTER_ITEM_UPDATE" ) then
		self.update = true;
	elseif ( event == "PLAYER_MONEY" or event == "GUILDBANK_UPDATE_MONEY" or event == "GUILDBANK_UPDATE_WITHDRAWMONEY" ) then
		BuyEmAllFrame_UpdateCanRepairAll();
		BuyEmAllFrame_UpdateRepairButtons();
	elseif ( event == "CURRENCY_DISPLAY_UPDATE" or event == "BAG_UPDATE") then
		BuyEmAllFrame_UpdateCurrencyAmounts();
		BuyEmAllFrame_Update();
	elseif ( event == "HEIRLOOMS_UPDATED" ) then
		local itemID, updateReason = ...;
		if itemID and updateReason == "NEW" then
			BuyEmAllFrame_Update();
		end
	elseif ( event == "MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL" ) then
		local item = ...;
		StaticPopup_Show("CONFIRM_MERCHANT_TRADE_TIMER_REMOVAL", item);
	elseif ( event == "GET_ITEM_INFO_RECEIVED" ) then
		BuyEmAllFrame_UpdateItemQualityBorders(self);
	elseif ( event == "UNIT_INVENTORY_CHANGED" ) then
		BuyEmAllFrame_Update();
	end
end

function BuyEmAllFrame_OnUpdate(self, dt)
	if ( self.update == true ) then
		self.update = false;
		if ( self:IsVisible() ) then
			BuyEmAllFrame_Update();
		end
	end
	if ( BuyEmAllFrame.itemHover ) then
		if ( IsModifiedClick("DRESSUP") ) then
			ShowInspectCursor();
		else
			if (CanAffordMerchantItem(BuyEmAllFrame.itemHover) == false) then
				SetCursor("BUY_ERROR_CURSOR");
			else
				SetCursor("BUY_CURSOR");
			end
		end
	end
	if ( BuyEmAllRepairItemButton:IsShown() ) then
		if ( InRepairMode() ) then
			BuyEmAllRepairItemButton:LockHighlight();
		else
			BuyEmAllRepairItemButton:UnlockHighlight();
		end
	end
end

function BuyEmAllFrame_OnShow(self)
	local forceUpdate = true;
	OpenAllBags(self, forceUpdate);

	-- Update repair all button status
	BuyEmAllFrame_UpdateCanRepairAll();
	BuyEmAllFrame_UpdateGuildBankRepair();
	PanelTemplates_SetTab(BuyEmAllFrame, 1);

	ResetSetMerchantFilter();
	self.FilterDropdown:Update();

	BuyEmAllFrame_Update();
	PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN);
end

function BuyEmAllFrame_OnHide(self)
	if(BuyEmAllBulkBuyFrame:IsShown()) then
		BuyEmAllBulkBuyFrame:Hide();
	end
	
	CloseMerchant();

	local forceUpdate = true;
	CloseAllBags(self, forceUpdate);

	ResetCursor();

	StaticPopup_Hide("CONFIRM_PURCHASE_TOKEN_ITEM");
	StaticPopup_Hide("CONFIRM_PURCHASE_ITEM_DELAYED");
	StaticPopup_Hide("CONFIRM_REFUND_TOKEN_ITEM");
	StaticPopup_Hide("CONFIRM_REFUND_MAX_HONOR");
	StaticPopup_Hide("CONFIRM_REFUND_MAX_ARENA_POINTS");
	PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE);
end

function BuyEmAllFrame_OnMouseWheel(self, value)
	if ( value > 0 ) then
		if ( BuyEmAllPrevPageButton:IsShown() and BuyEmAllPrevPageButton:IsEnabled() ) then
			BuyEmAllPrevPageButton_OnClick();
		end
	else
		if ( BuyEmAllNextPageButton:IsShown() and BuyEmAllNextPageButton:IsEnabled() ) then
			BuyEmAllNextPageButton_OnClick();
		end
	end
end

function BuyEmAllFrame_Update()
	if ( BuyEmAllFrame.lastTab ~= BuyEmAllFrame.selectedTab ) then
		BuyEmAllFrame_CloseStackSplitFrame();
		BuyEmAllFrame.lastTab = BuyEmAllFrame.selectedTab;
	end

	BuyEmAllFrame.FilterDropdown:Update();

	if ( BuyEmAllFrame.selectedTab == 1 ) then
		BuyEmAllFrame_UpdateMerchantInfo();
	else
		BuyEmAllFrame_UpdateBuybackInfo();
	end

	local hasJunkItems = C_MerchantFrame.GetNumJunkItems() > 0;
	BuyEmAllSellAllJunkButton.Icon:SetDesaturated(not hasJunkItems);
	BuyEmAllSellAllJunkButton:SetEnabled(hasJunkItems);
end

function BuyEmAllFrameItem_UpdateQuality(self, link, isBound)
	local quality = link and select(3, C_Item.GetItemInfo(link)) or nil;
	if ( quality ) then
		self.Name:SetTextColor(ITEM_QUALITY_COLORS[quality].r, ITEM_QUALITY_COLORS[quality].g, ITEM_QUALITY_COLORS[quality].b);
	else
		self.Name:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
		BuyEmAllFrame_RegisterForQualityUpdates();
	end

	local doNotSuppressOverlays = false;
	self.ItemButton:SetItemButtonQuality(quality, link, doNotSuppressOverlays, isBound);
end

function BuyEmAllFrame_RegisterForQualityUpdates()
	if ( not BuyEmAllFrame:IsEventRegistered("GET_ITEM_INFO_RECEIVED") ) then
		BuyEmAllFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED");
	end
end

function BuyEmAllFrame_UnregisterForQualityUpdates()
	if ( BuyEmAllFrame:IsEventRegistered("GET_ITEM_INFO_RECEIVED") ) then
		BuyEmAllFrame:UnregisterEvent("GET_ITEM_INFO_RECEIVED");
	end
end

function BuyEmAllFrame_UpdateItemQualityBorders(self)
	BuyEmAllFrame_UnregisterForQualityUpdates(); -- We'll re-register if we need to.

	if ( BuyEmAllFrame.selectedTab == 1 ) then
		local numMerchantItems = GetMerchantNumItems();
		for i=1, MERCHANT_ITEMS_PER_PAGE do
			local index = (((BuyEmAllFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE) + i);
			local item = _G["BuyEmAllItem"..i];
			if ( index <= numMerchantItems ) then
				local itemLink = GetMerchantItemLink(index);
				BuyEmAllFrameItem_UpdateQuality(item, itemLink);
			end
		end
	else
		local numBuybackItems = GetNumBuybackItems();
		for index=1, BUYBACK_ITEMS_PER_PAGE do
			local item = _G["BuyEmAllItem"..index];
			if ( index <= numBuybackItems ) then
				local itemLink = GetBuybackItemLink(index);
				BuyEmAllFrameItem_UpdateQuality(item, itemLink);
			end
		end
	end
end

function BuyEmAllFrame_UpdateMerchantInfo()
	BuyEmAllFrame:SetTitle(UnitName("npc"));
	BuyEmAllFrame:SetPortraitToUnit("npc");

	local numMerchantItems = GetMerchantNumItems();

	BuyEmAllPageText:SetFormattedText(MERCHANT_PAGE_NUMBER, BuyEmAllFrame.page, math.ceil(numMerchantItems / MERCHANT_ITEMS_PER_PAGE));

	local name, texture, price, stackCount, numAvailable, isPurchasable, isUsable, extendedCost, currencyID;
	for i=1, MERCHANT_ITEMS_PER_PAGE do
		local index = (((BuyEmAllFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE) + i);
		local itemButton = _G["BuyEmAllItem"..i.."ItemButton"];
		local merchantButton = _G["BuyEmAllItem"..i];
		local merchantMoney = _G["BuyEmAllItem"..i.."MoneyFrame"];
		local merchantAltCurrency = _G["BuyEmAllItem"..i.."AltCurrencyFrame"];
		if ( index <= numMerchantItems ) then
			name, texture, price, stackCount, numAvailable, isPurchasable, isUsable, extendedCost, currencyID = GetMerchantItemInfo(index);

			if(currencyID) then
				name, texture, numAvailable = CurrencyContainerUtil.GetCurrencyContainerInfo(currencyID, numAvailable, name, texture, nil);
			end

			local canAfford = CanAffordMerchantItem(index);
			_G["BuyEmAllItem"..i.."Name"]:SetText(name);
			SetItemButtonCount(itemButton, stackCount);
			SetItemButtonStock(itemButton, numAvailable);
			SetItemButtonTexture(itemButton, texture);

			if ( extendedCost and (price <= 0) ) then
				itemButton.price = nil;
				itemButton.extendedCost = true;
				itemButton.name = name;
				itemButton.link = GetMerchantItemLink(index);
				itemButton.texture = texture;
				BuyEmAllFrame_UpdateAltCurrency(index, i, canAfford);
				merchantAltCurrency:ClearAllPoints();
				merchantAltCurrency:SetPoint("BOTTOMLEFT", "BuyEmAllItem"..i.."NameFrame", "BOTTOMLEFT", 0, 31);
				merchantMoney:Hide();
				merchantAltCurrency:Show();
			elseif ( extendedCost and (price > 0) ) then
				itemButton.price = price;
				itemButton.extendedCost = true;
				itemButton.name = name;
				itemButton.link = GetMerchantItemLink(index);
				itemButton.texture = texture;
				local altCurrencyWidth = BuyEmAllFrame_UpdateAltCurrency(index, i, canAfford);
				MoneyFrame_SetMaxDisplayWidth(merchantMoney, MAX_MONEY_DISPLAY_WIDTH - altCurrencyWidth);
				MoneyFrame_Update(merchantMoney:GetName(), price);
				local color;
				if (canAfford == false) then
					color = "gray";
				end
				SetMoneyFrameColor(merchantMoney:GetName(), color);
				merchantAltCurrency:ClearAllPoints();
				merchantAltCurrency:SetPoint("LEFT", merchantMoney:GetName(), "RIGHT", -14, 0);
				merchantAltCurrency:Show();
				merchantMoney:Show();
			else
				itemButton.price = price;
				itemButton.extendedCost = nil;
				itemButton.name = name;
				itemButton.link = GetMerchantItemLink(index);
				itemButton.texture = texture;
				MoneyFrame_SetMaxDisplayWidth(merchantMoney, MAX_MONEY_DISPLAY_WIDTH);
				MoneyFrame_Update(merchantMoney:GetName(), price);
				local color;
				if (canAfford == false) then
					color = "gray";
				end
				SetMoneyFrameColor(merchantMoney:GetName(), color);
				merchantAltCurrency:Hide();
				merchantMoney:Show();
			end

			local itemLink = GetMerchantItemLink(index);
			BuyEmAllFrameItem_UpdateQuality(merchantButton, itemLink);

			local merchantItemID = GetMerchantItemID(index);
			local isHeirloom = merchantItemID and C_Heirloom.IsItemHeirloom(merchantItemID);
			local isKnownHeirloom = isHeirloom and C_Heirloom.PlayerHasHeirloom(merchantItemID);

			itemButton.showNonrefundablePrompt = not C_MerchantFrame.IsMerchantItemRefundable(index);

			itemButton.hasItem = true;
			itemButton:SetID(index);
			itemButton:Show();

			local tintRed = not isPurchasable or (not isUsable and not isHeirloom);

			SetItemButtonDesaturated(itemButton, isKnownHeirloom);

			if ( numAvailable == 0 or isKnownHeirloom ) then
				-- If not available and not usable
				if ( tintRed ) then
					SetItemButtonNameFrameVertexColor(merchantButton, 0.5, 0, 0);
					SetItemButtonSlotVertexColor(merchantButton, 0.5, 0, 0);
					SetItemButtonTextureVertexColor(itemButton, 0.5, 0, 0);
					SetItemButtonNormalTextureVertexColor(itemButton, 0.5, 0, 0);
				else
					SetItemButtonNameFrameVertexColor(merchantButton, 0.5, 0.5, 0.5);
					SetItemButtonSlotVertexColor(merchantButton, 0.5, 0.5, 0.5);
					SetItemButtonTextureVertexColor(itemButton, 0.5, 0.5, 0.5);
					SetItemButtonNormalTextureVertexColor(itemButton,0.5, 0.5, 0.5);
				end

			elseif ( tintRed ) then
				SetItemButtonNameFrameVertexColor(merchantButton, 1.0, 0, 0);
				SetItemButtonSlotVertexColor(merchantButton, 1.0, 0, 0);
				SetItemButtonTextureVertexColor(itemButton, 0.9, 0, 0);
				SetItemButtonNormalTextureVertexColor(itemButton, 0.9, 0, 0);
			else
				SetItemButtonNameFrameVertexColor(merchantButton, 0.5, 0.5, 0.5);
				SetItemButtonSlotVertexColor(merchantButton, 1.0, 1.0, 1.0);
				SetItemButtonTextureVertexColor(itemButton, 1.0, 1.0, 1.0);
				SetItemButtonNormalTextureVertexColor(itemButton, 1.0, 1.0, 1.0);
			end
		else
			itemButton.price = nil;
			itemButton.hasItem = nil;
			itemButton.name = nil;
			itemButton:Hide();
			SetItemButtonNameFrameVertexColor(merchantButton, 0.5, 0.5, 0.5);
			SetItemButtonSlotVertexColor(merchantButton,0.4, 0.4, 0.4);
			_G["BuyEmAllItem"..i.."Name"]:SetText("");
			_G["BuyEmAllItem"..i.."MoneyFrame"]:Hide();
			_G["BuyEmAllItem"..i.."AltCurrencyFrame"]:Hide();
		end
	end

	-- Handle repair items
	BuyEmAllFrame_UpdateRepairButtons();

	-- Handle vendor buy back item
	local numBuybackItems = GetNumBuybackItems();
	local buybackName, buybackTexture, buybackPrice, buybackQuantity, buybackNumAvailable, buybackIsUsable, buybackIsBound = GetBuybackItemInfo(numBuybackItems);
	if ( buybackName ) then
		BuyEmAllBuyBackItemName:SetText(buybackName);
		SetItemButtonCount(BuyEmAllBuyBackItemItemButton, buybackQuantity);
		SetItemButtonStock(BuyEmAllBuyBackItemItemButton, buybackNumAvailable);
		SetItemButtonTexture(BuyEmAllBuyBackItemItemButton, buybackTexture);
		BuyEmAllFrameItem_UpdateQuality(BuyEmAllBuyBackItem, GetBuybackItemLink(numBuybackItems), buybackIsBound);
		MoneyFrame_Update("BuyEmAllBuyBackItemMoneyFrame", buybackPrice);
		BuyEmAllBuyBackItem:Show();

	else
		BuyEmAllBuyBackItemName:SetText("");
		SetItemButtonTexture(BuyEmAllBuyBackItemItemButton, "");
		SetItemButtonCount(BuyEmAllBuyBackItemItemButton, 0);
		BuyEmAllFrameItem_UpdateQuality(BuyEmAllBuyBackItem, nil);
		-- Hide the tooltip upon sale
		if ( GameTooltip:IsOwned(BuyEmAllBuyBackItemItemButton) ) then
			GameTooltip:Hide();
		end
	end

	-- Handle paging buttons
	if ( numMerchantItems > MERCHANT_ITEMS_PER_PAGE ) then
		if ( BuyEmAllFrame.page == 1 ) then
			BuyEmAllPrevPageButton:Disable();
		else
			BuyEmAllPrevPageButton:Enable();
		end
		if ( BuyEmAllFrame.page == ceil(numMerchantItems / MERCHANT_ITEMS_PER_PAGE) or numMerchantItems == 0) then
			BuyEmAllNextPageButton:Disable();
		else
			BuyEmAllNextPageButton:Enable();
		end
		BuyEmAllPageText:Show();
		BuyEmAllPrevPageButton:Show();
		BuyEmAllNextPageButton:Show();
	else
		BuyEmAllPageText:Hide();
		BuyEmAllPrevPageButton:Hide();
		BuyEmAllNextPageButton:Hide();
	end

	-- Show all merchant related items
	BuyEmAllBuyBackItem:Show();
	BuyEmAllFrameBottomLeftBorder:Show();

	BuyEmAllSellAllJunkButton:SetShown(C_MerchantFrame.IsSellAllJunkEnabled());

	-- Hide buyback related items
	BuyEmAllItem11:Hide();
	BuyEmAllItem12:Hide();
	BuyEmAllBuybackBG:Hide();

	-- Position merchant items
	BuyEmAllItem3:SetPoint("TOPLEFT", "BuyEmAllItem1", "BOTTOMLEFT", 0, -8);
	BuyEmAllItem5:SetPoint("TOPLEFT", "BuyEmAllItem3", "BOTTOMLEFT", 0, -8);
	BuyEmAllItem7:SetPoint("TOPLEFT", "BuyEmAllItem5", "BOTTOMLEFT", 0, -8);
	BuyEmAllItem9:SetPoint("TOPLEFT", "BuyEmAllItem7", "BOTTOMLEFT", 0, -8);
end

function BuyEmAllFrame_UpdateAltCurrency(index, indexOnPage, canAfford)
	local itemCount = GetMerchantItemCostInfo(index);
	local frameName = "BuyEmAllItem"..indexOnPage.."AltCurrencyFrame";
	local usedCurrencies = 0;
	local width = 0;

	-- update Alt Currency Frame with itemValues
	if ( itemCount > 0 ) then
		for i=1, MAX_ITEM_COST do
			local itemTexture, itemValue, itemLink = GetMerchantItemCostItem(index, i);
			if ( itemTexture ) then
				usedCurrencies = usedCurrencies + 1;
				local button = _G[frameName.."Item"..usedCurrencies];
				button.index = index;
				button.item = i;
				button.itemLink = itemLink;
				AltCurrencyFrame_Update(frameName.."Item"..usedCurrencies, itemTexture, itemValue, canAfford);
				width = width + button:GetWidth();
				if ( usedCurrencies > 1 ) then
					-- button spacing;
					width = width + 4;
				end
				button:Show();
			end
		end
		for i = usedCurrencies + 1, MAX_ITEM_COST do
			_G[frameName.."Item"..i]:Hide();
		end
	else
		for i=1, MAX_ITEM_COST do
			_G[frameName.."Item"..i]:Hide();
		end
	end
	return width;
end

function BuyEmAllFrame_UpdateBuybackInfo()
	BuyEmAllFrame:SetTitle(MERCHANT_BUYBACK);
	BuyEmAllFrame:SetPortraitToAsset("Interface\\BuyEmAllFrame\\UI-BuyBack-Icon");

	-- Show Buyback specific items
	BuyEmAllItem11:Show();
	BuyEmAllItem12:Show();
	BuyEmAllBuybackBG:Show();

	-- Position buyback items
	BuyEmAllItem3:SetPoint("TOPLEFT", "BuyEmAllItem1", "BOTTOMLEFT", 0, -15);
	BuyEmAllItem5:SetPoint("TOPLEFT", "BuyEmAllItem3", "BOTTOMLEFT", 0, -15);
	BuyEmAllItem7:SetPoint("TOPLEFT", "BuyEmAllItem5", "BOTTOMLEFT", 0, -15);
	BuyEmAllItem9:SetPoint("TOPLEFT", "BuyEmAllItem7", "BOTTOMLEFT", 0, -15);

	local numBuybackItems = GetNumBuybackItems();
	local itemButton, buybackButton;
	local buybackName, buybackTexture, buybackPrice, buybackQuantity, buybackNumAvailable, buybackIsUsable, buybackIsBound;
	local buybackItemLink;
	for i=1, BUYBACK_ITEMS_PER_PAGE do
		itemButton = _G["BuyEmAllItem"..i.."ItemButton"];
		buybackButton = _G["BuyEmAllItem"..i];
		_G["BuyEmAllItem"..i.."AltCurrencyFrame"]:Hide();
		if ( i <= numBuybackItems ) then
			buybackName, buybackTexture, buybackPrice, buybackQuantity, buybackNumAvailable, buybackIsUsable, buybackIsBound = GetBuybackItemInfo(i);
			_G["BuyEmAllItem"..i.."Name"]:SetText(buybackName);
			SetItemButtonCount(itemButton, buybackQuantity);
			SetItemButtonStock(itemButton, buybackNumAvailable);
			SetItemButtonTexture(itemButton, buybackTexture);
			_G["BuyEmAllItem"..i.."MoneyFrame"]:Show();
			MoneyFrame_Update("BuyEmAllItem"..i.."MoneyFrame", buybackPrice);
			buybackItemLink = GetBuybackItemLink(i);
			BuyEmAllFrameItem_UpdateQuality(buybackButton, buybackItemLink, buybackIsBound);
			itemButton:SetID(i);
			itemButton:Show();
			if ( not buybackIsUsable ) then
				SetItemButtonNameFrameVertexColor(buybackButton, 1.0, 0, 0);
				SetItemButtonSlotVertexColor(buybackButton, 1.0, 0, 0);
				SetItemButtonTextureVertexColor(itemButton, 0.9, 0, 0);
				SetItemButtonNormalTextureVertexColor(itemButton, 0.9, 0, 0);
			else
				SetItemButtonNameFrameVertexColor(buybackButton, 0.5, 0.5, 0.5);
				SetItemButtonSlotVertexColor(buybackButton, 1.0, 1.0, 1.0);
				SetItemButtonTextureVertexColor(itemButton, 1.0, 1.0, 1.0);
				SetItemButtonNormalTextureVertexColor(itemButton, 1.0, 1.0, 1.0);
			end
		else
			SetItemButtonNameFrameVertexColor(buybackButton, 0.5, 0.5, 0.5);
			SetItemButtonSlotVertexColor(buybackButton,0.4, 0.4, 0.4);
			_G["BuyEmAllItem"..i.."Name"]:SetText("");
			_G["BuyEmAllItem"..i.."MoneyFrame"]:Hide();
			itemButton:Hide();
		end
	end

	-- Hide all merchant related items
	BuyEmAllRepairAllButton:Hide();
	BuyEmAllRepairItemButton:Hide();
	BuyEmAllBuyBackItem:Hide();
	BuyEmAllPrevPageButton:Hide();
	BuyEmAllNextPageButton:Hide();
	BuyEmAllFrameBottomLeftBorder:Hide();
	BuyEmAllPageText:Hide();
	BuyEmAllGuildBankRepairButton:Hide();
	BuyEmAllSellAllJunkButton:Hide();
end

function BuyEmAllPrevPageButton_OnClick()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
	BuyEmAllFrame.page = BuyEmAllFrame.page - 1;
	BuyEmAllFrame_CloseStackSplitFrame();
	BuyEmAllFrame_Update();
end

function BuyEmAllNextPageButton_OnClick()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
	BuyEmAllFrame.page = BuyEmAllFrame.page + 1;
	BuyEmAllFrame_CloseStackSplitFrame();
	BuyEmAllFrame_Update();
end

function BuyEmAllFrame_CloseStackSplitFrame()
	if ( StackSplitFrame:IsShown() ) then
		local numButtons = max(MERCHANT_ITEMS_PER_PAGE, BUYBACK_ITEMS_PER_PAGE);
		for i = 1, numButtons do
			if ( StackSplitFrame.owner == _G["BuyEmAllItem"..i.."ItemButton"] ) then
				StackSplitCancelButton_OnClick();
				return;
			end
		end
	end
end

function BuyEmAllItemBuybackButton_OnLoad(self)
	self:RegisterEvent("MERCHANT_UPDATE");
	self:RegisterForClicks("LeftButtonUp","RightButtonUp");
	self:RegisterForDrag("LeftButton");

	self.SplitStack = function(button, split)
		if ( split > 0 ) then
			BuyMerchantItem(button:GetID(), split);
		end
	end

	self:SetItemButtonScale(0.65);
end

function BuyEmAllItemButton_OnLoad(self)
	self:RegisterForClicks("LeftButtonUp","RightButtonUp");
	self:RegisterForDrag("LeftButton");

	self.SplitStack = function(button, split)
		if ( button.extendedCost ) then
			BuyEmAllFrame_ConfirmExtendedItemCost(button, split)
		elseif ( button.showNonrefundablePrompt ) then
			BuyEmAllFrame_ConfirmExtendedItemCost(button, split)
		elseif ( split > 0 ) then
			BuyMerchantItem(button:GetID(), split);
		end
	end

	self.UpdateTooltip = BuyEmAllItemButton_OnEnter;
end

function BuyEmAllItemButton_OnClick(self, button)
	BuyEmAllFrame.extendedCost = nil;
	BuyEmAllFrame.highPrice = nil;

	if ( BuyEmAllFrame.selectedTab == 1 ) then
		-- Is merchant frame
		if ( button == "LeftButton" ) then
			if ( BuyEmAllFrame.refundItem ) then
				if ( ContainerFrame_GetExtendedPriceString(BuyEmAllFrame.refundItem, BuyEmAllFrame.refundItemEquipped)) then
					-- a confirmation dialog has been shown
					return;
				end
			end

			PickupMerchantItem(self:GetID());
			if ( self.extendedCost ) then
				BuyEmAllFrame.extendedCost = self;
			elseif ( self.showNonrefundablePrompt ) then
				BuyEmAllFrame.extendedCost = self;
			elseif ( self.price and self.price >= MERCHANT_HIGH_PRICE_COST ) then
				BuyEmAllFrame.highPrice = self;
			end
		else
			if ( self.extendedCost ) then
				BuyEmAllFrame_ConfirmExtendedItemCost(self);
			elseif ( self.showNonrefundablePrompt ) then
				BuyEmAllFrame_ConfirmExtendedItemCost(self);
			elseif ( self.price and self.price >= MERCHANT_HIGH_PRICE_COST ) then
				BuyEmAllFrame_ConfirmHighCostItem(self);
			else
				BuyMerchantItem(self:GetID());
			end
		end
	else
		-- Is buyback item
		BuybackItem(self:GetID());
	end
end

function BuyEmAllItemButton_OnModifiedClick(self, button)
	if ( BuyEmAllFrame.selectedTab == 1 ) then
		if ( HandleModifiedItemClick(GetMerchantItemLink(self:GetID())) ) then return end

		if ( IsModifiedClick("SPLITSTACK")) then
			BuyEmAll:ItemClicked(self, button);
			return;
		end
	else
		HandleModifiedItemClick(GetBuybackItemLink(self:GetID()));
	end
end

function BuyEmAllItemButton_OnEnter(button)
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT");
	if ( BuyEmAllFrame.selectedTab == 1 ) then
		GameTooltip:SetMerchantItem(button:GetID());
		GameTooltip_ShowCompareItem(GameTooltip);
		BuyEmAllFrame.itemHover = button:GetID();
	else
		GameTooltip:SetBuybackItem(button:GetID());
		if ( IsModifiedClick("DRESSUP") and button.hasItem ) then
			ShowInspectCursor();
		else
			ShowBuybackSellCursor(button:GetID());
		end
	end
end

LIST_DELIMITER = ", "

local function ShouldAppendSpecText(itemLink)
	if C_Item.IsItemBindToAccountUntilEquip(itemLink) then
		-- If the merchant item is "Warbound until equipped", then we only want to show a list of specs for weapons
		local isWeapon = select(6, C_Item.GetItemInfoInstant(itemLink)) == Enum.ItemClass.Weapon;
		return isWeapon;
	end

	return true;
end

function BuyEmAllFrame_ConfirmExtendedItemCost(itemButton, numToPurchase)
	local index = itemButton:GetID();
	local itemsString;
	if ( GetMerchantItemCostInfo(index) == 0 and not itemButton.showNonrefundablePrompt) then
		if ( itemButton.price and itemButton.price >= MERCHANT_HIGH_PRICE_COST ) then
			BuyEmAllFrame_ConfirmHighCostItem(itemButton);
		else
			BuyMerchantItem( itemButton:GetID(), numToPurchase );
		end
		return;
	end

	BuyEmAllFrame.itemIndex = index;
	BuyEmAllFrame.count = numToPurchase;
	MerchantFrame.itemIndex = index;
	MerchantFrame.count = numToPurchase;

	local stackCount = itemButton.count or 1;
	numToPurchase = numToPurchase or stackCount;

	local maxQuality = 0;
	local usingCurrency = false;
	for i=1, MAX_ITEM_COST do
		local itemTexture, costItemCount, costItemLink, currencyName = GetMerchantItemCostItem(index, i);
		costItemCount = costItemCount * (numToPurchase / stackCount); -- cost per stack times number of stacks
		if ( currencyName ) then
			usingCurrency = true;
			if ( itemsString ) then
				itemsString = itemsString .. ", |T"..itemTexture..":0:0:0:-1|t ".. format(CURRENCY_QUANTITY_TEMPLATE, costItemCount, currencyName);
			else
				itemsString = " |T"..itemTexture..":0:0:0:-1|t "..format(CURRENCY_QUANTITY_TEMPLATE, costItemCount, currencyName);
			end
		elseif ( costItemLink ) then
			local itemName, itemLink, itemQuality = C_Item.GetItemInfo(costItemLink);

			if ( i == 1 and GetMerchantItemCostInfo(index) == 1 ) then
				local limitedCurrencyItemInfo = BuyEmAllFrame_GetLimitedCurrencyItemInfo(itemLink);
				if ( limitedCurrencyItemInfo ) then
					BuyEmAllFrame_ConfirmLimitedCurrencyPurchase(itemButton, limitedCurrencyItemInfo, numToPurchase, costItemCount);
					return;
				end
			end

			maxQuality = math.max(itemQuality, maxQuality);
			if ( itemsString ) then
				itemsString = itemsString .. LIST_DELIMITER .. format(ITEM_QUANTITY_TEMPLATE, costItemCount, itemLink);
			else
				itemsString = format(ITEM_QUANTITY_TEMPLATE, costItemCount, itemLink);
			end
		end
	end
	if ( itemButton.showNonrefundablePrompt and itemButton.price ) then
		if ( itemsString ) then
			itemsString = itemsString .. LIST_DELIMITER .. GetMoneyString(itemButton.price);
		else
			if itemButton.price < MERCHANT_HIGH_PRICE_COST then
				BuyMerchantItem( itemButton:GetID(), numToPurchase );
				return;
			end
			itemsString = GetMoneyString(itemButton.price);
		end
	end

	if ( not usingCurrency and maxQuality <= Enum.ItemQuality.Uncommon and not itemButton.showNonrefundablePrompt) or (not itemsString and not itemButton.price) then
		BuyMerchantItem( itemButton:GetID(), numToPurchase );
		return;
	end

	local popupData, specs = BuyEmAllFrame_GetProductInfo(itemButton);
	popupData.count = numToPurchase;

	local specText;
	if (ShouldAppendSpecText(itemButton.link) and specs and #specs > 0) then
		specText = "\n\n";
		for i=1, #specs do
			local specID, specName, specDesc, specIcon = GetSpecializationInfoByID(specs[i], UnitSex("player"));
			specText = specText.." |T"..specIcon..":0:0:0:-1|t "..NORMAL_FONT_COLOR_CODE..specName..FONT_COLOR_CODE_CLOSE;
			if (i < #specs) then
				specText = specText..PLAYER_LIST_DELIMITER
			end
		end
	else
		specText = "";
	end

	if (itemButton.showNonrefundablePrompt) then
		StaticPopup_Show("CONFIRM_PURCHASE_NONREFUNDABLE_ITEM", itemsString, specText, popupData );
	else
		StaticPopup_Show("CONFIRM_PURCHASE_TOKEN_ITEM", itemsString, specText, popupData );
	end
end

function BuyEmAllFrame_GetProductInfo(itemButton)
	local itemName, itemHyperlink;
	local itemQuality = 1;
	local r, g, b = 1, 1, 1;
	if(itemButton.link) then
		itemName, itemHyperlink, itemQuality = C_Item.GetItemInfo(itemButton.link);
	end

	local specs = {};
	if ( itemName ) then
		--It's an item
		r, g, b = C_Item.GetItemQualityColor(itemQuality);
		specs = C_Item.GetItemSpecInfo(itemButton.link);
	else
		--Not an item. Could be currency or something. Just use what's on the button.
		itemName = itemButton.name;
		r, g, b = C_Item.GetItemQualityColor(1);
	end

	local productInfo = {
		texture = itemButton.texture,
		name = itemName,
		color = {r, g, b, 1},
		link = itemButton.link,
		index = itemButton:GetID(),
	};

	return productInfo, specs;
end

function BuyEmAllFrame_ResetRefundItem()
	BuyEmAllFrame.refundItem = nil;
	BuyEmAllFrame.refundItemEquipped = nil;
end

function BuyEmAllFrame_SetRefundItem(item, isEquipped)
	BuyEmAllFrame.refundItem = item;
	BuyEmAllFrame.refundItemEquipped = isEquipped;
end

function BuyEmAllFrame_ConfirmHighCostItem(itemButton, quantity)
	quantity = (quantity or 1);
	local index = itemButton:GetID();

	BuyEmAllFrame.itemIndex = index;
	BuyEmAllFrame.count = quantity;
	BuyEmAllFrame.price = itemButton.price;
	MerchantFrame.itemIndex = index;
	MerchantFrame.count = numToPurchase;
	MerchantFrame.price = itemButton.price;
	
	StaticPopup_Show("CONFIRM_HIGH_COST_ITEM", itemButton.link);
end

function BuyEmAllFrame_GetLimitedCurrencyItemInfo(itemLink)
	local itemName, iconFileID, quantity, maxQuantity, totalEarned = C_Item.GetLimitedCurrencyItemInfo(itemLink);
	if not itemName then
		return nil;
	end

	return { ["name"] = itemName, ["iconFileID"] = iconFileID, ["quantity"] = quantity, ["maxQuantity"] = maxQuantity, ["totalEarned"] = totalEarned, };
end

function BuyEmAllFrame_ConfirmLimitedCurrencyPurchase(itemButton, currencyInfo, numToPurchase, totalCurrencyCost)
	local currencyIcon = CreateTextureMarkup(currencyInfo.iconFileID, 64, 64, 16, 16, 0, 1, 0, 1, 0, 0);
	local costString = currencyIcon .. totalCurrencyCost .. " " .. currencyInfo.name;

	local alreadySpent = currencyInfo.totalEarned - currencyInfo.quantity;
	-- The amount of this limited currency that the player currently has + the amount that they can still earn
	local unusedAmount = currencyInfo.maxQuantity - alreadySpent;
	local isFinalPurchase = (unusedAmount - totalCurrencyCost <= 0);

	local popupData = BuyEmAllFrame_GetProductInfo(itemButton);
	popupData.count = numToPurchase;
	if isFinalPurchase then
		popupData.confirmationText = LIMITED_CURRENCY_PURCHASE_FINAL:format(currencyInfo.name, currencyInfo.name, costString);
	else
		popupData.confirmationText = LIMITED_CURRENCY_PURCHASE:format(costString, unusedAmount - totalCurrencyCost, currencyInfo.name, costString)
	end

	StaticPopup_Show("CONFIRM_PURCHASE_ITEM_DELAYED", nil, nil, popupData);
end

function BuyEmAllFrame_UpdateCanRepairAll()
	if ( BuyEmAllRepairAllButton.Icon ) then
		local repairAllCost, canRepair = GetRepairAllCost();
		if ( canRepair ) then
			SetDesaturation(BuyEmAllRepairAllButton.Icon, false);
			BuyEmAllRepairAllButton:Enable();
		else
			SetDesaturation(BuyEmAllRepairAllButton.Icon, true);
			BuyEmAllRepairAllButton:Disable();
		end
	end
end

function BuyEmAllFrame_UpdateGuildBankRepair()
	local repairAllCost, canRepair = GetRepairAllCost();
	if ( canRepair ) then
		SetDesaturation(BuyEmAllGuildBankRepairButton.Icon, false);
		BuyEmAllGuildBankRepairButton:Enable();
	else
		SetDesaturation(BuyEmAllGuildBankRepairButton.Icon, true);
		BuyEmAllGuildBankRepairButton:Disable();
	end
end

function BuyEmAllFrame_UpdateRepairButtons()
	if ( CanMerchantRepair() ) then
		--See if can guildbank repair
		if ( CanGuildBankRepair() ) then
			BuyEmAllRepairAllButton:SetWidth(36);
			BuyEmAllRepairAllButton:SetHeight(36);
			BuyEmAllRepairItemButton:SetWidth(36);
			BuyEmAllRepairItemButton:SetHeight(36);
			BuyEmAllRepairAllButton:SetPoint("BOTTOMRIGHT", BuyEmAllFrame, "BOTTOMLEFT", 96, 33);
			BuyEmAllRepairItemButton:SetPoint("RIGHT", BuyEmAllRepairAllButton, "LEFT", -9, 0);
			BuyEmAllSellAllJunkButton:SetPoint("RIGHT", BuyEmAllRepairAllButton, "LEFT", 128, 0);

			BuyEmAllGuildBankRepairButton:Show();
			BuyEmAllFrame_UpdateGuildBankRepair();
		else
			BuyEmAllRepairAllButton:SetWidth(36);
			BuyEmAllRepairAllButton:SetHeight(36);
			BuyEmAllRepairItemButton:SetWidth(36);
			BuyEmAllRepairItemButton:SetHeight(36);
			BuyEmAllRepairAllButton:SetPoint("BOTTOMRIGHT", BuyEmAllFrame, "BOTTOMLEFT", 118, 33);
			BuyEmAllRepairItemButton:SetPoint("RIGHT", BuyEmAllRepairAllButton, "LEFT", -8, 0);
			BuyEmAllSellAllJunkButton:SetPoint("RIGHT", BuyEmAllRepairAllButton, "LEFT", 80, 0);

			BuyEmAllGuildBankRepairButton:Hide();
		end
		BuyEmAllRepairAllButton:Show();
		BuyEmAllRepairItemButton:Show();
		BuyEmAllFrame_UpdateCanRepairAll();
	else
		BuyEmAllRepairAllButton:Hide();
		BuyEmAllRepairItemButton:Hide();
		BuyEmAllGuildBankRepairButton:Hide();
		BuyEmAllSellAllJunkButton:SetPoint("BOTTOMRIGHT", BuyEmAllFrame, "BOTTOMRIGHT", -148, 33);
	end
end

function BuyEmAllFrame_UpdateCurrencies()
	local currencies = { GetMerchantCurrencies() };

	if ( #currencies == 0 ) then	-- common case
		BuyEmAllFrame:UnregisterEvent("CURRENCY_DISPLAY_UPDATE");
		BuyEmAllMoneyFrame:SetPoint("BOTTOMRIGHT", -4, 8);
		BuyEmAllMoneyFrame:Show();
		BuyEmAllExtraCurrencyInset:Hide();
		BuyEmAllExtraCurrencyBg:Hide();
	else
		BuyEmAllFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE");
		BuyEmAllExtraCurrencyInset:Show();
		BuyEmAllExtraCurrencyBg:Show();
		BuyEmAllFrame.numCurrencies = #currencies;
		if ( BuyEmAllFrame.numCurrencies > 3 ) then
			BuyEmAllMoneyFrame:Hide();
		else
			BuyEmAllMoneyFrame:SetPoint("BOTTOMRIGHT", -169, 8);
			BuyEmAllMoneyFrame:Show();
		end
		for index = 1, BuyEmAllFrame.numCurrencies do
			local tokenButton = _G["BuyEmAllToken"..index];
			-- if this button doesn't exist yet, create it and anchor it
			if ( not tokenButton ) then
				tokenButton = CreateFrame("BUTTON", "BuyEmAllToken"..index, BuyEmAllFrame, "BackpackTokenTemplate");
				-- token display order is: 6 5 4 | 3 2 1
				if ( index == 1 ) then
					tokenButton:SetPoint("BOTTOMRIGHT", -16, 8);
				elseif ( index == 4 ) then
					tokenButton:SetPoint("BOTTOMLEFT", 89, 8);
				else
					tokenButton:SetPoint("RIGHT", _G["BuyEmAllToken"..index - 1], "LEFT", 0, 0);
				end
				tokenButton:SetScript("OnEnter", BuyEmAllFrame_ShowCurrencyTooltip);
			end

			local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(currencies[index]);
			local name = currencyInfo.name;
			local count = currencyInfo.quantity;
			local icon = currencyInfo.iconFileID;
			if ( name and name ~= "" ) then
				tokenButton.Icon:SetTexture(icon);
				tokenButton.currencyID = currencies[index];
				tokenButton:Show();
				BuyEmAllFrame_UpdateCurrencyButton(tokenButton);
			else
				tokenButton.currencyID = nil;
				tokenButton:Hide();
			end
		end
	end

	for i = #currencies + 1, MAX_MERCHANT_CURRENCIES do
		local tokenButton = _G["BuyEmAllToken"..i];
		if ( tokenButton ) then
			tokenButton.currencyID = nil;
			tokenButton:Hide();
		else
			break;
		end
	end
end

function BuyEmAllFrame_ShowCurrencyTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetCurrencyByID(self.currencyID);
end

function BuyEmAllFrame_UpdateCurrencyAmounts()
	for i = 1, MAX_MERCHANT_CURRENCIES do
		local tokenButton = _G["BuyEmAllToken"..i];
		if ( tokenButton ) then
			BuyEmAllFrame_UpdateCurrencyButton(tokenButton);
		else
			return;
		end
	end
end

function BuyEmAllFrame_UpdateCurrencyButton(tokenButton)
	if ( tokenButton.currencyID ) then
		local count = C_CurrencyInfo.GetCurrencyInfo(tokenButton.currencyID).quantity;
		local displayCount = count;
		local displayWidth = 50;
		if ( count > 99999 ) then
			if BuyEmAllFrame.numCurrencies == 1 then
				displayWidth = 100;
			else
				displayCount = "*"
			end
		end
		tokenButton.Count:SetText(displayCount);
		tokenButton:SetWidth(displayWidth);
	end
end

function BuyEmAllFrame_OnSellAllJunkButtonConfirmed()
	C_MerchantFrame.SellAllJunkItems();
end

local popupData = { text = SELL_ALL_JUNK_ITEMS_POPUP, callback = BuyEmAllFrame_OnSellAllJunkButtonConfirmed };

function BuyEmAllFrame_OnSellAllJunkButtonClicked()
	GameTooltip:Hide();
	StaticPopup_ShowCustomGenericConfirmation(popupData);
end


function BuyEmAllBuyBackButton_OnEnter(button)
	BuyEmAllBuyBackItem.itemHover = button:GetID();
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT");
	GameTooltip:SetBuybackItem(GetNumBuybackItems());
end

function BuyEmAllBuyBackButton_OnLeave()
	GameTooltip_HideResetCursor();
	BuyEmAllBuyBackItem.itemHover = nil;
end

function UpdateCursorAfterBuyBack(buybackButton)
	if ( BuyEmAllBuyBackItem.itemHover ~= buybackButton:GetID() ) then
		return;
	end

	if (GetNumBuybackItems() == 0) then
		SetCursor("BUY_ERROR_CURSOR");
	else
		SetCursor("BUY_CURSOR");
	end
end