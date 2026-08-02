local M = {}
local previous_window
local keystrokes = 0

local names = {
  latexlog = "LaTeX logfile",
  pplatex = "LaTeX logfile using pplatex",
  pulp = "LaTeX logfile using pulp",
}

function M.new(method)
  method = method or vim.g.vimtex_quickfix_method
  if
    (method == "pplatex" or method == "pulp")
    and vim.fn.executable(method) == 0
  then
    require("vimtex.log").error(method .. " is not executable!")
    return vim.empty_dict()
  end
  return { method = method, name = names[method] or method }
end

function M.init_buffer()
  if vim.g.vimtex_quickfix_enabled == 0 then
    return
  end
  vim.api.nvim_buf_create_user_command(0, "VimtexErrors", M.toggle, {})
  vim.keymap.set("n", "<plug>(vimtex-errors)", M.toggle, { buffer = true })
end

function M.is_open()
  for _, window in ipairs(vim.fn.getwininfo()) do
    if
      window.tabnr == vim.fn.tabpagenr()
      and window.quickfix == 1
      and window.loclist == 0
    then
      return true
    end
  end
  return false
end

local function has_errors()
  for _, entry in ipairs(vim.fn.getqflist()) do
    if entry.type == "E" then
      return true
    end
  end
  return false
end

local function autoclose()
  if vim.fn.bufexists "[Command Line]" == 1 then
    return
  end
  if keystrokes == 0 then
    keystrokes = vim.g.vimtex_quickfix_autoclose_after_keystrokes
  end
  local quickfix
  for _, window in ipairs(vim.fn.getwininfo()) do
    if
      window.tabnr == vim.fn.tabpagenr()
      and window.quickfix == 1
      and window.loclist == 0
    then
      quickfix = window.winnr
      break
    end
  end
  if not quickfix then
    keystrokes = 0
  elseif quickfix == vim.fn.winnr() then
    keystrokes = vim.g.vimtex_quickfix_autoclose_after_keystrokes + 1
  else
    keystrokes = keystrokes - 1
  end
  if keystrokes == 0 then
    vim.cmd "cclose"
    vim.api.nvim_clear_autocmds { group = "vimtex_qf_autoclose" }
  end
end

local function compiler_file(extension)
  return vim.fn.eval(([[b:vimtex.compiler.get_file('%s')]]):format(extension))
end

function M.setqflist(file)
  local state = vim.b.vimtex
  if not state.qf or not state.qf.method then
    return
  end
  local tex, log, blg, jump
  if file and file ~= "" then
    tex, log, blg, jump =
      file,
      vim.fn.fnamemodify(file, ":r") .. ".log",
      vim.fn.fnamemodify(file, ":r") .. ".blg",
      false
  else
    tex, log, blg, jump =
      state.tex,
      compiler_file "log",
      compiler_file "blg",
      vim.g.vimtex_quickfix_autojump == 1
  end
  local title = vim.fn.getqflist { title = 1 }
  if (title.title or ""):match "VimTeX" then
    vim.fn.setqflist({}, "r")
  else
    vim.fn.setqflist {}
  end
  require("vimtex.qf." .. state.qf.method).addqflist(tex, log)
  if state.packages.biblatex then
    require("vimtex.qf.biblatex").addqflist(blg)
  else
    require("vimtex.qf.bibtex").addqflist(
      blg,
      vim.fn.fnamemodify(log, ":.:h") .. "/",
      tex
    )
  end
  local list = vim.fn.getqflist()
  for _, regex in ipairs(vim.g.vimtex_quickfix_ignore_filters or {}) do
    list = vim.tbl_filter(function(entry)
      return vim.fn.match(entry.text, regex) < 0
    end, list)
  end
  for index, entry in ipairs(list) do
    entry._vimtex_index = index
  end
  table.sort(list, function(first, second)
    local first_error, second_error = first.type == "E", second.type == "E"
    if first_error ~= second_error then
      return first_error
    end
    return first._vimtex_index < second._vimtex_index
  end)
  for _, entry in ipairs(list) do
    entry._vimtex_index = nil
  end
  vim.fn.setqflist(list, "r")
  pcall(
    vim.fn.setqflist,
    {},
    "r",
    { title = "VimTeX errors (" .. state.qf.name .. ")" }
  )
  if jump then
    vim.cmd "cfirst"
  end
end

function M.open(force)
  local ok, error_message = pcall(M.setqflist)
  if not ok then
    if tostring(error_message):match "No log file found" then
      if force then
        require("vimtex.log").warning "No log file found"
      end
    else
      require("vimtex.log").error(
        "Something went wrong when parsing log files!",
        tostring(error_message)
      )
    end
    if vim.g.vimtex_quickfix_mode > 0 then
      vim.cmd "cclose"
    end
    return
  end
  if vim.tbl_isempty(vim.fn.getqflist()) then
    if force then
      require("vimtex.log").info "No errors!"
    end
    if vim.g.vimtex_quickfix_mode > 0 then
      vim.cmd "cclose"
    end
    return
  end
  if
    force
    or (
      vim.g.vimtex_quickfix_mode > 0
      and (has_errors() or vim.g.vimtex_quickfix_open_on_warning == 1)
    )
  then
    previous_window = vim.fn.win_getid()
    vim.cmd "botright cwindow"
    if vim.g.vimtex_quickfix_mode == 2 then
      vim.cmd "redraw"
      vim.fn.win_gotoid(previous_window)
    end
    if vim.g.vimtex_quickfix_autoclose_after_keystrokes > 0 then
      local group =
        vim.api.nvim_create_augroup("vimtex_qf_autoclose", { clear = true })
      vim.api.nvim_create_autocmd(
        { "CursorMoved", "CursorMovedI" },
        { group = group, callback = autoclose }
      )
    end
    vim.cmd "redraw"
  end
end

function M.toggle()
  if M.is_open() then
    vim.cmd "cclose"
  else
    M.open(true)
  end
end

function M.inquire(file)
  local ok = pcall(M.setqflist, file)
  return ok and has_errors() and 1 or 0
end

return M
