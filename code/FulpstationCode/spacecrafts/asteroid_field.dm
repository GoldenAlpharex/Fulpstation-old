// Time for sommething big: Randomly-generated asteroid fields! //

#define CIRCLE "circle"
#define FULL_CIRCLE_DEGREES 360
#define CLUSTER_CHECK_NONE 0 // Has to be here otherwise it won't work, might change it later. Undefined at the end.
#define INIT_ANNOUNCE(X) to_chat(world, "<span class='boldannounce'>[X]</span>"); log_world(X)

/datum/controller/subsystem/mapping/proc/add_asteroid_z_level()
	var/start_time = REALTIMEOFDAY
	var/datum/space_level/asteroid_level = add_new_zlevel("Asteroid Field", traits = ZTRAIT_ASTEROID_FIELD)

	// These are the default parameters handed into the shape generator procs.
	var/new_turf = /turf/closed/mineral
	var/base_turf = /turf/open/space

	var/startTurfX = 20
	var/startTurfY = 20
	var/startTurfZ = asteroid_level.z_value
	var/endTurfX = 236
	var/endTurfY = 236
	var/endTurfZ = asteroid_level.z_value

	var/list/map = list()
	var/asteroid_probability = 1

	var/shape_generatorType = /datum/shape_generator
	var/datum/shape_generator/shape_generator = new shape_generatorType()

	map |= block(locate(startTurfX,startTurfY,startTurfZ), locate(endTurfX,endTurfY,endTurfZ))

	var/list/asteroid_generators = list()
	for(var/turf/T in map)
		if(prob(asteroid_probability))
			asteroid_generators += T

	for(var/turf/T in asteroid_generators)
		shape_generator.generate_roundish(base_turf, new_turf, T.x, T.y, T.z, rand(2, 9))

	INIT_ANNOUNCE("Generated Asteroid Field in [(REALTIMEOFDAY - start_time)/10] seconds!")
	// var/mapGeneratorType = /datum/map_generator/asteroid_scarce
	// var/datum/map_generator/mapGenerator

	// mapGenerator = new mapGeneratorType()
	// mapGenerator.defineRegion(locate(startTurfX,startTurfY,startTurfZ), locate(endTurfX,endTurfY,endTurfZ))
	// mapGenerator.generate()


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
	shape_generator.generate_roundish(generated_on, generated_turf, x, y, z, radius)
	// if(radius > 2)
	// 	INVOKE_ASYNC(shape_generator, /datum/shape_generator/.proc/flood_fill, src, generated_on, generated_turf)
	// shape_generator.flood_fill(src, generated_on, generated_turf)

/datum/map_generator_module/scarce_layer/asteroid_generators
	spawnableAtoms = list()
	spawnableTurfs = list(/turf/generator/asteroid = 1)
	mother = (/datum/map_generator/asteroid_scarce)

/datum/map_generator/asteroid_scarce
	modules = list(/datum/map_generator_module/scarce_layer/asteroid_generators)
	buildmode_name = "Asteroid: Scarce"

/// Putting some information that can be used by the procs that come from this, if needed
/datum/shape_generator



