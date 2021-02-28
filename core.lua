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
local fetchlang  = nil -- fetches language specific images where possible

-- load modules
local json = require ("dkjson")
local https = require("ssl.https")
local sqlite3 = require('lsqlite3')

-- create output directories
os.execute("mkdir -p collection/")
os.execute("mkdir -p cache/images/")
os.execute("mkdir -p cache/scans/")
os.execute("mkdir -p cache/data/")

-- load sqlite databases
local sqlmtgjson = sqlite3.open("./cache/mtgjson.sqlite")

-- initialize vars
local colormap = { R = "Red", U = "Blue", B = "Black", G = "Green", W = "White" }
local collection = {}
local metadata = {}
local images = {}
local files = {}

-- load delver lens backup file
local data = require("delver")
local metadata, images = data and data[1], data and data[2]

-- improve card info with mtgjson data
local id = 0
for i, card in pairs(metadata) do
  id = id + 1
  io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
  io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
  io.write(" - Loading MTGJSON Card Details ("..id..")")
  io.flush()

  -- read caches where possible
  local cache = io.open(string.format("cache/data/%s.json", card.scryfall), "rb")
  if cache then
    -- load mtgjson data from cache
    collection[i] = json.decode(cache:read("*all"))
    cache:close()
  else
    -- load mtgjson data from sqlite
    for mtgjson in sqlmtgjson:nrows("SELECT * FROM cards WHERE scryfallId = '" .. card.scryfall .. "'") do
      -- attach card metadata
      collection[i] = {}
      collection[i].multiverse = mtgjson.multiverseId
      collection[i].rarity = mtgjson.rarity
      collection[i].types = mtgjson.types
      collection[i].subtypes = mtgjson.subtypes
      collection[i].set = mtgjson.setCode
      collection[i].cmc = mtgjson.convertedManaCost
      collection[i].name = mtgjson.name
      collection[i].color = mtgjson.colorIdentity

      -- try to get best multiverse
      if not collection[i].multiverse then
        for alternate in sqlmtgjson:nrows("SELECT multiverseid FROM cards WHERE scryfallOracleId = '" .. mtgjson.scryfallOracleId .. "'") do
          collection[i].multiverse = collection[i].multiverse or alternate.multiverseId
        end
      end

      collection[i].imgurl = collection[i].multiverse and "https://gatherer.wizards.com/Handlers/Image.ashx?type=card&multiverseid=" .. collection[i].multiverse

      -- read locale data
      for locale in sqlmtgjson:nrows("SELECT name, multiverseid FROM foreign_data WHERE uuid = '" .. mtgjson.uuid .. "' AND language = '" .. card.lang .. "'") do
        collection[i].name_lang = locale.name
        collection[i].imgurl_lang = locale.multiverseid and "https://gatherer.wizards.com/Handlers/Image.ashx?type=card&multiverseid=" .. locale.multiverseid
      end

      -- read set data
      for set in sqlmtgjson:nrows("SELECT name, releaseDate FROM sets WHERE code = '" .. collection[i].set .. "'") do
        collection[i].date = set.releaseDate
        collection[i].setname = set.name
      end
    end

    -- write data cache
    local file = io.open(string.format("cache/data/%s.json", card.scryfall), "w")
    file:write(json.encode(collection[i]))
    file:close()
  end

  -- attach original metadata
  collection[i].scryfall = card.scryfall
  collection[i].lang = card.lang
end
print("")

-- download gatherer images
local id = 0
for i, card in pairs(collection) do
  id = id + 1
  io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
  io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
  io.write(" - Downloading Gatherer Artwork ("..id..")")
  io.flush()

  if fetchimage and card.multiverse and card.imgurl and not io.open("cache/images/" .. card.scryfall .. ".jpg") then
    local image = fetchlang and https.request(card.imgurl_lang)
    image = image or https.request(card.imgurl)

    if image then
      images[i]["stock"] = image
      local file = io.open("cache/images/" .. card.scryfall .. ".jpg", "w")
      file:write(image)
      file:close()
    else
      print(string.format(" WARNING: No Image for '%s' (%s)", card.name, card.multiverse))
    end
  elseif not card.multiverse then
    print(string.format(" WARNING: No Multiverse Entry for '%s'", card.name))
  end
end
print("")

-- prepare collection
local id = 0
for i, card in pairs(collection) do
  id = id + 1
  io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
  io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
  io.write(" - Prepare Collection ("..id..")")
  io.flush()

  local content = (preferscan and images[i]["scan"] or images[i]["stock"] or images[i]["scan"])

  local color = card.color
  if not color then
    color = "Artifact" -- artifacts
  elseif string.find(color, "%,") then
    color = "Multicolor" -- multicolor
  elseif colormap[color]then
    color = colormap[color]
  end

  -- prepare collection filenames
  local filename = string.format("%s, %s", color, card.name)
  if card.name_lang then
    filename = string.format("%s, %s (%s)", color, card.name, card.name_lang)
  end

  -- remove slashes in filename
  filename = string.gsub(filename, "/", "|")

  -- find next possible count
  local count = 1
  while files[string.format("%s (%s).%s", filename, count, "jpg")] do
    count = count + 1
  end

  -- write to disk
  files[string.format("%s (%s).%s", filename, count, "jpg")] = content
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
