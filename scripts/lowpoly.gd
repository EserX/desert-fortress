extends RefCounted
## Helpers for the faceted low-poly look: converts primitive meshes to flat-shaded
## meshes and builds simple colored materials.


## Returns a flat-shaded copy of a convex primitive mesh (sphere, cylinder, box...).
## Every triangle gets its own face normal, pointing away from the mesh center.
static func flat(mesh: Mesh) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var center := Vector3.ZERO
	for v in verts:
		center += v
	center /= max(verts.size(), 1)
	if indices.is_empty():
		for i in verts.size():
			indices.append(i)
	for i in range(0, indices.size() - 2, 3):
		var a: Vector3 = verts[indices[i]]
		var b: Vector3 = verts[indices[i + 1]]
		var c: Vector3 = verts[indices[i + 2]]
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-10:
			continue  # degenerate triangle (sphere poles)
		n = n.normalized()
		var face_center := (a + b + c) / 3.0
		if n.dot(face_center - center) < 0.0:
			n = -n
		out_v.append_array([a, b, c])
		out_n.append_array([n, n, n])
	var new_arrays := []
	new_arrays.resize(Mesh.ARRAY_MAX)
	new_arrays[Mesh.ARRAY_VERTEX] = out_v
	new_arrays[Mesh.ARRAY_NORMAL] = out_n
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, new_arrays)
	return result


static func material(color: Color, roughness := 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m
