# This Makefile is used to enable concurrent job execution (-j 4) by a fan-out mechanism on regions -> compartment level.
# Native Make file targets are used for caching top-level artifacts.
.DEFAULT_GOAL := all

SHELL := /bin/bash
.SHELLFLAGS := -Eeuo pipefail -c
.ONESHELL:

SCRIPT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))/oci-tenancy-review
SELF_MAKEFILE := $(lastword $(MAKEFILE_LIST))
REBUILD_DEPS := $(SCRIPT) $(SELF_MAKEFILE)

all: \
	report/compartments.csv \
	report/policies/policy_statements.csv \
	report/compute/compute_instances.csv \
	report/compute/compute_shapes_summary.csv \
	report/network/vcns.csv \
	report/network/subnets.csv \
	report/network/security_lists.csv \
	report/network/route_tables.csv \
	report/network/dhcp_options.csv \
	report/network/internet_gateways.csv \
	report/network/nat_gateways.csv \
	report/network/service_gateways.csv \
	report/network/local_peering_gateways.csv \
	report/network/network_security_groups.csv \
	report/network/network_security_group_rules.csv \
	report/network/drg_attachments.csv \
	report/storage/storage_inventory.csv \
	report/base-database/base_databases.csv \
	report/object-storage/buckets_inventory.csv \
	report/limits/compute_limits.csv \
	report/limits/block_storage_limits.csv \
	report/limits/object_storage_limits.csv \
	report/limits/service_limits.csv

regions: report/regions.txt

report/regions.txt: $(REBUILD_DEPS)
	@$(SCRIPT) regions

compartments: report/compartments.csv

report/compartments.csv: $(REBUILD_DEPS)
	@$(SCRIPT) compartments

policies: report/policies/policy_statements.csv

report/policies/policy_statements.csv: report/compartments.csv $(REBUILD_DEPS)
	@$(SCRIPT) policies-prepare
	@targets="$$(awk 'NF {print "policy-compartment-"$$1}' report/policies/.policy_cids.txt)"; \
	if [[ -n "$$targets" ]]; then $(MAKE) -f "$(SELF_MAKEFILE)" $$targets; fi
	@$(SCRIPT) policies-merge

policy-compartment-%:
	@cid="$*"; $(SCRIPT) _policy-compartment "$$cid" "report/policies/compartments/$$cid.jsonl"

compute: report/compute/compute_instances.csv report/compute/compute_shapes_summary.csv

report/compute/compute_instances.csv: report/compartments.csv report/regions.txt $(REBUILD_DEPS)
	@regions="$$(awk 'NF {print "compute-region-"$$0}' report/regions.txt)"; \
	if [[ -n "$$regions" ]]; then $(MAKE) -f "$(SELF_MAKEFILE)" $$regions; fi
	@$(SCRIPT) compute-merge

# compute-merge emits both files; if summary is missing, rebuild from existing region artifacts.
report/compute/compute_shapes_summary.csv: report/compute/compute_instances.csv
	@[[ -s "$@" ]] || $(SCRIPT) compute-merge

compute-region-%:
	@$(SCRIPT) compute-region-prepare $*
	@targets="$$(awk 'NF {print "compute-compartment-$*___CID___"$$1}' report/compute/regions/$*/.compute_cids_$*.txt)"; \
	if [[ -n "$$targets" ]]; then $(MAKE) -f "$(SELF_MAKEFILE)" $$targets; fi
	@$(SCRIPT) compute-region-merge $*

compute-compartment-%:
	@stem="$*"; region="$${stem%%___CID___*}"; cid="$${stem#*___CID___}"; \
	$(SCRIPT) _compute-compartment "$$region" "$$cid" "report/compute/regions/$$region/compartments/$$cid.jsonl"

network: \
	report/network/vcns.csv \
	report/network/subnets.csv \
	report/network/security_lists.csv \
	report/network/route_tables.csv \
	report/network/dhcp_options.csv \
	report/network/internet_gateways.csv \
	report/network/nat_gateways.csv \
	report/network/service_gateways.csv \
	report/network/local_peering_gateways.csv \
	report/network/network_security_groups.csv \
	report/network/network_security_group_rules.csv \
	report/network/drg_attachments.csv

