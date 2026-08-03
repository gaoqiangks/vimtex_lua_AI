local M = {}

local function copy_list(list)
  return { unpack(list or {}) }
end

local function generated_regex(list)
  local opening, closing = {}, {}
  for _, pair in ipairs(list.re) do
    table.insert(opening, pair[1])
    table.insert(closing, pair[2])
  end
  opening, closing =
    table.concat(opening, [[\|]]), table.concat(closing, [[\|]])
  return {
    open = [[\\\@<!\%(]] .. opening .. [[\)]],
    close = [[\\\@<!\%(]] .. closing .. [[\)]],
    both = [[\\\@<!\%(]] .. opening .. [[\|]] .. closing .. [[\)]],
  }
end

local function initialize()
  local lists = {
    env_tex = {
      name = { { "begin", "end" } },
      re = { { [[\\begin\s*{[^}]*}]], [[\\end\s*{[^}]*}]] } },
    },
    env_math = {
      name = {
        { [[\(]], [[\)]] },
        { "\\[", "\\]" },
        { "$$", "$$" },
        { "$", "$" },
      },
      re = {
        { [[\\(]], [[\\)]] },
        { "\\\\\\@<!\\\\\\[", "\\\\\\]" },
        { [[\$\$]], [[\$\$]] },
        { [[\$]], [[\$]] },
      },
    },
    delim_tex = {
      name = { { "[", "]" }, { "{", "}" } },
      re = { { "\\[", "\\]" }, { [[\\\@<!{]], [[\\\@<!}]] } },
    },
    delim_math = {
      name = {
        { "(", ")" },
        { "[", "]" },
        { [[\{]], [[\}]] },
        { [[\langle]], [[\rangle]] },
        { [[\lbrace]], [[\rbrace]] },
        { [[\lvert]], [[\rvert]] },
        { [[\lVert]], [[\rVert]] },
        { [[\lfloor]], [[\rfloor]] },
        { [[\lceil]], [[\rceil]] },
        { [[\ulcorner]], [[\urcorner]] },
      },
    },
    mods = {
      name = {
        { [[\left]], [[\right]] },
        { [[\bigl]], [[\bigr]] },
        { [[\Bigl]], [[\Bigr]] },
        { [[\biggl]], [[\biggr]] },
        { [[\Biggl]], [[\Biggr]] },
        { [[\big]], [[\big]] },
        { [[\Big]], [[\Big]] },
        { [[\bigg]], [[\bigg]] },
        { [[\Bigg]], [[\Bigg]] },
      },
      re = {
        { [[\\left]], [[\\right]] },
        { [[\\bigl]], [[\\bigr]] },
        { [[\\Bigl]], [[\\Bigr]] },
        { [[\\biggl]], [[\\biggr]] },
        { [[\\Biggl]], [[\\Biggr]] },
        { [[\\big\>]], [[\\big\>]] },
        { [[\\Big\>]], [[\\Big\>]] },
        { [[\\bigg\>]], [[\\bigg\>]] },
        { [[\\Bigg\>]], [[\\Bigg\>]] },
      },
    },
  }
  lists = vim.tbl_extend("force", lists, vim.g.vimtex_delim_list or {})
  for _, list in pairs(lists) do
    if not list.re and list.name then
      list.re = vim.tbl_map(function(pair)
        return vim.tbl_map(function(value)
          return vim.fn.escape(value, "\\$[]")
        end, pair)
      end, list.name)
    end
  end
  for _, key in ipairs { "name", "re" } do
    lists.env_all = lists.env_all or {}
    lists.delim_all = lists.delim_all or {}
    lists.all = lists.all or {}
    lists.env_all[key] =
      vim.list_extend(copy_list(lists.env_tex[key]), lists.env_math[key])
    lists.delim_all[key] =
      vim.list_extend(copy_list(lists.delim_math[key]), lists.delim_tex[key])
    lists.all[key] =
      vim.list_extend(copy_list(lists.env_all[key]), lists.delim_all[key])
  end

  local re = { env_all = {}, delim_all = {}, all = {} }
  for _, key in ipairs {
    "env_tex",
    "env_math",
    "delim_tex",
    "delim_math",
    "mods",
  } do
    re[key] = generated_regex(lists[key])
  end
  local opening, closing = {}, {}
  for _, pair in ipairs(lists.delim_math.re) do
    table.insert(opening, pair[1])
    table.insert(closing, pair[2])
  end
  opening, closing =
    table.concat(opening, [[\|]]), table.concat(closing, [[\|]])
  re.delim_math_mod = {
    open = [[\%(\%(]]
      .. re.mods.open
      .. [[\)\)\s*\\\@<!\%(]]
      .. opening
      .. [[\)\|\\left\s*\.]],
    close = [[\%(\%(]]
      .. re.mods.close
      .. [[\)\)\s*\\\@<!\%(]]
      .. closing
      .. [[\)\|\\right\s*\.]],
    both = [[\%(\%(]]
      .. re.mods.both
      .. [[\)\)\s*\\\@<!\%(]]
      .. opening
      .. [[\|]]
      .. closing
      .. [[\)\|\\\%(left\|right\)\s*\.]],
  }
  re.delim_math_modq = {
    open = [[\%(\%(]]
      .. re.mods.open
      .. [[\)\s*\)\?\\\@<!\%(]]
      .. opening
      .. [[\)\|\\left\s*\.]],
    close = [[\%(\%(]]
      .. re.mods.close
      .. [[\)\s*\)\?\\\@<!\%(]]
      .. closing
      .. [[\)\|\\right\s*\.]],
    both = [[\%(\%(]]
      .. re.mods.both
      .. [[\)\s*\)\?\\\@<!\%(]]
      .. opening
      .. [[\|]]
      .. closing
      .. [[\)\|\\\%(left\|right\)\s*\.]],
  }
  for _, side in ipairs { "open", "close", "both" } do
    re.env_all[side] = re.env_tex[side] .. [[\|]] .. re.env_math[side]
    re.delim_all[side] = re.delim_math_modq[side]
      .. [[\|]]
      .. re.delim_tex[side]
    re.all[side] = re.env_all[side] .. [[\|]] .. re.delim_all[side]
  end
  for _, group in pairs(re) do
    for _, side in ipairs { "open", "close", "both" } do
      group[side] = [[\m]] .. group[side]
    end
  end

  -- These lookups sit on hot paths for motions, text objects, and delimiter
  -- toggling. Build them once instead of scanning the configured lists for
  -- every delimiter encountered.
  local lookup = {}
  for kind, list in pairs(lists) do
    if list.name and list.re then
      local item = { corr = {}, re = { {}, {} } }
      for index, pair in ipairs(list.name) do
        if item.corr[pair[1]] == nil then
          item.corr[pair[1]] = pair[2]
        end
        if item.corr[pair[2]] == nil then
          item.corr[pair[2]] = pair[1]
        end
        item.re[1][pair[1]] = list.re[index][1]
        item.re[2][pair[2]] = list.re[index][2]
      end
      lookup[kind] = item
    end
  end

  M.lists, M.re, M.lookup = lists, re, lookup
  vim.g["vimtex#delim#lists"], vim.g["vimtex#delim#re"] = lists, re
