# Default target when running `make` without arguments.
.DEFAULT_GOAL := all

SHELL := /bin/bash
.SHELLFLAGS := -Eeuo pipefail -c
.ONESHELL:

SCRIPT := ./oci-tenancy-review

all: compartments policies compute block-storage limits

compartments:
	@$(SCRIPT) compartments

policies: compartments
	@$(SCRIPT) policies-prepare
	@targets="$$(awk 'NF {print "policy-compartment-"$$1}' report/policies/.policy_cids.txt)"; \
	if [[ -n "$$targets" ]]; then $(MAKE) $$targets; fi
	@$(SCRIPT) policies-merge

policy-compartment-%:
	@cid="$*"; $(SCRIPT) _policy-compartment "$$cid" "report/policies/compartments/$$cid.jsonl"

compute: compartments regions
	@regions="$$(awk 'NF {print "compute-region-"$$0}' report/regions.txt)"; \
	if [[ -n "$$regions" ]]; then $(MAKE) $$regions; fi
	@$(SCRIPT) compute-merge

compute-region-%:
	@$(SCRIPT) compute-region-prepare $*
	@targets="$$(awk 'NF {print "compute-compartment-$*___CID___"$$1}' report/compute/regions/$*/.compute_cids_$*.txt)"; \
	if [[ -n "$$targets" ]]; then $(MAKE) $$targets; fi
	@$(SCRIPT) compute-region-merge $*

compute-compartment-%:
	@stem="$*"; region="$${stem%%___CID___*}"; cid="$${stem#*___CID___}"; \
	$(SCRIPT) _compute-compartment "$$region" "$$cid" "report/compute/regions/$$region/compartments/$$cid.jsonl"

block-storage: compartments regions
	@regions="$$(awk 'NF {print "block-storage-region-"$$0}' report/regions.txt)"; \
	if [[ -n "$$regions" ]]; then $(MAKE) $$regions; fi
	@$(SCRIPT) block-storage-merge

block-storage-region-%:
	@$(SCRIPT) block-storage-region-prepare $*
	@targets="$$(awk 'NF {print "block-storage-compartment-$*___CID___"$$1}' report/storage/regions/$*/.storage_cids_$*.txt)"; \
	if [[ -n "$$targets" ]]; then $(MAKE) $$targets; fi
	@$(SCRIPT) block-storage-region-merge $*

block-storage-compartment-%:
	@stem="$*"; region="$${stem%%___CID___*}"; cid="$${stem#*___CID___}"; \
	$(SCRIPT) _storage-compartment "$$region" "$$cid" "report/storage/regions/$$region/compartments/$$cid"

limits: compute block-storage
	@regions="$$(awk 'NF {print "limits-region-"$$0}' report/regions.txt)"; \
	if [[ -n "$$regions" ]]; then $(MAKE) $$regions; fi
	@$(SCRIPT) limits-merge

limits-region-%:
	@$(SCRIPT) limits-region $*

regions:
	@$(SCRIPT) regions

clean:
	rm -rf report report.tar.gz

help:
	@echo "usage: make <target>"
	@echo ""
	@echo "targets:"
	@echo "  all            Run complete review with dependency-aware scheduling"
	@echo "  compartments   Build report/compartments.csv"
	@echo "  policies       Build report/policies/policy_statements.csv"
	@echo "  compute        Build report/compute/compute_instances.csv"
	@echo "  compute-region-<region> Fetch compute for a single region"
	@echo "  block-storage  Build report/storage/storage_inventory.csv"
	@echo "  block-storage-region-<region> Fetch storage for a single region"
	@echo "  limits         Build report/limits/service_limits.csv"
	@echo "  limits-region-<region> Fetch limits for a single region"
	@echo "  regions        Build report/regions.txt"
	@echo "  clean          Remove report artifacts"

.PHONY: all compartments policies compute block-storage limits regions clean help
