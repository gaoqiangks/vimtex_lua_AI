MYVIM ?= nvim --clean --headless

INMAKE := 1
export INMAKE

.PHONY: test test-backend test-fallback test-lualine

test: test-backend test-fallback test-lualine

test-backend:
	@$(MYVIM) -u test.vim

test-fallback:
	@$(MYVIM) -u test-fallback.vim

test-lualine:
	@$(MYVIM) -u test-lualine.vim
