extends RefCounted

const DESIGN_REFERENCE_SIZE := Vector2(1280.0, 720.0)
const MIN_SCALE := 0.1
const MAX_SCALE := 8.0


static func factor(node: Node) -> float:
	if node == null or node.get_viewport() == null:
		return 1.0
	var viewport := node.get_viewport()
	var viewport_size := viewport.get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return 1.0
	return clampf(minf(viewport_size.x / DESIGN_REFERENCE_SIZE.x, viewport_size.y / DESIGN_REFERENCE_SIZE.y), MIN_SCALE, MAX_SCALE)


static func size(node: Node, base_size: Vector2) -> Vector2:
	return base_size * factor(node)


static func length(node: Node, base_length: float) -> float:
	return base_length * factor(node)


static func font_size(node: Node, base_size: int) -> int:
	return maxi(1, roundi(float(base_size) * factor(node)))


static func offsets(control: Control) -> Vector4:
	return Vector4(control.offset_left, control.offset_top, control.offset_right, control.offset_bottom)


static func set_scaled_offsets(control: Control, base_offsets: Vector4) -> void:
	var scale := factor(control)
	control.offset_left = base_offsets.x * scale
	control.offset_top = base_offsets.y * scale
	control.offset_right = base_offsets.z * scale
	control.offset_bottom = base_offsets.w * scale
