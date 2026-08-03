local M = {}

local custom_maps = {}

local function wrapper_name(name)
  return (name or "vimtex#imaps#wrap_math"):match "([^#]+)$"
end

function M.wrap_trivial(_, rhs)
  return rhs
end

function M.wrap_math(lhs, rhs)
  return require("vimtex.syntax").in_mathzone() and rhs or lhs
end

function M.wrap_environment(lhs, rhs)
  local result, value = lhs, 0
  local contexts = (vim.b.vimtex_context or {})[lhs .. rhs] or {}
  for _, context in ipairs(contexts) do
    local environments, candidate_rhs
    if type(context) == "string" then
      environments, candidate_rhs = { context }, rhs
    else
      environments, candidate_rhs = context.envs, context.rhs
    end
    for _, environment in ipairs(environments) do
      local position = require("vimtex.env").is_inside(environment)
      local candidate = require("vimtex.pos").val(position)
      if candidate > value then
        value, result = candidate, candidate_rhs
      end
    end
  end
  return result
end

function M.style_math(command)
  if not require("vimtex.syntax").in_mathzone() then
    return ""
  end
  return "\\" .. command .. "{" .. vim.fn.nr2char(vim.fn.getchar()) .. "}"
end

local function evaluate_rhs(map)
  if not map.expr then
    return map.rhs
  end
  if type(map.rhs) == "function" then
    return map.rhs()
  end
  local style = map.rhs:match [[^vimtex#imaps#style_math%("([^"]+)"%)$]]
  if style then
    return M.style_math(style)
  end
  return vim.fn.eval(map.rhs)
end

local function create_map(map, maps, contexts)
  for _, existing in ipairs(maps) do
    if vim.deep_equal(existing, map) then
      return
    end
  end
  local copy = vim.tbl_extend("force", {}, map)
  local leader = copy.leader or vim.g.vimtex_imaps_leader
  local lhs = leader .. copy.lhs
  if copy.context then
    contexts[lhs .. copy.rhs] = copy.context
  end
  local name = wrapper_name(copy.wrapper)
  vim.keymap.set("i", lhs, function()
    local rhs = evaluate_rhs(copy)
    local wrapper = M[name]
    if wrapper then
      return wrapper(lhs, rhs)
    end
    return vim.fn[copy.wrapper](lhs, rhs)
  end, { buffer = true, expr = true, silent = true, nowait = true })
  table.insert(maps, copy)
end

function M.add_map(map)
  table.insert(custom_maps, map)
  if vim.b.vimtex_imaps then
    local maps = vim.b.vimtex_imaps
    local contexts = vim.b.vimtex_context or {}
    create_map(map, maps, contexts)
    vim.b.vimtex_imaps = maps
    vim.b.vimtex_context = contexts
  end
end

function M.list()
  vim.cmd "silent new VimTeX\\ imaps"
  local lines = {}
  for _, map in ipairs(vim.b.vimtex_imaps or {}) do
    lines[#lines + 1] = string.format(
      "%5s  ->  %-30s %s",
      map.leader or vim.g.vimtex_imaps_leader,
      map.rhs,
      map.wrapper or "vimtex.imaps.wrap_math"
    )
  end
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.keymap.set(
    "n",
    "q",
    "<cmd>bwipeout<cr>",
    { buffer = true, silent = true, nowait = true }
  )
  vim.keymap.set(
    "n",
    "<esc>",
    "<cmd>bwipeout<cr>",
    { buffer = true, silent = true, nowait = true }
  )
  vim.bo.bufhidden, vim.bo.buftype, vim.bo.buflisted = "wipe", "nofile", false
  vim.bo.swapfile, vim.bo.modifiable = false, false
  vim.wo.conceallevel, vim.wo.cursorline, vim.wo.wrap = 0, true, false
  vim.wo.list, vim.wo.number, vim.wo.relativenumber = false, false, false
  vim.cmd [[syntax match VimtexImapsLhs /^.*\ze->/ nextgroup=VimtexImapsArrow]]
  vim.cmd [[syntax match VimtexImapsArrow /->/ contained nextgroup=VimtexImapsRhs]]
  vim.cmd [[syntax match VimtexImapsRhs /\s*\S*/ contained nextgroup=VimtexImapsWrapper]]
  vim.cmd [[syntax match VimtexImapsWrapper /.*/ contained]]
end

function M.init_buffer()
  if vim.g.vimtex_imaps_enabled == 0 then
    return
  end
  local maps = vim.b.vimtex_imaps or {}
  local contexts = vim.b.vimtex_context or {}
  local disabled = {}
  for _, lhs in ipairs(vim.g.vimtex_imaps_disabled or {}) do
    disabled[lhs] = true
  end
  for _, map in ipairs(vim.g.vimtex_imaps_list or {}) do
    if not disabled[map.lhs] then
      create_map(map, maps, contexts)
    end
  end
  for _, map in ipairs(custom_maps) do
    if not disabled[map.lhs] then
      create_map(map, maps, contexts)
    end
  end
  vim.b.vimtex_imaps = maps
  vim.b.vimtex_context = contexts
  vim.api.nvim_buf_create_user_command(0, "VimtexImapsList", M.list, {})
  vim.keymap.set("n", "<plug>(vimtex-imaps-list)", M.list, { buffer = true })
end

return M
