local driver = {}

function driver:new(side)
    local d = peripheral.wrap(side)
    if not d then error("no disk drive on " .. side) end
    return {
        side      = side,
        hasData   = function() return d.hasData() end,
        getMount  = function() return d.getMountPath() end,
        getLabel  = function() return d.getLabel() end,
        setLabel  = function(_, lbl) d.setLabel(lbl) end,
        hasAudio  = function() return d.hasAudio() end,
        playAudio = function() d.playAudio() end,
        eject     = function() d.ejectDisk() end,
    }
end

return driver
