local log = {}

function log._inner(level, msg)
    local os_time = textutils.formatTime(os.time())
    local str = "[" .. os_time .. "] " .. "{" .. level .. "} " .. tostring(msg)
    print(str)
end

function log.info(msg)
    log._inner("INFO", msg)
end

function log.error(msg)
    log._inner("ERROR", msg)
end

function log.warn(msg)
    log._inner("WARN", msg)
end

function log.debug(msg)
    log._inner("INFO", msg)
end

function log.trace(msg)
    log._inner("TRACE", msg)
end

return log
