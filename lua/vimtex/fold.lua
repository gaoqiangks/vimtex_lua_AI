local M = {}
local states = {}

local function matches(text, pattern)
  return pattern and vim.fn.match(text, pattern) >= 0
end
local function matchstr(text, pattern)
  return vim.fn.matchstr(text, pattern)
end
local function config(name)
  return vim.tbl_deep_extend(
    "force",
    vim.deepcopy((vim.g.vimtex_fold_types_defaults or {})[name] or {}),
    (vim.g.vimtex_fold_types or {})[name] or {}
  )
end
local function simple(name, re, level, text)
  return { name = name, re = re, level = level, text = text }
end

local constructors = {}

constructors.preamble = function(cfg)
  return vim.tbl_extend(
    "force",
    simple(
      "preamble",
      { start = [[^\s*\\documentclass]], fold_re = [[\\documentclass]] },
      function(self, line)
        if matches(line, self.re.start) then
          return ">1"
        end
      end,
      function()
        return "      Preamble"
      end
    ),
    cfg
  )
end

constructors.comment_pkg = function(cfg)
  local object = simple(
    "comment_pkg",
    { start = [[^\s*\\begin\s*{comment}]], ["end"] = [[^\s*\\end\s*{comment}]] }
  )
  object.opened = false
  function object:level(line)
    if matches(line, self.re.start) then
      self.opened = true
      return "a1"
    elseif matches(line, self.re["end"]) then
      self.opened = false
      return "s1"
    elseif self.opened then
      return "="
    end
  end
  function object:parse_label()
    local depth = -1
    for lnum = vim.v.foldstart, vim.v.foldend do
      local line = vim.fn.getline(lnum)
      depth = depth
        + require("vimtex.util").count(line, [[\\begin{\w\+}]])
        - require("vimtex.util").count(line, [[\\end{\w\+}]])
      if depth == 0 and matches(line, [[^\s*\\label]]) then
        return matchstr(line, [=[^\s*\\label\%(\[.*\]\)\?{\zs.*\ze}]=])
      end
    end
    return ""
  end
  function object:parse_caption(source)
    local depth = -1
    for lnum = vim.v.foldstart, vim.v.foldend do
      local line = vim.fn.getline(lnum)
      depth = depth
        + require("vimtex.util").count(line, [[\\begin{\w\+}]])
        - require("vimtex.util").count(line, [[\\end{\w\+}]])
      if depth == 0 and matches(line, [[^\s*\\caption]]) then
        return matchstr(
          line,
          [=[^\s*\\caption\(\[.*\]\)\?{\zs.\{-1,}\ze\(}\s*\)\?$]=]
        )
      end
    end
    return matchstr(source, [[\\begin\*\?{.*}\s*%\s*\zs.*]])
  end
  function object:parse_frame(source)
    local caption =
      matchstr(source, [=[\\begin\*\?{.*}\%(\[[^]]*\]\)\?{\zs.\+\ze}]=])
    if caption == "" then
      caption = matchstr(source, [=[\\begin\*\?{.*}\%(\[[^]]*\]\)\?{\zs.\+]=])
    end
    if caption ~= "" then
      return caption
    end
    for lnum = vim.v.foldstart, vim.v.foldend do
      local line = vim.fn.getline(lnum)
      if matches(line, [[^\s*\\frametitle]]) then
        local title = matchstr(
          line,
          [=[^\s*\\frametitle\%(\[.*\]\)\?{\zs.\{-1,}\ze\%(}\s*\)\?$]=]
        )
        local nextline = vim.fn.getline(lnum + 1)
        if
          lnum < vim.v.foldend and matches(nextline, [[^\s*\\framesubtitle]])
        then
          return title
            .. ": "
            .. matchstr(
              nextline,
              [=[^\s*\\framesubtitle\%(\[.*\]\)\?{\zs.\{-1,}\ze\%(}\s*\)\?$]=]
            )
        end
        return title
      end
    end
    return matchstr(source, [=[\\begin\*\?{.*}\%(\[.*\]\)\?\s*%\s*\zs.*]=])
  end
  function object:text(line)
    return line
  end
  return vim.tbl_extend("force", object, cfg)
end

