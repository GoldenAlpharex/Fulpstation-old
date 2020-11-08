// Time for sommething big: Randomly-generated asteroid fields! //

#define CIRCLE "circle"
#define FULL_CIRCLE_DEGREES 360
#define CLUSTER_CHECK_NONE 0 // Has to be here otherwise it won't work, might change it later. Undefined at the end.
#define INIT_ANNOUNCE(X) to_chat(world, "<span class='boldannounce'>[X]</span>"); log_world(X)

/datum/controller/subsystem/mapping/proc/add_asteroid_z_level()
	name = "Asteroid Field"
	var/datum/space_level/asteroid_level = add_new_zlevel("Asteroid Field", traits = ZTRAIT_ASTEROID_FIELD)
	INIT_ANNOUNCE("The Asteroid Field is now generated at the z = [asteroid_level.z_value] level.")
	var/startTurfX = 20
	var/startTurfY = 20
	var/startTurfZ = asteroid_level.z_value
	var/endTurfX = 236
	var/endTurfY = 236
	var/endTurfZ = asteroid_level.z_value
	var/mapGeneratorType = /datum/map_generator/asteroid_scarce
	var/datum/map_generator/mapGenerator

	mapGenerator = new mapGeneratorType()
	mapGenerator.defineRegion(locate(startTurfX,startTurfY,startTurfZ), locate(endTurfX,endTurfY,endTurfZ))
	mapGenerator.generate()
	// // Spawning that landmark should be what kick-starts the whole asteroid generation.
	// var/obj/effect/landmark/map_generator/asteroid_field/asteroid_field = new
	// asteroid_field.forceMove(locate(10, 10, asteroid_level.z_value))


// /obj/effect/landmark/map_generator/asteroid_field
// 	startTurfX = 10
// 	startTurfY = 10
// 	startTurfZ = -1
// 	endTurfX = 246
// 	endTurfY = 246
// 	endTurfZ = -1
// 	mapGeneratorType = /datum/map_generator/asteroid_scarce

// /obj/effect/landmark/map_generator/asteroid_field/Initialize()
// 	. = ..()
// 	log_world("Initialized Asteroid Landmark!")

// For when it really needs to be rare
/datum/map_generator_module/scarce_layer
	clusterCheckFlags = CLUSTER_CHECK_NONE
	spawnableAtoms = list(/atom = 1)
	spawnableTurfs = list(/turf = 1)

/turf/generator
	name = "generator"
	desc = "Generates stuff. You shouldn't be seeing this."
	var/generated_turf = /turf/closed/wall // This is the default parameter handed into the shape generator procs.
	var/generated_on = /turf/open/space // This is the default parameter being fed into flood_fill.
	var/shape = CIRCLE // By default, can be changed to something else to change generation behavior, to be implemeted later
	var/radius = 5 // Once again, for map_generator_module purposes

/turf/generator/asteroid
	name = "asteroid generator"
	desc = "Generates asteroids. You shouldn't be seeing this."
	generated_turf = /turf/closed/mineral
	var/ores = list()
	var/shape_generatorType = /datum/shape_generator // Gotta have it somewhere, heh?
	var/datum/shape_generator/shape_generator

/turf/generator/asteroid/Initialize(mapload)
	. = ..()
	radius = rand(2, 9) // Should be a decent size, right?
	shape_generator = new shape_generatorType()
	shape_generator.generate_roundish(generated_turf, x, y, z, radius)
	if(radius > 2)
		INVOKE_ASYNC(shape_generator, /datum/shape_generator/.proc/flood_fill, src, generated_on, generated_turf)
	// shape_generator.flood_fill(src, generated_on, generated_turf)

/datum/map_generator_module/scarce_layer/asteroid_generators
	spawnableAtoms = list()
	spawnableTurfs = list(/turf/generator/asteroid = 1)
	mother = (/datum/map_generator/asteroid_scarce)

/datum/map_generator/asteroid_scarce
	modules = list(/datum/map_generator_module/scarce_layer/asteroid_generators)
	buildmode_name = "Asteroid: Scarce"

// Putting some information that can be used by the procs that come from this.
/datum/shape_generator
	var/list/already_iterated = list()

