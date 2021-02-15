#!/bin/env lua
local sqlite3 = require('lsqlite3')
local exportimg = nil

-- load both databases
local delver = sqlite3.open("./delver.sqlite")
local mycard = sqlite3.open("./mycards.sqlite")

-- create output directories
os.execute("mkdir -p output/")
os.execute("mkdir -p output/img")

-- write html
local file = io.open("output/mycards.html", "w+")

local function spairs(t, index, reverse)
  -- collect the keys
  local keys = {}
  for k in pairs(t) do keys[#keys+1] = k end

  local order
  if reverse then
    order = function(t,a,b) return t[b][index] < t[a][index] end
  else
    order = function(t,a,b) return t[b][index] > t[a][index] end
  end
  table.sort(keys, function(a,b) return order(t, a, b) end)

  -- return the iterator function
  local i = 0
  return function()
    i = i + 1
    if keys[i] then
      return keys[i], t[keys[i]]
    end
  end
end

local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

-- encoding
local foo = function(x)
  local r,b='',x:byte()
  for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
  return r;
end

local bar = function(x)
  if (#x < 6) then return '' end
  local c=0
  for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
  return b:sub(c+1,c+1)
end

local function enc(data)
  return ((data:gsub('.', foo)..'0000'):gsub('%d%d%d?%d?%d?%d?', bar)..({ '', '==', '=' })[#data%3+1])
end

-- detect overall number of cards
local count, current = 0, 1
for mcards in mycard:nrows("SELECT COUNT(*) AS count from cards;") do
  count = mcards.count
end

-- initialize content
css, content = "", '<h1>Magic Card Collection</h1>'
cards = {}

-- main loop
for mcards in mycard:nrows("SELECT * FROM cards;") do
  io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
  io.write(math.floor(current / count * 1000 + .5)/10 .. "% [" .. current .. "/" .. count .. "]")
  io.flush()
  current = current + 1

  local quantity = mcards.quantity
  local image = mcards.image

  -- initialize variables
  local multiverse, artist     -- delver: cards
  local name, mana, typ, cost  -- delver: names
  local edition, editionabb    -- delver: editions

  for dcards in delver:nrows("SELECT * FROM cards WHERE _id = " .. mcards.card .. ";") do
    artist = dcards.artist
    multiverse = dcards.multiverseid

    -- look for cards texts
    for dnames in delver:nrows("SELECT * FROM names WHERE _id = " .. dcards.name .. ";") do
      name = dnames.name
      typ  = dnames.type
      cost = dnames.cmana
      color = dnames.color
      mana = dnames.mana
    end

    -- look for edition
    for deditions in delver:nrows("SELECT * FROM editions WHERE _id = " .. dcards.edition .. ";") do
      edition = deditions.name
      editabb = deditions.tl_abb
    end
  end

  if multiverse then
    cards[color] = cards[color] or {}
    cards[color][multiverse] = {
      name = name,
      type = typ,
      color = color,
      cost = cost,
      mana = mana,
      edition = edition,
      edition_short = editabb,
      multiverse = multiverse,
      quantity = quantity,
    }

    if exportimg then -- export scanned image
      local pic = io.open("output/img/" .. multiverse .. ".jpg", "w")
      pic:write(image)
      pic:close()
    else
      cards[color][multiverse].image = enc(image)
    end
  else
    print("WARNING: Card '" .. mcards.card .. "' was not found in delver lens database")
  end
end

print("")
print("Exporting to HTML")


local color = nil
local colormap = {
  [2] = "Blue",
  [4] = "Black",
  [8] = "Red",
  [16] = "Green",
}

for color, data in pairs(cards) do
  -- content = content .. "<h2>" .. (colormap[color] or color) .. "</h2>"
  for id, card in spairs(data, "cost") do
    if exportimg then
      css = css .. ':root { --card-'..card.multiverse..': url("img/'..card.multiverse..'.jpg"); }'
    else
      css = css .. ':root { --card-'..card.multiverse..': url("data:image/gif;base64,'..card.image..'"); }'
    end
    css = css .. '#card-'..card.multiverse..' { background-image:var(--card-'..card.multiverse..'); }'
    css = css .. '#card-'..card.multiverse..':hover ~ #preview img { content:var(--card-'..card.multiverse..'); }'
    content = content .. [[
      <span class="card" id="card-]]..card.multiverse..[["><img/>
        <span class="cardcount">]]..card.quantity..[[</span>
        <span class="details">
          <span class="name">]]..card.name..[[</span>
          <span class="type">]]..card.type..[[</span>
          <b>Count:</b> <span class="count">]]..card.quantity..[[</span>
          <b>Cost:</b> <span class="cost">]]..card.cost..[[</span>
          <b>Edition:</b> <span class="edition">]]..card.edition..[[<span class="editionabb">(]]..card.edition_short..[[)</span></span>
        </span>
      </span>
    ]]
  end
end

-- page style
css = css .. [[
  body {
    margin-left: 64px;
    margin-right: 64px;
    margin-bottom: 200px;
    background: #222222;
    color: #cccccc;
    font-family: "Roboto", "Droid Sans", "Ubuntu Sans", Sans;
  }

  h2 {
    border-bottom: 1px #555 solid;
  }

  span.card {
    display: inline-block;
    position: relative;
    width: 126px;
    height: 176px;
    background-size: cover;
    vertical-align: bottom;
    margin: 5px;
    box-shadow: inset 0 0 10px #000;
  }

  span.card:hover {
    box-shadow: 0px 0px 5px #3fc;
  }

  span.card span.cardcount {
    display: inline-block;
    font-weight: bold;
    text-align: center;
    padding: 5px;
    min-width: 15px;
    border-radius: 15px;
    background: rgba(0,0,0,0.75);
    color: #fff;
    position: absolute;
    bottom: 5px;
    left: 5px;
  }

  span.card span.details {
    visibility: hidden;
    text-align: right;
    display: inline-block;
    position: fixed;
    bottom: 10px;
    right: 280px;
    z-index: 999;
  }

  span.card span.details span.name {
    display: block;
    font-size: 24pt;
    font-weigth: bold;
  }

  span.card span.details span.count {
  }

  span.card span.details span.cost {
  }

  span.card span.details span.edition {
  }

  span.card span.details span.type {
    display: block;
    font-size: 16pt;
  }

  span.card:hover span.details {
    visibility: visible;
  }

  #preview {
    z-index: 0;
    position: fixed;
    bottom:0;
    left:0;
    width:100%;
    border-top: 1px #000 solid;
    background: linear-gradient(to bottom,  rgba(0,0,0,.5), black);
    height: 100px;
  }

  #preview img {
    max-width: 252px;
    max-height: 352px;
    box-shadow: 0px 0px 15px #000;
    border-radius: 15px;
    position: absolute;
    bottom: 10px;
    right: 10px;
  }
]]

local loader = [[
  <div class="loader" style="position: fixed; width: 100%; height: 100%; background: #fff; color: #000; z-index: 9999; font-weight: bold; font-size: 18pt;">Loading...</div>
]]

local loaderend = [[
  <style>
    div.loader {
      display: none;
    }
  </style>
]]

content = loader .. content
content = content .. '<span id="preview"><img/></span>'

-- create navigation
file:write(content.. "\n" .. "<style>" .. css .. "</style>" .. loaderend)
file:close()
