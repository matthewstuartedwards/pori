#!/usr/bin/env bash
# add-coredns-entries.sh
# Adds custom DNS host entries to the minikube CoreDNS ConfigMap.
#
# Usage:
#   ./add-coredns-entries.sh [OPTIONS]
#
# Options:
#   -f FILE    Load entries from a file (one "IP hostname" pair per line)
#   -e ENTRY   Add a single entry inline, e.g. -e "1.2.3.4 myservice.local"
#   -d         Dry-run: print the patched Corefile without applying it
#   -q         Quiet: suppress all output except errors
#   -h         Show this help
#
# File format example (lines starting with # are ignored):
#   192.168.1.10  api.internal
#   192.168.1.11  db.internal
#   10.0.0.5      redis.local cache.local   # multiple hostnames per IP

set -euo pipefail

usage() {
  grep '^#' "$0" | sed 's/^# \?//'
  exit 0
}
die() { echo "ERROR: $*" >&2; exit 1; }
require() {
  for cmd in "$@"; do
    command -v "$cmd" &>/dev/null || die "'$cmd' is required but not found in PATH."
  done
}

ENTRY_FILE=""
INLINE_ENTRIES=()
DRY_RUN=false
QUIET=false

while getopts ":f:e:dqh" opt; do
  case $opt in
    f) ENTRY_FILE="$OPTARG" ;;
    e) INLINE_ENTRIES+=("$OPTARG") ;;
    d) DRY_RUN=true ;;
    q) QUIET=true ;;
    h) usage ;;
    :) die "Option -$OPTARG requires an argument." ;;
    \?) die "Unknown option: -$OPTARG" ;;
  esac
done

log() { $QUIET || echo "$@"; }

