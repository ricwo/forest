CURRENT_VERSION := $(shell git fetch --tags >/dev/null 2>&1; git tag -l | sort -V | tail -1 | grep . || echo "0.0.0")
MAJOR := $(shell echo $(CURRENT_VERSION) | cut -d. -f1)
MINOR := $(shell echo $(CURRENT_VERSION) | cut -d. -f2)
PATCH := $(shell echo $(CURRENT_VERSION) | cut -d. -f3)

.PHONY: release-major release-minor release-patch

release-major:
	@echo "Release $(CURRENT_VERSION) → $(shell echo $$(($(MAJOR)+1))).0.0"
	@read -p "Continue? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	@./scripts/release.sh $(shell echo $$(($(MAJOR)+1))).0.0

release-minor:
	@echo "Release $(CURRENT_VERSION) → $(MAJOR).$(shell echo $$(($(MINOR)+1))).0"
	@read -p "Continue? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	@./scripts/release.sh $(MAJOR).$(shell echo $$(($(MINOR)+1))).0

release-patch:
	@echo "Release $(CURRENT_VERSION) → $(MAJOR).$(MINOR).$(shell echo $$(($(PATCH)+1)))"
	@read -p "Continue? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	@./scripts/release.sh $(MAJOR).$(MINOR).$(shell echo $$(($(PATCH)+1)))