// Wtf is a vertex, you ask? Here: https://en.wikipedia.org/wiki/Vertex_(geometry)
// We use vertices here to create a round-ish shape, that will then get filled with turfs specified in turfpath.matrix
// Perfect for creating asteroids!
// There's a lot of min() and max() to avoid divisions by 0.
/datum/shape_generator/proc/generate_roundish(turf/turfpath, centerX, centerY, centerZ, max_radius)
	var/average_vertex_amount = rand(min(5, max_radius), max(5, max_radius))
	var/max_angle_delta = FLOOR(FULL_CIRCLE_DEGREES / average_vertex_amount, 1)
	var/min_angle_delta = FLOOR(FULL_CIRCLE_DEGREES / (1.5 * average_vertex_amount), 1)
	var/current_length = rand(3 , max(3, max_radius)) // We just initialize this here for the following while loop
	var/list/current_relative_vertex_coordinates = list("x" = current_length, "y" = 0) // To add support for multi-z (you mad lad), just add "z" = 0 there, and then tweak the loop
	var/list/relative_vertex_coordinates = list(current_relative_vertex_coordinates)
	var/current_angle = 0

	// Generating the relative vertexes (yes I know it looks complicated, but it isn't really complicated, actually)
	while(current_angle <= FULL_CIRCLE_DEGREES - min_angle_delta)
		var/angle_delta = rand(min_angle_delta, max_angle_delta)
		var/new_angle = current_angle + angle_delta
		var/new_length = rand(3 , max(3, max_radius))
		// Might want to work with absolutes and then add the sign based on the angle, but we'll see if it matters much at the implementation.
		current_relative_vertex_coordinates = list(
			"x" = FLOOR(new_length * cos(new_angle), 1),
			"y" = FLOOR(new_length * sin(new_angle), 1)
			)
		relative_vertex_coordinates += list(current_relative_vertex_coordinates)
		current_angle = new_angle
		current_length = new_length

	// Creating a new list containing all the vertex with their real coordinates.
	var/list/real_vertex_coordinates = list()
	for(var/vertex in relative_vertex_coordinates)
		real_vertex_coordinates += list(list("x" = vertex["x"] + centerX, "y" = vertex["y"] + centerY, "z" = centerZ))

	var/vertex_turfs = list()
	// Time to add turf to each vertex and store those turfs in a list
	for(var/vertex in real_vertex_coordinates)
		var/turf/vertex_turf = locate(vertex["x"], vertex["y"], vertex["z"])
		vertex_turf.ChangeTurf(turfpath)
		vertex_turfs += vertex_turf

	// Time to add turf between each vertex
	for(var/i in 1 to length(vertex_turfs))
		var/turf/target
		if(i == length(vertex_turfs)) // If it's the last vertex, connect it with the first.
			target = vertex_turfs[1]
		else
			target = vertex_turfs[i + 1]
		var/not_reached_vertex = TRUE
		var/turf/current_step = vertex_turfs[i]
		// Time go go through each turf between two vertices
		while(not_reached_vertex)
			var/turf/next_step = get_step_towards(current_step, target)
			next_step.ChangeTurf(turfpath)
			if(next_step == target)
				not_reached_vertex = FALSE
			else
				current_step = next_step


