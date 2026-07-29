spd         = 3;
depth       = -1;
// facing: 0=S 1=N 2=W 3=E 4=SE 5=SW 6=NE 7=NW
facing      = 0;
idle_facing = 0; // cardinal only (0-3), drives spr_player idle frame
moving      = false;

// walk sprite per facing direction — matches facing enum above
walk_sprs = [
    spr_walk_south,
    spr_walk_north,
    spr_walk_west,
    spr_walk_east,
    spr_walk_south_east,
    spr_walk_south_west,
    spr_walk_north_east,
    spr_walk_north_west,
];

skin_col_list = [
	make_colour_rgb(255, 220, 185),
	make_colour_rgb(235, 190, 145),
	make_colour_rgb(198, 145, 100),
	make_colour_rgb(140, 90,  50),
	make_colour_rgb(80,  50,  30),
];
hair_col_list = [
	make_colour_rgb(40,  30,  20),
	make_colour_rgb(100, 65,  30),
	make_colour_rgb(185, 135, 55),
	make_colour_rgb(215, 65,  25),
	make_colour_rgb(210, 200, 180),
	make_colour_rgb(105, 60,  135),
];
