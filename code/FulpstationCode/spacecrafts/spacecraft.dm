// Oh boy, what am I jumping into?
// For anything on the mechanic job, please refer to the mechanic.dm file.

#define RIGHT_ARM "right"
#define LEFT_ARM "left"
#define SPACECRAFT_UNDER_ARMS_LAYER 4.29 //Yeah, it's a strange name, but it's for overlays of arms that go slightly behind the spacecraft.
#define SPACECRAFT_LAYER 4.3
#define SPACECRAFT_ARMS_LAYER 4.4
#define SPACECRAFT_ABOVE_ARMS_LAYER 4.41
#define SPACECRAFT_THRUSTERS_LAYER 4.5

/obj/vehicle/sealed/spacecraft
	name = "Generic Spacecraft!"
	icon = 'icons/Fulpicons/spacecrafts/spacecraft.dmi' //We gotta have a placeholder for testing purposes, heh?
	icon_state = "pod_body"
	layer = SPACECRAFT_LAYER
	move_resist = MOVE_FORCE_STRONG
	resistance_flags = FIRE_PROOF | ACID_PROOF
	default_driver_move = FALSE
	force = 5
	var/enclosed = TRUE //Just in case there's ever an open-concept spacecraft.
	armor = list("melee" = 20, "bullet" = 10, "laser" = 0, "energy" = 0, "bomb" = 0, "bio" = 0, "rad" = 0, "fire" = 100, "acid" = 100)
	var/use_internal_tank = TRUE
	var/internal_tank_valve = ONE_ATMOSPHERE
	var/obj/machinery/portable_atmospherics/canister/internal_tank
	var/datum/gas_mixture/cabin_air
	var/obj/machinery/atmospherics/components/unary/portables_connector/connected_port = null
	var/overlays_file = 'icons/Fulpicons/spacecrafts/spacecraft_overlays.dmi'

	var/static/list/spacecraft_overlays = list() //To keep track of all of the different overlays that get applied on the spacecraft.
	var/obj/item/stock_parts/cell/cell //To keep track of the cell in the spacecraft.
	var/obj/item/stock_parts/scanning_module/scanmod //To keep track of the scanning module in the spacecraft.
	var/obj/item/stock_parts/capacitor/capacitor //To keep track of the capacitor in the spacecraft.
	var/obj/item/stock_parts/engine/engine //To keep track of the engine in the spacecraft.
	var/obj/item/spacecraft_parts/thrusters/thrusters //To keep track of the thrusters in the spacecraft.
	var/obj/item/spacecraft_parts/headlights/headlights //To keep track of the lights in the spacecraft.
	var/obj/item/spacecraft_parts/arm/right_arm //To keep track of the right arm of the spacecraft.
	var/obj/item/spacecraft_parts/arm/left_arm //To keep track of the left arm of the spacecraft.

	var/haslights = FALSE //So we could potentially tamper with the lights later on.
	var/lights = FALSE //Only turn them on if you actually need them, will probably reduce the amount of lag generated by this.
	var/lights_range = 6
	var/lights_power = 2
	var/lights_energy_drain = 5 //Basic lights energy drain when they're turned on.
	var/regular_move_delay = 2.5 //To keep track of the basic move delay of the spacecraft, influenced by the engine of the spacecraft.
	var/obj/item/radio/mech/radio

	// Action Datums for spacecraft buttons //
	var/datum/action/vehicle/sealed/spacecraft/spacecraft_toggle_lights/lights_action = new

/obj/vehicle/sealed/spacecraft/Initialize()
	. = ..()
	add_cabin()
	add_radio()
	if(enclosed)
		add_airtank()
	add_cell()
	add_scanmod()
	add_capacitor()
	add_thrusters()
	add_engine()
	add_lights()
	add_right_arm()
	add_left_arm()
	var/datum/component/riding/D = LoadComponent(/datum/component/riding)
	D.override_allow_spacemove = TRUE
	D.vehicle_move_delay = 50 //Default move delay, if needed at some point. It gets changed a lot, so this might get changed eventually.
	set_spacecraft_overlay()
	START_PROCESSING(SSobj, src)

/obj/vehicle/sealed/spacecraft/Destroy()
	if(internal_tank)
		qdel(internal_tank)
	internal_tank = null
	if(cell)
		qdel(cell)
	cell = null
	if(scanmod)
		qdel(scanmod)
	scanmod = null
	if(capacitor)
		qdel(capacitor)
	capacitor = null
	if(thrusters)
		qdel(thrusters)
	thrusters = null
	if(engine)
		qdel(engine)
	engine = null
	if(headlights)
		qdel(headlights)
	headlights = null
	if(right_arm)
		qdel(right_arm)
	right_arm = null
	if(left_arm)
		qdel(left_arm)
	left_arm = null
	if(loc)
		loc.assume_air(cabin_air)
		air_update_turf()
	else
		qdel(cabin_air)
	cabin_air = null

