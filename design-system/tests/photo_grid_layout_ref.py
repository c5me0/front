#!/usr/bin/env python3
"""Reference photo-grid packing and reflow geometry. Regenerates shared test vectors."""
import json, os

def layout(liked, columns=5):
    occ = set()
    def free(r, c): return (r, c) not in occ
    out = []
    prev = (0, 0)
    for is_liked in liked:
        if is_liked:
            r, c = prev
            while True:
                if c <= columns - 2 and free(r, c) and free(r, c + 1) and free(r + 1, c) and free(r + 1, c + 1):
                    break
                c += 1
                if c >= columns:
                    c = 0; r += 1
            for dr in (0, 1):
                for dc in (0, 1):
                    occ.add((r + dr, c + dc))
            out.append({"row": r, "col": c, "span": 2})
        else:
            r = c = 0
            while not free(r, c):
                c += 1
                if c >= columns:
                    c = 0; r += 1
            occ.add((r, c))
            out.append({"row": r, "col": c, "span": 1})
        prev = (out[-1]["row"], out[-1]["col"])
    rows = (max(r for r, _ in occ) + 1) if occ else 0
    return {"placements": out, "rows": rows}

def frames(result, columns, padding, gap, width):
    """Convert packed cells into pixel frames, including padding and gaps."""
    cell = max(0.0, (width - 2 * padding - (columns - 1) * gap) / columns)
    step = cell + gap
    out = []
    for p in result["placements"]:
        size = p["span"] * cell + (p["span"] - 1) * gap
        out.append({"x": padding + p["col"] * step, "y": padding + p["row"] * step, "w": size, "h": size})
    rows = result["rows"]
    content = rows * cell + (rows - 1) * gap if rows > 0 else 0.0
    return {"frames": out, "cellSize": cell, "contentHeight": content, "height": content + 2 * padding}

def lerp(a, b, t):
    """Interpolate frame components, retaining spring overshoot outside zero to one."""
    return {k: a[k] + (b[k] - a[k]) * t for k in ("x", "y", "w", "h")}

def contain_x(f, padding, width):
    """Clamp horizontal placement to content bounds without changing size or height."""
    x = max(padding, min(f["x"], width - padding - f["w"]))
    return {"x": x, "y": f["y"], "w": f["w"], "h": f["h"]}

def gangneung_initial():
    # Reference grid with two featured tiles; covered cells are excluded.
    hidden = {(0, 1), (1, 0), (1, 1), (3, 2), (4, 1), (4, 2)}
    seq = []
    for r in range(6):
        for c in range(5):
            if (r, c) in hidden: continue
            seq.append((r, c) in {(0, 0), (3, 1)})
    return seq