constructors.comments = function(cfg)
  local object = simple("comments", { start = [[^\s*%]] })
  object.opened = false
  function object:level(line, lnum, state)
    if state.dict.markers and state.dict.markers.opened then
      return
    end
    if matches(line, self.re.start) then
      local before = not matches(vim.fn.getline(lnum - 1), self.re.start)
      local after = not matches(vim.fn.getline(lnum + 1), self.re.start)
      if before and not after then
        self.opened = true
        return "a1"
      elseif after and not before then
        self.opened = false
        return "s1"
      end
    end
  end
  function object:text(line)
    local parts = {}
    for _, value in ipairs(vim.fn.getline(vim.v.foldstart, vim.v.foldend)) do
      parts[#parts + 1] = matchstr(value, [[%\s*\zs.*\ze\s*]])
    end
    return matchstr(line, [[^.*\s*%]]) .. table.concat(parts, " ")
  end
  return vim.tbl_extend("force", object, cfg)
end

local function command_folder(name, cfg, kind)
  local object = { name = name, re = {}, opened = 0, cmds = {} }
  object = vim.tbl_extend("force", object, cfg)
  local commands = table.concat(object.cmds, "|")
  local prefix = [[\v^\s*\\%(]] .. commands .. [[)\*?]]
  if kind == "single" then
    prefix = prefix .. [[\s*%(\[.*\])?]]
    object.re.start = prefix .. [[\s*\{\s*%($|\%)]]
    object.re["end"] = [[^\s*}]]
    object.re.text = prefix
  elseif kind == "single_opt" then
    object.re.start = prefix .. [[\s*\[\s*%($|\%)]]
    object.re["end"] = [[^\s*\]{]]
    object.re.text = prefix
  elseif kind == "multi" then
    object.re.start = prefix .. [[.*(\{|\[)\s*(\%.*)?$]]
    object.re["end"] = [[\v^\s*%(\}\s*\{)*\}\s*%(\%|$)]]
    object.re.text = prefix .. [[\{[^}]*\}]]
  else
    prefix = [[\v^\s*\\%(]] .. commands .. [=[)\s*%(\[[^\]]*\])?]=]
    object.re.start = prefix .. [=[\s*\w+\s*%(\[[^\]]*\])?\s*\ze\{\s*%($|\%)]=]
    object.re["end"] = [[^\s*}]]
  end
  object.re.fold_re = [[\\%(]] .. commands .. [[)]]
  function object:level(line)
    if matches(line, self.re.start) then
      self.opened = self.opened + 1
      return "a1"
    elseif self.opened > 0 and matches(line, self.re["end"]) then
      self.opened = self.opened - 1
      return "s1"
    end
  end
  function object:text(line)
    if kind == "multi" then
      return line
    end
    if kind == "single_opt" then
      local column = #matchstr(line, [[^\s*]]) + 1
      local command = require("vimtex.cmd").get_at(vim.v.foldstart, column)
      return matchstr(line, self.re.text)
        .. "[...]{"
        .. ((command.args or {})[1] or {}).text
        .. "}"
    end
    local prefix_text =
      matchstr(line, kind == "addplot" and self.re.start or self.re.text)
    return prefix_text
      .. "{...}"
      .. vim.fn.substitute(
        vim.fn.getline(vim.v.foldend),
        self.re["end"],
        "",
        ""
      )
  end
  return object
end
constructors.cmd_single = function(cfg)
  return command_folder("cmd_single", cfg, "single")
end
constructors.cmd_single_opt = function(cfg)
  return command_folder("cmd_single_opt", cfg, "single_opt")
end
constructors.cmd_multi = function(cfg)
  return command_folder("cmd_multi", cfg, "multi")
end
constructors.cmd_addplot = function(cfg)
  return command_folder("cmd_addplot", cfg, "addplot")
end