[[ -z "$ENTRY_FILE" && ${#INLINE_ENTRIES[@]} -eq 0 ]] && \
  die "Provide at least one entry via -f FILE or -e 'IP hostname'."

require minikube python3

# ── Write entries to a temp file so Python can read them cleanly ──────────────

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

if [[ -n "$ENTRY_FILE" ]]; then
  [[ -f "$ENTRY_FILE" ]] || die "File not found: $ENTRY_FILE"
  cat "$ENTRY_FILE" >> "$TMPFILE"
  echo >> "$TMPFILE"
fi

for entry in "${INLINE_ENTRIES[@]}"; do
  echo "$entry" >> "$TMPFILE"
done

# ── Fetch current Corefile from ConfigMap ─────────────────────────────────────

log "→ Fetching current CoreDNS ConfigMap..."
COREFILE_TMP=$(mktemp)
trap 'rm -f "$TMPFILE" "$COREFILE_TMP"' EXIT

minikube kubectl -- get configmap coredns -n kube-system \
  -o jsonpath='{.data.Corefile}' > "$COREFILE_TMP" || \
  die "Failed to fetch CoreDNS ConfigMap. Is minikube running?"

# ── Delegate all text manipulation to Python ──────────────────────────────────

PATCHED_TMP=$(mktemp)
trap 'rm -f "$TMPFILE" "$COREFILE_TMP" "$PATCHED_TMP"' EXIT

python3 - "$TMPFILE" "$COREFILE_TMP" "$PATCHED_TMP" "$QUIET" <<'PYEOF'
import re, sys

entries_file  = sys.argv[1]
corefile_path = sys.argv[2]
output_path   = sys.argv[3]
quiet         = sys.argv[4].lower() == "true"

def parse_host_lines(lines):
    """Parse 'IP host1 host2' lines into an ordered dict: ip -> [hostnames]."""
    host_map = {}
    for line in lines:
        line = line.split('#', 1)[0].strip()
        if not line or line == "fallthrough":
            continue
        parts = line.split()
        if len(parts) < 2:
            if not quiet: print(f"WARNING: skipping malformed line: {line!r}", file=sys.stderr)
            continue
        ip, *names = parts
        host_map.setdefault(ip, []).extend(names)
    return host_map

# Read current Corefile
with open(corefile_path) as f:
    corefile = f.read()

# Extract existing hosts block entries (if any)
existing_host_map = {}
existing = re.search(r'([ \t]*)hosts \{([^}]*)\}', corefile, re.MULTILINE)
if existing:
    block_indent = existing.group(1)
    existing_host_map = parse_host_lines(existing.group(2).splitlines())
else:
    # Detect indentation from a nearby directive for consistent formatting
    indent_match = re.search(r'^([ \t]+)(forward|prometheus)', corefile, re.MULTILINE)
    block_indent = indent_match.group(1) if indent_match else "        "

# Parse new entries from file
new_host_map = {}
with open(entries_file) as f:
    new_host_map = parse_host_lines(f.readlines())

if not new_host_map:
    print("ERROR: no valid entries parsed", file=sys.stderr)
    sys.exit(1)

# Merge: existing entries first, new entries add or extend
merged = dict(existing_host_map)
added, updated = [], []
for ip, names in new_host_map.items():
    # Deduplicate hostnames for this IP
    existing_names = merged.get(ip, [])
    new_names = [n for n in names if n not in existing_names]
    if ip not in merged:
        added.append((ip, names))
        merged[ip] = names
    elif new_names:
        updated.append((ip, new_names))
        merged[ip] = existing_names + new_names
    else:
        if not quiet: print(f"  (skipping {ip} — all hostnames already present)", file=sys.stderr)

# Build the merged hosts { } block
entry_indent = block_indent + "  "
hosts_lines = [f"{block_indent}hosts {{"]
for ip, names in merged.items():
    hosts_lines.append(f"{entry_indent}{ip} {' '.join(names)}")
hosts_lines.append(f"{entry_indent}fallthrough")
hosts_lines.append(f"{block_indent}}}")
hosts_block = "\n".join(hosts_lines)

# Splice back into the Corefile
if existing:
    new_corefile = corefile[:existing.start()] + hosts_block + corefile[existing.end():]
else:
    new_corefile = re.sub(
        r'([ \t]*(forward|prometheus) )',
        hosts_block + "\n" + block_indent + r"\1",
        corefile,
        count=1,
    )

with open(output_path, 'w') as f:
    f.write(new_corefile)

# Summary
if added and not quiet:
    print("✓ New entries added:", file=sys.stderr)
    for ip, names in added:
        print(f"    {ip}  →  {' '.join(names)}", file=sys.stderr)
if updated and not quiet:
    print("✓ Existing IPs extended:", file=sys.stderr)
    for ip, names in updated:
        print(f"    {ip}  +  {' '.join(names)}", file=sys.stderr)
PYEOF

# ── Dry-run or apply ──────────────────────────────────────────────────────────

if $DRY_RUN; then
  echo ""
  echo "════════════════════════════════════════"
  echo "  DRY RUN — Corefile not applied"
  echo "════════════════════════════════════════"
  cat "$PATCHED_TMP"
  exit 0
fi

log "→ Applying patched ConfigMap..."
if $QUIET; then
  minikube kubectl -- create configmap coredns \
    -n kube-system \
    --from-file=Corefile="$PATCHED_TMP" \
    --dry-run=client -o yaml | minikube kubectl -- apply -f - > /dev/null 2>&1
else
  minikube kubectl -- create configmap coredns \
    -n kube-system \
    --from-file=Corefile="$PATCHED_TMP" \
    --dry-run=client -o yaml | minikube kubectl -- apply -f -
fi

log "→ Restarting CoreDNS pods..."
minikube kubectl -- rollout restart deployment coredns -n kube-system
if $QUIET; then
  minikube kubectl -- rollout status deployment coredns -n kube-system --timeout=60s > /dev/null 2>&1
else
  minikube kubectl -- rollout status deployment coredns -n kube-system --timeout=60s
fi

log ""
log "✓ All done."