/obj/vehicle/sealed/spacecraft/CheckParts(list/parts_list)
	..()
	cell = locate(/obj/item/stock_parts/cell) in contents
	scanmod = locate(/obj/item/stock_parts/scanning_module) in contents
	capacitor = locate(/obj/item/stock_parts/capacitor) in contents
	engine = locate(/obj/item/stock_parts/engine) in contents
	thrusters = locate(/obj/item/spacecraft_parts/thrusters) in contents
	headlights = locate(/obj/item/spacecraft_parts/headlights) in contents
	for(var/obj/item/spacecraft_parts/arm/A in contents)
		if(A.configuration == RIGHT_ARM)
			right_arm = A
		if(A.configuration == LEFT_ARM)
			left_arm = A
	update_part_values()

/obj/vehicle/sealed/spacecraft/proc/update_part_values()
	if(headlights)
		haslights = TRUE
	else
		haslights = FALSE
	if(scanmod)
		lights_energy_drain = 6 - scanmod.rating
	if(engine)
		if(engine.rating < 5)
			regular_move_delay = 1.5 - 0.3*engine.rating
		if(engine.rating == 5)
			regular_move_delay = 0.1

/obj/vehicle/sealed/spacecraft/proc/add_airtank()
	internal_tank = new /obj/machinery/portable_atmospherics/canister/air(src)
	return internal_tank

/obj/vehicle/sealed/spacecraft/proc/add_cabin()
	cabin_air = new
	cabin_air.temperature = T20C
	cabin_air.volume = 200
	cabin_air.add_gases(/datum/gas/oxygen, /datum/gas/nitrogen)
	cabin_air.gases[/datum/gas/oxygen][MOLES] = O2STANDARD*cabin_air.volume/(R_IDEAL_GAS_EQUATION*cabin_air.temperature)
	cabin_air.gases[/datum/gas/nitrogen][MOLES] = N2STANDARD*cabin_air.volume/(R_IDEAL_GAS_EQUATION*cabin_air.temperature)
	return cabin_air

/obj/vehicle/sealed/spacecraft/proc/add_radio()
	radio = new(src)
	radio.name = "[src] radio"
	radio.icon = icon
	radio.icon_state = icon_state
	radio.subspace_transmission = TRUE


//This will make sure that there's a cell when it's spawned in if it's a map spawn or admin-spawned.
/obj/vehicle/sealed/spacecraft/proc/add_cell(obj/item/stock_parts/cell/C=null)
	QDEL_NULL(cell)
	if(C)
		C.forceMove(src)
		cell = C
	else
		cell = new /obj/item/stock_parts/cell/high/plus(src)

//This will make sure that there's a scanning module when it's spawned in if it's a map spawn or admin-spawned.
/obj/vehicle/sealed/spacecraft/proc/add_scanmod(obj/item/stock_parts/scanning_module/sm=null)
	QDEL_NULL(scanmod)
	if(sm)
		sm.forceMove(src)
		scanmod = sm
	else
		scanmod = new /obj/item/stock_parts/scanning_module(src)

//This will make sure that there's a capacitor when it's spawned in if it's a map spawn or admin-spawned.
/obj/vehicle/sealed/spacecraft/proc/add_capacitor(obj/item/stock_parts/capacitor/cap=null)
	QDEL_NULL(capacitor)
	if(cap)
		cap.forceMove(src)
		capacitor = cap
	else
		capacitor = new /obj/item/stock_parts/capacitor(src)

//This will make sure that there's thrusters when it's spawned in if it's a map spawn or admin-spawned.
/obj/vehicle/sealed/spacecraft/proc/add_thrusters(obj/item/spacecraft_parts/thrusters/thruster=null)
	QDEL_NULL(thrusters)
	if(thruster)
		thruster.forceMove(src)
		thrusters = thruster
	else
		thrusters = new /obj/item/spacecraft_parts/thrusters(src)

//This will make sure that there's an engine when it's spawned in if it's a map spawn or admin-spawned.
/obj/vehicle/sealed/spacecraft/proc/add_engine(obj/item/stock_parts/engine/E=null)
	QDEL_NULL(engine)
	if(E)
		E.forceMove(src)
		engine = E
	else
		engine = new /obj/item/stock_parts/engine/adv(src)

