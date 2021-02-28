-- initialize collection by enhancing import data with mtgjson fields
local mtgjson = {}
function mtgjson:Initialize(metadata)
  local json = require ("dkjson")
  local sqlite3 = require('lsqlite3')
  local sqlmtgjson = sqlite3.open("./cache/mtgjson.sqlite")
  local collection = {}

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
  print()

  return collection
end

return mtgjson
