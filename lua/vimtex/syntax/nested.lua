local M = {}
local included = { vimtex_nested_tex = false }

function M.reset()
  included = { vimtex_nested_tex = false }
end

function M.include(name)
  local cluster = "vimtex_nested_" .. name
  if included[cluster] ~= nil then
    return included[cluster] and "@" .. cluster or ""
  end
  local config = vim.g.vimtex_syntax_nested or {}
  name = (config.aliases or {})[name] or name
  local path = "syntax/" .. name .. ".vim"
  if #vim.api.nvim_get_runtime_file(path, true) == 0 then
    included[cluster] = false
    return ""
  end
  local commentstring
  if name == "dockerfile" then
    commentstring = vim.bo.commentstring
  end
  vim.b.current_syntax = nil
  vim.cmd(("syntax include @%s %s"):format(cluster, path))
  vim.b.current_syntax = "tex"
  for _, group in ipairs((config.ignored or {})[name] or {}) do
    vim.cmd(("syntax cluster %s remove=%s"):format(cluster, group))
  end
  if name == "dockerfile" then
    vim.bo.commentstring = commentstring
    vim.cmd "syntax cluster vimtex_nested_dockerfile remove=dockerfileLinePrefix"
  end
  vim.fn["VimtexSyntaxCore_init_options"]()
  included[cluster] = true
  return "@" .. cluster
end

return M