//This will make sure that there's lights when it's spawned in if it's a map spawn or admin-spawned.
/obj/vehicle/sealed/spacecraft/proc/add_lights(obj/item/spacecraft_parts/headlights/L=null)
	QDEL_NULL(L)
	if(L)
		L.forceMove(src)
		headlights = L
	else
		headlights = new /obj/item/spacecraft_parts/headlights(src)

//This will make sure that there's basic right and left arms when it's spawned in if it's a map spawn or admin-spawned.
/obj/vehicle/sealed/spacecraft/proc/add_right_arm(obj/item/spacecraft_parts/arm/R=null)
	QDEL_NULL(right_arm)
	if(R)
		R.forceMove(src)
		right_arm = R
	else
		right_arm = new /obj/item/spacecraft_parts/arm(src)
		
/obj/vehicle/sealed/spacecraft/proc/add_left_arm(obj/item/spacecraft_parts/arm/L=null)
	QDEL_NULL(left_arm)
	if(L)
		L.forceMove(src)
		left_arm = L
	else
		left_arm = new /obj/item/spacecraft_parts/arm(src)
		left_arm.configuration = LEFT_ARM
		left_arm.update_icon()

/obj/vehicle/sealed/spacecraft/process()
	var/internal_temp_regulation = 1

	update_part_values()

	if(internal_temp_regulation)
		if(cabin_air && cabin_air.return_volume() > 0)
			var/delta = cabin_air.temperature - T20C
			cabin_air.temperature -= max(-10, min(10, round(delta/4,0.1)))
	
	if(internal_tank)
		var/datum/gas_mixture/tank_air = internal_tank.return_air()

		var/release_pressure = internal_tank_valve
		var/cabin_pressure = cabin_air.return_pressure()
		var/pressure_delta = min(release_pressure - cabin_pressure, (tank_air.return_pressure() - cabin_pressure)/2)
		var/transfer_moles = 0
		if(pressure_delta > 0) //cabin pressure lower than release pressure
			if(tank_air.return_temperature() > 0)
				transfer_moles = pressure_delta*cabin_air.return_volume()/(cabin_air.return_temperature() * R_IDEAL_GAS_EQUATION)
				var/datum/gas_mixture/removed = tank_air.remove(transfer_moles)
				cabin_air.merge(removed)
		else if(pressure_delta < 0) //cabin pressure higher than release pressure
			var/datum/gas_mixture/t_air = return_air()
			pressure_delta = cabin_pressure - release_pressure
			if(t_air)
				pressure_delta = min(cabin_pressure - t_air.return_pressure(), pressure_delta)
			if(pressure_delta > 0) //if location pressure is lower than cabin pressure
				transfer_moles = pressure_delta*cabin_air.return_volume()/(cabin_air.return_temperature() * R_IDEAL_GAS_EQUATION)
				var/datum/gas_mixture/removed = cabin_air.remove(transfer_moles)
				if(t_air)
					t_air.merge(removed)
				else //just delete the cabin gas, we're in space or some shit
					qdel(removed)
	/*if(occupants)
		if(cell)
			var/cellcharge = cell.charge/cell.maxcharge
			switch(cellcharge)
				if(0.75 to INFINITY)
					occupants.clear_alert("charge")
				if(0.5 to 0.75)
					occupants.throw_alert("charge", /obj/screen/alert/lowcell, 1)
				if(0.25 to 0.5)
					occupants.throw_alert("charge", /obj/screen/alert/lowcell, 2)
				if(0.01 to 0.25)
					occupants.throw_alert("charge", /obj/screen/alert/lowcell, 3)
				else
					occupants.throw_alert("charge", /obj/screen/alert/emptycell)*/            // Figure a way to make this work later.
	if(lights)
		if(!scanmod)
			lights = FALSE
			return
		if(!headlights)
			lights = FALSE
			return
		use_power(lights_energy_drain)

/obj/vehicle/sealed/spacecraft/spacepod
	name = "space pod"
	desc = "It's a pod. In space. Doing what pods do."
	icon = 'icons/Fulpicons/spacecrafts/spacecraft.dmi'
	icon_state = "pod_body"

//// Movement ////

/obj/vehicle/sealed/spacecraft/driver_move(mob/user, direction)
	var/turf/T = get_turf(src)
	var/datum/gas_mixture/env = T.return_air()
	var/pressure = env.return_pressure()
	var/datum/component/riding/R = GetComponent(/datum/component/riding)
	if(!engine) //Shouldn't be moving without an engine.
		canmove = FALSE
		return ..()
	if(pressure >= 30) //Pressure too high? Tough luck, can't move.
		R.vehicle_move_delay = 500
		canmove = FALSE
		return ..()
	if(pressure <= 30 && pressure > 0.1) //Still some pressure? Tough luck, slow as fuck.
		R.vehicle_move_delay = 50
	if(pressure <= 0.1) //Finally in space like intended? Godspeed brother.
		R.vehicle_move_delay = regular_move_delay
	R.handle_ride(user, direction)
	return TRUE

