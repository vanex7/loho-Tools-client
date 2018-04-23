--[[
    ReusedListViewFactory 复用ListView的工厂类，提供构造能够重复利用的ListView（item重复利用）

    features:
        1、减少代码量，相同的数据已经在此过滤了
    todo:

    
    Example1:
        local factory = require("ReusedListViewFactory")
        self._reusedLst = factory.get(self._listView, handler(self, self._listItemInit) , handler(self, self._listItemSetData))
    
    Example2:
        local factory = require("ReusedListViewFactory")
        self._reusedLst = factory.get(self._listView,
            function(listItem)
                -- your code
            end,
            function (listItem, val)
                -- your code
            end)
    
    CHANGEDLOG:
        2017/11/22： 增加splitTable方法，方便pushBackItem的调用
]]

local UIItemReusedListView = require("app.game.util.UIItemReusedListView")
local ReusedListViewFactory = {}

function ReusedListViewFactory.get(widget, initCallback, setDataCallback, cname)
    ReusedListViewFactory.check(widget, initCallback, setDataCallback)

    local brige = class(cname or "brige")

    -- the function call by UIItemReusedListView
    -- the self is a list item copy
    brige.extend = function(self)
        local t = tolua.getpeer(self)
        if not t then
            t = {}
            tolua.setpeer(self, t)
        end
        setmetatable(t, brige)
        self:_initialize()
        return self
    end

    brige._initialize = function(self)
        initCallback(self)
    end

    brige.setData = function(self, val)
        if self._val == val then return end -- filter the same data
        self._val = val
        setDataCallback(self, val)
    end

    return UIItemReusedListView.extend(widget, brige)
end

function ReusedListViewFactory.check(widget, initCallback, setDataCallback)
    Macro.assetTrue(widget == nil or initCallback == nil or setDataCallback == nil)
    Macro.assetFalse(type(initCallback) == "function" and type(setDataCallback) == "function", "illegle argument")
end

--- @param longTable 长表
--- @param count 块大小
--- @param dValue 如果存在则填充块置count大小
--- @return masterTable 分割后的表，表内嵌套了n个count大小的表
function ReusedListViewFactory.splitTable(longTable, count, dValue)
    if type(longTable) ~= "table" then return {} end
    if #longTable <= count then return {longTable} end
    local masterTable = {}
    local t = nil
    for i,v in ipairs(longTable) do
        local bNew = i % count == 1
        if bNew then
            table.insert(masterTable, t)
            local tempT = {}
            t = tempT
        end
        t[#t + 1] = v
    end
    if dValue ~= nil and #t < count then 
        t = t or {}
        for i = #t + 1, count do t[i] = dValue end
    end
    table.insert(masterTable, t)
    return masterTable
end

return ReusedListViewFactory