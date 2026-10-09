"""Finds a node in a `uiautomator dump` by its text / content-desc.

Usage: python3 ci/ui_find.py ui.xml "Label"
Prints "left top right bottom" of the first matching node, or exits 1.
"""
import re
import sys
import xml.etree.ElementTree as ET

path, label = sys.argv[1], sys.argv[2]
try:
    root = ET.parse(path).getroot()
except Exception:
    sys.exit(1)
for node in root.iter("node"):
    names = [node.get("text") or "", node.get("content-desc") or ""]
    if any(n.strip() == label or n.strip().startswith(label + "\n") for n in names):
        m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.get("bounds", ""))
        if m:
            print(" ".join(m.groups()))
            sys.exit(0)
sys.exit(1)
