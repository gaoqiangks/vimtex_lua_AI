local M = {}
local api = vim.api
local installed = false

local function enabled()
  return vim.bo.filetype == "tex"
    and vim.g.vimtex_enabled ~= 0
    and vim.g.vimtex_env_normalize_on_paste ~= 0
end

-- Native and mapped puts set '[ and '] around the inserted text. Block puts
-- occupy disjoint columns, so their enclosing range is not safe to rewrite.
function M.after_put(tick, regtype)
  if
    not enabled()
    or tick == vim.b.changedtick
    or regtype:sub(1, 1) == "\022"
  then
    return
  end
  local first, last =
    api.nvim_buf_get_mark(0, "["), api.nvim_buf_get_mark(0, "]")
  if first[1] == 0 or last[1] < first[1] then
    return
  end
  local endline = api.nvim_buf_get_lines(0, last[1] - 1, last[1], true)[1]
  first[1], last[1] = first[1] - 1, last[1] - 1
  -- With a trailing newline a characterwise register ends just before col 0
  -- of the next line. No target closing delimiter fits in that single byte.
  if regtype ~= "v" or last[1] == first[1] or last[2] > 0 then
    last[2] = last[2] < #endline
        and (last[2] + 1 + vim.str_utf_end(endline, last[2] + 1))
      or #endline
  end
  if first[1] ~= last[1] or first[2] < last[2] then
    require("vimtex.env.normalize").range(first, last)
  end
end

-- Bracketed paste can split a delimiter, or even a UTF-8 character, between
-- calls. Forward every chunk immediately and normalize once the paste ends.
local function install_paste_handler()
  local previous = vim.paste
  local stream
  vim.paste = function(lines, phase)
    if phase == -1 or phase == 1 then
      stream = nil
      if enabled() and vim.fn.getcmdtype() == "" and vim.bo.buftype == "" then
        local cursor = api.nvim_win_get_cursor(0)
        stream = {
          buf = api.nvim_get_current_buf(),
          tick = vim.b.changedtick,
          chunks = {},
          replace_start = vim.fn.mode() == "R" and { cursor[1] - 1, cursor[2] }
            or nil,
        }
      end
    end
    local state = stream
    if state and state.buf == api.nvim_get_current_buf() then
      state.chunks[#state.chunks + 1] = table.concat(lines, "\n")
    else
      state, stream = nil, nil
    end
    local result = previous(lines, phase)
    if result == false or phase == -1 or phase == 3 then
      stream = nil
    end
    if
      state
      and result ~= false
      and (phase == -1 or phase == 3)
      and state.buf == api.nvim_get_current_buf()
      and state.tick ~= vim.b.changedtick
      and enabled()
    then
      local text = table.concat(state.chunks)
      if text:find("\\", 1, true) or text:find("$$", 1, true) then
        local mark = api.nvim_buf_get_mark(0, "[")
        local first = state.replace_start or { mark[1] - 1, mark[2] }
        local pasted = vim.split(text, "\n", { plain = true })
        local last = {
          first[1] + #pasted - 1,
          #pasted[#pasted] + (#pasted == 1 and first[2] or 0),
        }
        -- A previously installed handler may redirect or modify the paste.
        -- Only act if the destination still holds the text we received.
        local ok, actual = pcall(
          api.nvim_buf_get_text,
          0,
          first[1],
          first[2],
          last[1],
          last[2],
          {}
        )
        if ok and vim.deep_equal(pasted, actual) then
          require("vimtex.env.normalize").range(first, last)
        end
      end
    end
    return result
  end
end

-- For expression mappings that perform a native register put.
function M.put_suffix(reg)
  if not enabled() or vim.fn.mode() == "\022" then
    return ""
  end
  local regtype = reg == "=" and "v" or vim.fn.getregtype(reg)
  if regtype:sub(1, 1) == "\022" then
    return ""
  end
  return ("<Cmd>lua require('vimtex.env.paste').after_put(%d,%q)<CR>"):format(
    vim.b.changedtick,
    regtype
  )
end

function M.setup_buffer()
  if not installed then
    install_paste_handler()
    installed = true
  end
  -- Leave existing mappings (e.g. Yanky's p/P) in control of the operation.
  -- They can call after_put with the original changedtick and register type.
  if vim.g.vimtex_mappings_enabled == 0 then
    return
  end
  for _, mode in ipairs { "n", "x" } do
    for _, key in ipairs { "p", "P", "gp", "gP" } do
      if vim.fn.maparg(key, mode) == "" then
        vim.keymap.set(mode, key, function()
          return key .. M.put_suffix(vim.v.register)
        end, { buffer = true, expr = true, silent = true })
      end
    end
  end
end

return M
