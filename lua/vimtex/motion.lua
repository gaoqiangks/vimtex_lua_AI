local M = {}
local pos = require "vimtex.pos"

local section_pattern =
  [[\v^\s*\\%(%(sub)?paragraph|%(sub)*section|chapter|part|appendi%(x|ces)|%(front|back|main)matter|add%(sec|chap|part))>|^\s*\\%(begin|end)\{document\}|^\s*\% [fF]ake%(part|chapter|%(sub)*section)]]

local function prepare(visual)
  if visual then
    vim.cmd "normal! gv"
  end
  vim.cmd "normal! m`"
end

local function repeated_search(pattern, flags, count)
  for _ = 1, count do
    vim.fn.search(pattern, flags)
  end
end

function M.find_matching_pair(visual)
  if visual then
    vim.cmd "normal! gv"
  end
  local pair = require("vimtex.delim").get_current_matching("all", "both")
  if vim.tbl_isempty(pair[1]) then
    pair = require("vimtex.delim").get_next_matching("all", "both")
  end
  local match = pair[2]
  if vim.tbl_isempty(match) or match.match == "" then
    return
  end
  vim.cmd "normal! m`"
  pos.set_cursor(
    match.lnum,
    match.cnum
      + (
        (match.is_open == 1 or match.is_open == true) and 0
        or #match.match - 1
      )
  )
end

function M.section(kind, backwards, visual)
  local count = vim.v.count1
  prepare(visual)
  local top = vim.fn.search(section_pattern, "nbW") == 0
  local bottom = vim.fn.search(section_pattern, "nW") == 0
  if backwards and top then
    pos.set_cursor { 1, 1 }
    return
  end
  if not backwards and bottom then
    pos.set_cursor { vim.fn.line "$", 1 }
    return
  end
  local flags = "W" .. (backwards and "b" or "")
  for _ = 1, count do
    if kind == 1 then
      vim.fn.search([[\S]], "W")
    end
    bottom = vim.fn.search(section_pattern, "nW") == 0
    if kind == 1 and not backwards and bottom then
      pos.set_cursor { vim.fn.line "$", 1 }
      return
    end
    top = vim.fn.search(section_pattern, "ncbW") == 0
    local line = vim.fn.search(section_pattern, flags)
    if top and line > 0 and kind == 1 and not backwards then
      vim.fn.search(section_pattern, flags)
    end
    if kind == 1 then
      vim.fn.search([[\S\s*\n\zs]], "Wb")
      if vim.fn.search(section_pattern, "ncbW") == 0 then
        pos.set_cursor { 1, 1 }
      end
    end
  end
end

function M.environment(beginning, backwards, visual)
  local count = vim.v.count1
  prepare(visual)
  local pattern = vim.g["vimtex#re#not_comment"]
    .. (beginning and [[\\begin\s*\{]] or [[\\end\s*\{]])
  repeated_search(pattern, "W" .. (backwards and "b" or ""), count)
end

function M.frame(beginning, backwards, visual)
  local count = vim.v.count1
  prepare(visual)
  local pattern = vim.g["vimtex#re#not_comment"]
    .. (beginning and [[\\begin\s*\{frame\}]] or [[\\end\s*\{frame\}]])
  repeated_search(pattern, "W" .. (backwards and "b" or ""), count)
end

function M.comment(beginning, backwards, visual)
  local count = vim.v.count1
  prepare(visual)
  local pattern = beginning and [[\v%(^\s*\%.*\n)@<!\s*\%]]
    or [[\v^\s*\%.*\n%(^\s*\%)@!]]
  repeated_search(pattern, "W" .. (backwards and "b" or ""), count)
end

function M.math(beginning, backwards, visual)
  local count = vim.v.count1
  local saved = pos.get_cursor()
  prepare(visual)
  local pattern = vim.g["vimtex#re#not_comment"]
    .. (
      beginning and [[%((\\\[)|(\\\()|(\\begin\s*\{)|(\$\$)|(\$))]]
      or [[%((\\\])|(\\\))|(\\end\s*\{)|(\$\$)|(\$))]]
    )
  local flags = "Wp" .. (backwards and "b" or "")
  for _ = 1, count do
    local success = false
    for _ = 1, 6 do
      local submatch = vim.fn.search(pattern, flags)
      local current = pos.get_cursor()
      if submatch == 0 then
        break
      end
      if submatch < 4 then
        success = true
        break
      end
      if submatch == 4 then
        if require("vimtex.syntax").in_mathzone(current[2], current[3]) then
          success = true
          break
        end
      elseif beginning then
        if require("vimtex.syntax").in_mathzone(current[2], current[3]) then
          success = true
          break
        end
      else
        if
          require("vimtex.syntax").in_mathzone(current[2], current[3])
          or pos.val(saved) - pos.val(current) == 1
        then
          goto continue
        end
        current = pos.prev(pos.prev(current))
        if require("vimtex.syntax").in_mathzone(current[2], current[3]) then
          success = true
          break
        end
      end
      ::continue::
    end
    if success then
      saved = pos.get_cursor()
    else
      pos.set_cursor(saved)
      break
    end
  end
end

local function map(lhs, callback, charwise)
  vim.keymap.set("n", lhs, callback, { buffer = true, silent = true })
  vim.keymap.set("x", lhs, function()
    callback(true)
  end, { buffer = true, silent = true })
  vim.keymap.set("o", lhs, function()
    vim.cmd(charwise and "normal! v" or "normal! V")
    callback(true)
  end, { buffer = true, silent = true })
end

function M.init_buffer()
  if vim.g.vimtex_motion_enabled == 0 then
    return
  end
  map("<plug>(vimtex-%)", M.find_matching_pair, true)
  for _, spec in ipairs {
    { "]]", M.section, 0, false },
    { "][", M.section, 1, false },
    { "[]", M.section, 1, true },
    { "[[", M.section, 0, true },
    { "]n", M.math, true, false },
    { "]N", M.math, false, false },
    { "[n", M.math, true, true },
    { "[N", M.math, false, true },
    { "]m", M.environment, true, false },
    { "]M", M.environment, false, false },
    { "[m", M.environment, true, true },
    { "[M", M.environment, false, true },
    { "]r", M.frame, true, false },
    { "]R", M.frame, false, false },
    { "[r", M.frame, true, true },
    { "[R", M.frame, false, true },
    { "]/", M.comment, true, false },
    { "]*", M.comment, false, false },
    { "[/", M.comment, true, true },
    { "[*", M.comment, false, true },
  } do
    local lhs, callback, first, backwards = spec[1], spec[2], spec[3], spec[4]
    map("<plug>(vimtex-" .. lhs .. ")", function(visual)
      callback(first, backwards, visual)
    end)
  end
end

return M
