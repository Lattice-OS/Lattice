local driver = {}

function driver:new(side)
    local c = peripheral.wrap(side)
    if not c then error("no computer interface on " .. side) end
    return {
        side     = side,
        getID    = function() return c.getID() end,
        getLabel = function() return c.getLabel() end,
        uptime   = function() return c.uptime() end,
        day      = function() return c.getDay() end,
        time     = function() return c.getTime() end,
        redstone = {
            getInput   = function(_, ch) return c.getAnalogInput(ch) end,
            getOutput  = function(_, ch) return c.getAnalogOutput(ch) end,
            setOutput  = function(_, ch, val) c.setAnalogOutput(ch, val) end,
            getBundled = function(_, ch) return c.getBundledOutput(ch) end,
            setBundled = function(_, ch, val) c.setBundledOutput(ch, val) end,
        }
    }
end

return driver
