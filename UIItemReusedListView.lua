local UIItemReusedListView = class("UIItemReusedListView")

function UIItemReusedListView:ctor()
	Macro.assertFalse(false, "not support constructor, use 'UIItemReusedListView.extend' instead")
end

function UIItemReusedListView.extend(self, templateClass)
    local t = tolua.getpeer(self)
    if not t then
        t = {}
        tolua.setpeer(self, t)
    end
    setmetatable(t, UIItemReusedListView)
	self:_initialize(templateClass)
    return self	
end

local BUFFER_ZONE = 50

--[[
	templateClass 模板逻辑对象
	应实现extend(node)构造函数, 以及接口setData(data)
	
	local UIXxxListViewTemplate = class("UIXxxListViewTemplate")
	
	function UIXxxListViewTemplate:ctor() -- 不支持new必须使用extend
	end
	
	function UIXxxListViewTemplate.extend(self)
		local t = tolua.getpeer(self)
		if not t then
			t = {}
			tolua.setpeer(self, t)
		end
		setmetatable(t, UIXxxListViewTemplate)
		self:_initialize()
		return self
	end
	
	function UIXxxListViewTemplate:_initialize()
		...
	end
	
	function UIXxxListViewTemplate:setData(data)
		if self._data ~= data then  -- 注意这里需要判断引用是否相同, 以避免不必要的ui刷新
			self._data = data
			...
		end
	end
]]

function UIItemReusedListView:_initialize(templateClass)
    self._templateClass = templateClass
	
    self._itemDatas = {} -- 数据对象数组

    -- 保存item ui模板, 约定item(0)已存在模板
    self._templateNode = self:getItem(0)
    Macro.assertTrue(self._templateNode == nil, "ListView doesn't have default item!")
   	self._templateNode:removeFromParent(false)
    self:getParent():addChild(self._templateNode)
    self._templateNode:setVisible(false)
	self:removeItem(0) -- 仅removeFromParent是不够的
	self:setBounceEnabled(true)
	
	-- 初始化	
	self._lastContentPosY = 0
	self._margin = self:getItemsMargin()	
	self._itemTemplateHeight = self._templateNode:getContentSize().height
	self._spawnCount = math.floor(self:getContentSize().height / self._itemTemplateHeight) + 2
	self._reuseItemOffset = (self._itemTemplateHeight + self._margin) * self._spawnCount
	self._spawnItems = {} -- for caching
	self._preventUpdateContainer = false
	
	-- self:scheduleUpdateWithPriorityLua无效
	self:getInnerContainer():scheduleUpdateWithPriorityLua(function(dt)
		self:_update(dt)
	end, 0)
end

-- 获取List中所有的项目数据
function UIItemReusedListView:getItemDatas()
    return self._itemDatas
end

