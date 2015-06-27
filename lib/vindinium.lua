local http = require "socket.http"
local json = require "lib/dkjson"

-- Set possible game modes and their server URLs
local game_modes = {
    arena = "http://vindinium.org/api/arena",
    training = "http://vindinium.org/api/training"
}

-- Set valid moves
local valid_moves = {"Stay", "North", "South", "East", "West"}

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
        url = game.playUrl or game_modes[game.mode],
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

local vindinium = {}

function vindinium.random_move()
    return valid_moves[math.random(1,5)]
end

function vindinium.parse_response(game, response)
    -- Parse response json
    local parsed = json.decode(response)

    -- Pass the values onto game and open up "games"
    for ak, av in pairs(parsed) do
        if ak == "game" then
            for bk, bv in pairs(av) do
                game[bk] = bv
            end
        else
            game[ak] = av
        end
    end

    -- Identify and store tiles
    game.map = {}
    game.taverns = {}
    game.mines = {}
    -- SIGHSIGHSIGHSIGH
    -- I just rewrote this all, but I guess I'll just do it again
    -- because I accidentally deleted it.
    for y = 1, game.board.size do
        local dy = (y - 1) * game.board.size
        game.map[y] = {}
        for x = 1, game.board.size do
            local dx = (x + dy) * 2
            local tile = string.sub(game.board.tiles,
                dx - 1, dx)
            if tile == "##" then
                game.map[y][x] = {
                    type = "wall",
                    walk = false
                }
            elseif tile == "[]" then
                game.map[y][x] = {
                    type = "tavern",
                    walk = false
                }
                table.insert(game.taverns, {
                    pos = {x = x, y = y}
                })
            elseif string.sub(tile, 1, 1) == "$" then
                local id = string.sub(tile, 2, 2)
                if id == "-" then id = 0
                else id = tonumber(id)
                end
                game.map[y][x] = {
                    type = "mine",
                    walk = false,
                    id = id
                }
                table.insert(game.mines, {
                    pos = {x = x, y = y},
                    id = id
                })
            elseif string.sub(tile, 1, 1) == "@" then
                local id = tonumber(string.sub(tile, 2, 2))
                game.map[y][x] = {
                    type = "hero",
                    walk = false,
                    id = id
                }
            else
                game.map[y][x] = {
                    type = "ground",
                    walk = true
                }
            end
            if game.set_value then
                game.map[y][x].value = game.set_value(game, x, y)
            end
        end
    end

    -- Correct XY positions
    for k, v in pairs(game.heroes) do
        correct_pos(v.pos)
        correct_pos(v.spawnPos)
        game.map[v.pos.y][v.pos.x].id = v.id
    end
    correct_pos(game.hero.pos)
    correct_pos(game.hero.spawnPos)

end

-- Connect to the game
-- @param settings: a table requiring a "key" entry, and
--                  accepting "mode", "loop", and "pre_loop"
function vindinium.start(settings)
    assert(type(settings) == "table", "Settings table is invalid.")
    local game = {
      key   = assert(settings.key, "A key must be provided"),
      mode  = settings.mode or "training",
      loop  = settings.loop or vindinium.random_move,
      pre_loop = settings.pre_loop,
      set_value = settings.set_value,
      values = settings.values
    }

    assert(game_modes[game.mode], "Invalid game mode: " .. game.mode)

    -- Initial connection request
    local response = request(game, {key = game.key})
    vindinium.parse_response(game, response)

    -- Run pre_loop function if availiable
    if game.pre_loop then game.pre_loop(game) end

    -- Run loop function until the game is finished
    while game.finished == false do
        local move = game.loop(game)
        response = request(game, {key = game.key, dir = move})
        vindinium.parse_response(game, response)
    end
end

return vindinium
