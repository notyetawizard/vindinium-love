local http = require "socket.http"
local json = require "lib/dkjson"
-- Temp bot loading. Will need to clean this up.
local nbot = require "bots/notyetawizard"

-----

function love.load()
    assert(type(nbot) == "table", "Settings table is invalid.")
    local game = {
      key   = assert(settings.key, "A key must be provided"),
      mode  = settings.mode or "training",
      loop  = settings.loop or random_move,
      pre_loop = settings.pre_loop,
      set_value = settings.set_value,
      values = settings.values
    }

    assert(valid_modes[game.mode], "Invalid game mode: " .. game.mode)

    -- Initial connection request
    local response = request(game, {key = game.key})
    parse_first_response(game, response)

    -- Run pre_loop function if availiable
    if game.pre_loop then game.pre_loop(game) end
end

function love.update()
    if not game.finished then
        local move = game.loop(game)
        response = request(game, {key = game.key, dir = move})
        parse_response(game, response)
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
local function request(game, body_pairs)
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

function parse_first_response(game, response)
    -- Parse response json
    local parsed = json.decode(response)
end

function parse_response(game, response)
    -- Parse response json
    local parsed = json.decode(response)
end

function random_move()
    return valid_moves[math.random(1,5)]
end
