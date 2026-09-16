set -euo pipefail

USER_NAME="${1:-deployer}"
GROUP="${2:-nginx-team}"
NAMESPACE="${3:-nginx}"
EXPIRATION="${4:-2592000}" # 30 days. Signer may shorten to --cluster-signing-duration.
OUT_DIR="${OUT_DIR:-.}"

KEY="${OUT_DIR}/${USER_NAME}.key"
CSR="${OUT_DIR}/${USER_NAME}.csr"
CRT="${OUT_DIR}/${USER_NAME}.crt"

echo "==> Generating key and CSR for CN=${USER_NAME}, O=${GROUP}"
openssl genrsa -out "${KEY}" 3072
openssl req -new -key "${KEY}" -out "${CSR}" -subj "/CN=${USER_NAME}/O=${GROUP}"
openssl req -in "${CSR}" -noout -subject

echo "==> Submitting CertificateSigningRequest to the cluster"
# Replace any previous CSR object with the same name
kubectl delete csr "${USER_NAME}" --ignore-not-found
kubectl apply -f - <<YAML
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${USER_NAME}
spec:
  request: $(base64 <"${CSR}" | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: ${EXPIRATION}
  usages:
  - client auth
YAML

echo "==> Approving (admin action; the controller manager signs with the cluster CA)"
kubectl certificate approve "${USER_NAME}"

echo "==> Waiting for signed certificate"
for _ in $(seq 1 30); do
  CERT_B64="$(kubectl get csr "${USER_NAME}" -o jsonpath='{.status.certificate}')"
  [ -n "${CERT_B64}" ] && break
  sleep 1
done
[ -n "${CERT_B64:-}" ] || {
  echo "certificate not issued"
  exit 1
}
echo "${CERT_B64}" | base64 -d >"${CRT}"
openssl x509 -in "${CRT}" -noout -subject -issuer -dates

echo "==> Adding ${USER_NAME} to the current kubeconfig"
kubectl config set-credentials "${USER_NAME}" \
  --client-key="${KEY}" --client-certificate="${CRT}" --embed-certs=true
kubectl config set-context "${USER_NAME}" \
  --cluster=kubernetes --user="${USER_NAME}" --namespace="${NAMESPACE}"

echo "==> Verifying identity as seen by the API server"
kubectl --context "${USER_NAME}" auth whoami

echo
echo "Done. Next: kubectl apply -f namespace.yaml -f role.yaml -f rolebinding.yaml"
echo "Then:  kubectl --context ${USER_NAME} auth can-i --list"
