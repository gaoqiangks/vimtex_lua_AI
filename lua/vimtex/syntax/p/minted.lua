local M = {}
local databases = {}

local function core(name, ...)
  return vim.fn["VimtexSyntaxCore_" .. name](...)
end

local function parse()
  local buffer = vim.api.nvim_get_current_buf()
  if databases[buffer] then
    return databases[buffer]
  end
  local data, current, multiline = {}, nil, false
  local function register(language)
    language = language:gsub("-", "")
    data[language] = data[language] or { environments = {}, commands = {} }
    current = data[language]
  end
  local function add(field, value)
    if current and not vim.tbl_contains(current[field], value) then
      table.insert(current[field], value)
    end
  end
  local state = vim.b.vimtex or {}
  for _, line in
    ipairs(require("vimtex.parser").tex(state.tex, { detailed = 0 }))
  do
    local language
    if multiline then
      language = vim.fn.matchstr(line, [==[\]\s*{\zs\w\+\ze}]==])
      if language ~= "" then
        register(language)
        multiline = false
      end
    elseif vim.fn.match(line, [==[\\begin{minted}\s*\[[^]]*$]==]) >= 0 then
      multiline = true
    else
      language = vim.fn.matchstr(
        line,
        [==[\\begin{minted}\%(\s*\[[^]]*\]\)\?\s*{\zs\w\+\ze}]==]
      )
      if language == "" then
        language = vim.fn.matchstr(
          line,
          [==[\\mint\%(\s*\[[^]]*\]\)\?\s*{\zs\w\+\ze}]==]
        )
      end
      if language ~= "" then
        register(language)
      else
        local matches = vim.fn.matchlist(
          line,
          [==[\\newminted\%(\s*\[\([^]]*\)\]\)\?\s*{\([a-zA-Z-]\+\)}]==]
        )
        if #matches > 0 then
          register(matches[3])
          add(
            "environments",
            matches[2] ~= "" and matches[2] or matches[3] .. "code"
          )
        else
          matches = vim.fn.matchlist(
            line,
            [==[\\newmint\(inline\)\?\%(\s*\[\([^]]*\)\]\)\?\s*{\([a-zA-Z-]\+\)}]==]
          )
          if #matches > 0 then
            register(matches[4])
            add(
              "commands",
              matches[3] ~= "" and matches[3] or matches[4] .. matches[2]
            )
          end
        end
      end
    end
  end
  databases[buffer] = data
  return data
end

local function ex(command)
  vim.cmd(command)
end

function M.load()
  ex [=[syntax match texCmdNewmint '\\newmint\%(ed\|inline\)\?\>' skipwhite skipnl nextgroup=texNewmintOpt,texNewmintArgX]=]
  core("new_opt", "texNewmintOpt", { next = "texNewmintArgY" })
  core(
    "new_arg",
    "texNewmintArgX",
    { contains = "", next = "texNewmintArgOpts" }
  )
  core(
    "new_arg",
    "texNewmintArgY",
    { contains = "", next = "texNewmintArgOpts" }
  )
  core("new_arg", "texNewmintArgOpts", { contains = "" })
  ex [=[syntax match texMintedEnvBgn contained '\\begin{minted}' nextgroup=texMintedEnvOpt,texMintedEnvArg skipwhite skipnl contains=texCmdEnv]=]
  core("new_opt", "texMintedEnvOpt", { next = "texMintedEnvArg" })
  core("new_arg", "texMintedEnvArg", { contains = "" })
  ex [=[syntax match texMintedEnvBgn contained "\\begin{\w\+\*}" nextgroup=texMintedEnvArgOpt skipwhite skipnl contains=texCmdEnv]=]
  core("new_arg", "texMintedEnvArgOpt", { contains = "" })
  core("new_env", {
    name = "minted",
    region = "texMintedZone",
    contains = "texCmdEnv,texMintedEnvBgn",
  })
  core(
    "new_arg",
    "texMintedArg",
    { contains = "", next = "texMintedZoneInline" }
  )
  core("new_arg", "texMintedZoneInline", { contains = "" })
  core(
    "new_arg",
    "texMintedZoneInline",
    { contains = "", matcher = [=[start="\z([|+/]\)" end="\z1"]=] }
  )

  for language, config in pairs(parse()) do
    local cluster = require("vimtex.syntax.nested").include(language)
    local title = language:sub(1, 1):upper() .. language:sub(2)
    local env, inline, argument =
      "texMintedZone" .. title,
      "texMintedZoneInline" .. title,
      "texMintedArg" .. title
    local contains = "texCmdEnv,texMintedEnvBgn"
      .. (cluster ~= "" and "," .. cluster or "")
    if cluster == "" then
      ex("highlight def link " .. env .. " texMintedZone")
      ex("highlight def link " .. inline .. " texMintedZoneInline")
    end
    ex(
      ([==[syntax region %s start="\\begin{minted}\%%(\_s*\[\_[^]]\{-}\]\)\?\_s*{%s}" end="\\end{minted}" keepend contains=%s]==]):format(
        env,
        language,
        contains
      )
    )
    for _, name in ipairs(config.environments) do
      ex(
        ([=[syntax region %s start="\\begin{\z(%s\*\?\)}" end="\\end{\z1}" keepend contains=%s]=]):format(
          env,
          name,
          contains
        )
      )
    end
    ex(
      ([=[syntax match %s "{%s}" contained contains=texMintedArg nextgroup=%s skipwhite skipnl]=]):format(
        argument,
        language,
        inline
      )
    )
    core(
      "new_arg",
      inline,
      { contains = cluster, matcher = [=[start="\z([|+/]\)" end="\z1"]=] }
    )
    core("new_arg", inline, { contains = cluster })
    table.sort(config.commands)
    for _, name in ipairs(config.commands) do
      ex(
        ([=[syntax match texCmdMinted "\\%s\>" nextgroup=%s skipwhite skipnl]=]):format(
          name,
          inline
        )
      )
    end
  end
  ex [=[syntax match texCmdMinted "\\mint\%(inline\)\?" nextgroup=texMintedOpt,texMintedArg.* skipwhite skipnl]=]
  core("new_opt", "texMintedOpt", { next = "texMintedArg.*" })
  for _, pair in ipairs {
    { "texCmdMinted", "texCmd" },
    { "texCmdNewmint", "texCmd" },
    { "texMintedArg", "texSymbol" },
    { "texMintedEnvArg", "texSymbol" },
    { "texMintedEnvArgOpt", "texOpt" },
    { "texMintedEnvOpt", "texOpt" },
    { "texMintedOpt", "texOpt" },
    { "texMintedZone", "texZone" },
    { "texMintedZoneInline", "texZone" },
    { "texNewmintArgOpts", "texOpt" },
    { "texNewmintArgX", "texSymbol" },
    { "texNewmintArgY", "texComment" },
    { "texNewmintOpt", "texSymbol" },
  } do
    ex("highlight def link " .. pair[1] .. " " .. pair[2])
  end
end

return M
