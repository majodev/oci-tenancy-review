# OCI Tenancy Review

This initiative should help our customers identify bottlenecks, gaps and future potentials running on OCI. 

- [OCI Tenancy Review](#oci-tenancy-review)
  - [Prerequisites](#prerequisites)
  - [1. Discovery + architecture walkthrough](#1-discovery--architecture-walkthrough)
  - [2. Availability \& resiliency assessment](#2-availability--resiliency-assessment)
  - [3. Architecture \& scalability review](#3-architecture--scalability-review)
    - [Policy Statements](#policy-statements)
  - [4. Readout + actionable plan](#4-readout--actionable-plan)


## Prerequisites

* [OCI CLI](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm), tested with v3.76.0
* [jq](https://github.com/jqlang/jq) (already installed in OCI cloud shell by default)

Scope note:
* `--compartment-id "$TENANCY_OCID"` targets the root compartment (tenancy) only.
* To cover all subcompartments, use `--compartment-id-in-subtree true` when a command supports it.
* If a command does not support subtree listing (for example `oci iam policy list`), iterate through all compartments.


## 1. Discovery + architecture walkthrough
> (current-state goals, workloads, constraints) - through Zoom

## 2. Availability & resiliency assessment
> (HA patterns, DR considerations, failure modes, backup/restore)

## 3. Architecture & scalability review
> (service choices, patterns, integration points, bottlenecks)

### Policy Statements

To review all policy statements tenancy-wide and format them as CSV, use the following.
This is especially useful to spot duplicate policies and ensure any leaf compartment is below 500 policy statements total.

```bash
# use tenancy OCID from current OCI CLI context by default (Cloud Shell friendly)
TENANCY_OCID="${TENANCY_OCID:-$(
  oci iam compartment list \
    --include-root \
    --compartment-id-in-subtree true \
    --access-level ANY \
    --all \
    --query 'data[?starts_with(id, `ocid1.tenancy.`)].id | [0]' \
    --raw-output
)}"

# fallback: read tenancy OCID from ~/.oci/config (uses OCI_CLI_PROFILE or DEFAULT)
OCI_PROFILE="${OCI_CLI_PROFILE:-DEFAULT}"
TENANCY_OCID="${TENANCY_OCID:-$(
  awk -v profile="$OCI_PROFILE" '
    $0=="[" profile "]" {in_profile=1; next}
    /^\[/ {in_profile=0}
    in_profile && $1 ~ /^tenancy[[:space:]]*=/ {
      sub(/^[^=]*=[[:space:]]*/, "", $0); print $0; exit
    }
  ' ~/.oci/config
)}"

# optional manual override
# cat ~/.oci/config
# TENANCY_OCID="ocid1.tenancy.oc1...."

echo "Current tenancy ocid: ${TENANCY_OCID}"

# output folder (relative to current working directory)
rm -rf report
mkdir report

# collect all compartments as: OCID<TAB>full.path (root + subtree)
oci iam compartment list \
  --compartment-id "$TENANCY_OCID" \
  --compartment-id-in-subtree true \
  --access-level ANY \
  --include-root \
  --all > report/compartments.json

jq -r --arg tenancy "$TENANCY_OCID" '
  .data as $d
  | ($d | map({key: .id, value: .}) | from_entries) as $m
  | def full_path($id):
      if $id == $tenancy then
        ""
      else
        (full_path($m[$id]."compartment-id")) as $p
        | if $p == "" then $m[$id].name else ($p + "." + $m[$id].name) end
      end;
    [ $d[] | {id: .id, path: (if .id == $tenancy then "root" else full_path(.id) end)} ]
  | sort_by(if .path == "root" then "" else .path end)
  | .[]
  | [.id, .path]
  | @tsv
' report/compartments.json > report/compartment_ids.txt

# pull policies per compartment into a single JSON file
echo "" > report/policies_all_compartments.jsonl
while read -r cid; do
  cname="$(grep -m1 "^${cid}"$'\t' report/compartment_ids.txt | cut -f2-)"
  echo "Getting policies in cid ${cid} ${cname}..."
  oci iam policy list -c "$cid" --all \
    | jq -c --arg cid "$cid" --arg cname "$cname" \
      '.data[] | {compartmentId:$cid, compartmentName:$cname, name:.name, id:.id, timeCreated:."time-created", definedTags:."defined-tags", statements:.statements}' \
    >> report/policies_all_compartments.jsonl
done < <(cut -f1 report/compartment_ids.txt)

jq -s '.' report/policies_all_compartments.jsonl > report/policies_all_compartments.json

# to csv, flattened by policy statement
jq -r '
  ["compartment-id","compartment-name","policy-name","created-by","time-created","the actual statement","id"],
  (.[] as $p | ($p.statements // [])[] |
    [$p.compartmentId, $p.compartmentName, $p.name, ($p.definedTags["Oracle-Tags"]["CreatedBy"] // ""), $p.timeCreated, ., $p.id]
  ) | @csv
' report/policies_all_compartments.json > report/policy_statements.csv
```

## 4. Readout + actionable plan 

> (findings, prioritized recommendations, quick wins vs. longer-term items)
