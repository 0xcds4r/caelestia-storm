#!/usr/bin/env python3
"""Generate a caelestia colour scheme from a single seed colour and apply it.

Used by the plugin system: a plugin only names a seed colour (and optionally a
mode/variant) and this script expands it into the full Material palette plus the
terminal/app colours, then applies it the same way `caelestia scheme set` does.
"""

from __future__ import annotations

import argparse
import json
import sys


def build_colours(seed: str, mode: str, variant: str, flavour: str) -> dict[str, str]:
    from caelestia.utils.material.generator import gen_scheme
    from materialyoucolor.hct import Hct

    seed = seed.strip().lstrip("#")
    if len(seed) != 6:
        raise SystemExit(f"invalid seed colour: {seed!r}")

    class Meta:
        pass

    Meta.mode = mode
    Meta.variant = variant
    Meta.flavour = flavour

    primary = Hct.from_int(int("0xFF" + seed, 16))
    return gen_scheme(Meta, primary)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", required=True, help="seed colour, e.g. #ff7a18")
    parser.add_argument("--mode", default="dark", choices=["dark", "light"])
    parser.add_argument("--variant", default="tonalspot")
    parser.add_argument("--flavour", default="default")
    parser.add_argument("--print", action="store_true", help="print the scheme as JSON instead of applying it")
    args = parser.parse_args()

    colours = build_colours(args.seed, args.mode, args.variant, args.flavour)

    # "dynamic" is the only name the CLI accepts that does not resolve to a scheme file
    # shipped in the (read-only) package, so plugin schemes reuse it.
    data = {
        "name": "dynamic",
        "flavour": args.flavour,
        "mode": args.mode,
        "variant": args.variant,
        "colours": colours,
    }

    if args.print:
        print(json.dumps(data))
        return

    from caelestia.utils.scheme import Scheme
    from caelestia.utils.theme import apply_colours

    scheme = Scheme(data)
    scheme.save()
    apply_colours(scheme.colours, scheme.mode)


if __name__ == "__main__":
    sys.exit(main())
