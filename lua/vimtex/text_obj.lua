local M = {}
local pos = require "vimtex.pos"

local section_search = [[\v%(%(\\@<!%(\\\\)*)@<=\%.*)@<!\s*\\\zs(]]
  .. table.concat({
    [[%(sub)?paragraph>]],
    [[%(sub)*section>]],
    [[chapter>]],
    [[part>]],
    [[appendix>]],
    [[%(front|back|main)matter>]],
    [[add%(sec|chap|part)>]],
    [[%(begin|end)\{\zsdocument\ze\}]],
  }, "|")
  .. [[)|^\s*\% [fF]ake\zs(part|chapter|%(sub)*section)]]

local section_value = {
  document = 0,
  frontmatter = 1,
  mainmatter = 1,
  appendix = 1,
  backmatter = 1,
  part = 1,
  addpart = 1,
  chapter = 2,
  addchap = 2,
  section = 3,
  addsec = 3,
  subsection = 4,
  subsubsection = 5,
  paragraph = 6,
  subparagraph = 7,
}

local function normal(keys)
  vim.cmd("normal! " .. keys)
end

local function update_visual_marks()
  local first, last = vim.fn.getpos "v", vim.fn.getcurpos()
  if first[2] > last[2] or (first[2] == last[2] and first[3] > last[3]) then
    first, last = last, first
  end
  vim.fn.setpos("'<", first)
  vim.fn.setpos("'>", last)
end

function M.init_buffer()
  if vim.g.vimtex_text_obj_enabled == 0 then
    return
  end
  for _, spec in ipairs {
    { "c", "commands" },
    { "d", "delimited", "delims" },
    { "e", "delimited", "normal" },
    { "$", "delimited", "math" },
    { "P", "sections" },
    { "m", "items" },
  } do
    for _, inner in ipairs { true, false } do
      local lhs = "<plug>(vimtex-" .. (inner and "i" or "a") .. spec[1] .. ")"
      vim.keymap.set("x", lhs, function()
        update_visual_marks()
        vim.cmd "normal! \27"
        M[spec[2]](inner, true, spec[3])
      end, { buffer = true, silent = true })
      vim.keymap.set("o", lhs, function()
        M[spec[2]](inner, false, spec[3])
      end, { buffer = true, silent = true })
    end
  end
end

function M.commands(inner, visual)
  local object, previous = {}, {}
  local saved = pos.get_cursor()
  if visual then
    pos.set_cursor(vim.fn.getpos "'>")
  end
  for _ = 1, vim.v.count1 do
    if not vim.tbl_isempty(object) then
      pos.set_cursor(pos.prev(object.cmd_start))
    end
    previous, object = object, {}
    local command = require("vimtex.cmd").get_current()
    if vim.tbl_isempty(command) then
      break
    end
    local first = { unpack(command.pos_start) }
    local last = { unpack(command.pos_end) }
    if inner then
      last.lnum = first.lnum
      last.cnum = first.cnum + #command.name - 1
      first.cnum = first.cnum + 1
    end
    if
      visual
      and pos.equal(first, vim.fn.getpos "'<")
      and pos.equal(last, vim.fn.getpos "'>")
    then
      local old = command.pos_start
      pos.set_cursor(pos.prev(old))
      command = require("vimtex.cmd").get_current()
      if vim.tbl_isempty(command) then
        break
      end
      if pos.smaller(old, command.pos_end) then
        first, last = { unpack(command.pos_start) }, { unpack(command.pos_end) }
        if inner then
          last.lnum = first.lnum
          last.cnum = first.cnum + #command.name - 1
          first.cnum = first.cnum + 1
        end
      end
    end
    object =
      { pos_start = first, pos_end = last, cmd_start = command.pos_start }
  end
  if vim.tbl_isempty(object) then
    if
      vim.tbl_isempty(previous) or vim.g.vimtex_text_obj_variant == "targets"
    then
      if visual then
        normal "gv"
      else
        pos.set_cursor(saved)
      end
      return
    end
    object = previous
  end
  pos.set_cursor(object.pos_start)
  normal "v"
  pos.set_cursor(object.pos_end)
end

local function surrounding_or_next(kind)
  if kind == "delims" then
    return unpack(require("vimtex.delim").get_surrounding_or_next "delim_all")
  end
  return unpack(require("vimtex.env").get_surrounding_or_next(kind))
end

local function surrounding(kind)
  if kind == "delims" then
    return unpack(require("vimtex.delim").get_surrounding "delim_all")
  end
  return unpack(require("vimtex.env").get_surrounding(kind))
end

