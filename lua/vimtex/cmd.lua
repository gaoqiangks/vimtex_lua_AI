local M = {}
local pos = require "vimtex.pos"

function M.parser_separator_check(separator)
  return vim.fn.match(separator, [[\v^%(\n\s*)?$]]) >= 0
end

local function separator_valid(separator)
  local callback = vim.g.vimtex_parser_cmd_separator_check
  if callback == nil or callback == "vimtex#cmd#parser_separator_check" then
    return M.parser_separator_check(separator)
  end
  if type(callback) == "string" then
    return vim.fn[callback](separator) ~= 0
  end
  return vim.fn.call(callback, { separator }) ~= 0
end

local function text_between(first, last, include)
  local line1, column1 = first.lnum, first.cnum - (include and 1 or 0)
  local line2, column2 = last.lnum, last.cnum - (include and 0 or 1)
  local lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
  if #lines > 0 then
    lines[1] = lines[1]:sub(column1 + 1)
    local length = line1 == line2 and column2 - column1 or column2
    lines[#lines] = lines[#lines]:sub(1, length)
  end
  return table.concat(lines, "\n")
end

local function command_name(next_command)
  local found = vim.fn.searchpos(
    [[\v\\%([a-zA-Z@]+\*?|[,:;!])]],
    next_command and "nW" or "cbnW"
  )
  local line, column = found[1], found[2]
  return line,
    column,
    vim.fn.matchstr(
      vim.fn.getline(line),
      [[^\v\\%([,:;!]|[a-zA-Z@]*\*?)]],
      column - 1
    )
end

local function delimiter_part(opening_character, start)
  local saved = pos.get_cursor()
  pos.set_cursor(start)
  local pair = require("vimtex.delim").get_next_matching("delim_tex", "open")
  pos.set_cursor(saved)
  local opening, closing = pair[1], pair[2]
  if
    vim.tbl_isempty(opening)
    or opening.match ~= opening_character
    or not separator_valid(text_between(start, opening))
    or vim.tbl_isempty(closing)
  then
    return {}
  end
  return {
    open = opening,
    close = closing,
    text = text_between(opening, closing),
  }
end

local function simple_part(delimiters, start)
  local pattern = [[^\s*]]
    .. delimiters[1]
    .. "[^"
    .. delimiters[2]
    .. "]*"
    .. delimiters[2]
  local found = vim.fn.matchstr(vim.fn.getline(start.lnum), pattern, start.cnum)
  if found == "" then
    return {}
  end
  local separator = vim.fn.matchstr(found, [[^\s*]])
  if not separator_valid(separator) then
    return {}
  end
  local offset = #separator
  return {
    open = { lnum = start.lnum, cnum = start.cnum + offset + 1 },
    close = { lnum = start.lnum, cnum = start.cnum + #found },
    text = vim.trim(found),
  }
end

local function get(direction)
  local line, column, name = command_name(direction == "next")
  if line == 0 then
    return {}
  end
  local result = {
    name = name,
    text = "",
    pos_start = { lnum = line, cnum = column },
    pos_end = { lnum = line, cnum = column + #name - 1 },
    args = {},
    args_parens = {},
    args_chevrons = {},
    opts = {},
  }
  if name == "\\begin" then
    local argument = delimiter_part("{", result.pos_end)
    if vim.tbl_isempty(argument) then
      return result
    end
    table.insert(result.args, argument)
    result.pos_end = { lnum = argument.close.lnum, cnum = argument.close.cnum }
  end
  while true do
    local part = delimiter_part("[", result.pos_end)
    if not vim.tbl_isempty(part) then
      table.insert(result.opts, part)
    else
      part = delimiter_part("{", result.pos_end)
      if not vim.tbl_isempty(part) then
        table.insert(result.args, part)
      else
        part = simple_part({ "(", ")" }, result.pos_end)
        if not vim.tbl_isempty(part) then
          table.insert(result.args_parens, part)
        else
          part = simple_part({ "<", ">" }, result.pos_end)
          if not vim.tbl_isempty(part) then
            table.insert(result.args_chevrons, part)
          else
            break
          end
        end
      end
    end
    result.pos_end = { lnum = part.close.lnum, cnum = part.close.cnum }
  end
  result.text = text_between(result.pos_start, result.pos_end, true)
  return result
end

function M.get_next()
  return get "next"
end
function M.get_prev()
  return get "prev"
end
function M.get_current()
  local saved = pos.get_cursor()
  local cursor_value = pos.val(saved)
  for _ = 1, 3 do
    local command = get "prev"
    if vim.tbl_isempty(command) then
      break
    end
    if pos.val(command.pos_end) >= cursor_value then
      pos.set_cursor(saved)
      return command
    end
    pos.set_cursor(pos.prev(command.pos_start))
  end
  pos.set_cursor(saved)
  return {}
end
function M.get_at(...)
  local saved = pos.get_cursor()
  pos.set_cursor(...)
  local command = M.get_current()
  pos.set_cursor(saved)
  return command
end

function M.change(new_name)
  local command = M.get_current()
  if vim.tbl_isempty(command) then
    return
  end
  new_name = new_name:gsub("^\\", "")
  if new_name == "" then
    return
  end
  local line, column = command.pos_start.lnum, command.pos_start.cnum
  local cursor = pos.get_cursor()
  local text = vim.fn.getline(line)
  vim.fn.setline(
    line,
    vim.fn.strpart(text, 0, column)
      .. new_name
      .. vim.fn.strpart(text, column + #command.name - 1)
  )
  if #new_name < #command.name and cursor[3] > column + #new_name then
    cursor[3] = column + #new_name
  end
  pos.set_cursor(cursor)
end

function M.delete(...)
  local command = select("#", ...) > 0 and M.get_at(...) or M.get_current()
  if vim.tbl_isempty(command) then
    return
  end
  local cursor, line, column =
    pos.get_cursor(), command.pos_start.lnum, command.pos_start.cnum
  local finish = column + #command.name - 1
  if #command.args == 1 then
    local closing = command.args[1].close
    local text = vim.fn.getline(closing.lnum)
    vim.fn.setline(
      closing.lnum,
      vim.fn.strpart(text, 0, closing.cnum - 1)
        .. vim.fn.strpart(text, closing.cnum)
    )
    finish = command.args[1].open.cnum
  end
  local text = vim.fn.getline(line)
  vim.fn.setline(
    line,
    vim.fn.strpart(text, 0, column - 1) .. vim.fn.strpart(text, finish)
  )
  if cursor[2] == line then
    cursor[3] = cursor[3]
      - (
        cursor[3] > finish and finish - column + 1
        or math.max(cursor[3] - column, 0)
      )
  end
  pos.set_cursor(cursor)
end

function M.delete_all(...)
  local command = select("#", ...) > 0 and M.get_at(...) or M.get_current()
  if vim.tbl_isempty(command) then
    return
  end
  pos.set_cursor(command.pos_start)
  vim.cmd "normal! v"
  pos.set_cursor(command.pos_end)
  vim.cmd "normal! d"
end

function M.create_insert()
  if not vim.fn.mode():match "i" then
    return ""
  end
  local pattern, column =
    [[\v%(^|\A)\zs\a+(\*=)@>\a*\ze%(\A|$)]], vim.fn.col "." - 1
  local found = vim.fn.searchpos(pattern, "bcn", vim.fn.line ".")
  local line, start = found[1], found[2] - 1
  local match = vim.fn.matchstr(vim.fn.getline(line), pattern, start)
  local finish = start + #match
  if column > finish then
    require("vimtex.log").warning "Could not create command"
    return ""
  end
  local prefix = vim.fn.strpart(match, 0, column - start)
  local suffix = vim.fn.strpart(match, column - start)
  local suffix_length = finish - column
  local delete_suffix = suffix_length > 0 and ("\15" .. suffix_length .. "x")
    or ""
  return string.rep("\b", #prefix)
    .. delete_suffix
    .. "\\"
    .. prefix
    .. "{"
    .. suffix
end

function M.create_visual(name)
  if not name or name == "" then
    return
  end
  local anchor, cursor = vim.fn.getpos "v", vim.fn.getcurpos()
  local first_line, first_col, last_line, last_col =
    anchor[2], anchor[3], cursor[2], cursor[3]
  if
    first_line > last_line or (first_line == last_line and first_col > last_col)
  then
    first_line, last_line, first_col, last_col =
      last_line, first_line, last_col, first_col
  end
  local selected = vim.api.nvim_buf_get_text(
    0,
    first_line - 1,
    first_col - 1,
    last_line - 1,
    last_col,
    {}
  )
  selected[1] = "\\" .. name .. "{" .. selected[1]
  selected[#selected] = selected[#selected] .. "}"
  vim.api.nvim_buf_set_text(
    0,
    first_line - 1,
    first_col - 1,
    last_line - 1,
    last_col,
    selected
  )
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes("<esc>", true, false, true),
    "n",
    false
  )
end

function M.create(name, visual)
  if not name or name == "" then
    return
  end
  local indentkeys = vim.bo.indentkeys
  vim.bo.indentkeys = ""
  if visual then
    local first, last = vim.fn.getpos "'<", vim.fn.getpos "'>"
    if vim.fn.visualmode() == "\22" then
      vim.cmd "normal! gvA}"
      vim.cmd("normal! gvI\\" .. name .. "{")
      last[3] = last[3] + #name + 3
    else
      vim.cmd "normal! `>a}"
      vim.cmd "normal! `<"
      vim.cmd("normal! i\\" .. name .. "{")
      last[3] = last[3] + (last[2] == first[2] and #name + 3 or 1)
    end
    pos.set_cursor(last)
  else
    local cursor, register = pos.get_cursor(), vim.fn.getreg '"'
    cursor[3] = cursor[3] + #name + 2
    vim.cmd("normal! ciw\\" .. name .. '{\18"}')
    vim.fn.setreg('"', register)
    pos.set_cursor(cursor)
  end
  vim.bo.indentkeys = indentkeys
end

local function star_allowed(name)
  if #(vim.g.vimtex_toggle_star_cmds or {}) == 0 then
    return true
  end
  name = name:gsub("^\\", ""):gsub("%*$", "")
  for _, pattern in ipairs(vim.g.vimtex_toggle_star_cmds) do
    if vim.fn.match(name, [[\v^%(]] .. pattern .. [=[$)]=]) >= 0 then
      return true
    end
  end
  return false
end

function M.toggle_star()
  local command = M.get_current()
  if vim.tbl_isempty(command) or not star_allowed(command.name) then
    return
  end
  local name = command.name:match "%*$" and command.name:sub(1, -2)
    or command.name .. "*"
  name = name:gsub("^\\", "")
  local cursor = pos.get_cursor()
  cursor[3] = cursor[3] + #name - #command.name + 1
  local line, column =
    vim.fn.getline(command.pos_start.lnum), command.pos_start.cnum
  vim.fn.setline(
    command.pos_start.lnum,
    vim.fn.strpart(line, 0, column)
      .. name
      .. vim.fn.strpart(line, column + #command.name - 1)
  )
  pos.set_cursor(cursor)
end
function M.toggle_star_agnostic()
  local command = M.get_current()
  if vim.tbl_isempty(command) or command.name == "\\begin" then
    require("vimtex.env").toggle_star()
    return
  end
  local pair = require("vimtex.env").get_surrounding "normal"
  if vim.tbl_isempty(pair[1]) or pair[1].name == "document" then
    M.toggle_star()
    return
  end
  if pos.val(command.pos_start) >= pos.val(pair[1]) then
    M.toggle_star()
  else
    require("vimtex.env").toggle_star()
  end
end

local function fraction_toggled(origin, numerator, denominator)
  local target = (vim.g.vimtex_toggle_fractions or {})[origin] or "INLINE"
  if target == "INLINE" then
    if vim.fn.match(numerator, [[^\\\?\w*$]]) < 0 then
      numerator = "(" .. numerator .. ")"
    end
    if vim.fn.match(denominator, [[^\\\?\w*$]]) < 0 then
      denominator = "(" .. denominator .. ")"
    end
    return numerator .. "/" .. denominator
  end
  return "\\" .. target .. "{" .. numerator .. "}{" .. denominator .. "}"
end
local function trim_inline(text)
  return vim.trim(text):gsub("^%((.*)%)$", "%1")
end
local function inline_limit(text, direction)
  local opening, source =
    direction > 0 and "(" or ")", direction > 0 and text or text:reverse()
  local index, depth = -1, 0
  while index < #source do
    index = vim.fn.match(source, "[()]", index + 1)
    if index < 0 then
      index = #source
    end
    if index >= #source or source:sub(index + 1, index + 1) == opening then
      depth = depth + 1
    else
      depth = depth - 1
      if depth == 0 then
        return direction < 0 and #text - index or index
      end
    end
  end
  return -1
end
local function command_fraction()
  local names = {}
  for name in pairs(vim.g.vimtex_toggle_fractions or {}) do
    if name ~= "INLINE" then
      names["\\" .. name] = true
    end
  end
  local saved, command = pos.get_cursor()
  while true do
    command = get "prev"
    if vim.tbl_isempty(command) or command.pos_start.lnum < vim.fn.line "." then
      pos.set_cursor(saved)
      return
    end
    if names[command.name] then
      break
    end
    pos.set_cursor(pos.prev(command.pos_start))
  end
  pos.set_cursor(saved)
  local fraction = {
    origin = command.name:sub(2),
    col_start = command.pos_start.cnum - 1,
    col_end = command.pos_end.cnum - 1,
    numerator = command.args[1] and command.args[1].text or "",
    denominator = command.args[2] and command.args[2].text or "",
  }
  local consume = #command.args >= 2 and {}
    or (
      #command.args == 1 and { "denominator" } or { "numerator", "denominator" }
    )
  local line = vim.fn.getline "."
  for _, key in ipairs(consume) do
    local part = vim.fn.strpart(line, fraction.col_end + 1)
    local found = vim.fn.matchstr(part, [[^\s*{[^}]*}]])
    if found ~= "" then
      fraction[key] = vim.trim(found):sub(2, -2)
      fraction.col_end = fraction.col_end + #found
    else
      found = vim.fn.matchstr(part, [[^\s*\w]])
      if found ~= "" then
        fraction[key] = vim.trim(found)
        fraction.col_end = fraction.col_end + #found
      end
    end
  end
  if fraction.col_end < vim.fn.col "." then
    return
  end
  fraction.text_toggled =
    fraction_toggled(fraction.origin, fraction.numerator, fraction.denominator)
  return fraction
end
local function inline_fraction(text, cursor)
  local slash, previous = -1, -1
  while true do
    previous, slash = slash, vim.fn.match(text, "/", slash + 1)
    if slash < 0 or slash >= cursor then
      break
    end
  end
  local positions = {}
  if previous > 0 then
    table.insert(positions, previous)
  end
  if slash > 0 then
    table.insert(positions, slash)
  end
  for _, divide in ipairs(positions) do
    local before = text:sub(1, divide)
    local left
    if before:match "%)%s*$" then
      left = inline_limit(before, -1) - 1
    else
      left = vim.fn.match(before, [[\s*$]])
    end
    local atoms =
      vim.fn.matchstr(text:sub(1, left), [[\(\\(\)\?\zs[^-$(){} ]*$]])
    left = left - #atoms
    local after = text:sub(divide + 2)
    local denominator_atoms = [[\v^\s*[^$()} ]*]]
    local right_delimiter = [[\\%(right|[bB]igg?r?)?\)]]
    local denom
    if vim.fn.match(after, denominator_atoms .. right_delimiter) >= 0 then
      denom =
        vim.fn.matchstr(after, denominator_atoms .. [[\ze]] .. right_delimiter)
    else
      denom = vim.fn.matchstr(after, denominator_atoms)
    end
    local right = divide + #denom
    local remainder = text:sub(right + 2)
    local parens = ""
    if remainder:sub(1, 1) == "(" then
      local limit = inline_limit(remainder, 1)
      right = right + limit + 1
      parens = remainder:sub(1, limit + 1)
    end
    local fraction = {
      origin = "INLINE",
      numerator = trim_inline(atoms .. (before:match "(%b())%s*$" or "")),
      denominator = trim_inline(denom .. parens),
      col_start = left,
      col_end = right,
    }
    fraction.text_toggled = fraction_toggled(
      fraction.origin,
      fraction.numerator,
      fraction.denominator
    )
    if cursor >= left and cursor <= right then
      return fraction
    end
  end
end
function M.toggle_frac()
  local fraction = command_fraction()
    or inline_fraction(vim.fn.getline ".", vim.fn.col "." - 1)
  if not fraction then
    return
  end
  local line = vim.fn.getline "."
  vim.fn.setline(
    ".",
    vim.fn.strpart(line, 0, fraction.col_start)
      .. fraction.text_toggled
      .. vim.fn.strpart(line, fraction.col_end + 1)
  )
end
function M.toggle_frac_visual()
  local first, last = vim.fn.getpos "v", vim.fn.getcurpos()
  local first_line, first_col = first[2], first[3]
  local last_line, last_col = last[2], last[3]
  if
    first_line > last_line
    or (first_line == last_line and first_col > last_col)
  then
    first_line, last_line, first_col, last_col =
      last_line, first_line, last_col, first_col
  end
  local selected_lines = vim.api.nvim_buf_get_text(
    0,
    first_line - 1,
    first_col - 1,
    last_line - 1,
    last_col,
    {}
  )
  local selected = table.concat(selected_lines, "\n"):gsub("\n%s*", " ")
  local parts = vim.split(selected, "/", { plain = true })
  local fraction
  if #parts == 2 then
    fraction = {
      text_toggled = fraction_toggled(
        "INLINE",
        trim_inline(parts[1]),
        trim_inline(parts[2])
      ),
    }
  end
  if not fraction then
    local names = table.concat(
      vim.tbl_filter(function(x)
        return x ~= "INLINE"
      end, vim.tbl_keys(vim.g.vimtex_toggle_fractions or {})),
      [[\|]]
    )
    local found = vim.fn.matchlist(
      selected,
      [[^\s*\\\(]] .. names .. [[\)\s*{\(.*\)}\s*{\(.*\)}\s*$]]
    )
    if #found > 0 then
      fraction =
        { text_toggled = fraction_toggled(found[2], found[3], found[4]) }
    end
  end
  if fraction then
    vim.api.nvim_buf_set_text(
      0,
      first_line - 1,
      first_col - 1,
      last_line - 1,
      last_col,
      vim.split(fraction.text_toggled, "\n", { plain = true })
    )
  end
end
function M.toggle_break()
  local line = vim.fn.getline "."
  if vim.fn.match(line, [[\s*\\\\\s*$]]) >= 0 then
    line = vim.fn.substitute(line, [[\s*\\\\\s*$]], "", "")
  else
    line = vim.fn.substitute(line, [[\s*$]], [[ \\\\]], "")
  end
  vim.fn.setline(".", line)
end

local pending
local repeat_tick
local function operator(action)
  if action == "change" or action == "create" then
    pending = {
      action,
      (require("vimtex.ui").input {
        prompt = (action == "change" and "Change" or "Create") .. " command: ",
      } or ""):gsub("^\\", ""),
    }
  else
    pending = { action }
  end
  vim.go.operatorfunc = "v:lua.require'vimtex.cmd'.operator_callback"
  vim.cmd "normal! g@l"
end
function M.operator_callback()
  if not pending then
    return
  end
  local action, name = pending[1], pending[2]
  if action == "change" then
    M.change(name)
  elseif action == "create" then
    M.create(name, false)
  else
    M[action]()
  end
  pcall(
    vim.fn["repeat#set"],
    vim.api.nvim_replace_termcodes(
      "<plug>(vimtex-cmd-repeat)",
      true,
      false,
      true
    ),
    vim.v.count
  )
  repeat_tick = vim.b.changedtick
end
function M.init_buffer()
  local maps = {
    ["<plug>(vimtex-cmd-delete)"] = "delete",
    ["<plug>(vimtex-cmd-change)"] = "change",
    ["<plug>(vimtex-cmd-create)"] = "create",
    ["<plug>(vimtex-cmd-toggle-star)"] = "toggle_star",
    ["<plug>(vimtex-cmd-toggle-star-agn)"] = "toggle_star_agnostic",
    ["<plug>(vimtex-cmd-toggle-frac)"] = "toggle_frac",
    ["<plug>(vimtex-cmd-toggle-break)"] = "toggle_break",
  }
  for lhs, action in pairs(maps) do
    vim.keymap.set("n", lhs, function()
      operator(action)
    end, { buffer = true, silent = true })
  end
  vim.keymap.set("n", "<plug>(vimtex-cmd-repeat)", function()
    M.operator_callback()
  end, { buffer = true, silent = true })
  vim.keymap.set("n", ".", function()
    if pending and repeat_tick == vim.b.changedtick then
      M.operator_callback()
    else
      vim.cmd "normal! ."
    end
  end, { buffer = true, silent = true })
  vim.keymap.set(
    "i",
    "<plug>(vimtex-cmd-create)",
    M.create_insert,
    { buffer = true, expr = true, silent = true }
  )
  vim.keymap.set("x", "<plug>(vimtex-cmd-create)", function()
    local name = require("vimtex.ui").input { prompt = "Create command: " }
    M.create_visual((name or ""):gsub("^\\", ""))
  end, { buffer = true, silent = true })
  vim.keymap.set(
    "x",
    "<plug>(vimtex-cmd-toggle-frac)",
    M.toggle_frac_visual,
    { buffer = true, silent = true }
  )
end

return M
