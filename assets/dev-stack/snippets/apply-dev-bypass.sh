#!/bin/sh
# Applies the dev-only license-key bypass to an IC4 source checkout.
#
# WHY: applications/core/modules/setup/install/license.php (and the ACP
# license + upgrade pages) call \IPS\IPS::checkLicenseKey(), which makes an
# HTTPS request to Invision's license server. A dev stack without internet
# access (or without a valid key) can never pass the install's license step.
#
# WHAT: inserts a guarded early-return into IPS\IPS::checkLicenseKey() in
# init.php that skips the license-server round trip ONLY when the IC4_DEV
# environment variable is set (it is, in this dev stack's php service) AND
# the request host is localhost/127.0.0.1/::1.
#
# Usage:  bash apply-dev-bypass.sh /path/to/invision-community
# Idempotent: re-running is a no-op when the marker is already present.
# Reversing:  grep -n HERMES-DEV-ONLY <path>/init.php   (remove the marked block)
set -eu
SRC="${1:?usage: $0 /path/to/invision-community}"
INIT="$SRC/init.php"
MARKER="HERMES-DEV-ONLY BYPASS"

[ -f "$INIT" ] || { echo "no init.php at $INIT" >&2; exit 1; }
grep -q "$MARKER" "$INIT" && { echo "bypass already present - nothing to do"; exit 0; }

python3 - "$INIT" <<'PY'
import sys
path = sys.argv[1]
src = open(path).read()
anchor = "public static function checkLicenseKey( $val, $url )"
i = src.find(anchor)
assert i >= 0, "checkLicenseKey() not found in init.php"
j = src.find("{", i)
assert j >= 0, "checkLicenseKey body not found"
bypass = """
		/*
		 * HERMES-DEV-ONLY BYPASS - dev-stack only (set IC4_DEV=1, localhost
		 * requests): skip the license-server round trip. Never remove this
		 * block outside a development install; never ship it upstream.
		 */
		if ( \\getenv( 'IC4_DEV' )
			&& in_array(
				isset( $_SERVER['HTTP_HOST'] ) ? preg_replace( '/:\\d+$/', '', $_SERVER['HTTP_HOST'] ) : '',
				array( 'localhost', '127.0.0.1', '::1' ),
				TRUE
			)
		)
		{
			return;
		}"""
src = src[:j+1] + bypass + src[j+1:]
open(path, "w").write(src)
print("bypass applied to", path)
PY
