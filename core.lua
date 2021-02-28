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

-- initialize vars
local colormap = { R = "Red", U = "Blue", B = "Black", G = "Green", W = "White" }
local files = {}

-- load delver lens backup file
local delver = require("delver")
local metadata, images = delver:LoadBackup()

local mtgjson = require("mtgjson")
local collection = mtgjson:Initialize(metadata)


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
