//// This is the file for all the construction paths related to spacecrafts. We'll see where that takes us. ////

#define SKIP 2

/datum/component/construction/spacecraft
	var/base_icon

	var/static/list/accepted_tools = list(TOOL_CROWBAR, TOOL_MULTITOOL, TOOL_SCREWDRIVER, TOOL_WRENCH, TOOL_WELDER, TOOL_WIRECUTTER) //For some reason it's "wirecutters" and not "wirecutter"
	var/list/accepted_tools_verbs = list(
		TOOL_CROWBAR+"_back" = "remove", TOOL_MULTITOOL = "activate", TOOL_MULTITOOL+"_back" = "deactivate", TOOL_MULTITOOL+"_skip" = "bypass", TOOL_SCREWDRIVER = "secure",
		TOOL_SCREWDRIVER+"_back" = "unfasten", TOOL_WRENCH = "secure", TOOL_WRENCH+"_back" = "unfasten", TOOL_WELDER = "weld", TOOL_WELDER+"_back" = "slice",
		TOOL_WIRECUTTER = "adjust", TOOL_WIRECUTTER+"_back" = "unplug"
	)

	//Defining all the circuit boards here, just in case we need to override them later down the line.
	var/circuit_control = /obj/item/circuitboard/spacecraft/control
	var/circuit_module = /obj/item/circuitboard/spacecraft/module
	var/circuit_internal_regulator = /obj/item/circuitboard/spacecraft/internal_regulator
	var/circuit_radio = /obj/item/circuitboard/spacecraft/radio
	var/circuit_gps = /obj/item/circuitboard/spacecraft/gps

	//Defining the arms and modules here, to make it easier with the "name" in the lists of steps.
	var/obj/item/spacecraft_parts/arm/arm = /obj/item/spacecraft_parts/arm
	var/last_arm_configuration

	//Various inner and outer things that don't need to be separate items.
	var/inner_plating = /obj/item/stack/sheet/mineral/titanium
	var/inner_plating_amount = 3
	var/inner_window = /obj/item/stack/sheet/rglass
	var/inner_window_amount = 5
	var/outer_window = /obj/item/stack/sheet/titaniumglass
	var/outer_window_amount = 5
	var/outer_plating = /obj/item/stack/sheet/mineral/plastitanium
	var/outer_plating_amount = 5

/datum/component/construction/spacecraft/spawn_result()
	if(!result)
		return
	// Remove default spacecraft stock parts, as we replace them with new ones.
	var/obj/vehicle/sealed/spacecraft/S = new result(drop_location())
	QDEL_NULL(S.cell)
	QDEL_NULL(S.scanmod)
	QDEL_NULL(S.capacitor)
	QDEL_NULL(S.engine)
	QDEL_NULL(S.thrusters)
	QDEL_NULL(S.right_arm)
	QDEL_NULL(S.left_arm)

	var/obj/item/spacecraft_parts/spacecraft_shell/parent_shell = parent
	S.CheckParts(parent_shell.contents)

	QDEL_NULL(parent)

/datum/component/construction/spacecraft/proc/get_steps()
	return get_frame_steps() + get_stock_parts_steps() + get_circuit_steps() + get_internal_modules_steps() + get_inner_plating_steps() + get_arm_modules_steps() + get_outer_plating_steps()

/datum/component/construction/spacecraft/update_parent(step_index)
	steps = get_steps()
	..()
	// By default, each step in spacecraft construction has a single icon_state:
	// "[base_icon]_[index - 1]"
	// For example, the spacepod's step 1 icon_state is "spacepod_0".
	var/atom/parent_atom = parent
	if(!steps[index]["icon_state"] && base_icon)
		parent_atom.icon_state = "[base_icon]"//_[index - 1]" Add this back in later when you have the sprites!!!!!!!!!!

