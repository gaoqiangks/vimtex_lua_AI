local M = {}

local initialized = false

local defaults = {
  vimtex_bibliography_commands = {
    "%(no)?bibliography",
    "add%(bibresource|globalbib|sectionbib)",
  },
  vimtex_compiler_clean_paths = {},
  vimtex_compiler_enabled = 1,
  vimtex_compiler_latexmk_engines = {
    _ = "-pdf",
    ["context (luatex)"] = "-pdf -pdflatex=context",
    ["context (pdftex)"] = "-pdf -pdflatex=texexec",
    ["context (xetex)"] = "-pdf -pdflatex='texexec --xtx'",
    lualatex = "-lualatex",
    luatex = "-lualatex",
    pdfdvi = "-pdfdvi",
    pdflatex = "-pdf",
    pdfps = "-pdfps",
    xelatex = "-xelatex",
  },
  vimtex_compiler_latexrun_engines = {
    _ = "pdflatex",
    lualatex = "lualatex",
    pdflatex = "pdflatex",
    xelatex = "xelatex",
  },
  vimtex_compiler_method = "latexmk",
  vimtex_compiler_silent = 0,
  vimtex_complete_bib = {
    abbr_fmt = "",
    auth_len = 20,
    custom_patterns = {},
    info_fmt = "TITLE: @title\nAUTHOR: @author_all\nYEAR: @year",
    match_str_fmt = '@key [@type] @author_all (@year), "@title"',
    menu_fmt = '[@type] @author_short (@year), "@title"',
    simple = 0,
  },
  vimtex_complete_close_braces = 0,
  vimtex_complete_enabled = 1,
  vimtex_complete_ignore_case = 0,
  vimtex_complete_ref = {
    custom_patterns = {},
  },
  vimtex_complete_smart_case = 0,
  vimtex_context_pdf_viewer = "xdg-open",
  vimtex_delim_insert_timeout = 60,
  vimtex_delim_stopline = 500,
  vimtex_delim_timeout = 300,
  vimtex_doc_confirm_single = true,
  vimtex_doc_enabled = 1,
  vimtex_doc_handlers = {},
  vimtex_echo_verbose_input = 1,
  vimtex_env_change_autofill = 0,
  vimtex_env_toggle_map = {
    enumerate = "itemize",
    itemize = "enumerate",
  },
  vimtex_env_toggle_math_map = {
    ["$"] = "\\[",
    ["$$"] = "\\[",
    ["\\("] = "$",
    ["\\["] = "equation",
  },
  vimtex_fold_bib_enabled = 0,
  vimtex_fold_bib_max_key_width = 0,
  vimtex_fold_enabled = 0,
  vimtex_fold_levelmarker = "*",
  vimtex_fold_manual = 0,
  vimtex_fold_types = vim.empty_dict(),
  vimtex_fold_types_defaults = {
    cmd_addplot = {
      cmds = { "addplot[+3]?" },
    },
    cmd_multi = {
      cmds = {
        "%(re)?new%(command|environment)",
        "providecommand",
        "presetkeys",
        "Declare%(Multi|Auto)?CiteCommand",
        "Declare%(Index)?%(Field|List|Name)%(Format|Alias)",
      },
    },
    cmd_single = {
      cmds = { "hypersetup", "tikzset", "pgfplotstableread", "lstset" },
    },
    cmd_single_opt = {
      cmds = { "usepackage", "includepdf" },
    },
    comment_pkg = vim.empty_dict(),
    comments = {
      enabled = 0,
    },
    env_options = vim.empty_dict(),
    envs = {
      blacklist = {},
      whitelist = {},
    },
    items = vim.empty_dict(),
    markers = vim.empty_dict(),
    preamble = vim.empty_dict(),
    sections = {
      parse_levels = 0,
      parts = { "appendix", "frontmatter", "mainmatter", "backmatter" },
      sections = {
        "%(add)?part",
        "%(chapter|addchap)",
        "%(section|addsec)",
        "subsection",
        "subsubsection",
      },
    },
  },
  vimtex_format_border_begin = "\\v^\\s*%(\\\\item|\\\\begin|\\\\end|%(\\\\\\[|\\$\\$)\\s*$)",
  vimtex_format_border_end = "\\v\\\\%(\\\\\\*?|clear%(double)?page|linebreak|new%(line|page)|pagebreak|%(begin|end)\\{[^}]*\\})\\s*$|^\\s*%(\\\\\\]|\\$\\$)\\s*$",
  vimtex_format_enabled = 0,
  vimtex_grammar_textidote = {
    args = "",
    jar = "",
  },
  vimtex_grammar_vlty = {
    encoding = "auto",
    lt_command = "",
    lt_directory = "~/lib/LanguageTool",
    lt_disable = "WHITESPACE_RULE",
    lt_disablecategories = "",
    lt_enable = "",
    lt_enablecategories = "",
    server = "no",
    shell_options = "",
    show_suggestions = 0,
  },
  vimtex_imaps_disabled = {},
  vimtex_imaps_enabled = 1,
  vimtex_imaps_leader = "`",
  vimtex_imaps_list = {
    {
      lhs = "0",
      rhs = "\\emptyset",
    },
    {
      lhs = "2",
      rhs = "\\sqrt",
    },
    {
      lhs = "6",
      rhs = "\\partial",
    },
    {
      lhs = "8",
      rhs = "\\infty",
    },
    {
      lhs = "=",
      rhs = "\\equiv",
    },
    {
      lhs = "\\",
      rhs = "\\setminus",
    },
    {
      lhs = ".",
      rhs = "\\cdot",
    },
    {
      lhs = "*",
      rhs = "\\times",
    },
    {
      lhs = "<",
      rhs = "\\langle",
    },
    {
      lhs = ">",
      rhs = "\\rangle",
    },
    {
      lhs = "H",
      rhs = "\\hbar",
    },
    {
      lhs = "+",
      rhs = "\\dagger",
    },
    {
      lhs = "[",
      rhs = "\\subseteq",
    },
    {
      lhs = "]",
      rhs = "\\supseteq",
    },
    {
      lhs = "(",
      rhs = "\\subset",
    },
    {
      lhs = ")",
      rhs = "\\supset",
    },
    {
      lhs = "A",
      rhs = "\\forall",
    },
    {
      lhs = "B",
      rhs = "\\boldsymbol",
    },
    {
      lhs = "E",
      rhs = "\\exists",
    },
    {
      lhs = "N",
      rhs = "\\nabla",
    },
    {
      lhs = "jj",
      rhs = "\\downarrow",
    },
    {
      lhs = "jJ",
      rhs = "\\Downarrow",
    },
    {
      lhs = "jk",
      rhs = "\\uparrow",
    },
    {
      lhs = "jK",
      rhs = "\\Uparrow",
    },
    {
      lhs = "jh",
      rhs = "\\leftarrow",
    },
    {
      lhs = "jH",
      rhs = "\\Leftarrow",
    },
    {
      lhs = "jl",
      rhs = "\\rightarrow",
    },
    {
      lhs = "jL",
      rhs = "\\Rightarrow",
    },
    {
      lhs = "a",
      rhs = "\\alpha",
    },
    {
      lhs = "b",
      rhs = "\\beta",
    },
    {
      lhs = "c",
      rhs = "\\chi",
    },
    {
      lhs = "d",
      rhs = "\\delta",
    },
    {
      lhs = "e",
      rhs = "\\epsilon",
    },
    {
      lhs = "f",
      rhs = "\\phi",
    },
    {
      lhs = "g",
      rhs = "\\gamma",
    },
    {
      lhs = "h",
      rhs = "\\eta",
    },
    {
      lhs = "i",
      rhs = "\\iota",
    },
    {
      lhs = "k",
      rhs = "\\kappa",
    },
    {
      lhs = "l",
      rhs = "\\lambda",
    },
    {
      lhs = "m",
      rhs = "\\mu",
    },
    {
      lhs = "n",
      rhs = "\\nu",
    },
    {
      lhs = "p",
      rhs = "\\pi",
    },
    {
      lhs = "q",
      rhs = "\\theta",
    },
    {
      lhs = "r",
      rhs = "\\rho",
    },
    {
      lhs = "s",
      rhs = "\\sigma",
    },
    {
      lhs = "t",
      rhs = "\\tau",
    },
    {
      lhs = "y",
      rhs = "\\psi",
    },
    {
      lhs = "u",
      rhs = "\\upsilon",
    },
    {
      lhs = "w",
      rhs = "\\omega",
    },
    {
      lhs = "z",
      rhs = "\\zeta",
    },
    {
      lhs = "x",
      rhs = "\\xi",
    },
    {
      lhs = "D",
      rhs = "\\Delta",
    },
    {
      lhs = "F",
      rhs = "\\Phi",
    },
    {
      lhs = "G",
      rhs = "\\Gamma",
    },
    {
      lhs = "L",
      rhs = "\\Lambda",
    },
    {
      lhs = "P",
      rhs = "\\Pi",
    },
    {
      lhs = "Q",
      rhs = "\\Theta",
    },
    {
      lhs = "S",
      rhs = "\\Sigma",
    },
    {
      lhs = "U",
      rhs = "\\Upsilon",
    },
    {
      lhs = "W",
      rhs = "\\Omega",
    },
    {
      lhs = "X",
      rhs = "\\Xi",
    },
    {
      lhs = "Y",
      rhs = "\\Psi",
    },
    {
      lhs = "ve",
      rhs = "\\varepsilon",
    },
    {
      lhs = "vf",
      rhs = "\\varphi",
    },
    {
      lhs = "vk",
      rhs = "\\varkappa",
    },
    {
      lhs = "vp",
      rhs = "\\varpi",
    },
    {
      lhs = "vq",
      rhs = "\\vartheta",
    },
    {
      lhs = "vr",
      rhs = "\\varrho",
    },
    {
      expr = 1,
      leader = "#",
      lhs = "/",
      rhs = 'vimtex#imaps#style_math("slashed")',
    },
    {
      expr = 1,
      leader = "#",
      lhs = "b",
      rhs = 'vimtex#imaps#style_math("mathbf")',
    },
    {
      expr = 1,
      leader = "#",
      lhs = "f",
      rhs = 'vimtex#imaps#style_math("mathfrak")',
    },
    {
      expr = 1,
      leader = "#",
      lhs = "c",
      rhs = 'vimtex#imaps#style_math("mathcal")',
    },
    {
      expr = 1,
      leader = "#",
      lhs = "-",
      rhs = 'vimtex#imaps#style_math("overline")',
    },
    {
      expr = 1,
      leader = "#",
      lhs = "B",
      rhs = 'vimtex#imaps#style_math("mathbb")',
    },
    {
      lhs = "`",
      rhs = "``",
      wrapper = "vimtex#imaps#wrap_trivial",
    },
  },
  vimtex_include_search_enabled = 1,
  vimtex_indent_bib_enabled = 1,
  vimtex_indent_conditionals = {
    close = "\\\\fi\\>",
    ["else"] = "\\\\else\\>",
    open = "\\v%(\\\\newif)@<!\\\\if%(f>|field|name|numequal|thenelse|toggle)@!",
  },
  vimtex_indent_delims = {
    close = { "}" },
    close_indented = 0,
    include_modified_math = 1,
    open = { "{" },
  },
  vimtex_indent_enabled = 1,
  vimtex_indent_ignored_envs = { "document" },
  vimtex_indent_lists = {
    "itemize",
    "description",
    "enumerate",
    "thebibliography",
  },
  vimtex_indent_on_ampersands = 1,
  vimtex_indent_tikz_commands = 1,
  vimtex_labels_enabled = 1,
  vimtex_labels_refresh_always = 1,
  vimtex_lint_chktex_ignore_warnings = "-n1 -n3 -n8 -n25 -n36",
  vimtex_lint_chktex_parameters = "",
  vimtex_main_choose_first = 0,
  vimtex_mappings_disable = vim.empty_dict(),
  vimtex_mappings_enabled = 1,
  vimtex_mappings_override_existing = 0,
  vimtex_mappings_prefix = "<localleader>l",
  vimtex_matchparen_enabled = 1,
  vimtex_motion_enabled = 1,
  vimtex_parser_bib_backend = "lua",
  vimtex_quickfix_autoclose_after_keystrokes = 0,
  vimtex_quickfix_autojump = 0,
  vimtex_quickfix_blgparser = vim.empty_dict(),
  vimtex_quickfix_enabled = 1,
  vimtex_quickfix_ignore_filters = {},
  vimtex_quickfix_method = "latexlog",
  vimtex_quickfix_mode = 2,
  vimtex_quickfix_open_on_warning = 1,
  vimtex_subfile_start_local = 0,
  vimtex_syntax_conceal = {
    accents = 1,
    cites = 1,
    fancy = 1,
    greek = 1,
    ligatures = 1,
    math_bounds = 1,
    math_delimiters = 1,
    math_fracs = 1,
    math_super_sub = 1,
    math_symbols = 1,
    sections = 0,
    spacing = 1,
    styles = 1,
    texTabularChar = 1,
  },
  vimtex_syntax_conceal_cites = {
    icon = "📖",
    type = "brackets",
    verbose = true,
  },
  vimtex_syntax_conceal_disable = 0,
  vimtex_syntax_custom_cmds = {},
  vimtex_syntax_custom_cmds_with_concealed_delims = {},
  vimtex_syntax_custom_envs = {},
  vimtex_syntax_enabled = 1,
  vimtex_syntax_match_unicode = true,
  vimtex_syntax_nested = {
    aliases = {
      C = "c",
      csharp = "cs",
    },
    ignored = {
      bash = { "shSpecial" },
      cs = { "csBraces" },
      haskell = { "hsVarSym" },
      java = { "javaError" },
      lua = { "luaParen", "luaParenError" },
      markdown = { "mkdNonListItemBlock" },
      python = { "pythonEscape", "pythonBEscape", "pythonBytesEscape" },
      sh = { "shSpecial" },
    },
  },
  vimtex_syntax_nospell_comments = 0,
  vimtex_syntax_packages = {
    amsmath = {
      conceal = 1,
      load = 2,
    },
    babel = {
      conceal = 1,
    },
    fontawesome5 = {
      conceal = 1,
    },
    hyperref = {
      conceal = 1,
    },
    robust_externalize = {
      presets = {
        { "bash", "bash" },
        { "python", "python" },
        { "gnuplot", "gnuplot" },
        { "tikz", "@texClusterTikz" },
        { "latex", "TOP" },
      },
    },
  },
  vimtex_texcount_custom_arg = "",
  vimtex_text_obj_enabled = 1,
  vimtex_text_obj_linewise_operators = { "d", "y" },
  vimtex_text_obj_variant = "auto",
  vimtex_toc_config = {
    fold_enable = 0,
    fold_level_start = -1,
    hide_line_numbers = 1,
    hotkeys = "abcdeilmnopuvxyz",
    hotkeys_enabled = 0,
    hotkeys_leader = ";",
    indent_levels = 0,
    layer_keys = {
      content = "C",
      include = "I",
      label = "L",
      todo = "T",
    },
    layer_status = {
      content = 1,
      include = 1,
      label = 1,
      todo = 1,
    },
    mode = 1,
    name = "Table of contents (VimTeX)",
    refresh_always = 1,
    resize = 0,
    show_help = 1,
    show_numbers = 1,
    split_pos = "vert leftabove",
    split_width = 50,
    tocdepth = 3,
    todo_sorted = 1,
  },
  vimtex_toc_config_matchers = vim.empty_dict(),
  vimtex_toc_custom_matchers = {},
  vimtex_toc_enabled = 1,
  vimtex_toc_show_preamble = 1,
  vimtex_toc_todo_labels = {
    FIXME = "FIXME: ",
    TODO = "TODO: ",
  },
  vimtex_toggle_fractions = {
    INLINE = "frac",
    dfrac = "INLINE",
    frac = "INLINE",
  },
  vimtex_toggle_star_cmds = {
    "part",
    "%(sub)*section",
    "%(sub)*paragraph",
    "[vh]space",
    "\\w*cite\\w*",
    "\\w*ref",
    "%(re)?newcommand",
    "providecommand",
    "DeclareRobustCommand",
    "DeclareMathOperator",
    "%(re)?newenvironment",
    "includegraphics",
    "verb",
  },
  vimtex_ui_method = {
    confirm = "nvim",
    input = "nvim",
    select = "nvim",
  },
  vimtex_view_automatic = 1,
  vimtex_view_enabled = 1,
  vimtex_view_forward_search_on_start = 1,
  vimtex_view_galley_activate = 0,
  vimtex_view_galley_sync = 0,
  vimtex_view_general_options = "@pdf",
  vimtex_view_general_viewer = "xdg-open",
  vimtex_view_method = "general",
  vimtex_view_mupdf_options = "",
  vimtex_view_mupdf_send_keys = "",
  vimtex_view_reverse_search_edit_cmd = "edit",
  vimtex_view_sioyek_exe = "sioyek",
  vimtex_view_sioyek_options = "",
  vimtex_view_skim_activate = 0,
  vimtex_view_skim_no_select = 0,
  vimtex_view_skim_reading_bar = 0,
  vimtex_view_skim_sync = 0,
  vimtex_view_texshop_activate = 0,
  vimtex_view_texshop_sync = 0,
  vimtex_view_use_temp_files = false,
  vimtex_view_zathura_check_libsynctex = 1,
  vimtex_view_zathura_options = "",
  vimtex_view_zathura_use_synctex = 1,
}

