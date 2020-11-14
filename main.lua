#!/bin/env lua
local sqlite3 = require('lsqlite3')

-- load both databases
local delver = sqlite3.open("./delver.sqlite")
local mycards = sqlite3.open("./mycards.sqlite")

-- initial sqlite check
for row in mycards:nrows('SELECT * FROM cards;') do
  print(row.card)
end
