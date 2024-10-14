#!/usr/bin/env bash

set -e
set -o pipefail

# This PoC
# - works just for 1 record currently
# - only partially works for records with multi-line fields
#
# TODO: commas and leading and trailing {}

to_hjson() {

cat "$1" | rg '^((Name|Version|Description|Architecture|URL|Licenses|Groups|Provides|Depends On|Optional Deps|Required By|Optional For|Conflicts With|Replaces|Installed Size|Packager|Build Date|Install Date|Install Reason|Install Script|Validated By)[ :]+(.+$))|(^[ ]{18}(.+$))' --replace '{"$2":"$3$5"}'

}

to_hjson data/sample
echo
to_hjson data/sample-multiline-field

