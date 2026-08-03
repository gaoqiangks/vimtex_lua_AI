local M = {}
local log = require "vimtex.log"

local modules = {
  "cache",
  "cmd",
  "compiler",
  "delim",
  "env",
  "fold",
  "imaps",
  "log",
  "matchparen",
  "motion",
  "qf",
  "state",
  "text_obj",
  "toc",
  "view",
}

-- Do not load feature modules that are explicitly disabled. Their
-- init_buffer() functions also guard themselves, but requiring them can pull
-- in sizeable parser and backend dependency trees for no effect.
local module_options = {
  compiler = "vimtex_compiler_enabled",
  complete = "vimtex_complete_enabled",
  doc = "vimtex_doc_enabled",
  fold = "vimtex_fold_enabled",
  format = "vimtex_format_enabled",
  imaps = "vimtex_imaps_enabled",
  matchparen = "vimtex_matchparen_enabled",
  motion = "vimtex_motion_enabled",
  qf = "vimtex_quickfix_enabled",
  text_obj = "vimtex_text_obj_enabled",
  toc = "vimtex_toc_enabled",
  view = "vimtex_view_enabled",
}

local function module_enabled(name)
  local option = module_options[name]
  return not option or vim.g[option] ~= 0
end

local buffer_ids = {}
local buffer_modules = {}
local disabled_mappings = {}

local function init_lazy_modules(disabled)
  if not disabled.complete and module_enabled "complete" then
    vim.bo.omnifunc = "vimtex#complete#omnifunc"
  end
  if not disabled.format and module_enabled "format" then
    vim.bo.formatexpr = "v:lua.require('vimtex.format').formatexpr()"
  end
  if not disabled.context then
    vim.api.nvim_buf_create_user_command(0, "VimtexContextMenu", function()
      require("vimtex.context").menu()
    end, {})
    vim.keymap.set("n", "<plug>(vimtex-context-menu)", function()
      require("vimtex.context").menu()
    end, { buffer = true })
  end
  if not disabled.doc and module_enabled "doc" then
    vim.api.nvim_buf_create_user_command(0, "VimtexDocPackage", function(opts)
      require("vimtex.doc").package(opts.args)
    end, { nargs = "?" })
    vim.keymap.set(
      "n",
      "<plug>(vimtex-doc-package)",
      "<cmd>VimtexDocPackage<cr>",
      { buffer = true }
    )
  end
  if not disabled.info then
    vim.api.nvim_buf_create_user_command(0, "VimtexInfo", function(opts)
      require("vimtex.info").open(opts.bang)
    end, { bang = true })
    vim.keymap.set("n", "<Plug>(vimtex-info)", function()
      require("vimtex.info").open(false)
    end, { buffer = true })
    vim.keymap.set("n", "<Plug>(vimtex-info-full)", function()
      require("vimtex.info").open(true)
    end, { buffer = true })
  end
  if not disabled.misc then
    vim.api.nvim_buf_create_user_command(0, "VimtexReload", function()
      require("vimtex.misc").reload()
    end, {})
    local function count(opts, letters)
      require("vimtex.misc").wordcount_display {
        range = { opts.line1, opts.line2 },
        detailed = opts.bang,
        count_letters = letters,
      }
    end
    vim.api.nvim_buf_create_user_command(0, "VimtexCountWords", function(opts)
      count(opts, false)
    end, { bang = true, range = "%" })
    vim.api.nvim_buf_create_user_command(0, "VimtexCountLetters", function(opts)
      count(opts, true)
    end, { bang = true, range = "%" })
    vim.keymap.set("n", "<Plug>(vimtex-reload)", function()
      require("vimtex.misc").reload()
    end, { buffer = true })
  end
end

