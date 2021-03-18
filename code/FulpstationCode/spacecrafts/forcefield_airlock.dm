/obj/structure/forcefield_airlock // Like in that one movie about space knights fighting with laser swords.
	name = "forcefield airlock"
	desc = "A "
	icon = 'icons/Fulpicons/spacecrafts/forcefield_airlock.dmi'
	icon_state = "forcefield"
	anchored = TRUE
	density = TRUE // Letting vehicles through will be handled with CanAllowThrough()
	CanAtmosPass = ATMOS_PASS_NO // Don't want to space the workshop to get out.
	max_integrity = 300
	armor = list("melee" = 0, "bullet" = 0, "laser" = 100, "energy" = 100, "bomb" = 0, "bio" = 0, "rad" = 0, "fire" = 20, "acid" = 20)
	flags_ricochet = RICOCHET_SHINY

/obj/structure/forcefield_airlock/Initialize()
	. = ..()
	air_update_turf(TRUE) // Atmos holosigns were doing it, so maybe it's the right thing to do?
	// Add more stuff I dunno.

// /obj/structure/forcefield_airlock/proc/CheckSurroundingTurfs(target)
// 	// TODO //

/obj/structure/forcefield_airlock/CanAllowThrough(atom/movable/mover, turf/target)
	if(istype(mover, /obj/vehicle/sealed))
		return TRUE
	. = ..()
