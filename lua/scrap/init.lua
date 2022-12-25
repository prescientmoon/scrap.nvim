local internal = require("scrap.internal")
local scrap = {}

---Abbreviate many pairs at once
---@param abbreviations ScrapAbbreviation[]
function scrap.many_local_abbreviations(abbreviations)
  for _, value in pairs(abbreviations) do
    vim.cmd(":iabbrev <buffer> " .. value[1] .. " " .. value[2])
  end
end

scrap.expand_many = internal.expand_many

return scrap
