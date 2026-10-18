MYVIM ?= nvim --clean --headless

.PHONY: test benchmark

test:
	@INMAKE=1 $(MYVIM) -u test.lua

benchmark:
	@$(MYVIM) -l benchmark.lua
