npc_name   = "Villager";
dialog     = "Hello, traveler!";
skin_col   = make_colour_rgb(210, 170, 120);
shirt_col  = make_colour_rgb(120, 80, 40);
pants_col  = make_colour_rgb(60, 50, 80);
hair_col   = make_colour_rgb(60, 40, 20);
hair_style = 0;   // 0=short  1=long  2=bun

interact_dist = 80;
near_player   = false;
facing        = 0;   // 0=down 1=up 2=left 3=right
moving        = false;
walk_t        = 0;

patrol_cx    = x;
patrol_cy    = y;
patrol_r     = 100;
patrol_timer = irandom(120);
patrol_wait  = irandom_range(120, 280);
move_dx      = 0;
move_dy      = 0;
move_timer   = 0;
move_dur     = 0;
spd          = 1.0;

depth = -round(y);
