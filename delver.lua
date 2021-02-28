-- load delver backup file and turn it into tables
local delver = {}
function delver.LoadBackup()
  -- skip without any required files
  if not io.open("./cache/cards.sqlite") or not io.open("./cache/delver.sqlite") then
    return nil
  end

  -- load and initialize delver files
  local sqlite3 = require('lsqlite3')
  local sqldelver = sqlite3.open("./cache/delver.sqlite")
  local sqlcards = sqlite3.open("./cache/cards.sqlite")
  local metadata, images = {}, {}
  local id = 0

  for card in sqlcards:nrows("SELECT * FROM cards;") do
    local scryfall, ccount = nil, card.quantity
    for delver in sqldelver:nrows("SELECT * FROM cards WHERE _id = " .. card.card .. ";") do
      scryfall = delver.scryfall_id
    end

    while ccount > 0 do
      -- find next possible count
      local count = 1
      while metadata[string.format("%s,%s", scryfall, count)] do
        count = count + 1
      end

      -- save to collection
      metadata[string.format("%s,%s", scryfall, count)] = { scryfall = scryfall, lang = card.language }
      images[string.format("%s,%s", scryfall, count)] = { scan = card.image }
      ccount = ccount - 1

      -- show progress
      id = id + 1
      io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
      io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
      io.write(" - Loading Collection (" .. id .. ")")
    end
  end

  print()
  return metadata, images
end

return delver