/datum/component/construction/spacecraft/is_right_key(obj/item/I) // returns index step
	var/list/L = steps[index]
	if(check_used_item(I, L["key"]))
		return FORWARD //to the first step -> forward
	if(check_used_item(I, L["back_key"]))
		return BACKWARD //to the last step -> backwards
	if(check_used_item(I, L["skip_key"]))
		return SKIP //I don't know how to write it like the other comments, but this will allow you to skip the step it is at in the list, as well as the one right after.
	return FALSE

/datum/component/construction/spacecraft/check_used_item(obj/item/I, key)
	if(istype(I, /obj/item/spacecraft_parts/arm))
		var/obj/item/spacecraft_parts/arm/tool = I
		var/list/L = steps[index]
		if(L["config"] != null)
			if(L["config"] != tool.configuration)  //Check for the arms, to see if it's of the right configuration (so left only accepts left and right only accepts right).
				return FALSE
		last_arm_configuration = tool.configuration
	return ..() //Makes it so it does what the parent would normally do once the first part of the overwrite proc has gone through.

/datum/component/construction/spacecraft/proc/get_part_name(obj/item/I)
	return I.name

/datum/component/construction/spacecraft/proc/send_message(obj/item/tool, mob/living/user, diff)
	var/tool_message
	var/target_index = index + diff
	var/list/current_step = steps[index]
	var/list/target_step

	if(target_index > 0 && target_index <= steps.len)
		target_step = steps[target_index]
	else
		target_step = current_step //Just for safety precautions. I sure hope that won't ever happen, but who knows?

	if(diff == FORWARD)
		if(accepted_tools.Find(tool.tool_behaviour))
			tool_message = accepted_tools_verbs[tool.tool_behaviour]
		else
			tool_message = "install"
		user.visible_message("<span class='notice'>[user] [tool_message]s the [current_step["name"]].</span>","<span class='notice'>You [tool_message] the [current_step["name"]].</span>")
	if(diff == BACKWARD)
		if(accepted_tools.Find(tool.tool_behaviour+"_back"))
			tool_message = accepted_tools_verbs[tool.tool_behaviour+"_back"]
		else
			tool_message = "remove"
		user.visible_message("<span class='notice'>[user] [tool_message]s the [target_step["name"]].</span>","<span class='notice'>You [tool_message] the [target_step["name"]].</span>")
	if(diff == SKIP)
		if(accepted_tools.Find(tool.tool_behaviour+"_skip"))
			tool_message = accepted_tools_verbs[tool.tool_behaviour+"_skip"]
		else
			tool_message = "bypass"
		user.visible_message("<span class='notice'>[user] [tool_message]es the [current_step["name"]].</span>","<span class='notice'>You [tool_message] the [current_step["name"]].</span>")


/datum/component/construction/spacecraft/custom_action(obj/item/I, mob/living/user, diff)
	. = ..()
	send_message(I, user, diff)

/datum/component/construction/unordered/spacecraft_chassis/custom_action(obj/item/I, mob/living/user, typepath)
	. = user.transferItemToLoc(I, parent)
	if(.)
		var/atom/parent_atom = parent
		user.visible_message("<span class='notice'>[user] connects [I] to [parent].</span>", "<span class='notice'>You connect [I] to [parent].</span>")
		parent_atom.add_overlay(I.icon_state+"+o")
		qdel(I)

/datum/component/construction/unordered/spacecraft_chassis/spawn_result()
	var/atom/parent_atom = parent
	parent_atom.icon = 'icons/mecha/mech_construction.dmi'
	parent_atom.density = TRUE
	parent_atom.cut_overlays()
	return ..()

