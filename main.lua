local http = require "socket.http"
local json = require "lib/dkjson"
-- Temp bot loading. Will need to clean this up.
local nbot = require "bots/notyetawizard"

-- Initiate some global variables that bots will
-- need access to.
game = {}
map = {taverns = {}, mines = {}, heros = true, hero = true}

-- Set up for validity checks
local valid_modes = {
    arena = "http://vindinium.org/api/arena",
    training = "http://vindinium.org/api/training"
}

local valid_moves = {"Stay", "North", "South", "East", "West"}

local valid_tiles = {
    ground = {s = "  ", v = 0},
    hero = {s = "@(%d)", v = 0},
    mine = {s = "$([%d%-])", v = 5},
    tavern = {s = "%[%]", v = 10},
    wall = {s = "##", v = 11}
}

-- Make the the body for a POST HTTP request
-- @param body_pairs:   a table of key-value pairs
-- @return:             a string
local function mk_request_body(body_pairs)
    local buffer = {}
    for k, v in pairs(body_pairs) do
        table.insert(buffer, k .. "=" .. v)
    end
    return table.concat(buffer, "&")
end

-- Send a POST HTTP request, update game with respose values
-- @param game:         a game object including a url or mode
-- @param body_pairs:   a table of key-value pairs
-- @return:             the response as a json string
local function request(body_pairs)
    local response_body = {}
    local request_body = mk_request_body(body_pairs)

    --Send the request
    local _, code, headers = http.request{
        url = game.playUrl or valid_modes[game.mode],
        method = "POST",
        sink = ltn12.sink.table(response_body),
        source = ltn12.source.string(request_body),
        headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded",
            ["Content-Length"] = string.len(request_body)
        }
    }

    -- Validate response
    assert(type(response_body) == 'table', 'Invalid response from server')
    local response = table.concat(response_body)
    assert(code == 200, "Request failed: " .. code .. " - ".. response)

    return response
end

-- Vindinium uses a 0 base and X as the vertical direction,
-- while lua uses 1 as a base and X is traditionally horizontal.
-- This corrects that.
local function correct_pos(pos)
    pos.x, pos.y = pos.y + 1, pos.x + 1
end

-- Turn the position of a tile in the string
-- into x and y values
local function correct_xy(a,b)
    x = (a - 1) / 2 % map.size + 1
    y = ((b / 2) - x) / map.size + 1
    return x, y
end

-- Replace the heroes last positions with ground on the map.
local function remove_heroes()
    for i = 1, 4 do
        map[map.heroes[i].pos.y][map.heroes[i].pos.x] = 0
    end
end

local function update_map(board, tile, store)
    local i = 1
    while true do
        local a, b, c = string.find(board, tile.s, i)
        if a then
            i = b + 1
        else break
        end

        local x, y = correct_xy(a, b)
        if not map[y] then map[y] = {} end

        if c then
            if c == "-" then c = 0
            else c = tonumber(c)
            end
            map[y][x] = tile.v + c
        else
            map[y][x] = tile.v
        end

        if store then
            table.insert(store, {
                pos = {x = x, y = y},
                id = c
            })
        end
    end
end

-- Map parsers
local function parse_first_response(response)
    local parsed = json.decode(response)
    game.finished = parsed.game.finished
    game.id = parsed.game.id
    game.turn = parsed.game.turn
    game.maxTurns = parsed.game.maxTurns
    game.token = parsed.token
    game.viewUrl = parsed.viewUrl
    game.playUrl = parsed.playUrl

    map.size = parsed.game.board.size
    map.heroes = parsed.game.heroes
    correct_pos(map.heroes[1].pos)
    correct_pos(map.heroes[2].pos)
    correct_pos(map.heroes[3].pos)
    correct_pos(map.heroes[4].pos)
    map.hero = parsed.hero
    correct_pos(map.hero.pos)

    local board = parsed.game.board.tiles
    update_map(board, valid_tiles.ground)
    update_map(board, valid_tiles.wall)
    update_map(board, valid_tiles.hero)
    update_map(board, valid_tiles.mine, map.mines)
    update_map(board, valid_tiles.tavern, map.taverns)
end

