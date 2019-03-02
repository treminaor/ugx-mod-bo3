#using scripts\zm\_zm_powerups;

#using scripts\zm\ugxm\ugxm_gungame;
#using scripts\zm\ugxm\ugxm_util;
#using scripts\zm\_zm_score;

#insert scripts\zm\_zm_perks.gsh;
#insert scripts\zm\_zm_powerups.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#insert scripts\zm\ugxm\ugxm_header.gsh;

#define POWERUP_DEBUGGING true
#define EFFECT_ON 	true
#define EFFECT_OFF 	false

#define QUICKFOOT_MODEL "ugxm_powerup_quickfoot"
#define JUGGERNAUT_MODEL "ugxm_powerup_invulnerability"
#define KILLSHOT_MODEL "ugxm_powerup_killshot"
#define TERMINATOR_MODEL "p7_zm_der_spine"
#define POWERUP_RED_FIRE_FX "ugx/zombie/fire_hands_red"

#define TERMINATOR_SHADER 		"ugxm_terminator"
#define QUICKFOOT_SHADER 		"ugxm_quickfoot"
#define MULTIPLIER_SHADER 		"ugxm_multiplier"
#define GUN_1UP_SHADER 			"ugxm_gun_1up"
#define POINTS_1UP_SHADER 		"ugxm_points_1up"
#define GUN_DOWN_RAND_SHADER 	"ugxm_gun_down_rand"
#define INVISIBILITY_SHADER 	"ugxm_invisibility"
#define RANDOM_P_SHADER 		"ugxm_random"
#define INVULNERABILITY_SHADER 	"ugxm_invulnerability"
#define KILLSHOT_SHADER 		"ugxm_killshot"
#define SENTRY_GUN_SHADER 		"ugxm_sentry_gun"

#precache("model", QUICKFOOT_MODEL);
#precache("model", JUGGERNAUT_MODEL);
#precache("model", KILLSHOT_MODEL);
#precache("model", TERMINATOR_MODEL);
#precache("fx", POWERUP_RED_FIRE_FX);

#precache("material", TERMINATOR_SHADER);
#precache("material", QUICKFOOT_SHADER);
#precache("material", MULTIPLIER_SHADER);
#precache("material", GUN_1UP_SHADER);
#precache("material", POINTS_1UP_SHADER);
#precache("material", GUN_DOWN_RAND_SHADER);
#precache("material", INVISIBILITY_SHADER);
#precache("material", RANDOM_P_SHADER);
#precache("material", INVULNERABILITY_SHADER);
#precache("material", KILLSHOT_SHADER);
#precache("material", SENTRY_GUN_SHADER);

