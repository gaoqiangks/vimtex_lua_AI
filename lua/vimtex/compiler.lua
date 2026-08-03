local M = {}
local log = require "vimtex.log"
local paths = require "vimtex.paths"
local util = require "vimtex.util"

local function bind(self)
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

local function call(object, name, ...)
  local callback = object and object[name]
  if type(callback) == "function" then
    return callback(...)
  end
  if callback ~= nil and callback ~= vim.NIL then
    return vim.fn.call(callback, { ... }, object)
  end
end

local base = {
  name = "__template__",
  enabled = true,
  out_dir = "",
  continuous = 0,
  hooks = {},
  silence_next_callback = 0,
  file_info = {},
  status = -1,
}

function base._get_executable_string(self)
  if type(self.executable) == "string" then
    return self.executable
  end
  if type(self.executable) == "table" then
    return table.concat(self.executable, " ")
  end
  error "VimTeX: executable must be a string or list"
end

function base._is_executable_available(self)
  local executable = type(self.executable) == "table" and self.executable[1]
    or self.executable
  return executable and vim.fn.executable(executable) == 1
end

function base._output_roots(self)
  return {
    vim.env.VIMTEX_OUTPUT_DIRECTORY or "",
    self.out_dir,
    self.file_info.root,
  }
end

function base._get_file_candidates(self, extension)
  local result = {}
  for _, root in ipairs(self:_output_roots()) do
    if root ~= "" then
      local candidate = ("%s/%s.%s"):format(
        root,
        self.file_info.jobname,
        extension
      )
      if not paths.is_abs(root) then
        candidate = paths.join(self.file_info.root, candidate)
      end
      table.insert(result, vim.fn.fnamemodify(candidate, ":p"))
    end
  end
  return result
end

function base.get_file(self, extension)
  for _, file in ipairs(self:_get_file_candidates(extension)) do
    if vim.fn.filereadable(file) == 1 then
      return file
    end
  end
  return ""
end

function base.read_file(self, extension)
  for _, file in ipairs(self:_get_file_candidates(extension)) do
    local lines, readable = util.readfile(file)
    if readable then
      return lines, file
    end
  end
  return {}, ""
end

function base.get_output_signature(self, extension)
  return self:_get_file_candidates(extension)[1] or ""
end

function base._create_build_dir(self, directory)
  if directory == "" then
    return
  end
  local root = paths.is_abs(directory) and directory
    or paths.join(self.file_info.root, directory)
  local project = require("vimtex.state").get(vim.b.vimtex_id)
  for _, source in ipairs(project and project.get_sources() or {}) do
    local relative = vim.fn.fnamemodify(source, ":h")
    if relative ~= "." and not relative:match "^%.%./" then
      vim.fn.mkdir(paths.join(root, relative), "p")
    end
  end
end

function base.create_dirs(self)
  self:_create_build_dir(self.out_dir)
end

function base._remove_dir(self, directory)
  if directory == "" then
    return
  end
  local root = paths.is_abs(directory) and directory
    or paths.join(self.file_info.root, directory)
  if vim.fn.isdirectory(root) == 0 then
    return
  end
  local files = vim.fn.glob(root .. "/**/*", false, true)
  local has_readable_file = false
  for _, file in ipairs(files) do
    if vim.fn.filereadable(file) == 1 then
      has_readable_file = true
      break
    end
  end
  if not has_readable_file then
    table.sort(files, function(a, b)
      return #a > #b
    end)
    for _, path in ipairs(files) do
      vim.fn.delete(path, "d")
    end
    vim.fn.delete(root, "d")
  end
end

function base.remove_dirs(self)
  self:_remove_dir(self.out_dir)
end

function base.clean(self, full)
  local extensions = { "synctex.gz", "toc", "out", "aux", "log", "xdv", "fls" }
  if full == true or full == 1 then
    table.insert(extensions, "pdf")
  end
  for _, extension in ipairs(extensions) do
    local file = self:get_file(extension)
    if file ~= "" then
      vim.fn.delete(file)
    end
  end
  for _, expression in ipairs(vim.g.vimtex_compiler_clean_paths) do
    for _, path in
      ipairs(vim.fn.glob(self.file_info.root .. "/" .. expression, false, true))
    do
      vim.fn.delete(path, "rf")
    end
  end
end