local function init_filetype()
  vim.bo.comments = "sO:% -,mO:%  ,eO:%%,:%"
  vim.bo.commentstring = "%% %s"
  local suffixes = {
    ".sty",
    ".cls",
    ".log",
    ".aux",
    ".bbl",
    ".out",
    ".blg",
    ".brf",
    ".cb",
    ".dvi",
    ".fdb_latexmk",
    ".fls",
    ".idx",
    ".ilg",
    ".ind",
    ".inx",
    ".pdf",
    ".synctex.gz",
    ".toc",
  }
  vim.opt_local.suffixes:append(suffixes)
  if vim.bo.filetype == "bib" then
    vim.opt_local.suffixesadd = { ".tex", ".bib" }
    if vim.g.vimtex_fold_bib_enabled == 1 then
      require("vimtex.fold.bib").init()
    end
    return {
      fold = true,
      matchparen = true,
      format = true,
      doc = true,
      imaps = true,
      delim = true,
      env = true,
      motion = true,
      complete = true,
    }
  end
  vim.opt_local.suffixesadd = { ".tex", ".sty", ".cls" }
  vim.opt_local.iskeyword:append ":"
  vim.bo.includeexpr = "v:lua.require'vimtex.include'.expr()"
  vim.bo.include = vim.g["vimtex#re#tex_include"]
  vim.bo.define =
    [=[\v\\%(([egx]|mathchar|count|dimen|muskip|skip|toks)?def|font|(future)?let|new(count|dimen|skip|muskip|box|toks|read|write|fam|insert)|(re)?new(boolean|command|counter|environment|font|if|length|savebox|theorem(style)?)|DeclareMathOperator|bibitem%(\[[^]]*\])?)]=]
  return {}
end

local function map(mode, lhs, rhs, tex_only, force)
  if tex_only and vim.bo.filetype ~= "tex" then
    return
  end
  if disabled_mappings[mode] and disabled_mappings[mode][lhs] then
    return
  end
  if vim.fn.hasmapto(rhs, mode) == 1 then
    return
  end
  if
    not force
    and vim.g.vimtex_mappings_override_existing == 0
    and vim.fn.maparg(lhs, mode) ~= ""
  then
    return
  end
  vim.keymap.set(
    mode,
    lhs,
    rhs,
    { buffer = true, silent = true, nowait = true, remap = true }
  )
end

local function prefixed(mode, lhs, rhs, tex_only)
  map(mode, vim.g.vimtex_mappings_prefix .. lhs, rhs, tex_only)
end