function init_powerups()
{
	level.ugxm_powerup_settings["colors"] = [];
	//add_zombie_powerup( powerup_name, model_name, hint, func_should_drop_with_regular_powerups, only_affects_grabber, any_team, zombie_grabbable, fx, client_field_name, time_name, on_name, clientfield_version = VERSION_SHIP, player_specific = false )

	// Gungame only
	add_zombie_powerup_ugx("gun_1up", 			getWeapon("pistol_burst").worldModel, 	"Gun Advancement", 		"cyan", 	&gun_1up_grab, &gun_1up_should_drop, POWERUP_ONLY_AFFECTS_GRABBER, !POWERUP_ANY_TEAM, !POWERUP_ZOMBIE_GRABBABLE);
	add_zombie_powerup_ugx("points_1up", 		"p7_zm_power_up_carpenter", 			"Points Advancement",	"blue", 	&points_1up_grab, &points_1up_should_drop, POWERUP_ONLY_AFFECTS_GRABBER, !POWERUP_ANY_TEAM, !POWERUP_ZOMBIE_GRABBABLE);
	//add_zombie_powerup_ugx("gun_down_rand", 	"ugxm_powerup_gun_down_rand", 		"Degradation", 			"normal", 		&gun_down_rand,	undefined, undefined, undefined, false);
	
	// Gungame and Sharpshooter
	add_zombie_powerup_ugx("pap_gun_upgrade",	"ugxm_pap_gun_upgrade_model",				"Upgrade Gun",			"black",		&pap_gun_upgrade_grab, &pap_gun_upgrade_should_drop, POWERUP_ONLY_AFFECTS_GRABBER, !POWERUP_ANY_TEAM, !POWERUP_ZOMBIE_GRABBABLE);
	
	// All gamemodes
	//add_zombie_powerup_ugx("random", 			"ugxm_powerup_random", 				"Random Powerup",		"multicolor");	// question mark
	add_zombie_powerup_ugx("multiplier",		"p7_zm_power_up_double_points", 	"Points Multiplier",	"pink", 		&multiplier_grab, &multiplier_should_drop, POWERUP_ONLY_AFFECTS_GRABBER, !POWERUP_ANY_TEAM, !POWERUP_ZOMBIE_GRABBABLE);
	add_zombie_powerup_ugx("invulnerability", 	JUGGERNAUT_MODEL, 					"Invulnerability",		"green", 		&invulnerability_grab, &invulnerability_should_drop, POWERUP_ONLY_AFFECTS_GRABBER, !POWERUP_ANY_TEAM, !POWERUP_ZOMBIE_GRABBABLE);
	add_zombie_powerup_ugx("quickfoot", 		QUICKFOOT_MODEL, 					"Quick Foot",			"purple",		&quickfoot_grab, &quickfoot_should_drop, POWERUP_ONLY_AFFECTS_GRABBER, !POWERUP_ANY_TEAM, !POWERUP_ZOMBIE_GRABBABLE);
	add_zombie_powerup_ugx("terminator", 		TERMINATOR_MODEL, 					"Terminator",			"red", 			&terminator_grab, &terminator_should_drop, POWERUP_ONLY_AFFECTS_GRABBER, !POWERUP_ANY_TEAM, !POWERUP_ZOMBIE_GRABBABLE);
	add_zombie_powerup_ugx("killshot", 			KILLSHOT_MODEL, 					"Killshot",				"yellow", 		&killshot_grab, &killshot_should_drop, POWERUP_ONLY_AFFECTS_GRABBER, !POWERUP_ANY_TEAM, !POWERUP_ZOMBIE_GRABBABLE);
	//add_zombie_powerup_ugx("sentry_gun",		"ugxm_powerup_sentry_gun",			"Sentry Gun",			"white",		&sentry_gun, 		undefined, undefined, undefined, false);

	ARRAY_ADD(level._zombie_custom_spawn_logic, &ugxm_powerups_on_zombie_spawn);
	ARRAY_ADD(level._player_custom_spawn_logic, &ugxm_powerups_on_player_spawn);
	level.player_score_override = &multiplier_player_score_override;

	// If points_1up gives real points, or gungame points. true = gives player real points AND gungame points, false = gives player gungame points
	ugxm_util::powerup_setting("points_1up_real_points", true);
	
	// This is the width/height of the shaders for timed powerups
	ugxm_util::powerup_setting("powerup_shader_size", 32);
	
	// This is the spacing between shaders for timed powerups
	ugxm_util::powerup_setting("powerup_shader_spacing", 10);
	
}
function add_zombie_powerup_ugx( powerup_name, model_name, hint, color, func_grab, func_should_drop_with_regular_powerups, only_affects_grabber, any_team, zombie_grabbable, fx, client_field_name, time_name, on_name, clientfield_version = VERSION_SHIP, player_specific = false )
{
	zm_powerups::register_powerup( powerup_name, func_grab );
	zm_powerups::add_zombie_powerup( powerup_name, model_name, hint, func_should_drop_with_regular_powerups, only_affects_grabber, any_team, zombie_grabbable, fx, client_field_name, time_name, on_name, clientfield_version, player_specific );
	level.ugxm_powerup_settings["colors"][powerup_name] = color;
}

function ugxm_powerups_on_zombie_spawn() //UGXMBO3-12
{
	
}

function ugxm_powerups_on_player_spawn()
{
	self.ugxm_powerup_times = [];
}

