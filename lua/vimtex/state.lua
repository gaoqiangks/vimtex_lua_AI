local M = {}
local class = require "vimtex.state.class"
local paths = require "vimtex.paths"
local util = require "vimtex.util"

local states = {}
local next_id = 0
local subfile_preserve_root = false

local function current_file()
  return vim.api.nvim_buf_get_name(0)
end

local function get_main_id(main)
  for id, state in pairs(states) do
    if state.tex == main then
      return id
    end
  end
  return -1
end

local function globpath_upwards(expression, start)
  local directories, path = {}, start
  while true do
    table.insert(directories, vim.fn.fnameescape(path))
    local parent = vim.fn.fnamemodify(path, ":h")
    if parent == path then
      break
    end
    path = parent
  end
  return vim.tbl_filter(function(file)
    return vim.fn.filereadable(file) == 1
  end, vim.fn.globpath(
    table.concat(directories, ","),
    expression,
    false,
    true
  ))
end

local function file_is_main(file)
  local preamble = require("vimtex.parser").preamble(file, {
    root = vim.fn.fnamemodify(file, ":p:h"),
  })
  local has_class, has_document = false, false
  for _, line in ipairs(preamble) do
    if
      line:find "^%s*\\documentclass%s*[%[{]"
      and not line:find("{subfiles}", 1, true)
      and not line:find("{standalone}", 1, true)
    then
      has_class = true
    end
    if line:find "^%s*\\begin%s*{document}" then
      has_document = true
    end
  end
  return has_class and has_document, preamble
end

local function choose(candidates)
  candidates = util.uniq_unsorted(candidates)
  if #candidates == 0 then
    return ""
  elseif #candidates == 1 then
    return candidates[1]
  end
  local existing, existing_count, new = {}, 0, {}
  for _, candidate in ipairs(candidates) do
    local id = get_main_id(candidate)
    if id >= 0 then
      if existing[id] == nil then
        existing_count = existing_count + 1
      end
      existing[id] = candidate
    else
      table.insert(new, candidate)
    end
  end
  if existing_count == 1 then
    local _, value = next(existing)
    return value
  end
  local alternate = vim.fn.getbufvar(vim.fn.bufnr "#", "vimtex_id", -1)
  if existing[alternate] then
    return existing[alternate]
  elseif existing_count == 0 and #new == 1 then
    return new[1]
  elseif vim.g.vimtex_main_choose_first == 1 then
    return candidates[1]
  end
  local choices = {}
  for _, candidate in ipairs(candidates) do
    choices[candidate] = paths.relative(candidate, vim.fn.getcwd())
  end
  return require("vimtex.ui").select(choices, {
    prompt = "Please select an appropriate main file:",
    ["return"] = "key",
  }) or ""
end

local function get_texroot()
  for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, 20, false)) do
    local pattern = vim.fn.matchstr(line, vim.g["vimtex#re#tex_input_root"])
    if pattern ~= "" then
      if not paths.is_abs(pattern) then
        pattern = vim.fn.simplify(vim.fn.expand "%:p:h" .. "/" .. pattern)
      end
      local candidates = vim.fn.glob(pattern, false, true)
      if #candidates > 0 then
        return choose(candidates)
      end
    end
  end
  return ""
end

local function get_subfile()
  for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, 20, false)) do
    local filename = line:match "^%s*\\documentclass%[([^]]*)%]{subfiles}" or ""
    if filename ~= "" then
      if not filename:match "%.tex$" then
        filename = filename .. ".tex"
      end
      local candidate = paths.is_abs(filename) and filename
        or vim.fn.simplify(vim.fn.expand "%:p:h" .. "/" .. filename)
      if vim.fn.filereadable(candidate) == 1 then
        return candidate
      end
      candidate = vim.fn.fnamemodify(vim.fn.findfile(filename, ".;"), ":p")
      if vim.fn.filereadable(candidate) == 1 then
        local sources = require("vimtex.parser.tex").parse_files(candidate, {
          root = vim.fn.fnamemodify(candidate, ":p:h"),
        })
        if vim.tbl_contains(sources, current_file()) then
          subfile_preserve_root = true
          return candidate
        end
      end
    end
  end
  return ""
