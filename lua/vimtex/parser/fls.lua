local M = {}
local util = require "vimtex.util"

function M.parse(file)
  return util.readfile(file)
end

return M
