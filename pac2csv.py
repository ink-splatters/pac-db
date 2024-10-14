#!/usr/bin/env python

import os
import tarfile
import zstandard as zstd
import polars as pl
import tempfile
import shutil
import click
from typing import List, Dict


#def running_natively() -> bool:
#    # Check if the file is a compiled .so or .pyd file
#    return os.path.splitext(__file__)[1] in [".so", ".pyd"]
#
#
#if running_natively():
#    print("Running as native compiled code.")
#else:
#    print("Running as interpreted Python code.")


def detect_compression(filename: str) -> str:
    with open(filename, "rb") as f:
        magic_number = f.read(4)  # First 4 bytes are sufficient for zstd detection
    if magic_number.startswith(b"\xfd\x37\x7a\x58"):  # XZ format magic number
        return "xz"
    elif magic_number.startswith(b"\x28\xb5\x2f\xfd"):  # Zstandard format magic number
        return "zst"
    else:
        # Decode bytes to string safely if needed
        hex_magic_number = magic_number.hex()
        print(f"Unsupported magic number: {hex_magic_number}")
        raise ValueError("Unsupported compression format")


def extract_tarfile(filename: str, mode: str, extract_dir: str) -> List[str]:
    if mode == "xz":
        with tarfile.open(filename, "r:xz") as tar:
            tar.extractall(extract_dir)
            return tar.getnames()
    elif mode == "zst":
        dctx = zstd.ZstdDecompressor()
        with open(filename, "rb") as f:
            with dctx.stream_reader(f) as reader:
                with tarfile.open(fileobj=reader, mode="r:") as tar:
                    tar.extractall(extract_dir)
                    return tar.getnames()
    else:
        raise ValueError("Unsupported compression mode")


def parse_desc_file(filepath: str) -> Dict[str, str]:
    with open(filepath, "r") as f:
        content = f.read()
    sections = content.split("\n\n")
    data = {}
    for section in sections:
        lines = section.split("\n")
        if len(lines) > 1:
            key = lines[0].strip("%").strip()
            value = "\n".join(lines[1:])
            data[key] = value
    return data


@click.command()
@click.argument("input_db_file")
@click.argument("output_file")
@click.option("--tsv", is_flag=True, help="Output in TSV format instead of CSV")
def process_database(input_db_file: str, output_file: str, tsv: bool):
    compression = detect_compression(input_db_file)

    # Create a temporary directory
    temp_dir = tempfile.mkdtemp()
    try:
        packages = extract_tarfile(input_db_file, compression, temp_dir)

        records = []
        for package in packages:
            desc_path = os.path.join(temp_dir, package, "desc")
            if os.path.isfile(desc_path):
                data = parse_desc_file(desc_path)
                records.append(data)

        df = pl.DataFrame(records)

        if tsv:
            df.write_csv(output_file, separator="\t")
        else:
            df.write_csv(output_file)
    finally:
        # Clean up the temporary directory
        shutil.rmtree(temp_dir)


if __name__ == "__main__":
    process_database()