function check_stock_powerups() //UGXMBO3-10
{
	if(IS_FALSE(level.ugxm_powerup_settings["full_ammo"]))
		zm_powerups::powerup_remove_from_regular_drops("full_ammo");

	if(IS_FALSE(level.ugxm_powerup_settings["double_points"]))
		zm_powerups::powerup_remove_from_regular_drops("double_points");

	if(IS_FALSE(level.ugxm_powerup_settings["bonfire_sale"]))
		if(isDefined(level.zombie_powerups["bonfire_sale"]))
			zm_powerups::powerup_remove_from_regular_drops("bonfire_sale");

	if(IS_FALSE(level.ugxm_powerup_settings["carpenter"]))
		zm_powerups::powerup_remove_from_regular_drops("carpenter");

	if(IS_FALSE(level.ugxm_powerup_settings["fire_sale"]))
		zm_powerups::powerup_remove_from_regular_drops("fire_sale");

	if(IS_FALSE(level.ugxm_powerup_settings["free_perk"]))
		zm_powerups::powerup_remove_from_regular_drops("free_perk");

	if(IS_FALSE(level.ugxm_powerup_settings["insta_kill"]))
		zm_powerups::powerup_remove_from_regular_drops("insta_kill");

	if(IS_FALSE(level.ugxm_powerup_settings["nuke"]))
		zm_powerups::powerup_remove_from_regular_drops("nuke");

	if(IS_FALSE(level.ugxm_powerup_settings["shield_charge"]))
		zm_powerups::powerup_remove_from_regular_drops("shield_charge");

	if(IS_FALSE(level.ugxm_powerup_settings["minigun"]))
		zm_powerups::powerup_remove_from_regular_drops("minigun");

	if(IS_FALSE(level.ugxm_powerup_settings["ww_grenade"]))
		zm_powerups::powerup_remove_from_regular_drops("ww_grenade");
}

function announce_powerup(name = "undefined message", player, time = 1) //3arc has a graphic display that's probably LUI...
{
	//Colors: 		/*red*/ 					/* dark red*/			/*orange*/					/* purple*/				/* green*/				/*light green*/				/*blue*/					/*cyan*/
	col = []; col[0] = (1,0,0); col[1] = (0.56,0,0); col[2] = (0.91,0.36,0); col[3] = (0.49,0,0.564); col[4] = (0,1,0);  col[5] = (0,.93,0.176);	col[6] = (0,0,1); col[7] = (0,0.93,0.92);	
	
	if(!isDefined(player.ugxm_powerup_hudA))
		player.ugxm_powerup_hudA = [];

	message = self.hint;
	
	if(isDefined(player.ugxm_powerup_hudA[message]))
		return;
	
	player.ugxm_powerup_hudA[message] = ugxm_util::create_simple_hud(player);
	player.ugxm_powerup_hudA[message].foreground = false;
	player.ugxm_powerup_hudA[message].sort = 2;
	player.ugxm_powerup_hudA[message].hidewheninmenu = false;
	player.ugxm_powerup_hudA[message].alignX = "center";
	player.ugxm_powerup_hudA[message].alignY = "middle";
	player.ugxm_powerup_hudA[message].horzAlign = "center";
	player.ugxm_powerup_hudA[message].vertAlign = "middle";
	player.ugxm_powerup_hudA[message].x = 10;
	player.ugxm_powerup_hudA[message].y = 30;
	player.ugxm_powerup_hudA[message].alpha = 1;
	player.ugxm_powerup_hudA[message].fontScale = 2.25;
	player.ugxm_powerup_hudA[message].color = col[randomint(8)];
	player.ugxm_powerup_hudA[message] SetText(message);

	half_time = time / 2;
	player.ugxm_powerup_hudA[message] MoveOverTime( time );
	player.ugxm_powerup_hudA[message].x -= 20 + RandomInt( 40 );
	rand = randomint(100);
	
	if(rand >=50)
		player.ugxm_powerup_hudA[message].y -= ( -25 - RandomInt( 30 ) );
	else
		player.ugxm_powerup_hudA[message].y -= ( 25 + RandomInt( 30 ) );

	wait( half_time );
	player.ugxm_powerup_hudA[message].color += (.3, .3, .3);
	player.ugxm_powerup_hudA[message] FadeOverTime( half_time );
	player.ugxm_powerup_hudA[message].alpha = 0;
	wait( half_time );
	player.ugxm_powerup_hudA[message] ugxm_util::destroy_hud();
	player.ugxm_powerup_hudA[message] = undefined;
}

function generic_powerup_give(name, player, time, func_powerup_effect, func_powerup_loop_effect)
{
	thread announce_powerup(name, player);

	player thread ugxm_util::play_pooled_announcer_vox("powerup_" + name);

	if(time > 0)
		player thread powerup_shader_timed(name);
	else
		player thread powerup_shader(name);

	if(isDefined(player.ugxm_powerup_times[name])) //Powerup already active, reset the time and move on.
	{
		player.ugxm_powerup_times[name] += time;
		return;
	}

	elapsed = 0;

	player.ugxm_powerup_times[name] = time;

	player [[func_powerup_effect]](EFFECT_ON);

	while(elapsed < player.ugxm_powerup_times[name])
	{
		if(isDefined(func_powerup_loop_effect))
			player [[func_powerup_loop_effect]]();
		WAIT_SERVER_FRAME;
		elapsed += SERVER_FRAME;
	}

	player [[func_powerup_effect]](EFFECT_OFF);
	
	player.ugxm_powerup_times[name] = undefined;
}