//// Atmospherics stuff ////

/obj/vehicle/sealed/spacecraft/remove_air(amount)
	if(use_internal_tank)
		return cabin_air.remove(amount)
	return ..()

/obj/vehicle/sealed/spacecraft/return_air()
	if(use_internal_tank)
		return cabin_air
	return ..()

/obj/vehicle/sealed/spacecraft/return_analyzable_air()
	return cabin_air

/obj/vehicle/sealed/spacecraft/proc/return_pressure()
	var/datum/gas_mixture/t_air = return_air()
	if(t_air)
		. = t_air.return_pressure()

/obj/vehicle/sealed/spacecraft/return_temperature()
	var/datum/gas_mixture/t_air = return_air()
	if(t_air)
		. = t_air.return_temperature()

//// Power stuff ////

/obj/vehicle/sealed/spacecraft/proc/get_charge()
	if(cell)
		return max(0, cell.charge)

/obj/vehicle/sealed/spacecraft/proc/has_charge(amount)
	return (get_charge()>=amount)

/obj/vehicle/sealed/spacecraft/proc/use_power(amount)
	if(get_charge() && cell.use(amount))
		return 1
	return 0

/obj/vehicle/sealed/spacecraft/proc/give_power(amount)
	if(!isnull(get_charge()))
		cell.give(amount)
		return 1
	return 0

//// Actions ////

/obj/vehicle/sealed/spacecraft/generate_actions()
	initialize_passenger_action_type(/datum/action/vehicle/sealed/spacecraft/eject)
	initialize_controller_action_type(/datum/action/vehicle/sealed/spacecraft/spacecraft_toggle_lights, VEHICLE_CONTROL_DRIVE)

/datum/action/vehicle/sealed/spacecraft
	check_flags = AB_CHECK_RESTRAINED | AB_CHECK_STUN | AB_CHECK_CONSCIOUS
	icon_icon = 'icons/mob/actions/actions_spells.dmi'
	button_icon_state = "teleport"  // Yeah, I know, counter-intuitive, but button_icon_state goes with icon_icon. I might try to fix that in a future PR. Who knows.
	button_icon = 'icons/mob/actions/backgrounds.dmi'
	background_icon_state = "bg_default"
	var/obj/vehicle/sealed/spacecraft/chassis

/datum/action/vehicle/sealed/spacecraft/eject
	name = "Exit"
	desc = "Exit your spacecraft safely. Don't forget your spacesuit!"
	button_icon_state = "teleport"

/datum/action/vehicle/sealed/spacecraft/eject/Trigger()
	if(..() && istype(vehicle_entered_target))
		vehicle_entered_target.mob_try_exit(owner, owner)

/obj/vehicle/sealed/spacecraft/grant_action_type_to_mob(actiontype, mob/m)
	if(isnull(occupants[m]) || !actiontype)
		return FALSE
	LAZYINITLIST(occupant_actions[m])
	if(occupant_actions[m][actiontype])
		return TRUE
	var/datum/action/action = generate_action_type(actiontype)
	action.Grant(m, src)
	occupant_actions[m][action.type] = action
	return TRUE

/datum/action/vehicle/sealed/spacecraft/Grant(mob/M, obj/vehicle/sealed/spacecraft/S)
	if(S)
		chassis = S
	..()

/datum/action/vehicle/sealed/spacecraft/Destroy()
	chassis = null
	return ..()

/datum/action/vehicle/sealed/spacecraft/spacecraft_toggle_lights
	name = "Toggle Lights"
	icon_icon = 'icons/mob/actions/actions_mecha.dmi'
	button_icon_state = "mech_lights_off"

/datum/action/vehicle/sealed/spacecraft/spacecraft_toggle_lights/Trigger()
	if(!chassis)  //If there's no chassis, this is really bad.
		to_chat(owner, "You failed at turning on the lights, because the chassis is null. Report this to coders as soon as possible.")
		return
	if(!chassis.headlights)  //In case there's somehow no headlights.
		to_chat(owner, "Cannot locate headlights to turn on or off. Aborting.")
	chassis.lights = !chassis.lights
	if(chassis.lights)
		chassis.set_light(chassis.lights_range, l_power = chassis.lights_power)
		button_icon_state = "mech_lights_on"
	else
		chassis.set_light(-chassis.lights_range) //Negative light range is the same as a light range of 0, or so it looks like anyway.
		button_icon_state = "mech_lights_off"
	to_chat(owner, "<span class='notice'>Toggled lights [chassis.lights?"on":"off"].</span>")
	UpdateButtonIcon()

