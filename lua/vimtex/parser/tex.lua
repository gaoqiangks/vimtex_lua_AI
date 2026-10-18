local M = {}

local cache = require "vimtex.cache"
local paths = require "vimtex.paths"
local util = require "vimtex.util"

if vim.g["vimtex#re#tex_input"] == nil then
  require("vimtex.re").init()
end

local function root_default()
  local state = vim.b.vimtex
  return type(state) == "table" and state.root or ""
end

local function matches(text, pattern)
  return vim.fn.match(text, pattern) >= 0
end

-- Most TeX command lines are unrelated to file inclusion. Keep them away
-- from Vim's regex engine, which is considerably more expensive than these
-- plain Lua substring checks.
local function may_include(line)
  return line:find("\\input", 1, true)
    or line:find("\\include", 1, true)
    or line:find("\\import", 1, true)
    or line:find("\\subf", 1, true)
    or line:find("\\subi", 1, true)
    or line:find("\\loadglsentries", 1, true)
end

local function file_signature(file)
  local stat = vim.uv.fs_stat(file)
  return stat
      and stat.type == "file"
      and (stat.size .. ":" .. stat.mtime.sec .. ":" .. stat.mtime.nsec)
    or "missing"
end

local function options(opts)
  return vim.tbl_extend(
    "force",
    { detailed = true, root = opts and opts.root or root_default() },
    opts or {}
  )
end

function M.find_closing(start, text, count, delimiter)
  local opening = delimiter == "{" and 123 or 91
  local closing = delimiter == "{" and 125 or 93
  -- `start` and the return value use Vim's zero-based byte offsets. Lua's
  -- byte indexing makes a direct scan substantially cheaper than repeatedly
  -- crossing into Vim's regex engine for single-character delimiters.
  for index = start + 1, #text do
    local char = text:byte(index)
    if char == opening then
      count = count + 1
    elseif char == closing then
      count = count - 1
      if count == 0 then
        return index - 1, 0
      end
    end
  end
  return -1, count
end

local function input_to_filename(input, root)
  local opening = input:find("{", 1, true)
  if not opening then
    return ""
  end
  local start = opening
  local finish = M.find_closing(start, input, 1, "{")
  if finish < 0 then
    return ""
  end
  local file = input:sub(start + 1, finish)
  file = file:gsub('^[%s"]*', ""):gsub('[%s"]*$', "")
  if vim.fn.fnamemodify(file, ":e") == "" then
    file = file .. ".tex"
  end
  if paths.is_abs(file) then
    return file
  end
  local candidate = root .. "/" .. file
  if vim.fn.filereadable(candidate) == 1 then
    return candidate
  end
  candidate = require("vimtex.kpsewhich").find(file)
  return vim.fn.filereadable(candidate) == 1 and candidate or file
end

function M.texorpdfstring(title)
  local found = title:find("\\texorpdfstring", 1, true)
  if not found then
    return title
  end
  local first = found - 1
  local open_found = title:find("{", found + 1, true)
  if not open_found then
    return title
  end
  local open_tex = open_found - 1
  local close_tex = M.find_closing(open_tex + 1, title, 1, "{")
  if close_tex < 0 then
    return title
  end
  local pdf_found = title:find("{", close_tex + 2, true)
  if not pdf_found then
    return title
  end
  local open_pdf = pdf_found - 1
  local close_pdf = M.find_closing(open_pdf + 1, title, 1, "{")
  if close_pdf < 0 then
    return title
  end
  return title:sub(1, first)
    .. title:sub(open_tex + 2, close_tex)
    .. M.texorpdfstring(title:sub(close_pdf + 2))
end

function M.input_parser(line, current_file, root)
  local result = { file = "", new_root = root }
  local file = line:gsub("\\space%s*", " ")
  if matches(file, vim.g["vimtex#re#tex_input_import"]) then
    local current_root = file:find("\\sub", 1, true)
        and vim.fn.fnamemodify(current_file, ":p:h")
      or root
    local joined = file:gsub("/?}%s*{", "/")
    local candidate = input_to_filename(joined, current_root)
    result.file = candidate ~= "" and candidate
      or input_to_filename(file:gsub("{.-}", "", 1), current_root)
    result.new_root = vim.fn.fnamemodify(result.file, ":p:h")
  else
    result.file = input_to_filename(file, root)
  end
  return result
end

