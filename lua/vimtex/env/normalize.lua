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

local function scan(text)
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

function M.run()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local edits, skipped = scan(table.concat(lines, "\n"))
  local starts = { 1 }
  for i = 2, #lines do
    starts[i] = starts[i - 1] + #lines[i - 1] + 1
  end
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
  for i, edit in ipairs(edits) do
    local first, last = row(edit[1]), row(edit[2])
    if i > 1 then
      vim.cmd "undojoin"
    end
    vim.api.nvim_buf_set_text(
      0,
      first - 1,
      edit[1] - starts[first],
      last - 1,
      edit[2] - starts[last],
      { edit[3] }
    )
  end
  if #skipped > 0 then
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

return M