//// Overlay stuff ////

/obj/vehicle/sealed/spacecraft/setDir(newdir)
	. = ..()
	set_spacecraft_overlay()

/obj/vehicle/sealed/spacecraft/proc/set_spacecraft_overlay()
	var/mutable_appearance/right_arm_overlay
	var/mutable_appearance/left_arm_overlay
	var/mutable_appearance/thruster_overlay


	if(right_arm)
		right_arm_overlay = get_spacecraft_overlay("pod_arm_right", overlays_file, SPACECRAFT_ARMS_LAYER)
		right_arm_overlay.transform = null
		right_arm_overlay.pixel_y = -23
		if(dir == EAST)
			right_arm_overlay = get_spacecraft_overlay("pod_arm_right", overlays_file, SPACECRAFT_ABOVE_ARMS_LAYER)
			right_arm_overlay.pixel_x = 12
			right_arm_overlay.pixel_y = -25
		if(dir == WEST)
			right_arm_overlay = get_spacecraft_overlay("pod_arm_right", overlays_file, SPACECRAFT_UNDER_ARMS_LAYER)
			right_arm_overlay.pixel_x = -10
			right_arm_overlay.pixel_y = -23
		if(dir == NORTH || dir == SOUTH)
			right_arm_overlay.pixel_x = 0
	if(left_arm)
		left_arm_overlay = get_spacecraft_overlay("pod_arm_left", overlays_file, SPACECRAFT_ARMS_LAYER)
		left_arm_overlay.pixel_y = -23
		if(dir == EAST)
			left_arm_overlay = get_spacecraft_overlay("pod_arm_left", overlays_file, SPACECRAFT_UNDER_ARMS_LAYER)
			left_arm_overlay.pixel_x = 10
			left_arm_overlay.pixel_y = -25
		if(dir == WEST)
			left_arm_overlay = get_spacecraft_overlay("pod_arm_left", overlays_file, SPACECRAFT_ABOVE_ARMS_LAYER)
			left_arm_overlay.pixel_x = -12
			left_arm_overlay.pixel_y = -23
		if(dir == NORTH || dir == SOUTH)
			left_arm_overlay.pixel_x = 0
	
	if(thrusters)
		thruster_overlay = get_spacecraft_overlay("thrusters", overlays_file, SPACECRAFT_THRUSTERS_LAYER)
		if(dir == EAST)
			thruster_overlay.pixel_x = -2
		if(dir == WEST)
			thruster_overlay.pixel_x = 2
		if(dir == NORTH || dir == SOUTH)
			thruster_overlay.pixel_x = 0
	
	cut_overlays()
	add_overlay(right_arm_overlay)
	add_overlay(left_arm_overlay)
	add_overlay(thruster_overlay)

/obj/vehicle/sealed/spacecraft/proc/get_spacecraft_overlay(icon_state, icon_file, layer)
	var/obj/vehicle/sealed/spacecraft/A
	pass(A)	//suppress unused warning
	var/list/spacecraft_overlays = A.spacecraft_overlays
	var/iconkey = "[icon_state][icon_file]"
	if((!(. = spacecraft_overlays[iconkey])))
		. = spacecraft_overlays[iconkey] = mutable_appearance(icon_file, icon_state, layer)

//// Spacecraft Parts ////
/obj/item/spacecraft_parts
	name = "spacecraft parts"
	desc = "You feel compulsed to tell the coders about discovering this item."
	icon = 'icons/Fulpicons/spacecrafts/spacecraft_parts.dmi'
	icon_state = "thrusters"
	custom_materials = list(/datum/material/iron = 200)
	w_class = WEIGHT_CLASS_NORMAL

/datum/design/spacecraft_parts
	name = "Spacecraft Parts"
	desc = "You feel compulsed to tell the coders about discovering this item."
	build_type = PROTOLATHE
	category = list("Stock Parts")
	lathe_time_factor = 0.2
	departmental_flags = DEPARTMENTAL_FLAG_ENGINEERING

/obj/item/spacecraft_parts/arm
	name = "spacecraft arm"
	icon = 'icons/Fulpicons/spacecrafts/spacecraft_overlays.dmi'
	icon_state = "pod_arms_item"
	var/configuration = RIGHT_ARM
	var/description = "A generic spacecraft-grade arm." //This is to make it easier on the examine() to not add a new line every time the user examines the arm, which could otherwise potentially lead to memory issues.

/obj/item/spacecraft_parts/arm/examine()
	desc = "[description]\nIt is currently in the [configuration] configuration."
	. = ..()

