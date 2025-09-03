# Dockerfile-based linter for Starlark files
DOCKERFILE_LINT := Dockerfile.lint
LINT_IMAGE := ethereum-package-buildifier

.PHONY: lint lint-build fmt

# Build the lint Docker image
lint-build:
	docker build -f $(DOCKERFILE_LINT) -t $(LINT_IMAGE) .

# Run buildifier on all .star files in the repository
lint: lint-build
	@echo "Running buildifier on .star files..."
	@find . -name "*.star" -type f | while read file; do \
		echo "Linting $$file"; \
		docker run --rm -u $(shell id -u):$(shell id -g) -v $(PWD):/workspace $(LINT_IMAGE) -lint=warn "$$file" || exit 1; \
	done
	@echo "Linting complete."

# Format all .star files using buildifier
fmt: lint-build
	@echo "Formatting .star files..."
	@find . -name "*.star" -type f | while read file; do \
		echo "Formatting $$file"; \
		cat "$$file" | docker run --rm -i -u $(shell id -u):$(shell id -g) -v $(PWD):/workspace $(LINT_IMAGE) --type=bzl > "$$file.tmp" && mv "$$file.tmp" "$$file"; \
	done
	@echo "Formatting complete."