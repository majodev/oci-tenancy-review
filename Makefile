# This Makefile is used to enable concurrent job execution (-j 8) by a fan-out mechanism on regions -> compartment level. 
# Default target when running `make` without arguments.
.DEFAULT_GOAL := all

SHELL := /bin/bash
.SHELLFLAGS := -Eeuo pipefail -c
.ONESHELL:

SCRIPT := ./oci-tenancy-review

all: compute block-storage limits policies

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

.PHONY: all policies compute block-storage limits \
	policy-compartment-% compute-region-% compute-compartment-% \
	block-storage-region-% block-storage-compartment-% limits-region-% \
	compartments regions
