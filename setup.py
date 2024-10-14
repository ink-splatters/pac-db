from setuptools import setup
from mypyc.build import mypycify

import subprocess
import cpuinfo


def get_polars() -> list[str]:
    info = cpuinfo.get_cpu_info()
    flags = info.get("flags", [])

    required_flags = {"avx2", "fma", "bmi1", "bmi2", "lzcnt", "movbe"}

    return ["polars"] if required_flags.issubset(flags) else ["polars-lts-cpu"]


setup(
    name="arch_parser",
    version="0.1",
    packages=["arch_parser"],
    ext_modules=mypycify(
        ["pac2csv.py"], opt_level="3", debug_level="0", strip_asserts=True
    ),
    install_requires=[
        "numpy",
        "zstandard",
        "click",
    ]
    + get_polars(),
    entry_points={
        "console_scripts": [
            "pac2csv = pac2csv:process_database",
        ],
    },
    zip_safe=False,
)
