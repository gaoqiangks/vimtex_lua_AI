if vim.g.vimtex_enabled == 0 or vim.b.did_ftplugin_vimtex == 1 then
  return
end
vim.b.did_ftplugin_vimtex = 1

local scripts = vim.api.nvim_exec2("scriptnames", { output = true }).output
if scripts:lower():find "latex%-box" then
  vim.notify(
    "Conflicting plugin detected: LaTeX-Box; disable or remove it before using VimTeX",
    vim.log.levels.WARN
  )
end
