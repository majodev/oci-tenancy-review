# OCI Tenancy Review

> **DISCLAIMER** - This is not an official Oracle application. It is not supported by Oracle Support.

This repository provides `./oci-tenancy-review`, a CLI tool to easily generate OCI tenancy bill of materials (BOMs) exported as CSV, compatible with [Cloud Shell](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/cloudshellintro.htm).

We focus on **speed by concurrently scraping specific OCI domains** (e.g. compute, network/VCN, block-storage, base-database, object-storage, limits) rather than providing a full view of a whole OCI tenancy. These CSV artifacts can be cached granularly, making the process resumable.

Here's a sample video on how to quickly download a full archive of usage CSVs of your tenancy via [Cloud Shell](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/cloudshellintro.htm) ([fallback video link](https://objectstorage.eu-frankfurt-1.oraclecloud.com/p/VlWiV3DZA0TZXRVPv3KxWv3Fpp0WaY3BbjtcjfY_M9-v9HrrySN5BJmR9HjItLWD/n/frnhkcj2u67r/b/mranftl_shared/o/oci-tenancy-review/oci-tenancy-review-own-sm.mp4)):   

<p align="center" width="100%">
<video src="https://github.com/user-attachments/assets/9863fe12-ed46-4918-8288-45d009b8f549" width="80%" controls></video>
</p>

