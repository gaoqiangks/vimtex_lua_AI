local M = {}

local groups = {}

function M.clear()
  for _, name in ipairs { "vimtex_match_id1", "vimtex_match_id2" } do
    local id = vim.w[name]
    if id then
      pcall(vim.fn.matchdelete, id)
      vim.w[name] = nil
    end
  end
end

function M.highlight()
  M.clear()
  if require("vimtex.syntax").in_comment() then
    return
  end
  if vim.fn.mode() == "\22" then
    local position = require("vimtex.pos").get_cursor()
    if #position == 5 and position[#position] == 2147483647 then
      vim.api.nvim_feedkeys("$", "in", false)
    end
  end
  local pair = require("vimtex.delim").get_current_matching("all", "both")
  local current, corresponding = pair[1], pair[2]
  if vim.fn.empty(current) == 1 then
    return
  end
  if vim.fn.empty(corresponding) == 1 or corresponding.match == "" then
    return
  end
  local opening, closing = current, corresponding
  if current.is_open == 0 or current.is_open == false then
    opening, closing = corresponding, current
  end
  vim.w.vimtex_match_id1 = vim.fn.matchaddpos("MatchParen", {
    { opening.lnum, opening.cnum, #opening.match },
  })
  vim.w.vimtex_match_id2 = vim.fn.matchaddpos("MatchParen", {
    { closing.lnum, closing.cnum, #closing.match },
  })
end

function M.enable()
  local buffer = vim.api.nvim_get_current_buf()
  if groups[buffer] then
    pcall(vim.api.nvim_del_augroup_by_id, groups[buffer])
  end
  local group =
    vim.api.nvim_create_augroup("vimtex_matchparen" .. buffer, { clear = true })
  groups[buffer] = group
  vim.api.nvim_create_autocmd(
    { "CursorMoved", "CursorMovedI", "WinEnter", "TextChangedP" },
    {
      group = group,
      buffer = buffer,
      callback = M.highlight,
    }
  )
  vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
    group = group,
    buffer = buffer,
    callback = M.clear,
  })
  M.highlight()
end

function M.disable()
  M.clear()
  local buffer = vim.api.nvim_get_current_buf()
  if groups[buffer] then
    pcall(vim.api.nvim_del_augroup_by_id, groups[buffer])
    groups[buffer] = nil
  end
end

function M.popup_check()
  if vim.fn.pumvisible() == 1 then
    M.highlight()
  end
end

function M.init_buffer()
  if vim.g.vimtex_matchparen_enabled ~= 0 then
    M.enable()
  end
end

return M
