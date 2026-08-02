local M = {}
local paths = require "vimtex.paths"

function M.parse_optionlist(text)
  local options = vim.empty_dict()
  for _, element in ipairs(vim.split(text or "", ",", { plain = true })) do
    element = vim.trim(element)
    if element ~= "" then
      local pair = vim.split(element, "=", { plain = true })
      if #pair == 1 then
        options[element] = true
      elseif #pair == 2 then
        local key, value = vim.trim(pair[1]), vim.trim(pair[2])
        if value:lower() == "true" then
          options[key] = true
        elseif value:lower() == "false" then
          options[key] = false
        else
          options[key] = value
        end
      end
    end
  end
  return options
end

function M.parse_documentclass(preamble)
  local class =
    vim.fn.matchstr(preamble, [[\\documentclass[^{]*{\zs[^}]\+\ze}]])
  local option_string =
    vim.fn.matchstr(preamble, [=[\\documentclass[^\[]*\[\zs[^\]]\+\ze\]]=])
  return { class, M.parse_optionlist(option_string) }
end

function M.parse_packages(preamble)
  local re = vim.g["vimtex#re#not_comment"]
    .. vim.g["vimtex#re#not_bslash"]
    .. [=[\v\\%(usep|RequireP)ackage\s*%(\[([^[\]]*)\])?\s*\{\s*\zs%([^{}]+\S)\ze\s*\}]=]
  local packages = vim.empty_dict()
  for _, match in
    ipairs(vim.fn.matchstrlist({ preamble }, re, { submatches = true }))
  do
    local options = M.parse_optionlist(match.submatches[1] or "")
    for _, package in ipairs(vim.split(match.text, ",", { plain = true })) do
      packages[vim.trim(package)] = options
    end
  end
  return packages
end

function M.parse_graphicspath(preamble, root)
  local value = vim.fn.matchstr(
    preamble,
    vim.g["vimtex#re#not_bslash"]
      .. [[\\graphicspath\s*\{\s*\{\s*\zs.{-}\ze\s*\}\s*\}]]
  )
  local result = {}
  for _, path in ipairs(vim.split(value, [[\s*}\s*{\s*]])) do
    path = vim.fn.substitute(path, [[/\s*$]], "", "")
    table.insert(
      result,
      paths.is_abs(path) and path or vim.fn.simplify(root .. "/" .. path)
    )
  end
  return result
end