end

initialize()

local pos = require "vimtex.pos"
local function timeout()
  local mode = vim.v.insertmode ~= "" and vim.v.insertmode or vim.fn.mode()
  return mode == "i" and vim.g.vimtex_delim_insert_timeout
    or vim.g.vimtex_delim_timeout
end

local function re_for(delimiter, side, kind)
  kind = kind or "delim_all"
  if delimiter == "." then
    return M.re.delim_math[side == 1 and "open" or "close"]
  end
  local lookup = M.lookup[kind]
  return lookup and lookup.re[side + 1][delimiter] or ""
end

local function corresponding(delimiter, kind)
  local lookup = M.lookup[kind or "delim_all"]
  return lookup and lookup.corr[delimiter]
end

local function bounds(is_open)
  return is_open and "nW" or "bnW",
    is_open and (vim.fn.line "." + vim.g.vimtex_delim_stopline) or math.max(
      1,
      vim.fn.line "." - vim.g.vimtex_delim_stopline
    )
end

local function search_pair(delimiter, skip)
  local ok, found = pcall(
    vim.fn.searchpairpos,
    delimiter.re.open,
    "",
    delimiter.re.close,
    delimiter.gms_flags,
    skip or "",
    0,
    timeout()
  )
  if ok then
    return found
  end
  return vim.fn.searchpairpos(
    delimiter.re.open,
    "",
    delimiter.re.close,
    delimiter.gms_flags,
    skip or "",
    delimiter.gms_stopline
  )
