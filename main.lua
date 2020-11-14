#!/bin/env lua
local sqlite3 = require('lsqlite3')

-- load both databases
local delver = sqlite3.open("./delver.sqlite")
local mycard = sqlite3.open("./mycards.sqlite")

-- main loop
for mcards in mycard:nrows("SELECT * FROM cards;") do
  local quantity = mcards.quantity

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
      mana = dnames.mana
      typ  = dnames.type
      cost = dnames.cmana
    end

    -- look for edition
    for deditions in delver:nrows("SELECT * FROM editions WHERE _id = " .. dcards.edition .. ";") do
      edition = deditions.name
      editabb = deditions.tl_abb
    end
  end

  -- debug
  print(string.format([[
## %s (%s)
*Edition: %s (%s)*
![img](https://gatherer.wizards.com/Handlers/Image.ashx?multiverseid=%s&type=card)
  ]], name, quantity, edition, editabb, multiverse))
end
