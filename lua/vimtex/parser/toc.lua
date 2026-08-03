local M = {}

local fn = vim.fn
local util = require "vimtex.util"
local paths = require "vimtex.paths"
local tex = require "vimtex.parser.tex"
local fixme = require "vimtex.parser.fixme"
local auxiliary = require "vimtex.parser.auxiliary"

local matcher_names = {
  "beamer_frame",
  "bibliography",
  "comment",
  "include",
  "include_biblatex",
  "include_bibtex",
  "include_graphics",
  "include_vimtex",
  "index",
  "labels",
  "parts",
  "preamble",
  "section",
  "table_of_contents",
  "titlepage",
  "todo_comments",
  "todo_fixme",
  "todo_notes",
}

local sec_to_value = {
  ["_"] = 0,
  subparagraph = 1,
  paragraph = 2,
  subsubsubsubsection = 3,
  subsubsubsection = 4,
  subsubsection = 5,
  subsection = 6,
  section = 7,
  chapter = 8,
  part = 9,
}

local function matches(text, pattern)
  return fn.match(text, pattern) >= 0
end

local function matchstr(text, pattern)
  return fn.matchstr(text, pattern)
end

local function trim(text)
  return vim.trim(text or "")
end

local function is_empty(value)
  return fn.empty(value) == 1
end

local function short_path(file)
  if #file < 70 then
    return file
  end
  return file:sub(1, 31) .. "..." .. file:sub(-36)
end

local function find_closing(text, count, delimiter)
  return tex.find_closing(0, text, count, delimiter)
end

local function call_matcher(matcher, method, ...)
  local callback = matcher[method]
  if callback == nil then
    return nil
  end
  if type(callback) == "function" then
    return callback(matcher, ...)
  end
  return fn.call(callback, { ... }, matcher)
end

local level = {}

local level_names = {
  "preamble",
  "frontmatter",
  "mainmatter",
  "appendix",
  "backmatter",
  "part",
  "chapter",
  "section",
  "subsection",
  "subsubsection",
  "subsubsubsection",
  "paragraph",
  "subparagraph",
}

local reset_after = {
  chapter = {
    "section",
    "subsection",
    "subsubsection",
    "subsubsubsection",
    "paragraph",
    "subparagraph",
  },
  section = {
    "subsection",
    "subsubsection",
    "subsubsubsection",
    "paragraph",
    "subparagraph",
  },
  subsection = {
    "subsubsection",
    "subsubsubsection",
    "paragraph",
    "subparagraph",
  },
  subsubsection = { "subsubsubsection", "paragraph", "subparagraph" },
  subsubsubsection = { "paragraph", "subparagraph" },
  paragraph = { "subparagraph" },
}

function level:reset(part, current)
  if part == "preamble" then
    self.old = {}
  else
    self.old[#self.old + 1] = {
      frontmatter = self.frontmatter,
      mainmatter = self.mainmatter,
      appendix = self.appendix,
      backmatter = self.backmatter,
    }
  end

  for _, name in ipairs(level_names) do
    self[name] = 0
  end
  self.current = current
  self[part] = 1
end

function level:increment(name)
  self.current = M.level(name)
  self.part_toggle = 0

  if name == "part" then
    self.part = self.part + 1
    self.part_toggle = 1
  else
    self[name] = self[name] + 1
    for _, child in ipairs(reset_after[name] or {}) do
      self[child] = 0
    end
  end
end

function level:set_current(name)
  self.current = M.level(name)
end

local function default_entry(matcher, context)
  return {
    title = matcher.title,
    number = "",
    file = context.file,
    line = context.lnum,
    rank = context.lnum_total,
    level = 0,
    type = "content",
  }
end

local constructors = {}

