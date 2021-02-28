-- download gatherer images
local gatherer = {}
function gatherer:Fetch(collection, images)
  local https = require("ssl.https")
  local id = 0

  for i, card in pairs(collection) do
    id = id + 1
    io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
    io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
    io.write(" - Downloading Gatherer Artwork ("..id..")")
    io.flush()

    if card.multiverse and card.imgurl and not io.open("cache/images/" .. card.scryfall .. ".jpg") then
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
  return images
end

return gatherer
