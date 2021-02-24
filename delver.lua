#!/bin/env lua
--[[ delverexport
This script allows to export delver lens database content to plain files.
It makes use of the builtin card database of the app in order to export a
personal backup file into image files. It uses the magicthegathering.io API
to retreive card information and to download stock images of the cards.

Dependencies:

  - luarocks install luasec
  - luarocks install lsqlite3
  - luarocks install dkjson
]]--

-- configuration
local preferscan = true -- prefer scans over gatherer images
local fetchimage = nil -- set true to download gatherer images

-- load modules
local json = require ("dkjson")
local https = require("ssl.https")
local sqlite3 = require('lsqlite3')

-- check if delver lens files exist
if not io.open("./cache/cards.sqlite") or not io.open("./cache/delver.sqlite") then
 return
end

-- create output directories
os.execute("mkdir -p collection/")
os.execute("mkdir -p cache/images/")
os.execute("mkdir -p cache/scans/")
os.execute("mkdir -p cache/data/")

-- load sqlite databases
local sqldelver = sqlite3.open("./cache/delver.sqlite")
local sqlcards = sqlite3.open("./cache/cards.sqlite")
local sqlmtgjson = sqlite3.open("./cache/mtgjson.sqlite")

-- initialize vars
local colormap = { R = "Red", U = "Blue", B = "Black", G = "Green", W = "White" }
local collection = {}
local files = {}
local count = 0

-- read all delverlens backup cards
local id = 0
for card in sqlcards:nrows("SELECT * FROM cards;") do
  id = id + 1
  io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
  io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
  io.write(" - Loading Collection (" .. id .. ")")

  local scryfall
  for delver in sqldelver:nrows("SELECT * FROM cards WHERE _id = " .. card.card .. ";") do
    scryfall = delver.scryfall_id
  end

  table.insert(collection, { scan = card.image, count = card.quantity, scryfall = scryfall, lang = card.language })
end
print("")

-- improve card info with mtgjson data
local id = 0
for i, card in pairs(collection) do
  id = id + 1
  io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
  io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
  io.write(" - Loading MTGJSON Card Details ("..id.."/"..#collection..")")
  io.flush()

  -- read caches where possible
  local cache = io.open(string.format("cache/data/%s.json", card.scryfall), "rb")
  if cache then
    collection[i].meta = json.decode(cache:read("*all"))
    cache:close()
  else
    -- add mtgjson data to card
    for mtgjson in sqlmtgjson:nrows("SELECT * FROM cards WHERE scryfallId = '" .. card.scryfall .. "'") do
      -- attach card metadata
      card.meta = card.meta or {}
      card.meta.multiverse = mtgjson.multiverseId
      card.meta.rarity = mtgjson.rarity
      card.meta.types = mtgjson.types
      card.meta.subtypes = mtgjson.subtypes
      card.meta.set = mtgjson.setCode
      card.meta.cmc = mtgjson.convertedManaCost
      card.meta.name = mtgjson.name
      card.meta.color = mtgjson.colorIdentity

      -- try to get best multiverse
      if not card.meta.multiverse then
        for alternate in sqlmtgjson:nrows("SELECT multiverseid FROM cards WHERE scryfallOracleId = '" .. mtgjson.scryfallOracleId .. "'") do
          card.meta.multiverse = card.meta.multiverse or alternate.multiverseId
        end
      end

      card.meta.imgurl = card.meta.multiverse and "https://gatherer.wizards.com/Handlers/Image.ashx?type=card&multiverseid=" .. card.meta.multiverse

      -- read locale data
      for locale in sqlmtgjson:nrows("SELECT name, multiverseid FROM foreign_data WHERE uuid = '" .. mtgjson.uuid .. "' AND language = '" .. card.lang .. "'") do
        card.meta.name_lang = locale.name
        card.meta.imgurl_lang = locale.multiverseid and "https://gatherer.wizards.com/Handlers/Image.ashx?type=card&multiverseid=" .. locale.multiverseid
      end

      -- read set data
      for set in sqlmtgjson:nrows("SELECT name, releaseDate FROM sets WHERE code = '" .. card.meta.set .. "'") do
        card.meta.date = set.releaseDate
        card.meta.setname = set.name
      end
    end

    -- write data cache
    local file = io.open(string.format("cache/data/%s.json", card.scryfall), "w")
    file:write(json.encode(card.meta))
    file:close()
  end
end
print("")

-- download gatherer images
local id = 0
for i, card in pairs(collection) do
  id = id + 1
  io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
  io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
  io.write(" - Downloading Gatherer Artwork ("..id.."/"..#collection..")")
  io.flush()

  if fetchimage and card.meta.multiverse and card.meta.imgurl and not io.open("cache/images/" .. card.scryfall .. ".jpg") then
    local image = nil -- https.request(card.meta.imgurl_lang)
    image = image or https.request(card.meta.imgurl)

    if image then
      card.image = image
      local file = io.open("cache/images/" .. card.scryfall .. ".jpg", "w")
      file:write(image)
      file:close()
    else
      print(string.format(" WARNING: No Image for '%s' (%s)", card.meta.name, card.meta.multiverse))
    end
  elseif not card.meta.multiverse then
    print(string.format(" WARNING: No Multiverse Entry for '%s'", card.meta.name))
  end
end
print("")

-- prepare collection
local id = 0
for i, card in pairs(collection) do
  id = id + 1
  io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
  io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
  io.write(" - Prepare Collection ("..id.."/"..#collection..")")
  io.flush()

  local content = (preferscan and card.scan or card.image or card.scan)

  local color = card.meta.color
  if not color then
    color = "Artifact" -- artifacts
  elseif string.find(color, "%,") then
    color = "Multicolor" -- multicolor
  elseif colormap[color]then
    color = colormap[color]
  end

  -- prepare collection filenames
  local filename = string.format("%s, %s", color, card.meta.name)
  if card.meta.name_lang then
    filename = string.format("%s, %s (%s)", color, card.meta.name, card.meta.name_lang)
  end

  -- remove slashes in filename
  filename = string.gsub(filename, "/", "|")

  -- create files
  while card.count > 0 do
    -- find next possible count
    local count = 1
    while files[string.format("%s (%s).%s", filename, count, "jpg")] do
      count = count + 1
    end

    -- write to disk
    files[string.format("%s (%s).%s", filename, count, "jpg")] = content
    card.count = card.count - 1
  end
end
print("")

-- write collection
local id = 0
for filename, content in pairs(files) do
  id = id + 1
  io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
  io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
  io.write(" - Write Collection ("..id..")")
  io.flush()

  -- write to disk
  local file = io.open("collection/" .. filename, "w")
  file:write(content)
  file:close()
end
print("")
