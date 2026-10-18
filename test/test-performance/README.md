# Performance audit, 2026-10-19

This audit compares the Lua implementation at `9eb8f73` with the working-tree
optimizations. It does not compare this project with upstream VimTeX.

## Reproduce

```sh
make -C test/test-performance
make -C test/test-performance benchmark
```

The regression tests generate their inputs in a temporary directory. They cover
included preamble changes, command/bibliography/TOC cache invalidation after
child-file changes, deletion and restoration, independent completion results,
CRLF/NUL text-file decoding, symlink cycles, hidden files, `wildignore`, relative
path boundaries, syntax query case/regex behavior, and duplicate compile events.
They also verify that same-directory push/pop operations do not fire
`DirChanged`, including nested directory scopes.

The benchmark also creates and removes its own temporary project. To compare
another checkout, run the same benchmark script with its runtime root:

```sh
VIMTEX_BENCH_ROOT=/absolute/path/to/checkout \
VIMTEX_BENCH_OUT=/tmp/vimtex-benchmark.json \
  nvim --clean --headless -l test/test-performance/benchmark.lua
```

The benchmark assumes `latexmk` and the standard TeX packages are available.
It enables filetype plugins, indentation and syntax, disables persistent VimTeX
caches and automatic root-directive insertion, and does not run a TeX compiler.
Inputs comprise one main TeX file, 12 included files with 1,001 lines each,
1,000 bibliography entries, and 100 image directories. The generated files live
on the Linux `/tmp` filesystem, not on a Windows-mounted directory.

## Results

Neovim 0.12.5 / LuaJIT on WSL Linux. Each repeated operation reports the median
of five timed batches after a warmup. The table reports medians across five
independent Neovim processes per revision, alternating revisions between runs.
All numbers are milliseconds per operation. The file-open measurement is the
first `:edit` in each process, not total Neovim process startup time.

| Operation | Before | After | Before / after |
| --- | ---: | ---: | ---: |
| First TeX file open | 87.071 | 65.234 | 1.33x |
| Cached project parse, about 12,000 lines | 1.448 | 0.382 | 3.79x |
| Cached preamble parse | 0.026 | 0.020 | 1.32x |
| Command candidate rebuild | 3.172 | 2.309 | 1.37x |
| Cached bibliography completion | 0.811 | 0.607 | 1.34x |
| Graphics completion, 100 images | 12.745 | 1.723 | 7.40x |
| Matchparen while moving through ordinary prose | 3.189 | 0.101 | 31.68x |
| Matchparen at an unchanged cursor position | 3.109 | 0.095 | 32.75x |
| Math-zone syntax query | 0.022 | 0.022 | 1.03x |
| Cached source lookup | 0.004 | 0.004 | 0.98x |
| Cached command completion | 0.077 | 0.169 | 0.46x |

Cached command completion now validates the included files' metadata on each
call. This adds about 0.09 ms for this project, while fixing stale completion
after an external child-file edit. Source lookup and this syntax-query workload
are effectively unchanged. These are local microbenchmarks; process scheduling,
filesystem, package installation, project layout and user configuration affect
the absolute timings. In particular, first-open timings varied substantially
between processes, so the large matchparen/scan/parser improvements are stronger
evidence than the startup difference.

The underlying changes select Vim's backtracking engine for the generated
delimiter expressions; avoid intermediate project-line lists and repeated
per-line normalization; scan filenames by extension in a single libuv traversal;
deduplicate graphics roots; and copy bibliography candidates after filtering.
Directory changes normalize trailing separators before comparing paths, avoiding
redundant `:cd` and other plugins' `DirChanged` callbacks during completion.
Syntax queries cache highlight group names and use literal prefix checks where
appropriate. File caches compare size and nanosecond mtimes, including the
complete inclusion tree. No filesystem-result TTL or polling timer was added.

## Full-suite audit

`make -k -C test` was run in clean temporary copies both before and after the
optimizations. The baseline ran 57 test groups and failed six groups. The
optimized tree adds this regression group, for 58 groups total. All changed
runtime paths and the new regression tests passed; no new failing group was
introduced. Syntax compilation of all 152 runtime/test Lua files in Neovim's
LuaJIT, StyLua checking, and `git diff --check` passed.

Two pre-existing failures were corrected and their affected tests rerun:

- Cache cleanup tried to remove a `capture.json` file that the current tests no
  longer create. Optional cache artifacts now use `rm -f`.
- The executable-list success test used `test-builddir.tex`, which deliberately
  contains `\failed` for a different test. It now has its own valid TeX fixture.

The compiler also avoids parsing logs and reporting a second completion event
at process exit when an explicit terminal callback has already run. A separate
regression test exercises this behavior with a real asynchronous helper job.
The compiler backend tests now stop only jobs belonging to their own Neovim
instance, instead of using a global `pkill -f latexmk` command.

After these fixes, 54 of the 58 groups pass. Four baseline groups remain
unsuccessful in the current repository/environment:

- `test-getfile`: the checked-out fixtures lack `out/test.log` and
  `auxfiles/test.log`.
- `test-quickfix`: the example `main.log` fixture is absent; the locally generated
  spaces-in-filenames log also differs from its version-dependent expected list.
- `test-quickfix-fix-path`: the Beamer and hbox log fixtures are absent.
- `test-textobj-targets`: the existing targets.vim integration output differs
  from `test.ok` before and after this optimization.

These failures are not counted as passes or silently skipped. They require
fixture restoration/update or a separate targets.vim compatibility repair.
