# OCI Tenancy Review

> **DISCLAIMER** - This is not an official Oracle application. It is not supported by Oracle Support.

This repository provides `./oci-tenancy-review`, a CLI tool to easily generate OCI tenancy bill of materials (BOMs) exported as CSV, compatible with [Cloud Shell](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/cloudshellintro.htm).

We focus on **speed by concurrently scraping specific OCI domains** (e.g. compute, block-storage, base-database, object-storage, limits) rather than providing a full view of a whole OCI tenancy. These CSV artifacts can be cached granularly, making the process resumable.

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
    - [`report/storage/storage_inventory.csv`](#reportstoragestorage_inventorycsv)
    - [`report/object-storage/buckets_inventory.csv`](#reportobject-storagebuckets_inventorycsv)
    - [`report/base-database/base_databases.csv`](#reportbase-databasebase_databasescsv)
    - [`report/limits/service_limits.csv`](#reportlimitsservice_limitscsv)
    - [`report/limits/compute_limits.csv`](#reportlimitscompute_limitscsv)
    - [`report/limits/block_storage_limits.csv`](#reportlimitsblock_storage_limitscsv)
    - [`report/limits/object_storage_limits.csv`](#reportlimitsobject_storage_limitscsv)
    - [Per-Region Reports](#per-region-reports)
  - [Tests](#tests)
  - [Design Choices](#design-choices)
  - [Alternatives](#alternatives)


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
make -j 4 --no-print-directory regions compartments policies compute block-storage base-database object-storage limits 

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
- `report/storage/regions/<region>/storage_inventory.csv`
- `report/base-database/regions/<region>/base_databases.csv`
- `report/object-storage/regions/<region>/buckets_inventory.csv`
- `report/limits/regions/<region>/service_limits.csv`

## Tests

[Bats](https://bats-core.readthedocs.io/en/stable/) tests are under `test/test_main.bats`.

```bash
bats test/test_main.bats
```

## Design Choices

This repository intentionally separates concerns:

- `./oci-tenancy-review` is responsible for fetching OCI data and exporting report artifacts per domain (JSON/CSV).
- `Makefile` is responsible for orchestration concerns such as concurrent job execution and cache-aware target rebuilding.

In practice, the script defines what data is fetched and exported, while `make` defines how work is scheduled and reused.


## Alternatives

* [oci-python-sdk/examples/showoci](https://github.com/oracle/oci-python-sdk/blob/master/examples/showoci/README.md): More complete (but slower) continuous view of a customer tenancy.
