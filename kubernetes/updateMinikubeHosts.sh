#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="kube-system"
CONFIGMAP="coredns"
TMP_DIR="$(mktemp -d)"
BACKUP="${TMP_DIR}/Corefile.backup"
NEW_CORE="${TMP_DIR}/Corefile.new"
SNIPPET="${TMP_DIR}/hosts.snippet"
DATE_TAG="$(date +%Y%m%d-%H%M%S)"

echo "⏳ Getting minikube IP..."
MINIKUBE_IP="$(minikube ip)"
echo "   Detected IP: ${MINIKUBE_IP}"

# 1) Fetch current Corefile
echo "⏳ Fetching current CoreDNS Corefile..."
kubectl -n "${NAMESPACE}" get configmap "${CONFIGMAP}" -o jsonpath='{.data.Corefile}' > "${BACKUP}"

# 2) Build hosts snippet (between markers for idempotent updates)
#    We include: graphkb, ipr, pori, keycloak, redis, iprdevredis
#    plus iprdevredis.bcgsc.ca and all svc FQDN variants.
cat > "${SNIPPET}" <<'EOF'
# BEGIN custom hosts (copilot)
hosts {
__HOST_LINES__
    fallthrough
}
# END custom hosts (copilot)
EOF

# Build the host lines programmatically
declare -a BASES=("graphkb" "ipr" "pori" "keycloak" "redis" "iprdevredis")
declare -a SUFFIXES=("" ".default.svc.cluster.local" ".svc.cluster.local" ".cluster.local")

HOST_LINES=""
for name in "${BASES[@]}"; do
  for s in "${SUFFIXES[@]}"; do
    HOST_LINES+="    __IP__ ${name}${s}\n"
  done
done
# Extra external FQDN
HOST_LINES+="    __IP__ iprdevredis.bcgsc.ca\n"

# Substitute IP and inject host lines
HOST_LINES_ESCAPED="${HOST_LINES//\\/\\\\}"     # escape backslashes for sed safety
HOST_LINES_ESCAPED="${HOST_LINES_ESCAPED//\//\\/}" # escape slashes for sed safety
sed -e "s/__HOST_LINES__/${HOST_LINES_ESCAPED}/" -e "s/__IP__/${MINIKUBE_IP}/g" "${SNIPPET}" > "${SNIPPET}.filled"

# 3) Create new Corefile by inserting/replacing the snippet
#    Logic:
#     - If markers already exist, replace the block between them.
#     - Else, insert the block before the 'forward . /etc/resolv.conf' line in the main server.
if grep -q "# BEGIN custom hosts (copilot)" "${BACKUP}"; then
  echo "ℹ️  Updating existing custom hosts block..."
  awk -v RS= -v ORS="" '
    {
      gsub(/# BEGIN custom hosts \(copilot\)[\s\S]*?# END custom hosts \(copilot\)/,
           "###__COPILOT_SNIPPET__###")
      print
    }' "${BACKUP}" > "${NEW_CORE}"

  # Replace placeholder with actual snippet content
  SNIP_CONTENT="$(cat "${SNIPPET}.filled")"
  SNIP_CONTENT_ESCAPED="${SNIP_CONTENT//\\/\\\\}"
  SNIP_CONTENT_ESCAPED="${SNIP_CONTENT_ESCAPED//\//\\/}"
  sed -i "s/###__COPILOT_SNIPPET__###/${SNIP_CONTENT_ESCAPED}/" "${NEW_CORE}"
else
  echo "ℹ️  Inserting new custom hosts block..."
  # Try to insert before the 'forward . /etc/resolv.conf' line in the primary server block.
  # If not found, append at end of the first server block (.:53).
  if grep -q "forward \. /etc/resolv.conf" "${BACKUP}"; then
    awk -v add="$(sed 's/[&/\]/\\&/g' "${SNIPPET}.filled")" '
      BEGIN {added=0}
      {
        if (!added && $0 ~ /forward \. \/etc\/resolv\.conf/) {
          print add
          added=1
        }
        print
      }' "${BACKUP}" > "${NEW_CORE}"
  else
    # Fallback: insert after "kubernetes cluster.local" or at the top of block " .:53 {"
    if grep -q "kubernetes cluster\.local" "${BACKUP}"; then
      awk -v add="$(sed 's/[&/\]/\\&/g' "${SNIPPET}.filled")" '
        BEGIN {added=0}
        {
          print
          if (!added && $0 ~ /kubernetes cluster\.local/) {
            print add
            added=1
          }
        }' "${BACKUP}" > "${NEW_CORE}"
    else
      # Last resort: prepend to the first server block
      awk -v add="$(sed 's/[&/\]/\\&/g' "${SNIPPET}.filled")" '
        BEGIN {inblock=0; done=0}
        {
          if (!done && $0 ~ /^\.:53[[:space:]]*\{[[:space:]]*$/) {
            print
            print add
            done=1
          } else {
            print
          }
        }' "${BACKUP}" > "${NEW_CORE}"
    fi
  fi
fi

# 4) Keep a human-readable backup on disk as well (optional)
SAVE_DIR="./coredns-backups"
mkdir -p "${SAVE_DIR}"
cp "${BACKUP}" "${SAVE_DIR}/Corefile.${DATE_TAG}.bak"
echo "💾 Backup saved to ${SAVE_DIR}/Corefile.${DATE_TAG}.bak"

# 5) Apply updated ConfigMap
echo "🚀 Applying updated CoreDNS ConfigMap..."
kubectl -n "${NAMESPACE}" create configmap "${CONFIGMAP}" \
  --from-file=Corefile="${NEW_CORE}" \
  --dry-run=client -o yaml | kubectl apply -f -

# 6) Restart CoreDNS to pick up changes
echo "🔁 Restarting CoreDNS..."
kubectl -n "${NAMESPACE}" rollout restart deployment/coredns
kubectl -n "${NAMESPACE}" rollout status deployment/coredns

echo "✅ Done. Custom hosts are now served by CoreDNS:"
echo "   IP: ${MINIKUBE_IP}"