constructors.beamer_frame = function()
  local matcher = {
    prefilter_cmds = { "begin" },
    priority = 0,
    re = [=[^\s*\\begin{frame}]=],
    re_end = [=[^\s*\\end{frame}]=],
    re_match = [=[^\s*\\begin{frame}\%(\[[^]]\+\]\)\?{\zs.*\ze}\s*$]=],
  }
  function matcher:init()
    self.number, self.title, self.subtitle = 0, "", ""
  end
  function matcher:get_title()
    local suffix = ""
    if self.title ~= "" and self.subtitle ~= "" then
      suffix = ": " .. self.title .. " - " .. self.subtitle
    elseif self.title ~= "" then
      suffix = ": " .. self.title
    elseif self.subtitle ~= "" then
      suffix = ": " .. self.subtitle
    end
    return ("Frame %d%s"):format(self.number, suffix)
  end
  function matcher:get_entry(context)
    self.number = self.number + 1
    self.title, self.subtitle = "", ""
    local parts = fn.split(matchstr(context.line, self.re_match), [=[}\s*{]=])
    self.title = trim(parts[1])
    self.subtitle = trim(parts[2])
    if self.title == "" then
      context.continue = "beamer_frame"
    end
    return {
      title = self:get_title(),
      number = "",
      file = context.file,
      line = context.lnum,
      level = context.max_level - context.level.current,
      rank = context.lnum_total,
      type = "content",
    }
  end
  function matcher:continue_entry(context)
    if self.title == "" then
      self.title =
        trim(matchstr(context.line, [=[^\s*\\frametitle\s*{\zs[^}]*]=]))
    end
    if self.subtitle == "" then
      self.subtitle =
        trim(matchstr(context.line, [=[^\s*\\framesubtitle\s*{\zs[^}]*]=]))
    end
    if
      (self.title ~= "" and self.subtitle ~= "")
      or matches(context.line, self.re_end)
    then
      context.entry.title = self:get_title()
      context.continue = nil
    end
  end
  return matcher
end

constructors.bibliography = function()
  local matcher = {
    prefilter_cmds = { "printbib", "begin", "bibliography" },
    priority = 0,
    re = [=[\v^\s*\\%(printbib%(liography|heading)\s*(\{|\[)?|begin\s*\{\s*thebibliography\s*\}|bibliography\s*\{)]=],
    re_biblatex = [=[\v^\s*\\printbib%(liography|heading)]=],
  }
  function matcher:parse_options(context, entry)
    local opts = {}
    for _, item in ipairs(util.texsplit(self.options)) do
      local pair = fn.split(item, "=")
      local key = trim(pair[1] or "")
      local value = trim(pair[2] or ""):gsub("[{}]", "")
      opts[key] = value
    end
    local heading = opts.heading or ""
    entry.added_to_toc = matches(heading, [=[intoc\|numbered]=])
    if matches(heading, [=[\v%(sub)?bibnumbered]=]) then
      local levels = context.level.chapter > 0 and { "chapter", "section" }
        or { "section", "subsection" }
      context.level:increment(levels[heading:match "^sub" and 2 or 1])
      entry.level = context.max_level - context.level.current
      entry.number = vim.deepcopy(context.level)
    end
    entry.title = opts.title
      or (heading:match "^sub" and "References" or "Bibliography")
  end
  function matcher:get_entry(context)
    local entry = {
      title = "Bibliography",
      number = "",
      file = context.file,
      line = context.lnum,
      rank = context.lnum_total,
      level = 0,
      type = "content",
    }
    if not matches(context.line, self.re_biblatex) then
      return entry
    end
    self.options = matchstr(context.line, self.re_biblatex .. [=[\s*\[\zs.*]=])
    local ending, count =
      find_closing(self.options, self.options ~= "" and 1 or 0, "[")
    if count == 0 then
      self.options = self.options:sub(1, ending)
      self:parse_options(context, entry)
    else
      self.count = count
      context.continue = "bibliography"
    end
    return entry
  end
  function matcher:continue_entry(context)
    local ending, count = find_closing(context.line, self.count, "[")
    if count == 0 then
      self.options = self.options .. context.line:sub(1, ending)
      context.continue = nil
      self:parse_options(context, context.entry)
    else
      self.options = self.options .. context.line
      self.count = count
    end
  end
  function matcher:filter(entries)
    local has_toc = false
    for _, entry in ipairs(entries) do
      has_toc = has_toc or entry.added_to_toc == true
    end
    if has_toc then
      for index = #entries, 1, -1 do
        if entries[index].added_to_toc == false then
          table.remove(entries, index)
        end
      end
    end
  end
  return matcher
end

constructors.comment = function()
  local matcher = {
    in_preamble = 1,
    prefilter_cmds = { "begin" },
    re = [=[^\s*\\begin{comment}]=],
    re_end = [=[^\s*\\end{comment}]=],
  }
  function matcher:get_entry(context)
    context.continue = "comment"
    return {}
  end
  function matcher:continue_entry(context)
    if matches(context.line, self.re_end) then
      context.continue = nil
    end
  end
  return matcher
end

constructors.include = function()
  local matcher = {
    in_preamble = 1,
    prefilter_cmds = { "input", "include", "import", "subfile" },
    priority = 0,
    re = vim.g["vimtex#re#tex_input"] .. [=[\zs\f{-}\s*\ze\}]=],
  }
  function matcher:get_entry(context)
    local result =
      tex.input_parser(context.line, context.file, vim.b.vimtex.root)
    local file = fn.simplify(fn.fnamemodify(result.file, ":~:."))
    return {
      title = "tex incl: " .. short_path(file),
      number = "",
      file = file,
      line = 1,
      level = context.max_level - context.level.current,
      rank = context.lnum_total,
      type = "include",
    }
  end
  return matcher
end

constructors.include_biblatex = function()
  local matcher = {
    in_preamble = 1,
    in_content = 0,
    prefilter_cmds = { "add%(global|section)?bib" },
    priority = 0,
    re = [=[\v^\s*\\add(bibresource|globalbib|sectionbib)\s*\{\zs[^}]+\ze\}]=],
  }
  function matcher:get_entry(context)
    local file = matchstr(context.line, self.re)
    if fn.filereadable(file) == 0 then
      file = require("vimtex.kpsewhich").find(file)
    end
    return {
      title = ("bib incl: %-.67s"):format(fn.fnamemodify(file, ":t")),
      number = "",
      file = file,
      line = 1,
      level = 0,
      rank = context.lnum_total,
      type = "include",
      link = 1,
    }
  end
  return matcher
end

constructors.include_bibtex = function()
  local matcher = {
    in_preamble = 1,
    prefilter_cmds = { "bibliography" },
    priority = 0,
    re = [=[\v^\s*\\bibliography\s*\{\zs[^}]+\ze\}]=],
  }
  function matcher:get_entry(context)
    local entries = {}
    for _, name in ipairs(fn.split(matchstr(context.line, self.re), ",")) do
      local file = name:match "%.bib$" and name or name .. ".bib"
      if fn.filereadable(file) == 0 then
        file = require("vimtex.kpsewhich").find(file)
      end
      entries[#entries + 1] = {
        title = ("bib incl: %-.67s"):format(fn.fnamemodify(file, ":t")),
        number = "",
        file = file,
        line = 1,
        level = 0,
        rank = context.lnum_total,
        type = "include",
        link = 1,
      }
    end
    return entries
  end
  return matcher
end

constructors.include_graphics = function()
  local matcher = {
    prefilter_cmds = { "includegraphics" },
    priority = 1,
    re = [=[\v^\s*\\includegraphics\*?%(\s*\[[^]]*\]){0,2}\s*\{\zs[^}]*]=],
  }
  function matcher:get_entry(context)
    local file = matchstr(context.line, self.re)
    if not paths.is_abs(file) then
      file = require("vimtex.misc").get_graphicspath(file)
    end
    file = fn.fnamemodify(file, ":~:.")
    local extension = fn.fnamemodify(file, ":e")
    if
      fn.filereadable(file) == 0 or (extension ~= "asy" and extension ~= "tikz")
    then
      return {}
    end
    return {
      title = "fig incl: " .. short_path(file),
      number = "",
      file = file,
      line = 1,
      level = context.max_level - context.level.current,
      rank = context.lnum_total,
      type = "include",
      link = 1,
    }
  end
  return matcher
