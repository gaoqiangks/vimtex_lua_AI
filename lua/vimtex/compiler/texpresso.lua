local M = {}

function M.process_message(text)
  for _, line in ipairs(vim.split(text or "", "\n")) do
    local ok, message = pcall(vim.json.decode, line)
    if ok and type(message) == "table" then
      if message[1] == "synctex" then
        require("vimtex.view").inverse_search(message[3], message[2])
      elseif message[1] == "truncate-lines" and message[2] == "out" then
        local list = vim.fn.getqflist()
        vim.fn.setqflist(vim.list_slice(list, 1, message[3]), "r")
      elseif message[1] == "append-lines" and message[2] == "out" then
        vim.fn.setqflist(
          {},
          "a",
          { lines = vim.list_slice(message, 3), efm = "%t%*[^:]: %f:%l: %m" }
        )
      end
    end
  end
end

function M.send(...)
  local buffered = vim.b.vimtex and vim.b.vimtex.compiler
  local state = require("vimtex.state").get(vim.b.vimtex_id)
  local compiler = buffered and buffered.job and buffered
    or state and state.compiler
  local running = compiler
    and compiler.job
    and pcall(vim.fn.jobpid, compiler.job)
    and vim.fn.jobpid(compiler.job) > 0
  if running then
    pcall(vim.fn.chansend, compiler.job, vim.json.encode { ... } .. "\n")
  end
end

function M.attach()
  local buffer = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_attach(buffer, false, {
    on_lines = function(_, _, _, first, old_last, new_last)
      local lines = vim.api.nvim_buf_get_lines(buffer, first, new_last, false)
      M.send(
        "change-lines",
        vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buffer), ":p"),
        first,
        old_last - first,
        #lines > 0 and table.concat(lines, "\n") .. "\n" or ""
      )
    end,
  })
  return function()
    pcall(vim.api.nvim_buf_detach, buffer)
  end
end

return M
