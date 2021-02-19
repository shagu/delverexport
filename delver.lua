#!/bin/env lua
--[[ delverexport
This script allows to export delver lens database content to plain files.
It makes use of the builtin card database of the app in order to export a
personal backup file into image files. It uses the magicthegathering.io API
to retreive card information and to download stock images of the cards.
There will be 4 folders created:

  - images/
      The stock images of your cards
  - scans/
      The scanned images of your cards
  - json/
      The API data retrieved from magicthegathering.io
  - collection/
      The actual collection of your cards, named according to your settings.

Dependencies:

  - luarocks install luasec
  - luarocks install dkjson
  - luarocks install lsqlite3

]]--

-- configuration
local preferscan = nil -- prefer scans in collection?

-- load modules
local sqlite3 = require('lsqlite3')
local https = require("ssl.https")
local json = require ("dkjson")

-- check if delver lens files exist
if not io.open("./mycards.sqlite") or not io.open("./delver.sqlite") then
 return
end

-- create output directories
os.execute("mkdir -p collection/")
os.execute("mkdir -p images/")
os.execute("mkdir -p scans/")
os.execute("mkdir -p json/cards")
os.execute("mkdir -p json/sets")

-- load sqlite databases
local delver = sqlite3.open("./delver.sqlite")
local mycard = sqlite3.open("./mycards.sqlite")

-- detect overall number of cards
local count, current = 0, 1
for mcards in mycard:nrows("SELECT COUNT(*) AS count from cards;") do
  count = mcards.count
end

-- main loop
for mcards in mycard:nrows("SELECT * FROM cards;") do
  -- show progress
  io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
  io.write(math.floor(current / count * 1000 + .5)/10 .. "% [" .. current .. "/" .. count .. "]")
  io.flush()
  current = current + 1

  local basename, name, image, cmc, color

  -- read delver backup values
  local quantity = mcards.quantity
  local language = mcards.language
  local scan = mcards.image

  -- detect multiverse id
  local multiverse
  for dcards in delver:nrows("SELECT * FROM cards WHERE _id = " .. mcards.card .. ";") do
    multiverse = dcards.multiverseid

    for dnames in delver:nrows("SELECT * FROM names WHERE _id = " .. dcards.name .. ";") do
      name = dnames.name
    end
  end

  -- multi-sided
  local _, _, a, b = string.find(name, "(.+)//(.+)")
  if a and b then -- scan for double-cards
    -- obtain data from online resource or caches
    local data = nil
    local cache = io.open(string.format("json/cards/0-%s+%s.json", a, b), "rb")
    if cache then
      data = cache:read("*all")
      cache:close()
    else
      data = https.request("https://api.magicthegathering.io/v1/cards/?name=" .. a)
    end

    -- write cache to speed up next run
    if not cache then
      local file = io.open(string.format("json/cards/0-%s+%s.json", a, b), "w")
      file:write(data)
      file:close()
    end

    -- transform data to lua table
    local gatherer = json.decode(data)
    for card, data in pairs(gatherer.cards) do
      if data.names then
        for k, name in pairs(data.names) do
          if string.find(name,b) or string.find(b,name) and data.multiverseid then
            multiverse = data.multiverseid
            print("Assuming '" .. multiverse .. "' for '" .. name .. "'.")
            break
          end
        end
      end
    end
  elseif multiverse < 1 then -- scan by name for unknown cards
    -- obtain data from online resource or caches
    local data = nil
    local cache = io.open(string.format("json/cards/0-%s.json", name), "rb")
    if cache then
      data = cache:read("*all")
      cache:close()
    else
      data = https.request("https://api.magicthegathering.io/v1/cards/?name=" .. string.gsub(name, "%s+", "%%20"))
    end

    -- write cache to speed up next run
    if not cache then
      local file = io.open(string.format("json/cards/0-%s.json", name), "w")
      file:write(data)
      file:close()
    end

    local gatherer = json.decode(data)

    for card, data in pairs(gatherer.cards) do
      if ( data.name == name or multiverseid < 1 ) and data.multiverseid then
        multiverse = data.multiverseid
        print("Assuming '" .. multiverse .. "'  for '" .. name .. "'." ..  mcards.card)
      end
    end
  end

  -- obtain data from online resource or caches
  local data = nil
  local cache = io.open("json/cards/" .. multiverse .. ".json", "rb")
  if cache then
    data = cache:read("*all")
    cache:close()
  else
    data = https.request("https://api.magicthegathering.io/v1/cards/" .. multiverse)
  end

  -- write cache to speed up next run
  if not cache then
    local file = io.open(string.format("json/cards/%s.json", multiverse), "w")
    file:write(data)
    file:close()
  end

  -- transform data to lua table
  local gatherer = json.decode(data)

  -- load data from json
  local name = gatherer.card.name
  local locname = gatherer.card.name
  local image = gatherer.card.imageUrl
  local cmc = gatherer.card.cmc
  local color = gatherer.card.color
  local set = gatherer.card.set

  -- read proper content for localized cards
  local realmultiverse = multiverse
  if gatherer.card.foreignNames then
    for loc, data in pairs(gatherer.card.foreignNames) do
      if data.language == language then
        locname = data.name or name
        image = data.imageUrl or image
      end
    end
  end

  -- get set information from online resource or caches
  local setdata = nil
  local cache = io.open("json/sets/"..set..".json", "rb")
  if cache then
    setdata = cache:read("*all")
    cache:close()
  else
    setdata = https.request("https://api.magicthegathering.io/v1/sets/"..set)
  end

  -- write cache to speed up next run
  if not cache then
    local file = io.open(string.format("json/sets/%s.json", set), "w")
    file:write(setdata)
    file:close()
  end

  local date = "0000-00-00"
  if setdata then
    local gathererset = json.decode(setdata)
    date = gathererset.set.releaseDate or date
  end

  -- write scanned images
  local file = io.open("scans/" .. multiverse .. ".jpg", "w")
  file:write(scan)
  file:close()

  -- download stock images
  if not io.open("images/" .. multiverse .. ".jpg") then
    local download = https.request(image)

    if download then
      local file = io.open("images/" .. multiverse .. ".jpg", "w")
      file:write(download)
      file:close()
    else
      print("WARNING: No Image found for: " .. multiverse)
    end
  end

  -- select the prefered image to write
  local cardimage = scan
  if not preferscan then
    local file = io.open("images/" .. multiverse .. ".jpg")
    if file then
      cardimage = file:read("*all")
      file:close()
    end
  end

  -- build collection
  local filename = string.format("/%s - %s (%s).jpg", date, multiverse, quantity)

  -- if io.open("collection" .. filename) then
  --   print("ERROR: " .. filename .. " already exists.")
  -- end

  local file = io.open("collection" .. filename, "w")
  file:write(cardimage)
  file:close()
end
