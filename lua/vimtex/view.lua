local M = {}
local log = require "vimtex.log"
local paths = require "vimtex.paths"
local util = require "vimtex.util"

local function event(pattern)
  vim.api.nvim_exec_autocmds("User", { pattern = pattern, modeline = false })
end

local viewer = {}

function viewer.check(self)
  if self._check_value == nil then
    self._check_value = self:_check()
  end
  return self._check_value
end

function viewer.out(self)
  return self.compiler and self.compiler.get_file "pdf"
    or (vim.b.vimtex and vim.b.vimtex.compiler and vim.b.vimtex.compiler.get_file "pdf")
    or ""
end

function viewer.view(self, file)
  if not self:check() then
    return
  end
  local output = file ~= "" and file or self:out()
  if vim.fn.filereadable(output) == 0 then
    log.warning("Viewer cannot read PDF file!", output)
    return
  end
  self:_start(output)
  event "VimtexEventView"
end

function viewer.compiler_callback(self, output)
  if vim.g.vimtex_view_automatic == 1 and not self.started_through_callback then
    self:_start(output)
    self.started_through_callback = true
    event "VimtexEventView"
  end
end

function viewer.compiler_stopped(self)
  self.started_through_callback = nil
end

function viewer.xdo_check(self)
  return vim.fn.executable "xdotool" == 1 and self.xwin_id ~= nil
end