end

constructors.include_vimtex = function()
  local matcher = {
    in_preamble = 1,
    prefilter_re = [=[^\s*\%\s*vimtex-include]=],
    priority = 1,
    re = [=[^\s*%\s*vimtex-include:\?\s\+\zs\f\+]=],
  }
  function matcher:get_entry(context)
    local file = matchstr(context.line, self.re)
    if not paths.is_abs(file) then
      file = vim.b.vimtex.root .. "/" .. file
    end
    file = fn.fnamemodify(file, ":~:.")
    return {
      title = "vtx incl: " .. short_path(file),
      number = "",
      file = file,
      line = 1,
      level = context.max_level - context.level.current,
      rank = context.lnum_total,
      type = "include",
      link = 1,
    }
  end
  return matcher
end

constructors.index = function()
  return {
    title = "Alphabetical index",
    prefilter_cmds = { "printindex" },
    priority = 0,
    re = [=[\v^\s*\\printindex\[]=],
  }
end

constructors.labels = function()
  local matcher = {
    label_dict = {},
    prefilter_cmds = { "label" },
    priority = 1,
    re = vim.g["vimtex#re#not_comment"] .. [=[\\label\{\zs.{-}\ze\}]=],
    format = "%s%s",
  }
  function matcher:init()
    self.label_dict = {}
    for _, item in ipairs(auxiliary.labels()) do
      self.label_dict[item.word] = " (" .. item.menu .. ")"
    end
    local wininfo = fn.getwininfo(fn.win_getid())[1]
    local width = wininfo.width - wininfo.textoff - 2
    if (vim.g.vimtex_toc_config.split_pos or ""):find("vert", 1, true) then
      width = vim.g.vimtex_toc_config.split_width
    end
    width = width - 10
    local first = math.floor(width / 2)
    self.format = "%-" .. first .. "s%" .. (width - first) .. "s"
  end
  function matcher:get_entry(context)
    local key = matchstr(context.line, self.re)
    return {
      title = self.format:format(key, self.label_dict[key] or ""),
      number = "",
      file = context.file,
      line = context.lnum,
      level = context.max_level - context.level.current,
      rank = context.lnum_total,
      type = "label",
    }
  end
  return matcher
end

constructors.parts = function()
  local matcher = {
    re = [=[\v^\s*\\\zs((front|main|back)matter|appendix)>]=],
    prefilter_cmds = { "%(front|main|back)matter", "appendix" },
    priority = 0,
  }
  function matcher:get_entry(context)
    context.level:reset(matchstr(context.line, self.re), context.max_level)
    return {}
  end
  return matcher
end

constructors.preamble = function()
  return {
    disable = vim.g.vimtex_toc_show_preamble == 0
      or vim.g.vimtex_toc_show_preamble == false,
    in_preamble = 1,
    in_content = 0,
    prefilter_cmds = { "documentclass" },
    priority = 0,
    re = [=[\v^\s*\\documentclass]=],
    get_entry = function(_, context)
      return {
        title = "Preamble",
        number = "",
        file = context.file,
        line = context.lnum,
        level = 0,
        rank = context.lnum_total,
        type = "content",
      }
    end,
  }
end

local function parse_title(title)
  title = fn.substitute(title, [=[\v%(\]|\})\s*$]=], "", "")
  title = fn.substitute(title, [=[^\s*]=], "", "")
  title = fn.substitute(title, [=[\s\{2,}]=], " ", "g")
  return tex.texorpdfstring(title)
