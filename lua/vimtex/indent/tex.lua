local syntax = require "vimtex.syntax"

local M = {}
local configs = {}

local function matches(line, pattern)
  return pattern ~= "" and vim.fn.match(line, pattern) >= 0
end

local function clean_line(line)
  local start = 1
  while true do
    local index = line:find("%", start, true)
    if not index then
      return line
    end
    if index == 1 or line:sub(index - 1, index - 1) ~= "\\" then
      return line:sub(1, index - 1):gsub("%s*$", "")
    end
    start = index + 1
  end
end

local function in_verbatim(line_number)
  local column = vim.fn.col { line_number, "$" } - 2
  local stack = syntax.stack(line_number, column)
  local zone, environment = false, false
  for _, group in ipairs(stack) do
    if
      group:match "^texLstZone"
      or group:match "^texVerbZone"
      or group:match "^texMarkdownZone"
      or group:match "^texMintedZone"
    then
      zone = true
    elseif group:match "^texEnv" or group:match "^texMintedEnv" then
      environment = true
    end
  end
  return zone and not environment
end

local function previous_line(line_number)
  local line = vim.fn.getline(line_number)
  while
    line_number > 0
    and (line:find "^%s*%%" ~= nil or in_verbatim(line_number))
  do
    line_number = vim.fn.prevnonblank(line_number - 1)
    line = vim.fn.getline(line_number)
  end
  return line_number, line_number > 0 and clean_line(line) or ""
end

local function count(line, pattern)
  if pattern == "" then
    return 0
  end
  local total, start = 0, 0
  while start <= #line do
    local found = vim.fn.matchstrpos(line, pattern, start)
    if found[2] < 0 then
      break
    end
    total = total + 1
    start = found[3] > found[2] and found[3] or found[3] + 1
  end
  return total
end

local function count_open(line, opening, closing)
  local found = vim.fn.matchstrpos(line, opening)
  if found[2] < 0 then
    return 0
  end
  local total, first = 0, found[2]
  while found[2] >= 0 do
    total = total + 1
    local start = found[3] > found[2] and found[3] or found[3] + 1
    found = vim.fn.matchstrpos(line, opening, start)
  end
  found = vim.fn.matchstrpos(line, closing, first)
  while found[2] >= 0 do
    total = total - 1
    local start = found[3] > found[2] and found[3] or found[3] + 1
    found = vim.fn.matchstrpos(line, closing, start)
  end
  return math.max(total, 0)
end

local function count_close(line, opening, closing)
  local found = vim.fn.matchstrpos(line, closing)
  if found[2] < 0 then
    return 0
  end
  local total, last = 0, found[2]
  while found[2] >= 0 do
    total, last = total + 1, found[2]
    local start = found[3] > found[2] and found[3] or found[3] + 1
    found = vim.fn.matchstrpos(line, closing, start)
  end
  found = vim.fn.matchstrpos(line, opening)
  while found[2] >= 0 and found[2] < last do
    total = total - 1
    local start = found[3] > found[2] and found[3] or found[3] + 1
    found = vim.fn.matchstrpos(line, opening, start)
  end
  return math.max(total, 0)
end

local function parse_amp_context(config, context, line_number)
  local depth = 1
  line_number = vim.fn.prevnonblank(line_number - 1)
  while line_number >= 1 do
    local line = vim.fn.getline(line_number)
    if matches(line, config.depth_end) then
      depth = depth + 1
    end
    if matches(line, config.depth_begin) then
      depth = depth - 1
      if depth == 0 then
        context.init_lnum, context.init_line = line_number, line
        context.init_ind = vim.fn.indent(line_number)
        break
      end
    end
    if depth == 1 and matches(line, config.amp) then
      if context.amp_ind < 0 then
        context.amp_ind = vim.fn.strdisplaywidth(
          vim.fn.strpart(line, 0, vim.fn.match(line, config.amp))
        )
      end
      if not matches(line, config.align) then
        context.init_lnum, context.init_line = line_number, line
        context.init_ind = vim.fn.indent(line_number)
        break
      end
    end
    line_number = vim.fn.prevnonblank(line_number - 1)
  end
end

