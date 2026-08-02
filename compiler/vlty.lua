if vim.b.current_compiler then
  return
end
vim.b.current_compiler = "vlty"

require("vimtex.options").init()
local jobs = require "vimtex.jobs"
local ui = require "vimtex.ui"

local function fail(message)
  vim.notify(
    "vlty compiler - " .. message .. "; see :help vimtex-grammar-vlty",
    vim.log.levels.ERROR
  )
end

local python = vim.g.python3_host_prog
  or (vim.fn.executable "python3" == 1 and "python3" or "python")
if vim.fn.executable(python) ~= 1 then
  fail "requires Python"
  return
end

local function check_python(code)
  return jobs.run(
    vim.fn.shellescape(python) .. " -c " .. vim.fn.shellescape(code)
  ).code ~= 0
end

if check_python "import sys; assert sys.version_info >= (3, 6)" then
  fail "requires at least Python version 3.6"
  return
end
if check_python "import yalafi" then
  fail "requires the Python module YaLafi"
  return
end

local config = vim.deepcopy(vim.g.vimtex_grammar_vlty)
config.lt_command = config.lt_command or ""
local language_tool = ""
if config.server ~= "lt" then
  if config.lt_command ~= "" then
    if vim.fn.executable(config.lt_command) ~= 1 then
      fail "lt_command is not executable"
      return
    end
    language_tool = config.lt_command
  else
    if vim.fn.executable "java" ~= 1 then
      fail "requires Java"
      return
    end
    local jar = vim.fn.fnamemodify(
      config.lt_directory .. "/languagetool-commandline.jar",
      ":p"
    )
    if vim.fn.filereadable(jar) ~= 1 then
      fail "lt_directory path is not valid"
      return
    end
    language_tool = "java -jar " .. vim.fn.shellescape(jar)
  end
end

local state = vim.b.vimtex
state = type(state) == "table" and state
  or { documentclass = "", packages = {} }
local packages = table.concat(vim.tbl_keys(state.packages or {}), ",")
if config.language == nil then
  config.language =
    ui.select(vim.split(vim.wo.spelllang, ",", { plain = true }), {
      prompt = "Multiple spelllang languages detected, please select one:",
      force_choice = true,
    })
end

local language_option
if config.language == "" then
  vim.notify(
    "Set g:vimtex_grammar_vlty.language for more accurate checks; using autoDetect",
    vim.log.levels.WARN
  )
  language_option = " --autoDetect"
else
  config.language = config.language:gsub("_", "-")
  language_option = " --language " .. config.language
  if language_tool ~= "" then
    local available = vim.tbl_map(function(line)
      return vim.split(line, "%s+")[1]
    end, jobs.capture(language_tool .. " --list NOFILE"))
    local found = false
    for _, language in ipairs(available) do
      if language:lower() == config.language:lower() then
        found = true
      end
    end
    if #available > 0 and not found then
      vim.notify(
        "Language '" .. config.language .. "' is not listed by LanguageTool",
        vim.log.levels.WARN
      )
      if config.language:find("-", 1, true) then
        config.language = config.language:match "^[^-]+"
        language_option = " --language " .. config.language
      end
    end
  end
end

local encoding = config.encoding == "auto"
    and (vim.bo.fileencoding ~= "" and vim.bo.fileencoding or vim.o.encoding)
  or config.encoding
vim.bo.makeprg = table.concat({
  vim.fn.shellescape(python),
  "-m yalafi.shell",
  config.lt_command ~= "" and "--lt-command " .. config.lt_command
    or "--lt-directory " .. config.lt_directory,
  config.server == "no" and "" or "--server " .. config.server,
  "--encoding " .. encoding,
  language_option,
  '--disable "' .. config.lt_disable .. '"',
  '--enable "' .. config.lt_enable .. '"',
  '--disablecategories "' .. config.lt_disablecategories .. '"',
  '--enablecategories "' .. config.lt_enablecategories .. '"',
  '--documentclass "' .. (state.documentclass or "") .. '"',
  '--packages "' .. packages .. '"',
  config.shell_options,
  "%:S",
}, " ")

vim.bo.errorformat = "%I=== %f ===,%C%*\\d.) Line %l, column %v, Rule ID:%.%#"
  .. (config.show_suggestions == 1 and ",%CMessage: %m,%Z%m" or ",%ZMessage: %m")
  .. ",%-G%.%#,%-G%.%#"
