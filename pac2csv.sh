#!/usr/bin/env bash

set -e
set -o pipefail

# FIXME: currently the script produces invalid CSV/TSV which cannot be read by `polars`
# due to invalid schema

print_usage() {
	echo "Converts pacman database (one of /var/lib/pacman/sync) to TSV format"
	echo ""
	echo "Usage:"
	echo "    $0 <db> <output.csv> [--tsv]"
	echo ""
	echo "Flags:"
	echo "    --tsv    Use \\t as separator"
}

if [ $# -lt 2 ]; then
	print_usage
	exit 1
fi

db="$1"
output="$2"
sep=","

[ "$3" = "--tsv" ] && {
	sep=$'\t'
	echo "Mode: tsv."
}

temp="$(mktemp -d)"
trap 'rm -rf "$temp"' EXIT

bsdtar xf "$db" -C "$temp"
echo Extracted "$db" to a temporary location.

if command -v fd >/dev/null 2>&1; then
	mapfile -t files < <(fd desc -t f "$temp")
else
	mapfile -t files < <(find "$temp" -name 'desc' -type f)
fi

echo Found "${#files[@]}" entries.

{
	# Extract and print the schema
	schema=()
	file=${files[0]}
	while IFS= read -r line; do
		if [[ $line =~ ^%([^%]+)%$ ]]; then
			schema+=("${BASH_REMATCH[1]}")
		fi
	done <"$file"
	schema=($(printf "%s\n" "${schema[@]}" | sort | uniq))

	# Print the header
	printf "%s\n" "${schema[*]}" | tr ' ' "$sep"
} >"$output"

echo "Schema:"
cat "$output"
echo

# Extract and print the values for each file
for file in "${files[@]}"; do
	declare -A values
	key=""
	while IFS= read -r line; do
		if [[ $line =~ ^%([^%]+)%$ ]]; then
			key=${BASH_REMATCH[1]}
		elif [[ -n $key ]]; then
			values[$key]="${values[$key]}${values[$key]:+ }$line"
		fi
	done < <(sed ':a;N;$!ba;s/\n\n/\n\0/g' "$file" | tr '\0' '\n')

	{
		for k in "${schema[@]}"; do
			printf "%s" "${values[$k]}"
			if [ "$k" != "${schema[-1]}" ]; then
				printf "$sep"
			fi
		done
		printf "\n"
	} >>"$output"
done

echo "Wrote $output."