local function indent_amps(config, line_number, line, previous_number, previous)
  local context = {
    finished = false,
    amp_ind = -1,
    init_ind = -1,
    prev_lnum = previous_number,
    prev_line = previous,
    prev_ind = previous_number > 0 and vim.fn.indent(previous_number) or 0,
  }
  if vim.g.vimtex_indent_on_ampersands == 0 then
    return context.prev_ind, context
  end
  if
    matches(line, config.align)
    or matches(line, config.amp)
    or matches(line, [[^\v\s*\\%(end|])]])
  then
    parse_amp_context(config, context, line_number)
  end
  if matches(line, config.align) then
    context.finished = true
    local difference = vim.fn.strdisplaywidth(
      vim.fn.strpart(line, 0, vim.fn.match(line, config.amp))
    ) - vim.fn.strdisplaywidth(
      vim.fn.strpart(line, 0, vim.fn.match(line, [[\S]]))
    )
    return context.amp_ind - difference, context
  end
  if
    context.amp_ind >= 0
    and (matches(line, [[^\v\s*\\%(end|])]]) or matches(line, config.amp))
  then
    context.prev_lnum, context.prev_line = context.init_lnum, context.init_line
    return context.init_ind, context
  end
  return context.prev_ind, context
end

local function indent_envs(config, line, previous)
  local indent = 0
  if
    matches(previous, config.env_begin)
    and not matches(previous, config.env_end)
    and not matches(previous, config.env_ignored)
  then
    indent = indent + config.sw
  end
  if
    not matches(line, config.env_begin)
    and matches(line, config.env_end)
    and not matches(line, config.env_ignored)
  then
    indent = indent - config.sw
  end
  return indent
end

local function indent_items(config, line, previous, previous_number)
  if config.lists_empty then
    return 0
  end
  if
    matches(previous, config.item)
    and (
      not matches(line, config.enditem)
      or (matches(line, config.item) and matches(previous, config.beglist))
    )
  then
    return config.sw
  end
  if
    matches(line, config.endlist) and not matches(previous, config.begitem)
  then
    return -config.sw
  end
  if matches(line, config.item) and not matches(previous, config.item) then
    while previous_number >= 1 do
      if matches(previous, config.begitem) then
        return -config.sw * (matches(previous, config.item) and 1 or 0)
      end
      previous_number = vim.fn.prevnonblank(previous_number - 1)
      previous = vim.fn.getline(previous_number)
    end
  end
  return 0
end

local function indent_delims(config, line, previous)
  if config.delim_trivial then
    return 0
  end
  if config.delim_options.close_indented == 1 then
    return config.sw
      * (count(previous, config.open) - count(previous, config.close))
  end
  return config.sw
    * (
      count_open(previous, config.open, config.close)
      - count_close(line, config.open, config.close)
    )
end

local function indent_conditionals(config, line, previous)
  local conditional = config.conditionals
  if vim.tbl_isempty(conditional) then
    return 0
  end
  local indent = 0
  if
    (
      matches(previous, conditional.open)
      or matches(previous, conditional["else"])
    ) and not matches(previous, conditional.close)
  then
    indent = indent + config.sw
  end
  if
    not matches(line, conditional.open)
    and (matches(line, conditional.close) or matches(line, conditional["else"]))
  then
    indent = indent - config.sw
  end
  return indent
end

local function indent_tikz(config, line_number, previous)
  local state = vim.b.vimtex
  if
    type(state) ~= "table"
    or type(state.packages) ~= "table"
    or not state.packages.tikz
  then
    return 0
  end
  local in_tikz = false
  for _, group in ipairs(syntax.stack(line_number, 1)) do
    if group:match "^texTikzZone" then
      in_tikz = true
      break
    end
  end
  if not in_tikz then
    return 0
  end
  local environment = vim.fn.search([[\\begin\s*{tikzpicture\*\?}]], "bn")
  if environment > 0 and environment < line_number then
    local starts, stops =
      matches(previous, config.tikz_commands), matches(previous, [[;\s*$]])
    if starts and not stops then
      return config.sw
    end
    if not starts and stops then
      local context = table.concat(vim.fn.getline(environment, line_number - 1))
      return -config.sw * (matches(context, config.tikz_commands) and 1 or 0)
    end
  end
  return 0
end

