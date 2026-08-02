local M = {}

local function chunks(input)
  if type(input) == "string" then
    return { { input, "VimtexMsg" } }
  end
  local result = {}
  for _, part in ipairs(input) do
    result[#result + 1] = type(part) == "string" and { part, "VimtexMsg" }
      or { tostring(part[2]), part[1] }
  end
  return result
end

function M.echo(input, opts)
  if
    input == nil
    or input == ""
    or (type(input) == "table" and vim.tbl_isempty(input))
  then
    return
  end
  opts = vim.tbl_extend("force", { indent = 0 }, opts or {})
  if type(input) == "table" and not vim.islist(input) then
    for key, value in pairs(input) do
      local line =
        { { string.rep(" ", opts.indent) }, { tostring(key) .. ": ", "Label" } }
      vim.api.nvim_echo(vim.list_extend(line, chunks(value)), true, {})
    end
    return
  end
  local line = { { string.rep(" ", opts.indent) } }
  vim.api.nvim_echo(vim.list_extend(line, chunks(input)), true, {})
end

function M.confirm(prompt)
  M.echo(prompt)
  vim.api.nvim_echo({ { " [y]es/[n]o: ", "VimtexMsg" } }, false, {})
  while true do
    local input = vim.fn.nr2char(vim.fn.getchar())
    if input == "y" or input == "Y" then
      return true
    end
    if input == "n" or input == "N" or input == "\27" or input == "\3" then
      return false
    end
  end
end

function M.input(options)
  options = vim.tbl_extend(
    "force",
    { prompt = "> ", text = "", info = "" },
    options or {}
  )
  if vim.g.vimtex_echo_verbose_input ~= 0 and options.info ~= "" then
    M.echo(options.info)
  end
  if options.completion then
    return vim.fn.input(options.prompt, options.text, options.completion)
  end
  return vim.fn.input(options.prompt, options.text)
end

function M.get_number(maximum, digits, force_choice, do_echo)
  local choice = ""
  if do_echo then
    vim.api.nvim_echo({ { "> " } }, false, {})
  end
  while #choice < digits do
    if #choice > 0 and tonumber(choice .. "0") > maximum then
      return tonumber(choice) - 1
    end
    local input = vim.fn.nr2char(vim.fn.getchar())
    if
      not force_choice and (input == "\3" or input == "\27" or input == "x")
    then
      return -2
    end
    if #choice > 0 and input == "\r" then
      return tonumber(choice) - 1
    end
    if input:match "%d" and tonumber(choice .. input) > 0 then
      choice = choice .. input
      if do_echo then
        vim.api.nvim_echo({ { input } }, false, {})
      end
    end
  end
  return tonumber(choice) - 1
end

function M.select(container, options)
  options = vim.tbl_extend("force", {
    prompt = "Please choose item:",
    ["return"] = "value",
    force_choice = false,
    auto_select = true,
  }, options or {})
  local keys, list = nil, container
  if not vim.islist(container) then
    keys, list = vim.tbl_keys(container), vim.tbl_values(container)
  end
  local index, value = -1, ""
  if #list == 1 and options.auto_select then
    index, value = 0, list[1]
  elseif #list > 0 then
    local digits = #tostring(#list)
    M.echo(options.prompt)
    for item_index, item in ipairs(list) do
      local label = type(item) == "table" and item.name or item
      M.echo {
        { "VimtexWarning", ("%" .. digits .. "d: "):format(item_index) },
        tostring(label),
      }
    end
    if not options.force_choice then
      M.echo {
        { "VimtexWarning", string.rep(" ", digits - 1) .. "x: " },
        "Abort",
      }
    end
    index = M.get_number(#list, digits, options.force_choice, false)
    value = index >= 0 and list[index + 1] or ""
  end
  if options["return"] == "value" then
    return value
  end
  return keys and (index >= 0 and keys[index + 1] or "") or index
end

function M.get_winwidth()
  local info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
  return vim.api.nvim_win_get_width(0) - (info and info.textoff or 0)
end

function M.blink()
  vim.fn.sign_define("vimtexblink", { linehl = "VimtexBlink" })
  for _ = 1, 4 do
    vim.fn.sign_place(
      1,
      "vimtex",
      "vimtexblink",
      vim.api.nvim_get_current_buf(),
      { lnum = vim.fn.line "." }
    )
    vim.cmd.redraw()
    vim.wait(150)
    vim.fn.sign_unplace "vimtex"
    vim.cmd.redraw()
    vim.wait(150)
  end
  vim.fn.sign_undefine "vimtexblink"
end

_G.vimtex_ui_echo = M.echo
_G.vimtex_ui_confirm = M.confirm
_G.vimtex_ui_input = M.input
_G.vimtex_ui_select = M.select
_G.vimtex_ui_get_number = M.get_number
_G.vimtex_ui_get_winwidth = M.get_winwidth
_G.vimtex_ui_blink = M.blink

return M
