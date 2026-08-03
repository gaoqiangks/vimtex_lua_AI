local M = {}
local paths = require "vimtex.paths"
local parser = require "vimtex.parser"
local util = require "vimtex.util"
local complete_dir = vim.fn.fnamemodify(
  debug.getinfo(1, "S").source:sub(2),
  ":p:h:h:h"
) .. "/autoload/vimtex/complete"

local active
local texmf_cache = {}
local bib_candidate_cache = {}

local function matches(text, regex, ignore_case)
  return vim.fn.match(text, (ignore_case and [=[\c]=] or [=[\C]=]) .. regex)
    >= 0
end

local function filter(candidates, regex, options)
  options = options or {}
  local anchor = options.anchor ~= false
  local ignore_case = vim.g.vimtex_complete_ignore_case == 1
    and (
      vim.g.vimtex_complete_smart_case == 0
      or vim.fn.match(regex, [=[\u]=]) < 0
    )
  if regex:match "^[%w_:%- /]*$" then
    local needle = ignore_case and regex:lower() or regex
    return vim.tbl_filter(function(candidate)
      local value = type(candidate) == "table"
          and candidate[options.key or "word"]
        or candidate
      value = tostring(value or "")
      if ignore_case then
        value = value:lower()
      end
      return anchor and value:sub(1, #needle) == needle
        or not anchor and value:find(needle, 1, true) ~= nil
    end, candidates)
  end
  local pattern = (anchor and "^" or "") .. regex
  return vim.tbl_filter(function(candidate)
    local value = type(candidate) == "table"
        and candidate[options.key or "word"]
      or candidate
    return matches(value or "", pattern, ignore_case)
  end, candidates)
end

local function uniq(candidates)
  local seen, result = {}, {}
  for _, candidate in ipairs(candidates) do
    local key = type(candidate) == "table" and candidate.word or candidate
    if key and key ~= "" and not seen[key] then
      seen[key] = true
      table.insert(result, candidate)
    end
  end
  return result
end

local function texmf(filetype)
  if texmf_cache[filetype] then
    return vim.list_slice(texmf_cache[filetype])
  end
  local result = {}
  local home = vim.env.TEXMFHOME or ""
  if home == "" then
    home = require("vimtex.kpsewhich").run("--var-value TEXMFHOME")[1] or ""
  end
  if home ~= "" then
    for _, file in
      ipairs(vim.fn.glob(home .. "/**/*." .. filetype, false, true))
    do
      table.insert(result, vim.fn.fnamemodify(file, ":t:r"))
    end
  end
  for _, database in ipairs(require("vimtex.kpsewhich").run "--all ls-R") do
    if vim.fn.filereadable(database) == 1 then
      for _, line in ipairs(util.readfile(database)) do
        if line:match("%." .. filetype .. "$") then
          table.insert(result, vim.fn.fnamemodify(line, ":r"))
        end
      end
    end
  end
  texmf_cache[filetype] = uniq(result)
  return vim.list_slice(texmf_cache[filetype])
end

local function candidate_from_bib(entry)
  local author = (entry.author or "Unknown"):gsub("~", " ")
  local author_length = vim.g.vimtex_complete_bib.auth_len
  local substitutes = {
    ["@author_all"] = author_length > 0 and author:sub(
      1,
      vim.str_byteindex(author, "utf-32", author_length, false)
    ) or author,
    ["@author_short"] = author:gsub(",.*", " et al.", 1),
    ["@key"] = entry.key,
    ["@title"] = entry.title or "No title",
    ["@type"] = entry.type == "" and "-" or entry.type,
    ["@year"] = entry.year or entry.date or "?",
  }
  local result = { word = entry.key }
  for field, format in pairs {
    mstr = vim.g.vimtex_complete_bib.match_str_fmt,
    menu = vim.g.vimtex_complete_bib.menu_fmt,
    info = vim.g.vimtex_complete_bib.info_fmt,
    abbr = vim.g.vimtex_complete_bib.abbr_fmt,
  } do
    if format and format ~= "" then
      format = format:gsub("@[%a_]+", function(marker)
        return tostring(substitutes[marker] or marker)
      end)
      result[field] = format
    end
  end
  return result
end

local function complete_bib(regex)
  local project = require("vimtex.state").get(vim.b.vimtex_id)
  paths.pushd(vim.b.vimtex.root)
  local files = require("vimtex.bib").files()
  local signature = { vim.inspect(vim.g.vimtex_complete_bib) }
  for _, file in ipairs(files) do
    local stat = vim.uv.fs_stat(file)
    signature[#signature + 1] = file
    signature[#signature + 1] = stat
        and (stat.size .. ":" .. stat.mtime.sec .. ":" .. stat.mtime.nsec)
      or "missing"
  end
  local tex_stat = vim.uv.fs_stat(project.tex)
  signature[#signature + 1] = tex_stat
      and (tex_stat.size .. ":" .. tex_stat.mtime.sec .. ":" .. tex_stat.mtime.nsec)
    or "missing"
  signature = table.concat(signature, "\0")
  local cached = bib_candidate_cache[project.tex]
  local result
  if cached and cached.signature == signature then
    result = vim.deepcopy(cached.candidates)
  else
    result = {}
    for _, file in ipairs(files) do
      for _, entry in ipairs(parser.bib(file)) do
        table.insert(result, candidate_from_bib(entry))
      end
    end
    for _, line in ipairs(parser.tex(project.tex, { detailed = false })) do
      local key = line:find("\\bibitem", 1, true)
          and (line:match "\\bibitem%s*%b[]%s*{([^}]*)" or line:match "\\bibitem%s*{([^}]*)")
        or ""
      if key ~= "" then
        table.insert(
          result,
          candidate_from_bib {
            key = key,
            type = "thebibliography",
            author = "",
            year = "",
            title = key,
          }
        )
      end
    end
    bib_candidate_cache[project.tex] = {
      signature = signature,
      candidates = vim.deepcopy(result),
    }
  end
  paths.popd()
  if vim.g.vimtex_complete_bib.simple == 1 then
    return filter(result, regex)
  end
  return filter(result, regex, { anchor = false, key = "mstr" })
end

local function complete_ref(regex, context)
  local labels = require("vimtex.parser.auxiliary").labels()
  local words = {}
  for _, label in ipairs(labels) do
    words[label.word] = true
  end
  for _, label in ipairs(require("vimtex.parser.auxiliary").labels_manual()) do
    if not words[label.word] then
      table.insert(labels, label)
    end
  end
  local result = vim.tbl_filter(function(label)
    return matches(label.menu or "", regex, false)
  end, labels)
  if #result == 0 then
    result = vim.tbl_filter(function(label)
      return matches(label.word, regex, false)
    end, labels)
  end
  if context:find "\\eqref" then
    local equations = vim.tbl_filter(function(label)
      return label.word:match "^eq:"
    end, result)
    if #equations > 0 then
      result = equations
    end
  end
  return result
end

local function packages()
  local result = { "default", "class-" .. (vim.b.vimtex.documentclass or "") }
  vim.list_extend(result, vim.tbl_keys(vim.b.vimtex.packages or {}))
  local queue, seen = vim.list_slice(result), {}
  local index = 1
  while index <= #queue do
    local package = queue[index]
    index = index + 1
    if not seen[package] then
      seen[package] = true
      local file = complete_dir .. "/" .. package
      if vim.fn.filereadable(file) == 1 then
        for _, line in ipairs(util.readfile(file)) do
          local included = line:match "^#%s*include:%s*(.-)%s*$"
          if included and not seen[included] then
            table.insert(result, included)
            table.insert(queue, included)
          end
        end
      end
    end
  end
  return result
end

local function parse_source(lines, package)
  local result, local_commands = { cmd = {}, env = {} }, {}
  local command_re =
    [=[\v\\%(%(provide|renew|new)command|%(New|Declare|Provide|Renew)%(Expandable)?DocumentCommand|DeclarePairedDelimiter)\*?%(\{\\?\zs[^}]*|\\\zs\w+)]=]
  local environment_re =
    [=[\v\\((renew|new)environment|(New|Renew|Provide|Declare)DocumentEnvironment)\*?\{\\?\zs[^}]*]=]
  for _, line in ipairs(lines) do
    local has_backslash = line:find("\\", 1, true) ~= nil
    local command = has_backslash
        and (line:find("command", 1, true) or line:find(
          "DocumentCommand",
          1,
          true
        ) or line:find("DeclarePairedDelimiter", 1, true))
        and vim.fn.matchstr(line, command_re)
      or ""
    if command ~= "" then
      table.insert(
        result.cmd,
        { word = command, mode = ".", kind = "[cmd: " .. package .. "]" }
      )
    end
    local environment = has_backslash
        and (line:find("environment", 1, true) or line:find(
          "DocumentEnvironment",
          1,
          true
        ))
        and vim.fn.matchstr(line, environment_re)
      or ""
    if environment ~= "" then
      table.insert(
        result.env,
        { word = environment, mode = ".", kind = "[env: " .. package .. "]" }
      )
    end
    local let = has_backslash
        and (line:match "\\let[^\\]*\\([%w_]*)" or line:match "\\def[^\\]*\\([%w_]*)")
      or ""
    if let ~= "" then
      table.insert(
        local_commands,
        { word = let, mode = ".", kind = "[cmd: local]" }
      )
    end
  end
  vim.list_extend(result.cmd, local_commands)
  return result
end

local function load_package(package, kind)
  local file = complete_dir .. "/" .. package
  local lines, readable = util.readfile(file)
  if readable then
    local result = {}
    for _, line in ipairs(lines) do
      if kind == "cmd" and line:match "^%a" then
        local fields = vim.split(line, "%s+")
        table.insert(result, {
          word = fields[1],
          mode = ".",
          kind = "[cmd: " .. package .. "] ",
          menu = fields[2] or "",
        })
      elseif kind == "env" then
        local environment = line:match "^\\begin{(.-)}$"
        if environment then
          table.insert(result, {
            word = environment,
            mode = ".",
            kind = "[env: " .. package .. "] ",
          })
        end
      end
    end
    return result
  end
  local source = package:match "^class%-"
      and require("vimtex.kpsewhich").find(package:sub(7) .. ".cls")
    or require("vimtex.kpsewhich").find(package .. ".sty")
  return parse_source(util.readfile(source), package)[kind]
end

local function document_candidates(kind)
  local project = require("vimtex.state").get(vim.b.vimtex_id)
  local lines = parser.tex(project.tex, { detailed = false })
  local result = parse_source(lines, "local")[kind]
  if kind == "cmd" and (vim.b.vimtex.packages or {}).glossaries then
    local source = table.concat(lines, "\n")
    for block in source:gmatch "\\glsaddkey%s*(%b{}.-)%s*\\glsaddkey" do
      for command in block:gmatch "{\\([%a@]+)}" do
        table.insert(result, {
          word = command,
          mode = ".",
          kind = "[cmd: local]",
        })
      end
    end
    local block = source:match "\\glsaddkey%s*(%b{}.*)$"
    if block then
      for command in block:gmatch "{\\([%a@]+)}" do
        table.insert(result, {
          word = command,
          mode = ".",
          kind = "[cmd: local]",
        })
      end
    end
  end
  return result
end

local function complete_commands(regex, kind)
  local result = document_candidates(kind)
  for _, package in ipairs(packages()) do
    vim.list_extend(result, load_package(package, kind))
  end
  return filter(uniq(result), regex)
end

local function files(pattern, root, transform, kind)
  local result = {}
  for _, file in ipairs(vim.fn.globpath(root, pattern, false, true)) do
    table.insert(result, { word = transform(file), kind = kind })
  end
  return result
end

local function complete_graphics(regex)
  local result, added = {}, {}
  local roots = vim.deepcopy(vim.b.vimtex.graphicspath or {})
  table.insert(roots, vim.b.vimtex.root)
  local generated = vim.b.vimtex.compiler
      and vim.b.vimtex.compiler.get_file "pdf"
    or ""
  local extensions =
    { png = true, jpg = true, eps = true, pdf = true, pgf = true, tikz = true }
  for _, root in ipairs(roots) do
    for _, file in ipairs(vim.fn.globpath(root, "**/*.*", false, true)) do
      local extension = file:lower():match "%.([^.]+)$"
      if file ~= generated and not added[file] and extensions[extension] then
        added[file] = true
        table.insert(result, {
          abbr = paths.shorten_relative(file),
          word = paths.relative(file, root),
          kind = "[graphics]",
        })
      end
    end
  end
  return filter(result, regex)
end

local function complete_include(regex, context)
  local root, result = vim.b.vimtex.root, {}
  local all = vim.fn.globpath(root, "**/*.tex", false, true)
  if vim.b.vimtex.packages.tikz and not context:find "\\subfile" then
    vim.list_extend(all, vim.fn.globpath(root, "**/*.tikz", false, true))
  end
  for _, file in ipairs(all) do
    local word = paths.relative(file, root)
    if context:find "\\include" then
      word = vim.fn.fnamemodify(word, ":r")
    end
    table.insert(result, {
      word = word,
      kind = context:find "\\include" and "[include]" or "[input]",
    })
  end
  return filter(result, regex)
end

local glossary_types = {
  newglossaryentry = " [gls]",
  longnewglossaryentry = " [gls]",
  newacronym = " [acr]",
  newabbreviation = " [abbr]",
  glsxtrnewsymbol = " [symbol]",
}

local function complete_glossary(regex)
  local result = {}
  for _, line in ipairs(parser.tex(vim.b.vimtex.tex, { detailed = false })) do
    for command, menu in pairs(glossary_types) do
      local word = vim.fn.matchstr(
        line,
        "\\\\" .. command .. [=[\s*\%(\[.*\]\)\?\s*{\zs[^{}]*]=]
      )
      if word ~= "" then
        table.insert(result, { word = word, menu = menu })
      end
    end
  end
  for _, file in ipairs(vim.b.vimtex.glossaries or {}) do
    for _, entry in ipairs(parser.bib(file, { backend = "vim" })) do
      table.insert(result, {
        word = entry.key,
        kind = "[gls]",
        menu = " " .. (entry.name or entry.long or entry.title or ""),
      })
    end
  end
  return filter(result, regex)
end

local completers = {
  bib = {
    patterns = {
      [=[\v\\%(\a*cite|Cite)\a*\*?%(\s*\[[^]]*\]|\s*\<[^>]*\>){0,2}\s*\{[^}]*$]=],
      [=[\v\\%(\a*cites|Cites).{-}\{[^}]*$]=],
      [=[\\bibentry\s*{[^}]*$]=],
      [=[\v\\%(text|block)cquote\*?.{-}\{[^}]*$]=],
    },
    complete = complete_bib,
  },
  ref = {
    patterns = {
      [=[\v\\v?%(auto|eq|[cC]?%(page)?|labelc)?ref.{-}\{[^}]*$]=],
      [=[\\hyperref\s*\[[^]]*$]=],
      [=[\\subref\*\?{[^}]*$]=],
      [=[\\nameref{[^}]*$]=],
    },
    complete = complete_ref,
  },
  cmd = {
    patterns = { vim.g["vimtex#re#not_bslash"] .. [=[\\\a*$]=] },
    inside_braces = false,
    complete = function(regex)
      return complete_commands(regex, "cmd")
    end,
  },
  env = {
    patterns = { [=[\v\\%(begin|end)%(\s*\[[^]]*\])?\s*\{[^}]*$]=] },
    complete = function(regex)
      return complete_commands(regex, "env")
    end,
  },
  img = {
    patterns = { [=[\v\\includegraphics\*?%(\s*\[[^]]*\]){0,2}\s*\{[^}]*$]=] },
    complete = complete_graphics,
  },
  inc = {
    patterns = {
      vim.g["vimtex#re#tex_input"] .. "[^}]*$",
      [=[\v\\includeonly\s*\{[^}]*$]=],
    },
    complete = complete_include,
  },
  pdf = {
    patterns = { [=[\v\\includepdf%(\s*\[[^]]*\])?\s*\{[^}]*$]=] },
    complete = function(regex)
      return filter(
        files("**/*.pdf", vim.b.vimtex.root, function(file)
          return paths.relative(file, vim.b.vimtex.root)
        end, "[includepdf]"),
        regex
      )
    end,
  },
  sta = {
    patterns = { [=[\v\\includestandalone%(\s*\[[^]]*\])?\s*\{[^}]*$]=] },
    complete = function(regex)
      return filter(
        files("**/*.tex", vim.b.vimtex.root, function(file)
          return vim.fn.fnamemodify(
            paths.relative(file, vim.b.vimtex.root),
            ":r"
          )
        end, "[includestandalone]"),
        regex
      )
    end,
  },
  gls = {
    patterns = {
      [=[\v\\([cpdr]?(gls|Gls|GLS)|acr|Acr|ACR)\a*\s*\{[^}]*$]=],
      [=[\v\\(ac|Ac|AC)\s*\{[^}]*$]=],
    },
    complete = complete_glossary,
  },
  pck = {
    patterns = {
      [=[\v\\%(usepackage|RequirePackage)%(\s*\[[^]]*\])?\s*\{[^}]*$]=],
      [=[\v\\PassOptionsToPackage\s*\{[^}]*\}\s*\{[^}]*$]=],
    },
    complete = function(regex)
      return filter(
        vim.tbl_map(function(word)
          return { word = word, kind = "[package]" }
        end, texmf "sty"),
        regex
      )
    end,
  },
  doc = {
    patterns = {
      [=[\v\\documentclass%(\s*\[[^]]*\])?\s*\{[^}]*$]=],
      [=[\v\\PassOptionsToClass\s*\{[^}]*\}\s*\{[^}]*$]=],
    },
    complete = function(regex)
      return filter(
        vim.tbl_map(function(word)
          return { word = word, kind = "[documentclass]" }
        end, texmf "cls"),
        regex
      )
    end,
  },
  bst = {
    patterns = { [=[\v\\bibliographystyle\s*\{[^}]*$]=] },
    complete = function(regex)
      return filter(
        vim.tbl_map(function(word)
          return { word = word, kind = "[bst files]" }
        end, texmf "bst"),
        regex
      )
    end,
  },
}