report/network/vcns.csv: report/compartments.csv report/regions.txt $(REBUILD_DEPS)
	@regions="$$(awk 'NF {print "network-region-"$$0}' report/regions.txt)"; \
	if [[ -n "$$regions" ]]; then $(MAKE) -f "$(SELF_MAKEFILE)" $$regions; fi
	@$(SCRIPT) network-merge

report/network/subnets.csv \
report/network/security_lists.csv \
report/network/route_tables.csv \
report/network/dhcp_options.csv \
report/network/internet_gateways.csv \
report/network/nat_gateways.csv \
report/network/service_gateways.csv \
report/network/local_peering_gateways.csv \
report/network/network_security_groups.csv \
report/network/network_security_group_rules.csv \
report/network/drg_attachments.csv: report/network/vcns.csv
	@[[ -s "$@" ]] || $(SCRIPT) network-merge

network-region-%:
	@$(SCRIPT) network-region-prepare $*
	@targets="$$(awk 'NF {print "network-compartment-$*___CID___"$$1}' report/network/regions/$*/.network_cids_$*.txt)"; \
	if [[ -n "$$targets" ]]; then $(MAKE) -f "$(SELF_MAKEFILE)" $$targets; fi
	@$(SCRIPT) network-region-merge $*

network-compartment-%:
	@stem="$*"; region="$${stem%%___CID___*}"; cid="$${stem#*___CID___}"; \
	$(SCRIPT) _network-compartment "$$region" "$$cid" "report/network/regions/$$region/compartments/$$cid"

block-storage: report/storage/storage_inventory.csv

report/storage/storage_inventory.csv: report/compartments.csv report/regions.txt $(REBUILD_DEPS)
	@regions="$$(awk 'NF {print "block-storage-region-"$$0}' report/regions.txt)"; \
	if [[ -n "$$regions" ]]; then $(MAKE) -f "$(SELF_MAKEFILE)" $$regions; fi
	@$(SCRIPT) block-storage-merge

block-storage-region-%:
	@$(SCRIPT) block-storage-region-prepare $*
	@targets="$$(awk 'NF {print "block-storage-compartment-$*___CID___"$$1}' report/storage/regions/$*/.storage_cids_$*.txt)"; \
	if [[ -n "$$targets" ]]; then $(MAKE) -f "$(SELF_MAKEFILE)" $$targets; fi
	@$(SCRIPT) block-storage-region-merge $*

block-storage-compartment-%:
	@stem="$*"; region="$${stem%%___CID___*}"; cid="$${stem#*___CID___}"; \
	$(SCRIPT) _storage-compartment "$$region" "$$cid" "report/storage/regions/$$region/compartments/$$cid"

base-database: report/base-database/base_databases.csv

report/base-database/base_databases.csv: report/compartments.csv report/regions.txt $(REBUILD_DEPS)
	@regions="$$(awk 'NF {print "base-database-region-"$$0}' report/regions.txt)"; \
	if [[ -n "$$regions" ]]; then $(MAKE) -f "$(SELF_MAKEFILE)" $$regions; fi
	@$(SCRIPT) base-database-merge

base-database-region-%:
	@$(SCRIPT) base-database-region-prepare $*
	@targets="$$(awk 'NF {print "base-database-compartment-$*___CID___"$$1}' report/base-database/regions/$*/.base_database_cids_$*.txt)"; \
	if [[ -n "$$targets" ]]; then $(MAKE) -f "$(SELF_MAKEFILE)" $$targets; fi
	@$(SCRIPT) base-database-region-merge $*

base-database-compartment-%:
	@stem="$*"; region="$${stem%%___CID___*}"; cid="$${stem#*___CID___}"; \
	$(SCRIPT) _base-database-compartment "$$region" "$$cid" "report/base-database/regions/$$region/compartments/$$cid.jsonl"

