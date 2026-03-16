# OCI Tenancy Review

This repository provides a single shell script to generate tenancy review artifacts under `report/`.

## Requirements

- `bash`
- `oci` CLI
- `jq`
- `awk`, `sort`

## Setup

```bash
git clone <this-repo>
cd ace_review
chmod +x ./oci-tenancy-review
```

Set tenancy OCID (required):

```bash
# Option 1 (in Cloud Shell): Use tenancy OCID from current OCI CLI context by default
export TENANCY_OCID="${TENANCY_OCID:-$(
  oci iam compartment list \
    --include-root \
    --compartment-id-in-subtree true \
    --access-level ANY \
    --all \
    --query 'data[?starts_with(id, `ocid1.tenancy.`)].id | [0]' \
    --raw-output
)}"

# Option 2 (configured local env): read tenancy OCID from ~/.oci/config (uses OCI_CLI_PROFILE or DEFAULT)
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

# Option 3: Set manually
# cat ~/.oci/config
# export TENANCY_OCID="ocid1.tenancy.oc1...."

echo "Your tenancy ocid is: '${TENANCY_OCID}'"
```

## Usage

```bash
# Build report/compartment_ids.txt (OCID<TAB>path)
./oci-tenancy-review compartments

# Build report/policy_statements.csv
./oci-tenancy-review policies

# Build compute inventory CSVs
./oci-tenancy-review compute

# Run all steps (compartments + policies + compute)
./oci-tenancy-review all
```

Notes:
- All outputs are written relative to current working directory under `report/`.
- `policies` and `compute` auto-generate compartment mapping if missing.
- Run `./oci-tenancy-review help` for command help.

## Tests

Bats tests are under `test/test_main.bats`.

```bash
bats test/test_main.bats
```