function M.parse_glossaries(preamble, root, packages)
  if not packages["glossaries-extra"] then
    return {}
  end
  local searching, result = false, {}
  for _, original in ipairs(preamble) do
    local line = original
    if line:match [[^%s*\GlsXtrLoadResources%s*%[]] then
      searching = true
      line = vim.fn.matchstr(line, [[^\s*\\GlsXtrLoadResources\s*\[\zs.*]])
    end
    if searching then
      local fields = vim.split(line, "[=,]")
      local index = 1
      while index <= #fields do
        if vim.trim(fields[index]) == "src" and fields[index + 1] then
          local value =
            vim.trim(fields[index + 1]):gsub("^{", ""):gsub("[]}]%s*", "")
          if not paths.is_abs(value) then
            value = paths.join(root, value)
          end
          if vim.fn.filereadable(value) == 0 then
            value = value .. ".bib"
          end
          table.insert(result, value)
          break
        end
        index = index + 1
      end
    end
  end
  return result
end

function M.gather_sources(texfile, root)
  local sources = require("vimtex.parser.tex").parse_files(texfile, {
    root = root,
  })
  return vim.tbl_map(function(file)
    return paths.relative(file, root)
  end, sources)
end

local methods = {}

function methods.__pprint(self)
  local items = {
    { "name", self.name },
    { "base", self.base },
    { "root", self.root },
    { "tex", self.tex },
    { "main parser", self.main_parser },
  }
  if self.documentclass then
    table.insert(items, { "document class", self.documentclass })
  end
  if self.documentclass_options then
    local options = {}
    for key, value in pairs(self.documentclass_options) do
      table.insert(options, key .. "=" .. tostring(value))
    end
    table.sort(options)
    table.insert(items, { "document class options", table.concat(options) })
  end
  if self.packages and not vim.tbl_isempty(self.packages) then
    local packages = vim.tbl_keys(self.packages)
    table.sort(packages)
    table.insert(items, { "packages", table.concat(packages) })
  end
  local sources = self.get_sources()
  if #sources >= 2 then
    table.insert(items, { "source files", sources })
  end
  table.insert(items, { "compiler", self.compiler or {} })
  table.insert(items, { "viewer", self.viewer or {} })
  if self.qf and self.qf.name then
    table.insert(items, { "qf method", self.qf.name })
  end
  return { { "VimTeX project", items } }
end

function methods.cleanup(self)
  if
    self.compiler
    and self.compiler.is_running
    and self.compiler.is_running()
  then
    self.compiler.kill()
  end
  local saved = vim.b.vimtex
  vim.b.vimtex = self
  vim.api.nvim_exec_autocmds(
    "User",
    { pattern = "VimtexEventQuit", modeline = false }
  )
  vim.b.vimtex = saved
  pcall(vim.cmd, "cclose")
end

function methods.get_sources(self, options)
  options = vim.tbl_extend("force", { refresh = false }, options or {})
  if not self.__sources or options.refresh then
    self.__sources = M.gather_sources(self.tex, self.root)
  end
  return vim.deepcopy(self.__sources)
end

function methods.getftime(self)
  local result = -1
  for _, file in ipairs(self.get_sources()) do
    result = math.max(result, vim.fn.getftime(paths.join(self.root, file)))
  end
  return result
end

function methods.update_packages(self)
  if not self.compiler then
    return
  end
  for _, line in
    ipairs(require("vimtex.parser").fls(self.compiler.get_file "fls"))
  do
    local package = vim.fn.fnamemodify(
      vim.fn.matchstr(line, [[^INPUT \zs.\+\ze\.sty$]]),
      ":t"
    )
    if package ~= "" then
      self.packages[package] = {}
    end
  end
end

function methods.get_tex_program(self)
  local program = "_"
  local lines =
    require("vimtex.parser").preamble(self.tex, { root = self.root })
  for index = 1, math.min(21, #lines) do
    local value = vim.fn.matchstr(
      lines[index],
      [[\v^\c\s*\%\s*!?\s*tex\s+%(ts-)?program\s*\=\s*\zs.*$]]
    )
    if value ~= "" then
      program = value
    end
  end
  return vim.trim(program):lower()
end

function methods.is_compileable(self)
  if self.main_parser ~= "fallback current file" then
    return true
  end
  local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  return text:find "\\documentclass%s*[%[{]" ~= nil
    and text:find "\\begin%s*{document}" ~= nil
    and text:find "\\end%s*{document}" ~= nil
end

function M.new(options)
  local opts = vim.tbl_extend("force", {
    main = "",
    main_parser = "",
    preserve_root = false,
    unsupported_modules = {},
  }, options or {})
  local root = vim.fn.resolve(vim.fn.fnamemodify(opts.main, ":h"))
  local base = vim.fn.fnamemodify(opts.main, ":t")
  if opts.preserve_root and vim.b.vimtex then
    root = vim.b.vimtex.root
    base = paths.relative(opts.main, root)
  end
  local extension = vim.fn.fnamemodify(opts.main, ":e"):lower()
  local self = vim.tbl_extend("force", vim.deepcopy(methods), {
    root = root,
    base = base,
    name = vim.fn.fnamemodify(opts.main, ":t:r"),
    main_parser = opts.main_parser,
    tex = (
      vim.tbl_contains({ "tex", "latex" }, extension)
      or vim.tbl_contains({ "dtx", "tikz", "ins" }, extension)
    )
        and paths.join(root, base)
      or "",
  })
  for name, method in pairs(methods) do
    self[name] = function(...)
      local arguments = { ... }
      if arguments[1] == self then
        table.remove(arguments, 1)
      end
      return method(self, unpack(arguments))
    end
  end
  local preamble = self.tex ~= ""
      and require("vimtex.parser").preamble(self.tex, { root = root })
    or {}
  local joined = table.concat(vim.tbl_map(function(line)
    return vim.fn.substitute(line, [[\\\@<!%.*]], "", "")
  end, preamble))
  local document = M.parse_documentclass(joined)
  self.documentclass, self.documentclass_options = document[1], document[2]
  self.packages = M.parse_packages(joined)
  self.graphicspath = M.parse_graphicspath(joined, root)
  self.glossaries = M.parse_glossaries(preamble, root, self.packages)
  local unsupported = opts.unsupported_modules
  if not vim.tbl_contains(unsupported, "compiler") then
    require("vimtex.compiler").init_state(self)
  end
  if not vim.tbl_contains(unsupported, "view") then
    require("vimtex.view").init_state(self)
  end
  if not vim.tbl_contains(unsupported, "qf") then
    self.qf = require("vimtex.qf").new()
  end
  if not vim.tbl_contains(unsupported, "toc") then
    self.toc = require("vimtex.toc").new()
  end
  self.context_menu = { "cite", "glossaries" }
  self.update_packages()
  return self
end

return M