function base.exec(self, command)
  local options = {
    cwd = self.file_info.root,
    stdin = self.continuous == 1 and self.stdin_pipe and "pipe" or "null",
    on_stdout = function(_, data)
      self:_on_output(data)
    end,
    on_stderr = function(_, data)
      self:_on_output(data)
    end,
  }
  if self.continuous ~= 1 then
    options.on_exit = function()
      vim.schedule(function()
        if self.status ~= 0 then
          M.callback(
            2
              + require("vimtex.qf").inquire(
                self.file_info.target ~= vim.b.vimtex.tex
                    and self.file_info.target
                  or ""
              )
          )
        end
      end)
    end
  end
  self.job = vim.fn.jobstart(command, options)
end

local compiler_statuses = {
  vimtex_compiler_callback_compiling = 1,
  vimtex_compiler_callback_success = 2,
  vimtex_compiler_callback_failure = 3,
}

function base._on_output(self, data)
  local lines = {}
  for _, line in ipairs(data or {}) do
    if line ~= "" then
      lines[#lines + 1] = line
    end
  end
  if #lines > 0 then
    vim.fn.writefile(lines, self.output, "a")
  end
  for _, line in ipairs(lines) do
    local status = compiler_statuses[line:gsub("\r", "")]
    if status then
      M.callback(status)
    end
  end
  local output = table.concat(lines, "\n")
  for _, hook in ipairs(self.hooks or {}) do
    if type(hook) == "function" then
      hook(output)
    else
      pcall(vim.fn.call, hook, { output })
    end
  end
end

function base.start(self, passed)
  if self:is_running() then
    return
  end
  self:create_dirs()
  vim.fn.writefile({}, self.output, "a")
  self.cmd = self:__build_cmd(passed or "")
  local jobname = self.cmd:match "%-jobname=(%S+)"
  self.file_info.jobname = jobname and jobname ~= "" and jobname
    or self.file_info.target_name
  self:exec { "sh", "-c", self.cmd }
  self.status = 1
  vim.api.nvim_exec_autocmds(
    "User",
    { pattern = "VimtexEventCompileStarted", modeline = false }
  )
end

function base.start_single(self, passed)
  local continuous = self.continuous
  self.continuous = 0
  self:start(passed)
  self.continuous = continuous
end

function base.stop(self)
  if not self:is_running() then
    return
  end
  self.status = 0
  self:kill()
  vim.api.nvim_exec_autocmds(
    "User",
    { pattern = "VimtexEventCompileStopped", modeline = false }
  )
end

function base.kill(self)
  if self.job then
    pcall(vim.fn.jobstop, self.job)
  end
end

function base.wait(self)
  if self.job then
    vim.fn.jobwait({ self.job }, 5000)
  end
end

function base.is_running(self)
  if not self.job then
    return false
  end
  return pcall(vim.fn.jobpid, self.job) and vim.fn.jobpid(self.job) > 0
end

function base.get_pid(self)
  return self:is_running() and vim.fn.jobpid(self.job) or 0
end

function base.__pprint(self)
  return {
    { "engine", self.get_engine and self:get_engine() or "" },
    { "options", self.options or {} },
    { "out_dir", self.out_dir },
  }
end

local rc_file_cache = {}
local rc_file_order = {}

local function read_rc_file(path)
  local stat = vim.uv.fs_stat(path)
  if not stat or stat.type ~= "file" then
    return
  end
  local mtime = stat.mtime.sec .. ":" .. stat.mtime.nsec
  local cached = rc_file_cache[path]
  if cached and cached.mtime == mtime and cached.size == stat.size then
    return cached.lines
  end
  local lines = util.readfile(path)
  if rc_file_cache[path] == nil then
    rc_file_order[#rc_file_order + 1] = path
    if #rc_file_order > 16 then
      rc_file_cache[table.remove(rc_file_order, 1)] = nil
    end
  end
  rc_file_cache[path] = { mtime = mtime, size = stat.size, lines = lines }
  return lines
end

local rc_kinds = { [0] = true, [1] = true, [2] = true }

local function match_rc_value(line, option, kind)
  option = vim.pesc(option)
  if kind == 0 then
    return line:match("^%s*%$" .. option .. "%s*=%s*['\"](.+)['\"]")
  elseif kind == 1 then
    return line:match("^%s*%$" .. option .. "%s*=%s*(%d+)")
  elseif kind == 2 then
    return line:match("^%s*@" .. option .. "%s*=%s*%((.*)%)")
  end
end

local function parse_rc_value(value, kind)
  if kind == 1 then
    return tonumber(value)
  elseif kind == 2 then
    local entries = {}
    for entry in (value .. ","):gmatch "(.-)," do
      entries[#entries + 1] = vim.trim(entry):gsub("^'", ""):gsub("'$", "")
    end
    return entries
  end
  return value
end

local function rc_opts(root, specs)
  local results, unresolved = {}, #specs
  for index, spec in ipairs(specs) do
    if not rc_kinds[spec.kind] then
      error "VimTeX: Argument error"
    end
    results[index] = { spec.default, -1 }
  end
  local config = vim.env.XDG_CONFIG_HOME ~= "" and vim.env.XDG_CONFIG_HOME
    or vim.fn.expand "~/.config"
  local files = {
    { root .. "/latexmkrc", 1 },
    { root .. "/.latexmkrc", 1 },
    { vim.fn.expand "~/.latexmkrc", 0 },
    { config .. "/latexmk/latexmkrc", 0 },
  }
  for _, item in ipairs(files) do
    local lines = read_rc_file(item[1])
    if lines then
      for _, line in ipairs(lines) do
        for index, spec in ipairs(specs) do
          if results[index][2] == -1 then
            local found = match_rc_value(line, spec.option, spec.kind)
            if found then
              results[index] = {
                parse_rc_value(found, spec.kind),
                item[2],
              }
              unresolved = unresolved - 1
            end
          end
        end
        if unresolved == 0 then
          return results
        end
      end
    end
  end
  return results
end

local function rc_opt(root, option, kind, default)
  return rc_opts(root, {
    { option = option, kind = kind, default = default },
  })[1]
end

M.latexmk = { get_rc_opt = rc_opt }

local defaults = {
  latexmk = {
    name = "latexmk",
    aux_dir = "",
    callback = 1,
    clean_ext = "",
    continuous = 1,
    executable = "latexmk",
    options = {
      "-verbose",
      "-file-line-error",
      "-synctex=1",
      "-interaction=nonstopmode",
    },
  },
  latexrun = {
    name = "latexrun",
    executable = "latexrun",
    options = { "--verbose-cmds", '--latex-args="-synctex=1"' },
  },
  tectonic = {
    name = "tectonic",
    executable = "tectonic",
    options = { "--keep-logs", "--synctex" },
  },
  arara = { name = "arara", executable = "arara", options = { "--log" } },
  generic = { name = "generic", command = "" },
  texpresso = {
    name = "texpresso",
    executable = "texpresso",
    continuous = 1,
    stdin_pipe = true,
    options = {},
  },
}

local function tex_program(self)
  local state = require("vimtex.state").get(vim.b.vimtex_id)
  return state and state.get_tex_program() or "_"
end

local builders = {}
function builders.latexmk(self, passed)
  local engine = self:get_engine()
  local command = "max_print_line=2000 "
    .. self:_get_executable_string()
    .. " "
    .. table.concat(self.options, " ")
  if self.callback == 1 then
    for name, status in pairs {
      compiling = "compiling",
      success = "success",
      failure = "failure",
    } do
      command = command
        .. " -e "
        .. util.shellescape(
          "$"
            .. name
            .. '_cmd = "echo vimtex_compiler_callback_'
            .. status
            .. '"'
        )
    end
  end
  if passed ~= "" then
    command = command .. " " .. vim.trim(passed)
  end
  command = command .. " " .. engine
  if self.out_dir ~= "" then
    command = command .. " -outdir=" .. vim.fn.fnameescape(self.out_dir)
  end
  if self.aux_dir ~= "" then
    command = command
      .. " -emulate-aux-dir -auxdir="
      .. vim.fn.fnameescape(self.aux_dir)
  end
  if self.continuous == 1 then
    command = command .. " -pvc -pvctimeout- -view=none"
  end
  return command .. " " .. util.shellescape(self.file_info.target_basename)
end
function builders.generic(self, passed)
  return self.command:gsub("@tex", util.shellescape(self.file_info.target))
    .. passed
end
function builders.arara(self, passed)
  return "arara "
    .. table.concat(self.options, " ")
    .. " "
    .. passed
    .. " "
    .. util.shellescape(self.file_info.target_basename)
end
function builders.tectonic(self, passed)
  local out = self.out_dir ~= "" and self.out_dir or self.file_info.root
  return "tectonic "
    .. table.concat(self.options, " ")
    .. ' --outdir="'
    .. out
    .. '" '
    .. passed
    .. " "
    .. util.shellescape(self.file_info.target_basename)
end
function builders.latexrun(self, passed)
  return "latexrun "
    .. table.concat(self.options, " ")
    .. " --latex-cmd "
    .. self:get_engine()
    .. " -O "
    .. (self.out_dir ~= "" and vim.fn.fnameescape(self.out_dir) or ".")
    .. passed
    .. " "
    .. util.shellescape(self.file_info.target_basename)
end
function builders.texpresso(self, passed)
  local options = { "-json", "-lines" }
  vim.list_extend(options, self.options)
  if passed ~= "" then
    table.insert(options, vim.trim(passed))
  end
  return "texpresso "
    .. table.concat(options, " ")
    .. " "
    .. util.shellescape(self.file_info.target_basename)
end

local function new(method, options)
  local self = vim.tbl_deep_extend(
    "force",
    vim.deepcopy(base),
    vim.deepcopy(defaults[method]),
    options
  )
  self.output = vim.fn.tempname()
  self.hooks = vim.deepcopy(self.hooks or {})
  self.__build_cmd = builders[method]
  if type(self.out_dir) == "function" then
    self.out_dir = self.out_dir(self.file_info)
  end
  if
    vim.env.VIMTEX_OUTPUT_DIRECTORY and vim.env.VIMTEX_OUTPUT_DIRECTORY ~= ""
  then
    if
      self.out_dir ~= "" and self.out_dir ~= vim.env.VIMTEX_OUTPUT_DIRECTORY
    then
      log.warning(
        "Setting VIMTEX_OUTPUT_DIRECTORY overrides out_dir!",
        "Changed out_dir from: " .. self.out_dir,
        "Changed out_dir to: " .. vim.env.VIMTEX_OUTPUT_DIRECTORY
      )
    end
    self.out_dir = vim.env.VIMTEX_OUTPUT_DIRECTORY
  end
  if method == "latexmk" then
    local names = { "out_dir", "aux_dir" }
    local values = rc_opts(self.file_info.root, {
      { option = names[1], kind = 0, default = "" },
      { option = names[2], kind = 0, default = "" },
    })
    for index, name in ipairs(names) do
      local value = values[index][1]
      if value ~= "" then
        self[name] = value
      end
    end
    function self._output_roots(instance)
      return {
        vim.env.VIMTEX_OUTPUT_DIRECTORY or "",
        instance.aux_dir,
        instance.out_dir,
        instance.file_info.root,
      }
    end
    function self.get_engine(instance)
      local program = tex_program(instance)
      local pdfmode = rc_opt(instance.file_info.root, "pdf_mode", 1, -1)
      local engines = { "pdflatex", "pdfps", "pdfdvi", "lualatex", "xelatex" }
      if program == "_" and pdfmode[1] >= 1 and pdfmode[1] <= 5 then
        program = engines[pdfmode[1]]
      elseif
        pdfmode[2] == 1
        and pdfmode[1] >= 1
        and pdfmode[1] <= 5
        and program ~= "_"
        and program ~= engines[pdfmode[1]]
      then
        log.warning(
          "Value of pdf_mode from latexmkrc is inconsistent with TeX program directive!",
          "TeX program: " .. program,
          "pdf_mode:    " .. engines[pdfmode[1]],
          "The value of pdf_mode will be ignored."
        )
      end
      return vim.g.vimtex_compiler_latexmk_engines[program]
        or vim.g.vimtex_compiler_latexmk_engines._
    end
    local clean_base = self.clean
    function self.clean(instance, full)
      local command = instance:_get_executable_string()
      if
        instance.clean_ext ~= ""
        and rc_opt(instance.file_info.root, "clean_ext", 0, -1)[2] == -1
      then
        command = command
          .. " -e "
          .. util.shellescape("$clean_ext = q/" .. instance.clean_ext .. "/;")
      end
      command = command .. ((full == true or full == 1) and " -C" or " -c")
      if instance.out_dir ~= "" then
        command = command .. " -outdir=" .. vim.fn.fnameescape(instance.out_dir)
      end
      command = command
        .. " "
        .. util.shellescape(instance.file_info.target_basename)
      require("vimtex.jobs").run(command, { cwd = instance.file_info.root })
      if not instance:_is_executable_available() then
        clean_base(instance, full)
      end
    end
  elseif method == "latexrun" then
    function self.get_engine(instance)
      local program = tex_program(instance)
      return vim.g.vimtex_compiler_latexrun_engines[program]
        or vim.g.vimtex_compiler_latexrun_engines._
    end
    function self.clean(instance)
      local output = instance.out_dir ~= "" and instance.out_dir or "."
      require("vimtex.jobs").run(
        "latexrun --clean-all -O " .. vim.fn.fnameescape(output),
        { cwd = instance.file_info.root }
      )
    end
  elseif method == "generic" then
    self.enabled = self.command ~= ""
  else
    self.enabled = self:_is_executable_available()
  end
  if method == "texpresso" then
    local protocol = require "vimtex.compiler.texpresso"
    table.insert(self.hooks, protocol.process_message)
    function self.texpresso_send(_, ...)
      protocol.send(...)
    end
    function self.texpresso_reload(instance)
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      protocol.send(
        "open",
        vim.fn.expand "%:p",
        #lines > 0 and table.concat(lines, "\n") .. "\n" or ""
      )
    end
    function self.texpresso_synctex_forward(instance)
      protocol.send("synctex-forward", vim.fn.expand "%:p", vim.fn.line ".")
    end
    function self.texpresso_previous_page()
      protocol.send "previous-page"
    end
    function self.texpresso_next_page()
      protocol.send "next-page"
    end
    function self.texpresso_theme()
      local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
      local function color(value)
        value = value or 0
        return {
          math.floor(value / 0x10000) / 255,
          math.floor(value / 0x100) % 0x100 / 255,
          value % 0x100 / 255,
        }
      end
      protocol.send("theme", color(normal.bg), color(normal.fg))
    end
    local start = self.start
    function self.start(instance, passed)
      start(instance, passed)
      if not instance:is_running() then
        return
      end
      instance.nvim_detach = protocol.attach()
      instance:texpresso_theme()
      instance:texpresso_reload()
    end
    local stop = self.stop
    function self.stop(instance)
      if instance.nvim_detach then
        instance.nvim_detach()
        instance.nvim_detach = nil
      end
      stop(instance)
    end
  end
  return bind(self)
end

local function method_for(target)
  local method = vim.g.vimtex_compiler_method
  if type(method) == "string" then
    if vim.fn.exists("*" .. method) == 1 then
      return vim.fn.call(method, { target })
    end
    return method
  end
  return vim.fn.call(method, { target })
end

function M.init(options)
  local method = method_for(options.file_info.target)
  if not defaults[method] then
    log.error("Error! Invalid compiler method: " .. tostring(method))
    method = "latexmk"
  end
  local configured = vim.deepcopy(vim.g["vimtex_compiler_" .. method] or {})
  return new(method, vim.tbl_deep_extend("force", configured, options))
end

function M.init_state(state)
  if vim.g.vimtex_compiler_enabled == 0 then
    return
  end
  state.compiler = M.init {
    file_info = {
      root = state.root,
      target = state.tex,
      target_name = state.name,
      target_basename = state.base,
      jobname = state.name,
    },
  }
end

function M.callback(status)
  status = tonumber(status)
  if not status then
    return
  end
  local compiler = vim.b.vimtex and vim.b.vimtex.compiler
  if not compiler then
    return
  end
  compiler.status = status
  local events = {
    [1] = "VimtexEventCompiling",
    [2] = "VimtexEventCompileSuccess",
    [3] = "VimtexEventCompileFailed",
  }
  if status >= 2 then
    local state = require("vimtex.state").get(vim.b.vimtex_id)
    if state then
      state.update_packages()
      vim.b.vimtex = state
      require("vimtex.syntax.packages").init()
    end
    require("vimtex.qf").open(false)
  end
  vim.api.nvim_exec_autocmds(
    "User",
    { pattern = events[status], modeline = false }
  )
end

function M.get_output_clashes(compiler, states)
  local signature = call(compiler, "get_output_signature", "aux") or ""
  if signature == "" then
    return {}
  end
  return vim.tbl_filter(function(state)
    return state.compiler ~= compiler
      and call(state.compiler, "is_running")
      and call(state.compiler, "get_output_signature", "aux") == signature
  end, states)
end

function M.start(options)
  local state = require("vimtex.state").get(vim.b.vimtex_id)
  local compiler = state and state.compiler
  if
    not compiler
    or not compiler.enabled
    or not state.is_compileable()
    or compiler.is_running()
  then
    return
  end
  if
    #M.get_output_clashes(compiler, require("vimtex.state").list_all()) > 0
  then
    return
  end
  compiler.start(vim.fn.expandcmd(options or ""))
end

function M.compile(options, bang)
  local compiler = require("vimtex.state").get(vim.b.vimtex_id).compiler
  if not compiler.is_running() then
    M.start(options)
  elseif not bang then
    M.stop()
  end
end

function M.compile_ss(options)
  local compiler = require("vimtex.state").get(vim.b.vimtex_id).compiler
  if not compiler.is_running() then
    compiler.start_single(vim.fn.expandcmd(options or ""))
  end
end

function M.stop()
  local compiler = require("vimtex.state").get(vim.b.vimtex_id).compiler
  if compiler and compiler.is_running() then
    compiler.stop()
  end
end

function M.stop_all()
  for _, state in ipairs(require("vimtex.state").list_all()) do
    if state.compiler and state.compiler.is_running() then
      state.compiler.stop()
    end
  end
end

function M.clean(full)
  vim.api.nvim_exec_autocmds("User", {
    pattern = "VimtexEventCleanStarted",
    modeline = false,
  })
  local compiler = require("vimtex.state").get(vim.b.vimtex_id).compiler
  local buffer_compiler = vim.b.vimtex and vim.b.vimtex.compiler or {}
  for _, key in ipairs { "clean_ext", "out_dir", "aux_dir" } do
    if buffer_compiler[key] ~= nil then
      compiler[key] = buffer_compiler[key]
    end
  end
  local restart = compiler.is_running()
  if restart then
    compiler.stop()
  end
  compiler.clean(full)
  vim.defer_fn(function()
    compiler.remove_dirs()
    if restart then
      compiler.start()
    end
    vim.api.nvim_exec_autocmds("User", {
      pattern = "VimtexEventCleanFinished",
      modeline = false,
    })
  end, 100)
end

function M.output()
  local compiler = require("vimtex.state").get(vim.b.vimtex_id).compiler
  if vim.fn.filereadable(compiler.output) == 0 then
    log.warning "No output exists!"
    return
  end
  vim.cmd("botright split " .. vim.fn.fnameescape(compiler.output))
end

function M.status(detailed)
  local compiler = require("vimtex.state").get(vim.b.vimtex_id).compiler
  log.info(
    compiler.is_running() and "Compiler is running"
      or "Compiler is not running!"
  )
end

function M.init_buffer()
  if vim.g.vimtex_compiler_enabled == 0 then
    return
  end
  local command = vim.api.nvim_buf_create_user_command
  command(0, "VimtexCompile", function(o)
    M.compile(o.args, o.bang)
  end, { nargs = "*", bang = true })
  command(0, "VimtexCompileSS", function(o)
    M.compile_ss(o.args)
  end, { nargs = "*" })
  command(0, "VimtexCompileOutput", M.output, {})
  command(0, "VimtexStop", M.stop, {})
  command(0, "VimtexStopAll", M.stop_all, {})
  command(0, "VimtexClean", function(o)
    M.clean(o.bang)
  end, { bang = true })
  command(0, "VimtexStatus", function(o)
    M.status(o.bang)
  end, { bang = true })
  local maps = {
    ["<plug>(vimtex-compile)"] = M.compile,
    ["<plug>(vimtex-compile-ss)"] = M.compile_ss,
    ["<plug>(vimtex-compile-output)"] = M.output,
    ["<plug>(vimtex-stop)"] = M.stop,
    ["<plug>(vimtex-stop-all)"] = M.stop_all,
    ["<plug>(vimtex-clean)"] = M.clean,
    ["<plug>(vimtex-clean-full)"] = function()
      M.clean(true)
    end,
  }
  for lhs, callback in pairs(maps) do
    vim.keymap.set("n", lhs, callback, { buffer = true })
  end
end

return M