// Flood-fill, as explained by pseudo-code.
// Flood-fill (node, target-color, replacement-color):
//  1. If target-color is equal to replacement-color, return.
//  2. If color of node is not equal to target-color, return.
//  3. Set Q to the empty queue.
//  4. Add node to Q.
//  5. For each element N of Q:
//  6.     Set w and e equal to N.
//  7.     Move w to the west until the color of the node to the west of w no longer matches target-color.
//  8.     Move e to the east until the color of the node to the east of e no longer matches target-color.
//  9.     For each node n between w and e:
// 10.         Set the color of n to replacement-color.
// 11.         If the color of the node to the north of n is target-color, add that node to Q.
// 12.         If the color of the node to the south of n is target-color, add that node to Q.
// 13. Continue looping until Q is exhausted.
// 14. Return.
/datum/shape_generator/proc/flood_fill(turf/node_turf, target_turf_path, new_turf_path, list/queue=list())
	return
	// target and new turf paths being equal would just cause a runtime. Runtime bad.
	if(target_turf_path == new_turf_path)
		return
	// If the node_turf (so the starting point) doesn't match target_turf_path or the generator turf path,
	// get out of there while you still can.
	if(!istype(node_turf, target_turf_path) && !istype(node_turf, /turf/generator))
		return
	if(length(queue) == 0 && !(node_turf in queue))
		queue += node_turf
	while(length(queue) > 0)
		// We start by finding the north-most and south-most turfs that are the same type as target_turf_path
		for(var/turf/queue_turf in queue)
			// while(istype(north_turf, target_turf_path))
			// 	var/turf/new_turf = get_step(north_turf, NORTH)
			// 	if(istype(new_turf, target_turf_path))
			// 		north_turf = new_turf
			// 	else
			// 		break
			// while(istype(south_turf, target_turf_path))
			// 	var/turf/new_turf = get_step(south_turf, SOUTH)
			// 	if(istype(new_turf, target_turf_path))
			// 		south_turf = new_turf
			// 	else
			// 		break
			smart_add_to_list(already_iterated, replace_turf_in_dir(queue_turf, target_turf_path, new_turf_path, NORTH, queue))
			smart_add_to_list(already_iterated, replace_turf_in_dir(queue_turf, target_turf_path, new_turf_path, SOUTH, queue))

			if(!(queue_turf in already_iterated))
				already_iterated += queue_turf
			// var/not_reached_target = TRUE
			// var/turf/current_step = north_turf
			// // Time to go through each turf between the north and the south turfs from before and add turf to them,
			// // then add their adjacent turfs to queue.
			// while(not_reached_target)
			// 	var/turf/next_step = get_step_towards(current_step, south_turf)

			// 	current_step.ChangeTurf(replacement_turf_path)
			// 	// We need to avoid having turfs more than once in the queue, otherwise this will never end.
			// 	add_step_to_queue(current_step, queue, EAST)
			// 	add_step_to_queue(current_step, queue, WEST)
			// 	if(isnull(next_step))
			// 		not_reached_target = FALSE
			// 	if(!(current_step in already_iterated))
			// 		already_iterated += current_step
			// 	if(next_step == south_turf)
			// 		add_step_to_queue(next_step, queue, EAST)
			// 		add_step_to_queue(next_step, queue, WEST)
			// 		next_step.ChangeTurf(replacement_turf_path)
			// 		if(!(next_step in already_iterated))
			// 			already_iterated += next_step
			// 		not_reached_target = FALSE
			// 	else
			// 		current_step = next_step

		// At the very end, we remove all the turfs that were already iterated previously from queue, to avoid runtimes. Runtimes bad
		log_world("The already_iterated list is now [length(already_iterated)] elements long.")
		queue -= already_iterated
		log_world("The queue list is now [length(queue)] elements long.")

///* Going in a dir, checking if the new turf is matching the target turf type, if so, change it to the new turf type and keep going,  ///
//   if not, just end there.																										  *///
/datum/shape_generator/proc/replace_turf_in_dir(turf/current_turf, target_turf_path, new_turf_path, dir, list/queue, list/already_iterated_list=already_iterated)
	var/turf/new_turf = get_step(current_turf, dir)
	already_iterated_list += new_turf
	var/isFirstTime = TRUE
	while(!isnull(new_turf) && istype(new_turf, target_turf_path))
		add_step_to_queue(current_turf, queue, EAST)
		add_step_to_queue(current_turf, queue, WEST)
		if(!isnull(current_turf) && istype(current_turf, target_turf_path))
			current_turf.ChangeTurf(new_turf_path)
		already_iterated_list += current_turf
		current_turf = new_turf
		new_turf = get_step(current_turf, dir)
	return already_iterated_list

// Adding steps to the queue for the flood_fill() proc
/datum/shape_generator/proc/add_step_to_queue(turf/starting_turf, list/queue, dir, list/already_iterated_list=already_iterated, turf_type=/turf/open/space)
	var/turf/next_turf = get_step(starting_turf, dir)
	if(!(next_turf in queue) && !(next_turf in already_iterated_list) && istype(starting_turf, turf_type))
		queue += next_turf

// This proc tries to add the elements from second_list into first_list, while making sure they're not already apart of it.
/datum/shape_generator/proc/smart_add_to_list(list/first_list, list/second_list)
	for(var/elem in second_list)
		if(!(elem in first_list))
			first_list += elem

#undef CLUSTER_CHECK_NONE
#undef INIT_ANNOUNCE
