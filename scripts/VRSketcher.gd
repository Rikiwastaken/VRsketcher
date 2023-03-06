extends Node
class_name VRSketcher

var camera : Camera = null;

export(NodePath) var controller_viewport_path : NodePath = "";
export(NodePath) var camera_sync_path : NodePath = "";

onready var world : Spatial = get_node("World");
onready var imported_models_root : Spatial = get_node("Imported_Models");
onready var lines_root : Spatial = get_node("Lines");
onready var measurements_root : Spatial = get_node("Measurements");

onready var project_manager : Control = get_node("Interface/ProjectManager");
onready var vr_sketcher_interface : Control = get_node("Interface/VRSketcherInterface");
onready var controller_selection : Control = get_node("Interface/ControllerSelection");

onready var model_interaction_area : PackedScene = load("res://scenes/ModelInteractionArea.tscn");


func _ready() -> void :
	(get_node("Interface/VRSketcherInterface/HSplitContainer/VBoxContainer/TabedContainer/Display/X_Resolution/SpinBox") as SpinBox).value = get_viewport().size.x;
	(get_node("Interface/VRSketcherInterface/HSplitContainer/VBoxContainer/TabedContainer/Display/Y_Resolution/SpinBox") as SpinBox).value = get_viewport().size.y;
	
	Project.connect("open_project", self, "open_project");

	project_manager.visible = true;
	vr_sketcher_interface.visible = false;
	controller_selection.visible = false;
	
func set_controller(controller : Node, enable_vr : bool) -> void :
	for child in get_children_recursive(controller) :
		if child is Camera :
			camera = child;
			break;
			
	(get_node(controller_viewport_path) as Viewport).arvr = enable_vr;
	
	get_node(controller_viewport_path).add_child(controller);
	
	(get_node(camera_sync_path) as SpatialSync).node_to_sync_to = camera;
	
	EventBus.connect("paint_color_changed", self, "update_color_preview");

func get_children_recursive (root : Node) -> Array :
	var children : Array = [];
	
	for child in root.get_children():
		children.append(child);
		if child.get_child_count() > 0 :
			children.append_array(get_children_recursive(child));
		
	return children;

func apply_display_settings():
	var x_resolution : float = (get_node("Interface/VRSketcherInterface/HSplitContainer/TabedContainer/Display/X_Resolution/SpinBox") as SpinBox).value;
	var y_resolution : float = (get_node("Interface/VRSketcherInterface/HSplitContainer/TabedContainer/Display/Y_Resolution/SpinBox") as SpinBox).value;
	var fov : float = (get_node("Interface/VRSketcherInterface/HSplitContainer/TabedContainer/Display/FOV/SpinBox") as SpinBox).value;
	var fullscreen = (get_node("Interface/VRSketcherInterface/HSplitContainer/TabedContainer/Display/Fullscreen/CheckBox") as CheckBox).pressed;

	get_viewport().size = Vector2(x_resolution, y_resolution);
	OS.window_size = Vector2(x_resolution, y_resolution);
	OS.window_fullscreen = fullscreen;
	
	if camera != null :
		camera.fov = fov;

func update_color_preview(color : Color) -> void :
	(get_node("Interface/VRSketcherInterface/ColorPreview/MarginContainer/Control/TextureRect") as Control).self_modulate = color;

func open_project() -> void :
	project_manager.visible = false;
	vr_sketcher_interface.visible = true;
	controller_selection.visible = true;
	
	if Project.current_project.has("scene_models_data") == true :
		for model_data in Project.current_project["scene_models_data"] :
			import_model(
				model_data["model_filename"] as String,
				true,
				model_data["position"] as Vector3,
				model_data["rotation"] as Vector3,
				model_data["scale"] as float
			);
		
	if Project.current_project.has("scene_line_drawings") == true :
		for line_data in Project.current_project["scene_line_drawings"] :
			var line_renderer : Line = Line.new();
			(get_tree().root.get_node("VRSketcher") as VRSketcher).lines_root.add_child(line_renderer);
			line_renderer.generate_collisions = true;
			line_renderer.thickness = (line_data as Dictionary)["thickness"] as float;
			line_renderer.add_points_from_array((line_data as Dictionary)["points"] as Array);
			line_renderer.material_index = (line_data as Dictionary)["material_index"] as int;
			line_renderer.material_override = PaintMaterials.materials[line_renderer.material_index];

	if Project.current_project.has("scene_measurements") == true :
		for measurement_data in Project.current_project["scene_measurements"] :
			var measurement : Measurement = Measurement.new();
			measurement.mode = measurement_data["mode"];
			measurement.start_point = measurement_data["start_point"];
			measurement.middle_point = measurement_data["middle_point"];
			measurement.end_point = measurement_data["end_point"];
			(get_tree().root.get_node("VRSketcher") as VRSketcher).measurements_root.add_child(measurement);



func import_model(model_path : String, local_model : bool = false, model_position : Vector3 = Vector3.ZERO, model_rotation : Vector3 = Vector3(-90.0, 0.0, 0.0), model_scale : float = 1.0) -> void :
	print("Loading 3D model file : " + model_path);
	
	if local_model == true :
		model_path = Project.get_imported_models_directory_path() + "/" + model_path;
	
	var dir : Directory = Directory.new();
	if dir.file_exists(model_path) == true :
		
		var extension : String = model_path.rsplit(".", true, 1)[1];
		
		var loaded_meshes : Array = [];
		
		
		if extension == "3mf" || extension == "3MF" :
			loaded_meshes = Importer3mf.import_model_file(model_path);
		elif extension == "obj" || extension == "OBJ" :
			loaded_meshes = ImporterObj.import_model_file(model_path);
		elif extension == "stl" || extension == "STL" :
			loaded_meshes = ImporterStl.import_model_file(model_path);


		if loaded_meshes.size() > 0 :
			var model : ImportedModel = ImportedModel.new();
			
			var model_name : String = model_path.rsplit("/", true, 1)[1];
			model.model_filename = model_name;
			
			#Copy model in the import directory if it isn't there yet
			var local_model_file : File = File.new();
			if local_model_file.file_exists(Project.get_imported_models_directory_path() + "/" + model_name) == false :
				if dir.file_exists(model_path) == true :
					dir.copy(model_path, Project.get_imported_models_directory_path() + "/" + model_name);

			model_name = model_name.rsplit(".")[0];
			model.inspector_name = model_name;

			for mesh in loaded_meshes :
				model.add_mesh(mesh);
			imported_models_root.add_child(model);
			model.global_transform.origin = model_position;
			model.rotation_degrees = model_rotation;
			model.scale = Vector3.ONE * model_scale;

			model.set_material(MaterialLibrary.get_current_material());
			
			var interaction_area : ModelInteractionArea = model_interaction_area.instance();
			model.add_child(interaction_area);
			interaction_area.set_interaction_area(model.get_model_aabb().position, model.get_model_aabb().size / 2.0);
			
			ImportedModelsManager.add_model(model);
			print("model loaded")
		else :
			print("model loading error");
	else :
		print("model not found");

func save_project() -> void :
	Project.save_project();