// Default proc for the first steps of spacecraft construction.
/datum/component/construction/spacecraft/proc/get_frame_steps()
	return list(
		list(
			"key" = TOOL_WRENCH,
			"name" = "compartments",
			"desc" = "The compartments are loosely connected to the frame."
		),
		list(
			"key" = TOOL_WELDER,
			"back_key" = TOOL_WRENCH,
			"name" = "compartments",
			"desc" = "The compartments are tightly connected to the frame."
		),
		list(
			"key" = /obj/item/stack/cable_coil,
			"amount" = 5,
			"back_key" = TOOL_WELDER,
			"name" = "wiring to the frame",
			"desc" = "The compartments are welded to the frame."
		),
		list(
			"key" = TOOL_WIRECUTTER,
			"back_key" = TOOL_SCREWDRIVER,
			"name" = "wiring",
			"desc" = "The wiring is loosely connected to everything."
		)
	)

/datum/component/construction/spacecraft/proc/get_stock_parts_steps()
	return list(
		list(
			"key" = /obj/item/stock_parts/engine,
			"action" = ITEM_MOVE_INSIDE,
			"back_key" = TOOL_WIRECUTTER,
			"name" = "engine",
			"desc" = "The wiring is adjusted."
		),
		list(
			"key" = TOOL_WRENCH,
			"back_key" = TOOL_CROWBAR,
			"name" = "engine to the frame",
			"desc" = "The engine is installed."
		),
		list(
			"key" = /obj/item/spacecraft_parts/thrusters,
			"action" = ITEM_MOVE_INSIDE,
			"back_key" = TOOL_WRENCH,
			"name" = "thrusters",
			"desc" = "The engine is secured tightly to the frame."
		),
		list(
			"key" = TOOL_WRENCH,
			"back_key" = TOOL_CROWBAR,
			"name" = "thrusters to the frame",
			"desc" = "The thrusters are installed."
		),
		list(
			"key" = /obj/item/spacecraft_parts/headlights,
			"action" = ITEM_MOVE_INSIDE,
			"back_key" = TOOL_SCREWDRIVER,
			"name" = "headlights",
			"desc" = "The thrusters are secured tightly to the frame."
		),
		list(
			"key" = TOOL_WRENCH,
			"back_key" = TOOL_CROWBAR,
			"name" = "headlights",
			"desc" = "The headlights are installed."
		),
		list(
			"key" = /obj/item/stock_parts/scanning_module,
			"action" = ITEM_MOVE_INSIDE,
			"back_key" = TOOL_WRENCH,
			"name" = "scanning module",
			"desc" = "The headlights are secured."
		),
		list(
			"key" = TOOL_SCREWDRIVER,
			"back_key" = TOOL_CROWBAR,
			"name" = "scanning module",
			"desc" = "The scanning module is installed."
		),
		list(
			"key" = /obj/item/stock_parts/capacitor,
			"action" = ITEM_MOVE_INSIDE,
			"back_key" = TOOL_SCREWDRIVER,
			"name" = "capacitor",
			"desc" = "The scanning module is secured."
		),
		list(
			"key" = TOOL_SCREWDRIVER,
			"back_key" = TOOL_CROWBAR,
			"name" = "capacitor",
			"desc" = "The capacitor is installed."
		),
		list(
			"key" = /obj/item/stock_parts/cell,
			"action" = ITEM_MOVE_INSIDE,
			"back_key" = TOOL_SCREWDRIVER,
			"name" = "cell",
			"desc" = "The capacitor is secured."
		),
		list(
			"key" = TOOL_SCREWDRIVER,
			"back_key" = TOOL_CROWBAR,
			"name" = "cell",
			"desc" = "The cell is installed."
		)
	)

