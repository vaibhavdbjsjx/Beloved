#!/bin/sh
# Build phase "Validate release readiness" (app target).
#
# 1. Identity: archives (App Store / TestFlight) must never ship placeholder identifiers.
# 2. Content: archives must not ship a faith choice that would show no content. Release
#    builds show only approved, rights-cleared items (ContentPolicy.release).
# 3. Configuration: release builds must be the production environment, must not point at
#    a network endpoint the privacy policy doesn't disclose, and links must be HTTPS.
#
# Unsigned Debug compile checks are silent; Release and signed builds warn; archives fail.

fail_or_warn() {
  if [ "${ACTION}" = "install" ]; then
    echo "error: $1"
    status=1
  elif [ "${CONFIGURATION}" = "Release" ] || [ "${CODE_SIGNING_ALLOWED}" != "NO" ]; then
    echo "warning: $1"
  fi
}

status=0

case "${PL_BUNDLE_ID_PREFIX}" in
  ""|unconfigured.*|com.example.*|com.yourcompany.*) placeholder=1 ;;
  *) placeholder=0 ;;
esac
[ -z "${DEVELOPMENT_TEAM}" ] && placeholder=1
if [ "$placeholder" = 1 ]; then
  fail_or_warn "Beloved identity is not configured: set PL_BUNDLE_ID_PREFIX and DEVELOPMENT_TEAM in Config/Identity.xcconfig (docs/12-signing-setup.md)."
fi

if ! report=$(xcrun python3 "${SRCROOT}/Config/release-content-report.py" 2>&1); then
  fail_or_warn "Release content is incomplete — $(echo "${report}" | tr '\n' ';' ) Approve reviewed, rights-cleared content (docs/19-app-store-readiness.md §Content)."
fi

if [ "${CONFIGURATION}" = "Release" ] && [ "${PL_ENVIRONMENT}" != "production" ]; then
  fail_or_warn "Release builds must use PL_ENVIRONMENT = production (got '${PL_ENVIRONMENT}')."
fi

case "${PL_ASSISTANT_ENDPOINT}" in
  ""|https://*) ;;
  *) fail_or_warn "PL_ASSISTANT_ENDPOINT must be an https:// URL when set (got '${PL_ASSISTANT_ENDPOINT}')." ;;
esac

for key in PL_SUPPORT_URL PL_PRIVACY_POLICY_URL; do
  eval "url=\${${key}}"
  case "${url}" in
    ""|https://*) ;;
    *) fail_or_warn "${key} must be an https:// URL (got '${url}')." ;;
  esac
  case "${url}" in
    *example.com*|*example.org*|*.example/*|*your-domain*|*localhost*|*127.0.0.1*)
      fail_or_warn "${key} is a placeholder or local URL ('${url}')." ;;
  esac
done

exit ${status}
