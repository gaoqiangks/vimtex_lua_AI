local M = {}
local pos = require "vimtex.pos"

local function state()
  return vim.b.toc or (vim.b.vimtex and vim.b.vimtex.toc)
end

local function base(number, radix)
  if number < radix then
    return { number }
  end
  local result = base(math.floor(number / radix), radix)
  table.insert(result, number % radix)
  return result
end

local function roman(number)
  local result = ""
  for _, pair in ipairs {
    { 1000, "M" },
    { 900, "CM" },
    { 500, "D" },
    { 400, "CD" },
    { 100, "C" },
    { 90, "XC" },
    { 50, "L" },
    { 40, "XL" },
    { 10, "X" },
    { 9, "IX" },
    { 5, "V" },
    { 4, "IV" },
    { 1, "I" },
  } do
    while number >= pair[1] do
      number, result = number - pair[1], result .. pair[2]
    end
  end
  return result
end

function M.new(options)
  return require("vimtex.util").extend_recursive(
    vim.deepcopy(vim.g.vimtex_toc_config),
    options or {}
  )
end

function M.is_open(toc)
  toc = toc or state()
  return toc and vim.fn.bufwinnr(vim.fn.bufnr(toc.name)) >= 0
end

local function visible(toc, entry)
  return (entry.active == nil or entry.active)
    and not entry.hidden
    and (entry.type ~= "content" or entry.level <= toc.tocdepth)
end

