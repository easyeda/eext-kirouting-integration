"""
Layer mapping between EasyEDA Pro and KiCad.
"""

EASYEDA_TO_KICAD_LAYER = {
    1: 'F.Cu',
    2: 'B.Cu',
    15: 'In1.Cu', 16: 'In2.Cu', 17: 'In3.Cu', 18: 'In4.Cu',
    19: 'In5.Cu', 20: 'In6.Cu', 21: 'In7.Cu', 22: 'In8.Cu',
    23: 'In9.Cu', 24: 'In10.Cu', 25: 'In11.Cu', 26: 'In12.Cu',
    27: 'In13.Cu', 28: 'In14.Cu', 29: 'In15.Cu', 30: 'In16.Cu',
    31: 'In17.Cu', 32: 'In18.Cu', 33: 'In19.Cu', 34: 'In20.Cu',
    35: 'In21.Cu', 36: 'In22.Cu', 37: 'In23.Cu', 38: 'In24.Cu',
    39: 'In25.Cu', 40: 'In26.Cu', 41: 'In27.Cu', 42: 'In28.Cu',
    43: 'In29.Cu', 44: 'In30.Cu',
}

KICAD_TO_EASYEDA_LAYER = {v: k for k, v in EASYEDA_TO_KICAD_LAYER.items()}


def easyeda_layer_to_kicad(layer_id: int) -> str:
    return EASYEDA_TO_KICAD_LAYER.get(layer_id, 'F.Cu')


def kicad_layer_to_easyeda(layer_name: str) -> int:
    return KICAD_TO_EASYEDA_LAYER.get(layer_name, 1)
