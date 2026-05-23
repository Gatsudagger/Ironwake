depth = -10000;
show_tasks = false;
show_stats = false;
show_pause = false;
selected   = 0;

task_names = ["Train",  "Forage", "Rest"  ];
task_costs = [25,       10,       0       ];
task_mins  = [180,      120,      240     ]; // in-game minutes advanced per task
task_descs = [
	"Advance 3h. Triggers biome stat growth.",
	"Advance 2h. Restore 10 STA.",
	"Advance 4h. Restore 35% max STA.",
];

interact_dist  = 150;
near_creature  = false;
feedback_msg   = "";
feedback_timer = 0;
