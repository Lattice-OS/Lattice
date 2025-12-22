local hardware = {
    by_type = {},
    by_name = {},
}


for _, name in ipairs(peripheral.getNames()) do
    local ptype = peripheral.getType(name)

    local wrapped = peripheral.wrap(name)

    hardware.by_name[name] = {
        type = ptype,
        object = wrapped,
    }

    hardware.by_type[ptype] = hardware.by_type[ptype] or {}
    table.insert(hardware.by_type[ptype], wrapped)
end