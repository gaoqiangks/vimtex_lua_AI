local M = {}

local function print_error(error)
  local prefix, line, message = error:match "^(.-) line (%d+): (.*)$"
  if not prefix then
    prefix, message = error:match "^(.-): (.*)$"
  end
  prefix = vim.fn.fnamemodify(prefix or "", ":.")
  vim.api.nvim_echo({
    {
      string.format(
        "%s%s: %s\n",
        prefix,
        line and ":" .. line or "",
        message or error
      ),
    },
  }, true, {})
end

function M.finished()
  for _, error in ipairs(vim.v.errors) do
    print_error(error)
  end
  if #vim.v.errors > 0 then
    vim.cmd "cquit"
  else
    vim.cmd "quitall!"
  end
end

function M.completion(context, base)
  local ok, result = pcall(function()
    vim.cmd("silent normal GO" .. context .. "\24\15")
    vim.cmd "silent normal! u"
    return require("vimtex.complete").omnifunc(0, base or "")
  end)
  if ok then
    return result
  end
  vim.fn.assert_report(
    string.format(
      "\n  Context: %s\n  Base: %s\n%s",
      context,
      base or "",
      result
    )
  )
  return {}
end

function M.keys(keys, context, expected)
  vim.cmd "bwipeout!"
  vim.cmd "setfiletype tex"
  local lines = type(context) == "string" and { context } or context
  local description = type(context) == "string" and ("Context: " .. context)
    or ("Context:\n" .. table.concat(context, "\n"))
  local ok, error = pcall(function()
    vim.fn.append(1, lines)
    vim.cmd "normal! ggdd"
    vim.api.nvim_feedkeys(keys, "xt", false)
  end)
  if not ok then
    vim.fn.assert_report(
      string.format("\n  Keys: %s\n  %s\n%s", keys, description, error)
    )
  end
  local observed = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  if type(expected) == "string" then
    observed = table.concat(observed)
  end
  vim.fn.assert_equal(
    expected,
    observed,
    string.format("Keys: %s\n  %s", keys, description)
  )
end

function M.main(file, expected, toggle)
  vim.cmd("silent edit " .. vim.fn.fnameescape(file))
  if toggle ~= nil then
    vim.cmd "VimtexToggleMain"
  end
  expected = expected == "" and "" or vim.fn.fnamemodify(expected, ":p")
  vim.fn.assert_true(vim.b.vimtex ~= nil)
  vim.fn.assert_equal(
    vim.fn.fnamemodify(expected, ":."),
    vim.fn.fnamemodify((vim.b.vimtex or {}).tex or "", ":.")
  )
  vim.cmd "bwipeout!"
end

return M
