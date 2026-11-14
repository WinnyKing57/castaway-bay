extends SceneTree

func _init() -> void:
	var classes := ["Terrain3D", "Terrain3DData", "Terrain3DRegion", "Terrain3DAssets", "Terrain3DMaterial", "Terrain3DUtil", "Terrain3DTextureAsset", "Terrain3DMeshAsset"]
	for cn in classes:
		if not ClassDB.class_exists(cn):
			print("=== %s : NOT FOUND" % cn)
			continue
		print("=== %s ===" % cn)
		var methods := ClassDB.class_get_method_list(cn, true)
		var names := []
		for m in methods:
			names.append(str(m["name"]))
		names.sort()
		print("methods: ", ", ".join(names))
		var props := ClassDB.class_get_property_list(cn, true)
		var pnames := []
		for p in props:
			pnames.append("%s:%s" % [p["name"], p["type"]])
		pnames.sort()
		print("props: ", ", ".join(pnames))
		var consts := ClassDB.class_get_integer_constant_list(cn, true)
		var cvals := []
		for c in consts:
			cvals.append("%s=%s" % [c, ClassDB.class_get_integer_constant(cn, c)])
		cvals.sort()
		print("consts: ", ", ".join(cvals))
	quit()
