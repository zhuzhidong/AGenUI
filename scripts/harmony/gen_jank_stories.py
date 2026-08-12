#!/usr/bin/env python3
"""Generate A2UI Show/Jank structural-jank stories into resource + harmony rawfile."""
import json
import os

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RESOURCE_BASE = os.path.join(REPO, "playground", "resource", "stories", "A2UI Show", "Jank")
RAWFILE_BASE = os.path.join(
    REPO, "playground", "harmony", "entry", "src", "main", "resources",
    "rawfile", "stories", "A2UI Show", "Jank",
)

def write(name: str, payload: dict) -> None:
    for base in (RESOURCE_BASE, RAWFILE_BASE):
        d = os.path.join(base, name)
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, "updateComponents.json"), "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)

def massive_tree() -> dict:
    children = [f"t{i}" for i in range(500)]
    components = [{"id": "root", "component": "Column", "align": "stretch", "children": children}]
    components += [{"id": f"t{i}", "component": "Text", "text": f"Item {i}", "variant": "body"} for i in range(500)]
    return {"version": "v0.9", "updateComponents": {"surfaceId": "jank-massive", "components": components}}

def deep_nesting() -> dict:
    # 30 levels of nested Columns; level i references level i+1 (as "nest{i+1}")
    # plus 3 Text siblings. Root is "nest0" (id "root" alias handled by surface).
    ids_text = [f"d{i}-t{j}" for i in range(30) for j in range(3)]
    comps = []
    for i in range(30):
        child_ids = [f"d{i}-t0", f"d{i}-t1", f"d{i}-t2"]
        if i < 29:
            child_ids.append(f"nest{i+1}")
        comps.append({"id": "root" if i == 0 else f"nest{i}", "component": "Column", "children": child_ids})
    comps += [{"id": t, "component": "Text", "text": "deep", "variant": "body"} for t in ids_text]
    return {"version": "v0.9", "updateComponents": {"surfaceId": "jank-deep", "components": comps}}

def overdraw() -> dict:
    layers = [f"s{i}" for i in range(20)]
    components = [{"id": "root", "component": "Stack", "children": layers}]
    components += [{"id": f"s{i}", "component": "Column", "backgroundColor": "rgba(255,0,0,0.2)", "width": "100%", "height": "100%"} for i in range(20)]
    components.append({"id": "center", "component": "Text", "text": "OVERDRAW", "variant": "h1"})
    components[0]["children"].append("center")
    return {"version": "v0.9", "updateComponents": {"surfaceId": "jank-overdraw", "components": components}}

def huge_payload() -> dict:
    big = "x" * 200000
    components = [
        {"id": "root", "component": "Column", "children": ["big"]},
        {"id": "big", "component": "Text", "text": big, "variant": "body"},
    ]
    return {"version": "v0.9", "updateComponents": {"surfaceId": "jank-huge", "components": components}}

def main() -> None:
    write("MassiveTree", massive_tree())
    write("DeepNesting", deep_nesting())
    write("Overdraw", overdraw())
    write("HugePayload", huge_payload())
    print("generated 4 jank stories into resource + rawfile")

if __name__ == "__main__":
    main()
