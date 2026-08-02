local M = {}

function M.load(config)
  if config.conceal == 0 or config.conceal == false then
    return
  end
  vim.cmd [[syntax match texSpecialChar '\\glq\>'  conceal cchar=‚]]
  vim.cmd [[syntax match texSpecialChar '\\grq\>'  conceal cchar=‘]]
  vim.cmd [[syntax match texSpecialChar '\\glqq\>' conceal cchar=„]]
  vim.cmd [[syntax match texSpecialChar '\\grqq\>' conceal cchar=“]]
  vim.cmd [[syntax match texSpecialChar '\\hyp\>'  conceal cchar=-]]
end

return M