local function selection_delimited(opening, closing, inner)
  local linewise =
    vim.tbl_contains(vim.g.vimtex_text_obj_linewise_operators, vim.v.operator)
  local l1, c1, l2, c2 = opening.lnum, opening.cnum, closing.lnum, closing.cnum
  local inline
  if inner then
    if opening.env_cmd and not vim.tbl_isempty(opening.env_cmd) then
      l1, c1 = opening.env_cmd.pos_end.lnum, opening.env_cmd.pos_end.cnum + 1
    else
      c1 = c1 + #opening.match
    end
    c2 = c2 - 1
    inline = l2 - l1 > 1
      and vim.fn.match(vim.fn.strpart(vim.fn.getline(l1), c1), [[^\s*$]]) >= 0
      and vim.fn.match(vim.fn.strpart(vim.fn.getline(l2), 0, c2), [[^\s*$]])
        >= 0
    if inline then
      l1 = l1 + 1
      c1 = #vim.fn.matchstr(vim.fn.getline(l1), [[^\s*]]) + 1
      l2 = l2 - 1
      c2 = #vim.fn.getline(l2)
      if c2 == 0 and not linewise then
        l2, c2 = l2 - 1, #vim.fn.getline(l2 - 1) + 1
      end
    elseif c2 == 0 then
      l2, c2 = l2 - 1, #vim.fn.getline(l2 - 1) + 1
    end
  else
    c2 = c2 + #closing.match - 1
    inline = l2 - l1 > 1
      and vim.fn.match(vim.fn.strpart(vim.fn.getline(l1), 0, c1 - 1), [[^\s*$]]) >= 0
      and vim.fn.match(vim.fn.strpart(vim.fn.getline(l2), 0, c2), [[^\s*$]])
        >= 0
  end
  return {
    open = opening,
    close = closing,
    pos_start = { l1, c1 },
    pos_end = { l2, c2 },
    is_inline = inline,
    select_mode = inline and linewise and "V"
      or (vim.v.operator == ":" and vim.fn.visualmode() or "v"),
  }
end

local function same_selection(object)
  if object.select_mode == "v" then
    return vim.deep_equal(
      { unpack(vim.fn.getpos "'<", 2, 3) },
      object.pos_start
    ) and vim.deep_equal(
      { unpack(vim.fn.getpos "'>", 2, 3) },
      object.pos_end
    )
  end
  return object.select_mode == "V"
    and vim.fn.getpos("'<")[2] == object.pos_start[1]
    and vim.fn.getpos("'>")[2] == object.pos_end[1]
end

local function visual_delimited(inner, kind, start)
  if inner then
    pos.set_cursor(pos.next(start))
    local opening, closing = surrounding(kind)
    if opening and not vim.tbl_isempty(opening) then
      local object = selection_delimited(opening, closing, true)
      if same_selection(object) then
        pos.set_cursor(pos.prev(opening.lnum, opening.cnum))
        opening, closing = surrounding(kind)
        if not opening or vim.tbl_isempty(opening) then
          return {}
        end
        return selection_delimited(opening, closing, true)
      end
    end
  end
  pos.set_cursor(start)
  local opening, closing = surrounding_or_next(kind)
  if not opening or vim.tbl_isempty(opening) then
    return {}
  end
  local object = selection_delimited(opening, closing, inner)
  if inner then
    return object
  end
  if same_selection(object) then
    pos.set_cursor(pos.prev(opening.lnum, opening.cnum))
    opening, closing = surrounding(kind)
    if not opening or vim.tbl_isempty(opening) then
      return {}
    end
    return selection_delimited(opening, closing, false)
  end
  return object
end

function M.delimited(inner, visual, kind)
  local object, previous = {}, {}
  local saved, start = pos.get_cursor(), vim.fn.getpos "'>"
  local count = kind == "math" and 1 or vim.v.count1
  for _ = 1, count do
    if not vim.tbl_isempty(object) then
      local next_pos = pos.prev(inner and object.open or object.pos_start)
      if visual then
        start = next_pos
      else
        pos.set_cursor(next_pos)
      end
    end
    if visual then
      object = visual_delimited(inner, kind, start)
    else
      local opening, closing = surrounding_or_next(kind)
      object = not opening
        or vim.tbl_isempty(opening) and {}
        or selection_delimited(opening, closing, inner)
    end
    if vim.tbl_isempty(object) then
      if
        not vim.tbl_isempty(previous)
        and vim.g.vimtex_text_obj_variant ~= "targets"
      then
        object = previous
        break
      end
      if visual then
        normal "gv"
      else
        pos.set_cursor(saved)
      end
      return
    end
    previous = object
  end
  if pos.smaller(object.pos_end, object.pos_start) then
    if vim.v.operator == "y" and not visual then
      return
    end
    if vim.v.operator == "c" or vim.v.operator == "d" then
      pos.set_cursor(object.pos_start)
      normal "ix"
    end
    object.pos_end = object.pos_start
  end
  normal(object.select_mode)
  pos.set_cursor(object.pos_start)
  normal "o"
  pos.set_cursor(object.pos_end)
  if vim.o.selection == "exclusive" then
    normal "l"
  end
