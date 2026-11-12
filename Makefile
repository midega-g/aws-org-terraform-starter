# Local checks, same as CI. Usage: make check
WORKSPACES := 00_bootstrap 01_org 02_scps 03_iam 04_github_oidc

.PHONY: check fmt validate scan hooks
check: fmt validate scan

fmt:
	terraform fmt -check -recursive terraform

validate:
	@for d in $(WORKSPACES); do \
	  echo "== $$d"; \
	  terraform -chdir=terraform/$$d init -backend=false -input=false >/dev/null && \
	  terraform -chdir=terraform/$$d validate || exit 1; \
	done

scan:
	./scripts/scan-secrets.sh
	checkov -d terraform --config-file .checkov.yaml --quiet

hooks:
	./scripts/setup-hooks.sh