def main():
    g = gangneung_initial()
    cases = []
    def add(name, liked, columns=5):
        cases.append({"name": name, "columns": columns, "liked": liked, "expected": layout(liked, columns)})
    add("gangneung-figma-initial (24장, #1·#14 liked → A r0c0, B r3c1, 6행)", g)
    add("none-liked-30", [False] * 30)
    add("like-first", [True] + [False] * 29)
    add("like-last-column (#5)", [False] * 4 + [True] + [False] * 25)
    add("like-col4-row2 (#10)", [False] * 9 + [True] + [False] * 20)
    add("two-adjacent (#1,#2)", [True, True] + [False] * 28)
    add("near-end (#29)", [False] * 28 + [True, False])
    add("last-item-liked (#30)", [False] * 29 + [True])
    add("all-liked-3", [True, True, True])
    add("fixed-2-cells like #1", [True, False])
    add("fixed-2-cells like #2", [False, True])
    demo = list(g); demo[3] = True  # The demo favorites the fourth photo.
    add("gangneung-demo-like-#4", demo)
    demo2 = list(demo); demo2[8] = True
    add("gangneung-demo-like-#4-#9", demo2)
    exp = cases[0]["expected"]["placements"]
    assert exp[0] == {"row": 0, "col": 0, "span": 2} and exp[13] == {"row": 3, "col": 1, "span": 2}, exp[13]
    assert cases[0]["expected"]["rows"] == 6

    # Record token metrics in each vector so implementations can be tested independently.
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tokens.json")) as f:
        pg = json.load(f)["layout"]["photoGrid"]
    metrics = {
        "bordered": {"columns": pg["columns"], "padding": pg["padding"], "gap": pg["gap"]},
        "gangneung": {"columns": pg["columns"], "padding": pg["gangneung"]["padding"], "gap": pg["gangneung"]["gap"]},
    }
    frame_cases = []
    def add_frames(name, liked, variant, width):
        m = metrics[variant]
        res = layout(liked, m["columns"])
        frame_cases.append({"name": name, "variant": variant, "liked": liked, "metrics": m, "width": width,
                            "expected": frames(res, m["columns"], m["padding"], m["gap"], width)})
    add_frames("gangneung-figma-initial @393 (A 6,6 · B 82.6,235.8 · 151.2)", g, "gangneung", 393)
    add_frames("gangneung-demo-like-#4 @393", demo, "gangneung", 393)
    add_frames("bordered none-liked-30 @393", [False] * 30, "bordered", 393)
    add_frames("bordered like-last-column (#5) @393", [False] * 4 + [True] + [False] * 25, "bordered", 393)
    add_frames("bordered fixed-2-cells like #2 @393", [False, True], "bordered", 393)
    add_frames("bordered none-liked-2 @375", [False, False], "bordered", 375)
    add_frames("empty @393", [], "bordered", 393)
    add_frames("unmeasured width 0 → cell clamps to 0", [True, False], "gangneung", 0)
    fa = frame_cases[0]["expected"]
    assert abs(fa["frames"][13]["x"] - 82.6) < 1e-9 and abs(fa["frames"][13]["y"] - 235.8) < 1e-9, fa["frames"][13]
    assert abs(fa["frames"][0]["w"] - 151.2) < 1e-9 and abs(fa["cellSize"] - 74.6) < 1e-9

    # Clamp an interpolated reflow frame to the content width.
    # The first overshoot peak of the reflow spring is approximately fifteen percent.
    contain_cases = []
    def add_contain(name, before, after, index, variant, width, t):
        m = metrics[variant]
        a = frames(layout(before, m["columns"]), m["columns"], m["padding"], m["gap"], width)["frames"][index]
        b = frames(layout(after, m["columns"]), m["columns"], m["padding"], m["gap"], width)["frames"][index]
        contain_cases.append({"name": name, "variant": variant, "padding": m["padding"], "width": width, "t": t,
                              "a": a, "b": b, "expected": contain_x(lerp(a, b, t), m["padding"], width)})
    none30 = [False] * 30
    like5 = list(none30); like5[4] = True
    unlike4 = list(demo2); unlike4[3] = False
    like9 = list(demo); like9[8] = True
    add_contain("bordered like #5 (r0c4 → 2x2 r1c0) 오버슈트 → 왼쪽 가장자리 padding 에 멈춤", none30, like5, 4, "bordered", 393, 1.15)
    add_contain("gangneung like #9 (r2c4 → 2x2 r3c0) 오버슈트 → 왼쪽 가장자리", demo, like9, 8, "gangneung", 393, 1.15)
    add_contain("gangneung unlike #4 (2x2 r1c2 → r0c4) 오버슈트 → 오른쪽 가장자리 (w 는 그대로 외삽)", demo2, unlike4, 3, "gangneung", 393, 1.15)
    add_contain("bordered like #5 진행 중 t=0.5 → 박스 안이라 그대로", none30, like5, 4, "bordered", 393, 0.5)
    add_contain("bordered like #5 정착 t=1 → 목표 그대로", none30, like5, 4, "bordered", 393, 1.0)
    add_contain("bordered like #5 → #6 (r1c0 → 구멍 r0c4) 오버슈트 → 오른쪽 가장자리", none30, like5, 5, "bordered", 393, 1.15)
    add_contain("bordered like #5 → #7 (r1c1 → r1c2) 오버슈트 → 박스 안이라 그대로", none30, like5, 6, "bordered", 393, 1.15)
    add_contain("unmeasured width 0 → padding (왼쪽 우선)", [True, False], [False, True], 0, "gangneung", 0, 1.15)
    ca = contain_cases[0]
    assert abs(ca["expected"]["x"] - metrics["bordered"]["padding"]) < 1e-12, ca
    cu = contain_cases[2]["expected"]
    assert abs(cu["x"] + cu["w"] - (393 - metrics["gangneung"]["padding"])) < 1e-9, cu

    out = {"$note": "사진 그리드 배치 규칙 교차 검증 벡터 — docs/interaction-spec.md §1. design-system/tests/photo_grid_layout_ref.py 가 생성 (Python 독립 구현). RN/Flutter 구현이 모두 통과해야 한다. cases = layoutPhotoGrid, frameCases = photoGridFrames, containCases = 리플로우 한 프레임 containPhotoGridFrameX(lerpPhotoGridFrame(a, b, t), padding, width) (metrics 는 생성 시점 tokens.json layout.photoGrid).",
           "tolerance": 1e-9,
           "cases": cases,
           "frameCases": frame_cases,
           "containCases": contain_cases}
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "photo-grid-layout.vectors.json")
    with open(path, "w") as f: json.dump(out, f, indent=1, ensure_ascii=False); f.write("\n")
    print("wrote", path, len(cases), "cases,", len(frame_cases), "frameCases,", len(contain_cases), "containCases; gangneung B =", exp[13])

if __name__ == "__main__":
    main()
