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

-- create output directories
os.execute("mkdir -p collection/")
os.execute("mkdir -p cache/images/")
os.execute("mkdir -p cache/scans/")
os.execute("mkdir -p cache/data/")

-- initialize vars
local files = {}

-- load delver lens backup file
local delver = require("delver")
local collection, images = delver:LoadBackup()

-- create collection with mgtjson data
local mtgjson = require("mtgjson")
local collection = mtgjson:Initialize(collection)

-- download gatherer images
local gatherer = require("gatherer")
local images = gatherer:Fetch(collection, images)

-- build filesystem collection
local filesystem = require("filesystem")
local _ = filesystem:Write(collection, images)