end

constructors.section = function()
  local matcher = {
    prefilter_cmds = {
      "part",
      "chapter",
      "%(sub)*section",
      "%(sub)?paragraph",
      "add%(part|chap|sec)",
    },
    priority = 0,
    re = [=[\v^\s*\\%(part|chapter|%(sub)*section|%(sub)?paragraph|add%(part|chap|sec))\*?\s*(\[|\{)]=],
    re_starred = [=[\v^\s*\\%(%(part|chapter|%(sub)*section)\*|add%(part|chap|sec))]=],
    re_level = [=[\v^\s*\\\zs%(part|chapter|%(sub)*section|%(sub)?paragraph|add%(part|chap|sec))]=],
  }
  function matcher:level_name(line)
    local name = matchstr(line, self.re_level)
    return ({ addpart = "part", addchap = "chapter", addsec = "section" })[name]
      or name
  end
  function matcher:get_entry(context)
    local level_name = self:level_name(context.line)
    local captures = fn.matchlist(context.line, self.re)
    local delimiter = captures[2]
    local title = matchstr(context.line, self.re .. [=[\zs.{-}\ze\%?\s*$]=])
    local number = ""
    local ending, count = find_closing(title, 1, delimiter)
    if count == 0 then
      title = parse_title(title:sub(1, ending + 1))
    else
      self.delimiter, self.count = delimiter, count
      context.continue = "section"
    end
    if matches(context.line, self.re_starred) then
      context.level:set_current(level_name)
    else
      context.level:increment(level_name)
      if not matches(context.line, [=[\v^\s*\\%(sub)?paragraph]=]) then
        number = vim.deepcopy(context.level)
      end
    end
    return {
      title = title,
      number = number,
      file = context.file,
      line = context.lnum,
      level = context.max_level - context.level.current,
      rank = context.lnum_total,
      type = "content",
    }
  end
  function matcher:continue_entry(context)
    local ending, count = find_closing(context.line, self.count, self.delimiter)
    if count == 0 then
      context.entry.title =
        parse_title(context.entry.title .. context.line:sub(1, ending + 1))
      context.continue = nil
    else
      context.entry.title = context.entry.title .. context.line
      self.count = count
    end
  end
  return matcher
end

constructors.table_of_contents = function()
  return {
    title = "Table of contents",
    prefilter_cmds = { "tableofcontents" },
    priority = 0,
    re = [=[\v^\s*\\tableofcontents]=],
  }
end

constructors.titlepage = function()
  return {
    title = "Titlepage",
    prefilter_cmds = { "begin" },
    priority = 0,
    re = [=[\v^\s*\\begin\{titlepage\}]=],
  }
end

constructors.todo_comments = function()
  local labels = vim.g.vimtex_toc_todo_labels or {}
  local keys = vim.tbl_keys(labels)
  local matcher = {
    in_preamble = 1,
    prefilter_re = [=[\%\s*%(]=] .. table.concat(keys, "|") .. ")",
    priority = 2,
    re = vim.g["vimtex#re#not_bslash"] .. [=[\%\s*(]=] .. table.concat(
      keys,
      "|"
    ) .. [=[)[ :]+\s*(.*)]=],
  }
  function matcher:get_entry(context)
    local captures = fn.matchlist(context.line, self.re)
    local kind, text = captures[2], captures[3]
    return {
      title = (vim.g.vimtex_toc_todo_labels[kind:upper()] or "") .. text,
      number = "",
      file = context.file,
      line = context.lnum,
      level = context.max_level - context.level.current,
      rank = context.lnum_total,
      type = "todo",
    }
  end
  return matcher
end

constructors.todo_fixme = function()
  local matcher = { priority = 2 }
  function matcher:init()
    local authors = fixme.authors()
    self.re_cmd = [=[\v\\%(]=]
      .. table.concat(authors.cmd, "|")
      .. [=[)%(warning|error|fatal|note)\*?%(\[[^]]*\])?\{\zs.*]=]
    self.re_env = [=[\v\\begin\s*\{%(]=]
      .. table.concat(authors.env, "|")
      .. [=[)%(warning|error|fatal|note)\*?\}]=]
    self.re = self.re_cmd .. "|" .. self.re_env
    self.prefilter_cmds = { "begin" }
    for _, prefix in ipairs(authors.cmd) do
      self.prefilter_cmds[#self.prefilter_cmds + 1] = prefix
        .. "%(warning|error|fatal|note)"
    end
  end
  function matcher:get_entry(context)
    local title, label
    if matches(context.line, self.re_cmd) then
      title = matchstr(context.line, self.re_cmd)
      label =
        matchstr(context.line, [=[\v\\\zs\a+%(note|warning|error|fatal)]=])
    else
      title = matchstr(context.line, self.re_env .. [=[\s*\{\zs.*]=])
      label = matchstr(context.line, [=[\v\a+%(note|warning|error|fatal)]=])
    end
    local ending, count = find_closing(title, 1, "{")
    if count == 0 then
      title = title:sub(1, ending)
    else
      self.count = count
      context.continue = "todo_fixme"
    end
    return {
      title = label .. ": " .. title,
      number = "",
      file = context.file,
      line = context.lnum,
      level = context.max_level - context.level.current,
      rank = context.lnum_total,
      type = "todo",
    }
  end
  function matcher:continue_entry(context)
    local ending, count = find_closing(context.line, self.count, "{")
    if count == 0 then
      context.entry.title = context.entry.title .. context.line:sub(1, ending)
      context.continue = nil
    else
      context.entry.title = context.entry.title .. context.line
      self.count = count
    end
  end
  return matcher
end

constructors.todo_notes = function()
  local matcher = {
    prefilter_cmds = { "todo" },
    priority = 2,
    re = vim.g["vimtex#re#not_comment"]
      .. [=[\\\w*todo\w*%(\[[^]]*\])?\{\zs.*]=],
  }
  function matcher:get_entry(context)
    local title = matchstr(context.line, self.re)
    local ending, count = find_closing(title, 1, "{")
    if count == 0 then
      title = title:sub(1, ending)
    else
      self.count = count
      context.continue = "todo_notes"
    end
    return {
      title = (vim.g.vimtex_toc_todo_labels.TODO or "TODO: ") .. title,
      number = "",
      file = context.file,
      line = context.lnum,
      level = context.max_level - context.level.current,
      rank = context.lnum_total,
      type = "todo",
    }
  end
  function matcher:continue_entry(context)
    local ending, count = find_closing(context.line, self.count, "{")
    if count == 0 then
      context.entry.title = context.entry.title .. context.line:sub(1, ending)
      context.continue = nil
    else
      context.entry.title = context.entry.title .. context.line
      self.count = count
    end
  end
  return matcher
end

function M.level(name)
  local value = sec_to_value[name]
  assert(value, "Unknown section level: " .. tostring(name))
  return value
end

function M.get_topmatters()
  local total = level.frontmatter
    + level.mainmatter
    + level.appendix
    + level.backmatter
  for _, old in ipairs(level.old or {}) do
    total = total
      + old.frontmatter
      + old.mainmatter
      + old.appendix
      + old.backmatter
  end
  return total
end

function M.get_matchers()
  local matchers = { all = {}, preamble = {}, content = {}, d = {} }
  local overrides = vim.g.vimtex_toc_config_matchers or {}
  for _, name in ipairs(matcher_names) do
    local matcher = constructors[name]()
    matcher = vim.tbl_deep_extend("force", matcher, overrides[name] or {})
    matcher.name = name
    matchers.all[#matchers.all + 1] = matcher
  end
  for _, matcher in ipairs(vim.g.vimtex_toc_custom_matchers or {}) do
    matchers.all[#matchers.all + 1] = matcher
  end
  for index = #matchers.all, 1, -1 do
    if
      matchers.all[index].disable == true or matchers.all[index].disable == 1
    then
      table.remove(matchers.all, index)
    end
  end
  local custom = 1
  for _, matcher in ipairs(matchers.all) do
    if matcher.name == nil then
      matcher.name = "custom" .. custom
      custom = custom + 1
    end
    matchers.d[matcher.name] = matcher
  end
  table.sort(matchers.all, function(first, second)
    return (first.priority or 0) < (second.priority or 0)
  end)
  for _, matcher in ipairs(matchers.all) do
    call_matcher(matcher, "init")
    if matcher.get_entry == nil then
      matcher.get_entry = default_entry
    end
    if matcher.in_preamble == true or matcher.in_preamble == 1 then
      matchers.preamble[#matchers.preamble + 1] = matcher
    end
    if
      matcher.in_content == nil
      or matcher.in_content == true
      or matcher.in_content == 1
    then
      matchers.content[#matchers.content + 1] = matcher
    end
  end
  local commands, fragments = {}, {}
  for _, matcher in ipairs(matchers.all) do
    vim.list_extend(commands, matcher.prefilter_cmds or {})
    if matcher.prefilter_re then
      fragments[#fragments + 1] = matcher.prefilter_re
    end
  end
  matchers.prefilter = [=[\v\\%(]=]
    .. table.concat(util.uniq_unsorted(commands), "|")
    .. ")"
  if #fragments > 0 then
    matchers.prefilter = matchers.prefilter
      .. "|"
      .. table.concat(fragments, "|")
  end
  return matchers
end

function M.parse(file)
  local entries = {}
  local content = tex.parse(file)
  local matchers = M.get_matchers()
  local max_level = 0
  for _, item in ipairs(content) do
    if matches(item[3], matchers.d.section.re) then
      max_level =
        math.max(max_level, M.level(matchers.d.section:level_name(item[3])))
    end
  end
  level:reset("preamble", max_level)
  if #content == 0 then
    return entries
  end

  local context = {}
  local matcher_list = matchers.preamble
  for total, item in ipairs(content) do
    local file_name, line_number, line_text = item[1], item[2], item[3]
    if context.continue then
      context.line = line_text
      context.lnum = line_number
      context.lnum_total = total
      context.entry = entries[#entries] or {}
      call_matcher(matchers.d[context.continue], "continue_entry", context)
    else
      context = {
        file = file_name,
        line = line_text,
        lnum = line_number,
        lnum_total = total,
        level = level,
        max_level = max_level,
        entry = entries[#entries] or {},
        num_entries = #entries,
      }
      if
        level.preamble == 1
        and matches(line_text, [=[\v^\s*\\begin\{document\}]=])
      then
        level.preamble = 0
        matcher_list = matchers.content
      elseif matches(line_text, matchers.prefilter) then
        for _, matcher in ipairs(matcher_list) do
          if matches(line_text, matcher.re) then
            local entry = call_matcher(matcher, "get_entry", context)
            if type(entry) == "table" and vim.islist(entry) then
              vim.list_extend(entries, entry)
            elseif type(entry) == "table" and not is_empty(entry) then
              entries[#entries + 1] = entry
            end
          end
        end
      end
    end
  end
  for _, matcher in ipairs(matchers.all) do
    call_matcher(matcher, "filter", entries)
  end
  return entries
end

return M
