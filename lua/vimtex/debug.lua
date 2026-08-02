local M = {}

function M.stacktrace(open_quickfix)
  local entries = {}
  for depth = 3, 64 do
    local info = debug.getinfo(depth, "Sln")
    if not info then
      break
    end
    entries[#entries + 1] = {
      filename = (info.source or ""):gsub("^@", ""),
      ["function"] = info.name or "<anonymous>",
      lnum = info.currentline or 0,
      text = depth == 3 and "Manual stacktrace" or "",
      nr = depth - 3,
    }
  end
  if open_quickfix == true or open_quickfix == 1 then
    vim.fn.setqflist(entries)
    vim.cmd("copen " .. (#entries + 2))
    vim.cmd "wincmd p"
  end
  return entries
end

return M