/obj/item/spacecraft_parts/arm/update_icon()
	if(configuration == RIGHT_ARM)
		transform = null
	else // Mirroring the icon if it's not the right arm.
		transform = matrix(-1, 0, 0, 0, 1, 0)

/obj/item/spacecraft_parts/arm/screwdriver_act(mob/living/user, obj/item/I)
	I.play_tool_sound(src)
	if(configuration == RIGHT_ARM)
		configuration = LEFT_ARM
	else
		configuration = RIGHT_ARM
	to_chat(user, "<span class='notice'>You modify [src] to be installed on the [configuration == RIGHT_ARM ? "right" : "left"] arm.</span>")
	update_icon()

/datum/design/spacecraft_parts/arm
	name = "Spacecraft Arm"
	desc = "A generic spacecraft-grade arm."
	id = "spacecraft_arm"
	materials = list(/datum/material/titanium = 100, /datum/material/iron = 200)
	build_path = /obj/item/spacecraft_parts/arm

/obj/item/spacecraft_parts/thrusters
	name = "thrusters"
	desc = "The thrust needs to come from somewhere, doesn't it?"
	icon_state = "thrusters"
	custom_materials = list(/datum/material/iron = 200)

/datum/design/spacecraft_parts/thrusters
	name = "Thrusters"
	desc = "The thrust needs to come from somewhere, doesn't it?"
	id = "spacecraft_thrusters"
	materials = list(/datum/material/iron = 200)
	build_path = /obj/item/spacecraft_parts/thrusters

/obj/item/spacecraft_parts/headlights
	name = "headlights"
	desc = "For those scared of the dark. Intended for spacecrafts."
	icon = 'icons/obj/stock_parts.dmi'
	icon_state = "advanced_matter_bin"
	custom_materials = list(/datum/material/iron = 50, /datum/material/glass = 200)

/datum/design/spacecraft_parts/headlights
	name = "Headlights"
	desc = "For those scared of the dark. Intended for spacecrafts."
	id = "spacecraft_headlights"
	materials = list(/datum/material/iron = 50, /datum/material/glass = 200)
	build_path = /obj/item/spacecraft_parts/headlights

/obj/item/spacecraft_parts/spacecraft_shell
	name = "spacecraft shell"
	desc = "The skeleton of the spacecraft."
	custom_materials = list(/datum/material/titanium = 1000, /datum/material/iron = 200)
	w_class = WEIGHT_CLASS_GIGANTIC
	interaction_flags_item = NONE
	var/construct_type = /datum/component/construction/unordered/spacecraft_chassis/spacepod

/obj/item/spacecraft_parts/spacecraft_shell/Initialize()
	. = ..()
	if(construct_type)
		AddComponent(construct_type)

/datum/design/spacecraft_parts/spacecraft_shell
	name = "Spacecraft Shell"
	desc = "The skeleton of the spacecraft."
	id = "spacecraft_shell"
	materials = list(/datum/material/titanium = 1000, /datum/material/iron = 200)
	build_path = /obj/item/spacecraft_parts/spacecraft_shell

/obj/item/spacecraft_parts/internal_module_compartment
	name = "internal module compartment"
	desc = "The place where all the internal modules end up."
	custom_materials = list(/datum/material/iron = 200)

/datum/design/spacecraft_parts/internal_module_compartment
	name = "Internal Module Compartment"
	desc = "The place where all the internal modules end up."
	id = "spacecraft_internal_module_compartment"
	materials = list(/datum/material/iron = 200)
	build_path = /obj/item/spacecraft_parts/internal_module_compartment

/obj/item/spacecraft_parts/arm_module_compartment
	name = "arm module compartment"
	desc = "The place where all the arm modules end up."
	custom_materials = list(/datum/material/iron = 200)

/datum/design/spacecraft_parts/arm_module_compartment
	name = "Arm Module Compartment"
	desc = "The place where all the arm modules end up."
	id = "spacecraft_arm_module_compartment"
	materials = list(/datum/material/iron = 200)
	build_path = /obj/item/spacecraft_parts/arm_module_compartment

/obj/item/spacecraft_parts/circuit_compartment
	name = "circuit compartment"
	desc = "The place where all the circuitry ends up."
	custom_materials = list(/datum/material/iron = 200)

/datum/design/spacecraft_parts/circuit_compartment
	name = "Circuit Compartment"
	desc = "The place where all the circuitry ends up."
	id = "spacecraft_circuit_compartment"
	materials = list(/datum/material/iron = 200)
	build_path = /obj/item/spacecraft_parts/circuit_compartment

/obj/item/spacecraft_parts/pilot_seat
	name = "pilot seat"
	desc = "Very comfortable, even has integrated joysticks for controlling the spacecraft!"
	custom_materials = list(/datum/material/iron = 200)

