# OCI Tenancy Review

> **DISCLAIMER** - This is not an official Oracle application. It is not supported by Oracle Support.

This repository provides `./oci-tenancy-review`, a CLI tool to easily generate OCI tenancy bill of materials (BOMs) exported as CSV, compatible with [Cloud Shell](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/cloudshellintro.htm).

We focus on **speed by concurrently scraping specific OCI domains** (e.g. compute, block-storage, limits) rather than providing a full view of a whole OCI tenancy.

- [OCI Tenancy Review](#oci-tenancy-review)
  - [Prerequisites](#prerequisites)
  - [Setup](#setup)
    - [Set tenancy OCID (required)](#set-tenancy-ocid-required)
  - [Usage](#usage)
    - [Setting target region(s) for discovery](#setting-target-regions-for-discovery)
    - [Run a specific reporter](#run-a-specific-reporter)
  - [Exported Files](#exported-files)
    - [`report/regions.txt`](#reportregionstxt)
    - [`report/compartments.csv`](#reportcompartmentscsv)
    - [`report/policies/policy_statements.csv`](#reportpoliciespolicy_statementscsv)
    - [`report/compute/compute_instances.csv`](#reportcomputecompute_instancescsv)
    - [`report/compute/compute_shapes_summary.csv`](#reportcomputecompute_shapes_summarycsv)
    - [`report/storage/storage_inventory.csv`](#reportstoragestorage_inventorycsv)
    - [`report/limits/service_limits.csv`](#reportlimitsservice_limitscsv)
    - [Per-Region Reports](#per-region-reports)
  - [Tests](#tests)
  - [Alternatives](#alternatives)


## Prerequisites

If running in OCI [Cloud Shell](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/cloudshellintro.htm) all tooling is already available.

For local runs, ensure the following is installed and configured:
* [jq](https://github.com/jqlang/jq)
* [OCI CLI](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/cliconcepts.htm)
* UNIX tooling like `bash`, GNU `make`, `awk`, `sort`

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
echo "Your tenancy ocid is: '${TENANCY_OCID}'"

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
echo "Your tenancy ocid is: '${TENANCY_OCID}'"

```

</details>

<details>
<summary><b>Option 3: Set TENANCY_OCID manually</b></summary>

To explicitly set your `TENANCY_OCID` use the following:

```bash
# cat ~/.oci/config
export TENANCY_OCID="ocid1.tenancy.oc1...."
echo "Your tenancy ocid is: '${TENANCY_OCID}'"

```

</details>


## Usage

```bash
# Run all reports
./oci-tenancy-review all

# Your reports are now available in the report subfolder
# If you are within a OCI cloud shell, you may want to archive this folder to easily download it
tar -czvf report.tar.gz report

```

If you used OCI [Cloud Shell](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/cloudshellintro.htm) to execute the above, you should now be able to download the archived report by navigating to "Cog -> Download" (top right) and targeting this file:
```
oci-tenancy-review/report.tar.gz
```

Now inspect all .csv files in that archive.

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

### Run a specific reporter

```bash
# Run selected workflow domains
./oci-tenancy-review compute block-storage

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

# Build compute + block-storage limits posture CSV at report/limits/
./oci-tenancy-review limits

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
This report currently focuses on compute and block-storage service limits.

### Per-Region Reports

When region workflows are used (for example via `compute`, `block-storage`, `limits`), each domain
also writes per-region artifacts:

- `report/compute/regions/<region>/compute_instances.csv`
- `report/storage/regions/<region>/storage_inventory.csv`
- `report/limits/regions/<region>/service_limits.csv`

## Tests

Bats tests are under `test/test_main.bats`.

```bash
bats test/test_main.bats
```

## Alternatives

* [oci-python-sdk/examples/showoci](https://github.com/oracle/oci-python-sdk/blob/master/examples/showoci/README.md): More complete (but slower) continuous view of a customer tenancy.
