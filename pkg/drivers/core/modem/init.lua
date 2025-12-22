local driver = {}

function driver:new(side)
    local m = peripheral.wrap(side)
    if not m then error("no modem on " .. side) end
    return {
        side       = side,
        isWireless = m.isWireless(),
        open       = function(_, ch) m.open(ch) end,
        close      = function(_, ch) m.close(ch) end,
        closeAll   = function() m.closeAll() end,
        transmit   = function(_, ch, replyCh, msg)
            m.transmit(ch, replyCh or ch, msg)
        end,
        isOpen     = function(_, ch) return m.isOpen(ch) end,
    }
end

return driver
