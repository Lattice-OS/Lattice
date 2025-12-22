local driver = {}

function driver:new(side)
    local p = peripheral.wrap(side)
    if not p then error("no printer on " .. side) end
    return {
        side     = side,
        pageFeed = function() p.endPage() end,
        write    = function(_, txt) p.write(txt) end,
        setTitle = function(_, ttl) p.setPageTitle(ttl) end,
        getTitle = function() return p.getPageTitle() end,
        getInk   = function() return p.getInkLevel() end,
        getPaper = function() return p.getPaperLevel() end,
    }
end

return driver
