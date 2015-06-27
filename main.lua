local http = require "socket.http"
local json = require "lib/dkjson"
-- Temp bot loading. Will need to clean this up.
local nbot = require "bots/notyetawizard"

local game = {}
map = {taverns = {}, mines = {}, heros = {}, hero = {}}

-----

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
        response = request({key = game.key, dir = move})
        parse_response(response)
    else
        love.event.quit()
    end
end

function love.draw()

end

-----

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

local function remove_heros()

end

local function update_map(board, tile)

end

function parse_first_response(response)
    -- Parse response json
    local parsed = json.decode(response)
    game.id = parsed.game.id
    game.turn = parsed.game.turn
    game.maxTurns = parsed.game.maxTurns
    game.finished = parsed.game.finished
    game.token = parsed.game.token
    game.viewUrl = parsed.game.viewUrl
    game.playUrl = parsed.game.playUrl

    map.size = parsed.game.board.size
    map.hero = parsed.hero

    local board = parsed.game.board.tiles
    update_map(board, valid_tiles.ground)
    update_map(board, valid_tiles.wall)
    update_map(board, valid_tiles.hero)
    update_map(board, valid_tiles.mine)
    update_map(board, valid_tiles.tavern)

end

function parse_response(response)
    -- Parse response json
    local parsed = json.decode(response)
    game.turn = parsed.game.turn
    game.finished = parsed.game.finished

    map.hero = parsed.hero
    map.mines = {}

    local board = parsed.game.board.tiles

    -- set heroes back to ground on the map

    update_map(board, valid_tiles.hero)
    update_map(board, valid_tiles.mine)
end

function random_move()
    return valid_moves[math.random(1,5)]
end