local highlights = {
  VimtexImapsArrow = "Comment",
  VimtexImapsLhs = "ModeMsg",
  VimtexImapsRhs = "ModeMsg",
  VimtexImapsWrapper = "Type",
  VimtexInfo = "Question",
  VimtexInfoTitle = "PreProc",
  VimtexInfoKey = "PreProc",
  VimtexInfoValue = "Statement",
  VimtexMsg = "ModeMsg",
  VimtexSuccess = "Statement",
  VimtexTodo = "Todo",
  VimtexWarning = "WarningMsg",
  VimtexError = "Error",
  VimtexFatal = "ErrorMsg",
  VimtexBlink = "PMenu",
  VimtexTocHelp = "helpVim",
  VimtexTocHelpKey = "ModeMsg",
  VimtexTocHelpLayerOn = "Statement",
  VimtexTocHelpLayerOff = "Comment",
  VimtexTocTodo = "VimtexTodo",
  VimtexTocWarning = "VimtexWarning",
  VimtexTocError = "VimtexError",
  VimtexTocFatal = "VimtexFatal",
  VimtexTocNum = "Number",
  VimtexTocSec0 = "Title",
  VimtexTocSec2 = "helpVim",
  VimtexTocSec3 = "NonText",
  VimtexTocSec4 = "Comment",
  VimtexTocHotkey = "Comment",
  VimtexTocLabelsSecs = "Statement",
  VimtexTocLabelsEq = "PreProc",
  VimtexTocLabelsFig = "Identifier",
  VimtexTocLabelsTab = "String",
  VimtexTocIncl = "Number",
}