/// Wtf is a vertex, you ask? Here: https://en.wikipedia.org/wiki/Vertex_(geometry)
/// We use vertices here to create a round-ish shape, that will then get filled with turfs specified in new_turfpath
/// Perfect for creating asteroids!
/// There's a lot of min() and max() to avoid divisions by 0.
/datum/shape_generator/proc/generate_roundish(turf/target_turfpath, turf/new_turfpath, centerX, centerY, centerZ, max_radius)
	/// Time to generate the coordinates of the vertices that, when linked, create a round-ish shape.
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
	/// Time to add turf to each vertex and store those turfs in a list
	for(var/vertex in real_vertex_coordinates)
		var/turf/vertex_turf = locate(vertex["x"], vertex["y"], vertex["z"])
		if(!istype(vertex_turf, new_turfpath))
			vertex_turf.ChangeTurf(new_turfpath)
		vertex_turfs += vertex_turf

	/// Time to add turf between each vertex, let's remember those border steps too
	var/border_turfs = vertex_turfs /// We start by adding the vertices

	for(var/i in 1 to length(vertex_turfs))
		var/turf/target
		if(i == length(vertex_turfs)) // If it's the last vertex, connect it with the first.
			target = vertex_turfs[1]
		else
			target = vertex_turfs[i + 1]

		var/list/turfs_on_line = getline(vertex_turfs[i], target)
		for(var/turf/border_turf in turfs_on_line)
			border_turf.ChangeTurf(new_turfpath, flags=CHANGETURF_SKIP)
			border_turfs += border_turf
		// var/not_reached_vertex = TRUE
		// var/turf/current_step = vertex_turfs[i]
		// /// Time go go through each turf between two vertices
		// while(not_reached_vertex)
		// 	var/turf/next_step = get_step_towards(current_step, target)
		// 	if(!istype(next_step, new_turfpath))
		// 		next_step.ChangeTurf(new_turfpath)
		// 	if(next_step == target)
		// 		not_reached_vertex = FALSE
		// 	else
		// 		current_step = next_step
		// 		border_turfs += next_step

	/// Now, time to slice the borders to allow for easier shape-filling.
	var/list/border_turfs_slices = list()
	for(var/turf/border_turf in border_turfs)
		border_turfs_slices["[border_turf.x]"] += list(border_turf)

	/// Time to go from the lowest point of a slice to the upper point, and fill that in a smart way.
	var/list/turfs_to_changeturf = list()
	for(var/key in border_turfs_slices)
		var/list/slice = border_turfs_slices[key]
		/// If it's only one turf, no need to go over it.
		if(length(slice) == 1)
			continue
		slice = sortTim(slice, /proc/cmp_turf_y, FALSE)
		// var/turf/lowest_turf_from_slice = slice[1]
		// var/max_range = centerY - lowest_turf_from_slice.y + max_radius - rand(1, 2)
		// var/current_distance = 0
		/// If we've got a cave-in (or multiple), let's alternate between filling and not.
		if(length(slice) % 2 == 0)
			var/replace = TRUE
			for(var/i in 1 to (length(slice) - 1))
				var/list/turf_line = getline(slice[i], slice[i+1])
				if(replace)
					turfs_to_changeturf += turf_line
				replace = !replace

			// var/turf/current_turf = slice[1]
			// while(current_turf != slice[length(slice)] && current_distance <= max_range)
			// 	var/turf/next_turf = get_step(current_turf, NORTH)
			// 	if(istype(next_turf, new_turfpath) && (next_turf in slice))
			// 		replace = !replace
			// 	if(istype(next_turf, target_turfpath))
			// 		if(replace == TRUE)
			// 			next_turf.ChangeTurf(new_turfpath)
			// 	current_turf = next_turf
			// 	current_distance += 1
		/// Else fuck that we're just making a line, smart enough
		else
			turfs_to_changeturf += getline(slice[1], slice[length(slice)])
			// var/turf/current_turf = slice[1]
			// while(current_turf != slice[length(slice)] && current_distance < max_range)
			// 	var/turf/next_turf = get_step(current_turf, NORTH)
			// 	if(istype(next_turf, target_turfpath))
			// 		next_turf.ChangeTurf(new_turfpath)
			// 	current_turf = next_turf
			// 	current_distance += 1

		/// Finally, we invoke a changeturf for later in the loading process, hopefully reduces loading time
		for(var/turf/T in turfs_to_changeturf)
			T.ChangeTurf(new_turfpath, flags=CHANGETURF_SKIP)



// /// Made separate to make generate_roundish() clearer.
// /// Returns a list of the real coordinates of the vertices used for a round-ish shape.
// /datum/shape_generator/proc/generate_circle_vertices_coordinates(centerX, centerY, centerZ, max_radius)
// 	var/average_vertex_amount = rand(min(5, max_radius), max(5, max_radius))
// 	var/max_angle_delta = FLOOR(FULL_CIRCLE_DEGREES / average_vertex_amount, 1)
// 	var/min_angle_delta = FLOOR(FULL_CIRCLE_DEGREES / (1.5 * average_vertex_amount), 1)
// 	var/current_length = rand(3 , max(3, max_radius)) // We just initialize this here for the following while loop
// 	var/list/current_relative_vertex_coordinates = list("x" = current_length, "y" = 0) // To add support for multi-z (you mad lad), just add "z" = 0 there, and then tweak the loop
// 	var/list/relative_vertex_coordinates = list(current_relative_vertex_coordinates)
// 	var/current_angle = 0

// 	// Generating the relative vertexes (yes I know it looks complicated, but it isn't really complicated, actually)
// 	while(current_angle <= FULL_CIRCLE_DEGREES - min_angle_delta)
// 		var/angle_delta = rand(min_angle_delta, max_angle_delta)
// 		var/new_angle = current_angle + angle_delta
// 		var/new_length = rand(3 , max(3, max_radius))
// 		// Might want to work with absolutes and then add the sign based on the angle, but we'll see if it matters much at the implementation.
// 		current_relative_vertex_coordinates = list(
// 			"x" = FLOOR(new_length * cos(new_angle), 1),
// 			"y" = FLOOR(new_length * sin(new_angle), 1)
// 			)
// 		relative_vertex_coordinates += list(current_relative_vertex_coordinates)
// 		current_angle = new_angle
// 		current_length = new_length

// 	// Creating a new list containing all the vertex with their real coordinates.
// 	var/list/real_vertex_coordinates = list()
// 	for(var/vertex in relative_vertex_coordinates)
// 		real_vertex_coordinates += list(list("x" = vertex["x"] + centerX, "y" = vertex["y"] + centerY, "z" = centerZ))

// 	return real_vertex_coordinates


// /// To allow for ordering a list of turfs based on the given axis
// /proc/cmp_turf_axis(turf/a, turf/b, axis)
// 	switch(axis)
// 		if("x")
// 			return a.x - b.x
// 		if("y")
// 			return a.y - b.y
// 		if("z")
// 			return a.z - b.z

/// To allow for ordering a list of turfs based on the given axis
/proc/cmp_turf_x(turf/a, turf/b)
	return a.x - b.x

/proc/cmp_turf_y(turf/a, turf/b)
	return a.y - b.y

/proc/cmp_turf_z(turf/a, turf/b)
	return a.z - b.z


#undef CLUSTER_CHECK_NONE
#undef INIT_ANNOUNCE