/datum/component/construction/spacecraft/proc/get_circuit_steps()
	return list(
		list(
			"key" = circuit_control,
			"action" = ITEM_DELETE,
			"back_key" = TOOL_SCREWDRIVER,
			"name" = "central control circuit",
			"desc" = "The cell is secured."
		),
		list(
			"key" = TOOL_SCREWDRIVER,
			"back_key" = TOOL_CROWBAR,
			"name" = "central control circuit",
			"desc" = "The Central Control circuit is installed."
		),
		list(
			"key" = circuit_module,
			"action" = ITEM_DELETE,
			"back_key" = TOOL_SCREWDRIVER,
			"name" = "module control circuit",
			"desc" = "The Central Control circuit is secured."
		),
		list(
			"key" = TOOL_SCREWDRIVER,
			"back_key" = TOOL_CROWBAR,
			"name" = "module control circuit",
			"desc" = "The Module Control circuit is installed."
		),
		list(
			"key" = circuit_internal_regulator,
			"action" = ITEM_DELETE,
			"back_key" = TOOL_SCREWDRIVER,
			"name" = "internal regulator circuit",
			"desc" = "The Module Control circuit is secured."
		),
		list(
			"key" = TOOL_SCREWDRIVER,
			"back_key" = TOOL_CROWBAR,
			"name" = "internal regulator circuit",
			"desc" = "The Internal Regulator circuit is installed."
		),
		list(
			"key" = circuit_radio,
			"action" = ITEM_DELETE,
			"back_key" = TOOL_SCREWDRIVER,
			"name" = "internal radio control circuit",
			"desc" = "The Internal Regulator circuit is secured."
		),
		list(
			"key" = TOOL_SCREWDRIVER,
			"back_key" = TOOL_CROWBAR,
			"name" = "internal radio control circuit",
			"desc" = "The Internal Radio Control circuit is installed."
		),
		list(
			"key" = circuit_gps,
			"action" = ITEM_DELETE,
			"back_key" = TOOL_SCREWDRIVER,
			"name" = "space-triangulation circuit",
			"desc" = "The Internal Radio Control circuit is secured."
		),
		list(
			"key" = TOOL_SCREWDRIVER,
			"back_key" = TOOL_CROWBAR,
			"name" = "space-triangulation circuit",
			"desc" = "The Space-Triangulation circuit is installed."
		)
	)

/datum/component/construction/spacecraft/proc/get_internal_modules_steps()  // Will need to think of a way to make it optional to go through these steps/have a way to skip to the next set of steps at certain key points in there.
	return list()

/datum/component/construction/spacecraft/proc/get_inner_plating_steps()
	return list(
		list(
			"key" = /obj/item/spacecraft_parts/pilot_seat,
			"action" = ITEM_DELETE,
			"back_key" = TOOL_SCREWDRIVER,
			"name" = "pilot seat",
			"desc" = "The Space-Triagulation circuit is secured."
		),
		list(
			"key" = TOOL_WRENCH,
			"back_key" = TOOL_CROWBAR,
			"name" = "pilot seat",
			"desc" = "The Pilot Seat is installed loosely."
		),
		list(
			"key" = /obj/item/spacecraft_parts/dashboard,
			"action" = ITEM_DELETE,
			"back_key" = TOOL_WRENCH,
			"name" = "dashboard",
			"desc" = "The Pilot Seat is secured in place."
		),
		list(
			"key" = TOOL_WRENCH,
			"back_key" = TOOL_CROWBAR,
			"name" = "dashboard",
			"desc" = "The Dashboard is installed loosely."
		),
		list(
			"key" = TOOL_MULTITOOL,
			"back_key" = TOOL_WRENCH,
			"name" = "dashboard",
			"desc" = "The Dashboard is secured in place."
		),
		list(
			"key" = inner_plating,
			"amount" = inner_plating_amount,
			"back_key" = TOOL_MULTITOOL,
			"name" = "inner plating",
			"desc" = "The Dashboard is active."
		),
		list(
			"key" = TOOL_WRENCH,
			"back_key" = TOOL_CROWBAR,
			"name" = "inner plating",
			"desc" = "The Inner Plating is installed loosely."
		),
		list(
			"key" = TOOL_WELDER,
			"back_key" = TOOL_WRENCH,
			"name" = "inner plating",
			"desc" = "The Inner Plating is secured in place."
		),
		list(
			"key" = inner_window,
			"amount" = inner_window_amount,
			"back_key" = TOOL_WELDER,
			"name" = "inner window",
			"desc" = "The Inner Plating is welded firmly in place."
		),
		list(
			"key" = TOOL_WRENCH,
			"back_key" = TOOL_CROWBAR,
			"name" = "inner window",
			"desc" = "The Inner Window is installed loosely."
		),
		list(
			"key" = TOOL_WELDER,
			"back_key" = TOOL_WRENCH,
			"name" = "inner window",
			"desc" = "The Inner Window is secured in place."
		)
	)

