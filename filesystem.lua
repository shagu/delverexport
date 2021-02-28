-- build a raw collection on filesystem
local filesystem = {}
local colormap = { R = "Red", U = "Blue", B = "Black", G = "Green", W = "White" }

function filesystem:Write(collection, images)
  local id, files = 0, {}

  for i, card in pairs(collection) do
    id = id + 1
    io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
    io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
    io.write(" - Write Filesystem Collection ("..id..")")
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

    -- cache created file in table
    files[string.format("%s (%s).%s", filename, count, "jpg")] = true

    -- write to disk
    local file = io.open("collection/" .. string.format("%s (%s).%s", filename, count, "jpg"), "w")
    file:write(content)
    file:close()
  end
  print("")
end

return filesystem
