class_name InteractionEffect
extends MeshInstance3D

## How long the stamp persists before being freed.
@export var duration: float = 8.0
## Final scale when fading out.
@export var end_scale: float = 1.0
## Opacity curve over lifetime (0→1 normalized time).
@export var alpha_over_life: Curve

var _current_time: float = 0.0
var _origin_scale: Vector3


func _ready() -> void:
	_origin_scale = scale
	if _origin_scale.is_zero_approx():
		_origin_scale = Vector3.ONE * 0.001


func _process(delta: float) -> void:
	_current_time += delta
	if _current_time >= duration:
		queue_free()
		return

	var t := _current_time / duration
	if alpha_over_life:
		set_instance_shader_parameter("stamp_opacity", alpha_over_life.sample(t))
	else:
		# Default: hold full opacity then fade out in last 30%
		var fade := _smoothstep(1.0, 0.7, t)
		set_instance_shader_parameter("stamp_opacity", fade)
	scale = _origin_scale.lerp(Vector3.ONE * end_scale, t)


static func _smoothstep(edge0: float, edge1: float, x: float) -> float:
	var c := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)
