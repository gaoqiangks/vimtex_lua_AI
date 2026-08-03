local cache = require "vimtex.cache"
local kpsewhich = require "vimtex.kpsewhich"
local util = require "vimtex.util"

local M = {}

local function compiler_file(extension)
  return vim.api.nvim_eval(
    ("b:vimtex.compiler.get_file('%s')"):format(extension)
  )
end

local function validate(files)
  local result = {}
  for _, file in ipairs(files) do
    if file ~= "" then
      file = file:gsub("%.bib$", "") .. ".bib"
      if vim.fn.filereadable(file) ~= 1 then
        file = kpsewhich.find(file)
      end
      if vim.fn.filereadable(file) == 1 then
        result[#result + 1] = file
      end
    end
  end
  return result
end

local function manual_files(state)
  local store = cache.open("bibfiles", {
    ["local"] = true,
    default = { files = {}, ftime = -1 },
  })
  local local_state = vim.b.vimtex_local
  local id = type(local_state) == "table" and local_state.main_id
    or vim.b.vimtex_id
  local project = require("vimtex.state").get(id)
  local bibfiles = {}
  local sources = project.get_sources()
  for _, source in ipairs(sources) do
    local file = project.root .. "/" .. source
    local current = store:get(file)
    local mtime = vim.fn.getftime(file)
    if mtime > current.ftime then
      store.modified = true
      current.ftime = mtime
      current.files = {}

      for _, line in ipairs(util.readfile(file)) do
        line = line:gsub("%%.*$", "")
        local command = line:match "\\([A-Za-z]+)%s*%b[]%s*{"
        if not command then
          command = line:match "\\([A-Za-z]+)%s*{"
        end
        local entry = line:match "^[^{]*{(.*)}%s*$"
        if command and entry then
          local recognized = false
          for _, expression in ipairs(vim.g.vimtex_bibliography_commands) do
            if vim.fn.match(command, [[\v^]] .. expression .. "$") >= 0 then
              recognized = true
              break
            end
          end
          if recognized then
            entry = entry:gsub("\\jobname", state.name)
            local files = vim.split(entry, ",", { trimempty = true })
            if #files > 1 then
              files[#files + 1] = entry
            end
            local initial = vim.deepcopy(files)
            for _, expression in ipairs(initial) do
              if expression:find "[*?{[]" then
                local ok, expanded = pcall(vim.fn.glob, expression, false, true)
                if ok then
                  vim.list_extend(files, expanded)
                end
              end
            end
            vim.list_extend(current.files, files)
          end
        end
      end
      store.data[file] = current
    end
    vim.list_extend(bibfiles, current.files)
  end
  store:write()

  local unique = {}
  local previous
  for _, file in ipairs(bibfiles) do
    if file ~= previous then
      unique[#unique + 1] = file
    end
    previous = file
  end
  return unique
end

function M.files()
  local state = vim.b.vimtex
  if type(state) ~= "table" then
    return {}
  end

  if type(state.compiler) == "table" then
    if state.packages.biblatex then
      local bcf = compiler_file "bcf"
      if vim.fn.filereadable(bcf) == 1 then
        local bibs = {}
        for _, line in ipairs(util.readfile(bcf)) do
          if line:find("bcf:datasource", 1, true) then
            bibs[#bibs + 1] = line:match "<[^>]*>([^<]*)" or ""
          end
        end
        for _, file in ipairs(vim.deepcopy(bibs)) do
          if file:find "[*?{[]" then
            vim.list_extend(bibs, vim.fn.glob(file, false, true))
          end
        end
        if #bibs > 0 then
          return validate(bibs)
        end
      end
    end

    local blg = compiler_file "blg"
    if vim.fn.filereadable(blg) == 1 then
      local bibs = {}
      for _, line in ipairs(util.readfile(blg)) do
        local file = line:match "^Database file #%d+: (.*)%.bib$"
        if file then
          local ignored_biblatex = state.packages.biblatex
            and file:match "%-blx$"
          local ignored_revtex = state.documentclass:match "^revtex4"
            and file:match ".Notes$"
          if not ignored_biblatex and not ignored_revtex then
            bibs[#bibs + 1] = file
          end
        end
      end
      if #bibs > 0 then
        return validate(bibs)
      end
    end
  end
  return validate(manual_files(state))
end

return M
