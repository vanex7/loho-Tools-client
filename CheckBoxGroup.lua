--[[	CheckBoxGroup：用来控制多个CheckBox的工具类

	features：
		1、每个CheckBox都能做到按下时滑动取消的功能
		2、Group中只存在一个选中的情况
		3、new时，默认选中的为table中的第一个，可以通过setSelectedIndex来改变选中项(也会触发回调)

	todo：
		1、保证Group size 为 1 的情况的适用性， 推荐重载方法
		2、关于size的操作
		... 
	
	examples：
		1:
			local group = CheckBoxGroup.new({self._cbx1, self._cbx2}, function(group, index, token)
				print(group[index]:getName()) -- equals self._cbx1:getName()
				print(token) -- equals first
			end, "first")
			group:dispose()
		2:
			local fn = function(group, index , token)
				print(group[index]:getName())
				print("token = " .. token)
			end
			local group1 = CheckBoxGroup.new({self._cbx1, self._cbx2}, fn, "group1")
			local group2 = CheckBoxGroup.new({self._cbx3, self._cbx4}, fn, "group2")
			group1:dispose()
			group2:dispose()
			-- 这两个group使用了同一个监听函数，可以通过token来区别他们

		其他方法：
			group:setSelectedIndex(index)
			group:getSelectedIndex() -- return selected item index
	
	CHANGEDLOG:
		2017-11-20 避免在初始化控件的时候调用了回调，删除了new时去触发回调的逻辑
]]
local CheckBoxGroup = class("CheckBoxGroup")
function CheckBoxGroup:ctor(group, callback, token)
    self._token = token
    self._callback = callback
    self._group = group
    self._currentSelectedIndex = 1

    for i, v in ipairs(group) do
        self:_registerTouchEvent(v, i)
    end
end

function CheckBoxGroup:setSelectedIndex(index)
    Macro.assertTrue(index < 0 or index > #self._group, "index out of bounds")
    self:_innercallback(self._group[index], index, self._token)
end

function CheckBoxGroup:getSelectedIndex()
    Macro.assertTrue(self._currentSelectedIndex < 0 or self._currentSelectedIndex > #self._group)
    return self._currentSelectedIndex
end

function CheckBoxGroup:dispose()
    self._token = nil
    self._callback = nil
    self._group = nil
end

function CheckBoxGroup:_changeCheckBoxSelectedStatus(index)
    for i, v in ipairs(self._group) do
        v:setSelected(i == index)
    end
end

function CheckBoxGroup:_innercallback(selectedCheckBox, index, token)
    self:_changeCheckBoxSelectedStatus(index)
    self._currentSelectedIndex = index
    self._callback(self._group, index, self._token)
end


function CheckBoxGroup:_registerTouchEvent(cbox, index)
    local isSelected = false
    cbox:addTouchEventListener(function(sender, eventType)
        if eventType == ccui.TouchEventType.began then
            isSelected = cbox:isSelected()
        elseif eventType == ccui.TouchEventType.moved then
        elseif eventType == ccui.TouchEventType.ended then
            self:_innercallback(cbox, index)
        elseif eventType == ccui.TouchEventType.canceled then
            cbox:setSelected(isSelected)
        end
    end)
end

function CheckBoxGroup:forEach(func)
    for idx, cbox in ipairs(self._group) do
        func(idx, cbox)
    end
end

function CheckBoxGroup:setVisible(value)
    self:forEach(function(idx, cbox)
        cbox:setVisible(value)
    end)
end

function CheckBoxGroup:setEnable(value)
    self:forEach(function(idx, cbox)
        cbox:setEnabled(value)
    end)
end

function CheckBoxGroup:getChild(index)
    return self._group[index]
end

return CheckBoxGroup