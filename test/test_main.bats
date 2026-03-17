#!/usr/bin/env bats

setup() {
  SCRIPT_PATH="$BATS_TEST_DIRNAME/../oci-tenancy-review"
  TMPDIR_TEST="$(mktemp -d)"
  export WORKDIR="$TMPDIR_TEST/work"
  mkdir -p "$WORKDIR"

  mkdir -p "$TMPDIR_TEST/bin"
  cat > "$TMPDIR_TEST/bin/oci" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

args="$*"

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

@test "compartments command writes sorted compartment_ids.txt" {
  cd "$WORKDIR"
  export TENANCY_OCID="ocid1.tenancy.oc1..tenancy"

  run "$SCRIPT_PATH" compartments
  [ "$status" -eq 0 ]

  [ -f report/compartment_ids.txt ]
  run cat report/compartment_ids.txt
  [ "$status" -eq 0 ]
  [[ "$output" == $'ocid1.tenancy.oc1..tenancy\troot\nocid1.compartment.oc1..child\tchild' ]]
}

@test "regions command writes report/regions.txt" {
  cd "$WORKDIR"
  export TENANCY_OCID="ocid1.tenancy.oc1..tenancy"

  run "$SCRIPT_PATH" regions
  [ "$status" -eq 0 ]
  [ -f report/regions.txt ]
  [[ "$output" == *"eu-frankfurt-1"* ]]
  [[ "$output" == *"eu-zurich-1"* ]]
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

  run "$SCRIPT_PATH" compute
  [ "$status" -eq 0 ]
  [[ "$output" == *"[WARN] Skipping unreachable region: eu-mars-1"* ]]
}

@test "verbose mode enables bash xtrace output" {
  cd "$WORKDIR"
  export TENANCY_OCID="ocid1.tenancy.oc1..tenancy"

  run "$SCRIPT_PATH" compute --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *"+ oci iam region-subscription list --tenancy-id ocid1.tenancy.oc1..tenancy --all --output json"* ]]
}
