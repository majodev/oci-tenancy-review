#!/usr/bin/env bats

setup() {
  SCRIPT_PATH="$BATS_TEST_DIRNAME/../oci-tenancy-review"
  TMPDIR_TEST="$(mktemp -d)"
  export WORKDIR="$TMPDIR_TEST/work"
  mkdir -p "$WORKDIR"
  export OCI_TEST_THROTTLE_STATE_FILE="$TMPDIR_TEST/oci_throttle_state"
  rm -f "$OCI_TEST_THROTTLE_STATE_FILE"

  mkdir -p "$TMPDIR_TEST/bin"
  cat > "$TMPDIR_TEST/bin/oci" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

args="$*"

if [[ -n "${OCI_TEST_THROTTLE_ONCE_PATTERN:-}" ]] && [[ "$args" == *"$OCI_TEST_THROTTLE_ONCE_PATTERN"* ]]; then
  if [[ ! -f "${OCI_TEST_THROTTLE_STATE_FILE:-}" ]]; then
    : > "${OCI_TEST_THROTTLE_STATE_FILE:-/tmp/oci_throttle_state}"
    echo "ServiceError: {'status': 429, 'code': 'TooManyRequests', 'message': 'Rate limit exceeded'}" >&2
    exit 1
  fi
fi

if [[ "$args" == iam\ compartment\ list* ]]; then
  cat <<'JSON'
{
  "data": [
    {
      "id": "ocid1.tenancy.oc1..tenancy",
      "name": "TENANCY",
      "compartment-id": "ocid1.tenancy.oc1..tenancy"
    },
    {
      "id": "ocid1.compartment.oc1..child",
      "name": "child",
      "compartment-id": "ocid1.tenancy.oc1..tenancy"
    }
  ]
}
JSON
  exit 0
fi

if [[ "$args" == iam\ region-subscription\ list* ]]; then
  cat <<'JSON'
{
  "data": [
    {"region-name": "eu-frankfurt-1"},
    {"region-name": "eu-zurich-1"},
    {"region-name": "eu-kragujevac-1"}
  ]
}
JSON
  exit 0
fi

if [[ "$args" == iam\ availability-domain\ list* ]]; then
  if [[ "$args" == *"--region eu-frankfurt-1"* || "$args" == *"--region eu-zurich-1"* ]]; then
    cat <<'JSON'
{"data":[{"name":"AD-1"}]}
JSON
    exit 0
  fi
  echo '{"code":"NotAuthorizedOrNotFound"}' >&2
  exit 1
fi

if [[ "$args" == limits\ service\ list* ]]; then
  cat <<'JSON'
{
  "data": [
    {"name": "compute"},
    {"name": "block-storage"}
  ]
}
JSON
  exit 0
fi

if [[ "$args" == limits\ value\ list* ]]; then
  if [[ "$args" == *"--service-name compute"* ]]; then
    cat <<'JSON'
{
  "data": [
    {
      "name": "standard-e4-core-count",
      "scope-type": "REGION",
      "value": 10
    }
  ]
}
JSON
  else
    cat <<'JSON'
{
  "data": [
    {
      "name": "total-storage-gb",
      "scope-type": "REGION",
      "value": 100
    }
  ]
}
JSON
  fi
  exit 0
fi

if [[ "$args" == limits\ resource-availability\ get* ]]; then
  if [[ "$args" == *"--service-name compute"* ]]; then
    cat <<'JSON'
{
  "data": {
    "used": 9,
    "available": 1
  }
}
JSON
  else
    cat <<'JSON'
{
  "data": {
    "used": 20,
    "available": 80
  }
}
JSON
  fi
  exit 0
fi

if [[ "$args" == search\ resource\ structured-search*"query policy resources"* ]]; then
  cat <<'JSON'
{
  "data": [
    {
      "compartment-id": "ocid1.compartment.oc1..child"
    }
  ]
}
JSON
  exit 0
fi

if [[ "$args" == search\ resource\ structured-search*"query instance resources"* ]]; then
  cat <<'JSON'
{
  "data": [
    {
      "compartment-id": "ocid1.compartment.oc1..child"
    }
  ]
}
JSON
  exit 0
fi

if [[ "$args" == search\ resource\ structured-search*"query volume resources"* ]]; then
  cat <<'JSON'
{
  "data": [
    {
      "compartment-id": "ocid1.compartment.oc1..child"
    }
  ]
}
JSON
  exit 0
fi

if [[ "$args" == search\ resource\ structured-search*"query bootvolume resources"* ]]; then
  cat <<'JSON'
{
  "data": [
    {
      "compartment-id": "ocid1.compartment.oc1..child"
    }
  ]
}
JSON
  exit 0
fi

if [[ "$args" == iam\ policy\ list* ]]; then
  if [[ "$args" == *"ocid1.compartment.oc1..child"* ]]; then
    cat <<'JSON'
{
  "data": [
    {
      "id": "ocid1.policy.oc1..p1",
      "name": "policy-child",
      "time-created": "2026-01-01T00:00:00+00:00",
      "defined-tags": {
        "Oracle-Tags": {
          "CreatedBy": "tester@example.com"
        }
      },
      "statements": [
        "Allow group Devs to inspect all-resources in compartment child"
      ]
    }
  ]
}
JSON
  else
    echo '{"data": []}'
  fi
  exit 0
fi

if [[ "$args" == compute\ instance\ list* ]]; then
  if [[ "$args" == *"ocid1.compartment.oc1..child"* ]]; then
    cat <<'JSON'
{
  "data": [
    {
      "id": "ocid1.instance.oc1..i1",
      "display-name": "app-01",
      "shape": "VM.Standard.E4.Flex",
      "shape-config": {
        "ocpus": 2,
        "memory-in-gbs": 16,
        "baseline-ocpu-utilization": "BASELINE_1_2"
      },
      "lifecycle-state": "RUNNING",
      "availability-domain": "kIdk:EU-FRANKFURT-1-AD-1",
      "fault-domain": "FAULT-DOMAIN-1",
      "image-id": "ocid1.image.oc1..img1",
      "launch-mode": "PARAVIRTUALIZED",
      "source-details": {"source-type": "image"},
      "capacity-reservation-id": null,
      "dedicated-vm-host-id": null,
      "preemptible-instance-config": null,
      "availability-config": {"recovery-action": "RESTORE_INSTANCE"},
      "instance-options": {"are-legacy-imds-endpoints-disabled": true},
      "launch-options": {
        "network-type": "VFIO",
        "is-consistent-volume-naming-enabled": true
      },
      "agent-config": {
        "is-monitoring-disabled": false,
        "is-management-disabled": false
      },
      "is-live-migration-preferred": true,
      "is-pv-encryption-in-transit-enabled": true,
      "metadata": {"ssh_authorized_keys": "x"},
      "freeform-tags": {"owner": "app"},
      "defined-tags": {"Operations": {"CostCenter": "123"}},
      "time-created": "2026-01-02T00:00:00+00:00",
      "region": "eu-frankfurt-1"
    }
  ]
}
JSON
  else
    echo '{"data": []}'
  fi
  exit 0
fi

if [[ "$args" == bv\ volume\ list* ]]; then
  cat <<'JSON'
{
  "data": [
    {
      "id": "ocid1.volume.oc1..v1",
      "display-name": "data-vol-1",
      "lifecycle-state": "AVAILABLE",
      "availability-domain": "AD-1",
      "size-in-gbs": 200,
      "vpus-per-gb": 20,
      "is-auto-tune-enabled": true,
      "kms-key-id": "ocid1.key.oc1..k1",
      "backup-policy-id": "ocid1.volumebackuppolicy.oc1..p1",
      "freeform-tags": {"owner":"app"},
      "defined-tags": {"Operations":{"CostCenter":"123"}},
      "time-created": "2026-01-03T00:00:00+00:00"
    }
  ]
}
JSON
  exit 0
fi

if [[ "$args" == bv\ boot-volume\ list* ]]; then
  cat <<'JSON'
{
  "data": [
    {
      "id": "ocid1.bootvolume.oc1..b1",
      "display-name": "boot-vol-1",
      "lifecycle-state": "AVAILABLE",
      "availability-domain": "AD-1",
      "size-in-gbs": 50,
      "kms-key-id": null,
      "backup-policy-id": null,
      "freeform-tags": {},
      "defined-tags": {},
      "time-created": "2026-01-03T00:00:00+00:00"
    }
  ]
}
JSON
  exit 0
fi

if [[ "$args" == bv\ backup\ list* ]]; then
  cat <<'JSON'
{
  "data": [
    {
      "id": "ocid1.volumebackup.oc1..vb1",
      "volume-id": "ocid1.volume.oc1..v1",
      "time-created": "2026-01-04T00:00:00+00:00",
      "type": "INCREMENTAL",
      "lifecycle-state": "AVAILABLE"
    }
  ]
}
JSON
  exit 0
fi

if [[ "$args" == bv\ boot-volume-backup\ list* ]]; then
  cat <<'JSON'
{
  "data": [
    {
      "id": "ocid1.bootvolumebackup.oc1..bb1",
      "boot-volume-id": "ocid1.bootvolume.oc1..b1",
      "time-created": "2026-01-05T00:00:00+00:00",
      "type": "FULL",
      "lifecycle-state": "AVAILABLE"
    }
  ]
}
JSON
  exit 0
fi

if [[ "$args" == bv\ block-volume-replica\ list* ]]; then
  cat <<'JSON'
{
  "data": [
    {
      "id": "ocid1.blockvolumereplica.oc1..r1",
      "source-volume-id": "ocid1.volume.oc1..v1",
      "lifecycle-state": "AVAILABLE"
    }
  ]
}
JSON
  exit 0
fi

if [[ "$args" == bv\ boot-volume-replica\ list* ]]; then
  cat <<'JSON'
{
  "data": [
    {
      "id": "ocid1.bootvolumereplica.oc1..r1",
      "source-boot-volume-id": "ocid1.bootvolume.oc1..b1",
      "lifecycle-state": "AVAILABLE"
    }
  ]
}
JSON
  exit 0
fi

echo "Unhandled mock OCI command: $args" >&2
exit 1
MOCK
  chmod +x "$TMPDIR_TEST/bin/oci"

  export PATH="$TMPDIR_TEST/bin:$PATH"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

@test "fails when TENANCY_OCID is missing" {
  cd "$WORKDIR"
  run "$SCRIPT_PATH" compartments
  [ "$status" -ne 0 ]
  [[ "$output" == *"TENANCY_OCID is required"* ]]
}

@test "compartments command writes sorted compartments.csv" {
  cd "$WORKDIR"
  export TENANCY_OCID="ocid1.tenancy.oc1..tenancy"

  run "$SCRIPT_PATH" compartments
  [ "$status" -eq 0 ]

  [ -f report/compartments.csv ]
  run cat report/compartments.csv
  [ "$status" -eq 0 ]
  [[ "$output" == *"compartment-id,compartment-path"* ]]
  [[ "$output" == *"ocid1.tenancy.oc1..tenancy,root"* ]]
  [[ "$output" == *"ocid1.compartment.oc1..child,child"* ]]
}

@test "regions command writes report/regions.txt" {
  cd "$WORKDIR"
  export TENANCY_OCID="ocid1.tenancy.oc1..tenancy"

  run "$SCRIPT_PATH" regions
  [ "$status" -eq 0 ]
  [ -f report/regions.txt ]
  run cat report/regions.txt
  [ "$status" -eq 0 ]
  [[ "$output" == *"eu-frankfurt-1"* ]]
  [[ "$output" == *"eu-zurich-1"* ]]
  [[ "$output" != *"eu-kragujevac-1"* ]]
}

@test "policies command writes policy_statements.csv" {
  cd "$WORKDIR"
  export TENANCY_OCID="ocid1.tenancy.oc1..tenancy"

  run "$SCRIPT_PATH" policies
  [ "$status" -eq 0 ]

  [ -f report/policies/policy_statements.csv ]
  run cat report/policies/policy_statements.csv
  [ "$status" -eq 0 ]
  [[ "$output" == *"compartment-id,compartment-name,policy-name"* ]]
  [[ "$output" == *"ocid1.compartment.oc1..child"* ]]
  [[ "$output" == *"policy-child"* ]]
}

@test "limits command writes service_limits.csv" {
  cd "$WORKDIR"
  export TENANCY_OCID="ocid1.tenancy.oc1..tenancy"
  export OCI_REVIEW_REGIONS="eu-frankfurt-1"

  run "$SCRIPT_PATH" limits
  [ "$status" -eq 0 ]
  [ -f report/limits/service_limits.csv ]

  run cat report/limits/service_limits.csv
  [ "$status" -eq 0 ]
  [[ "$output" == *"region,service-name,limit-name,scope-type"* ]]
  [[ "$output" == *"eu-frankfurt-1,compute"* ]]
  [[ "$output" == *"eu-frankfurt-1,block-storage"* ]]
  [[ "$output" == *"compute"* ]]
}

@test "block-storage command writes storage_inventory.csv with dr fields" {
  cd "$WORKDIR"
  export TENANCY_OCID="ocid1.tenancy.oc1..tenancy"
  export OCI_REVIEW_REGIONS="eu-frankfurt-1"

  run "$SCRIPT_PATH" block-storage
  [ "$status" -eq 0 ]
  [ -f report/storage/storage_inventory.csv ]

  run cat report/storage/storage_inventory.csv
  [ "$status" -eq 0 ]
  [[ "$output" == *"region,compartment-path,kind,display-name"* ]]
  [[ "$output" == *"block-volume"* ]]
  [[ "$output" == *"boot-volume"* ]]
  [[ "$output" == *"\"YES\""* ]]
}

@test "compute command writes compute_instances.csv with shape and sizing" {
  cd "$WORKDIR"
  export TENANCY_OCID="ocid1.tenancy.oc1..tenancy"

  run "$SCRIPT_PATH" compute
  [ "$status" -eq 0 ]

  [ -f report/compute/compute_instances.csv ]
  run cat report/compute/compute_instances.csv
  [ "$status" -eq 0 ]
  [[ "$output" == *"instance-name,shape,ocpus,memory-in-gbs"* ]]
  [[ "$output" == *"app-01"* ]]
  [[ "$output" == *"VM.Standard.E4.Flex"* ]]
  [[ "$output" == *",2,16,"* ]]
}

@test "compute skips unreachable regions from OCI_REVIEW_REGIONS" {
  cd "$WORKDIR"
  export TENANCY_OCID="ocid1.tenancy.oc1..tenancy"
  export OCI_REVIEW_REGIONS="eu-frankfurt-1,eu-mars-1"
  rm -f report/regions.txt

  run "$SCRIPT_PATH" compute
  [ "$status" -eq 0 ]
  [[ "$output" == *"Skipping unreachable region: eu-mars-1"* ]]
}

@test "compute uses cached report/regions.txt automatically" {
  cd "$WORKDIR"
  export TENANCY_OCID="ocid1.tenancy.oc1..tenancy"
  mkdir -p report
  cat > report/regions.txt <<'EOF'
eu-zurich-1
EOF

  run "$SCRIPT_PATH" compute
  [ "$status" -eq 0 ]
  [[ "$output" == *"using cached target regions from report/regions.txt"* ]]
}

@test "compute-region writes region-scoped artifacts" {
  cd "$WORKDIR"
  export TENANCY_OCID="ocid1.tenancy.oc1..tenancy"

  run "$SCRIPT_PATH" compute-region eu-frankfurt-1
  [ "$status" -eq 0 ]
  [ -f report/compute/regions/eu-frankfurt-1/compute_instances.json ]
}

@test "makefile defines compartment-level fanout patterns" {
  cd "$BATS_TEST_DIRNAME/.."
  run make -pn all
  [ "$status" -eq 0 ]
  [[ "$output" == *"policy-compartment-%:"* ]]
  [[ "$output" == *"compute-compartment-%:"* ]]
  [[ "$output" == *"block-storage-compartment-%:"* ]]
}

@test "block-storage-region writes region-scoped artifacts" {
  cd "$WORKDIR"
  export TENANCY_OCID="ocid1.tenancy.oc1..tenancy"

  run "$SCRIPT_PATH" block-storage-region eu-frankfurt-1
  [ "$status" -eq 0 ]
  [ -f report/storage/regions/eu-frankfurt-1/storage_inventory_enriched.json ]
}

@test "DEBUG=true enables bash xtrace output" {
  cd "$WORKDIR"
  export TENANCY_OCID="ocid1.tenancy.oc1..tenancy"

  run env DEBUG=true "$SCRIPT_PATH" compute
  [ "$status" -eq 0 ]
  [[ "$output" == *"+ oci iam region-subscription list --tenancy-id ocid1.tenancy.oc1..tenancy --all --output json"* ]]
}

@test "compute retries once on OCI rate-limited error" {
  cd "$WORKDIR"
  export TENANCY_OCID="ocid1.tenancy.oc1..tenancy"
  export OCI_TEST_THROTTLE_ONCE_PATTERN="iam region-subscription list"

  run "$SCRIPT_PATH" compute
  [ "$status" -eq 0 ]
  [[ "$output" == *"rate-limited"* ]]
}

@test "make all declares dependency graph for parallel execution" {
  cd "$BATS_TEST_DIRNAME/.."

  [ -f Makefile ]

  run make -pn all
  [ "$status" -eq 0 ]
  [[ "$output" == *"all: compartments policies compute block-storage limits"* ]]
  [[ "$output" == *"policies: compartments"* ]]
  [[ "$output" == *"compute: compartments regions"* ]]
  [[ "$output" == *"compute-region-%:"* ]]
  [[ "$output" == *"block-storage: compartments regions"* ]]
  [[ "$output" == *"block-storage-region-%:"* ]]
  [[ "$output" == *"limits: compute block-storage"* ]]
  [[ "$output" == *"limits-region-%:"* ]]
}
