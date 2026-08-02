local M = {}

local function show_entry(entry)
  local copy = vim.deepcopy(entry)
  require("vimtex.ui").echo {
    { "Normal", "@" },
    { "VimtexMsg", copy.type },
    { "Normal", "{" },
    { "Special", copy.key },
    { "Normal", "," },
  }
  for _, key in ipairs { "key", "type", "source_lnum", "source_file" } do
    copy[key] = nil
  end
  for _, key in ipairs { "title", "author", "year" } do
    if copy[key] then
      require("vimtex.ui").echo {
        { "VimtexInfoValue", "  " .. key .. ": " },
        { "Normal", copy[key] },
      }
      copy[key] = nil
    end
  end
  for key, value in pairs(copy) do
    require("vimtex.ui").echo {
      { "VimtexInfoValue", "  " .. key .. ": " },
      { "Normal", value },
    }
  end
  require("vimtex.ui").echo { { "Normal", "}" } }
end

local function goto_entry(entry, split)
  vim.cmd(
    (split and "split " or "edit ") .. vim.fn.fnameescape(entry.source_file)
  )
  vim.cmd "filetype detect"
  require("vimtex.pos").set_cursor(entry.source_lnum, 0)
  vim.cmd "normal! zv"
end

local function cite_actions(command, word)
  local cite = require "vimtex.cite"
  local selected = cite.get_key(command, word)
  if selected == "" then
    return
  end
  local entry = cite.get_entry(selected)
  if vim.tbl_isempty(entry) then
    require("vimtex.log").warning("Cite key not found: " .. selected)
    return {}
  end
  local actions = {
    prompt = "Context menu for citekey " .. entry.key,
    selected = selected,
    entry = entry,
    {
      name = "Edit entry",
      run = function()
        goto_entry(entry, false)
      end,
    },
    {
      name = "Show entry",
      run = function()
        show_entry(entry)
      end,
    },
  }
  if entry.file then
    local pdfs = vim.tbl_filter(function(file)
      return vim.fn.fnamemodify(file, ":e"):lower() == "pdf"
    end, vim.split(entry.file, ";", { trimempty = true }))
    if #pdfs > 0 then
      table.insert(actions, {
        name = "Open PDF",
        run = function()
          local readable = vim.tbl_filter(function(file)
            return vim.fn.filereadable(vim.fn.expand(file)) == 1
          end, pdfs)
          if #readable == 0 then
            require("vimtex.log").warning "Could not open PDF file!"
            return
          end
          local file =
            require("vimtex.ui").select(readable, { prompt = "Open file:" })
          if file then
            require("vimtex.jobs").start(
              vim.g.vimtex_context_pdf_viewer
                .. " "
                .. require("vimtex.util").shellescape(file),
              { detached = true }
            )
          end
        end,
      })
    end
  end
  if entry.doi then
    table.insert(actions, {
      name = "Open doi",
      run = function()
        require("vimtex.util").www("http://dx.doi.org/" .. entry.doi)
      end,
    })
  end
  if
    entry.eprint
    and (entry.eprint:sub(1, 5) == "arXiv" or entry.archiveprefix == "arXiv")
  then
    table.insert(actions, {
      name = "Open arXiv",
      run = function()
        require("vimtex.util").www(
          "https://arxiv.org/abs/" .. entry.eprint:gsub("^arXiv:", "")
        )
      end,
    })
  end
  if entry.url then
    table.insert(actions, {
      name = "Open url",
      run = function()
        require("vimtex.util").www(entry.url)
      end,
    })
  end
  if vim.fn.executable "zotero" == 1 then
    table.insert(actions, {
      name = "Open in Zotero",
      run = function()
        require("vimtex.util").www("zotero://select/items/bbt:" .. entry.key)
      end,
    })
  end
  return actions
end

local function glossary_actions(command, word)
  if
    vim.tbl_isempty(command)
    or not command.name:sub(2):match "^[cpdr]?[gG][lL][sS]"
    or #command.args ~= 1
  then
    return
  end
  local keys = vim.split(
    table.concat(
      vim.tbl_map(function(argument)
        return argument.text
      end, command.args),
      ","
    ),
    ",%s*",
    { trimempty = true }
  )
  local selected = vim.tbl_contains(keys, word) and word or keys[1]
  if not selected or selected == "" then
    return
  end
  local state, entries = vim.b.vimtex or {}, {}
  require("vimtex.paths").pushd(state.root)
  for _, file in ipairs(state.glossaries or {}) do
    vim.list_extend(
      entries,
      require("vimtex.parser").bib(file, { backend = "lua" })
    )
  end
  require("vimtex.paths").popd()
  local entry
  for _, candidate in ipairs(entries) do
    if candidate.key == selected then
      entry = candidate
      break
    end
  end
  if not entry then
    require("vimtex.log").warning("Glossary key not found: " .. selected)
    return {}
  end
  return {
    prompt = "Context menu for glossary key: " .. entry.key,
    selected = selected,
    entry = entry,
    {
      name = "Go to entry",
      run = function()
        goto_entry(entry, false)
      end,
    },
    {
      name = "Go to entry in split",
      run = function()
        goto_entry(entry, true)
      end,
    },
    {
      name = "Show entry",
      run = function()
        show_entry(entry)
      end,
    },
  }
end

local handlers = { cite_actions, glossary_actions }

function M.get(...)
  local saved
  if select("#", ...) > 0 then
    saved = require("vimtex.pos").get_cursor()
    require("vimtex.pos").set_cursor(...)
  end
  local command, word =
    require("vimtex.cmd").get_current(), vim.fn.expand "<cword>"
  if saved then
    require("vimtex.pos").set_cursor(saved)
  end
  if vim.tbl_isempty(command) then
    return
  end
  for _, handler in ipairs(handlers) do
    local actions = handler(command, word)
    if actions ~= nil then
      return { cmd = command, word = word, actions = actions }
    end
  end
end

function M.inspect(...)
  local context = M.get(...)
  if not context or not context.actions then
    return {}
  end
  local menu = {}
  for _, action in ipairs(context.actions) do
    menu[#menu + 1] = { name = action.name }
  end
  return {
    selected = context.actions.selected,
    entry = context.actions.entry,
    menu = menu,
  }
end

function M.menu()
  local context = M.get()
  if not context or not context.actions or #context.actions == 0 then
    return
  end
  local names = vim.tbl_map(function(action)
    return action.name
  end, context.actions)
  local selected =
    require("vimtex.ui").select(names, { prompt = context.actions.prompt })
  if not selected then
    return
  end
  for _, action in ipairs(context.actions) do
    if action.name == selected then
      pcall(action.run)
      return
    end
  end
end

function M.init_buffer()
  vim.api.nvim_buf_create_user_command(0, "VimtexContextMenu", M.menu, {})
  vim.keymap.set("n", "<plug>(vimtex-context-menu)", M.menu, { buffer = true })
end

return M