local function parse_current(file, root, current)
  current.lines, current.includes = {}, {}
  local input_pattern = vim.g["vimtex#re#tex_input"]
    .. [[|^\s*\\loadglsentries]]
  for line_number, line in ipairs(util.readfile(file)) do
    current.lines[#current.lines + 1] = { file, line_number, line }
    if may_include(line) and matches(line, input_pattern) then
      local result = M.input_parser(line, file, root)
      current.lines[#current.lines + 1] = result
      if file == result.file then
        require("vimtex.log").error {
          "Recursive file inclusion!",
          "File: " .. vim.fn.fnamemodify(file, ":."),
          "Line " .. line_number .. ":",
          line,
        }
      else
        current.includes[#current.includes + 1] = result
      end
    end
  end
end

local function parse_recursive(file, root, store, active, parsed, detailed)
  if active[file] then
    return
  end
  active[file] = true
  local current = store:get(root .. "\0" .. file)
  local signature = file_signature(file)
  if signature ~= current.signature then
    current.signature = signature
    parse_current(file, root, current)
  end
  for _, value in ipairs(current.lines or {}) do
    if value[1] then
      parsed[#parsed + 1] = detailed and value or value[3]
    else
      parse_recursive(
        value.file,
        value.new_root,
        store,
        active,
        parsed,
        detailed
      )
    end
  end
  active[file] = nil
end

local function parse_files_recursive(file, root, store, active, signatures)
  active = active or {}
  if active[file] then
    return {}
  end
  active[file] = true
  local current = store:get(root .. "\0" .. file)
  local signature = file_signature(file)
  if signature ~= current.signature then
    current.signature = signature
    parse_current(file, root, current)
  end
  if signatures then
    signatures[#signatures + 1] = root .. "\0" .. file .. "\0" .. signature
  end
  if signature == "missing" then
    active[file] = nil
    return {}
  end
  local files = { file }
  for _, included in ipairs(current.includes or {}) do
    vim.list_extend(
      files,
      parse_files_recursive(
        included.file,
        included.new_root,
        store,
        active,
        signatures
      )
    )
  end
  active[file] = nil
  return files
end

local function read_lines_until(file, callback)
  local fd = vim.uv.fs_open(file, "r", 438)
  if not fd then
    return
  end
  local offset, pending = 0, ""
  while true do
    local chunk = vim.uv.fs_read(fd, 16384, offset)
    if not chunk or chunk == "" then
      break
    end
    offset = offset + #chunk
    local data, start = pending .. chunk, 1
    while true do
      local finish = data:find("\n", start, true)
      if not finish then
        pending = data:sub(start)
        break
      end
      local line = data:sub(start, finish - 1):gsub("\r$", ""):gsub("%z", "\n")
      if callback(line) == false then
        vim.uv.fs_close(fd)
        return
      end
      start = finish + 1
    end
  end
  vim.uv.fs_close(fd)
  if pending ~= "" then
    callback(pending:gsub("\r$", ""):gsub("%z", "\n"))
  end
end

function M.parse(file, opts)
  opts = options(opts)
  local store = cache.open("parser_tex", {
    ["local"] = true,
    persistent = false,
    default = { ftime = -2 },
  })
  local parsed = {}
  parse_recursive(
    file,
    opts.root,
    store,
    {},
    parsed,
    opts.detailed ~= false and opts.detailed ~= 0
  )
  return parsed
end

function M.parse_files(file, opts)
  opts = options(opts)
  local store = cache.open("parser_tex", {
    ["local"] = true,
    persistent = false,
    default = { ftime = -2 },
  })
  return util.uniq_unsorted(parse_files_recursive(file, opts.root, store))
end

---Fingerprint the complete inclusion tree without copying all its lines.
---Unlike the maximum mtime, this detects deletion and restored/older files.
function M.signature(file, opts)
  opts = options(opts)
  local store = cache.open("parser_tex", {
    ["local"] = true,
    persistent = false,
    default = {},
  })
  local signatures = {}
  parse_files_recursive(file, opts.root, store, {}, signatures)
  return table.concat(signatures, "\0")
end

local function parse_preamble_recursive(file, root, parsed_files)
  if parsed_files[file] then
    return {}
  end
  parsed_files[file] = file_signature(file)
  local lines = {}
  read_lines_until(file, function(line)
    local has_command = line:find("\\", 1, true) ~= nil
    if may_include(line) and matches(line, vim.g["vimtex#re#tex_input"]) then
      local result = M.input_parser(line, file, root)
      vim.list_extend(
        lines,
        parse_preamble_recursive(result.file, result.new_root, parsed_files)
      )
    else
      lines[#lines + 1] = line
    end
    if has_command and line:find "\\begin%s*{document}" then
      return false
    end
  end)
  return lines
end

function M.parse_preamble(file, opts)
  opts = vim.tbl_extend(
    "force",
    { root = opts and opts.root or root_default(), cached = false },
    opts or {}
  )
  local store = cache.open("parser_preamble", {
    persistent = false,
    default = { time = -2 },
  })
  local current = store:get(opts.root .. "\0" .. file)
  if opts.cached and current.lines then
    return util.copy_list(current.lines)
  end
  local valid = current.dependencies ~= nil
  for dependency, signature in pairs(current.dependencies or {}) do
    if file_signature(dependency) ~= signature then
      valid = false
      break
    end
  end
  if not valid then
    current.dependencies = {}
    current.lines =
      parse_preamble_recursive(file, opts.root, current.dependencies)
  end
  return util.copy_list(current.lines or {})
end

return M
