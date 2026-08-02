local M = {}

local function core(name, ...)
  return vim.fn["VimtexSyntaxCore_" .. name](...)
end

local function add_conceals()
  vim.cmd [[
    syntax match texCmdRefEq nextgroup=texRefEqConcealedArg conceal skipwhite skipnl "\\eqref\>"
    syntax match texRefEqConcealedDelim contained "{" conceal cchar=(
    syntax match texRefEqConcealedDelim contained "}" conceal cchar=)
    syntax region texMathConcealedArg contained matchgroup=texMathCmd start="\%#=1\\operatorname\*\?\s*{\s*" end="\s*}" concealends
    syntax cluster texClusterMath add=texMathConcealedArg
  ]]
  core("new_arg", "texRefEqConcealedArg", {
    contains = "texComment,@NoSpell,texRefEqConcealedDelim",
    opts = "keepend contained",
    matchgroup = "",
  })
  local conceal = vim.g.vimtex_syntax_conceal
  if
    type(conceal) ~= "table"
    or conceal.math_delimiters == 0
    or conceal.math_delimiters == false
  then
    return
  end
  if vim.o.encoding == "utf-8" then
    vim.cmd [[
      syntax match texMathDelim contained conceal cchar=| "\\\%([bB]igg\?l\?\|left\)\\lvert\>\s\?"
      syntax match texMathDelim contained conceal cchar=| "\\\%([bB]igg\?r\?\|right\)\\rvert\>"
      syntax match texMathDelim contained conceal cchar=‖ "\\\%([bB]igg\?l\?\|left\)\\lVert\>\s\?"
      syntax match texMathDelim contained conceal cchar=‖ "\\\%([bB]igg\?r\?\|right\)\\rVert\>"
    ]]
  end
  vim.cmd [[
    syntax match texCmdEnvM "\\\%(begin\|end\){Vmatrix}" contained conceal cchar=║
    syntax match texCmdEnvM "\\\%(begin\|end\){vmatrix}" contained conceal cchar=|
    syntax match texCmdEnvM "\\begin{Bmatrix}" contained conceal cchar={
    syntax match texCmdEnvM "\\end{Bmatrix}" contained conceal cchar=}
    syntax match texCmdEnvM "\\begin{bmatrix}" contained conceal cchar=[
    syntax match texCmdEnvM "\\end{bmatrix}" contained conceal cchar=]
    syntax match texCmdEnvM "\\begin{pmatrix}" contained conceal cchar=(
    syntax match texCmdEnvM "\\end{pmatrix}" contained conceal cchar=)
    syntax match texCmdEnvM "\\begin{smallmatrix}" contained conceal cchar=(
    syntax match texCmdEnvM "\\end{smallmatrix}" contained conceal cchar=)
  ]]
end

function M.load(config)
  for _, environment in ipairs {
    "align",
    "alignat",
    "flalign",
    "gather",
    "multline",
    "xalignat",
  } do
    core("new_env", { name = environment, starred = true, math = true })
  end
  core("new_env", { name = "xxalignat", math = true })
  vim.cmd [[
    syntax match texMathCmdEnv contained contains=texCmdMathEnv nextgroup=texMathArrayArg skipwhite skipnl "\%#=1\v\\begin\{%(subarray|x?alignat\*?|xxalignat)\}"
    syntax match texMathCmdEnv contained contains=texCmdMathEnv "\%#=1\v\\end\{%(subarray|x?alignat\*?|xxalignat)\}"
    syntax match texCmdNumberWithin "\%#=1\\numberwithin\>" nextgroup=texNumberWithinArg1 skipwhite skipnl
    syntax match texCmdSubjClass "\%#=1\\subjclass\>" nextgroup=texSubjClassOpt,texSubjClassArg skipwhite skipnl
    syntax match texCmdOpname nextgroup=texOpnameArg skipwhite skipnl "\%#=1\\operatorname\>"
    syntax match texCmdDeclmathoper nextgroup=texDeclmathoperArgName skipwhite skipnl "\%#=1\\DeclareMathOperator\>\*\?"
    syntax match texMathCmd "\%#=1\\tag\>\*\?" contained nextgroup=texMathTagArg
  ]]
  core(
    "new_arg",
    "texNumberWithinArg1",
    { next = "texNumberWithinArg2", contains = "TOP,@Spell" }
  )
  core("new_arg", "texNumberWithinArg2", { contains = "TOP,@Spell" })
  core(
    "new_opt",
    "texSubjClassOpt",
    { next = "texSubjClassArg", contains = "TOP,@Spell" }
  )
  core("new_arg", "texSubjClassArg", { contains = "TOP,@Spell" })
  core("new_arg", "texOpnameArg", { contains = "TOP,@Spell" })
  core(
    "new_arg",
    "texDeclmathoperArgName",
    { next = "texDeclmathoperArgBody", contains = "" }
  )
  core("new_arg", "texDeclmathoperArgBody", { contains = "TOP,@Spell" })
  core("new_arg", "texMathTagArg", { contains = "TOP,@Spell" })
  if config.conceal ~= 0 and config.conceal ~= false then
    add_conceals()
  end
  for group, target in pairs {
    texCmdDeclmathoper = "texCmdNew",
    texCmdNumberWithin = "texCmd",
    texCmdOpName = "texCmd",
    texCmdSubjClass = "texCmd",
    texCmdRefEq = "texCmdRef",
    texRefEqConcealedArg = "texRefArg",
    texRefEqConcealedDelim = "texDelim",
    texDeclmathoperArgName = "texArgNew",
    texDeclmathoperArgBody = "texMathZone",
    texMathConcealedArg = "texMathTextArg",
    texNumberWithinArg1 = "texArg",
    texNumberWithinArg2 = "texArg",
    texOpnameArg = "texMathZone",
    texSubjClassArg = "texArg",
    texSubjClassOpt = "texOpt",
  } do
    vim.cmd("highlight def link " .. group .. " " .. target)
  end
end

return M
