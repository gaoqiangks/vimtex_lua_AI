local health = vim.health

local M = {}

local function executable(program)
  return vim.fn.executable(program) == 1
end

local function check_general()
  health.ok "Neovim version is supported"

  if not executable "bibtex" then
    health.warn(
      "bibtex is not executable",
      { "bibtex is required for cite completions" }
    )
  end
  if not executable "biber" then
    health.warn(
      "biber is not executable",
      { "Biber is required by many bibliography configurations" }
    )
  end
end

local function check_plugin_clash()
  local scripts = vim.api.nvim_exec2("scriptnames", { output = true }).output
  if scripts:lower():find "latex%-box" then
    health.warn("Conflicting plugin detected: LaTeX-Box", {
      "Disable or remove LaTeX-Box before using VimTeX",
    })
  end
end

local function check_compiler()
  if vim.g.vimtex_compiler_enabled == 0 then
    return
  end

  local method = vim.g.vimtex_compiler_method
  if type(method) == "function" then
    method = method "[nofile]"
  elseif type(method) == "string" and vim.fn.exists("*" .. method) == 1 then
    method = vim.fn[method] "[nofile]"
  end

  if type(method) ~= "string" or not executable(method) then
    health.error(
      ("g:vimtex_compiler_method (`%s`) is not executable"):format(
        tostring(method)
      )
    )
  else
    health.ok "Compiler should work"
  end
end

local viewers = {}

function viewers.general()
  local viewer = vim.g.vimtex_view_general_viewer
  if executable(viewer) then
    health.ok "General viewer should work"
  else
    health.error("Selected viewer is not executable", {
      "Selection: " .. tostring(viewer),
      ":help g:vimtex_view_general_viewer",
    })
  end
end

local function check_programs(name, programs)
  local ok = true
  for _, item in ipairs(programs) do
    if not executable(item[1]) then
      health[item[2] or "error"](("%s requires `%s`"):format(name, item[1]))
      ok = false
    end
  end
  if ok then
    health.ok(name .. " should work")
  end
end

function viewers.zathura()
  check_programs("Zathura", { { "zathura" }, { "xdotool", "warn" } })
end

function viewers.zathura_simple()
  check_programs("Zathura", { { "zathura" } })
end

function viewers.mupdf()
  check_programs(
    "MuPDF",
    { { "mupdf" }, { "xdotool", "warn" }, { "synctex", "warn" } }
  )
end

function viewers.sioyek()
  check_programs("Sioyek", { { vim.g.vimtex_view_sioyek_exe } })
end

local mac_app_ids = {
  galley = "GalleyPDF",
  skim = "Skim",
  texshop = "TeXShop",
}

local function check_macos_viewer(method)
  local app = mac_app_ids[method]
  local script = ('tell application "Finder" to POSIX path of (get application file id (id of application "%s") as alias)'):format(
    app
  )
  vim.fn.system { "osascript", "-e", script }
  if vim.v.shell_error == 0 then
    health.ok(app .. " viewer should work")
  else
    health.error(app .. " is not installed")
  end
end

local function check_view()
  local method = vim.g.vimtex_view_method
  if viewers[method] then
    viewers[method]()
  elseif mac_app_ids[method] then
    check_macos_viewer(method)
  end

  if executable "xdotool" and not executable "pstree" then
    health.warn(
      "pstree is unavailable",
      { "Inverse search works better when pstree is installed" }
    )
  end
end

function M.check()
  require("vimtex.options").init()

  health.start "VimTeX"
  check_general()
  check_plugin_clash()
  check_view()
  check_compiler()
end

return M
