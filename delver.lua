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
local preferscan = true -- prefer scans, skips gatherer downloads

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
for card in sqlcards:nrows("SELECT * FROM cards;") do
  io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
  io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
  io.write(" - Loading Collection (" .. count .. ")")

  for delver in sqldelver:nrows("SELECT * FROM cards WHERE _id = " .. card.card .. ";") do

    -- export scan image
    if card.image then
      local file = io.open("cache/scans/" .. delver.scryfall_id .. ".jpg", "w")
      file:write(card.image)
      file:close()
    end

    -- write data table
    if collection[delver.scryfall_id] then
      collection[delver.scryfall_id].count = collection[delver.scryfall_id].count + card.quantity
    else
      collection[delver.scryfall_id] = { lang = card.language, count = card.quantity }
      count = count + 1
    end
  end
end
print("")

-- improve card info with mtgjson data
local id = 0
for scryfall, card in pairs(collection) do
  id = id + 1
  io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
  io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
  io.write(" - Loading MTGJSON Card Details ("..id.."/"..count..")")
  io.flush()

  -- read caches where possible
  local cache = io.open(string.format("cache/data/%s.json", scryfall), "rb")
  if cache then
    collection[scryfall] = json.decode(cache:read("*all"))
    cache:close()
  else
    -- add mtgjson data to card
    for mtgjson in sqlmtgjson:nrows("SELECT * FROM cards WHERE scryfallId = '" .. scryfall .. "'") do
      card.multiverse = mtgjson.multiverseId
      card.rarity = mtgjson.rarity
      card.types = mtgjson.types
      card.subtypes = mtgjson.subtypes

      card.set = mtgjson.setCode
      card.rarity = mtgjson.rarity

      card.cmc = mtgjson.convertedManaCost

      card.name = mtgjson.name
      card.name_alt = mtgjson.name

      card.color = mtgjson.colorIdentity

      -- try to get best multiverse
      if not card.multiverse then
        for alternate in sqlmtgjson:nrows("SELECT multiverseid FROM cards WHERE scryfallOracleId = '" .. mtgjson.scryfallOracleId .. "'") do
          card.multiverse = card.multiverse or alternate.multiverseId
        end
      end

      card.imgurl_alt = card.multiverse and "https://gatherer.wizards.com/Handlers/Image.ashx?type=card&multiverseid=" .. card.multiverse

      -- read locale data
      for locale in sqlmtgjson:nrows("SELECT name, multiverseid FROM foreign_data WHERE uuid = '" .. mtgjson.uuid .. "' AND language = '" .. card.lang .. "'") do
        card.name = locale.name
        card.imgurl = locale.multiverseid and "https://gatherer.wizards.com/Handlers/Image.ashx?type=card&multiverseid=" .. locale.multiverseid
      end

      -- read set data
      for set in sqlmtgjson:nrows("SELECT name, releaseDate FROM sets WHERE code = '" .. card.set .. "'") do
        card.date = set.releaseDate
        card.setname = set.name
      end

      -- set fallbacks
      card.name = card.name or card.name_alt
      card.imgurl = card.imgurl or card.imgurl_alt
    end

    -- write data cache
    local file = io.open(string.format("cache/data/%s.json", scryfall), "w")
    file:write(json.encode(card))
    file:close()
  end
end
print("")

-- download gatherer images
local id = 0
for scryfall, card in pairs(collection) do
  id = id + 1
  io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
  io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
  io.write(" - Downloading Gatherer Artwork ("..id.."/"..count..")")
  io.flush()

  if not preferscan  and card.multiverse and not io.open("cache/images/" .. scryfall .. ".jpg") then
    local image = https.request(card.imgurl)
    image = image or https.request(card.imgurl_alt)

    if image then
      local file = io.open("cache/images/" .. scryfall .. ".jpg", "w")
      file:write(image)
      file:close()
    else
      print(string.format(" WARNING: No Image for '%s' (%s)", card.name, card.multiverse))
    end
  elseif not card.multiverse then
    print(string.format(" WARNING: No Multiverse Entry for '%s'", card.name))
  elseif preferscan then
    io.write(" [Skipped]")
  end
end
print("")

-- prepare collection
local id = 0
for scryfall, card in pairs(collection) do
  id = id + 1
  io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
  io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
  io.write(" - Prepare Collection ("..id.."/"..count..")")
  io.flush()

  local scan -- read scan image
  local file = io.open("cache/scans/" .. scryfall .. ".jpg", "rb")
  if file then
    scan = file:read("*all")
    file:close()
  end

  local image -- read image image
  local file = io.open("cache/images/" .. scryfall .. ".jpg", "rb")
  if file then
    image = file:read("*all")
    file:close()
  end

  local content = (preferscan and scan or image)

  if content then
    local color = card.color
    if not color then
      color = "Artifact" -- artifacts
    elseif string.find(color, "%,") then
      color = "Multicolor" -- multicolor
    elseif colormap[color]then
      color = colormap[color]
    end

    -- prepare collection filenames
    local filename = string.format("%s, %s (%s)", color, card.name_alt, card.name)
    if card.name == card.name_alt then
      filename = string.format("%s, %s", color, card.name)
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