local order = {
  "bib",
  "ref",
  "cmd",
  "env",
  "img",
  "inc",
  "pdf",
  "sta",
  "gls",
  "pck",
  "doc",
  "bst",
}

local function close_braces(candidates)
  if
    not vim.fn.strpart(vim.fn.getline ".", vim.fn.col "." - 1):match "^%s*[,}]"
  then
    for _, candidate in ipairs(candidates) do
      candidate.abbr = candidate.abbr or candidate.word
      candidate.word = candidate.word:gsub("}*$", "}")
    end
  end
  return candidates
end

function M.omnifunc(findstart, base)
  if findstart == 1 then
    active = nil
    local position = vim.fn.col "." - 1
    local line = vim.fn.getline("."):sub(1, position)
    for _, name in ipairs(order) do
      local completer = completers[name]
      for _, pattern in ipairs(completer.patterns) do
        if matches(line, pattern, false) then
          active = completer
          while position > 0 do
            local previous = line:sub(position, position)
            if
              previous:match "[{,%[\\]"
              or line:sub(position - 1, position) == ", "
            then
              completer.context =
                vim.fn.matchstr(line, completer.re_context or [=[\S*$]=])
              return position
            end
            position = position - 1
          end
          return -2
        end
      end
    end
    return -3
  elseif not active then
    return {}
  end
  local result = active.complete(base, active.context or "")
  return vim.g.vimtex_complete_close_braces == 1
      and active.inside_braces ~= false
      and close_braces(result)
    or result
end

function M.complete(kind, input, context)
  local completer = completers[kind]
  return completer and completer.complete(input, context or "") or {}
end

function M.init_buffer()
  if vim.g.vimtex_complete_enabled == 0 then
    return
  end
  vim.bo.omnifunc = "v:lua.require'vimtex.complete'.omnifunc"
end

return M
