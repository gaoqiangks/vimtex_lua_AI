MYVIM ?= nvim --clean --headless

INMAKE := 1
export INMAKE

.PHONY: test test-backend test-fallback

test: test-backend test-fallback

test-backend:
	@$(MYVIM) -u test.vim

test-fallback:
	@$(MYVIM) -u test-fallback.vim