end

local function latexmain()
  local result = ""
  for _, marker in
    ipairs(globpath_upwards("*.latexmain", vim.fn.expand "%:p:h"))
  do
    result = vim.fn.fnamemodify(marker, ":p:r")
    if vim.fn.filereadable(result) == 1 then
      return result
    end
  end
  return result
end

local function latexmk_main()
  local ok, result = pcall(
    require("vimtex.compiler").latexmk.get_rc_opt,
    vim.fn.expand "%:p:h",
    "default_files",
    2,
    {}
  )
  if not ok or (result[2] or 0) < 1 then
    return ""
  end
  for _, name in ipairs(result[1]) do
    local file = paths.join(vim.fn.expand "%:p:h", name)
    if vim.fn.filereadable(file) == 1 then
      return file
    end
  end
  return ""
end

local function recurse_main(file, context, input_regex)
  file = vim.fn.fnamemodify(file, ":p")
  if context.tried[file] or vim.fn.filereadable(file) == 0 then
    return {}
  end
  context.tried[file] = true
  if file ~= current_file() and file_is_main(file) then
    return { file }
  end
  local basename = vim.fn.fnamemodify(file, ":t:r")
  local result = {}
  local directory = vim.fn.fnamemodify(file, ":p:h")
  local candidates = context.candidates[directory]
  if not candidates then
    candidates = globpath_upwards("*.tex", directory)
    context.candidates[directory] = candidates
  end
  for _, candidate in ipairs(candidates) do
    if not context.tried[candidate] then
      local lines = context.lines[candidate]
      if not lines then
        lines = util.readfile(candidate)
        context.lines[candidate] = lines
      end
      for _, line in ipairs(lines) do
        if
          line:find(basename, 1, true)
          and vim.fn.match(line, input_regex) >= 0
        then
          vim.list_extend(
            result,
            recurse_main(candidate, context, vim.g["vimtex#re#tex_input"])
          )
          break
        end
      end
    end
  end
  return result
end

local function recursive_candidates(from_bib)
  return recurse_main(
    current_file(),
    { tried = {}, lines = {}, candidates = {} },
    from_bib and vim.g["vimtex#re#bib_input"] or vim.g["vimtex#re#tex_input"]
  )
end

local function get_main()
  if vim.b.vimtex_main and vim.fn.filereadable(vim.b.vimtex_main) == 1 then
    return vim.fn.fnamemodify(vim.b.vimtex_main, ":p"), "buffer variable", {}
  end
  local candidate = get_texroot()
  if candidate ~= "" then
    return candidate, "texroot specifier", {}
  end
  if vim.bo.filetype == "tex" then
    local is_main, preamble = file_is_main(current_file())
    if is_main then
      return current_file(), "current file verified", {}, preamble
    end
    candidate = get_subfile()
    if candidate ~= "" then
      return candidate, "subfiles", {}
    end
  end
  candidate = latexmain()
  if candidate ~= "" then
    return candidate, "latexmain specifier", {}
  end
  candidate = latexmk_main()
  if candidate ~= "" then
    return candidate, "latexmkrc @default_files", {}
  end
  local extension = vim.fn.expand "%:e"
  if extension == "cls" or extension == "sty" then
    local id = vim.fn.getbufvar(vim.fn.bufnr "#", "vimtex_id", -1)
    if states[id] then
      return states[id].tex, "cls/sty file (inherit from alternate)", {}
    end
    return current_file(), "cls/sty file", { "compiler", "view", "toc", "qf" }
  end
  candidate = choose(recursive_candidates(vim.bo.filetype ~= "tex"))
  if candidate ~= "" then
    return candidate,
      vim.bo.filetype == "tex" and "recursive search"
        or "recursive search (bib)",
      {}
  end
  if vim.bo.filetype == "bib" then
    local id = vim.fn.getbufvar(vim.fn.bufnr "#", "vimtex_id", -1)
    if states[id] then
      return states[id].tex, "bib file (inherit from alternate)", {}
    end
    return current_file(),
      "bib file",
      { "compiler", "view", "toc", "qf", "fold" }
  end
  return current_file(), "fallback current file", {}
