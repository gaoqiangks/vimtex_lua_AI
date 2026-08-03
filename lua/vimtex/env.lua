local M = {}
local pos = require "vimtex.pos"
local math_environments = {
  "align",
  "alignat",
  "displaymath",
  "eqnarray",
  "equation",
  "flalign",
  "gather",
  "math",
  "mathpar",
  "multline",
  "xalignat",
  "xxalignat",
}
local completion_environment
local repeat_action
local repeat_tick
local math_punctuation = {
  ",",
  ".",
  ";",
  ":",
  "?",
  "!",
  "，",
  "。",
  "；",
  "：",
  "？",
  "！",
  "、",
  "…",
}

---Transform an environment name entered through cse/cs$.
---@param name string
---@return string
function M.apply_change_hook(name)
  local hook = M.change_hook or vim.g.vimtex_env_change_hook
  if hook == nil or hook == "" then
    return name
  end

  local ok, transformed
  if type(hook) == "function" then
    ok, transformed = pcall(hook, name)
  else
    ok, transformed = pcall(vim.fn.call, hook, { name })
  end
  if not ok then
    require("vimtex.log").warning(
      "Environment change hook failed; using the entered name",
      tostring(transformed)
    )
    return name
  end
  return type(transformed) == "string" and transformed ~= "" and transformed
    or name
end

function M.get_surrounding(kind)
  if kind == "normal" then
    return require("vimtex.delim").get_surrounding "env_tex"
  end
  if kind ~= "math" then
    require("vimtex.log").error "Wrong argument!"
    return { {}, {} }
  end
  local pair = require("vimtex.delim").get_surrounding "env_math"
  if not vim.tbl_isempty(pair[1]) then
    return pair
  end
  return require("vimtex.delim").get_surrounding(
    "env_tex",
    { whitelist = math_environments }
  )
end

function M.get_surrounding_or_next(kind)
  if kind == "normal" then
    return require("vimtex.delim").get_surrounding_or_next "env_tex"
  end
  if kind ~= "math" then
    require("vimtex.log").error "Wrong argument!"
    return { {}, {} }
  end
  local cursor = pos.val(pos.get_cursor())
  local special = require("vimtex.delim").get_surrounding_or_next "env_math"
  local special_value = vim.tbl_isempty(special[1]) and 500 * cursor
    or pos.val(special[1])
  if special_value <= cursor then
    return special
  end
  local environment = require("vimtex.delim").get_surrounding_or_next(
    "env_tex",
    { whitelist = math_environments }
  )
  if vim.tbl_isempty(environment[1]) then
    return special
  end
  local environment_value = pos.val(environment[1])
  return (environment_value <= cursor or environment_value < special_value)
      and environment
    or special
end

function M.get_inner()
  local pair = M.get_surrounding "normal"
  return vim.tbl_isempty(pair[1])
    or pair[1].name == "document" and {}
    or { name = pair[1].name, open = pair[1], close = pair[2] }
end

local function walk(all)
  local saved, result = pos.get_cursor(), all and {} or nil
  while true do
    local environment = M.get_inner()
    if vim.tbl_isempty(environment) then
      pos.set_cursor(saved)
      return result or {}
    end
    if all then
      table.insert(result, environment)
    else
      result = environment
    end
    pos.set_cursor(pos.prev(environment.open))
  end
end
function M.get_outer()
  return walk(false)
end
function M.get_all()
  return walk(true)
end