function viewer.xdo_focus_vim(self)
  if not self:xdo_check() then
    return
  end
  local ids = require("vimtex.jobs").capture(
    "xdotool search --onlyvisible --pid " .. vim.fn.getpid()
  )
  if ids[1] then
    require("vimtex.jobs").run("xdotool windowactivate " .. ids[#ids])
  end
end

function viewer.__pprint(self)
  local result = {}
  for key, value in pairs(self) do
    if key:match "^cmd" or key == "job" or key == "xwin_id" then
      table.insert(result, { key:gsub("_", " "), value })
    end
  end
  return result
end

local function callback_program()
  return (vim.g.vimtex_callback_progpath or vim.v.progpath)
    .. " --headless -c \"VimtexInverseSearch %{line}:%{column} '%{input}'\""
end

local function generic_start(self, output)
  local command = vim.g.vimtex_view_general_viewer
    .. " "
    .. vim.g.vimtex_view_general_options
  local replacements = {
    ["@line"] = vim.fn.line ".",
    ["@col"] = vim.fn.col ".",
    ["@tex"] = util.shellescape(vim.fn.expand "%:p"),
    ["@pdf"] = util.shellescape(output),
  }
  for pattern, value in pairs(replacements) do
    command = command:gsub(pattern, tostring(value))
  end
  self.cmd_start = command
  self.job =
    require("vimtex.jobs").start(command, { detached = util.get_os() ~= "win" })
end

local function make(method, state)
  local self = vim.tbl_extend("force", {}, viewer, {
    method = method,
    name = method,
    compiler = state.compiler,
    _check = function(instance)
      local executable = method == "general"
          and vim.split(vim.g.vimtex_view_general_viewer, " ")[1]
        or method == "zathura_simple" and "zathura"
        or method == "sioyek" and vim.g.vimtex_view_sioyek_exe
        or method
      local ok = vim.fn.executable(executable) == 1
      if not ok then
        log.error(instance.name .. " is not executable!")
      end
      return ok
    end,
  })
  self._start = function(instance, output)
    local command
    if method == "general" then
      return generic_start(instance, output)
    elseif method == "zathura" or method == "zathura_simple" then
      command = "zathura " .. (vim.g.vimtex_view_zathura_options or "")
      if method == "zathura" then
        command = command .. " -x " .. util.shellescape(callback_program())
      end
      command = command
        .. (" --synctex-forward %d:%d:%s "):format(
          vim.fn.line ".",
          vim.fn.col ".",
          util.shellescape(vim.fn.expand "%:p")
        )
        .. util.shellescape(paths.relative(output, vim.fn.getcwd()))
    elseif method == "sioyek" then
      command = table.concat({
        vim.g.vimtex_view_sioyek_exe,
        vim.g.vimtex_view_sioyek_options,
        "--inverse-search",
        util.shellescape(callback_program()),
        "--forward-search-file",
        util.shellescape(vim.fn.expand "%:p"),
        "--forward-search-line",
        vim.fn.line ".",
        util.shellescape(output),
      }, " ")
    elseif method == "mupdf" then
      command = "mupdf "
        .. (vim.g.vimtex_view_mupdf_options or "")
        .. " "
        .. util.shellescape(output)
    elseif method == "galley" then
      command = "open -a GalleyPDF " .. util.shellescape(output)
    else
      command = "open -a "
        .. util.shellescape(instance.name)
        .. " "
        .. util.shellescape(output)
    end
    instance.cmd_start = command
    instance.job = require("vimtex.jobs").start(command, { detached = true })
  end
  for name, callback in pairs(self) do
    if type(callback) == "function" then
      self[name] = function(...)
        if select(1, ...) == self then
          return callback(self, select(2, ...))
        end
        return callback(self, ...)
      end
    end
  end
  return self
end

function M.init_state(state)
  if vim.g.vimtex_view_enabled == 0 or state.viewer then
    return
  end
  state.viewer = make(vim.g.vimtex_view_method, state)
end

function M.view(file)
  if vim.b.vimtex and vim.b.vimtex.viewer then
    vim.b.vimtex.viewer.view(file or "")
  end
end

function M.compiler_callback()
  local current = vim.b.vimtex and vim.b.vimtex.viewer
  if current and current.check() then
    local output = current.out()
    if output ~= "" then
      current.compiler_callback(output)
    end
  end
end

function M.compiler_stopped()
  local current = vim.b.vimtex and vim.b.vimtex.viewer
  if current then
    current.compiler_stopped()
  end
end

function M.inverse_search(line, filename, column)
  if not vim.b.vimtex then
    return -1
  end
  local file = vim.fn.resolve(vim.fn.fnamemodify(filename, ":p"))
  local sources = vim.fn.eval "b:vimtex.get_sources({'refresh': v:true})"
  sources = vim.tbl_map(function(source)
    return vim.fn.resolve(
      paths.is_abs(source) and source or paths.join(vim.b.vimtex.root, source)
    )
  end, sources)
  if not vim.tbl_contains(sources, file) then
    return -2
  end
  if vim.fn.mode() == "i" then
    vim.cmd "stopinsert"
  end
  if vim.fn.bufloaded(file) == 0 then
    if vim.fn.filereadable(file) == 0 then
      log.warning(
        "Reverse goto failed!",
        ('File not readable: "%s"'):format(filename)
      )
      return -4
    end
    local command = vim.g.vimtex_view_reverse_search_edit_cmd
      .. " "
      .. vim.fn.fnameescape(filename)
    if not pcall(vim.cmd, command) then
      log.warning("Reverse goto failed!", "Command error: " .. command)
      return -3
    end
  elseif vim.api.nvim_get_current_buf() ~= vim.fn.bufnr(file) then
    local windows = vim.fn.win_findbuf(vim.fn.bufnr(file))
    if windows[1] then
      vim.api.nvim_set_current_win(windows[1])
    else
      vim.cmd(
        vim.g.vimtex_view_reverse_search_edit_cmd
          .. " "
          .. vim.fn.fnameescape(filename)
      )
    end
  end
  vim.api.nvim_win_set_cursor(0, { line, math.max(0, (column or 0) - 1) })
  local current = vim.b.vimtex and vim.b.vimtex.viewer
  if current and current.xdo_check() then
    current.xdo_focus_vim()
  end
  event "VimtexEventViewReverse"
  return 0
end

function M.inverse_search_cmd(line, filename, column)
  if line > 0 and filename ~= "" then
    local server_file = require("vimtex.cache").path "nvim_servernames.log"
    local servers = vim.fn.filereadable(server_file) == 1
        and util.readfile(server_file)
      or {}
    for _, server in ipairs(servers) do
      local ok, socket = pcall(vim.fn.sockconnect, "pipe", server, { rpc = 1 })
      if ok then
        vim.rpcnotify(
          socket,
          "nvim_exec_lua",
          "return require('vimtex.view').inverse_search(...)",
          {
            line,
            filename,
            column,
          }
        )
        vim.fn.chanclose(socket)
      end
    end
  end
  vim.cmd "qall!"
end

function M.init_buffer()
  if vim.g.vimtex_view_enabled == 0 then
    return
  end
  vim.api.nvim_buf_create_user_command(0, "VimtexView", function(options)
    M.view(options.args)
  end, { nargs = "?", complete = "file" })
  vim.keymap.set("n", "<plug>(vimtex-view)", M.view, { buffer = true })
end

return M