/datum/design/spacecraft_parts/pilot_seat
	name = "Pilot Seat"
	desc = "Very comfortable, even has integrated joysticks for controlling the spacecraft!"
	id = "spacecraft_pilot_seat"
	materials = list(/datum/material/iron = 200)
	build_path = /obj/item/spacecraft_parts/pilot_seat

/obj/item/spacecraft_parts/dashboard
	name = "dashboard"
	desc = "So many buttons..."
	custom_materials = list(/datum/material/iron = 200, /datum/material/glass = 50)

/datum/design/spacecraft_parts/dashboard
	name = "Dashboard"
	desc = "So many buttons..."
	id = "spacecraft_dashboard"
	materials = list(/datum/material/iron = 200, /datum/material/glass = 50)
	build_path = /obj/item/spacecraft_parts/dashboard

/obj/item/circuitboard/spacecraft  //Never forget to make "presets", to save up a ton of useless lines of codes.
	name = "spacecraft circuit board"
	desc = "Not something you should have your hands on! Report this to coders immediately."
	icon = 'icons/obj/module.dmi'
	icon_state = "mcontroller"
	inhand_icon_state = "electronic"
	lefthand_file = 'icons/mob/inhands/misc/devices_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/misc/devices_righthand.dmi'
	custom_materials = list(/datum/material/glass = 500)
	flags_1 = CONDUCT_1
	force = 5
	w_class = WEIGHT_CLASS_SMALL
	throwforce = 0
	throw_speed = 3
	throw_range = 7

/obj/item/circuitboard/spacecraft/control
	name = "spacecraft central control circuit"
	desc = "A circuit, when you need to control everything else."
	icon_state = "mainboard"
	custom_materials = list(/datum/material/glass = 1000)

/obj/item/circuitboard/spacecraft/module
	name = "spacecraft module control circuit"
	desc = "A circuit to control all of the different modules of a spacecraft."

/obj/item/circuitboard/spacecraft/internal_regulator
	name = "spacecraft internal regulator circuit"
	desc = "A circuit to control the temperature inside a spacecraft."

/obj/item/circuitboard/spacecraft/radio
	name = "spacecraft internal radio control circuit"
	desc = "A circuit to control the internal radio of a spacecraft."

/obj/item/circuitboard/spacecraft/gps
	name = "spacecraft space-triangulation circuit"
	desc = "A circuit allowing your spacecraft to use its internal GPS."

/datum/design/board/spacecraft
	name = "Generic Spacecraft Circuit Board"
	desc = "Can this mess even be used for anything?"
	build_type = IMPRINTER
	materials = list(/datum/material/glass = 500)
	departmental_flags = DEPARTMENTAL_FLAG_ENGINEERING
	category = list("Exosuit Modules")

/datum/design/board/spacecraft/control
	name = "Spacecraft Central Control Circuit"
	desc = "A circuit, when you need to control everything else."
	id = "spacecraft_central_control"
	build_path = /obj/item/circuitboard/spacecraft/control

/datum/design/board/spacecraft/module
	name = "Spacecraft Module Control Circuit"
	desc = "A circuit to control all of the different modules of a spacecraft."
	id = "spacecraft_module_control"
	build_path = /obj/item/circuitboard/spacecraft/module

/datum/design/board/spacecraft/internal_regulator
	name = "Spacecraft Internal Regulator Circuit"
	desc = "A circuit to control the temperature inside a spacecraft."
	id = "spacecraft_internal_regulator"
	build_path = /obj/item/circuitboard/spacecraft/internal_regulator

/datum/design/board/spacecraft/radio
	name = "Spacecraft Internal Radio Control Circuit"
	desc = "A circuit to control the internal radio of a spacecraft."
	id = "spacecraft_radio"
	build_path = /obj/item/circuitboard/spacecraft/radio

/datum/design/board/spacecraft/gps
	name = "Spacecraft Space-Triangulation Circuit"
	desc = "A circuit allowing your spacecraft to use its internal GPS."
	id = "spacecraft_gps"
	build_path = /obj/item/circuitboard/spacecraft/gps

/datum/techweb_node/spacecraft
	id = "spacecraft"
	starting_node = TRUE
	display_name = "Basic Spacecraft Technology"
	description = "Everything you'd ever need to be in space!"
	design_ids = list("spacecraft_shell", "basic_engine", "spacecraft_thrusters", "spacecraft_arm", "spacecraft_headlights", "spacecraft_internal_module_compartment",
		"spacecraft_arm_module_compartment", "spacecraft_circuit_compartment", "spacecraft_pilot_seat", "spacecraft_dashboard", "spacecraft_central_control",
		"spacecraft_module_control", "spacecraft_internal_regulator", "spacecraft_radio", "spacecraft_gps")
	prereq_ids = list("base")
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = 10)
	export_price = 10