local function mappings()
  if vim.g.vimtex_mappings_enabled == 0 then
    return
  end
  disabled_mappings = {}
  for mode, mappings_disabled in pairs(vim.g.vimtex_mappings_disable or {}) do
    local lookup = {}
    for _, lhs in ipairs(mappings_disabled) do
      lookup[lhs] = true
    end
    disabled_mappings[mode] = lookup
  end
  for _, item in ipairs {
    { "i", "<plug>(vimtex-info)" },
    { "I", "<plug>(vimtex-info-full)" },
    { "x", "<plug>(vimtex-reload)" },
    { "X", "<plug>(vimtex-reload-state)" },
    { "s", "<plug>(vimtex-toggle-main)", true },
    { "q", "<plug>(vimtex-log)" },
    { "a", "<plug>(vimtex-context-menu)", true },
  } do
    prefixed("n", item[1], item[2], item[3])
  end
  local direct = {
    { "n", "ds$", "<plug>(vimtex-env-delete-math)" },
    { "n", "cs$", "<plug>(vimtex-env-change-math)" },
    { "n", "dse", "<plug>(vimtex-env-delete)" },
    { "n", "cse", "<plug>(vimtex-env-change)" },
    { "n", "tse", "<plug>(vimtex-env-toggle)" },
    { "n", "tss", "<plug>(vimtex-env-toggle-star)" },
    { "n", "ts$", "<plug>(vimtex-env-toggle-math)" },
    { "n", "dsc", "<plug>(vimtex-cmd-delete)" },
    { "n", "csc", "<plug>(vimtex-cmd-change)" },
    { "n", "tsc", "<plug>(vimtex-cmd-toggle-star)" },
    { "n", "tsf", "<plug>(vimtex-cmd-toggle-frac)" },
    { "x", "tsf", "<plug>(vimtex-cmd-toggle-frac)" },
    { "n", "tsb", "<plug>(vimtex-cmd-toggle-break)" },
    { "n", "dsd", "<plug>(vimtex-delim-delete)" },
    { "n", "csd", "<plug>(vimtex-delim-change-math)" },
    { "n", "tsd", "<plug>(vimtex-delim-toggle-modifier)" },
    { "x", "tsd", "<plug>(vimtex-delim-toggle-modifier)" },
    { "n", "tsD", "<plug>(vimtex-delim-toggle-modifier-reverse)" },
    { "x", "tsD", "<plug>(vimtex-delim-toggle-modifier-reverse)" },
    { "i", "]]", "<plug>(vimtex-delim-close)" },
  }
  for _, mode in ipairs { "i", "n", "x" } do
    table.insert(direct, { mode, "<F7>", "<plug>(vimtex-cmd-create)" })
  end
  table.insert(direct, { "n", "<F6>", "<plug>(vimtex-env-surround-line)" })
  table.insert(direct, { "x", "<F6>", "<plug>(vimtex-env-surround-visual)" })
  table.insert(direct, { "n", "<F8>", "<plug>(vimtex-delim-add-modifiers)" })
  for _, item in ipairs(direct) do
    map(item[1], item[2], item[3])
  end
  if vim.g.vimtex_compiler_enabled == 1 then
    for _, item in ipairs {
      { "l", "<plug>(vimtex-compile)" },
      { "S", "<plug>(vimtex-compile-ss)" },
      { "o", "<plug>(vimtex-compile-output)" },
      { "k", "<plug>(vimtex-stop)" },
      { "K", "<plug>(vimtex-stop-all)" },
      { "e", "<plug>(vimtex-errors)" },
      { "c", "<plug>(vimtex-clean)" },
      { "C", "<plug>(vimtex-clean-full)" },
      { "g", "<plug>(vimtex-status)" },
      { "G", "<plug>(vimtex-status-all)" },
    } do
      prefixed("n", item[1], item[2])
    end
    prefixed("n", "L", "<plug>(vimtex-compile-selected)", true)
    prefixed("x", "L", "<plug>(vimtex-compile-selected)", true)
  end
  if vim.g.vimtex_motion_enabled == 1 then
    for _, lhs in ipairs {
      "%",
      "]]",
      "][",
      "[]",
      "[[",
      "]M",
      "]m",
      "[M",
      "[m",
      "]N",
      "]n",
      "[N",
      "[n",
      "]R",
      "]r",
      "[R",
      "[r",
      "]/",
      "]*",
      "[/",
      "[*",
    } do
      for _, mode in ipairs { "n", "x", "o" } do
        map(mode, lhs, "<plug>(vimtex-" .. lhs .. ")", true, lhs == "%")
      end
    end
  end
  if vim.g.vimtex_text_obj_enabled == 1 then
    for _, lhs in ipairs {
      "id",
      "ad",
      "i$",
      "a$",
      "iP",
      "aP",
      "im",
      "am",
      "ie",
      "ae",
      "ic",
      "ac",
    } do
      for _, mode in ipairs { "x", "o" } do
        map(mode, lhs, "<plug>(vimtex-" .. lhs .. ")", lhs:match "[Pm]$" ~= nil)
      end
    end
  end
  if vim.g.vimtex_toc_enabled == 1 then
    prefixed("n", "t", "<plug>(vimtex-toc-open)")
    prefixed("n", "T", "<plug>(vimtex-toc-toggle)")
  end
  if vim.b.vimtex.viewer then
    prefixed("n", "v", "<plug>(vimtex-view)")
  end
  if vim.g.vimtex_imaps_enabled == 1 then
    prefixed("n", "m", "<plug>(vimtex-imaps-list)")
  end
  if vim.g.vimtex_doc_enabled == 1 then
    map("n", "K", "<plug>(vimtex-doc-package)", true)
  end
