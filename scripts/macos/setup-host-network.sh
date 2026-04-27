#!/usr/bin/env bash
# scripts/macos/setup-host-network.sh — STUB
#
# This script's logic has moved to the epanahi.cloud repo as part of the
# MTG-renaming migration. It now lives in:
#
#   ~/Development/epanahi.cloud/provision/theros/02-network.sh
#   ~/Development/epanahi.cloud/provision/ravnica/02-network.sh
#
# Per-host TOML config moved to:
#
#   ~/Development/epanahi.cloud/hosts/<hostname>.toml
#
# To apply a host's network config, check out epanahi.cloud and run its
# provision script for the target role, or call the relevant 02-network.sh
# directly.

set -euo pipefail

cat >&2 <<'EOF'
[ERR] This script has been superseded. Its logic is now in the epanahi.cloud
      repository at:

        ~/Development/epanahi.cloud/provision/theros/02-network.sh
        ~/Development/epanahi.cloud/provision/ravnica/02-network.sh

      If you have not yet cloned epanahi.cloud:

        cd ~/Development
        git clone <your-epanahi.cloud-repo-url> epanahi.cloud
        cd epanahi.cloud
        bash bootstrap.sh             # auto-detects hostname, dispatches
        # or:
        bash provision/<role>/02-network.sh   # apply just the network bit

      See epanahi.cloud/docs/current-state.md for context.
EOF
exit 2