constructors.markers = function(cfg)
  local object = vim.tbl_extend(
    "force",
    { name = "markers", open = "{{{", close = "}}}", re = {}, opened = false },
    cfg
  )
  object.re.start, object.re["end"] =
    "%.*" .. object.open, "%.*" .. object.close
  object.re.text = {
    { object.re.start .. [[\d\?\s*\zs.*]], "% " .. object.open .. " " },
    { [[%\s*\zs.*\ze]] .. object.open, "% " .. object.open .. " " },
    { [[^.*\ze\s*%]], "" },
  }
  object.re.fold_re =
    vim.fn.escape(object.open .. "|" .. object.close, "{}%+*.")
  function object:level(line)
    local opening, closing =
      vim.fn.matchlist(line, self.re.start .. [[\(\d\?\)]]),
      vim.fn.matchlist(line, self.re["end"] .. [[\(\d\?\)]])
    if #opening > 0 then
      self.opened = true
      return opening[2] == "" and "a1" or ">" .. opening[2]
    elseif #closing > 0 then
      self.opened = false
      return closing[2] == "" and "s1" or "<" .. closing[2]
    end
  end
  function object:text(line)
    for _, rule in ipairs(self.re.text) do
      local value = matchstr(line, rule[1])
      if value ~= "" then
        return rule[2] .. value
      end
    end
    return "% " .. self.open .. " " .. vim.fn.getline(vim.v.foldstart + 1)
  end
  return object
end

constructors.env_options = function(cfg)
  local object = vim.tbl_extend("force", {
    name = "envs with options",
    re = {
      start = vim.g["vimtex#re#not_comment"]
        .. [[\\begin\s*\{.{-}\}\[\s*($|\%)]],
      ["end"] = [[\s*\]\s*$]],
    },
    opened = false,
  }, cfg)
  function object:level(line)
    if not self.opened and matches(line, self.re.start) then
      self.opened = true
      return "a1"
    elseif self.opened and matches(line, self.re["end"]) then
      self.opened = false
      return "s1"
    end
  end
  function object:text(line)
    return line .. "...] "
  end
  return object
end

