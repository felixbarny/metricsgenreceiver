include ./Makefile.Common

# All source code and documents. Used in spell check.
ALL_DOC := $(shell find . \( -name "*.md" -o -name "*.yaml" \) \
                                -type f | sort)

# ALL_MODULES includes ./* dirs with a go.mod file (excludes . and ./_build dirs)
ALL_MODULES := $(shell find . -type f -name "go.mod" -not -wholename "./go.mod" -not -wholename "./_build/*" -exec dirname {} \; | sort )

GROUP ?= all
FOR_GROUP_TARGET=for-$(GROUP)-target

.DEFAULT_GOAL := all

.PHONY: all
all: misspell

# Append root module to all modules
GOMODULES = $(ALL_MODULES)

# Define a delegation target for each module
.PHONY: $(GOMODULES)
$(GOMODULES):
	@echo "Running target '$(TARGET)' in module '$@'"
	$(MAKE) -C $@ $(TARGET)

# Triggers each module's delegation target
.PHONY: for-all-target
for-all-target: $(GOMODULES)

.PHONY: gomoddownload
gomoddownload:
	@$(MAKE) $(FOR_GROUP_TARGET) TARGET="moddownload"

.PHONY: gotest
gotest:
	@$(MAKE) $(FOR_GROUP_TARGET) TARGET="test"

.PHONY: golint
golint:
	@$(MAKE) $(FOR_GROUP_TARGET) TARGET="lint"

.PHONY: golicense
golicense:
	@$(MAKE) $(FOR_GROUP_TARGET) TARGET="license-check"

.PHONY: gofmt
gofmt:
	@$(MAKE) $(FOR_GROUP_TARGET) TARGET="fmt"

.PHONY: gotidy
gotidy:
	@$(MAKE) $(FOR_GROUP_TARGET) TARGET="tidy"

.PHONY: gogenerate
gogenerate:
	@$(MAKE) $(FOR_GROUP_TARGET) TARGET="generate"
	@$(MAKE) $(FOR_GROUP_TARGET) TARGET="fmt"

.PHONY: gogovulncheck
gogovulncheck:
	$(MAKE) $(FOR_GROUP_TARGET) TARGET="govulncheck"

.PHONY: goporto
goporto:
	$(MAKE) $(FOR_GROUP_TARGET) TARGET="porto"

# Build a collector based on the Elastic components (generate Elastic collector)
.PHONY: genelasticcol
genelasticcol: $(BUILDER)
	$(BUILDER) --config ./distributions/elastic-components/manifest.yaml

# Validate that the Elastic components collector can run with the example configuration.
.PHONY: elasticcol-validate
elasticcol-validate: genelasticcol
	./_build/elastic-collector-components validate --config ./distributions/elastic-components/config.yaml

.PHONY: builddocker
builddocker:
	@if [ -z "$(TAG)" ]; then \
		echo "TAG is not set. Please provide a tag using 'make builddocker TAG=<tag>'"; \
		exit 1; \
	fi
	@if [ ! -f "_build/elastic-collector-components" ]; then \
		GOOS=linux $(MAKE) genelasticcol; \
	fi
	@if [ -n "$(USERNAME)" ]; then \
		IMAGE_NAME=$(USERNAME)/elastic-collector-components:$(TAG); \
	else \
		IMAGE_NAME=elastic-collector-components:$(TAG); \
	fi; \
	docker build -t $$IMAGE_NAME -f distributions/elastic-components/Dockerfile .
