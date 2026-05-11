with open('D:/KICAD Routing-intergration/kicad-routing-bridge/src/index.ts', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Fix line 686 (index 685) - replace broken line
lines[685] = '\tconsole.log("[TIMING] total: " + (Date.now() - t_start) + "ms");\n'

with open('D:/KICAD Routing-intergration/kicad-routing-bridge/src/index.ts', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('OK: fixed broken timing line')