//UGXMBO3-3
function quickfoot_grab(player)
{
	thread generic_powerup_give(self.powerup_name, player, N_POWERUP_DEFAULT_TIME, &quickfoot_effect);
}
function quickfoot_effect(activate)
{
	if(activate)
		self SetMoveSpeedScale(1.2); //original 1.1 value was 1.1 but this seems too slow in BO3.
	else
		self SetMoveSpeedScale(1.0);
}
function quickfoot_should_drop()
{
	return IS_TRUE(level.ugxm_powerup_settings["quickfoot"]);
}

//UGXMBO3-5
function multiplier_grab(player)
{
	thread generic_powerup_give(self.powerup_name, player, N_POWERUP_DEFAULT_TIME, &multiplier_effect);
}
function multiplier_effect(activate)
{
	//effect takes place simply from the powerup name being defined in the player's .ugxm_powerup_times array
}
function multiplier_player_score_override(damage_weapon, player_points)
{
	if(isDefined(self.ugxm_powerup_times))
		if(isDefined(self.ugxm_powerup_times["multiplier"]) && self.ugxm_powerup_times["multiplier"] > 0)
			player_points = player_points * 2;

	return player_points;
}
function multiplier_should_drop()
{
	return IS_TRUE(level.ugxm_powerup_settings["multiplier"]);
}

//UGXMBO3-6
function killshot_grab(player)
{
	thread generic_powerup_give(self.powerup_name, player, N_POWERUP_DEFAULT_TIME, &killshot_effect);
}
function killshot_effect(activate)
{
	self.personal_instakill = activate;
}	
function killshot_should_drop()
{
	return IS_TRUE(level.ugxm_powerup_settings["killshot"]);
}

//UGXMBO3-2
function invulnerability_grab(player)
{
	thread generic_powerup_give(self.powerup_name, player, N_POWERUP_DEFAULT_TIME, &invulnerability_effect);
}
function invulnerability_effect(activate)
{
	if(activate)	
		self EnableInvulnerability();
	else
	{
		self DisableInvulnerability();
	}
}
function invulnerability_should_drop()
{
	return IS_TRUE(level.ugxm_powerup_settings["invulnerability"]);
}

//UGXMBO3-1
function terminator_grab(player) //in these grab funcs, self is the powerup struct. Don't wait in these functions, they aren't threaded and will break the grab delete of the powerup.
{
	thread generic_powerup_give(self.powerup_name, player, N_POWERUP_DEFAULT_TIME, &terminator_effect, &terminator_loop_effect);
}
function terminator_effect(activate)
{
	if(activate)
		self SetPerk(PERK_DOUBLETAP2);
	else
		self UnSetPerk(PERK_DOUBLETAP2);
}
function terminator_loop_effect()
{
	currentweapon = self GetCurrentWeapon();
	self SetWeaponAmmoClip( currentweapon, currentweapon.clipSize );
}
function terminator_should_drop()
{
	return IS_TRUE(level.ugxm_powerup_settings["terminator"]);
}

//UGXMBO3-7
function gun_1up_grab(player)
{
	thread generic_powerup_give(self.powerup_name, player, 0, &gun_1up_effect);
}
function gun_1up_effect(activate)
{	
	if(activate)
	{
		keys = ugxm_gungame::getGunKeys();
		if(isDefined(level.ugxm_gungame["guns"][keys[self.gunscore+1]]))
			self.score_total = level.ugxm_gungame["guns"][keys[self.gunscore+1]];
		else
			self.score_total = level.ugxm_gungame["complete"];
	}
}
function gun_1up_should_drop()
{
	return IS_TRUE(level.ugxm_powerup_settings["gun_1up"]);
}

//UGXMBO3-16
function points_1up_grab(player)
{
	thread generic_powerup_give(self.powerup_name, player, 0, &points_1up_effect);
}
function points_1up_effect(activate)
{
	if(activate)
	{
		points = randomintrange(100, 2000);
		self iPrintLn("^2You got " + points + " points!");
	
		if(IS_TRUE(level.ugxm_gungame["real_points"]))
			self zm_score::add_to_player_score(points);
		else
			self.score_total += points;
	}
}
function points_1up_should_drop()
{
	return IS_TRUE(level.ugxm_powerup_settings["points_1up"]);
}

