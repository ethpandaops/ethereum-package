# Dockerfile-based linter for Starlark files
DOCKERFILE_LINT := Dockerfile.buildifier
LINT_IMAGE := ethereum-package-buildifier

.PHONY: lint lint-build fmt fmt-check

# Build the lint Docker image
lint-build:
	docker build -f $(DOCKERFILE_LINT) -t $(LINT_IMAGE) .

# Run buildifier on .star files (all files if no FILES specified, or specific FILES/patterns)
lint: lint-build
	@if [ "$(FILES)" ]; then \
		echo "Running buildifier on specified files: $(FILES)"; \
		exit_code=0; \
		for pattern in $(FILES); do \
			for file in $$pattern; do \
				if [ -f "$$file" ]; then \
					printf "\033[1;34mLinting file: \033[1;33m%s\033[0m\n" "$$file"; \
					docker run --rm -u $(shell id -u):$(shell id -g) -v $(PWD):/workspace $(LINT_IMAGE) --config=.buildifier.lint.json "$$file" || exit_code=1; \
				fi; \
			done; \
		done; \
		exit $$exit_code; \
	else \
		echo "Running buildifier on all .star files..."; \
		exit_code=0; \
		for file in $$(find . -name "*.star" -type f); do \
			printf "\033[1;34mLinting file: \033[1;33m%s\033[0m\n" "$$file"; \
			docker run --rm -u $(shell id -u):$(shell id -g) -v $(PWD):/workspace $(LINT_IMAGE) --config=.buildifier.lint.json "$$file" || exit_code=1; \
		done; \
		exit $$exit_code; \
	fi
	@echo "Linting complete."

# Format .star files using buildifier (all files if no FILES specified, or specific FILES/patterns)
fmt: lint-build
	@if [ "$(FILES)" ]; then \
		echo "Formatting specified files: $(FILES)"; \
		for pattern in $(FILES); do \
			for file in $$pattern; do \
				if [ -f "$$file" ]; then \
					printf "\033[1;32mFormatting file: \033[1;33m%s\033[0m\n" "$$file"; \
					cat "$$file" | docker run --rm -i -u $(shell id -u):$(shell id -g) -v $(PWD):/workspace $(LINT_IMAGE) --type=bzl > "$$file.tmp" && mv "$$file.tmp" "$$file"; \
				fi; \
			done; \
		done; \
	else \
		echo "Formatting all .star files..."; \
		find . -name "*.star" -type f | while read file; do \
			printf "\033[1;32mFormatting file: \033[1;33m%s\033[0m\n" "$$file"; \
			cat "$$file" | docker run --rm -i -u $(shell id -u):$(shell id -g) -v $(PWD):/workspace $(LINT_IMAGE) --type=bzl > "$$file.tmp" && mv "$$file.tmp" "$$file"; \
		done; \
	fi
	@echo "Formatting complete."
