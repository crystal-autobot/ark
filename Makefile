.PHONY: build release test lint format format-check docker clean help

build: ## Build debug binary
	@mkdir -p bin
	crystal build src/main.cr -o bin/ark

release: ## Build optimized binary
	@mkdir -p bin
	crystal build src/main.cr -o bin/ark --release --no-debug

test: ## Run specs
	crystal spec

lint: ## Run ameba linter
	./bin/ameba src/

format: ## Format source files
	crystal tool format src/ spec/

format-check: ## Check source formatting
	crystal tool format --check src/ spec/

docker: ## Build Docker image
	docker build -t ark .

clean: ## Remove build artifacts
	rm -rf bin/ark build/

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'
