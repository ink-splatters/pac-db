#!/usr/bin/env python

import polars as pl
import typing

RawItem = list[str]


def to_items(data: str) -> list[RawItem]:
    data.split("\n\n")


def collect[T](it: typing.Iterable[T]) -> list[T]:
    return [*it]


with open("dump", "r") as f:
    data = f.read()


items = to_items(data)
print(items)
