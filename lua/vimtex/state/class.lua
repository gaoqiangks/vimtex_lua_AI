local M = {}
local paths = require "vimtex.paths"
local tex_extensions = {
  tex = true,
  latex = true,
  dtx = true,
  tikz = true,
  ins = true,
}

function M.parse_optionlist(text)
  local options = vim.empty_dict()
  for element in ((text or "") .. ","):gmatch "(.-)," do
    element = vim.trim(element)
    if element ~= "" then
      local equal = element:find("=", 1, true)
      if not equal then
        options[element] = true
      elseif not element:find("=", equal + 1, true) then
        local key = vim.trim(element:sub(1, equal - 1))
        local value = vim.trim(element:sub(equal + 1))
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

local function skip_space(text, index)
  while text:sub(index, index):match "%s" do
    index = index + 1
  end
  return index
end

function M.parse_documentclass(preamble)
  local command = "\\documentclass"
  local start = preamble:find(command, 1, true)
  if
    not start or (start > 1 and preamble:sub(start - 1, start - 1) == "\\")
  then
    return { "", M.parse_optionlist "" }
  end
  local cursor = skip_space(preamble, start + #command)
  local option_string = ""
  if preamble:sub(cursor, cursor) == "[" then
    local close = preamble:find("]", cursor + 1, true)
    if not close then
      return { "", M.parse_optionlist "" }
    end
    option_string = preamble:sub(cursor + 1, close - 1)
    cursor = skip_space(preamble, close + 1)
  end
  if preamble:sub(cursor, cursor) ~= "{" then
    return { "", M.parse_optionlist(option_string) }
  end
  local close = preamble:find("}", cursor + 1, true)
  local class = close and preamble:sub(cursor + 1, close - 1) or ""
  return { class, M.parse_optionlist(option_string) }
end

local function parse_package_command(text, index)
  local cursor = skip_space(text, index)
  local option_text = ""
  if text:sub(cursor, cursor) == "[" then
    local close = text:find("]", cursor + 1, true)
    if not close then
      return index
    end
    option_text = text:sub(cursor + 1, close - 1)
    cursor = skip_space(text, close + 1)
  end
  if text:sub(cursor, cursor) ~= "{" then
    return index
  end
  local close = text:find("}", cursor + 1, true)
  if not close then
    return index
  end
  return close + 1, text:sub(cursor + 1, close - 1), option_text
end

function M.parse_packages(preamble)
  local packages = vim.empty_dict()
  local index = 1
  while true do
    local use = preamble:find("\\usepackage", index, true)
    local require_package = preamble:find("\\RequirePackage", index, true)
    local start
    if use and require_package then
      start = math.min(use, require_package)
    else
      start = use or require_package
    end
    if not start then
      break
    end

    local command = start == use and "\\usepackage" or "\\RequirePackage"
    index = start + #command
    if start == 1 or preamble:sub(start - 1, start - 1) ~= "\\" then
      local names, option_text
      index, names, option_text = parse_package_command(preamble, index)
      if names then
        local options = M.parse_optionlist(option_text)
        for package_name in names:gmatch "[^,]+" do
          local trimmed = vim.trim(package_name)
          if trimmed ~= "" then
            packages[trimmed] = options
          end
        end
      end
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
    path = path:gsub("/%s*$", "")
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
    local resources = line:match "^%s*\\GlsXtrLoadResources%s*%[(.*)"
    if resources then
      searching = true
      line = resources
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

local function strip_comment(line)
  local start = 1
  while true do
    local index = line:find("%", start, true)
    if not index then
      return line
    end
    if index == 1 or line:sub(index - 1, index - 1) ~= "\\" then
      return line:sub(1, index - 1)
    end
    start = index + 1
  end
end

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
  return vim.list_slice(self.__sources)
end

function methods.getftime(self)
  local result = -1
  for _, file in ipairs(self.get_sources()) do
    local stat = vim.uv.fs_stat(paths.join(self.root, file))
    if stat then
      result = math.max(result, stat.mtime.sec + stat.mtime.nsec / 1e9)
    end
  end
  return result
end

function methods.update_packages(self)
  if not self.compiler then
    return
  end
  local lines = self.compiler.read_file and self.compiler.read_file "fls"
    or require("vimtex.parser").fls(self.compiler.get_file "fls")
  for _, line in ipairs(lines) do
    if line:sub(1, 6) == "INPUT " and line:sub(-4) == ".sty" then
      local package = line:sub(7, -5):match "[^/\\]+$"
      if package then
        self.packages[package] = {}
      end
    end
  end
end

function methods.get_tex_program(self)
  local program = "_"
  local lines =
    require("vimtex.parser").preamble(self.tex, { root = self.root })
  for index = 1, math.min(21, #lines) do
    local line = lines[index]:lower()
    local value = line:match "^%s*%%%s*!?%s*tex%s+ts%-program%s*=%s*(.+)$"
      or line:match "^%s*%%%s*!?%s*tex%s+program%s*=%s*(.+)$"
    if value then
      program = value
    end
  end
  return vim.trim(program)
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
  local self = {
    root = root,
    base = base,
    name = vim.fn.fnamemodify(opts.main, ":t:r"),
    main_parser = opts.main_parser,
    tex = tex_extensions[extension] and paths.join(root, base) or "",
  }
  for name, method in pairs(methods) do
    self[name] = function(...)
      if select(1, ...) == self then
        return method(self, select(2, ...))
      end
      return method(self, ...)
    end
  end
  local preamble = opts.preamble
    or (
      self.tex ~= ""
        and require("vimtex.parser").preamble(self.tex, { root = root })
      or {}
    )
  local uncommented = {}
  for index, line in ipairs(preamble) do
    uncommented[index] = strip_comment(line)
  end
  local joined = table.concat(uncommented)
  local document = M.parse_documentclass(joined)
  self.documentclass, self.documentclass_options = document[1], document[2]
  self.packages = M.parse_packages(joined)
  self.graphicspath = M.parse_graphicspath(joined, root)
  self.glossaries = M.parse_glossaries(preamble, root, self.packages)
  local unsupported = {}
  for _, name in ipairs(opts.unsupported_modules) do
    unsupported[name] = true
  end
  if vim.g.vimtex_compiler_enabled ~= 0 and not unsupported.compiler then
    require("vimtex.compiler").init_state(self)
  end
  if vim.g.vimtex_view_enabled ~= 0 and not unsupported.view then
    require("vimtex.view").init_state(self)
  end
  if not unsupported.qf then
    self.qf = require("vimtex.qf").new()
  end
  if not unsupported.toc then
    self.toc = require("vimtex.toc").new()
  end
  self.context_menu = { "cite", "glossaries" }
  self.update_packages()
  return self
end

return M