end

local function section_selection(inner, previous_type)
  local saved = pos.get_cursor()
  local minimum = section_value[previous_type]
  local first, section_type, value
  while true do
    first = vim.fn.searchpos(section_search, "bcnW")
    if first[1] == 0 then
      return {}, {}, ""
    end
    section_type = vim.fn.matchstr(vim.fn.getline(first[1]), section_search)
    value = section_value[section_type]
    if previous_type ~= "" then
      if value >= minimum then
        pos.set_cursor(pos.prev(first))
      else
        pos.set_cursor(saved)
        break
      end
    else
      break
    end
  end
  local last
  while true do
    last = vim.fn.searchpos(section_search, "nW")
    if last[1] == 0 then
      last = { vim.fn.line "$" + 1, 1 }
      break
    end
    local current =
      section_value[vim.fn.matchstr(vim.fn.getline(last[1]), section_search)]
    if current <= value then
      last[1] = last[1] - 1
      break
    end
    pos.set_cursor(last)
  end
  if inner then
    pos.set_cursor(first[1] + 1, first[2])
    first = vim.fn.searchpos([[\S]], "cnW")
    pos.set_cursor(last)
    last = vim.fn.searchpos([[\S]], "bcnW")
  elseif value == 0 then
    first = { first[1] + 1, first[2] }
  end
  return first, last, section_type
end

function M.sections(inner, visual)
  local saved = pos.get_cursor()
  pos.set_cursor(pos.next(saved))
  local first, last, kind = section_selection(inner, "")
  if #first == 0 then
    pos.set_cursor(saved)
    return
  end
  if
    visual
    and vim.fn.visualmode() == "V"
    and vim.fn.getpos("'<")[2] == first[1]
    and vim.fn.getpos("'>")[2] == last[1]
  then
    local f, l, k = section_selection(inner, kind)
    if #f > 0 then
      first, last, kind = f, l, k
    end
  end
  for _ = 2, vim.v.count1 do
    local f, l, k = section_selection(inner, kind)
    if #f == 0 then
      break
    end
    first, last, kind = f, l, k
  end
  pos.set_cursor(first)
  normal "V"
  pos.set_cursor(last)
end

local function item_selection(inner)
  local cursor = pos.get_cursor()
  local cursor_value = pos.val(cursor)
  local depth, current, first = 0, pos.next(cursor), nil
  while true do
    pos.set_cursor(pos.prev(current))
    if depth > 5 then
      return {}, {}
    end
    first = vim.fn.searchpos(
      depth > 0 and [[\\begin{\w\+}]] or [[^\s*\\item\S*]],
      "bcnW"
    )
    local first_value = pos.val(first)
    if first_value == 0 then
      return {}, {}
    end
    local ending = vim.fn.searchpos([[\%(^\s*\)\?\\end{\w\+}]], "bcnW")
    local ending_value = pos.val(ending)
    if ending_value == 0 or first_value > ending_value then
      if depth == 0 then
        break
      end
      current, depth = first, depth - 1
    else
      current, depth = ending, depth + 1
    end
  end
  depth, current = 0, first
  local last
  while true do
    pos.set_cursor(pos.next(current))
    local re = depth > 0 and [[\\end{\w\+}]]
      or [[\n\s*\%(\\item\|\\end{\(itemize\|enumerate\)}\)]]
    last = vim.fn.searchpos(re, "nW")
    local last_value = pos.val(last)
    if depth == 0 and last_value == 0 then
      return {}, {}
    end
    local beginning = vim.fn.searchpos([[\\begin{\w\+}]], "cnW")
    local beginning_value = pos.val(beginning)
    if beginning_value == 0 or last_value < beginning_value then
      if depth == 0 then
        break
      end
      current, depth = last, depth - 1
    else
      current, depth = beginning, depth + 1
    end
  end
  if cursor_value > pos.val(last) then
    return {}, {}
  end
  if inner then
    first[2] = vim.fn.searchpos([[^\s*\\item\S*\s]], "cne")[2] + 1
    last[2] = vim.fn.col { last[1], "$" } - 1
  end
  return first, last
end

function M.items(inner)
  local saved = pos.get_cursor()
  local first, last = item_selection(inner)
  if #first == 0 then
    pos.set_cursor(saved)
    return
  end
  if inner then
    normal(vim.v.operator == ":" and vim.fn.visualmode() or "v")
  else
    normal "V"
  end
  pos.set_cursor(first)
  normal "o"
  pos.set_cursor(last)
end

return M
