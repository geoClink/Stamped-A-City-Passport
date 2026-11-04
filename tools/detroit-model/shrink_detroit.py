#!/usr/bin/env python3
"""Shrink the Detroit 3D model (detroit.usdz) for the Vision Pro asset pack.

The original model is about 352 MB. Almost all of that is the scene file
itself, stored as *text* USD (detroit.usda, about 329 MB). The textures are
only about 23 MB. So the steps, biggest win first, are:

1. Save the scene as *binary* USD (.usdc). Same data, about 4x smaller.
2. Swap each tree crown (a 162-vertex sphere) for a 42-vertex sphere of the
   same size. A crown is about 3 mm wide at the app's overview scale, so
   the extra detail can't be seen.
3. Delete faces that point straight down on buildings, sidewalks and roads.
   These are the bottoms of extruded shapes, which sit on or under the
   ground. The viewer always looks down at the city, so they are never seen.
4. Re-save the JPEG textures at quality 80 (only kept when smaller). Their
   resolution is NOT reduced, because the app lets you zoom in 10x.
5. Package everything with USD's own usdz writer, which keeps the archive
   uncompressed and 64-byte aligned the way RealityKit expects.

The input file is only read, never changed.

Usage (from the repo root, inside the venv described in README.md):
    python tools/detroit-model/shrink_detroit.py
    python tools/detroit-model/shrink_detroit.py --input path/to/detroit.usdz --output out.usdz
"""

import argparse
import shutil
import tempfile
import zipfile
from pathlib import Path

import numpy as np
import trimesh
from PIL import Image
from pxr import Sdf, Usd, UsdGeom, UsdUtils, Vt

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_INPUT = REPO_ROOT / "Packages" / "output" / "detroit.usdz"
DEFAULT_OUTPUT = REPO_ROOT / "tools" / "detroit-model" / "output" / "detroit.usdz"

# Meshes whose downward faces are always hidden (extruded shapes on the ground).
EXTRUDED_MESH_PREFIXES = ("buildings_", "sidewalks", "roads")
TREE_CROWNS_MESH = "tree_crowns"
# A face counts as "pointing down" when its normal is within about 8 degrees of -Y.
DOWNWARD_NORMAL_Y = -0.99


def megabytes(size_in_bytes: int) -> str:
    return f"{size_in_bytes / 1_000_000:.1f} MB"


# ---------------------------------------------------------------------------
# Primvar helpers: when faces or vertices are removed, every per-vertex,
# per-face or per-face-corner value (like texture coordinates) must be
# trimmed the same way, or the mesh breaks.
# ---------------------------------------------------------------------------

def trim_primvars(mesh: UsdGeom.Mesh, kept_vertices: np.ndarray, kept_faces: np.ndarray,
                  kept_corners: np.ndarray) -> None:
    """Keep only the primvar entries that belong to kept vertices, faces or corners."""
    keep_by_interpolation = {
        UsdGeom.Tokens.vertex: kept_vertices,
        UsdGeom.Tokens.varying: kept_vertices,
        UsdGeom.Tokens.uniform: kept_faces,
        UsdGeom.Tokens.faceVarying: kept_corners,
    }
    for primvar in UsdGeom.PrimvarsAPI(mesh.GetPrim()).GetPrimvarsWithAuthoredValues():
        keep = keep_by_interpolation.get(primvar.GetInterpolation())
        if keep is None:  # constant primvars apply to the whole mesh
            continue
        if primvar.IsIndexed():
            # Indexed primvars: trim the index list and leave the values alone.
            indices = np.array(primvar.GetIndicesAttr().Get())
            primvar.GetIndicesAttr().Set(Vt.IntArray.FromNumpy(indices[keep].astype(np.int32)))
        else:
            values = primvar.Get()
            value_type = type(values)
            trimmed = np.array(values)[keep]
            primvar.Set(value_type.FromNumpy(trimmed))


