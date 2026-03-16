# OCI Tenancy Review

This repository provides a single shell script to generate OCI tenancy review artifacts under `report/`.
This script is compatible with OCI [Cloud Shell](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/cloudshellintro.htm).

## Prerequisites

If running in OCI [Cloud Shell](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/cloudshellintro.htm) everything is already preconfigured for you. For local runs, ensure [OCI CLI](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/cliconcepts.htm) and [jq](https://github.com/jqlang/jq) is installed.

## Setup

```bash
git clone https://github.com/majodev/oci-tenancy-review.git
cd oci-tenancy-review
chmod +x ./oci-tenancy-review

```

### Set tenancy OCID (required)

You need administrative access to your tenancy, the tenancy you want to inspect must be supplied via the env var `TENANCY_OCID`.

#### Option 1: OCI Cloud Shell

If you are running inside OCI [Cloud Shell](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/cloudshellintro.htm), use tenancy OCID from current OCI CLI context by default.

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

#### Option 2: Local ENV

Read tenancy OCID from ~/.oci/config (uses OCI_CLI_PROFILE or DEFAULT)

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

#### Option 3: Set manually

```bash
# cat ~/.oci/config
export TENANCY_OCID="ocid1.tenancy.oc1...."
echo "Your tenancy ocid is: '${TENANCY_OCID}'"

```

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

To run a specific reporter, use the following:
```bash
# Build report/compartment_ids.txt (OCID<TAB>path)
./oci-tenancy-review compartments

# Build report/policies/policy_statements.csv
./oci-tenancy-review policies

# Build compute inventory CSVs at report/compute/
./oci-tenancy-review compute
```

Notes:
- All outputs are written relative to current working directory under `report/`.
- Run `./oci-tenancy-review help` for command help.

## Exported Files

### `report/compartment_ids.txt`

Tab-separated file (`OCID<TAB>path`) with one row per compartment:
- `column 1`: compartment OCID
- `column 2`: human-readable compartment path (`root` for tenancy root, child paths like `prod.apps.backend`)

### `report/policies/policy_target_compartments.csv`

CSV header:
- `compartment-id`
- `compartment-path`

Contains the filtered compartment list used for policy collection.

### `report/policies/policy_statements.csv`

CSV header:
- `compartment-id`
- `compartment-name` (human-readable compartment path)
- `policy-name`
- `created-by` (from defined tag `Oracle-Tags.CreatedBy` when present)
- `time-created`
- `the actual statement` (one row per statement)
- `id` (policy OCID)

### `report/compute/compute_target_compartments.csv`

CSV header:
- `compartment-id`
- `compartment-path`

Contains the filtered compartment list used for compute instance collection.

### `report/compute/compute_instances.csv`

CSV header:
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
- `source-type`
- `capacity-reservation-id`
- `dedicated-vm-host-id`
- `preemptible-action-type`
- `availability-recovery-action`
- `legacy-imds-endpoints-disabled`
- `network-type`
- `consistent-volume-naming-enabled`
- `monitoring-disabled`
- `management-disabled`
- `live-migration-preferred`
- `pv-encryption-in-transit-enabled`
- `metadata-key-count`
- `freeform-tag-count`
- `defined-tag-namespace-count`
- `time-created`
- `instance-id`

### `report/compute/compute_shapes_summary.csv`

CSV header:
- `shape`
- `count`

Shape distribution summary derived from `compute_instances.csv`.

## Tests

Bats tests are under `test/test_main.bats`.

```bash
bats test/test_main.bats
```