end

function M.init()
  local main, parser, unsupported, preamble = get_main()
  local id = get_main_id(main)
  if id < 0 then
    id = next_id
    next_id = next_id + 1
    states[id] = class.new {
      main = main,
      main_parser = parser,
      unsupported_modules = unsupported,
      preamble = preamble,
    }
  end
  vim.b.vimtex_id, vim.b.vimtex = id, states[id]
end

local function standalone()
  for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, 20, false)) do
    if
      line:find "^%s*\\documentclass%b[]{standalone}"
      or line:find "^%s*\\documentclass{standalone}"
    then
      return true
    end
  end
  return false
end

function M.init_local()
  local preserve = subfile_preserve_root
  subfile_preserve_root = false
  if
    vim.bo.filetype ~= "tex"
    or vim.b.vimtex.tex == ""
    or vim.b.vimtex.tex == current_file()
  then
    return
  end
  local id = get_main_id(current_file())
  if id < 0 then
    id = next_id
    next_id = next_id + 1
    states[id] = class.new {
      main = current_file(),
      main_parser = "local file",
      preserve_root = preserve or standalone(),
    }
    local main = states[vim.b.vimtex_id]
    main.subids = main.subids or {}
    table.insert(main.subids, id)
    states[id].main_id = vim.b.vimtex_id
  end
  vim.b.vimtex_local = { active = 0, main_id = vim.b.vimtex_id, sub_id = id }
  if
    vim.b.vimtex.main_parser == "subfiles"
    and vim.g.vimtex_subfile_start_local == 1
  then
    M.toggle_main()
  end
end

function M.toggle_main()
  local local_state = vim.b.vimtex_local
  if not local_state then
    return
  end
  local_state.active = local_state.active == 1 and 0 or 1
  vim.b.vimtex_local = local_state
  local id = local_state.active == 1 and local_state.sub_id
    or local_state.main_id
  vim.b.vimtex_id, vim.b.vimtex = id, states[id]
  require("vimtex.log").info(
    ("Changed to `%s' %s"):format(
      vim.b.vimtex.base,
      local_state.active == 1 and "[local]" or "[main]"
    )
  )
end

function M.reload()
  local ids = { get_main_id(current_file()), vim.b.vimtex_id or -1 }
  for _, id in ipairs(ids) do
    if states[id] then
      states[id].cleanup()
      states[id] = nil
    end
  end
  M.init()
  M.init_local()
end

function M.list_all()
  return vim.tbl_values(states)
end

function M.exists(id)
  return states[id] ~= nil
end

function M.get(id)
  return states[id]
end

function M.get_all()
  return states
end

function M.cleanup(id)
  local state = states[id]
  if not state then
    return
  end
  local id_counts = {}
  for buffer = 1, vim.fn.bufnr "$" do
    if vim.fn.buflisted(buffer) == 1 then
      local buffer_id = vim.fn.getbufvar(buffer, "vimtex_id", -1)
      id_counts[buffer_id] = (id_counts[buffer_id] or 0) + 1
    end
  end
  if (id_counts[id] or 0) > 1 then
    return
  end
  if state.subids then
    for _, subid in ipairs(state.subids) do
      if id_counts[subid] then
        return
      end
    end
    for _, subid in ipairs(state.subids) do
      if states[subid] then
        states[subid].cleanup()
        states[subid] = nil
      end
    end
  end
  state.cleanup()
  states[id] = nil
end

function M.cleanup_all()
  for id, state in pairs(states) do
    state.cleanup()
    states[id] = nil
  end
end

function M.init_buffer()
  vim.api.nvim_buf_create_user_command(0, "VimtexToggleMain", M.toggle_main, {})
  vim.api.nvim_buf_create_user_command(0, "VimtexReloadState", M.reload, {})
  vim.keymap.set(
    "n",
    "<plug>(vimtex-toggle-main)",
    M.toggle_main,
    { buffer = true }
  )
  vim.keymap.set(
    "n",
    "<plug>(vimtex-reload-state)",
    M.reload,
    { buffer = true }
  )
end

return M
