#!/usr/bin/env bash

# "nvim persistence strategy"
# Works with custom config in persistence.nvim for tmux-aware session management
# Usage: set -g @resurrect-strategy-nvim 'persistence'

ORIGINAL_COMMAND="$1"
DIRECTORY="$2"

main() {
	# Always replace with nvim + persistence loading
	# persistence.nvim will handle whether a session exists for this context
	echo "nvim -c 'lua vim.schedule(function() pcall(require, \"persistence\") and require(\"persistence\").load() end)'"
}

main