local function visible_entries(toc, entries)
  local result = {}
  for _, entry in ipairs(entries or {}) do
    if visible(toc, entry) then
      result[#result + 1] = entry
    end
  end
  return result
end

function M.get_visible_entries(toc)
  toc = toc or state()
  return visible_entries(toc, vim.deepcopy(toc.entries or {}))
end

function M.get_entries(force, toc)
  toc = toc or state()
  if toc.entries and toc.refresh_always == 0 and not force then
    return toc.entries
  end
  toc.entries = require("vimtex.parser").toc()
  toc.topmatters = require("vimtex.parser.toc").get_topmatters()
  if toc.todo_sorted == 1 then
    local todos = vim.tbl_filter(function(entry)
      return entry.type == "todo"
    end, toc.entries)
    for index = 2, #todos do
      todos[index].level = 1
    end
    toc.entries = vim.tbl_filter(function(entry)
      return entry.type ~= "todo"
    end, toc.entries)
    for index = #todos, 1, -1 do
      table.insert(toc.entries, 1, todos[index])
    end
  end
  if toc.hotkeys_enabled == 1 then
    local radix, count = vim.fn.strwidth(toc.hotkeys), #toc.entries
    local width = #base(count, radix)
    for index, entry in ipairs(toc.entries) do
      local digits, keys = base(index - 1, radix), {}
      for _ = 1, width - #digits do
        table.insert(keys, vim.fn.strcharpart(toc.hotkeys, 0, 1))
      end
      for _, digit in ipairs(digits) do
        table.insert(keys, vim.fn.strcharpart(toc.hotkeys, digit, 1))
      end
      entry.num, entry.hotkey = index, table.concat(keys)
    end
  end
  for _, entry in ipairs(toc.entries) do
    entry.active = toc.layer_status[entry.type] == 1
  end
  if force and M.is_open(toc) then
    M.refresh(toc)
  end
  return toc.entries
end

function M.print_number(number, toc)
  toc = toc or state()
  if not number or number == "" then
    return ""
  end
  if type(number) == "string" then
    return number
  end
  if vim.tbl_isempty(number) then
    return ""
  end
  if number.part_toggle == 1 or number.part_toggle == true then
    return roman(number.part)
  end
  local values = {
    number.chapter,
    number.section,
    number.subsection,
    number.subsubsection,
    number.subsubsubsection,
  }
  local first, last = 1, #values
  while first <= last and values[first] == 0 do
    first = first + 1
  end
  while last >= first and values[last] == 0 do
    last = last - 1
  end
  if
    (toc.topmatters or 0) > 1
    and (number.frontmatter == 1 or number.backmatter == 1)
  then
    return ""
  end
  if (number.appendix == 1 or number.appendix == true) and values[first] then
    values[first] = string.char(values[first] + 64)
  end
  return table.concat(values, ".", first, last)
end

local function set_number_format(toc)
  local width = 0
  for _, entry in ipairs(visible_entries(toc, toc.entries)) do
    width = math.max(width, #M.print_number(entry.number, toc) + 1)
  end
  toc.number_width = toc.layer_status.content == 1
      and math.max(0, math.min(2 * (toc.tocdepth + 2), width))
    or 0
  toc.number_format = "%-" .. toc.number_width .. "s"
end

function M.print_entry(entry, toc)
  toc = toc or state()
  local output = "L" .. entry.level .. " "
  if toc.hotkeys_enabled == 1 then
    output = output .. ("[%s] "):format(entry.hotkey)
  end
  if toc.indent_levels == 1 then
    output = output .. string.rep("  ", entry.level)
  end
  if toc.show_numbers == 1 then
    local number = entry.level >= toc.tocdepth + 2 and ""
      or vim.fn.strpart(
        M.print_number(entry.number, toc),
        0,
        toc.number_width - 1
      )
    output = output .. (toc.number_format):format(number)
  end
  output = output .. entry.title
  vim.fn.append("$", output)
end

local function print_help(toc)
  if toc.show_help == 0 then
    vim.fn.append("$", { "Press h to toggle help text.", "" })
    toc.help_nlines = 2
    return
  end
  local lines = {
    "      h  Toggle help text",
    "<Esc>/q  Close",
    "<Space>  Jump",
    "<Enter>  Jump and close",
    "      r  Refresh",
    "      t  Toggle sorted TODOs",
    "    -/+  Decrease/increase ToC depth",
    "    f/F  Apply/clear filter",
    "",
  }
  if toc.layer_status.content == 1 then
    table.insert(lines, #lines, "      s  Hide numbering")
  end
  local width = 0
  for _, key in pairs(toc.layer_keys) do
    width = math.max(width, #key)
  end
  local first = true
  for layer, status in pairs(toc.layer_status) do
    table.insert(
      lines,
      (first and "Layers:  " or "         ")
        .. ("%-" .. (width + 2) .. "s"):format(toc.layer_keys[layer])
        .. layer
        .. (status == 1 and "+" or "- (hidden)")
    )
    first = false
  end
  vim.fn.append("$", lines)
  vim.fn.append("$", "")
  toc.help_nlines = #lines + 1
end

local function print_entries(toc)
  set_number_format(toc)
  for _, entry in ipairs(visible_entries(toc, toc.entries)) do
    M.print_entry(entry, toc)
  end
end

function M.refresh(toc)
  toc = toc or state()
  local toc_window = vim.fn.bufwinnr(vim.fn.bufnr(toc.name))
  local current = vim.fn.bufwinnr ""
  if toc_window < 0 then
    return
  end
  if current ~= toc_window then
    vim.cmd(toc_window .. "wincmd w")
  end
  toc.position = pos.get_cursor()
  vim.bo.modifiable = true
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {})
  print_help(toc)
  print_entries(toc)
  vim.api.nvim_buf_set_lines(0, 0, 1, false, {})
  vim.bo.modifiable = false
  if toc.position[2] <= toc.help_nlines then
    toc.position[2] = toc.help_nlines + 1
  end
  pos.set_cursor(toc.position)
  if current ~= toc_window then
    vim.cmd(current .. "wincmd w")
  end
end

function M.close(toc)
  toc = toc or state()
  if not toc.bufnr_prev then
    return
  end
  toc.fold_level = vim.wo.foldlevel
  if toc.resize == 1 then
    vim.o.columns = vim.o.columns - toc.split_width
  end
  if toc.split_pos == "full" then
    vim.cmd("buffer " .. toc.bufnr_prev)
  else
    vim.fn.win_gotoid(toc.winid_prev)
    pcall(vim.cmd, "bwipeout " .. vim.fn.bufnr(toc.name))
  end
  if toc.bufnr_alternate and toc.bufnr_alternate >= 0 then
    vim.fn.setreg("#", toc.bufnr_alternate)
  end
end

local function activate(entry, close_after, toc)
  toc.prev_index = pos.get_cursor_line()
  local main = (vim.b.vimtex or {}).tex or ""
  vim.fn.win_gotoid(toc.winid_prev)
  local buffer = vim.fn.bufnr(entry.file)
  if buffer == -1 then
    vim.cmd("badd " .. vim.fn.fnameescape(entry.file))
    buffer = vim.fn.bufnr(entry.file)
  end
  vim.cmd("keepalt buffer! " .. buffer)
  if entry.line then
    pos.set_cursor(entry.line, 0)
  end
  if entry.link and main ~= "" then
    vim.b.vimtex_main = main
    require("vimtex.main").init()
  end
  vim.cmd "normal! zv"
  if close_after and toc.split_pos ~= "full" then
    M.close(toc)
  end
  vim.api.nvim_exec_autocmds(
    "User",
    { pattern = "VimtexEventTocActivated", modeline = false }
  )
end

local function activate_current(close_after, toc)
  local index = pos.get_cursor_line() - toc.help_nlines
  local entries = visible_entries(toc, toc.entries)
  if entries[index] then
    activate(entries[index], close_after, toc)
  end
end

local function create(toc)
  local previous, alternate, window =
    vim.fn.bufnr "", vim.fn.bufnr "#", vim.fn.win_getid()
  local project, syntax = vim.b.vimtex or {}, vim.b.vimtex_syntax or {}
  if toc.split_pos == "full" then
    vim.cmd("edit " .. vim.fn.fnameescape(toc.name))
  else
    if toc.resize == 1 then
      vim.o.columns = vim.o.columns + toc.split_width
    end
    vim.cmd(
      ("%s %dnew %s"):format(
        toc.split_pos,
        toc.split_width,
        vim.fn.fnameescape(toc.name)
      )
    )
  end
  toc.bufnr_prev, toc.bufnr_alternate, toc.winid_prev =
    previous, alternate, window
  vim.b.toc, vim.b.vimtex, vim.b.vimtex_syntax = toc, project, syntax
  vim.bo.bufhidden, vim.bo.buftype, vim.bo.filetype =
    "wipe", "nofile", "vimtex-toc"
  vim.bo.buflisted, vim.bo.swapfile = false, false
  vim.wo.cursorline, vim.wo.wrap, vim.wo.winfixwidth, vim.wo.winfixheight =
    true, false, true, true
  if toc.hide_line_numbers == 1 then
    vim.wo.number, vim.wo.relativenumber = false, false
  end
  M.refresh(toc)
  local maps = {
    q = function()
      M.close(toc)
    end,
    ["<esc>"] = function()
      M.close(toc)
    end,
    ["<space>"] = function()
      activate_current(false, toc)
    end,
    ["<cr>"] = function()
      activate_current(true, toc)
    end,
    r = function()
      M.get_entries(true, toc)
    end,
    s = function()
      toc.show_numbers = toc.show_numbers == 1 and 0 or 1
      M.refresh(toc)
    end,
    ["-"] = function()
      toc.tocdepth = math.max(toc.tocdepth - 1, -2)
      M.refresh(toc)
    end,
    ["+"] = function()
      toc.tocdepth = math.min(toc.tocdepth + 1, 5)
      M.refresh(toc)
    end,
  }
  for lhs, callback in pairs(maps) do
    vim.keymap.set(
      "n",
      lhs,
      callback,
      { buffer = true, silent = true, nowait = true }
    )
  end
  vim.api.nvim_buf_create_user_command(0, "VimtexTocToggle", function()
    M.close(toc)
  end, {})
  vim.api.nvim_exec_autocmds(
    "User",
    { pattern = "VimtexEventTocCreated", modeline = false }
  )
end

function M.open()
  local toc = state()
  if M.is_open(toc) then
    return
  end
  if toc.layers then
    for key in pairs(toc.layer_status) do
      toc.layer_status[key] = vim.tbl_contains(toc.layers, key) and 1 or 0
    end
  end
  toc.calling_file, toc.calling_line = vim.fn.expand "%:p", vim.fn.line "."
  M.get_entries(false, toc)
  if toc.mode > 1 then
    local list = {}
    for _, entry in ipairs(toc.entries) do
      if entry.active then
        table.insert(
          list,
          { lnum = entry.line, filename = entry.file, text = entry.title }
        )
      end
    end
    vim.fn.setloclist(0, list)
    pcall(vim.fn.setloclist, 0, {}, "r", { title = toc.name })
    if toc.mode == 4 then
      vim.cmd "lopen"
    end
  end
  if toc.mode < 3 then
    create(toc)
  end
end

function M.toggle()
  local toc = state()
  if M.is_open(toc) then
    M.close(toc)
  else
    M.open()
  end
end

function M.init_buffer()
  if vim.g.vimtex_toc_enabled == 0 then
    return
  end
  vim.api.nvim_buf_create_user_command(0, "VimtexTocOpen", M.open, {})
  vim.api.nvim_buf_create_user_command(0, "VimtexTocToggle", M.toggle, {})
  vim.keymap.set("n", "<plug>(vimtex-toc-open)", M.open, { buffer = true })
  vim.keymap.set("n", "<plug>(vimtex-toc-toggle)", M.toggle, { buffer = true })
end

return M