//// Stock Parts ////

// Tier 1 //
/obj/item/stock_parts/engine
	name = "basic engine"
	desc = "The most basic engine able to power a spacecraft, but hey, it works."
	icon = 'icons/Fulpicons/spacecrafts/spacecraft_parts.dmi'
	icon_state = "engine"
	custom_materials = list(/datum/material/iron = 250)

/datum/design/engine
	name = "Basic Engine"
	desc = "The most basic engine able to power a spacecraft, but hey, it works."
	id = "basic_engine"
	build_type = PROTOLATHE
	materials = list(/datum/material/iron = 250)
	build_path = /obj/item/stock_parts/engine
	category = list("Stock Parts")
	lathe_time_factor = 0.2
	departmental_flags = DEPARTMENTAL_FLAG_ENGINEERING

// Tier 2 //
/obj/item/stock_parts/engine/adv
	name = "advanced engine"
	desc = "An engine capable of powering a spacecraft."
	icon_state = "adv_engine"
	rating = 2
	custom_materials = list(/datum/material/iron = 250)

/datum/design/adv_engine
	name = "Advanced Engine"
	desc = "An engine capable of powering a spacecraft."
	id = "adv_engine"
	build_type = PROTOLATHE
	materials = list(/datum/material/iron = 250)
	build_path = /obj/item/stock_parts/engine/adv
	category = list("Stock Parts")
	lathe_time_factor = 0.2
	departmental_flags = DEPARTMENTAL_FLAG_ENGINEERING

/datum/techweb_node/engineering/New()
	design_ids += list("adv_engine")

// Tier 3 //
/obj/item/stock_parts/engine/super
	name = "super engine"
	desc = "An engine capable of powering a spacecraft."
	icon_state = "super_engine"
	rating = 3
	custom_materials = list(/datum/material/iron = 375)

/datum/design/super_engine
	name = "Super Engine"
	desc = "An engine capable of powering a spacecraft."
	id = "super_engine"
	build_type = PROTOLATHE
	materials = list(/datum/material/iron = 375)
	build_path = /obj/item/stock_parts/engine/super
	category = list("Stock Parts")
	lathe_time_factor = 0.2
	departmental_flags = DEPARTMENTAL_FLAG_ENGINEERING

/datum/techweb_node/high_efficiency/New()
	design_ids += list("super_engine")

// Tier 4 //
/obj/item/stock_parts/engine/bluespace
	name = "bluespace engine"
	desc = "An engine capable of powering a spacecraft. Now with 100% more bluespace shenanigans!"
	icon_state = "bluespace_engine"
	rating = 4
	custom_materials = list(/datum/material/iron = 500, /datum/material/bluespace = 50)

/datum/design/bluespace_engine
	name = "Bluespace Engine"
	desc = "An engine capable of powering a spacecraft. Now with 100% more bluespace shenanigans!"
	id = "bluespace_engine"
	build_type = PROTOLATHE
	materials = list(/datum/material/iron = 500, /datum/material/bluespace = 50)
	build_path = /obj/item/stock_parts/engine/bluespace
	category = list("Stock Parts")
	lathe_time_factor = 0.2
	departmental_flags = DEPARTMENTAL_FLAG_ENGINEERING

/datum/techweb_node/micro_bluespace/New()
	design_ids += list("bluespace_engine")

// Tier 5 //
/obj/item/stock_parts/engine/quantum
	name = "quantum engine"
	desc = "An engine capable of powering a spacecraft. You can faintly hear the screams of all the quantum physicians that died trying to create this masterpiece of quatum technology."
	icon = 'icons/Fulpicons/quantumcell_fulp.dmi'
	icon_state = "quantumcap"
	rating = 5
	custom_materials = list(/datum/material/iron = 750, /datum/material/uranium = 100, /datum/material/diamond = 100, /datum/material/bluespace = 100)

/datum/design/quantum_engine
	name = "Quantum Engine"
	desc = "An engine capable of powering a spacecraft. You can faintly hear the screams of all the quantum physicians that died trying to create this masterpiece of quatum technology."
	id = "quantum_engine"
	build_type = PROTOLATHE
	materials = list(/datum/material/iron = 750, /datum/material/uranium = 100, /datum/material/diamond = 100, /datum/material/bluespace = 100)
	build_path = /obj/item/stock_parts/engine/quantum
	category = list("Stock Parts")
	lathe_time_factor = 0.2
	departmental_flags = DEPARTMENTAL_FLAG_ENGINEERING

/datum/techweb_node/quantum_tech/New()
	design_ids += list("quantum_engine")
