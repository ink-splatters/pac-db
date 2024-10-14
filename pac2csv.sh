#!/usr/bin/env bash

set -e
set -o pipefail

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
use_tabs=0

if [ "$3" = "--tsv" ]; then
    use_tabs=1
fi

temp="$(mktemp -d)"
trap 'rm -rf "$temp"' EXIT

bsdtar xf "$db" -C "$temp"
pushd "$temp" > /dev/null

if command -v fd >/dev/null 2>&1; then
    mapfile -t files < <(fd desc -t f)
else
    mapfile -t files < <(find . -name 'desc' -type f)
fi

sep=","
[ $use_tabs -eq 1 ] && sep=$'\t'

{
    # Extract and print the schema
    schema=()
    for file in "${files[@]}"; do
        while IFS= read -r line; do
            if [[ $line =~ ^%([^%]+)%$ ]]; then
                schema+=("${BASH_REMATCH[1]}")
            fi
        done < "$file"
    done
    schema=($(printf "%s\n" "${schema[@]}" | sort | uniq))

    # Print the header
    printf "%s\n" "${schema[*]}" | tr ' ' "$sep"
} > "$output"

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
    } >> "$output"
done

popd > /dev/null