end

local function matching_simple(delimiter, pair, skip)
  local found = pair and search_pair(delimiter, skip)
    or vim.fn.searchpos(
      delimiter.re.corr,
      delimiter.gms_flags,
      delimiter.gms_stopline
    )
  local line, column = found[1], found[2]
  return vim.fn.matchstr(
    vim.fn.getline(line),
    "^" .. delimiter.re.corr,
    column - 1
  ),
    line,
    column
end

local function parse_environment(context)
  local open = context.match:match "^\\begin" ~= nil
  local result = vim.tbl_extend("force", context, {
    type = "env",
    side = open and "open" or "close",
    is_open = open,
    name = vim.fn.matchstr(context.match, [[{\zs[^}*]*\ze\*\?}]]),
    starred = vim.fn.match(context.match, [[\*}$]]) > 0,
    corr = context.match:gsub(
      open and "begin" or "end",
      open and "end" or "begin",
      1
    ),
    re = { open = [[\m\\begin\s*{[^}]*}]], close = [[\m\\end\s*{[^}]*}]] },
  })
  result.gms_flags, result.gms_stopline = bounds(open)
  result.re.this, result.re.corr =
    result.re[result.side], result.re[open and "close" or "open"]
  if open then
    result.env_cmd = require("vimtex.cmd").get_at(context.lnum, context.cnum)
  end
  result._parser = "environment"
  return result
end

local function parse_tex(context, opts)
  local syntax = context.match == "$" and "texMathZoneTI" or "texMathZoneTD"
  local open =
    require("vimtex.syntax").in_group(syntax, context.lnum, context.cnum + 1)
  local escaped = [[\m]] .. vim.fn.escape(context.match, "$")
  local result = vim.tbl_extend("force", context, {
    type = "env",
    corr = context.match,
    side = open and "open" or "close",
    is_open = open,
    re = { this = escaped, corr = escaped, open = escaped, close = escaped },
  })
  result.gms_flags, result.gms_stopline = bounds(open)
  result._parser = "tex"
  if opts.side ~= "both" and opts.side ~= result.side then
    local saved = pos.get_cursor()
    pos.set_cursor(
      opts.direction == "next" and pos.next(context.lnum, context.cnum)
        or pos.prev(context.lnum, context.cnum)
    )
    result = M._get(opts)
    pos.set_cursor(saved)
  end
  return result
end