- [OCI Tenancy Review](#oci-tenancy-review)
  - [Prerequisites](#prerequisites)
  - [Setup](#setup)
    - [Set tenancy OCID (required)](#set-tenancy-ocid-required)
  - [Usage](#usage)
    - [Advanced: parallel fan-out + cached CSV outputs via Make](#advanced-parallel-fan-out--cached-csv-outputs-via-make)
    - [Setting target region(s) for discovery](#setting-target-regions-for-discovery)
    - [Run a specific reporter (uncached)](#run-a-specific-reporter-uncached)
  - [Exported Files](#exported-files)
    - [`report/regions.txt`](#reportregionstxt)
    - [`report/compartments.csv`](#reportcompartmentscsv)
    - [`report/policies/policy_statements.csv`](#reportpoliciespolicy_statementscsv)
    - [`report/compute/compute_instances.csv`](#reportcomputecompute_instancescsv)
    - [`report/compute/compute_shapes_summary.csv`](#reportcomputecompute_shapes_summarycsv)
    - [`report/network/vcns.csv`](#reportnetworkvcnscsv)
    - [`report/network/subnets.csv`](#reportnetworksubnetscsv)
    - [`report/network/security_lists.csv`](#reportnetworksecurity_listscsv)
    - [`report/network/route_tables.csv`](#reportnetworkroute_tablescsv)
    - [`report/network/dhcp_options.csv`](#reportnetworkdhcp_optionscsv)
    - [`report/network/internet_gateways.csv`](#reportnetworkinternet_gatewayscsv)
    - [`report/network/nat_gateways.csv`](#reportnetworknat_gatewayscsv)
    - [`report/network/service_gateways.csv`](#reportnetworkservice_gatewayscsv)
    - [`report/network/local_peering_gateways.csv`](#reportnetworklocal_peering_gatewayscsv)
    - [`report/network/network_security_groups.csv`](#reportnetworknetwork_security_groupscsv)
    - [`report/network/network_security_group_rules.csv`](#reportnetworknetwork_security_group_rulescsv)
    - [`report/network/drg_attachments.csv`](#reportnetworkdrg_attachmentscsv)
    - [`report/storage/storage_inventory.csv`](#reportstoragestorage_inventorycsv)
    - [`report/object-storage/buckets_inventory.csv`](#reportobject-storagebuckets_inventorycsv)
    - [`report/base-database/base_databases.csv`](#reportbase-databasebase_databasescsv)
    - [`report/limits/service_limits.csv`](#reportlimitsservice_limitscsv)
    - [`report/limits/compute_limits.csv`](#reportlimitscompute_limitscsv)
    - [`report/limits/block_storage_limits.csv`](#reportlimitsblock_storage_limitscsv)
    - [`report/limits/object_storage_limits.csv`](#reportlimitsobject_storage_limitscsv)
    - [Per-Region Reports](#per-region-reports)
  - [Tests](#tests)
  - [Safety \& Auditability](#safety--auditability)
    - [OCI Call Mapping](#oci-call-mapping)
  - [Design Choices](#design-choices)
  - [Alternatives](#alternatives)
    - [Key Feature Comparison](#key-feature-comparison)
    - [Practical Trade-off](#practical-trade-off)


## Prerequisites

If running in OCI [Cloud Shell](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/cloudshellintro.htm) all tooling is already available.

For local runs, ensure the following is installed and configured:
* [jq](https://github.com/jqlang/jq)
* [OCI CLI](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/cliconcepts.htm)
* UNIX tooling like `bash`, `awk`, `sort`
* (Optional, advanced) GNU `make` for parallel fan-out and cached top-level CSV targets

## Setup

```bash
git clone https://github.com/majodev/oci-tenancy-review.git
cd oci-tenancy-review
chmod +x ./oci-tenancy-review

```

### Set tenancy OCID (required)

You need administrative access to your tenancy, the tenancy you want to inspect must be supplied via the env var `TENANCY_OCID`.

Use one of the following three options depending on your environment:

<details open>
<summary><b>Option 1: Automatically set TENANCY_OCID within OCI Cloud Shell</b></summary>

If you are running inside [Cloud Shell](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/cloudshellintro.htm), simply reuse the tenancy OCID from current OCI CLI context:

```bash
export TENANCY_OCID="${TENANCY_OCID:-$(
  oci iam compartment list \
    --include-root \
    --compartment-id-in-subtree true \
    --access-level ANY \
    --all \
    --query 'data[?starts_with(id, `ocid1.tenancy.`)].id | [0]' \
    --raw-output
)}"
echo "Your tenancy OCID is: '${TENANCY_OCID}'"

```
</details>

<details>
<summary><b>Option 2: Automatically set TENANCY_OCID on your local machine</b></summary>

Read tenancy OCID from `~/.oci/config` (uses `OCI_CLI_PROFILE` or `DEFAULT`):

```bash
OCI_PROFILE="${OCI_CLI_PROFILE:-DEFAULT}"
export TENANCY_OCID="${TENANCY_OCID:-$(
  awk -v profile="$OCI_PROFILE" '
    $0=="[" profile "]" {in_profile=1; next}
    /^\[/ {in_profile=0}
    in_profile && $1 ~ /^tenancy[[:space:]]*=/ {
      sub(/^[^=]*=[[:space:]]*/, "", $0); print $0; exit
    }
  ' ~/.oci/config
)}"
echo "Your tenancy OCID is: '${TENANCY_OCID}'"

```

</details>

<details>
<summary><b>Option 3: Set TENANCY_OCID manually</b></summary>

To explicitly set your `TENANCY_OCID` use the following:

```bash
# cat ~/.oci/config
export TENANCY_OCID="ocid1.tenancy.oc1...."
echo "Your tenancy OCID is: '${TENANCY_OCID}'"

```

</details>


## Usage

```bash
# Run all reports (delegates to `make -j 4 --no-print-directory all`, so 4 jobs can execute concurrently)
./oci-tenancy-review all

# Your reports are now available in the report subfolder
# If you are within an OCI Cloud Shell, you may want to archive this folder to download it more easily
tar -czvf report.tar.gz report

```

If you used OCI [Cloud Shell](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/cloudshellintro.htm) to execute the above, you should now be able to download the archived report by navigating to "Cog -> Download" (top right) and targeting this file:
```
oci-tenancy-review/report.tar.gz
```

Now inspect all `.csv` files in that archive.

---

### Advanced: parallel fan-out + cached CSV outputs via Make

For larger tenancies or repeated runs, use `make` to execute region/compartment fan-out concurrently and cache top-level CSV outputs.

```bash
# Build all top-level CSVs (cached by file timestamps) with 4 job runners
make -j 4 --no-print-directory all

# Run specific job runner concurrently
make -j 4 --no-print-directory regions compartments policies compute network block-storage base-database object-storage limits 

# Build a specific CSV artifact (this will execute the dependent runner)
make -j 4 --no-print-directory report/compute/compute_instances.csv
make -j 4 --no-print-directory report/limits/service_limits.csv
```

---

### Setting target region(s) for discovery

If `REGIONS` is unset, discovery runs in all subscribed regions (the default case).  
Set `REGIONS` to override this and target one or more specific regions:

```bash
# single region
export REGIONS="eu-frankfurt-1"

# multiple regions (comma-separated)
export REGIONS="eu-frankfurt-1,eu-zurich-1"
```

When targeting regions (default all subscribed or `REGIONS`), the script
first checks if each region is reachable and automatically skips unreachable ones.
By default, `eu-kragujevac-1` is blacklisted. You can override blacklist regions with:

```bash
export BLACKLISTED_REGIONS="eu-amsterdam-1"
```

### Run a specific reporter (uncached)

Note that the following runs uncached and serial. Use `make -j 4 --no-print-directory <cmd>` if you want to control job concurrency and have artifact caching.

```bash
# Build report/regions.txt (reachable, non-blacklisted target regions)
./oci-tenancy-review regions

# Build report/compartments.csv
./oci-tenancy-review compartments

# Build compute inventory CSVs at report/compute/
./oci-tenancy-review compute

# Build compute inventory for one region at report/compute/regions/<region>/
./oci-tenancy-review compute-region eu-frankfurt-1

# Build VCN/network inventory CSVs at report/network/
./oci-tenancy-review network

# Build VCN/network inventory for one region at report/network/regions/<region>/
./oci-tenancy-review network-region eu-frankfurt-1

# Build block + boot volume inventory CSV at report/storage/
./oci-tenancy-review block-storage

# Build storage inventory for one region at report/storage/regions/<region>/
./oci-tenancy-review block-storage-region eu-frankfurt-1

# Build object storage bucket inventory CSV at report/object-storage/
./oci-tenancy-review object-storage

# Build object storage inventory for one region at report/object-storage/regions/<region>/
./oci-tenancy-review object-storage-region eu-frankfurt-1

# Build base database inventory CSV at report/base-database/
./oci-tenancy-review base-database

# Build base database inventory for one region at report/base-database/regions/<region>/
./oci-tenancy-review base-database-region eu-frankfurt-1

# Build compute + block-storage + object-storage limits posture CSV at report/limits/
./oci-tenancy-review limits

# Build compute-only limits CSV at report/limits/compute_limits.csv
./oci-tenancy-review compute-limits

# Build block-storage-only limits CSV at report/limits/block_storage_limits.csv
./oci-tenancy-review block-storage-limits

# Build object-storage-only limits CSV at report/limits/object_storage_limits.csv
./oci-tenancy-review object-storage-limits

# Build limits posture for one region at report/limits/regions/<region>/
./oci-tenancy-review limits-region eu-frankfurt-1

# Build report/policies/policy_statements.csv
./oci-tenancy-review policies

# Enable debug shell tracing (-x)
DEBUG=true ./oci-tenancy-review compute
```

Notes:
- All outputs are written relative to current working directory under `report/`.
- Run `./oci-tenancy-review help` for command help.

## Exported Files

![csv and exported folder structure](https://github.com/user-attachments/assets/3a3db547-8a7f-4c36-9828-7b45fc4f714a)

### `report/regions.txt`

Newline-separated target region names used for discovery (for example `eu-frankfurt-1`), after applying:
- `REGIONS` selection (or all subscribed if unset)
- reachability checks
- `BLACKLISTED_REGIONS` exclusions

### `report/compartments.csv`

CSV header:
- `compartment-id`
- `compartment-path`

### `report/policies/policy_statements.csv`

CSV header:
- `compartment-id`
- `compartment-path` (human-readable path, `:` separated)
- `statement-seq`
- `policy-name`
- `policy-statement` (one row per statement)
- `created-by` (from defined tag `Oracle-Tags.CreatedBy` when present)
- `time-created`
- `policy-lifecycle-state`
- `policy-description`
- `policy-freeform-tag-count`
- `policy-defined-tag-namespace-count`
- `id` (policy OCID)

### `report/compute/compute_instances.csv`

CSV header:
- `compartment-id`
- `compartment-path`
- `region`
- `instance-name`
- `shape`
- `ocpus`
- `memory-in-gbs`
- `baseline-ocpu-utilization`
- `lifecycle-state`
- `availability-domain`
- `fault-domain`
- `image-id`
- `launch-mode`
- `launch-boot-volume-type`
- `launch-firmware`
- `launch-remote-data-volume-type`
- `source-type`
- `capacity-reservation-id`
- `dedicated-vm-host-id`
- `time-maintenance-reboot-due`
- `preemptible-action-type`
- `availability-recovery-action`
- `legacy-imds-endpoints-disabled`
- `network-type`
- `consistent-volume-naming-enabled`
- `all-plugins-disabled`
- `monitoring-disabled`
- `management-disabled`
- `live-migration-preferred`
- `pv-encryption-in-transit-enabled`
- `metadata-key-count`
- `extended-metadata-key-count`
- `platform-type`
- `platform-secure-boot-enabled`
- `platform-tpm-enabled`
- `platform-measured-boot-enabled`
- `platform-memory-encryption-enabled`
- `freeform-tag-count`
- `defined-tag-namespace-count`
- `time-created`
- `instance-id`

### `report/compute/compute_shapes_summary.csv`

CSV header:
- `shape`
- `count`

Shape distribution summary derived from `compute_instances.csv`.

### `report/network/vcns.csv`

CSV header:
- `compartment-id`
- `compartment-path`
- `region`
- `vcn-name`
- `dns-label`
- `vcn-domain-name`
- `cidr-block`
- `cidr-blocks`
- `ipv6-cidr-blocks`
- `is-ipv6-enabled`
- `default-route-table-id`
- `default-security-list-id`
- `default-dhcp-options-id`
- `freeform-tag-count`
- `defined-tag-namespace-count`
- `time-created`
- `id`

### `report/network/subnets.csv`

CSV header:
- `compartment-id`
- `compartment-path`
- `region`
- `vcn-name`
- `vcn-id`
- `subnet-name`
- `availability-domain`
- `dns-label`
- `subnet-domain-name`
- `cidr-block`
- `ipv6-cidr-block`
- `ipv6-cidr-blocks`
- `route-table-id`
- `dhcp-options-id`
- `security-list-ids`
- `prohibit-public-ip-on-vnic`
- `prohibit-internet-ingress`
- `freeform-tag-count`
- `defined-tag-namespace-count`
- `time-created`
- `id`

### `report/network/security_lists.csv`

CSV header:
- `compartment-id`
- `compartment-path`
- `region`
- `vcn-name`
- `vcn-id`
- `security-list-name`
- `ingress-rule-count`
- `egress-rule-count`
- `ingress-rules-json`
- `egress-rules-json`
- `freeform-tag-count`
- `defined-tag-namespace-count`
- `time-created`
- `lifecycle-state`
- `id`

### `report/network/route_tables.csv`

CSV header:
- `compartment-id`
- `compartment-path`
- `region`
- `vcn-name`
- `vcn-id`
- `route-table-name`
- `route-rule-count`
- `route-rules-json`
- `freeform-tag-count`
- `defined-tag-namespace-count`
- `time-created`
- `lifecycle-state`
- `id`

### `report/network/dhcp_options.csv`

CSV header:
- `compartment-id`
- `compartment-path`
- `region`
- `vcn-name`
- `vcn-id`
- `dhcp-options-name`
- `option-count`
- `options-json`
- `freeform-tag-count`
- `defined-tag-namespace-count`
- `time-created`
- `lifecycle-state`
- `id`

### `report/network/internet_gateways.csv`

CSV header:
- `compartment-id`
- `compartment-path`
- `region`
- `vcn-name`
- `vcn-id`
- `internet-gateway-name`
- `is-enabled`
- `freeform-tag-count`
- `defined-tag-namespace-count`
- `time-created`
- `lifecycle-state`
- `id`

### `report/network/nat_gateways.csv`

CSV header:
- `compartment-id`
- `compartment-path`
- `region`
- `vcn-name`
- `vcn-id`
- `nat-gateway-name`
- `block-traffic`
- `nat-ip`
- `public-ip-id`
- `freeform-tag-count`
- `defined-tag-namespace-count`
- `time-created`
- `lifecycle-state`
- `id`

### `report/network/service_gateways.csv`

CSV header:
- `compartment-id`
- `compartment-path`
- `region`
- `vcn-name`
- `vcn-id`
- `service-gateway-name`
- `route-table-id`
- `service-count`
- `services-json`
- `freeform-tag-count`
- `defined-tag-namespace-count`
- `time-created`
- `lifecycle-state`
- `id`

### `report/network/local_peering_gateways.csv`

CSV header:
- `compartment-id`
- `compartment-path`
- `region`
- `vcn-name`
- `vcn-id`
- `local-peering-gateway-name`
- `peer-id`
- `route-table-id`
- `freeform-tag-count`
- `defined-tag-namespace-count`
- `time-created`
- `lifecycle-state`
- `id`

### `report/network/network_security_groups.csv`

CSV header:
- `compartment-id`
- `compartment-path`
- `region`
- `vcn-name`
- `vcn-id`
- `network-security-group-name`
- `rule-count`
- `freeform-tag-count`
- `defined-tag-namespace-count`
- `time-created`
- `lifecycle-state`
- `id`

### `report/network/network_security_group_rules.csv`

CSV header:
- `compartment-id`
- `compartment-path`
- `region`
- `vcn-name`
- `vcn-id`
- `network-security-group-name`
- `network-security-group-id`
- `direction`
- `protocol`
- `is-stateless`
- `source`
- `source-type`
- `destination`
- `destination-type`
- `icmp-type`
- `icmp-code`
- `source-port-range`
- `destination-port-range`
- `description`
- `id`

### `report/network/drg_attachments.csv`

CSV header:
- `compartment-id`
- `compartment-path`
- `region`
- `vcn-name`
- `vcn-id`
- `attachment-name`
- `drg-id`
- `attachment-type`
- `drg-route-table-id`
- `vcn-route-table-id`
- `network-id`
- `network-details-json`
- `time-created`
- `lifecycle-state`
- `id`

The network reporter is intended to provide a fast VCN topology snapshot across regions, including core VCN definitions and their attached subnet/routing/security constructs.

### `report/storage/storage_inventory.csv`

CSV header:
- `compartment-id`
- `compartment-path`
- `region`
- `kind` (`block-volume` or `boot-volume`)
- `display-name`
- `lifecycle-state`
- `availability-domain`
- `size-in-gbs`
- `vpus-per-gb`
- `is-hydrated`
- `auto-tune-enabled`
- `auto-tuned-vpus-per-gb`
- `autotune-policy-count`
- `volume-group-id`
- `replica-ad-list`
- `backup-policy-id`
- `backup-count`
- `latest-backup-time`
- `latest-backup-type`
- `replica-count`
- `dr-protection` (`YES`/`NO`)
- `kms-key-id`
- `image-id` (boot volumes)
- `freeform-tag-count`
- `defined-tag-namespace-count`
- `time-created`
- `id`

This report is designed for storage overview plus DR/failure-mode discovery (backup and replication coverage).

### `report/object-storage/buckets_inventory.csv`

CSV header:
- `compartment-id`
- `compartment-path`
- `region`
- `namespace`
- `bucket-name`
- `bucket-created-by`
- `time-created`
- `etag`
- `freeform-tag-count`
- `defined-tag-namespace-count`
- `freeform-tag-keys` (`;`-joined key names)
- `defined-tag-namespaces` (`;`-joined namespace names)
- `defined-tag-key-count` (sum of tag keys across defined-tag namespaces)
- `freeform-tags-json` (raw freeform tags object)
- `defined-tags-json` (raw defined tags object)
- `bucket-id`
- `public-access-type`
- `storage-tier`
- `object-events-enabled`
- `replication-enabled`
- `is-read-only`
- `versioning`
- `auto-tiering`
- `kms-key-id`
- `approximate-object-count`
- `approximate-size-bytes`
- `object-lifecycle-policy-etag`
- `metadata-key-count`
- `id`

Implementation detail: each bucket now uses `oci os bucket get` for enrichment, while Make fan-out remains region -> compartment for concurrency.

### `report/base-database/base_databases.csv`

CSV header:
- `compartment-id`
- `compartment-path`
- `region`
- `db-name`
- `db-unique-name`
- `db-workload`
- `db-version`
- `db-system-id`
- `db-home-id`
- `vm-cluster-id`
- `cdb-name`
- `pdb-name`
- `lifecycle-state`
- `lifecycle-details`
- `character-set`
- `ncharacter-set`
- `is-cdb`
- `kms-key-id`
- `kms-key-version-id`
- `key-store-id`
- `key-store-wallet-name`
- `vault-id`
- `database-software-image-id`
- `sid-prefix`
- `auto-backup-enabled`
- `backup-recovery-window-in-days`
- `backup-destination-type`
- `auto-full-backup-day`
- `last-backup-timestamp`
- `last-failed-backup-timestamp`
- `last-backup-duration-in-seconds`
- `freeform-tag-count`
- `defined-tag-namespace-count`
- `time-created`
- `id`

### `report/limits/service_limits.csv`

CSV header:
- `region`
- `service-name`
- `limit-name`
- `scope-type`
- `availability-domain`
- `limit-value`
- `used`
- `available`
- `usage-percent`
- `id` (stable key: `region:service-name:scope-type:availability-domain:limit-name`)

Rows are ordered by `usage-percent` descending, then region/service/limit.
This report currently focuses on compute, block-storage, and object-storage service limits.

### `report/limits/compute_limits.csv`

Same schema as `service_limits.csv`, scoped to `service-name=compute`.

### `report/limits/block_storage_limits.csv`

Same schema as `service_limits.csv`, scoped to `service-name=block-storage`.

### `report/limits/object_storage_limits.csv`

Same schema as `service_limits.csv`, scoped to `service-name=object-storage`.

### Per-Region Reports

When region workflows are used (for example via `compute`, `block-storage`, `base-database`, `object-storage`, `limits`), each domain
also writes per-region artifacts:

- `report/compute/regions/<region>/compute_instances.csv`
- `report/network/regions/<region>/vcns.csv`
- `report/network/regions/<region>/subnets.csv`
- `report/network/regions/<region>/security_lists.csv`
- `report/network/regions/<region>/route_tables.csv`
- `report/network/regions/<region>/dhcp_options.csv`
- `report/network/regions/<region>/internet_gateways.csv`
- `report/network/regions/<region>/nat_gateways.csv`
- `report/network/regions/<region>/service_gateways.csv`
- `report/network/regions/<region>/local_peering_gateways.csv`
- `report/network/regions/<region>/network_security_groups.csv`
- `report/network/regions/<region>/network_security_group_rules.csv`
- `report/network/regions/<region>/drg_attachments.csv`
- `report/storage/regions/<region>/storage_inventory.csv`
- `report/base-database/regions/<region>/base_databases.csv`
- `report/object-storage/regions/<region>/buckets_inventory.csv`
- `report/limits/regions/<region>/service_limits.csv`

## Tests

[Bats](https://bats-core.readthedocs.io/en/stable/) tests are under `test/test_main.bats`.

```bash
bats test/test_main.bats
```

## Safety & Auditability

The script is intentionally designed to be straightforward to audit:

- **Read-only OCI usage:** all OCI CLI interactions use read-oriented operations (for example `list`, `get`, `search`).
- **Local write scope:** generated artifacts are written under `./report/`.
- **Runtime call log:** OCI calls and exit codes are written to `report/run.log` by default. Override with `RUN_LOG_FILE`.

In CI/CD, we enforce this read-only expectation with automated tests. The Bats test suite includes:
- a blacklist guard that scans executable source for mutating OCI CLI verbs (`create`, `update`, `delete`, `patch`, `put`, `remove`, `bulk-delete`) and fails if any are introduced, and
- a whitelist guard that allows only explicitly approved OCI invocation patterns used by this project.

The [GitHub Actions workflow](https://github.com/majodev/oci-tenancy-review/actions) runs these tests on every push and pull request.

### OCI Call Mapping

The following mapping summarizes top-level `./oci-tenancy-review` commands and OCI CLI calls used by the script.

- Shared calls:
  - `oci iam region-subscription list`
  - `oci iam availability-domain list`
  - `oci iam compartment list`

- `regions`:
  - `oci iam region-subscription list`
  - `oci iam availability-domain list`

- `compartments`:
  - `oci iam compartment list`

- `policies`:
  - `oci search resource structured-search` (policy resources)
  - `oci iam policy list`

- `compute`, `compute-region`:
  - `oci search resource structured-search` (instance resources)
  - `oci compute instance list`

- `network`, `network-region`:
  - `oci search resource structured-search` (VCN resources)
  - `oci network vcn list`
  - `oci network subnet list`
  - `oci network security-list list`
  - `oci network route-table list`
  - `oci network dhcp-options list`
  - `oci network internet-gateway list`
  - `oci network nat-gateway list`
  - `oci network service-gateway list`
  - `oci network local-peering-gateway list`
  - `oci network nsg list`
  - `oci network nsg rules list`
  - `oci network drg-attachment list`

- `block-storage`, `block-storage-region`:
  - `oci search resource structured-search` (volume resources)
  - `oci search resource structured-search` (bootvolume resources)
  - `oci bv volume list`
  - `oci bv boot-volume list`
  - `oci bv backup list`
  - `oci bv boot-volume-backup list`
  - `oci bv block-volume-replica list`
  - `oci bv boot-volume-replica list`

- `base-database`, `base-database-region`:
  - `oci search resource structured-search` (database resources)
  - `oci db database list`

- `object-storage`, `object-storage-region`:
  - `oci search resource structured-search` (bucket resources)
  - `oci os ns get`
  - `oci os bucket list`
  - `oci os bucket get`

- `compute-limits`, `block-storage-limits`, `object-storage-limits`, `limits`, `limits-region`:
  - `oci limits value list`
  - `oci limits resource-availability get`

- `all`:
  - Delegates to `make`; resulting OCI calls are the union of the selected domain commands.

## Design Choices

This repository intentionally separates concerns:

- `./oci-tenancy-review` is responsible for fetching OCI data and exporting report artifacts per domain (JSON/CSV).
- `Makefile` is responsible for orchestration concerns such as concurrent job execution and cache-aware target rebuilding.

In practice, the script defines what data is fetched and exported, while `make` defines how work is scheduled and reused.


## Alternatives

This tool is intentionally specialized for fast, targeted tenancy BOM extraction. If your primary goal is broader compliance coverage, there are stronger alternatives:

| Alternative | Primary Goal | Collection Model | Typical Scope | Runtime/Complexity Profile | Best Fit |
|---|---|---|---|---|---|
| [CIS Compliance Script (`oci-cis-landingzone-quickstart`)](https://github.com/oci-landing-zones/oci-cis-landingzone-quickstart) | CIS/Best-Practice posture assessment | Python SDK-based checks across many benchmark controls; internal threaded execution | Broad tenancy security/compliance checks, detailed per-finding reports | Higher operational surface (Python env + dependencies), broader/heavier scans that can run significantly longer on large tenancies; no domain-targeted run mode or cache/resume model; limited real-time progress detail during execution | Security/compliance audits, benchmark tracking, governance programs |
| [showoci (`oci-python-sdk/examples/showoci`)](https://github.com/oracle/oci-python-sdk/blob/master/examples/showoci/README.md) | General tenancy inventory exploration | Python SDK sample inventory traversal | Broad resource visibility | Broader and generally slower than focused OCI CLI scraping | Exploration and full-inventory style discovery |
| `oci-tenancy-review` (this repo) | Fast operational BOM exports for selected domains | OCI CLI + Make fan-out + cacheable artifacts | Targeted compute/storage/database/object-storage/limits/policy views | Minimal runtime dependencies in Cloud Shell, optimized for repeated runs and fast CSV output | Ops reviews, tenancy snapshots, cost/capacity and architecture-oriented analysis |

### Key Feature Comparison

| Feature | `oci-tenancy-review` (this repo) | CIS Compliance Script (`oci-cis-landingzone-quickstart`) | showoci (`oci-python-sdk/examples/showoci`) |
|---|---|---|---|
| Domain-scoped execution (run only one focused domain) | Yes (`compute`, `block-storage`, `object-storage`, `base-database`, `limits`, `policies`, etc.) | No dedicated domain subcommands; broad report modes via global flags (`--raw`, `--obp`, `--all-resources`) | Partial via service flags, but oriented to broad service inventory extraction rather than fixed BOM domains |
| Region targeting | Yes (`REGIONS`, plus per-region commands like `compute-region`) | Yes (`--regions`) | Yes (`-rg` / `-rgn`) |
| Resumable/cache-aware artifact graph | Yes (Makefile target graph with cached outputs and incremental rebuilds) | No make-style cache/resume dependency graph | No make-style cache/resume dependency graph (can export cache snapshot, but not orchestrated incremental rebuild model) |
| Concurrency | Yes (Make fan-out and per-domain orchestration) | Yes (threads and thread pools inside Python collector) | Yes (parallel processing by default, configurable thread count) |
| Progress visibility while running | Clear per-domain/per-region command boundaries and artifact-level checkpoints | Limited; mostly coarse stage logs and end-of-stage counts | Moderate console output, but not focused on artifact checkpointing for resumable runs |
| CSV analyst-friendliness (flat columns vs nested objects) | Optimized for analysis-friendly flattened CSV columns per domain | Raw data CSVs often include nested/object fields (for example compute structures), which makes direct spreadsheet analysis harder without extra transformation | Can export broad CSV data, but many outputs prioritize coverage over tightly normalized, domain-specific flat schemas |
| Minimal Cloud Shell operational footprint | Yes (`bash` + `oci` + `jq`; `make` optional advanced path) | No (Python runtime + OCI SDK dependency surface) | No (Python runtime + OCI SDK dependency surface) |
| Read-auditability controls for admins | Strong focus: small Bash entrypoint, explicit OCI command mapping, run log (`report/run.log`), CI tests enforcing read-only OCI command usage | Broader compliance engine; auditability is oriented to benchmark findings rather than a small script surface | Broad inventory tool; not focused on a small audited execution surface for targeted exports |
| Primary output model | Targeted BOM CSV artifacts per domain (plus intermediate JSON) | Compliance findings/reports + optional raw data CSV/JSON | General inventory screen/CSV/JSON reporting |

### Practical Trade-off

Use this project when you want **speed, straightforward auditability, and focused exports**.  
Use the CIS Compliance Script when you want **formal benchmark-aligned compliance depth** (at the cost of broader checks and heavier execution).

If you are interested in a guide for easily executing the OCI CIS compliance script via Cloud Shell, checkout [my guide](https://github.com/majodev/oci-cis-cloud-shell-guide).