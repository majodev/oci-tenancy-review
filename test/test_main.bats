#!/usr/bin/env bats

setup() {
  SCRIPT_PATH="$BATS_TEST_DIRNAME/../oci-tenancy-review"
  TMPDIR_TEST="$(mktemp -d)"
  export REAL_JQ="$(command -v jq)"
  export WORKDIR="$TMPDIR_TEST/work"
  mkdir -p "$WORKDIR"
  export OCI_TEST_THROTTLE_STATE_FILE="$TMPDIR_TEST/oci_throttle_state"
  export OCI_TEST_TIMEOUT_STATE_FILE="$TMPDIR_TEST/oci_timeout_state"
  rm -f "$OCI_TEST_THROTTLE_STATE_FILE"
  rm -f "$OCI_TEST_TIMEOUT_STATE_FILE"

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

if [[ -n "${OCI_TEST_TIMEOUT_ONCE_PATTERN:-}" ]] && [[ "$args" == *"$OCI_TEST_TIMEOUT_ONCE_PATTERN"* ]]; then
  if [[ ! -f "${OCI_TEST_TIMEOUT_STATE_FILE:-}" ]]; then
    : > "${OCI_TEST_TIMEOUT_STATE_FILE:-/tmp/oci_timeout_state}"
    cat >&2 <<'ERR'
RequestException:
{
    "client_version": "Oracle-PythonCLI/3.76.0",
    "message": "The connection to endpoint timed out.",
    "target_service": "CLI"
}
ERR
    exit 1
  fi
fi

if [[ "$args" == iam\ compartment\ list* ]]; then
  child_name="${OCI_TEST_CHILD_COMPARTMENT_NAME:-child}"
  cat <<JSON
{
  "data": [
    {
      "id": "ocid1.tenancy.oc1..tenancy",
      "name": "TENANCY",
      "compartment-id": "ocid1.tenancy.oc1..tenancy"
    },
    {
      "id": "ocid1.compartment.oc1..child",
      "name": "${child_name}",
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
    {"name": "block-storage"},
    {"name": "object-storage"}
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
  elif [[ "$args" == *"--service-name object-storage"* ]]; then
    cat <<'JSON'
{
  "data": [
    {
      "name": "bucket-count",
      "scope-type": "REGION",
      "availability-domain": "1000"
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
  elif [[ "$args" == *"--service-name object-storage"* ]]; then
    cat <<'JSON'
{
  "data": {
    "used": 123,
    "available": 877
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

if [[ "$args" == search\ resource\ structured-search*"query bucket resources"* ]]; then
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

if [[ "$args" == search\ resource\ structured-search*"query database resources"* ]]; then
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
      "description": "Policy for child compartment",
      "lifecycle-state": "ACTIVE",
      "time-created": "2026-01-01T00:00:00+00:00",
      "freeform-tags": {
        "owner": "sec"
      },
      "defined-tags": {
        "Oracle-Tags": {
          "CreatedBy": "tester@example.com"
        },
        "Operations": {
          "CostCenter": "123"
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
      "time-maintenance-reboot-due": "2026-02-01T00:00:00+00:00",
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
        "boot-volume-type": "PARAVIRTUALIZED",
        "firmware": "UEFI_64",
        "network-type": "VFIO",
        "remote-data-volume-type": "PARAVIRTUALIZED",
        "is-consistent-volume-naming-enabled": true
      },
      "agent-config": {
        "are-all-plugins-disabled": false,
        "is-monitoring-disabled": false,
        "is-management-disabled": false
      },
      "platform-config": {
        "type": "AMD_VM",
        "is-secure-boot-enabled": true,
        "is-trusted-platform-module-enabled": true,
        "is-measured-boot-enabled": true,
        "is-memory-encryption-enabled": true
      },
      "is-live-migration-preferred": true,
      "is-pv-encryption-in-transit-enabled": true,
      "metadata": {"ssh_authorized_keys": "x"},
      "extended-metadata": {"note":"test"},
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

if [[ "$args" == db\ database\ list* ]]; then
  cat <<'JSON'
{
  "data": [
    {
      "id": "ocid1.database.oc1..d1",
      "db-name": "APPDB",
      "db-unique-name": "APPDB_iad1",
      "db-workload": "OLTP",
      "db-version": "19c",
      "db-system-id": "ocid1.dbsystem.oc1..s1",
      "db-home-id": "ocid1.dbhome.oc1..h1",
      "vm-cluster-id": null,
      "cdb-name": "CDB1",
      "pdb-name": "PDB1",
      "lifecycle-state": "AVAILABLE",
      "lifecycle-details": "Primary DB",
      "character-set": "AL32UTF8",
      "ncharacter-set": "AL16UTF16",
      "is-cdb": true,
      "kms-key-id": "ocid1.key.oc1..kdb1",
      "kms-key-version-id": "ocid1.keyversion.oc1..kv1",
      "key-store-id": "ocid1.keystore.oc1..ks1",
      "key-store-wallet-name": "WLT1",
      "vault-id": "ocid1.vault.oc1..v1",
      "database-software-image-id": "ocid1.dbsoftwareimage.oc1..img1",
      "sid-prefix": "DB",
      "last-backup-timestamp": "2026-01-08T00:00:00+00:00",
      "last-failed-backup-timestamp": "2026-01-09T00:00:00+00:00",
      "last-backup-duration-in-seconds": 1234,
      "db-backup-config": {
        "auto-backup-enabled": true,
        "recovery-window-in-days": 7,
        "backup-destination-type": "NFS",
        "auto-full-backup-day": "SUNDAY"
      },
      "time-created": "2026-01-07T00:00:00+00:00",
      "freeform-tags": {"owner":"dba"},
      "defined-tags": {"Operations":{"CostCenter":"99"}}
    }
  ]
}
JSON
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
      "is-hydrated": true,
      "is-auto-tune-enabled": true,
      "auto-tuned-vpus-per-gb": 30,
      "autotune-policies": [{"autotune-type":"PERFORMANCE_BASED"}],
      "volume-group-id": "ocid1.volumegroup.oc1..vg1",
      "kms-key-id": "ocid1.key.oc1..k1",
      "backup-policy-id": "ocid1.volumebackuppolicy.oc1..p1",
      "block-volume-replicas": [
        {"availability-domain":"AD-2"}
      ],
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
      "vpus-per-gb": 10,
      "is-hydrated": false,
      "is-auto-tune-enabled": false,
      "auto-tuned-vpus-per-gb": null,
      "autotune-policies": [],
      "boot-volume-replicas": [],
      "volume-group-id": "ocid1.volumegroup.oc1..vg2",
      "kms-key-id": null,
      "image-id": "ocid1.image.oc1..img1",
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

if [[ "$args" == os\ ns\ get* ]]; then
  cat <<'JSON'
{
  "data": "mynamespace"
}
JSON
  exit 0
fi

if [[ "$args" == os\ bucket\ list* ]]; then
  cat <<'JSON'
{
  "data": [
    {
      "name": "bucket-a",
      "namespace": "mynamespace",
      "compartment-id": "ocid1.compartment.oc1..child",
      "created-by": "ocid1.user.oc1..u1",
      "time-created": "2026-01-06T00:00:00+00:00",
      "etag": "etag-1",
      "freeform-tags": {"owner":"team-a"},
      "defined-tags": {"Operations":{"CostCenter":"42"}}
    }
  ]
}
JSON
  exit 0
fi

if [[ "$args" == os\ bucket\ get* ]]; then
  cat <<'JSON'
{
  "data": {
    "id": "ocid1.bucket.oc1.eu-frankfurt-1..b1",
    "public-access-type": "NoPublicAccess",
    "storage-tier": "Standard",
    "object-events-enabled": false,
    "replication-enabled": true,
    "is-read-only": false,
    "versioning": "Enabled",
    "auto-tiering": "InfrequentAccess",
    "kms-key-id": "ocid1.key.oc1..k1",
    "approximate-count": 7,
    "approximate-size": 4096,
    "object-lifecycle-policy-etag": "olp-etag-1",
    "metadata": {
      "env": "dev"
    }
  }
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
  local normalized_output="${output//\"/}"
  [[ "$normalized_output" == *"compartment-id,compartment-path,statement-seq,policy-name,policy-statement,created-by,time-created,policy-lifecycle-state,policy-description,policy-freeform-tag-count,policy-defined-tag-namespace-count,id"* ]]
  [[ "$output" == *"ocid1.compartment.oc1..child"* ]]
  [[ "$output" == *"policy-child"* ]]
  [[ "$output" == *"\"policy-child\",\"Allow group Devs to inspect all-resources in compartment child\",\"tester@example.com\",\"2026-01-01T00:00:00+00:00\",\"ACTIVE\",\"Policy for child compartment\",1,2,\"ocid1.policy.oc1..p1\""* ]]
  [[ "$output" == *"ACTIVE"* ]]
  [[ "$output" == *"Policy for child compartment"* ]]
  [[ "$output" == *",1,2,"* ]]
}

@test "compartment path text is not passed as jq CLI argument" {
  cd "$WORKDIR"
  export TENANCY_OCID="ocid1.tenancy.oc1..tenancy"
  export REGIONS="eu-frankfurt-1"
  export OCI_TEST_CHILD_COMPARTMENT_NAME="blocked-word team"
  export OCI_TEST_FAIL_ON_JQ_ARG_PATTERN="blocked-word team"

  cat > "$TMPDIR_TEST/bin/jq" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ -n "${OCI_TEST_FAIL_ON_JQ_ARG_PATTERN:-}" ]]; then
  for arg in "$@"; do
    if [[ "$arg" == *"${OCI_TEST_FAIL_ON_JQ_ARG_PATTERN}"* ]]; then
      echo "blocked: jq arg contains forbidden pattern" >&2
      exit 99
    fi
  done
fi
exec "${REAL_JQ:?}" "$@"
EOF
  chmod +x "$TMPDIR_TEST/bin/jq"

  run "$SCRIPT_PATH" compute
  [ "$status" -eq 0 ]
}

@test "limits command writes service_limits.csv" {
  cd "$WORKDIR"
  export TENANCY_OCID="ocid1.tenancy.oc1..tenancy"
  export REGIONS="eu-frankfurt-1"

  run "$SCRIPT_PATH" limits
  [ "$status" -eq 0 ]
  [ -f report/limits/service_limits.csv ]
  [ -f report/limits/compute_limits.csv ]
  [ -f report/limits/block_storage_limits.csv ]
  [ -f report/limits/object_storage_limits.csv ]

  run cat report/limits/service_limits.csv
  [ "$status" -eq 0 ]
  local normalized_output="${output//\"/}"
  [[ "$normalized_output" == *"region,service-name,limit-name,scope-type,availability-domain,limit-value,used,available,usage-percent,id"* ]]
  [[ "$normalized_output" == *"eu-frankfurt-1,compute"* ]]
  [[ "$normalized_output" == *"eu-frankfurt-1,block-storage"* ]]
  [[ "$normalized_output" == *"eu-frankfurt-1,object-storage"* ]]
  [[ "$normalized_output" == *"standard-e4-core-count"* ]]
  [[ "$normalized_output" == *"bucket-count"* ]]
  [[ "$normalized_output" == *"eu-frankfurt-1,object-storage,bucket-count,REGION,,1000,123,877,12.3,eu-frankfurt-1:object-storage:REGION::bucket-count"* ]]
  [[ "$normalized_output" == *"eu-frankfurt-1:compute:REGION"* ]]
}

@test "block-storage command writes storage_inventory.csv with dr fields" {
  cd "$WORKDIR"
  export TENANCY_OCID="ocid1.tenancy.oc1..tenancy"
  export REGIONS="eu-frankfurt-1"

  run "$SCRIPT_PATH" block-storage
  [ "$status" -eq 0 ]
  [ -f report/storage/storage_inventory.csv ]

  run cat report/storage/storage_inventory.csv
  [ "$status" -eq 0 ]
  local normalized_output="${output//\"/}"
  [[ "$normalized_output" == *"compartment-id,compartment-path,region,kind,display-name"* ]]
  [[ "$output" == *"block-volume"* ]]
  [[ "$output" == *"boot-volume"* ]]
  [[ "$output" == *"\"YES\""* ]]
  [[ "$output" == *"ocid1.compartment.oc1..child"* ]]
  [[ "$output" == *"ocid1.volumegroup.oc1..vg1"* ]]
  [[ "$output" == *",true,30,1,"* ]]
  [[ "$output" == *"AD-2"* ]]
  [[ "$output" == *"ocid1.image.oc1..img1"* ]]
  [[ "$output" == *"ocid1.bootvolume.oc1..b1"* ]]
}

@test "compute command writes compute_instances.csv with shape and sizing" {
  cd "$WORKDIR"
  export TENANCY_OCID="ocid1.tenancy.oc1..tenancy"

  run "$SCRIPT_PATH" compute
  [ "$status" -eq 0 ]

  [ -f report/compute/compute_instances.csv ]
  run cat report/compute/compute_instances.csv
  [ "$status" -eq 0 ]
  local normalized_output="${output//\"/}"
  [[ "$normalized_output" == *"instance-name,shape,ocpus,memory-in-gbs"* ]]
  [[ "$output" == *"app-01"* ]]
  [[ "$output" == *"VM.Standard.E4.Flex"* ]]
  [[ "$output" == *",2,16,"* ]]
  [[ "$output" == *"time-maintenance-reboot-due"* ]]
  [[ "$output" == *"launch-boot-volume-type"* ]]
  [[ "$output" == *"platform-secure-boot-enabled"* ]]
  [[ "$output" == *"extended-metadata-key-count"* ]]
  [[ "$output" == *"2026-02-01T00:00:00+00:00"* ]]
  [[ "$output" == *"UEFI_64"* ]]
  [[ "$output" == *"AMD_VM"* ]]
  [[ "$output" == *",true,true,true,true,"* ]]
}

@test "compute skips unreachable regions from REGIONS" {
  cd "$WORKDIR"
  export TENANCY_OCID="ocid1.tenancy.oc1..tenancy"
  export REGIONS="eu-frankfurt-1,eu-mars-1"
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

@test "internal makefile command compartments works" {
  cd "$WORKDIR"
  export TENANCY_OCID="ocid1.tenancy.oc1..tenancy"

  run "$SCRIPT_PATH" compartments
  [ "$status" -eq 0 ]
  [ -f report/compartments.csv ]
}

@test "makefile defines compartment-level fanout patterns" {
  cd "$BATS_TEST_DIRNAME/.."
  run cat Makefile
  [ "$status" -eq 0 ]
  [[ "$output" == *"policy-compartment-%:"* ]]
  [[ "$output" == *"compute-compartment-%:"* ]]
  [[ "$output" == *"block-storage-compartment-%:"* ]]
  [[ "$output" == *"base-database-compartment-%:"* ]]
  [[ "$output" == *"object-storage-compartment-%:"* ]]
}

@test "block-storage-region writes region-scoped artifacts" {
  cd "$WORKDIR"
  export TENANCY_OCID="ocid1.tenancy.oc1..tenancy"

  run "$SCRIPT_PATH" block-storage-region eu-frankfurt-1
  [ "$status" -eq 0 ]
  [ -f report/storage/regions/eu-frankfurt-1/storage_inventory_enriched.json ]
}

@test "base-database command writes base_databases.csv" {
  cd "$WORKDIR"
  export TENANCY_OCID="ocid1.tenancy.oc1..tenancy"
  export REGIONS="eu-frankfurt-1"

  run "$SCRIPT_PATH" base-database
  [ "$status" -eq 0 ]
  [ -f report/base-database/base_databases.csv ]

  run cat report/base-database/base_databases.csv
  [ "$status" -eq 0 ]
  local normalized_output="${output//\"/}"
  [[ "$normalized_output" == *"compartment-id,compartment-path,region,db-name,db-unique-name,db-workload,db-version,db-system-id,db-home-id,vm-cluster-id,cdb-name,pdb-name,lifecycle-state,lifecycle-details,character-set,ncharacter-set,is-cdb,kms-key-id,kms-key-version-id,key-store-id,key-store-wallet-name,vault-id,database-software-image-id,sid-prefix,auto-backup-enabled,backup-recovery-window-in-days,backup-destination-type,auto-full-backup-day,last-backup-timestamp,last-failed-backup-timestamp,last-backup-duration-in-seconds,freeform-tag-count,defined-tag-namespace-count,time-created,id"* ]]
  [[ "$output" == *"\"ocid1.compartment.oc1..child\",\"child\",\"eu-frankfurt-1\",\"APPDB\",\"APPDB_iad1\",\"OLTP\",\"19c\",\"ocid1.dbsystem.oc1..s1\",\"ocid1.dbhome.oc1..h1\",\"\",\"CDB1\",\"PDB1\",\"AVAILABLE\",\"Primary DB\",\"AL32UTF8\",\"AL16UTF16\",true,\"ocid1.key.oc1..kdb1\",\"ocid1.keyversion.oc1..kv1\",\"ocid1.keystore.oc1..ks1\",\"WLT1\",\"ocid1.vault.oc1..v1\",\"ocid1.dbsoftwareimage.oc1..img1\",\"DB\",true,7,\"NFS\",\"SUNDAY\",\"2026-01-08T00:00:00+00:00\",\"2026-01-09T00:00:00+00:00\",1234,1,1,\"2026-01-07T00:00:00+00:00\",\"ocid1.database.oc1..d1\""* ]]
}

@test "object-storage command writes buckets_inventory.csv" {
  cd "$WORKDIR"
  export TENANCY_OCID="ocid1.tenancy.oc1..tenancy"
  export REGIONS="eu-frankfurt-1"

  run "$SCRIPT_PATH" object-storage
  [ "$status" -eq 0 ]
  [ -f report/object-storage/buckets_inventory.csv ]

  run cat report/object-storage/buckets_inventory.csv
  [ "$status" -eq 0 ]
  local normalized_output="${output//\"/}"
  [[ "$normalized_output" == *"compartment-id,compartment-path,region,namespace,bucket-name,bucket-created-by,time-created,etag,freeform-tag-count,defined-tag-namespace-count,freeform-tag-keys,defined-tag-namespaces,defined-tag-key-count,freeform-tags-json,defined-tags-json,bucket-id,public-access-type,storage-tier,object-events-enabled,replication-enabled,is-read-only,versioning,auto-tiering,kms-key-id,approximate-object-count,approximate-size-bytes,object-lifecycle-policy-etag,metadata-key-count,id"* ]]
  [[ "$output" == *"\"ocid1.compartment.oc1..child\",\"child\",\"eu-frankfurt-1\",\"mynamespace\",\"bucket-a\",\"ocid1.user.oc1..u1\",\"2026-01-06T00:00:00+00:00\",\"etag-1\",1,1,\"owner\",\"Operations\",1,\"{\"\"owner\"\":\"\"team-a\"\"}\",\"{\"\"Operations\"\":{\"\"CostCenter\"\":\"\"42\"\"}}\",\"ocid1.bucket.oc1.eu-frankfurt-1..b1\",\"NoPublicAccess\",\"Standard\",false,true,false,\"Enabled\",\"InfrequentAccess\",\"ocid1.key.oc1..k1\",7,4096,\"olp-etag-1\",1,\"ocid1.bucket.oc1.eu-frankfurt-1..b1\""* ]]
}

@test "DEBUG=true enables bash xtrace output" {
  cd "$WORKDIR"
  export TENANCY_OCID="ocid1.tenancy.oc1..tenancy"

  run env DEBUG=true "$SCRIPT_PATH" compute
  [ "$status" -eq 0 ]
  [[ "$output" == *"region-subscription"* ]]
  [[ "$output" == *"--tenancy-id"* ]]
  [[ "$output" == *"ocid1.tenancy.oc1..tenancy"* ]]
}

@test "compute retries once on OCI rate-limited error" {
  cd "$WORKDIR"
  export TENANCY_OCID="ocid1.tenancy.oc1..tenancy"
  export OCI_TEST_THROTTLE_ONCE_PATTERN="iam region-subscription list"

  run "$SCRIPT_PATH" compute
  [ "$status" -eq 0 ]
  [[ "$output" == *"rate-limited"* ]]
}

@test "compute retries once on OCI connection timeout error" {
  cd "$WORKDIR"
  export TENANCY_OCID="ocid1.tenancy.oc1..tenancy"
  export OCI_TEST_TIMEOUT_ONCE_PATTERN="iam region-subscription list"

  run "$SCRIPT_PATH" compute
  [ "$status" -eq 0 ]
  [[ "$output" == *"timed out"* ]]
}

@test "multi-command positional invocation is rejected" {
  cd "$WORKDIR"
  export TENANCY_OCID="ocid1.tenancy.oc1..tenancy"
  export REGIONS="eu-frankfurt-1"

  run "$SCRIPT_PATH" compute block-storage limits
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage: compute"* ]]
}

@test "all delegates to make with expected args" {
  cd "$WORKDIR"
  local make_log="$TMPDIR_TEST/make_args.log"
  cat > "$TMPDIR_TEST/bin/make" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "${MAKE_LOG:?}"
exit 0
EOF
  chmod +x "$TMPDIR_TEST/bin/make"
  export MAKE_LOG="$make_log"

  run "$SCRIPT_PATH" all
  [ "$status" -eq 0 ]
  run cat "$make_log"
  [ "$status" -eq 0 ]
  [[ "$output" == *"-j 4 --no-print-directory all"* ]]
}

@test "help describes one-command invocation and make usage externally" {
  cd "$WORKDIR"
  export TENANCY_OCID="ocid1.tenancy.oc1..tenancy"

  run "$SCRIPT_PATH" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"One command per invocation."* ]]
  [[ "$output" == *"The 'all' command delegates to Makefile parallel execution."* ]]
}

@test "compute writes runtime call log under report/run.log by default" {
  cd "$WORKDIR"
  export TENANCY_OCID="ocid1.tenancy.oc1..tenancy"
  export REGIONS="eu-frankfurt-1"

  run "$SCRIPT_PATH" compute
  [ "$status" -eq 0 ]
  [ -f report/run.log ]
  run cat report/run.log
  [ "$status" -eq 0 ]
  [[ "$output" == *$'command=compute\trc=0\toci '* ]]
  [[ "$output" == *"availability-domain"* ]]
  [[ "$output" == *"compute"* ]]
  [[ "$output" == *"instance"* ]]
}

@test "source contains no mutating OCI verbs" {
  cd "$BATS_TEST_DIRNAME/.."
  run bash -lc "if rg -n --pcre2 '\\boci\\b[^\\n]*\\b(create|update|delete|patch|put|remove|bulk-delete)\\b' oci-tenancy-review Makefile; then exit 1; fi"
  [ "$status" -eq 0 ]
}

@test "make all declares dependency graph for parallel execution" {
  cd "$BATS_TEST_DIRNAME/.."

  [ -f Makefile ]

  run cat Makefile
  [ "$status" -eq 0 ]
  [[ "$output" == *"all: \\"* ]]
  [[ "$output" == *"report/compartments.csv \\"* ]]
  [[ "$output" == *"report/policies/policy_statements.csv \\"* ]]
  [[ "$output" == *"report/compute/compute_instances.csv \\"* ]]
  [[ "$output" == *"report/compute/compute_shapes_summary.csv \\"* ]]
  [[ "$output" == *"report/storage/storage_inventory.csv \\"* ]]
  [[ "$output" == *"report/base-database/base_databases.csv \\"* ]]
  [[ "$output" == *"report/object-storage/buckets_inventory.csv \\"* ]]
  [[ "$output" == *"report/limits/compute_limits.csv \\"* ]]
  [[ "$output" == *"report/limits/block_storage_limits.csv \\"* ]]
  [[ "$output" == *"report/limits/object_storage_limits.csv \\"* ]]
  [[ "$output" == *"report/limits/service_limits.csv"* ]]
  [[ "$output" == *"report/compartments.csv:"* ]]
  [[ "$output" == *"report/regions.txt:"* ]]
  [[ "$output" == *"report/policies/policy_statements.csv: report/compartments.csv"* ]]
  [[ "$output" == *'report/policies/policy_statements.csv: report/compartments.csv $(REBUILD_DEPS)'* ]]
  [[ "$output" == *"compute: report/compute/compute_instances.csv report/compute/compute_shapes_summary.csv"* ]]
  [[ "$output" == *"report/compute/compute_instances.csv: report/compartments.csv report/regions.txt"* ]]
  [[ "$output" == *'report/compute/compute_instances.csv: report/compartments.csv report/regions.txt $(REBUILD_DEPS)'* ]]
  [[ "$output" == *"compute-region-%:"* ]]
  [[ "$output" == *"block-storage: report/storage/storage_inventory.csv"* ]]
  [[ "$output" == *"block-storage-region-%:"* ]]
  [[ "$output" == *"base-database: report/base-database/base_databases.csv"* ]]
  [[ "$output" == *"base-database-region-%:"* ]]
  [[ "$output" == *"object-storage: report/object-storage/buckets_inventory.csv"* ]]
  [[ "$output" == *"object-storage-region-%:"* ]]
  [[ "$output" == *"compute-limits: report/limits/compute_limits.csv"* ]]
  [[ "$output" == *"block-storage-limits: report/limits/block_storage_limits.csv"* ]]
  [[ "$output" == *"object-storage-limits: report/limits/object_storage_limits.csv"* ]]
  [[ "$output" == *"limits: report/limits/service_limits.csv"* ]]
  [[ "$output" == *"report/limits/service_limits.csv: report/limits/compute_limits.csv report/limits/block_storage_limits.csv report/limits/object_storage_limits.csv"* ]]
  [[ "$output" == *'report/limits/service_limits.csv: report/limits/compute_limits.csv report/limits/block_storage_limits.csv report/limits/object_storage_limits.csv $(REBUILD_DEPS)'* ]]
  [[ "$output" == *"limits-region-%:"* ]]
}
