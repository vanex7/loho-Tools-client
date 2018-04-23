local UIPopListItem = class("UIPopListItem", function() return ccui.Layout:create() end)
function UIPopListItem:ctor(parent, index)
    Macro.assertFalse(index)
    self._index = index
    parent:addChild(self)
    self:init()
    self:loadConfig(parent:getConfig())
end

function UIPopListItem:init()
    self._text = ccui.Text:create()
    self._bg = ccui.ImageView:create()
    self:addChild(self._bg)
    self:addChild(self._text)
end

function UIPopListItem:setText(text)
    self._text:setString(text)
end

function UIPopListItem:loadConfig(config)
    self._text:setString(config.texts[self._index])
    self._text:setFontSize(config.contentSize)
    self._text:setTextColor(config.contentColor)

    self._bg:loadTexture(config.backgroundRes)
    self._bg:setScale9Enabled(true)
    self._bg:ignoreContentAdaptWithSize(false)
    self._bg:setContentSize(config.backgroundSize)

    local size = config.backgroundSize
    local halfHeight = size.height * 0.5
    local halfWidth = size.width * 0.5
    self._bg:setAnchorPoint(cc.p(0.5, 0.5))
    self._bg:setPosition(cc.p(halfWidth, halfHeight))

    if config.contentAlign == 'center' then
        self._text:setAnchorPoint(cc.p(0.5, 0.5))
        self._text:setPosition(cc.p(halfWidth, halfHeight))
    elseif config.contentAlign == 'left' then
        self._text:setAnchorPoint(cc.p(0, 0.5))
        self._text:setPosition(cc.p(config.contentMargin, halfHeight))
    elseif config.contentAlign == 'right' then
        self._text:setAnchorPoint(cc.p(1, 0.5))
        self._text:setPosition(cc.p(halfWidth * 2 - config.contentMargin, halfHeight))
    end

    self:setAnchorPoint(cc.p(0.5, 0.5))
    self:setPosition(0, 0)
    self:setTouchEnabled(true)
    self:ignoreContentAdaptWithSize(false)
    self:setContentSize(config.backgroundSize)

    --test color
    -- self:setBackGroundColorType(1)
    -- self:setBackGroundColor({ r = 150, g = 200, b = 255 })
end

function UIPopListItem:setTextSize(size)
    self._config.contentSize = size
    self._text:setFontSize(size)
end

function UIPopListItem:setTextColor(_c4b)
    self._config.contentColor = _c4b
    self._text:setTextColor(_c4b)
end

function UIPopListItem:dispose()
    self:removeFromParent()
end



local UIPopList = class("UIPopList", function() return ccui.Widget:create() end)
function UIPopList:newConfig()
    local cfg = {
        texts = { 'defualt1', 'defualt2', 'defualt3' },
        contentSize = 20,
        contentColor = cc.c4b(255, 0, 0, 255),
        contentMargin = 0,
        contentAlign = 'center', -- or 'right' or 'left'
        backgroundRes = 'art/function/icon_risk0.png',
        backgroundSize = cc.size(120, 40),
        margin = 2,
        showType = 'top', -- or 'bottom'
    }
    return cfg
end

function UIPopList:ctor(config)
    self._isSeleting = false -- 是否正常选择中
    self._seletedItemIndex = 1
    self._config = config or self:newConfig()
    self._items = {}
    self:setConfig(config)
end

function UIPopList:setConfig(config)
    self:_removeAllItems()
    self._config = config
    self:init()
    self:_registerCallback()
end

function UIPopList:getConfig()
    return self._config
end

function UIPopList:setOnClickCallback(callback)
    self._callback = callback
end

function UIPopList:init()
    for idx, text in ipairs(self._config.texts) do
        table.insert(self._items, UIPopListItem.new(self, idx))
    end

    -- 隐藏除了第一个以外的选项
    self:hideWithoutFirst()
    -- 添加点击监听
    self:setShowType(self._config.showType)
end

-- function UIPopList:setEnable(value)
-- end
-- function UIPopList:setVisible(value)
--     self:setVisible(value or false)
-- end
function UIPopList:setShowType(type)
    self._type = type
    self:refreshPosition()
end

function UIPopList:refreshPosition()
    self._type = self._type or 'top'

    local k = 1
    if 'top' == self._type then
        k = 1
    elseif 'bottom' == self._type then
        k = -1
    end

    local height = self._config.backgroundSize.height
    local start = self._seletedItemIndex
    for i = start, start + #self._items - 1, 1 do
        local index = i
        if i > #self._items then
            index = i - #self._items
        end
        local item = self._items[index]
        local y = math.abs(i - start) * (height + self._config.margin) * k
        item:setPosition(0, y)
        -- Logger.debug(string.format("i = %s, index = %s, y = %s, start = %s", i, index, y, start))
    end
end

function UIPopList:hideWithoutFirst()
    for idx, item in ipairs(self._items) do
        local isVisible = idx == self._seletedItemIndex
        item:setVisible(isVisible)
    end
end

function UIPopList:_changeStatus(status)
    self:refreshPosition()
    if status then
        for idx, item in ipairs(self._items) do
            item:setVisible(true)
        end
    else
        self:hideWithoutFirst()
    end
end

function UIPopList:_registerCallback()
    for idx, item in ipairs(self._items) do
        -- print("addTouchEventListener")
        item:addTouchEventListener(function(sender, eventType)
            -- print('event coming')
            if eventType == ccui.TouchEventType.ended then
                self:_onClick(item, idx)
                -- print(item:getPosition())
            end
        end)
    end
end

function UIPopList:_onClick(item, index)
    -- print("onclick", index)
    self._isSeleting = not self._isSeleting
    if not self._isSeleting and self._callback then
        self._callback(self, item, index)
    end
    self._seletedItemIndex = index
    self:_changeStatus(self._isSeleting)
end

function UIPopList:pushItem()
    assert(false, 'unimplement')
end

function UIPopList:popItem()
    assert(false, 'unimplement')
end

function UIPopList:removeItemByIndex()
    assert(false, 'unimplement')
end

function UIPopList:getSeletedItemIndex()
    return self._seletedItemIndex
end

function UIPopList:_removeAllItems()
    for idx, item in ipairs(self._items) do
        item:dispose()
    end
    self._items = {}
end

function UIPopList:dispose()
    self:_removeAllItems()
end

return UIPopList