constructors.envs = function(cfg)
  local nc = vim.g["vimtex#re#not_comment"]
  local object = vim.tbl_extend("force", {
    name = "environments",
    re = {
      start = nc .. [[\\begin\s*\{.{-}\}]],
      ["end"] = nc .. [[\\end\s*\{.{-}\}]],
      name = nc .. [[\\%(begin|end)\s*\{(.{-})\}(\s*\{.*\})?]],
    },
    whitelist = {},
    blacklist = {},
  }, cfg)
  function object:validate(environment)
    return (
      #self.whitelist == 0 or vim.tbl_contains(self.whitelist, environment)
    )
      and (
        #self.blacklist == 0
        or not vim.tbl_contains(self.blacklist, environment)
      )
  end
  function object:level(line)
    local found = vim.fn.matchlist(line, self.re.name)
    local environment = found[2] or ""
    if environment ~= "" and self:validate(environment) then
      if matches(line, self.re.start) and not matches(line, [[\\end]]) then
        return "a1"
      elseif
        matches(line, self.re["end"]) and not matches(line, [[\\begin]])
      then
        return "s1"
      end
    end
  end
  function object:parse_label()
    local depth = -1
    for lnum = vim.v.foldstart, vim.v.foldend do
      local line = vim.fn.getline(lnum)
      depth = depth
        + require("vimtex.util").count(line, [[\\begin{\w\+}]])
        - require("vimtex.util").count(line, [[\\end{\w\+}]])
      if depth == 0 and matches(line, [[^\s*\\label]]) then
        return matchstr(line, [=[^\s*\\label\%(\[.*\]\)\?{\zs.*\ze}]=])
      end
    end
    return ""
  end
  function object:parse_caption(source)
    local depth = -1
    for lnum = vim.v.foldstart, vim.v.foldend do
      local line = vim.fn.getline(lnum)
      depth = depth
        + require("vimtex.util").count(line, [[\\begin{\w\+}]])
        - require("vimtex.util").count(line, [[\\end{\w\+}]])
      if depth == 0 and matches(line, [[^\s*\\caption]]) then
        return matchstr(
          line,
          [=[^\s*\\caption\(\[.*\]\)\?{\zs.\{-1,}\ze\(}\s*\)\?$]=]
        )
      end
    end
    return matchstr(source, [[\\begin\*\?{.*}\s*%\s*\zs.*]])
  end
  function object:parse_frame(source)
    local caption =
      matchstr(source, [=[\\begin\*\?{.*}\%(\[[^]]*\]\)\?{\zs.\+\ze}]=])
    if caption == "" then
      caption = matchstr(source, [=[\\begin\*\?{.*}\%(\[[^]]*\]\)\?{\zs.\+]=])
    end
    if caption ~= "" then
      return caption
    end
    for lnum = vim.v.foldstart, vim.v.foldend do
      local line = vim.fn.getline(lnum)
      if matches(line, [[^\s*\\frametitle]]) then
        local title = matchstr(
          line,
          [=[^\s*\\frametitle\%(\[.*\]\)\?{\zs.\{-1,}\ze\%(}\s*\)\?$]=]
        )
        local nextline = vim.fn.getline(lnum + 1)
        if
          lnum < vim.v.foldend and matches(nextline, [[^\s*\\framesubtitle]])
        then
          return title
            .. ": "
            .. matchstr(
              nextline,
              [=[^\s*\\framesubtitle\%(\[.*\]\)\?{\zs.\{-1,}\ze\%(}\s*\)\?$]=]
            )
        end
        return title
      end
    end
    return matchstr(source, [=[\\begin\*\?{.*}\%(\[.*\]\)\?\s*%\s*\zs.*]=])
  end
  function object:text(line)
    local found = vim.fn.matchlist(line, self.re.name)
    local environment = found[2] or ""
    if not self:validate(environment) then
      return
    end
    local option, label, caption
    if environment == "frame" then
      option, label, caption = "", "", self:parse_frame(line)
    elseif environment == "table" or environment == "figure" then
      option, label, caption = "", self:parse_label(), self:parse_caption(line)
    else
      option, label, caption =
        matchstr(line, [=[\[.*\]]=]),
        self:parse_label(),
        self:parse_caption(line)
    end
    local width_rhs = 0
    if label ~= "" then
      label = "(" .. label .. ")"
      width_rhs = #label
    end
    local width_lhs = require("vimtex.ui").get_winwidth() - width_rhs - 2
    local indent = #matchstr(line, [[^\s*]])
    local title = string.rep(" ", indent)
      .. "\\begin{"
      .. environment
      .. "}"
      .. (found[3] or "")
    if option ~= "" then
      local available = width_lhs - #title
      if available >= 3 then
        title = title
          .. (
            #option > available - vim.fn.strchars(caption) and "[…]" or option
          )
      end
    end
    if caption ~= "" then
      title = vim.fn.printf("%-18S ", title)
      local available = width_lhs - vim.fn.strchars(title)
      if available >= 5 then
        if vim.fn.strchars(caption) > available then
          caption = vim.fn.strpart(caption, 0, available - 1) .. "…"
        end
        title = title .. caption
      end
    end
    return vim.fn
      .printf("%-*S %*S", width_lhs, title, width_rhs, label)
      :gsub("%s+$", "")
  end
  return object
end