//UGXMBO3-9
function pap_gun_upgrade_grab(player)
{
	thread generic_powerup_give(self.powerup_name, player, 0, &pap_gun_upgrade_effect);
}
function pap_gun_upgrade_effect(activate)
{
	if(activate)
		self.ugxm_gg_ss_temp_use_upgrade = true;
}
function pap_gun_upgrade_should_drop()
{
	return IS_TRUE(level.ugxm_powerup_settings["pap_gun_upgrade"]);
}

//UGXMBO3-15 Powerup Shaders since we don't get LUI access :)
function powerup_shader(powerup)
{
	if(!isDefined(self.ugxm_powerup_hudB))
		self.ugxm_powerup_hudB = [];
	
	if(isDefined(self.ugxm_powerup_hudB[powerup]))
		return;
	
	self.ugxm_powerup_hudB[powerup] = ugxm_util::create_simple_hud(self);
	self.ugxm_powerup_hudB[powerup].foreground = false; 
	self.ugxm_powerup_hudB[powerup].sort = 2; 
	self.ugxm_powerup_hudB[powerup].hidewheninmenu = false; 
	self.ugxm_powerup_hudB[powerup].alignX = "center"; 
	self.ugxm_powerup_hudB[powerup].alignY = "middle";
	self.ugxm_powerup_hudB[powerup].horzAlign = "center";
	self.ugxm_powerup_hudB[powerup].vertAlign = "middle";
	self.ugxm_powerup_hudB[powerup].x = 0; 
	self.ugxm_powerup_hudB[powerup].y = -24;
	//self.ugxm_powerup_hudB[powerup] SetShader( powerup, 16, 16 );
	self.ugxm_powerup_hudB[powerup] SetShader( "ugxm_" + powerup,  level.ugxm_powerup_settings["powerup_shader_size"],  level.ugxm_powerup_settings["powerup_shader_size"]);
	self.ugxm_powerup_hudB[powerup].alpha = 0;
	self.ugxm_powerup_hudB[powerup] FadeOverTime(1);
	self.ugxm_powerup_hudB[powerup].alpha = 1;
	
	
	wait 1;
	self.ugxm_powerup_hudB[powerup] FadeOverTime(1.25);
	self.ugxm_powerup_hudB[powerup] MoveOverTime(1.25);
	self.ugxm_powerup_hudB[powerup] ScaleOverTime(1.25, 1, 1);
	rand = randomint(100);
	
	if(rand >=50)
		self.ugxm_powerup_hudB[powerup].y -= ( -175 - RandomInt( 60 ) ); 
	else
		self.ugxm_powerup_hudB[powerup].y -= ( 175 + RandomInt( 60 ) ); 
		
	self.ugxm_powerup_hudB[powerup].alpha = 0;
	wait 1.3;
	self.ugxm_powerup_hudB[powerup] ugxm_util::destroy_hud();
	self.ugxm_powerup_hudB[powerup] = undefined;
}