end

local function filename_changed_pre(buffer)
  local state = require("vimtex.state").get(vim.b[buffer].vimtex_id)
  vim.b[buffer].vimtex_filename_was_main = state
    and vim.api.nvim_buf_get_name(buffer) == state.tex
end

local function filename_changed_post(buffer)
  if not vim.b[buffer].vimtex_filename_was_main then
    return
  end
  local state = require("vimtex.state").get(vim.b[buffer].vimtex_id)
  local old = state.tex
  state.tex = vim.api.nvim_buf_get_name(buffer)
  state.root, state.base =
    vim.fn.fnamemodify(state.tex, ":h"), vim.fn.fnamemodify(state.tex, ":t")
  state.name = vim.fn.fnamemodify(state.tex, ":t:r")
  log.warning "Filename change detected"
  log.info("Old: " .. old)
  log.info("New: " .. state.tex)
  if state.compiler then
    if state.compiler.is_running() then
      state.compiler.stop()
    end
    require("vimtex.compiler").init_state(state)
  end
  vim.b[buffer].vimtex = state
end

local function init_buffer()
  local disabled = init_filetype()
  for _, name in ipairs(vim.b.vimtex.disabled_modules or {}) do
    disabled[name] = true
  end
  local group = vim.api.nvim_create_augroup(
    "vimtex_buffers_" .. vim.api.nvim_get_current_buf(),
    { clear = true }
  )
  local buffer = vim.api.nvim_get_current_buf()
  vim.api.nvim_create_autocmd("BufFilePre", {
    group = group,
    buffer = buffer,
    callback = function()
      filename_changed_pre(buffer)
    end,
  })
  vim.api.nvim_create_autocmd("BufFilePost", {
    group = group,
    buffer = buffer,
    callback = function()
      filename_changed_post(buffer)
    end,
  })
  vim.api.nvim_create_autocmd("BufUnload", {
    group = group,
    buffer = buffer,
    callback = function(args)
      buffer_ids[args.buf] = vim.b[args.buf].vimtex_id
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = buffer,
    callback = function(args)
      local id = buffer_ids[args.buf] or vim.b[args.buf].vimtex_id
      require("vimtex.state").cleanup(id)
      for _, module in ipairs(buffer_modules[args.buf] or {}) do
        if type(module.cleanup_buffer) == "function" then
          pcall(module.cleanup_buffer, args.buf)
        end
      end
      buffer_modules[args.buf] = nil
      buffer_ids[args.buf] = nil
      pcall(vim.api.nvim_del_augroup_by_id, group)
    end,
  })
  init_lazy_modules(disabled)
  local initialized = {}
  for _, name in ipairs(modules) do
    if not disabled[name] and module_enabled(name) then
      local ok, module = pcall(require, "vimtex." .. name)
      if ok and type(module.init_buffer) == "function" then
        local initialized_ok = pcall(module.init_buffer)
        if initialized_ok then
          initialized[#initialized + 1] = module
        end
      end
    end
  end
  buffer_modules[buffer] = initialized
end

function M.quit()
  require("vimtex.state").cleanup_all()
  require("vimtex.cache").write_all()
end

function M.init()
  vim.api.nvim_exec_autocmds(
    "User",
    { pattern = "VimtexEventInitPre", modeline = false }
  )
  require("vimtex.options").init()
  require("vimtex.state").init()
  require("vimtex.state").init_local()
  init_buffer()
  mappings()
  vim.api.nvim_exec_autocmds(
    "User",
    { pattern = "VimtexEventInitPost", modeline = false }
  )
end

return M
