/obj/machinery/spacecraft_console
    name = "spacecraft console"
    desc = "I don't know man, I'm trying to figure shit out."
    icon = 'icons/obj/modular_console.dmi'
    icon_state = "console"
    var/allowed_colors = list("#ffffff", "#00ffff", "#00ff00", "#000000", "#ff0000", "#0000ff")
    var/color = "#ff0000"
    var/health = 20

/obj/machinery/spacecraft_console/ui_interact(mob/user, ui_key = "main", datum/tgui/ui = null, force_open = 0, datum/tgui/master_ui = null, datum/ui_state/state = GLOB.not_incapacitated_turf_state) // Remember to use the appropriate state.
    ui = SStgui.try_update_ui(user, src, ui_key, ui, force_open)
    if(!ui)
        ui = new(user, src, ui_key, "SampleInterface", name, 300, 300, master_ui, state)
        ui.open()

/obj/machinery/spacecraft_console/ui_data(mob/user)
    var/list/data = list()
    data["health"] = health
    data["color"] = color
    return data

/obj/machinery/spacecraft_console/ui_act(action, params)
    if(..())
        return
    if(action == "change_color")
        var/new_color = params["color"]
        if(!(color in allowed_colors))
            return FALSE
        color = new_color
        . = TRUE
    update_icon()