function M.indent(line_number)
  local config = configs[vim.api.nvim_get_current_buf()]
  if not config then
    return 0
  end
  config.sw = vim.fn.shiftwidth()
  local previous_number, previous =
    previous_line(vim.fn.prevnonblank(line_number - 1))
  if previous_number == 0 then
    return vim.fn.indent(line_number)
  end
  local line = vim.fn.getline(line_number)
  if in_verbatim(line_number) then
    return line == "" and vim.fn.indent(previous_number)
      or vim.fn.indent(line_number)
  end
  line = clean_line(line)

  local indent, amp =
    indent_amps(config, line_number, line, previous_number, previous)
  if amp.finished then
    return indent
  end
  previous_number, previous = amp.prev_lnum, amp.prev_line
  indent = indent + indent_envs(config, line, previous)
  indent = indent + indent_items(config, line, previous, previous_number)
  indent = indent + indent_delims(config, line, previous)
  indent = indent + indent_conditionals(config, line, previous)
  if vim.g.vimtex_indent_tikz_commands ~= 0 then
    indent = indent + indent_tikz(config, previous_number, previous)
  end
  return math.max(indent, 0)
end

function M.setup()
  if vim.b.did_indent then
    return
  end
  require("vimtex.options").init()
  if vim.g.vimtex_indent_enabled == 0 then
    return
  end
  vim.b.did_vimtex_indent, vim.b.did_indent = 1, 1
  vim.bo.autoindent = true
  vim.bo.indentexpr = "v:lua.vimtex_indent_tex_expr()"
  vim.bo.indentkeys =
    [[!^F,o,O,0(,0),],},\&,0=\\item ,0=\\item[,0=\\else,0=\\fi,0=\\rangle,0=\\rbrace,0=\\rvert,0=\\rVert,0=\\rfloor,0=\\rceil,0=\\urcorner]]

  local not_backslash = vim.g["vimtex#re#not_bslash"]
  local lists = table.concat(vim.g.vimtex_indent_lists, [[\|]])
  local delim_options = vim.tbl_deep_extend("force", {
    open = { "{" },
    close = { "}" },
    close_indented = 0,
    include_modified_math = 1,
  }, vim.g.vimtex_indent_delims)
  local opening, closing =
    table.concat(delim_options.open, [[\|]]),
    table.concat(delim_options.close, [[\|]])
  if delim_options.include_modified_math == 1 then
    local regex = require("vimtex.delim").re.delim_math_mod
    opening = opening .. (opening == "" and "" or [[\|]]) .. regex.open
    closing = closing .. (closing == "" and "" or [[\|]]) .. regex.close
  end
  configs[vim.api.nvim_get_current_buf()] = {
    sw = vim.fn.shiftwidth(),
    amp = not_backslash .. [[\&]],
    align = "^[ \\t\\\\]*" .. not_backslash .. [[\&]],
    depth_begin = not_backslash .. [=[\\%(begin\s*\{|[|\w+\{\s*$)]=],
    depth_end = not_backslash .. [=[\\end\s*\{\w+\*?}|^\s*%(}|\\])]=],
    env_begin = [=[\\begin{.*}\|\\\@<!\\\[]=],
    env_end = [=[\\end{.*}\|\\\]]=],
    env_ignored = [[\v<%(]]
      .. table.concat(vim.g.vimtex_indent_ignored_envs, "|")
      .. ")>",
    lists_empty = #vim.g.vimtex_indent_lists == 0,
    item = [[^\s*\\item\>]],
    beglist = [[\\begin{\%(]] .. lists .. [[\)]],
    endlist = [[\\end{\%(]] .. lists .. [[\)]],
    delim_options = delim_options,
    open = opening,
    close = closing,
    delim_trivial = opening == "" or closing == "",
    conditionals = vim.g.vimtex_indent_conditionals,
    tikz_commands = [[\v\\%(draw|fill|path|node|coordinate|clip|add%(legendentry|plot))]],
  }
  local config = configs[vim.api.nvim_get_current_buf()]
  config.begitem = config.item .. [[\|]] .. config.beglist
  config.enditem = config.item .. [[\|]] .. config.endlist
end

_G.vimtex_indent_tex = M.indent
_G.vimtex_indent_tex_expr = function()
  return M.indent(vim.v.lnum)
end

return M