local function parse_latex(context)
  local open = vim.fn.match(context.match, [[\\(\|\\\[]]) >= 0
  local paren = vim.fn.match(context.match, [[\\(\|\\)]]) >= 0
  local ropen = vim.g["vimtex#re#not_bslash"]
    .. (paren and [[\m\\(]] or "\\m\\\\\\[")
  local rclose = vim.g["vimtex#re#not_bslash"]
    .. (paren and [[\m\\)]] or "\\m\\\\\\]")
  local result = vim.tbl_extend("force", context, {
    type = "env",
    side = open and "open" or "close",
    is_open = open,
    corr = open and context.match:gsub("%[", "]"):gsub("%(", ")")
      or context.match:gsub("%]", "["):gsub("%)", "("),
    re = { open = ropen, close = rclose },
  })
  result.gms_flags, result.gms_stopline = bounds(open)
  result.re.this, result.re.corr =
    result.re[result.side], result.re[open and "close" or "open"]
  result._parser = "latex"
  return result
end

local function parse_math(context)
  local open = vim.fn.match(context.match, M.re.delim_all.open) >= 0
  local result = vim.tbl_extend("force", context, {
    type = "delim",
    side = open and "open" or "close",
    is_open = open,
  })
  result.gms_flags, result.gms_stopline = bounds(open)
  if vim.fn.match(context.match, "^" .. M.re.mods.both) >= 0 then
    local m1 = vim.fn.matchstr(context.match, "^" .. M.re.mods.both)
    local d1 = context.match:sub(#m1 + 1):gsub("^%s*", "")
    local s1 = open and 0 or 1
    local re1 = re_for(m1, s1, "mods")
      .. [[\s*]]
      .. re_for(d1, s1, "delim_math")
    local m2, d2, s2 =
      corresponding(m1, "mods"),
      corresponding(d1, "delim_math"),
      open and 1 or 0
    local re2 = re_for(m2, s2, "mods")
      .. [[\s*]]
      .. (
        (m1:match [[\left]] or m1:match [[\right]])
          and ([[\%(]] .. re_for(d2, s2, "delim_math") .. [[\|\.\)]])
        or re_for(d2, s2, "delim_math")
      )
    result.delim, result.mod, result.corr = d1, m1, m2 .. d2
    result.corr_delim, result.corr_mod = d2, m2
    result.re = {
      this = re1,
      corr = re2,
      open = open and re1 or re2,
      close = open and re2 or re1,
    }
  else
    local d2 = corresponding(context.match)
    local re1, re2 =
      re_for(context.match, open and 0 or 1), re_for(d2, open and 1 or 0)
    result.delim, result.mod, result.corr = context.match, "", d2
    result.corr_delim, result.corr_mod = d2, ""
    result.re = {
      this = re1,
      corr = re2,
      open = open and re1 or re2,
      close = open and re2 or re1,
    }
  end
  result._parser = "math"
  return result
end

local function parse_unmatched(context)
  local open = vim.fn.match(context.match, M.re.delim_all.open) >= 0
  local result = vim.tbl_extend("force", context, {
    type = "delim",
    side = open and "open" or "close",
    is_open = open,
    delim = ".",
    corr_delim = ".",
    mod = open and [[\left]] or [[\right]],
    corr_mod = open and [[\right]] or [[\left]],
    corr = open and [[\right.]] or [[\left.]],
  })
  result.gms_flags, result.gms_stopline = bounds(open)
  local re1 = open and [[\\left\s*\.]] or [[\\right\s*\.]]
  local re2 = re_for(open and [[\right]] or [[\left]], open and 1 or 0, "mods")
    .. [[\s*]]
    .. re_for(".", 0)
  result.re = {
    this = re1,
    corr = re2,
    open = open and re1 or re2,
    close = open and re2 or re1,
  }
  result._parser = "unmatched"
  return result
end

function M._get(opts)
  local saved, regex = pos.get_cursor(), M.re[opts.type][opts.side]
  local line, column
  while true do
    local flags = opts.direction == "next" and "cnW" or "bcnW"
    local stop = opts.direction == "next"
        and vim.fn.line "." + vim.g.vimtex_delim_stopline
      or (
        opts.direction == "prev"
          and math.max(vim.fn.line "." - vim.g.vimtex_delim_stopline, 1)
        or vim.fn.line "."
      )
    local found = vim.fn.searchpos(regex, flags, stop)
    line, column = found[1], found[2]
    if line == 0 then
      break
    end
    if
      opts.syn_exclude
      and require("vimtex.syntax").in_group(opts.syn_exclude, line, column)
    then
      pos.set_cursor(pos.prev(line, column))
    else
      break
    end
  end
  pos.set_cursor(saved)
  local match = vim.fn.matchstr(vim.fn.getline(line), "^" .. regex, column - 1)
  if
    opts.direction == "current"
    and column + #match + (vim.fn.mode() == "i" and 1 or 0) <= vim.fn.col "."
  then
    return {}
  end
  local context = { lnum = line, cnum = column, match = match }
  if match:match [[^\begin]] or match:match [[^\end]] then
    return parse_environment(context)
  end
  if
    match:match "^%$%$?" and not require("vimtex.syntax").in_group "texComment"
  then
    return parse_tex(context, opts)
  end
  if vim.fn.match(match, [[^\\\%((\|)\|\[\|\]\)]]) >= 0 then
    return parse_latex(context)
  end
  if vim.fn.match(match, [[^\\\%(left\|right\)\s*\.]]) >= 0 then
    return parse_unmatched(context)
  end
  if vim.fn.match(match, "^" .. M.re.delim_all.both) >= 0 then
    return parse_math(context)
  end
  return {}
end

local function options(direction, kind, side, extra)
  return vim.tbl_extend(
    "force",
    { direction = direction, type = kind, side = side },
    extra or {}
  )
end

function M.get_next(kind, side, extra)
  return M._get(options("next", kind, side, extra))
end
function M.get_prev(kind, side, extra)
  return M._get(options("prev", kind, side, extra))
end
function M.get_current(kind, side, extra)
  return M._get(options("current", kind, side, extra))
end
local function from(position, fn, kind, side, extra)
  local saved = pos.get_cursor()
  pos.set_cursor(position)
  local result = fn(kind, side, extra)
  pos.set_cursor(saved)
  return result
end
function M.get_next_after(position, kind, side, extra)
  return from(position, M.get_next, kind, side, extra)
end
function M.get_prev_before(position, kind, side, extra)
  return from(position, M.get_prev, kind, side, extra)
end

function M.get_matching(delimiter)
  if not delimiter or not delimiter.lnum then
    return {}
  end
  local saved = pos.get_cursor()
  pos.set_cursor(delimiter)
  local match, line, column
  if delimiter._parser == "environment" then
    match, line, column = matching_simple(delimiter, true)
  elseif delimiter._parser == "unmatched" then
    local misses = {}
    vim.g._vimtex_delim_misses = misses
    for _ = 1, 10 do
      local found = search_pair(
        delimiter,
        [[index(g:_vimtex_delim_misses, [line("."), col(".")]) >= 0]]
      )
      line, column = found[1], found[2]
      match = vim.fn.matchstr(
        vim.fn.getline(line),
        "^" .. delimiter.re.corr,
        column - 1
      )
      if line == 0 then
        break
      end
      local candidate = parse_math { lnum = line, cnum = column, match = match }
      local corresponding_candidate = M.get_matching(candidate)
      if
        corresponding_candidate.lnum == delimiter.lnum
        and corresponding_candidate.cnum == delimiter.cnum
      then
        break
      end
      table.insert(misses, { line, column })
      vim.g._vimtex_delim_misses = misses
    end
    vim.g._vimtex_delim_misses = nil
  elseif delimiter._parser == "math" then
    match, line, column = matching_simple(
      delimiter,
      true,
      [[synIDattr(synID(line("."), col("."), 0), "name") =~? "comment"]]
    )
  else
    match, line, column = matching_simple(delimiter, false)
  end
  pos.set_cursor(saved)
  local result = vim.deepcopy(delimiter)
  result.lnum, result.cnum, result.match = line, column, match
  result.corr, result.side, result.is_open =
    delimiter.match,
    delimiter.is_open and "close" or "open",
    not delimiter.is_open
  result.re.corr, result.re.this = delimiter.re.this, delimiter.re.corr
  if result.type == "delim" then
    result.corr_delim, result.corr_mod, result.delim, result.mod =
      delimiter.delim, delimiter.mod, delimiter.corr_delim, delimiter.corr_mod
  elseif result.name then
    if result.is_open then
      result.env_cmd = require("vimtex.cmd").get_at(line, column)
    else
      result.env_cmd = nil
    end
    result.name = vim.fn.matchstr(match, [[{\zs\k*\ze\*\?}]])
  end
  return result
end
function M.get_current_matching(...)
  local d = M.get_current(...)
  return { d, M.get_matching(d) }
end
function M.get_next_matching(...)
  local d = M.get_next(...)
  return { d, M.get_matching(d) }
end

local function allowed(opening, opts)
  local whitelist = (opts or {}).whitelist or {}
  return #whitelist == 0
    or vim.tbl_contains(whitelist, ((opening.name or ""):gsub("%*$", "")))
end

local function surrounding_environment(kind, opts)
  local saved = pos.get_cursor()
  local cursor_value = pos.val(saved)
  local last, opening_value = cursor_value, cursor_value - 1
  local maximum = kind == "env_math" and 3 or 100
  for _ = 1, maximum do
    if opening_value >= last then
      break
    end
    local opening = M.get_prev(kind, "open")
    if vim.tbl_isempty(opening) then
      break
    end
    if allowed(opening, opts) then
      local closing = M.get_matching(opening)
      local candidate = pos.val(closing) + #(closing.match or "") - 1
      if candidate >= cursor_value then
        pos.set_cursor(saved)
        return { opening, closing }
      end
    end
    pos.set_cursor(pos.prev(opening))
    last, opening_value = opening_value, pos.val(opening)
  end
  pos.set_cursor(saved)
  return { {}, {} }
end

local function surrounding_delimiter(kind)
  local saved = pos.get_cursor()
  local cursor_value = pos.val(saved)
  local last, current = cursor_value, cursor_value - 1
  for _ = 1, 100 do
    if current >= last then
      break
    end
    local opening = M.get_prev(kind, "open")
    if vim.tbl_isempty(opening) then
      break
    end
    local environment_close = M.get_next_after(opening, "env_all", "close")
    local environment_open = M.get_matching(environment_close)
    local opening_value = pos.val(opening)
    local environment_open_value = vim.tbl_isempty(environment_open) and 0
      or pos.val(environment_open)
    local environment_close_value = vim.tbl_isempty(environment_close)
        and cursor_value + 1
      or pos.val(environment_close) + #(environment_close.match or "") - 1
    if
      environment_open_value > opening_value
      or environment_close_value > cursor_value
    then
      local closing = M.get_matching(opening)
      if pos.val(closing) + #(closing.match or "") - 1 >= cursor_value then
        pos.set_cursor(saved)
        return { opening, closing }
      end
    end
    pos.set_cursor(pos.prev(opening))
    last, current = current, opening_value
  end
  pos.set_cursor(saved)
  return { {}, {} }
end

function M.get_surrounding(kind, opts)
  return kind:match "^env" and surrounding_environment(kind, opts or {})
    or surrounding_delimiter(kind)
end

function M.get_surrounding_or_next(kind, opts)
  local result = M.get_surrounding(kind, opts)
  if not vim.tbl_isempty(result[1]) then
    return result
  end
  if not kind:match "^env" then
    return { {}, {} }
  end
  local saved = pos.get_cursor()
  local maximum = kind == "env_math" and 3 or 100
  local opening
  for _ = 1, maximum do
    opening = M.get_next(kind, "open")
    if vim.tbl_isempty(opening) then
      pos.set_cursor(saved)
      return { {}, {} }
    end
    if not kind:match "^env" or allowed(opening, opts or {}) then
      break
    end
    pos.set_cursor(pos.next(opening))
  end
  pos.set_cursor(saved)
  return { opening, M.get_matching(opening) }
end

function M.close()
  local saved = pos.get_cursor()
  local indent = vim.g.vimtex_indent_enabled == 1 and "\6" or ""
  local cursor_value, current, last =
    pos.val(saved), pos.val(saved), pos.val(saved) + 1
  while current < last do
    local opening = M.get_prev("all", "open", { syn_exclude = "texComment" })
    if vim.tbl_isempty(opening) or opening.name == "document" then
      break
    end
    local closing = M.get_matching(opening)
    if closing.match == "" then
      pos.set_cursor(saved)
      return opening.corr .. indent
    end
    last, current = current, pos.val(opening)
    if
      current ~= cursor_value
      and pos.val(closing) + #closing.match > cursor_value
    then
      pos.set_cursor(saved)
      return opening.corr .. indent
    end
    pos.set_cursor(pos.prev(opening))
  end
  pos.set_cursor(saved)
  return ""
end

function M.toggle_modifier(args)
  args = vim.tbl_extend(
    "keep",
    args or {},
    { count = vim.v.count1, dir = 1, openclose = {} }
  )
  local pair = #args.openclose > 0 and args.openclose
    or M.get_surrounding "delim_math_modq"
  local opening, closing = pair[1], pair[2]
  if vim.tbl_isempty(opening) then
    return
  end
  local direction = args.dir < 0 and -args.count or args.count
  local modifiers = { { "", "" } }
  vim.list_extend(
    modifiers,
    vim.g.vimtex_delim_toggle_mod_list or { { [[\left]], [[\right]] } }
  )
  local replacement = { "", "" }
  for index, item in ipairs(modifiers) do
    if opening.mod == item[1] then
      replacement = modifiers[((index - 1 + direction) % #modifiers) + 1]
      break
    end
  end
  local closing_column = closing.cnum
  local shift = #replacement[1] - #(opening.mod or "")
  if opening.lnum == closing.lnum then
    closing_column = closing_column + shift
  end
  local cursor = pos.get_cursor()
  local adjust_right = cursor[3] >= closing.cnum + #(closing.mod or "")
  if cursor[2] == opening.lnum and cursor[3] > opening.cnum then
    if cursor[3] > opening.cnum + #(opening.mod or "") then
      cursor[3] = cursor[3] + shift
    elseif shift < 0 then
      cursor[3] = opening.cnum
    end
  end
  if cursor[2] == closing.lnum and cursor[3] >= closing_column then
    cursor[3] = adjust_right
        and cursor[3] + #replacement[2] - #(closing.mod or "")
      or closing_column
  end
  local line = vim.fn.getline(opening.lnum)
  vim.fn.setline(
    opening.lnum,
    line:sub(1, opening.cnum - 1)
      .. replacement[1]
      .. line:sub(opening.cnum + #(opening.mod or ""))
  )
  line = vim.fn.getline(closing.lnum)
  vim.fn.setline(
    closing.lnum,
    line:sub(1, closing_column - 1)
      .. replacement[2]
      .. line:sub(closing_column + #(closing.mod or ""))
  )
  pos.set_cursor(cursor)
  return replacement
end

function M.change_with_args(opening, closing, new)
  local first, last
  if new == "" then
    first, last = "", ""
  elseif new == "{" or new == "}" then
    first, last = "{", "}"
  else
    local side = vim.fn.match(new, M.re.delim_math.close) >= 0 and 2 or 1
    for _, pair in ipairs(M.lists.delim_math.name) do
      if pair[side] == new then
        first, last = pair[1], pair[2]
        break
      end
    end
    first, last = first or new, last or new
  end
  local line = vim.fn.getline(opening.lnum)
  vim.fn.setline(
    opening.lnum,
    line:sub(1, opening.cnum - 1)
      .. first
      .. line:sub(opening.cnum + #opening.match)
  )
  local c1, c2 = closing.cnum, closing.cnum + #closing.match - 1
  if opening.lnum == closing.lnum then
    local shift = #first - #opening.match
    c1, c2 = c1 + shift, c2 + shift
    local cursor = pos.get_cursor()
    if cursor[3] > opening.cnum + #opening.match - 1 then
      cursor[3] = cursor[3] + shift
      pos.set_cursor(cursor)
    end
  end
  line = vim.fn.getline(closing.lnum)
  vim.fn.setline(closing.lnum, line:sub(1, c1 - 1) .. last .. line:sub(c2 + 1))
end

function M.change(new)
  local pair = M.get_surrounding "delim_math"
  if vim.tbl_isempty(pair[1]) then
    return
  end
  new = new
    or require("vimtex.ui").input { prompt = "Change surrounding delimiter: " }
  if new and new ~= "" then
    M.change_with_args(pair[1], pair[2], new)
  end
end

function M.change_input_complete(lead)
  local result = {}
  for _, pair in ipairs(M.lists.delim_all.name) do
    for _, value in ipairs(pair) do
      if vim.startswith(value, lead) then
        table.insert(result, value)
      end
    end
  end
  return result
end

function M.delete()
  local pair = M.get_surrounding "delim_math_modq"
  if not vim.tbl_isempty(pair[1]) then
    M.change_with_args(pair[1], pair[2], "")
  end
end

function M.toggle_modifier_visual(args)
  args = vim.tbl_extend(
    "keep",
    args or {},
    { count = vim.v.count1, dir = 1, reselect = true }
  )
  local anchor, cursor = vim.fn.getpos "v", vim.fn.getcurpos()
  local first, last = anchor, cursor
  if pos.larger(first, last) then
    first, last = last, first
  end
  vim.cmd "normal! \27"
  local last_value, current = pos.val(last) + 1000, first
  while pos.val(current) < last_value do
    pos.set_cursor(current)
    local opening = M.get_next("delim_math_modq", "open")
    if vim.tbl_isempty(opening) or pos.val(opening) >= last_value then
      break
    end
    local closing = M.get_matching(opening)
    if
      not vim.tbl_isempty(closing)
      and last_value >= pos.val(closing) + #closing.match - 1
    then
      local replacements = M.toggle_modifier {
        count = args.count,
        dir = args.dir,
        openclose = { opening, closing },
      }
      local difference = (
        opening.lnum == last[2] and (#replacements[1] - #(opening.mod or ""))
        or 0
      )
        + (
          closing.lnum == last[2]
            and (#replacements[2] - #(closing.mod or ""))
          or 0
        )
      last[3], last_value = last[3] + difference, last_value + difference
    end
    current = pos.next(opening)
  end
  vim.fn.setpos("'<", first)
  vim.fn.setpos("'>", last)
  pos.set_cursor(cursor)
  if args.reselect then
    vim.cmd "normal! gv"
  end
end

function M.add_modifiers()
  local cursor = pos.get_cursor()
  local wrap = vim.o.whichwrap
  vim.o.whichwrap = "h"
  while require("vimtex.syntax").in_mathzone() do
    vim.cmd "normal! h"
    local here = pos.get_cursor()
    if here[2] == 1 and here[3] == 1 then
      break
    end
  end
  vim.o.whichwrap = wrap
  local start, undo = pos.val(pos.get_cursor()), true
  pos.set_cursor(cursor)
  while true do
    local pair = M.get_surrounding "delim_math_modq"
    local opening, closing = pair[1], pair[2]
    if vim.tbl_isempty(opening) or pos.val(opening) <= start then
      break
    end
    pos.set_cursor(pos.prev(opening))
    if opening.mod == "" then
      if undo then
        undo = false
        pos.set_cursor(cursor)
        require("vimtex.util").undostore()
        pos.set_cursor(pos.prev(opening))
      end
      local line = vim.fn.getline(closing.lnum)
      vim.fn.setline(
        closing.lnum,
        line:sub(1, closing.cnum - 1) .. [[\right]] .. line:sub(closing.cnum)
      )
      line = vim.fn.getline(opening.lnum)
      vim.fn.setline(
        opening.lnum,
        line:sub(1, opening.cnum - 1) .. [[\left]] .. line:sub(opening.cnum)
      )
      cursor[3] = cursor[3] + 5
    end
  end
  pos.set_cursor(cursor)
end

local pending
local function operator(action)
  pending = { action }
  if action == "change" then
    local pair = M.get_surrounding "delim_math"
    if vim.tbl_isempty(pair[1]) then
      pending = nil
      return
    end
    pending[2] =
      require("vimtex.ui").input { prompt = "Change surrounding delimiter: " }
  end
  vim.go.operatorfunc = "v:lua.require'vimtex.delim'.operator_callback"
  vim.cmd("normal! " .. (vim.v.count > 0 and vim.v.count or "") .. "g@l")
end

function M.operator_callback()
  if not pending then
    return
  end
  local action, argument = pending[1], pending[2]
  if action == "toggle_modifier_prev" then
    M.toggle_modifier { dir = -1 }
  elseif action == "toggle_modifier_next" then
    M.toggle_modifier()
  elseif action == "change" then
    M.change(argument)
  else
    M[action]()
  end
end

function M.init_buffer()
  for lhs, action in pairs {
    ["<plug>(vimtex-delim-toggle-modifier)"] = "toggle_modifier_next",
    ["<plug>(vimtex-delim-toggle-modifier-reverse)"] = "toggle_modifier_prev",
    ["<plug>(vimtex-delim-change-math)"] = "change",
    ["<plug>(vimtex-delim-delete)"] = "delete",
  } do
    vim.keymap.set("n", lhs, function()
      operator(action)
    end, { buffer = true, silent = true })
  end
  vim.keymap.set("x", "<plug>(vimtex-delim-toggle-modifier)", function()
    M.toggle_modifier_visual()
  end, { buffer = true, silent = true })
  vim.keymap.set("x", "<plug>(vimtex-delim-toggle-modifier-reverse)", function()
    M.toggle_modifier_visual { dir = -1 }
  end, { buffer = true, silent = true })
  vim.keymap.set(
    "i",
    "<plug>(vimtex-delim-close)",
    M.close,
    { buffer = true, expr = true, silent = true }
  )
  vim.keymap.set(
    "n",
    "<plug>(vimtex-delim-add-modifiers)",
    M.add_modifiers,
    { buffer = true, silent = true }
  )
end

return M