/datum/component/construction/spacecraft/proc/get_arm_modules_steps() // Will need to think of a way to make it optional to go through these steps/have a way to skip to the next set of steps at certain key points in there.
	return list(
		list(
			"key" = arm,
			"config" = RIGHT_ARM,
			"action" = ITEM_MOVE_INSIDE,
			"back_key" = TOOL_WELDER,
			"skip_key" = TOOL_MULTITOOL,
			"name" = RIGHT_ARM+" "+initial(arm.name),
			"desc" = "The Inner Window is welded firmly in place."
		),
		list(
			"key" = TOOL_WRENCH,
			"back_key" = TOOL_CROWBAR,
			"name" = RIGHT_ARM+" "+initial(arm.name),
			"desc" = "The right arm is installed loosely."
		),
		list(
			"key" = arm,
			"config" = LEFT_ARM,
			"action" = ITEM_MOVE_INSIDE,
			"back_key" = TOOL_WRENCH,
			"skip_key" = TOOL_MULTITOOL,
			"name" = LEFT_ARM+" "+initial(arm.name),
			"desc" = "The right arm is secured firmly in place."
		),
		list(
			"key" = TOOL_WRENCH,
			"back_key" = TOOL_CROWBAR,
			"name" = LEFT_ARM+" "+initial(arm.name),
			"desc" = "The left arm is installed loosely."
		)
	)

/datum/component/construction/spacecraft/proc/get_outer_plating_steps()
	var/prevstep_desc = last_arm_configuration ? "The "+ last_arm_configuration + " arm is installed firmly in place." : "The Inner Window is welded firmly in place."
	return list(
		list(
			"key" = outer_window,
			"amount" = outer_window_amount,
			"back_key" = TOOL_WRENCH,
			"name" = "outer window",
			"desc" = prevstep_desc
		),
		list(
			"key" = TOOL_WRENCH,
			"back_key" = TOOL_CROWBAR,
			"name" = "outer window",
			"desc" = "The Outer Window is installed loosely."
		),
		list(
			"key" = TOOL_WELDER,
			"back_key" = TOOL_WRENCH,
			"name" = "outer window",
			"desc" = "The Outer Window is secured in place."
		),
		list(
			"key" = outer_plating,
			"amount" = outer_plating_amount,
			"back_key" = TOOL_WELDER,
			"name" = "external hull plates",
			"desc" = "The Outer Window is welded firmly in place."
		),
		list(
			"key" = TOOL_WRENCH,
			"back_key" = TOOL_CROWBAR,
			"name" = "external hull plates",
			"desc" = "The External Hull Plates are installed loosely."
		),
		list(
			"key" = TOOL_WELDER,
			"back_key" = TOOL_WRENCH,
			"name" = "external hull plates",
			"desc" = "The External Hull Plates are secured in place."
		)
	)

/datum/component/construction/unordered/spacecraft_chassis/spacepod
	result = /datum/component/construction/spacecraft/spacepod
	steps = list(
		/obj/item/spacecraft_parts/internal_module_compartment,
		/obj/item/spacecraft_parts/arm_module_compartment,
		/obj/item/spacecraft_parts/circuit_compartment
	)

/datum/component/construction/spacecraft/spacepod
	result = /obj/vehicle/sealed/spacecraft/spacepod
	base_icon = "ripley0"  //PLACEHOLDER, CHANGE WHEN YOU GET THE NEW SPRITES!