constructors.items = function(cfg)
  local object =
    vim.tbl_extend("force", { name = "items", re = {}, state = {} }, cfg)
  local environments = [[\{%(]]
    .. table.concat(vim.g.vimtex_indent_lists or {}, "|")
    .. [[)\*?}]]
  object.re.env_start, object.re.env_end =
    [[\v^\s*\\begin]] .. environments, [[\v^\s*\\end]] .. environments
  object.re.fold_re, object.re.fold_re_next =
    [[^\s*\\item>]], [[^\s*\\%(item>|end]] .. environments .. [[)]]
  object.re.start, object.re["end"] =
    [[\v]] .. object.re.fold_re, [[\v]] .. object.re.fold_re_next
  function object:level(line, lnum, state)
    local env_value = state.dict.envs and state.dict.envs:level(line, lnum)
      or nil
    local nextline = vim.fn.getline(lnum + 1)
    if matches(line, self.re.env_start) then
      table.insert(self.state, { folded = false })
    elseif matches(line, self.re.env_end) then
      table.remove(self.state)
      local parent = self.state[#self.state]
      if parent and parent.folded and matches(nextline, self.re["end"]) then
        return "s2"
      end
    elseif matches(line, [[\v^\s*\\begin\{]]) then
      table.insert(self.state, {})
    elseif #self.state > 0 then
      local current = self.state[#self.state]
      if matches(line, [[\v^\s*\\end\{]]) and next(current) == nil then
        table.remove(self.state)
      elseif next(current) then
        if
          matches(line, self.re.start) and not matches(nextline, self.re["end"])
        then
          current.folded = true
          return env_value == "a1" and "a2" or "a1"
        elseif current.folded and matches(nextline, self.re["end"]) then
          current.folded = false
          return env_value == "s1" and "s2" or "s1"
        end
      end
    end
  end
  function object:text(line)
    return line
  end
  return object
end

constructors.sections = function(cfg)
  local object = vim.tbl_extend("force", {
    name = "sections",
    parse_levels = 0,
    re = {},
    folds = {},
    sections = {},
    parts = {},
    time = -1,
  }, cfg)
  object.re.parts = [[\v^\s*\\%(]] .. table.concat(object.parts, "|") .. ")"
  object.re.sections = [[\v^\s*\\%(]]
    .. table.concat(object.sections, "|")
    .. ")"
  object.re.fake_sections = [[\v^\s*\% [fF]ake%(]]
    .. table.concat(object.sections, "|")
    .. ").*"
  object.re.any_sections = [[\v^\s*%(\\|\% [fF]ake)%(]]
    .. table.concat(object.sections, "|")
    .. ").*"
  object.re.start = object.re.parts
    .. "|"
    .. object.re.sections
    .. "|"
    .. object.re.fake_sections
  object.re.secpat1, object.re.secpat2 =
    object.re.sections .. [[\*?\s*\{\zs.*]],
    object.re.sections .. [[\*?\s*\[\zs.*]]
  object.re.fold_re = [[\\%(]]
    .. table.concat(
      vim.list_extend({ unpack(object.parts) }, object.sections),
      "|"
    )
    .. ")"
  function object:refresh()
    local time = vim.api.nvim_buf_get_changedtick(0)
    if time == self.time then
      return
    end
    self.time, self.folds = time, {}
    local lines, level = vim.api.nvim_buf_get_lines(0, 0, -1, false), 0
    local part_count = 0
    for _, line in ipairs(lines) do
      if matches(line, self.re.parts) then
        part_count = part_count + 1
      end
    end
    if part_count >= 2 then
      level = level + 1
      table.insert(self.folds, 1, { self.re.parts, level })
    end
    for _, section in ipairs(self.sections) do
      local pattern = [[\v^\s*%(\\|\% [fF]ake)]] .. section .. [[:?>]]
      for _, line in ipairs(lines) do
        if matches(line, pattern) then
          level = level + 1
          table.insert(self.folds, 1, { pattern, level })
          break
        end
      end
    end
  end
  function object:level(line)
    self:refresh()
    for _, fold in ipairs(self.folds) do
      if matches(line, fold[1]) then
        return ">" .. fold[2]
      end
    end
  end
  function object:parse_title(line, pattern, delimiter)
    local title = matchstr(line, pattern)
    local finish, depth =
      require("vimtex.parser.tex").find_closing(0, title, 1, delimiter)
    local lnum = vim.v.foldstart
    while depth > 0 and lnum <= vim.v.foldend do
      lnum = lnum + 1
      local start = #title
      title = title .. vim.fn.getline(lnum)
      finish, depth = require("vimtex.parser.tex").find_closing(
        start,
        title,
        depth,
        delimiter
      )
    end
    if depth == 0 then
      title = vim.fn.strpart(title, 0, finish)
    end
    return require("vimtex.parser.tex").texorpdfstring(
      title:gsub("^%s*", ""):gsub("%s%s+", " ")
    )
  end
  function object:text(line, level)
    local title
    if matches(line, [[\\frontmatter]]) then
      title = "Frontmatter"
    elseif matches(line, [[\\mainmatter]]) then
      title = "Mainmatter"
    elseif matches(line, [[\\backmatter]]) then
      title = "Backmatter"
    elseif matches(line, [[\\appendix]]) then
      title = "Appendix"
    elseif matches(line, self.re.secpat1) then
      title = self:parse_title(line, self.re.secpat1, "{")
    elseif matches(line, self.re.secpat2) then
      title = self:parse_title(line, self.re.secpat2, "[")
    else
      title = matchstr(line, self.re.fake_sections)
    end
    title = title or ""
    return string.format("%-5s %s", level, title):gsub("%s+$", "")
  end
  return object
end

local order = {
  "comment_pkg",
  "preamble",
  "cmd_single",
  "cmd_single_opt",
  "cmd_multi",
  "cmd_addplot",
  "sections",
  "markers",
  "comments",
  "items",
  "envs",
  "env_options",
}
local function build_state()
  local state = {
    dict = {},
    ordered = {},
    fold_re = [[\v\\%(begin|end)>|^\s*\%|^\s*\]\s*%(\{|$)|^\s*}]],
    fold_re_next = "",
  }
  for name, defaults in pairs(vim.g.vimtex_fold_types_defaults or {}) do
    local cfg = config(name)
    if cfg.enabled ~= 0 and cfg.enabled ~= false and constructors[name] then
      state.dict[name] = constructors[name](cfg)
    end
  end
  for _, name in ipairs(order) do
    local object = state.dict[name]
    if object then
      table.insert(state.ordered, object)
      if object.re.fold_re then
        state.fold_re = state.fold_re .. "|" .. object.re.fold_re
      end
      if object.re.fold_re_next then
        state.fold_re_next = state.fold_re_next
          .. (state.fold_re_next == "" and [[\v]] or "|")
          .. object.re.fold_re_next
      end
    end
  end
  return state
end

function M.level(lnum)
  local state = states[vim.api.nvim_get_current_buf()]
  if not state then
    return "="
  end
  local line, nextline = vim.fn.getline(lnum), vim.fn.getline(lnum + 1)
  if
    line:find "^%s*\\begin%s*{document}"
    or line:find "^%s*\\end%s*{document}"
  then
    return 0
  end
  if
    not matches(line, state.fold_re)
    and (state.fold_re_next == "" or not matches(nextline, state.fold_re_next))
  then
    return "="
  end
  for _, object in ipairs(state.ordered) do
    local value = object:level(line, lnum, state)
    if value ~= nil and value ~= "" then
      return value
    end
  end
  return "="
end

function M.text()
  local state = states[vim.api.nvim_get_current_buf()]
  if not state then
    return vim.fn.getline(vim.v.foldstart)
  end
  local line = vim.fn.getline(vim.v.foldstart)
  local level = vim.v.foldlevel > 1
      and string.rep("-", vim.v.foldlevel - 2) .. vim.g.vimtex_fold_levelmarker
    or ""
  for _, object in ipairs(state.ordered) do
    if matches(line, object.re.start) then
      local value = object:text(line, level)
      if value and value ~= "" then
        return value
      end
    end
  end
  return line
end

function M.refresh(mapping)
  if vim.wo.diff then
    vim.wo.foldmethod = "diff"
  else
    vim.wo.foldmethod = "expr"
    vim.cmd("normal! " .. mapping)
    vim.wo.foldmethod = "manual"
  end
end

local function modeline_has_foldmethod()
  local count = vim.o.modelines
  if count == 0 then
    return false
  end
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  for index, line in ipairs(lines) do
    if
      (index <= count or index > #lines - count)
      and line:match "vim:.*f%a*m"
      and (line:match "foldmethod" or line:match "fdm")
    then
      return true
    end
  end
  return false
end

function M.init_buffer()
  if vim.g.vimtex_fold_enabled == 0 or modeline_has_foldmethod() then
    return
  end
  states[vim.api.nvim_get_current_buf()] = build_state()
  vim.wo.foldmethod, vim.wo.foldexpr, vim.wo.foldtext =
    "expr",
    "v:lua.require('vimtex.fold').level(v:lnum)",
    "v:lua.require('vimtex.fold').text()"
  if vim.g.vimtex_fold_manual == 1 then
    for _, key in ipairs { "zx", "zX" } do
      vim.keymap.set("n", key, function()
        M.refresh(key)
      end, { buffer = true, silent = true, nowait = true })
    end
    vim.api.nvim_buf_create_user_command(0, "VimtexRefreshFolds", function()
      M.refresh "zx"
    end, {})
  end
end

return M
