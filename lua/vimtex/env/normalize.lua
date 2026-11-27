local M = {}
local displays = require "vimtex.env.normalize_display"
local inline = { open = "$", close = "$" }
local named =
  vim.tbl_extend("force", displays, { math = inline, equation = {} })

local literal_env = {
  verbatim = true,
  ["verbatim*"] = true,
  Verbatim = true,
  BVerbatim = true,
  LVerbatim = true,
  SaveVerbatim = true,
  lstlisting = true,
  minted = true,
  comment = true,
  filecontents = true,
  ["filecontents*"] = true,
  luacode = true,
  ["luacode*"] = true,
}
local row_command = {
  tag = true,
  notag = true,
  nonumber = true,
  intertext = true,
  shortintertext = true,
  displaybreak = true,
  shoveleft = true,
  shoveright = true,
}

-- Inline verbatim arguments have their own catcodes, including % and \.
local function literal_end(text, pos, cmd)
  local limit = text:find("\n", pos, true) or (#text + 1)
  local line = text:sub(pos, limit - 1)
  local i = 1
  if line:sub(i, i) == "*" then
    i = i + 1
  end
  if cmd ~= "verb" then
    i = line:match("^%s*()", i)
    i = line:match("^%b[]%s*()", i) or i
  end
  if cmd == "mintinline" then
    i = line:match("^%b{}%s*()", i) or i
  end
  local delim = line:sub(i, i)
  if delim == "{" and (cmd == "mintinline" or cmd == "lstinline") then
    return pos + (line:match("^%b{}()", i) or #line + 1) - 1
  end
  local last = line:find(delim, i + 1, true)
  return last and pos + last or limit
end

local function next_nontrivia(text, pos)
  while true do
    pos = text:match("^%s*()", pos)
    if text:sub(pos, pos) ~= "%" then
      return text:sub(pos, pos)
    end
    pos = text:find("\n", pos, true) or (#text + 1)
  end
end

local function scan(text, first_allowed)
  local edits, skipped, stack = {}, {}, {}
  local pos = 1

  local function open(kind, pair, first, after)
    local parent = stack[#stack]
    local frame = { kind = kind, pair = pair, first = first, after = after }
    if pair.multiline and parent and parent.pair.multiline then
      parent.skip, frame.skip = true, true
    end
    stack[#stack + 1] = frame
  end

  local function close(kind, first, after)
    local frame = stack[#stack]
    if not frame or frame.kind ~= kind then
      return
    end
    stack[#stack] = nil
    if frame.first < first_allowed then
      return
    end
    local pair = frame.pair
    if frame.skip then
      skipped[#skipped + 1] = frame.first
    elseif pair.open then
      local opening = pair.open
      if pair == inline and frame.after == first then
        opening = "${}" -- Two adjacent bare dollars would open display math.
      elseif pair.multiline and next_nontrivia(text, frame.after) == "[" then
        -- An initial interval [a,b] is not an optional alignment argument.
        if opening:match "{aligned}$" or opening:match "{gathered}$" then
          opening = opening .. "[c]"
        end
      end
      edits[#edits + 1] = { frame.first, frame.after, opening }
      edits[#edits + 1] = { first, after, pair.close }
    end
  end

  while true do
    local at = text:find("[\\$%%]", pos)
    if not at then
      break
    end
    local ch = text:sub(at, at)
    local top = stack[#stack]
    if ch == "%" then
      pos = text:find("\n", at, true) or (#text + 1)
    elseif ch == "$" then
      local kind = "$"
      if not (top and top.kind == "$") and text:sub(at + 1, at + 1) == "$" then
        kind = "$$"
      end
      pos = at + #kind
      if top and top.kind == kind then
        close(kind, at, pos)
      else
        open(kind, kind == "$$" and displays.displaymath or {}, at, pos)
      end
    else
      -- Consume whole control words/symbols so \\, \% and \$ stay literal.
      local cmd, after = text:match("^\\([a-zA-Z@]+)()", at)
      if not cmd then
        cmd, after = text:sub(at + 1, at + 1), at + 2
      end
      pos = after
      if cmd == "(" or cmd == "[" then
        open(cmd, cmd == "(" and inline or displays.displaymath, at, pos)
      elseif cmd == ")" or cmd == "]" then
        close(cmd == ")" and "(" or "[", at, pos)
      elseif cmd == "begin" or cmd == "end" then
        local name, tail = text:match("^%s*{([%w@*%-]+)}()", after)
        if name then
          pos = tail
          if cmd == "begin" and literal_env[name] then
            local term = "\\end{" .. vim.pesc(name) .. "}"
            -- Kernel verbatim can end mid-line. Code listings have a
            -- line-oriented terminator and can contain it as sample text.
            if name ~= "verbatim" and name ~= "verbatim*" then
              term = "\n[ \t]*" .. term
            end
            local _, last = text:find(term, tail)
            pos = last and last + 1 or #text + 1
          elseif named[name] then
            if cmd == "begin" then
              open(name, named[name], at, tail)
            else
              close(name, at, tail)
            end
          end
        end
      elseif
        cmd == "verb"
        or cmd == "Verb"
        or cmd == "lstinline"
        or cmd == "mintinline"
      then
        pos = literal_end(text, after, cmd)
      elseif
        cmd == "url"
        or cmd == "path"
        or cmd == "nolinkurl"
        or cmd == "detokenize"
      then
        pos = text:match("^%s*%b{}()", after) or after
      elseif top and top.kind == "$$" and (cmd == "eqno" or cmd == "leqno") then
        top.skip = true -- Primitive display tags are invalid inside equation.
      elseif top and top.pair.multiline then
        if cmd == "label" then
          top.skip = top.skip or top.has_label
          top.has_label = true
        elseif row_command[cmd] then
          top.skip = true
        end
      end
    end
  end
  return edits, skipped
end

-- A native put leaves '] and often the cursor on its last character. Keep
-- both at the new end even when the closing delimiter grows by several bytes.
local ns = vim.api.nvim_create_namespace "vimtex_normalize_paste"
local function track_paste_end(last)
  local api = vim.api
  local id = api.nvim_buf_set_extmark(0, ns, last[1], last[2], {})
  local mark = api.nvim_buf_get_mark(0, "]")
  local cursor = api.nvim_win_get_cursor(0)
  local endline = api.nvim_buf_get_lines(0, last[1], last[1] + 1, true)[1]
  local final_char = last[2] > 0
    and last[2] - 1 + vim.str_utf_start(endline, last[2])
  local mark_at_end = mark[1] == last[1] + 1
    and (mark[2] == final_char or math.min(mark[2], #endline) == last[2])
  return function()
    local finish = api.nvim_buf_get_extmark_by_id(0, ns, id, {})
    api.nvim_buf_del_extmark(0, ns, id)
    local row, col = finish[1] + 1, finish[2]
    if mark_at_end then
      local mark_col = col
      if mark[2] < last[2] and col > 0 then
        local line = api.nvim_buf_get_lines(0, row - 1, row, true)[1]
        mark_col = vim.str_utf_start(line, col) + col - 1
      end
      api.nvim_buf_set_mark(0, "]", row, mark_col, {})
      if vim.deep_equal(cursor, mark) then
        api.nvim_win_set_cursor(0, { row, mark_col })
        return
      end
    end
    if cursor[1] == last[1] + 1 and cursor[2] == last[2] then
      api.nvim_win_set_cursor(0, { row, col })
    end
  end
end

-- A paste supplies a half-open range in zero-based buffer coordinates.
-- Scan its prefix for TeX context, but only edit pairs wholly inside the range.
local function normalize(first, last)
  local lines =
    vim.api.nvim_buf_get_lines(0, 0, last and last[1] + 1 or -1, true)
  if last then
    lines[#lines] = lines[#lines]:sub(1, last[2])
  end
  local starts = { 1 }
  for i = 2, #lines do
    starts[i] = starts[i - 1] + #lines[i - 1] + 1
  end
  local edits, skipped = scan(
    table.concat(lines, "\n"),
    first and starts[first[1] + 1] + first[2] or 1
  )
  local function row(offset)
    local lo, hi = 1, #starts
    while lo < hi do
      local mid = math.floor((lo + hi + 1) / 2)
      if starts[mid] <= offset then
        lo = mid
      else
        hi = mid - 1
      end
    end
    return lo
  end

  table.sort(edits, function(a, b)
    return a[1] > b[1]
  end)
  local restore_end = last and #edits > 0 and track_paste_end(last)
  for i, edit in ipairs(edits) do
    local start_row, end_row = row(edit[1]), row(edit[2])
    if first or i > 1 then
      vim.cmd "undojoin"
    end
    vim.api.nvim_buf_set_text(
      0,
      start_row - 1,
      edit[1] - starts[start_row],
      end_row - 1,
      edit[2] - starts[end_row],
      { edit[3] }
    )
  end
  if restore_end then
    restore_end()
  end
  if not first and #skipped > 0 then
    local rows = {}
    table.sort(skipped)
    for _, offset in ipairs(skipped) do
      rows[#rows + 1] = row(offset)
    end
    require("vimtex.log").warning(
      "Preserved math with special numbering or layout at line(s): "
        .. table.concat(rows, ", ")
    )
  end
end

function M.range(first, last)
  -- Most puts are ordinary text. Avoid scanning the document in that case.
  for _, line in
    ipairs(
      vim.api.nvim_buf_get_text(0, first[1], first[2], last[1], last[2], {})
    )
  do
    if line:find("\\", 1, true) or line:find("$$", 1, true) then
      normalize(first, last)
      return
    end
  end
end

function M.run()
  normalize()
end

return M