function UIItemReusedListView:pushBackItem(itemData)
	self:stopAutoScroll()	
	self:_insertItem(#self._itemDatas + 1, itemData)
end

function UIItemReusedListView:insertItem(index, itemData)
	if index <= #self._itemDatas + 1 then
		self:stopAutoScroll()
		self:_insertItem(index, itemData)
	end
end

-- ccui.ListView已有removeItem方法
function UIItemReusedListView:deleteItem(index)
	if index <= #self._itemDatas then
		self:stopAutoScroll()
		self:_deleteItem(index)
	end	
end

-- ccui.ListView已有removeAllItems方法
function UIItemReusedListView:deleteAllItems()
	self:stopAutoScroll()
	self._itemDatas = {}
	self._spawnItems = {}
	self:removeAllItems()
	self:_updateContainer()
end

-- 同帧大量增删数据项目时使用, 提高效率
-- 例如初始化时或者大量删除项目时
function UIItemReusedListView:beginUpdateItemDatas()
	self._preventUpdateContainer = true
end

function UIItemReusedListView:endUpdateItemDatas()
	self._preventUpdateContainer = false
	self:_updateContainer()
end

-- 重新排列, 出于性能考虑不修改item内容
function UIItemReusedListView:_rearrangeSpawnItems()
	local spawnItems = self:getItems()
	local positions = {}
	for itemId, spawned in ipairs(spawnItems) do
		positions[itemId] = spawned:getPositionY()
	end
	table.sort(spawnItems, function(a, b) return a._itemId < b._itemId end)
	for itemId, spawned in ipairs(spawnItems) do
		spawned:setPositionY(positions[itemId])		
	end
	self._spawnItems = spawnItems
end

function UIItemReusedListView:_insertItem(index, itemData)
	table.insert(self._itemDatas, index, itemData)
	if #self._itemDatas <= self._spawnCount then
		local itemNode = self._templateClass.extend(self._templateNode:clone())
		itemNode:setVisible(true)
		itemNode:setData(itemData)
		itemNode._itemId = index
		self:insertCustomItem(itemNode, index - 1)
		self:forceDoLayout()
		self:_rearrangeSpawnItems()
	end

	-- refresh content
	local first = self._spawnItems[1]._itemId
	local offset = index < first and 1 or 0
	local firstItemId = first + offset
	for n, spawned in ipairs(self._spawnItems) do
		spawned:setData(self._itemDatas[firstItemId + n - 1])
		spawned._itemId = firstItemId + n - 1
	end
	self:_updateContainer()
end


function UIItemReusedListView:_updateContainer()
	if self._preventUpdateContainer then return end
		
	local totalCount = #self._itemDatas
	local totalHeight = self._itemTemplateHeight * totalCount + (totalCount - 1) * self._margin
	if totalHeight < self:getContentSize().height then
		totalHeight = self:getContentSize().height
	end

	-- 空列表
	if totalCount == 0 then
		self:getInnerContainer():setContentSize(cc.size(self:getInnerContainerSize().width, totalHeight))
		self:getInnerContainer():forceDoLayout()
		self:getInnerContainer():setPositionY(0)
		self._lastContentPosY = 0
		return
	end
	
	local oldFirstItemPosInView = self:_getItemPositionYInView(self._spawnItems[1])
	self:getInnerContainer():setContentSize(cc.size(self:getInnerContainerSize().width, totalHeight))
	self:getInnerContainer():forceDoLayout()	
	for _, spawned in ipairs(self._spawnItems) do
		local itemId = spawned._itemId		
		spawned:setPositionY(totalHeight - (itemId * self._itemTemplateHeight + (itemId - 1) * self._margin))		
	end
	
	-- 尽量保持项目在列表的原位置
	local firstItemPos = self._spawnItems[1]:getPositionY()
	local newContentPos = oldFirstItemPosInView - firstItemPos
	local newContentPos = math.max(math.min(newContentPos, 0), -(totalHeight - self:getContentSize().height))
	self:getInnerContainer():setPositionY(newContentPos)
	self._lastContentPosY = newContentPos	
end

function UIItemReusedListView:_deleteItem(index)
	table.remove(self._itemDatas, index)
	if #self._itemDatas < self._spawnCount then
		self:removeItem(index - 1)
		self:forceDoLayout()
		self:_rearrangeSpawnItems()
	end

	if #self._itemDatas == 0 then
		self:_updateContainer()
		return
	end

	-- refresh content
	local first = self._spawnItems[1]._itemId
	local last = self._spawnItems[#self._spawnItems]._itemId
	local offset = (index <= last and first > 1) and -1 or 0
	local firstItemId = first + offset
	for n, spawned in ipairs(self._spawnItems) do
		spawned:setData(self._itemDatas[firstItemId + n - 1])
		spawned._itemId = firstItemId + n - 1
	end
	self:_updateContainer()
end

function UIItemReusedListView:_update(dt)
	local containerY = self:getInnerContainer():getPositionY()
	if containerY == self._lastContentPosY then return end
	
	local totalCount = #self._itemDatas
	local totalHeight = self._itemTemplateHeight * totalCount + (totalCount - 1) * self._margin
	local listViewHeight = self:getContentSize().height
	local items = self._spawnItems
	local isDown = containerY < self._lastContentPosY	
	
	local isDirty = false
	repeat
		local isMoved = false
		local i = 1
		while i <= self._spawnCount and i <= totalCount do
			local item = items[i]
			if item == nil then
				Logger.debug("UIItemReusedListView item nil: i = %d, count = %d, spawnCount = %d, totalCount = %d", i, #items, self._spawnCount, totalCount)
			end
			local itemPos = self:_getItemPositionYInView(item)
			if isDown then
				if itemPos < -self._itemTemplateHeight - BUFFER_ZONE and item:getPositionY() + self._reuseItemOffset < totalHeight then
					local itemId = item._itemId - #items
					item:setPositionY(item:getPositionY() + self._reuseItemOffset)
					item:setData(self._itemDatas[itemId])
					item._itemId = itemId
					isDirty, isMoved = true, true
				end
			else
				if itemPos > listViewHeight + BUFFER_ZONE and item:getPositionY() - self._reuseItemOffset >= 0 then
					item:setPositionY(item:getPositionY() - self._reuseItemOffset)
					local itemId = item._itemId + #items
					item:setData(self._itemDatas[itemId])
					item._itemId = itemId
					isDirty, isMoved = true, true
				end
			end
			i = i + 1
		end
	until not isMoved
	
	if isDirty then
		table.sort(self._spawnItems, function(a, b) return a._itemId < b._itemId end)
	end	
	
	self._lastContentPosY = self:getInnerContainer():getPositionY()	
end

function UIItemReusedListView:_getItemPositionYInView(itemNode)
	local worldPos = itemNode:getParent():convertToWorldSpaceAR(cc.p(itemNode:getPosition()))
	local viewPos = self:convertToNodeSpace(worldPos)
	return viewPos.y
end

-- 更新项目内容数据
function UIItemReusedListView:updateItem(index, itemData)
    -- 修改数据
	Macro.assertFalse(index <= #self._itemDatas, "index out of bounds")
    self._itemDatas[index] = itemData
	
	for _, itemNode in ipairs(self._spawnItems) do
		if itemNode._itemId == index then
			itemNode:setData(itemData)
		end
	end
end

return UIItemReusedListView