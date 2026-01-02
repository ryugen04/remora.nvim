.PHONY: test test-unit test-integration lint install-deps

# Run all tests
test:
	@echo "Running all tests..."
	nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"

# Run unit tests only
test-unit:
	@echo "Running unit tests..."
	nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/core/ { minimal_init = 'tests/minimal_init.lua' }" \
		-c "PlenaryBustedFile tests/state_spec.lua { minimal_init = 'tests/minimal_init.lua' }" \
		-c "PlenaryBustedDirectory tests/utils/ { minimal_init = 'tests/minimal_init.lua' }"

# Run integration tests only
test-integration:
	@echo "Running integration tests..."
	nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/integration/ { minimal_init = 'tests/minimal_init.lua' }"

# Run specific test file
test-file:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make test-file FILE=tests/path/to/test_spec.lua"; \
		exit 1; \
	fi
	nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "PlenaryBustedFile $(FILE) { minimal_init = 'tests/minimal_init.lua' }"

# Lint Lua files
lint:
	@echo "Linting Lua files..."
	@if command -v luacheck > /dev/null; then \
		luacheck lua/ tests/; \
	else \
		echo "luacheck not found. Install with: luarocks install luacheck"; \
	fi

# Install test dependencies
install-deps:
	@echo "Installing test dependencies..."
	@echo "Cloning plenary.nvim..."
	@if [ ! -d "/tmp/plenary.nvim" ]; then \
		git clone https://github.com/nvim-lua/plenary.nvim /tmp/plenary.nvim; \
	else \
		echo "plenary.nvim already cloned"; \
	fi

# Clean test artifacts
clean:
	@echo "Cleaning test artifacts..."
	rm -rf /tmp/remora-test-data

# Help
help:
	@echo "Available targets:"
	@echo "  test              - Run all tests"
	@echo "  test-unit         - Run unit tests only"
	@echo "  test-integration  - Run integration tests only"
	@echo "  test-file FILE=   - Run specific test file"
	@echo "  lint              - Lint Lua files with luacheck"
	@echo "  install-deps      - Install test dependencies"
	@echo "  clean             - Clean test artifacts"
	@echo ""
	@echo "Examples:"
	@echo "  make test"
	@echo "  make test-unit"
	@echo "  make test-file FILE=tests/core/storage_spec.lua"
