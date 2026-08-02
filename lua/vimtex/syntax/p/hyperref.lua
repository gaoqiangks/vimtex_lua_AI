local M = {}

local function argument(name, options)
  vim.fn["VimtexSyntaxCore_new_arg"](name, options or vim.empty_dict())
end

function M.load(config)
  require("vimtex.syntax.packages").load "nameref"
  vim.cmd [[syntax match texCmdHyperref '\\autoref\>' skipwhite nextgroup=texRefOpt,texRefArg]]
  vim.cmd [[syntax match texCmdHyperref '\\hyperref\>' skipwhite nextgroup=texHyperrefLink,texHyperrefText]]
  vim.fn["VimtexSyntaxCore_new_opt"](
    "texHyperrefLink",
    { next = "texHyperrefText" }
  )
  argument "texHyperrefText"
  vim.cmd [[syntax match texCmdHyperref "\\url\>" skipwhite nextgroup=texUrlArg]]
  argument("texUrlArg", { contains = "@NoSpell" })

  if config.conceal ~= 0 and config.conceal ~= false then
    vim.cmd [[syntax match texCmdHyperref '\\href\>' skipwhite nextgroup=texHrefArgLinkC conceal]]
    argument("texHrefArgLinkC", {
      opts = "contained conceal",
      next = "texHrefArgTextC",
      contains = "texHrefLinkGroup,@NoSpell",
    })
    argument("texHrefLinkGroup", {
      matchgroup = "matchgroup=NONE",
      opts = "contained conceal",
      contains = "texHrefLinkGroup",
    })
    argument("texHrefArgTextC", { opts = "contained concealends" })
    vim.cmd [[syntax match texCmdHyperref '\\texorpdfstring\>' skipwhite nextgroup=texTOPSArgTex conceal]]
    argument(
      "texTOPSArgTex",
      { opts = "contained concealends transparent", next = "texTOPSArgPdf" }
    )
    argument("texTOPSArgPdf", { opts = "contained conceal", contains = "" })
  else
    vim.cmd [[syntax match texCmdHyperref '\\href\>' skipwhite nextgroup=texHrefArgLink]]
    argument(
      "texHrefArgLink",
      { next = "texHrefArgText", contains = "texHrefLinkGroup,@NoSpell" }
    )
    argument(
      "texHrefLinkGroup",
      { matchgroup = "matchgroup=NONE", contains = "texHrefLinkGroup" }
    )
    argument "texHrefArgText"
    vim.cmd [[syntax match texCmdHyperref '\\texorpdfstring\>' skipwhite nextgroup=texTOPSArgTex]]
    argument(
      "texTOPSArgTex",
      { opts = "contained transparent", next = "texTOPSArgPdf" }
    )
    argument("texTOPSArgPdf", { contains = "" })
  end

  for group, target in pairs {
    texCmdHyperref = "texCmd",
    texHyperrefLink = "texOpt",
    texHyperrefText = "texArg",
    texHrefArgLink = "texOpt",
    texHrefArgLinkC = "texHrefArgLink",
    texHrefArgText = "texArg",
    texHrefArgTextC = "texHrefArgText",
    texHrefLinkGroup = "texHrefArgLink",
    texUrlArg = "texOpt",
    texTOPSArgPdf = "texOpt",
  } do
    vim.cmd("highlight def link " .. group .. " " .. target)
  end
end

return M
