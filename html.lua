-- build a raw collection on filesystem
local html = {}
function html:Write(collection, images)
  local id, files = 0, {}
  local json = require ("dkjson")
  table.sort(collection)

  -- write collection as json object
  local file = io.open("www/collection.js", "w")
  file:write("const collection = [" .. json.encode(collection) .. "];")
  file:close()

  -- write template to html output folder
  local template = io.open("html/template.html", "rb")
  local file = io.open("www/index.html", "w")
  file:write(template:read("*all"))
  file:close()
  template:close()

  -- copy all template resources
  for _, file in pairs({"res/artifact.png", "res/black.png", "res/blue.png", "res/green.png", "res/logo.png", "res/multi.png", "res/red.png", "res/white.png"}) do
    local src = io.open("html/"..file, "rb")
    local dest = io.open("www/"..file, "w")
    dest:write(src:read("*all"))
    dest:close()
    src:close()
  end

  -- write all images into html directory
  for i, card in pairs(collection) do
    id = id + 1
    io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
    io.write("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b")
    io.write(" - Write HTML Collection ("..id..")")
    io.flush()

    local content = (preferscan and images[i]["scan"] or images[i]["stock"] or images[i]["scan"])
    local file = io.open("www/img/" .. i .. ".jpg", "w")
    file:write(content)
    file:close()
  end
  print("")
end

return html
