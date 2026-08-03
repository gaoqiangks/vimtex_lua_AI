local parser = require "vimtex.parser.bib"

local M = {}
local level_cache = { buffer = -1, tick = -1, levels = {} }

local function count(text, character)
  local _, total = text:gsub(vim.pesc(character), "")
  return total
end

local function get_max_key_width()
  if vim.g.vimtex_fold_bib_max_key_width > 0 then
    return vim.g.vimtex_fold_bib_max_key_width
  end

  local entries = parser.parse_cheap(
    1,
    vim.api.nvim_buf_line_count(0),
    { get_description = false }
  )
  if #entries == 0 then
    return 32
  end

  local width = 0
  for _, entry in ipairs(entries) do
    width = math.max(
      width,
      3
        + vim.fn.strdisplaywidth(entry.type or "")
        + vim.fn.strdisplaywidth(entry.key or "")
    )
  end
  return width
end

function M.init()
  vim.b.vimtex_fold_bib_maxwidth = get_max_key_width()

  vim.api.nvim_create_autocmd("BufWrite", {
    group = vim.api.nvim_create_augroup("vimtex_buffers", { clear = false }),
    buffer = 0,
    callback = function()
      vim.b.vimtex_fold_bib_maxwidth = get_max_key_width()
    end,
  })

  vim.opt_local.foldmethod = "expr"
  vim.opt_local.foldexpr = "v:lua.vimtex_fold_bib_level(v:lnum)"
  vim.opt_local.foldtext = "v:lua.vimtex_fold_bib_text()"
end

local function refresh_levels()
  local buffer = vim.api.nvim_get_current_buf()
  local tick = vim.api.nvim_buf_get_changedtick(buffer)
  if level_cache.buffer == buffer and level_cache.tick == tick then
    return
  end
  local levels = {}
  local opened, closed, firstline = 0, 0, 0
  local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
  for line_number, line in ipairs(lines) do
    if line:match "^%s*$" then
      local previous = levels[line_number - 1]
      levels[line_number] = previous == "<1" and 0 or previous or 0
    else
      local is_first = line:match "^%s*@" ~= nil
      if is_first then
        firstline = line_number
        opened, closed = count(line, "{"), count(line, "}")
      elseif firstline > 0 then
        opened = opened + count(line, "{")
        closed = closed + count(line, "}")
      end
      if firstline == 0 then
        levels[line_number] = 0
      elseif is_first then
        levels[line_number] = opened > 0 and opened == closed and 0 or ">1"
      else
        levels[line_number] = opened == closed and "<1" or 1
      end
    end
  end
  level_cache = { buffer = buffer, tick = tick, levels = levels }
end

function M.level(line_number)
  refresh_levels()
  return level_cache.levels[line_number] or 0
end

function M.text()
  local entries = parser.parse_cheap(vim.v.foldstart, vim.v.foldend, {})
  if #entries ~= 1 or not entries[1].type or not entries[1].key then
    return vim.fn.foldtext()
  end

  local entry = entries[1]
  local text = "@" .. entry.type .. "{" .. entry.key .. "}"
  local width = vim.fn.strdisplaywidth(text)
  local maximum = vim.b.vimtex_fold_bib_maxwidth
  if width > maximum then
    text = vim.fn.printf("%." .. maximum .. "S", text)
    width = vim.fn.strdisplaywidth(text)
  end
  text = text .. string.rep(" ", maximum + 2 - width)

  if entry.description and entry.description ~= "" then
    text = text .. entry.description
  end
  return text
end

_G.vimtex_fold_bib_level = M.level
_G.vimtex_fold_bib_text = M.text

return M