object-storage: report/object-storage/buckets_inventory.csv

report/object-storage/buckets_inventory.csv: report/compartments.csv report/regions.txt $(REBUILD_DEPS)
	@regions="$$(awk 'NF {print "object-storage-region-"$$0}' report/regions.txt)"; \
	if [[ -n "$$regions" ]]; then $(MAKE) -f "$(SELF_MAKEFILE)" $$regions; fi
	@$(SCRIPT) object-storage-merge

object-storage-region-%:
	@$(SCRIPT) object-storage-region-prepare $*
	@namespace="$$(cat report/object-storage/regions/$*/.object_storage_ns_$*.txt 2>/dev/null || true)"; \
	[[ -n "$$namespace" ]] || { echo "Failed to resolve Object Storage namespace for region $*" >&2; exit 1; }; \
	targets="$$(awk -v ns="$$namespace" 'NF {print "object-storage-compartment-$*___CID___"$$1"___NS___"ns}' report/object-storage/regions/$*/.object_storage_cids_$*.txt)"; \
	if [[ -n "$$targets" ]]; then $(MAKE) -f "$(SELF_MAKEFILE)" $$targets; fi
	@$(SCRIPT) object-storage-region-merge $*

object-storage-compartment-%:
	@stem="$*"; region="$${stem%%___CID___*}"; rest="$${stem#*___CID___}"; cid="$${rest%%___NS___*}"; namespace="$${rest#*___NS___}"; \
	$(SCRIPT) _object-storage-compartment "$$region" "$$cid" "report/object-storage/regions/$$region/compartments/$$cid.jsonl" "$$namespace"

compute-limits: report/limits/compute_limits.csv

report/limits/compute_limits.csv: report/compute/compute_instances.csv report/regions.txt $(REBUILD_DEPS)
	@regions="$$(awk 'NF {print "limits-region-"$$0"___SVC___compute"}' report/regions.txt)"; \
	if [[ -n "$$regions" ]]; then $(MAKE) -f "$(SELF_MAKEFILE)" $$regions; fi
	@$(SCRIPT) limits-merge compute

block-storage-limits: report/limits/block_storage_limits.csv

report/limits/block_storage_limits.csv: report/storage/storage_inventory.csv report/regions.txt $(REBUILD_DEPS)
	@regions="$$(awk 'NF {print "limits-region-"$$0"___SVC___block-storage"}' report/regions.txt)"; \
	if [[ -n "$$regions" ]]; then $(MAKE) -f "$(SELF_MAKEFILE)" $$regions; fi
	@$(SCRIPT) limits-merge block-storage

object-storage-limits: report/limits/object_storage_limits.csv

report/limits/object_storage_limits.csv: report/object-storage/buckets_inventory.csv report/regions.txt $(REBUILD_DEPS)
	@regions="$$(awk 'NF {print "limits-region-"$$0"___SVC___object-storage"}' report/regions.txt)"; \
	if [[ -n "$$regions" ]]; then $(MAKE) -f "$(SELF_MAKEFILE)" $$regions; fi
	@$(SCRIPT) limits-merge object-storage

limits: report/limits/service_limits.csv

report/limits/service_limits.csv: report/limits/compute_limits.csv report/limits/block_storage_limits.csv report/limits/object_storage_limits.csv $(REBUILD_DEPS)
	@$(SCRIPT) limits-merge

limits-region-%:
	@stem="$*"; region="$${stem%%___SVC___*}"; svc="$${stem#*___SVC___}"; \
	if [[ "$$svc" == "$$stem" ]]; then svc="all"; fi; \
	$(SCRIPT) limits-region "$$region" "$$svc"


.PHONY: all regions compartments policies compute network block-storage base-database limits \
	compute-limits block-storage-limits object-storage-limits object-storage \
	policy-compartment-% compute-region-% compute-compartment-% \
	network-region-% network-compartment-% \
	block-storage-region-% block-storage-compartment-% \
	base-database-region-% base-database-compartment-% \
	object-storage-region-% object-storage-compartment-% limits-region-%