def remove_downward_faces(mesh: UsdGeom.Mesh) -> int:
    """Delete triangles that face straight down. Returns how many were removed."""
    counts = np.array(mesh.GetFaceVertexCountsAttr().Get())
    if not np.all(counts == 3):
        print(f"  skip {mesh.GetPath()}: not all triangles")
        return 0
    points = np.array(mesh.GetPointsAttr().Get(), dtype=np.float64)
    corners = np.array(mesh.GetFaceVertexIndicesAttr().Get())
    triangles = corners.reshape(-1, 3)

    # Face normal = cross product of two edges. The sign follows the winding
    # order, so check which way the mesh winds first.
    edge_a = points[triangles[:, 1]] - points[triangles[:, 0]]
    edge_b = points[triangles[:, 2]] - points[triangles[:, 0]]
    normals = np.cross(edge_a, edge_b)
    lengths = np.linalg.norm(normals, axis=1)
    lengths[lengths == 0] = 1
    normals_y = normals[:, 1] / lengths
    if mesh.GetOrientationAttr().Get() == UsdGeom.Tokens.leftHanded:
        normals_y = -normals_y

    kept_faces = normals_y > DOWNWARD_NORMAL_Y
    removed = int((~kept_faces).sum())
    if removed == 0:
        return 0

    # Drop the vertices that no kept face uses anymore, and renumber the rest.
    kept_triangles = triangles[kept_faces]
    kept_vertices = np.zeros(len(points), dtype=bool)
    kept_vertices[kept_triangles.ravel()] = True
    new_index = np.cumsum(kept_vertices) - 1

    kept_corners = np.repeat(kept_faces, 3)
    trim_primvars(mesh, kept_vertices, kept_faces, kept_corners)
    mesh.GetPointsAttr().Set(Vt.Vec3fArray.FromNumpy(points[kept_vertices].astype(np.float32)))
    mesh.GetFaceVertexIndicesAttr().Set(
        Vt.IntArray.FromNumpy(new_index[kept_triangles].ravel().astype(np.int32)))
    mesh.GetFaceVertexCountsAttr().Set(Vt.IntArray.FromNumpy(counts[kept_faces].astype(np.int32)))
    update_extent(mesh)
    return removed


def simplify_tree_crowns(mesh: UsdGeom.Mesh) -> None:
    """Replace every tree-crown sphere with a lower-detail sphere of the same size."""
    prim = mesh.GetPrim()
    per_vertex = [p for p in UsdGeom.PrimvarsAPI(prim).GetPrimvarsWithAuthoredValues()
                  if p.GetInterpolation() != UsdGeom.Tokens.constant]
    if per_vertex:
        print(f"  skip {mesh.GetPath()}: has per-vertex data we would lose")
        return

    points = np.array(mesh.GetPointsAttr().Get(), dtype=np.float64)
    triangles = np.array(mesh.GetFaceVertexIndicesAttr().Get()).reshape(-1, 3)
    crowns = trimesh.Trimesh(vertices=points, faces=triangles, process=False).split(only_watertight=False)

    # A unit sphere with 42 vertices and 80 triangles (the original has 162 / 320).
    small_sphere = trimesh.creation.icosphere(subdivisions=1, radius=1.0)
    new_points = []
    new_triangles = []
    vertex_offset = 0
    for crown in crowns:
        low, high = crown.bounds
        center = (low + high) / 2
        half_size = (high - low) / 2  # per axis, so slightly squashed crowns stay squashed
        new_points.append(small_sphere.vertices * half_size + center)
        new_triangles.append(small_sphere.faces + vertex_offset)
        vertex_offset += len(small_sphere.vertices)

    all_points = np.concatenate(new_points).astype(np.float32)
    all_triangles = np.concatenate(new_triangles).astype(np.int32)
    # trimesh winds counter-clockwise (right-handed), which is USD's default.
    mesh.GetOrientationAttr().Set(UsdGeom.Tokens.rightHanded)
    mesh.GetPointsAttr().Set(Vt.Vec3fArray.FromNumpy(all_points))
    mesh.GetFaceVertexIndicesAttr().Set(Vt.IntArray.FromNumpy(all_triangles.ravel()))
    mesh.GetFaceVertexCountsAttr().Set(Vt.IntArray.FromNumpy(np.full(len(all_triangles), 3, dtype=np.int32)))
    update_extent(mesh)
    print(f"  {mesh.GetPath()}: {len(crowns)} crowns, {len(points)} -> {len(all_points)} vertices")


def update_extent(mesh: UsdGeom.Mesh) -> None:
    """Recompute the bounding box after changing the points."""
    extent = UsdGeom.Boundable.ComputeExtentFromPlugins(mesh, Usd.TimeCode.Default())
    if extent:
        mesh.GetExtentAttr().Set(extent)