local function split_line(delimiter)
  local line = vim.fn.getline(delimiter.lnum)
  return line:sub(1, delimiter.cnum - 1),
    line:sub(delimiter.cnum + #delimiter.match)
end

---Remove sentence punctuation immediately following a math delimiter.
---@param text string
---@return string punctuation
---@return string remainder
local function take_leading_math_punctuation(text)
  local index = (text:find "[^ \t]" or (#text + 1))
  local first = index
  while index <= #text do
    local found
    for _, punctuation in ipairs(math_punctuation) do
      if text:sub(index, index + #punctuation - 1) == punctuation then
        found = punctuation
        break
      end
    end
    if not found then
      break
    end
    index = index + #found
  end
  if index == first then
    return "", text
  end
  return text:sub(first, index - 1), text:sub(index):gsub("^[ \t]*", "")
end

function M.change_in_place(opening, closing, replacement)
  local before, after = split_line(closing)
  vim.fn.setline(closing.lnum, before .. replacement[2] .. after)
  before, after = split_line(opening)
  vim.fn.setline(opening.lnum, before .. replacement[1] .. after)
  if opening.lnum == closing.lnum then
    local cursor = pos.get_cursor()
    if cursor[3] > opening.cnum + #opening.match - 1 then
      cursor[3] = cursor[3] + #replacement[1] - #opening.match
      pos.set_cursor(cursor)
    end
  end
end

function M.change_to_inline_math(opening, closing, replacement)
  local before, after = split_line(closing)
  local punctuation
  punctuation, after = take_leading_math_punctuation(after)
  local close = punctuation .. replacement[2]
  if (before .. after):match "^%s*$" then
    vim.fn.setline(
      closing.lnum - 1,
      (vim.fn.getline(closing.lnum - 1):gsub("%s*$", close))
    )
    vim.cmd(closing.lnum .. "delete _")
    local nextline = vim.trim(vim.fn.getline(closing.lnum))
    if nextline ~= "" and not nextline:match "^\\end{" then
      vim.cmd((closing.lnum - 1) .. "join")
    end
  elseif before:match "^%s*$" then
    vim.fn.setline(
      closing.lnum - 1,
      vim.fn.getline(closing.lnum - 1):gsub("%s*$", close)
        .. after:gsub("^%s*", " ")
    )
    vim.cmd(closing.lnum .. "delete _")
  else
    vim.fn.setline(closing.lnum, before:gsub("%s*$", close) .. after)
  end
  before, after = split_line(opening)
  if (before .. after):match "^%s*$" then
    vim.cmd(opening.lnum .. "delete _")
    after = vim.fn.getline(opening.lnum):gsub("^%s*", replacement[1])
    local previous = vim.fn.getline(opening.lnum - 1)
    if previous:match "^%s*$" then
      vim.fn.setline(opening.lnum, before:match "^%s*" .. after)
      pos.set_cursor { opening.lnum, opening.cnum }
    else
      before = previous:gsub("%s*$", " ")
      vim.fn.setline(opening.lnum - 1, before .. after)
      vim.cmd(opening.lnum .. "delete _")
      pos.set_cursor { opening.lnum - 1, #before + 1 }
    end
  elseif after:match "^%s*$" then
    vim.fn.setline(
      opening.lnum,
      before .. vim.fn.getline(opening.lnum + 1):gsub("^%s*", replacement[1])
    )
    vim.cmd((opening.lnum + 1) .. "delete _")
    pos.set_cursor { opening.lnum, opening.cnum }
  else
    vim.fn.setline(opening.lnum, before .. after:gsub("^%s*", replacement[1]))
    pos.set_cursor { opening.lnum, opening.cnum }
  end
end

function M.change_to_indented(opening, closing, replacement)
  local cursor, lines = pos.get_cursor(), closing.lnum - opening.lnum + 2
  local old_indent
  if cursor[2] == opening.lnum then
    cursor[3] = cursor[3]
      - opening.cnum
      + vim.fn.indent(opening.lnum)
      + vim.bo.shiftwidth
  else
    old_indent = vim.fn.indent(cursor[2])
  end
  local before, after = split_line(closing)
  local punctuation
  punctuation, after = take_leading_math_punctuation(after)
  before, after = before:gsub("%s*$", ""), after:gsub("^%s*", "")
  if before ~= "" then
    vim.fn.setline(closing.lnum, before .. punctuation)
    vim.fn.append(closing.lnum, replacement[2])
  else
    if punctuation ~= "" then
      vim.fn.setline(
        closing.lnum - 1,
        vim.fn.getline(closing.lnum - 1):gsub("%s*$", punctuation)
      )
    end
    vim.fn.setline(closing.lnum, replacement[2])
  end
  if after ~= "" then
    vim.fn.append(closing.lnum + (before ~= "" and 1 or 0), after)
    lines = lines + 1
  end
  before, after = split_line(opening)
  before, after = before:gsub("%s*$", ""), after:gsub("^%s*", "")
  if before ~= "" then
    vim.fn.setline(opening.lnum, before)
    vim.fn.append(opening.lnum, replacement[1])
    pos.set_cursor(opening.lnum + 1, 1)
    cursor[2] = cursor[2] + 1
  else
    vim.fn.setline(opening.lnum, replacement[1])
    pos.set_cursor(opening.lnum, 1)
  end
  if after ~= "" then
    vim.fn.append(opening.lnum + (before ~= "" and 1 or 0), after)
    cursor[2] = cursor[2] + 1
  end
  vim.cmd(("silent normal! =%dj"):format(lines))
  if old_indent then
    cursor[3] = cursor[3] - old_indent + vim.fn.indent(cursor[2])
  end
  pos.set_cursor(cursor)
end

function M.change(opening, closing, name)
  local pairs = {
    ["$"] = { "$", "$" },
    ["\\("] = { "\\(", "\\)" },
    ["$$"] = { "$$", "$$" },
    ["\\["] = { "\\[", "\\]" },
  }
  local replacement = pairs[name]
    or { "\\begin{" .. name .. "}", "\\end{" .. name .. "}" }
  if name == "$" then
    return M.change_to_inline_math(opening, closing, replacement)
  end
  local inline = opening.match == "$"
    or (
      opening.match == "\\("
      and not (
        vim.trim(vim.fn.getline(opening.lnum)) == "\\("
        and vim.trim(vim.fn.getline(closing.lnum)) == "\\)"
      )
    )
  if inline then
    return M.change_to_indented(opening, closing, replacement)
  end
  return M.change_in_place(opening, closing, replacement)
end
function M.change_surrounding(kind, name)
  local pair = M.get_surrounding(kind)
  if not vim.tbl_isempty(pair[1]) then
    return M.change(pair[1], pair[2], name)
  end
end

function M.surround(first, last, name)
  if first < 1 or last < first or name == "" then
    return
  end
  local cursor = pos.get_cursor()
  cursor[2] = cursor[2]
    + (cursor[2] > last and 1 or 0)
    + (cursor[2] >= first and 1 or 0)
  vim.fn.append(last, "\\end{" .. name .. "}")
  vim.fn.append(first - 1, "\\begin{" .. name .. "}")
  vim.cmd(("silent normal! %dG%d=="):format(first, last - first + 3))
  pos.set_cursor(cursor)
end

function M.surround_opfunc(kind)
  if kind == "operator" then
    vim.go.operatorfunc = "v:lua.require'vimtex.env'.surround_opfunc"
    return "g@"
  end
  local first, last
  if kind == "visual" then
    first, last = vim.fn.getpos("'<")[2], vim.fn.getpos("'>")[2]
  else
    first, last = vim.fn.getpos("'[")[2], vim.fn.getpos("']")[2]
  end
  M.surround(
    first,
    last,
    require("vimtex.ui").input { prompt = "Surround with environment: " } or ""
  )
  vim.cmd "normal! zv"
end

local function remove_delimiter(delimiter)
  local before, after = split_line(delimiter)
  if delimiter.side == "close" then
    before = before:gsub("%s+$", "")
    if before == "" then
      after = after:gsub("^%s+", "")
    end
  else
    after = after:gsub("^%s+", "")
    if after == "" then
      before = before:gsub("%s+$", "")
    end
  end
  vim.fn.setline(delimiter.lnum, before .. after)
end
function M.delete(kind)
  local pair = M.get_surrounding(kind)
  local opening, closing = pair[1], pair[2]
  if vim.tbl_isempty(opening) then
    return
  end
  if kind == "normal" then
    require("vimtex.cmd").delete_all(closing)
    require("vimtex.cmd").delete_all(opening)
  else
    remove_delimiter(closing)
    remove_delimiter(opening)
  end
  if vim.fn.getline(closing.lnum):match "^%s*$" then
    vim.cmd(closing.lnum .. "d _")
  end
  if vim.fn.getline(opening.lnum):match "^%s*$" then
    vim.cmd(opening.lnum .. "d _")
  end
end
function M.toggle()
  local pair = M.get_surrounding "normal"
  local target = not vim.tbl_isempty(pair[1])
    and (vim.g.vimtex_env_toggle_map or {})[pair[1].name]
  if target and target ~= "" then
    M.change(pair[1], pair[2], target)
  end
end
function M.toggle_star()
  local pair = M.get_surrounding "normal"
  local opening = pair[1]
  if not vim.tbl_isempty(opening) and opening.name ~= "document" then
    M.change(
      opening,
      pair[2],
      (opening.starred == true or opening.starred == 1) and opening.name
        or opening.name .. "*"
    )
  end
end
function M.toggle_math()
  local pair = M.get_surrounding "math"
  local opening = pair[1]
  if vim.tbl_isempty(opening) then
    return
  end
  local current = opening.name or opening.match
  local target = (vim.g.vimtex_env_toggle_math_map or {})[current] or "$"
  if
    (opening.starred == true or opening.starred == 1) and target:match "^%w+$"
  then
    target = target .. "*"
  end
  M.change(opening, pair[2], target)
end

function M.is_inside(environment)
  local start, finish =
    [[\\begin\s*{]] .. environment .. [[\*\?}]],
    [[\\end\s*{]] .. environment .. [[\*\?}]]
  local ok, result =
    pcall(vim.fn.searchpairpos, start, "", finish, "bnW", "", 0, 100)
  return ok and result
    or vim.fn.searchpairpos(
      start,
      "",
      finish,
      "bnW",
      "",
      math.max(vim.fn.line "." - 500, 1)
    )
end

function M.input_complete(lead)
  local result = {}
  if vim.startswith(completion_environment, lead) then
    result[#result + 1] = completion_environment
  end
  for _, item in
    ipairs(require("vimtex.complete").complete("env", "", "\\begin"))
  do
    local word = item.word
    if
      word ~= "document"
      and word ~= completion_environment
      and vim.startswith(word, lead)
    then
      result[#result + 1] = word
    end
  end
  if vim.startswith("\\[", lead) then
    result[#result + 1] = "\\["
  end
  return result
end

local function prompt(kind)
  local pair = M.get_surrounding(kind)
  if vim.tbl_isempty(pair[1]) then
    return
  end
  local name = pair[1].name or pair[1].match
  completion_environment = name
  local input = require("vimtex.ui").input {
    prompt = "Change surrounding environment: ",
    text = vim.g.vimtex_env_change_autofill == 1 and name or "",
    completion = "customlist,v:lua.require'vimtex.env'.input_complete",
  }
  return input and M.apply_change_hook(input) or input
end

function M.init_buffer()
  local actions = {
    ["<plug>(vimtex-env-change)"] = function()
      local name = prompt "normal"
      if name and name ~= "" then
        repeat_action = function()
          M.change_surrounding("normal", name)
        end
        repeat_action()
        repeat_tick = vim.b.changedtick
      end
    end,
    ["<plug>(vimtex-env-change-math)"] = function()
      local name = prompt "math"
      if name and name ~= "" then
        repeat_action = function()
          M.change_surrounding("math", name)
        end
        repeat_action()
        repeat_tick = vim.b.changedtick
      end
    end,
    ["<plug>(vimtex-env-delete)"] = function()
      M.delete "normal"
    end,
    ["<plug>(vimtex-env-delete-math)"] = function()
      M.delete "math"
    end,
    ["<plug>(vimtex-env-toggle)"] = M.toggle,
    ["<plug>(vimtex-env-toggle-star)"] = M.toggle_star,
    ["<plug>(vimtex-env-toggle-math)"] = M.toggle_math,
  }
  for lhs, callback in pairs(actions) do
    vim.keymap.set("n", lhs, callback, { buffer = true, silent = true })
  end
  vim.keymap.set("n", ".", function()
    if repeat_action and repeat_tick == vim.b.changedtick then
      repeat_action()
      repeat_tick = vim.b.changedtick
    else
      vim.cmd "normal! ."
    end
  end, { buffer = true, silent = true })
  vim.keymap.set("n", "<plug>(vimtex-env-surround-operator)", function()
    return M.surround_opfunc "operator"
  end, { buffer = true, expr = true, silent = true })
  vim.keymap.set(
    "n",
    "<plug>(vimtex-env-surround-line)",
    "<plug>(vimtex-env-surround-operator)_",
    { buffer = true, remap = true, silent = true }
  )
  vim.keymap.set("x", "<plug>(vimtex-env-surround-visual)", function()
    M.surround_opfunc "visual"
  end, { buffer = true, silent = true })
end

return M
