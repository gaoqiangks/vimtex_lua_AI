.PHONY: test test-matching-comments

MYVIM ?= nvim --clean --headless

INMAKE := 1
export INMAKE

test: test-matching-comments
	@$(MYVIM) -u test.vim

test-matching-comments:
	@$(MYVIM) -u test-matching-comments.vim