local function init_highlights()
  for name, target in pairs(highlights) do
    vim.api.nvim_set_hl(0, name, { default = true, link = target })
  end
end

local function platform_viewer()
  local os = vim.uv.os_uname().sysname
  if os == "Darwin" then
    return "open", "@pdf"
  elseif os:match "Windows" then
    if vim.fn.executable "SumatraPDF" == 1 then
      return "SumatraPDF", "-reuse-instance -forward-search @tex @line @pdf"
    elseif vim.fn.executable "mupdf" == 1 then
      return "mupdf", "@pdf"
    end
    return 'start ""', "@pdf"
  end
  return "xdg-open", "@pdf"
end

function M.init()
  if initialized then
    return
  end

  require("vimtex.re").init()

  init_highlights()

  local context_was_set = vim.g.vimtex_context_pdf_viewer ~= nil
  local imaps_were_set = vim.g.vimtex_imaps_list ~= nil

  defaults.vimtex_complete_ignore_case = vim.o.ignorecase and 1 or 0
  defaults.vimtex_complete_smart_case = vim.o.smartcase and 1 or 0

  local viewer, viewer_options = platform_viewer()
  defaults.vimtex_view_general_viewer = viewer
  defaults.vimtex_view_general_options = viewer_options

  local config_home = vim.env.XDG_CONFIG_HOME
  if not config_home or config_home == "" then
    config_home = vim.fn.expand "~/.config"
  end
  local chktexrc = config_home .. "/chktexrc"
  defaults.vimtex_lint_chktex_parameters = vim.fn.filereadable(chktexrc) == 1
      and "--localrc " .. vim.fn.shellescape(chktexrc)
    or ""

  if vim.wo.diff then
    vim.g.vimtex_fold_enabled = 0
    vim.g.vimtex_fold_bib_enabled = 0
  end

  for name, default in pairs(defaults) do
    local current = vim.g[name]
    if current == nil then
      vim.g[name] = type(default) == "table" and vim.deepcopy(default)
        or default
    elseif type(default) == "table" and type(current) == "table" then
      vim.g[name] = vim.tbl_deep_extend("keep", current, default)
    end
  end

  if not context_was_set then
    local configured = vim.g.vimtex_view_method
    vim.g.vimtex_context_pdf_viewer = configured == "general"
        and vim.g.vimtex_view_general_viewer
      or configured
  end

  if not imaps_were_set then
    local imaps = vim.g.vimtex_imaps_list
    local escape = imaps[#imaps]
    escape.lhs = vim.g.vimtex_imaps_leader
    escape.rhs = vim.g.vimtex_imaps_leader:rep(2)
    vim.g.vimtex_imaps_list = imaps
  end

  if vim.g.vimtex_syntax_conceal_disable == 1 then
    local conceal = vim.g.vimtex_syntax_conceal
    for key in pairs(conceal) do
      conceal[key] = 0
    end
    vim.g.vimtex_syntax_conceal = conceal

    local packages = vim.g.vimtex_syntax_packages
    for _, package in ipairs { "amsmath", "babel", "hyperref", "fontawesome5" } do
      packages[package].conceal = 0
    end
    vim.g.vimtex_syntax_packages = packages
  end

  initialized = true
end

return M