local function parse_response(response)
    local parsed = json.decode(response)
    game.finished = parsed.game.finished
    game.turn = parsed.game.turn

    remove_heroes()
    map.heroes = parsed.game.heroes
    correct_pos(map.heroes[1].pos)
    correct_pos(map.heroes[2].pos)
    correct_pos(map.heroes[3].pos)
    correct_pos(map.heroes[4].pos)
    map.hero = parsed.hero
    correct_pos(map.hero.pos)
    map.mines = {}

    local board = parsed.game.board.tiles

    update_map(board, valid_tiles.hero)
    update_map(board, valid_tiles.mine, map.mines)
end

-- Function that returns a random valid move.
-- Good for testing and example bots.
function game.random_move()
    return valid_moves[math.random(1,5)]
end

--
-- Set filtering to nearest neighbor, for sprite art
love.graphics.setDefaultFilter("nearest", "nearest")

-- Load all needed images
local gfx = {
    tile_size = 24,
    tile_offset = 8,
    [0] = love.graphics.newImage("gfx/0_ground.png"),
    [1] = {
        north = love.graphics.newImage("gfx/1_heroN.png"),
        east = love.graphics.newImage("gfx/1_heroE.png"),
        south = love.graphics.newImage("gfx/1_heroS.png"),
        west = love.graphics.newImage("gfx/1_heroW.png")
    },
    [2] = {
        north = love.graphics.newImage("gfx/2_heroN.png"),
        east = love.graphics.newImage("gfx/2_heroE.png"),
        south = love.graphics.newImage("gfx/2_heroS.png"),
        west = love.graphics.newImage("gfx/2_heroW.png")
    },
    [3] = {
        north = love.graphics.newImage("gfx/3_heroN.png"),
        east = love.graphics.newImage("gfx/3_heroE.png"),
        south = love.graphics.newImage("gfx/3_heroS.png"),
        west = love.graphics.newImage("gfx/3_heroW.png")
    },
    [4] = {
        north = love.graphics.newImage("gfx/4_heroN.png"),
        east = love.graphics.newImage("gfx/4_heroE.png"),
        south = love.graphics.newImage("gfx/4_heroS.png"),
        west = love.graphics.newImage("gfx/4_heroW.png")
    },
    [5] = love.graphics.newImage("gfx/5_mine.png"),
    [6] = love.graphics.newImage("gfx/6_mine.png"),
    [7] = love.graphics.newImage("gfx/7_mine.png"),
    [8] = love.graphics.newImage("gfx/8_mine.png"),
    [9] = love.graphics.newImage("gfx/9_mine.png"),
    [10] = love.graphics.newImage("gfx/10_tavern.png")
}

-- Draw the map to a canvas, as it never changes.
local function draw_map()
    local map_canvas = love.graphics.newCanvas(map.size*gfx.tile_size,
        map.size*gfx.tile_size),
    love.graphics.setCanvas(map_canvas)
    for y = 1, map.size do
        if map[y] then
            for x = 1, map.size do
                if map[y][x] ~= 11 then
                    love.graphics.draw(gfx[0], x*gfx.tile_size,
                        y*(gfx.tile_size-gfx.tile_offset))
                end
            end
        end
    end
    love.graphics.setCanvas()
    gfx.map = love.graphics.newImage(map_canvas:getImageData())
end

---

function love.load()
    assert(type(nbot) == "table", "Settings table is invalid.")
    game.key   = assert(nbot.key, "A key must be provided")
    game.mode  = nbot.mode or "training"
    game.loop  = nbot.loop or random_move
    game.pre_loop = nbot.pre_loop

    assert(valid_modes[game.mode], "Invalid game mode: " .. game.mode)

    -- Initial connection request
    local response = request{key = game.key}
    parse_first_response(response)

    -- Run pre_loop function if availiable
    if game.pre_loop then game.pre_loop() end
end

function love.update()
    if not game.finished then
        local move = game.loop()
        response = request{key = game.key, dir = move}
        parse_response(response)
    else
        love.event.quit()
    end
end

function love.draw()
    -- init the map if it doesn't exist
    if not gfx.map then
        draw_map()
    end
    -- draw the map
    love.graphics.draw(gfx.map, 1, 1)

    -- draw a test sprite every other turn, because I
    -- can't figure out why the map disappears and this doesn't.
    if game.turn % 8 == 0 then
        love.graphics.draw(gfx[10], 24, 25)
    end
end
