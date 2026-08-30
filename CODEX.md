  └ game\scripts\app_manager.gd (+2 -2)
    243      world_viewport.position = Vector2(10, 122)
    244 -    world_viewport.size = Vector2(600, 500)
    244 +    world_viewport.size = Vector2(700, 500)******
    245      world_viewport.stretch = true
        ⋮
    247      world_render_target = SubViewport.new()
    248 -    world_render_target.size = Vector2i(600, 500)
    248 +    world_render_target.size = Vector2i(700, 500)*******
    249      world_render_target.render_target_update_mode = SubViewport.UPDATE_ALWAYS

  └ game\scripts\simulation_hud.gd (+2 -2)
    57
    58 -    var event_panel := PanelContainer.new(); event_panel.position = Vector2(622, 122); event_panel.size = Vector2(328, 178); event_panel.add_theme_styl
        ebox_override("panel", UIFactory.panel()); root.add_child(event_panel)
    58 +    var event_panel := PanelContainer.new(); event_panel.position = Vector2(722, 122); event_panel.size = Vector2(228, 178); event_panel.add_theme_styl
        ebox_override("panel", UIFactory.panel()); root.add_child(event_panel)
    59      var event_box := VBoxContainer.new(); event_panel.add_child(event_box)
       ⋮
    62
    63 -    inspector_panel = PanelContainer.new(); inspector_panel.position = Vector2(622, 312); inspector_panel.size = Vector2(328, 310); *******inspector_panel.vis
        ible = false; inspector_panel.add_theme_stylebox_override("panel", UIFactory.panel()); root.add_child(inspector_panel)
    63 +    inspector_panel = PanelContainer.new(); inspector_panel.position = Vector2(722, 312); inspector_panel.size = Vector2(228, 310); ********inspector_panel.vis
        ible = false; inspector_panel.add_theme_stylebox_override("panel", UIFactory.panel()); root.add_child(inspector_panel)
    64      var inspector_box := VBoxContainer.new(); inspector_panel.add_child(inspector_box)