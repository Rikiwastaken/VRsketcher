extends Area
class_name VRToolItem

export(int) var target_tool_index : int = 0;
export(Texture) var tool_icon : Texture = null;

var base_blink_speed : float = 1.0;

onready var icon_material : ShaderMaterial = load("res://materials/vr_tool_item.tres").duplicate();

func _ready() -> void :
	(get_node("Graphics") as MeshInstance).material_override = icon_material;
	
	base_blink_speed = icon_material.get_shader_param("blink_speed");
	
	icon_material.set_shader_param("icon_texture", tool_icon);
	icon_material.set_shader_param("blink_speed", 0.0);

func focus_entered() -> void :
	icon_material.set_shader_param("blink_speed", base_blink_speed);
	
func focus_exited() -> void :
	icon_material.set_shader_param("blink_speed", 0.0);