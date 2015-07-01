local key = "0v7iqtny"
local mode = "training"

local function pre_loop()
    
end

local function loop()
    --[[
    os.execute("clear")
    for y = 1, map.size do
        val = ""
        for x = 1, map.size do
            if map[y][x] == 11 then
                val = val .. "# "
            elseif map[y][x] == 10 then
                val = val .. "T "
            elseif map[y][x] == 0 then
                val = val .. "  "
            else val = val .. map[y][x] .. " "
            end
        end
        print(val)
    end
    --]]

    return game.random_move()
end

-- local set_value =

-- local values =

return {
    key = key,
    mode = mode,
    -- map = "m1",
    -- turns = 50,
    --pre_loop = pre_loop,
    loop = loop
}