function powerup_shader_timed(powerup)
{
	if(!isDefined(self.ugxm_powerup_shaders))
		self.ugxm_powerup_shaders = [];

	shaderWidth = level.ugxm_powerup_settings["powerup_shader_size"];
	shaderSpacing = level.ugxm_powerup_settings["powerup_shader_spacing"];
	totalWidth = (self.ugxm_powerup_shaders.size * shaderWidth) + ((self.ugxm_powerup_shaders.size - 1) * shaderSpacing);


	if(!isDefined(self.ugxm_powerup_shaders[powerup]))
	{
		self notify("ugxm_stop_powerup_shuffle");
		self.ugxm_powerup_shaders[powerup] = ugxm_util::create_simple_hud(self);
	}
	
	wait 0.1;
	
	self.ugxm_powerup_shaders[powerup].foreground = false; 
	self.ugxm_powerup_shaders[powerup].sort = 2; 
	self.ugxm_powerup_shaders[powerup].hidewheninmenu = false; 
	self.ugxm_powerup_shaders[powerup].alignX = "center"; 
	self.ugxm_powerup_shaders[powerup].alignY = "bottom";
	self.ugxm_powerup_shaders[powerup].horzAlign = "center";
	self.ugxm_powerup_shaders[powerup].vertAlign = "bottom";
	
	if(self.ugxm_powerup_shaders.size == 1)
		self.ugxm_powerup_shaders[powerup].x = 0;
	else
		self.ugxm_powerup_shaders[powerup].x = (totalWidth / 2) + shaderSpacing + (shaderWidth / 2);
	
	self.ugxm_powerup_shaders[powerup].y = -20;
	
	if(is_any_stock_powerup_enabled()) //UGXMBO3-61
		self.ugxm_powerup_shaders[powerup].y = -60;
	
	self.ugxm_powerup_shaders[powerup] SetShader( "ugxm_" + powerup, shaderWidth, shaderWidth );
	
	self shader_shuffle();

	elapsed = 0;
	counter = 0;

	while(isDefined(self.ugxm_powerup_times[powerup]) && elapsed < self.ugxm_powerup_times[powerup])
	{
		WAIT_SERVER_FRAME;
		elapsed += SERVER_FRAME;
		remaining = self.ugxm_powerup_times[powerup] - elapsed;
		if(!isDefined(remaining))
			break;

		self.ugxm_powerup_shaders[powerup] FadeOverTime(0.05);

		if(remaining < 5)
		{
			if(counter >= 2)
			{
				if(self.ugxm_powerup_shaders[powerup].alpha == 0)
					self.ugxm_powerup_shaders[powerup].alpha = 1;
				else
					self.ugxm_powerup_shaders[powerup].alpha = 0;
					
				counter = 0;
			}
		}
		else if(remaining < 10)
		{
			if(counter >= 10)
			{
				if(self.ugxm_powerup_shaders[powerup].alpha == 0)
					self.ugxm_powerup_shaders[powerup].alpha = 1;
				else
					self.ugxm_powerup_shaders[powerup].alpha = 0;
					
				counter = 0;
			}
		}
		counter++;
	}
	self.ugxm_powerup_shaders[powerup] FadeOverTime(0.1);
	self.ugxm_powerup_shaders[powerup].alpha = 0;
	wait 0.5;
	self.ugxm_powerup_shaders[powerup] ugxm_util::destroy_hud();
	self.ugxm_powerup_shaders[powerup] = undefined;

	self shader_shuffle();	
}
function shader_shuffle()
{
	self endon("ugxm_stop_powerup_shuffle");
	
	shaderWidth = level.ugxm_powerup_settings["powerup_shader_size"];
	shaderSpacing = level.ugxm_powerup_settings["powerup_shader_spacing"];
	
	totalWidth = (self.ugxm_powerup_shaders.size * shaderWidth) + ((self.ugxm_powerup_shaders.size - 1) * shaderSpacing);
	farLeft = 0 - totalWidth;
	farLeftHalfAbsolute = totalWidth / 2;
	
	revkeys = getArrayKeys(self.ugxm_powerup_shaders);
	keys = [];
	for(i=0;i<revkeys.size;i++)
		keys[i] = revkeys[revkeys.size - (i+1)];
	
	for(i=0;i<keys.size;i++)
	{
		self.ugxm_powerup_shaders[keys[i]] MoveOverTime(1);
		self.ugxm_powerup_shaders[keys[i]].x = farLeft + (shaderWidth / 2) + farLeftHalfAbsolute + (i * (shaderWidth + shaderSpacing));
	}
}

function is_any_stock_powerup_enabled() //Unless all of these are explicitly disabled, this is false. //@fixme see comments
{
	if(!IS_FALSE(level.ugxm_powerup_settings["full_ammo"]) //should I bother checking this? It doesn't affect the HUD
		&& !IS_FALSE(level.ugxm_powerup_settings["double_points"])
		&& !IS_FALSE(level.ugxm_powerup_settings["bonfire_sale"])
		&& !IS_FALSE(level.ugxm_powerup_settings["carpenter"])  //should I bother checking this? It doesn't affect the HUD
		&& !IS_FALSE(level.ugxm_powerup_settings["fire_sale"]) 
		&& !IS_FALSE(level.ugxm_powerup_settings["free_perk"])  //should I bother checking this? It doesn't affect the HUD
		&& !IS_FALSE(level.ugxm_powerup_settings["insta_kill"])
		&& !IS_FALSE(level.ugxm_powerup_settings["nuke"])  //should I bother checking this? It doesn't affect the HUD
		&& !IS_FALSE(level.ugxm_powerup_settings["shield_charge"]) 
		&& !IS_FALSE(level.ugxm_powerup_settings["minigun"])
		&& !IS_FALSE(level.ugxm_powerup_settings["ww_grenade"])
	) 
	{
		return true;
	}

	return false;
}