local parser = require "vimtex.parser.bib"

local M = {}

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

function M.level(line_number)
  local line = vim.api.nvim_buf_get_lines(
    0,
    line_number - 1,
    line_number,
    false
  )[1] or ""
  if vim.trim(line) == "" then
    if line_number == 1 then
      return 0
    end
    local previous = M.level(line_number - 1)
    return previous == "<1" and 0 or previous
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  vim.api.nvim_win_set_cursor(0, { line_number, 0 })
  local firstline = vim.fn.search([[^\s*@]], "bcnW")
  vim.api.nvim_win_set_cursor(0, cursor)

  if firstline == 0 then
    return 0
  end

  local text = table.concat(
    vim.api.nvim_buf_get_lines(0, firstline - 1, line_number, false)
  )
  local opened = count(text, "{")
  local balanced = opened == count(text, "}")
  if firstline == line_number then
    return opened > 0 and balanced and 0 or ">1"
  end
  return balanced and "<1" or 1
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