def index_face_varying_primvars(mesh: UsdGeom.Mesh) -> None:
    """Store repeated per-corner values (texture coordinates) once, plus a small index list.

    The wall texture coordinates repeat a lot, so "unique values + indices"
    is much smaller than one value per triangle corner. USD and RealityKit
    read both forms the same way.
    """
    for primvar in UsdGeom.PrimvarsAPI(mesh.GetPrim()).GetPrimvarsWithAuthoredValues():
        if primvar.GetInterpolation() != UsdGeom.Tokens.faceVarying or primvar.IsIndexed():
            continue
        values = primvar.Get()
        value_type = type(values)
        as_array = np.array(values)
        unique_values, indices = np.unique(as_array, axis=0, return_inverse=True)
        primvar.Set(value_type.FromNumpy(unique_values))
        primvar.SetIndices(Vt.IntArray.FromNumpy(indices.ravel().astype(np.int32)))


def shrink_geometry(stage: Usd.Stage) -> None:
    for prim in stage.Traverse():
        if not prim.IsA(UsdGeom.Mesh):
            continue
        mesh = UsdGeom.Mesh(prim)
        name = prim.GetName()
        if name == TREE_CROWNS_MESH:
            simplify_tree_crowns(mesh)
        elif name.startswith(EXTRUDED_MESH_PREFIXES):
            removed = remove_downward_faces(mesh)
            print(f"  {prim.GetPath()}: removed {removed} downward faces")
        index_face_varying_primvars(mesh)


def reencode_jpegs(folder: Path, quality: int) -> None:
    """Re-save each JPEG at the given quality, keeping the original if that isn't smaller."""
    before = after = 0
    for jpeg in sorted(folder.rglob("*.jpg")):
        original_size = jpeg.stat().st_size
        candidate = jpeg.with_suffix(".tmp.jpg")
        with Image.open(jpeg) as image:
            image.convert("RGB").save(candidate, "JPEG", quality=quality, optimize=True, progressive=False)
        if candidate.stat().st_size < original_size:
            candidate.replace(jpeg)
        else:
            candidate.unlink()
        before += original_size
        after += jpeg.stat().st_size
    print(f"  textures: {megabytes(before)} -> {megabytes(after)}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT, help="original detroit.usdz (read only)")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT, help="where to write the small usdz")
    parser.add_argument("--jpeg-quality", type=int, default=80, help="JPEG quality for textures (default 80)")
    args = parser.parse_args()

    if args.input.resolve() == args.output.resolve():
        raise SystemExit("Refusing to overwrite the input file. Pick a different --output.")

    with tempfile.TemporaryDirectory(prefix="shrink_detroit_") as work_folder:
        work = Path(work_folder)

        # 1. Unpack a copy of the usdz (a usdz is a zip file).
        print(f"Unpacking {args.input} ({megabytes(args.input.stat().st_size)})")
        with zipfile.ZipFile(args.input) as archive:
            archive.extractall(work)
        scene_files = [p for p in work.iterdir() if p.suffix in (".usda", ".usdc", ".usd")]
        if len(scene_files) != 1:
            raise SystemExit(f"Expected one scene file in the usdz, found {scene_files}")
        scene = scene_files[0]

        # 2 + 3. Lighter geometry.
        print("Simplifying geometry")
        stage = Usd.Stage.Open(str(scene))
        shrink_geometry(stage)

        # 1. Save as binary USD next to the textures, so relative paths like
        # @0/satellite_0_0.jpg@ still resolve.
        binary_scene = work / f"{scene.stem}.usdc"
        stage.GetRootLayer().Export(str(binary_scene))
        del stage
        if scene != binary_scene:
            scene.unlink()
        print(f"  binary scene: {megabytes(binary_scene.stat().st_size)}")

        # 4. Smaller textures.
        print("Re-encoding textures")
        reencode_jpegs(work, args.jpeg_quality)

        # 5. Package. CreateNewUsdzPackage writes an uncompressed, 64-byte
        # aligned zip and pulls in every texture the scene refers to.
        args.output.parent.mkdir(parents=True, exist_ok=True)
        temporary_output = work / "packaged.usdz"
        if not UsdUtils.CreateNewUsdzPackage(Sdf.AssetPath(str(binary_scene)), str(temporary_output)):
            raise SystemExit("usdz packaging failed")
        shutil.move(temporary_output, args.output)

    print(f"Done: {args.output} ({megabytes(args.output.stat().st_size)})")


if __name__ == "__main__":
    main()
