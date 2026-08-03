local M = {}
local constructs = {}

local function parse_constructs()
  local buffer = vim.api.nvim_get_current_buf()
  if constructs[buffer] then
    return constructs[buffer]
  end
  local pattern = [[\c\\\%(declare\|new\)tcblisting]]
  local environments = {}
  for _, line in
    ipairs(require("vimtex.parser").tex(vim.b.vimtex.tex, { detailed = false }))
  do
    if vim.fn.match(line, pattern) >= 0 then
      environments[#environments + 1] =
        vim.fn.matchstr(line, pattern .. [[\s*{\zs[a-zA-Z-]\+\ze}]])
    end
  end
  constructs[buffer] = environments
  return environments
end

function M.load(_)
  local environments = parse_constructs()
  vim.cmd [[syntax match texCmdTCBEnv contained '\\begin{\w\+}' nextgroup=texTCBEnvArg skipwhite contains=texCmdEnv]]
  vim.fn["VimtexSyntaxCore_new_arg"]("texTCBEnvArg", { contains = "" })
  for _, environment in ipairs(environments) do
    vim.fn["VimtexSyntaxCore_new_env"] {
      name = environment,
      region = "texTCBZone",
      contains = "texCmdEnv,texCmdTCBEnv",
    }
  end
  vim.cmd "highlight def link texTCBZone texZone"
  vim.cmd "highlight def link texTCBEnvArg texArg"
end

function M.cleanup_buffer(buffer)
  constructs[buffer] = nil
end

return M
