#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\compass;
#using scripts\shared\exploder_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\_zm_perks.gsh;

#insert scripts\zm\_zm_utility.gsh;

#using scripts\zm\_load;
#using scripts\zm\_zm;
#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_magicbox;
#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;
#using scripts\zm\_zm_zonemgr;

#using scripts\shared\math_shared;

#using scripts\shared\ai\zombie_utility;
//#using scripts\mp\gametypes_zm\_globallogic;

//UGX
#using scripts\zm\ugxm\ugxm_util;

#define CHAOSMODE 6

#define GUN_SPOT_FX "ui/fx_ctf_flag_base_team"

#precache( "model", "p7_dogtags_enemy");
#precache( "model", "ugx_care_package");
#precache( "fx", GUN_SPOT_FX );

#precache( "material", "ugxm_5k" );
#precache( "material", "ugxm_10k" );
#precache( "material", "ugxm_60sec" );
#precache( "material", "ugxm_selfrevive" );

//@todo add HUD display for self revive count
//@todo implement combo freezer - try adding to DPAD wheel (i saw some code somewhere) or just make a HUD elem. Then just use a keybind, dont need a weapon this time.

REGISTER_SYSTEM( "ugxm_chaosmode", &__init__, undefined )
function __init__()
{
	callback::on_spawned(&on_player_spawned_chaosmode); //UGXMBO3-57
}

function chaosmode_menu_var_init()
{
	level.ugxm_timed_gameplay_disallowed[6] = true;
}

function prepare_chaosmode()
{
	players = getplayers();
	
	
	/*for(i=0;i<players.size;i++) 
	{
		players[i] setClientDvar("ugxm_combofeed_visible", 0);
		players[i] setClientDvar("ugxm_chaosscore_client_vis", 0);
		players[i] setClientDvar("ugxm_chaosraw_client_vis", 0);
		players[i] setClientDvar("ugxm_chaosrevive_visible", 0);
		players[i] setClientDvar("ugxm_chaosraw", "0");
		players[i] setClientDvar("ugxm_chaosscore", "0");
	}*/

	if(level.ugxm_settings["gamemode"] != CHAOSMODE) 
		return;

	ARRAY_ADD(level._zombie_custom_spawn_logic, &chaos_mode_zombie_options)

	//level.check_end_solo_game_override = &chaos_check_end_solo_game_override;

	level.func_get_zombie_spawn_delay = &get_zombie_spawn_delay;
	level.func_get_delay_between_rounds = &get_zombie_spawn_delay;

	thread ugxm_util::auto_doors_power_etc(true, true);

	//easy way to get sprinters. 3arc made it impossible to use their newer set run cycle functions right now, and the WaW ones cause glitched zombies 50% of the time in BO3 for some reason.
	// 0-40 = walk, 41-70 = run, 71+ = sprint
	thread force_zombie_speed(70);

	level.ugxm_settings["timed"] = true;
	level.ugxm_settings["game_time"] = 180; //default is 120
	level.ugxm_settings["timer_goes_down"] = true;
	level.ugxm_settings["timed_gp_show_desc"] = false;
	level.ugxm_settings["timed_gp_flash_low_time"] = true;
	level.ugxm_settings["timed_gp_custom_hud_location"] = true;

	level.tgTimer.fontScale = 2.5;
	level.tgTimer.alignX = "center"; 
	level.tgTimer.alignY = "top";
	level.tgTimer.horzAlign = "center"; 
	level.tgTimer.vertAlign = "top";
	level.tgTimer.x = 0; 
	level.tgTimer.y = 27; 

	level.ugxm_powerups["sentry_gun"]["enabled"] = false;
	ugxm_util::game_setting("allow_ugx_bossround", false);
	ugxm_util::game_setting("allow_ugx_powerups", false);
	ugxm_util::powerup_setting("using_custom_powerups", false);
	ugxm_util::game_setting("allow_gobblegums", false);
	ugxm_util::game_setting("allow_wall_guns", false);
	ugxm_util::game_setting("allow_mbox", false);
	ugxm_util::game_setting("allow_weap_cabinet", false);
	ugxm_util::game_setting("allow_pay_turrets", false);
	ugxm_util::game_setting("allow_perks", false);
	ugxm_util::game_setting("allow_pap", false);
	ugxm_util::powerup_setting("powerup_drop_chance_chaosmode", 0);
	ugxm_util::powerup_setting("powerups_per_round_chaosmode", 0); //no 
	ugxm_util::game_setting("grenades_disallowed", true); //@todo
	ugxm_util::game_setting("dont_increase_zombie_health", true);

	ugxm_util::powerup_setting("full_ammo", false);
	ugxm_util::powerup_setting("nuke", true);
	ugxm_util::powerup_setting("double_points", true);
	ugxm_util::powerup_setting("insta_kill", true);
	ugxm_util::powerup_setting("carpenter", false);
	ugxm_util::powerup_setting("fire_sale", false);
	ugxm_util::powerup_setting("bonfire_sale", false);
	ugxm_util::powerup_setting("free_perk", false);
	ugxm_util::powerup_setting("minigun", true);

	level.gamemode_is_competative = true;

	level.ugxm_settings["chaosmode_coop_mode"] = true; //forcing this for now

	level.ugxm_chaosmode_medals = [];
	level.ugxm_chaosmode_medals["first_place"]	 = undefined; 
	level.ugxm_chaosmode_medals["second_place"]	 = undefined; 
	level.ugxm_chaosmode_medals["third_place"]	 = undefined; 
	level.ugxm_chaosmode_medals["last_place"]	 = undefined;

	level.ugxm_chaos = [];
	//add these as ugxm_user_settings later
	//Gametime defined in ugxm_init::timed_gameplay()
	level.ugxm_chaos["ks_timeout"] = 2; //Time, in seconds, before a killstreak is lost
	level.ugxm_chaos["kill_score"] = 50; //Score awarded to chaosscore when zombie killed
	level.ugxm_chaos["multi_timeout"] = 5; //Time, in seconds, before a multiplier is lost
	level.ugxm_chaos["longshot_dist"] = 450; //Distance considered to qualify the "Long Shot" bonus
	level.ugxm_chaos["gun_location_count"] = Int(game["random_spawn_positions"].size / 2.5); //how many gun spawns can be on the map at a time. 
	if(level.ugxm_chaos["gun_location_count"] < 5 && game["random_spawn_positions"].size >= 5)
		level.ugxm_chaos["gun_location_count"] = 5;
	level.ugxm_chaos["gun_location_max"] = 25;
	level.ugxm_chaos["max_care_pkgs"] = 1; //how many care packages can be on the map at once before they stop being dropped?
	level.ugxm_chaos["pkg_drop_interval"] = 30; //Time, in seconds, between care package drops - +-randomInt(15) will be added to this amount to make it more interesting. Cannot be set lower than 15.
	level.ugxm_chaos["combofreeze_length"] = 12; //Time, in seconds, that the combo bar will be frozen by a Combo Freezer
	level.ugxm_chaos["gun_cooldown_time"] = 30; //Time, in seconds, that it takes for a taken gun to re-appear

	if(level.ugxm_chaos["pkg_drop_interval"] < 15) level.ugxm_chaos["pkg_drop_interval"] = 15;
	level.ugxm_chaos["waypoint_objects"] = [];
	level.ugxm_chaos["objective_index"] = 0;
	
	if(players.size > 1)
		level.ugxm_powerups["invisibility"]["enabled"] = true;

	level.ugxm_settings["endgame_text"] = "Chaos Mode Over!";
	level flag::init("end_game_chaos");

	thread main();
}

function get_zombie_spawn_delay(round_number)
{
	return 0.1;
}

function force_zombie_speed(speed)
{
	last_speed_change = 0;
	level.zombie_move_speed = speed; //works for round 1
	level.zombie_vars["zombie_move_speed_multiplier"] = speed; //works for subsequent rounds after round 1
	level.zombie_vars["zombie_move_speed_multiplier_easy"] = speed; //works for subsequent rounds after round 1
	level.zombie_vars["zombie_new_runner_interval"] = 1; //don't wait to make those stragglers catch up

	while(1)
	{
		if(level.round_number > last_speed_change)
		{
			level.zombie_move_speed = speed; //works for round 1
			level.zombie_vars["zombie_move_speed_multiplier"] = speed; //works for subsequent rounds after round 1
			level.zombie_vars["zombie_move_speed_multiplier_easy"] = speed; //works for subsequent rounds after round 1
			last_speed_change = level.round_number;
		}
		
		//attempting to stop the end of a special round from delaying zombies spawning in, ruins chaos mode.
		if(flag::exists("world_is_paused"))
			if(flag::get("world_is_paused"))
				level flag::clear("world_is_paused");
		if(flag::exists("spawn_zombies"))
			if(!flag::get("spawn_zombies"))
				level flag::set("spawn_zombies");

		WAIT_SERVER_FRAME;
	}
}

function chaos_mode_zombie_options()
{
	
}

/*function chaos_check_end_solo_game_override()
{
	foreach(player in getPlayers())
		if(player.chaos_self_revive_count > 0)
			return true; //don't let the game end until nobody can be revived
	return false;
}*/
function chaos_check_end_solo_game_override()
{
	if(self.chaos_self_revive_count > 0)
	{
		self.lives = 9999;
		self SetPerk(PERK_QUICK_REVIVE); 
		return false;
	}
	self.lives = 0;
	self UnSetPerk(PERK_QUICK_REVIVE); 
	return true;
}

function main()
{
	//calculate_map_corners();			
	//build_valid_nodes();

	//level.whoswho_laststand_func = &chaos_mode_solo_revive;
	level._game_module_game_end_check = &chaos_check_end_solo_game_override;
	level.force_solo_quick_revive = true;

	thread zombieKilled();
	thread initGunLocations();
	thread carePackageDropper();
	thread catch_end_game_notify();

	//thread test_max_score();
}

function on_player_spawned_chaosmode()
{
	if(!level flag::get("voting_complete"))	
		level flag::wait_till("voting_complete");

	if(level.ugxm_settings["gamemode"] != CHAOSMODE)
		return;

	self initalize_chaos_vars();
	self thread scoreMultiplierMonitor();
	self thread killcomboMonitor();
	self thread perkMonitor();
	self thread nukedMonitor();
	self thread comboannounce_monitor();
	self thread chaosSelfRevive();
	self thread temp_score_hud();
	
	//self.player_damage_override = &chaos_player_damage_override;
}

function chaos_player_damage_override(eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, psOffsetTime)
{
	if(iDamage >= self.health && self.chaos_self_revive_count > 0)
	{
		self playsound("you_died");
		self thread zm::wait_and_revive();
		return;
	}
}

function temp_score_hud()
{
	
	level endon("end_game");
	self endon("disconnect");
	
	//self.gg_pt_start = ugxm_util::create_info_hud(self, "Chaos Points:", 0, (1,1,1));
	//self.gg_mt_start = ugxm_util::create_info_hud(self, "Multiplier Points:", 1, (1,1,1));

	self.selfrevive_hud = ugxm_util::create_info_hud(self, "Self-Revives Remaining:", 0, (1,1,1));
	
	
	while(1)
	{
		wait 0.1;
		if(isDefined(self.gg_pt_end)) self.gg_pt_end ugxm_util::destroy_hud();
		self.gg_pt_end = ugxm_util::create_custom_hud(1, self, Float(self.chaosscore_string), 0, (1, 1, 0), -100, 0, "value", "right", "middle", "right", "middle", 3);
		
		if(isDefined(self.gg_pl_end)) self.gg_pl_end ugxm_util::destroy_hud();
		self.gg_pl_end = ugxm_util::create_custom_hud(1, self, Float(self.rawscore), 0, (1, 1, 0), -10, 40, "value", "left", "middle", "center", "bottom", 2.5);

		if(isDefined(self.kf1)) self.kf1 ugxm_util::destroy_hud();
		self.kf1 = ugxm_util::create_custom_hud(1, self, self.ugxm_combofeed[0], 1, (1, 1, 1), -300, 125, "text", "left", "middle", "right", "middle", 1.5);

		if(isDefined(self.kf2)) self.kf2 ugxm_util::destroy_hud();
		self.kf2 = ugxm_util::create_custom_hud(0.8, self, self.ugxm_combofeed[1], 2, (1, 1, 1), -300, 125, "text", "left", "middle", "right", "middle", 1.5);

		if(isDefined(self.kf3)) self.kf3 ugxm_util::destroy_hud();
		self.kf3 = ugxm_util::create_custom_hud(0.65, self, self.ugxm_combofeed[2], 3, (1, 1, 1), -300, 125, "text", "left", "middle", "right", "middle", 1.5);

		if(isDefined(self.kf4)) self.kf4 ugxm_util::destroy_hud();
		self.kf4 = ugxm_util::create_custom_hud(0.4, self, self.ugxm_combofeed[3], 4, (1, 1, 1), -300, 125, "text", "left", "middle", "right", "middle", 1.5);

		if(isDefined(self.kf5)) self.kf5 ugxm_util::destroy_hud();
		self.kf5 = ugxm_util::create_custom_hud(0.25, self, self.ugxm_combofeed[4], 5, (1, 1, 1), -300, 125, "text", "left", "middle", "right", "middle", 1.5);

		if(isDefined(self.selfrevive_hud_val)) self.selfrevive_hud_val ugxm_util::destroy_hud();
		self.selfrevive_hud_val = ugxm_util::create_info_hud(self, self.chaos_self_revive_count, 0, (0.1,0.688,0.903), 80, "value");
	}	
}

function test_max_score()
{
	wait 1;
	player = getPlayers()[0];
	testString = "2";
	while(1)
	{
		time = getTime();
		player updateRawScore(999999);
		player increaseScoreMultiplier();
		//testString = safeMultiplyToNum(ugxm_util::string(time), "3");

		//player.lastkilltime = time;
		wait 1;
	}
}

function initalize_chaos_vars()
{ //Call on: Player
	self.chaosscore_string = "";		//overall chaos score for player, displayed in upper right corner of screen
	self.old_chaosscore_string = "0"; 	//brother of chaosscore_string, used for game over calcs and medal logic.
	self.rawscore = "0"; 				//center-of-screen number that gets hit by the multiplier on every mult increase. Result of mult is added to overall score (chaosscore_string)
	self.chaos_multiplier = 1; 			
	self.combofrozen = false;
	self.lastkilltime = 0;
	self.lastMultiplierTime = 0;
	self.highest_rawscore = 0; 			//this is still signed int32, fix
	self.highest_multiplier = 0;
	self.killstreak_count = 0;
	self.chaos_perks = [];
	self.ugxm_combofeed_index = 4;
	self.ugxm_combofeed = [];
	self.ugxm_combofeed_alpha = [];
	self.ugxm_combofeed[0] = " ";
	self.ugxm_combofeed_alpha[0] = 0;
	self.ugxm_combofeed[1] = " ";
	self.ugxm_combofeed_alpha[1] = 0;
	self.ugxm_combofeed[2] = " ";
	self.ugxm_combofeed_alpha[2] = 0;
	self.ugxm_combofeed[3] = " ";
	self.ugxm_combofeed_alpha[3] = 0;
	self.ugxm_combofeed[4] = " ";
	self.ugxm_combofeed_alpha[4] = 0;
	self.maxhealth = 100;
	self.health = 100;
	level.ugxm_chaos["pkgs_on_map"] = 0;
	level.ugxm_chaos["total_pkgs_dropped"] = 0;
	setDvar("ugxm_combofeed_visible", 0);
	//self setClientDvar("ugxm_combofeed_visible", 0);
	setDvar("ugxm_chaosscore_client_vis", 0);
	//self setClientDvar("ugxm_chaosscore_client_vis", 0);
	setDvar("ugxm_chaosrevive_visible", 0);
	//self setClientDvar("ugxm_chaosrevive_visible", 0);
	setDvar("ugxm_chaosraw", "0");
	//self setClientDvar("ugxm_chaosraw", "0");
	setDvar("ugxm_chaosscore", "0");
	//self setClientDvar("ugxm_chaosscore", "0");
	setDvar("ugxm_player_" + self getEntityNumber() + "_miniscore", "0");
	//self setClientDvar("ugxm_player_" + self getEntityNumber() + "_miniscore", "0");
	self destroyChaosHUD();
	self loseAllPerks();

	/# self.chaos_self_revive_count = -3; #/ //speed up testing for the end game msg
} //Desc: Initalizes all client values to their default values. Should be called upon death and game start.
function chaos_cleanup_on_death()
{ //Call on: Player
	while(1)
	{
		self util::waittill_any("zombified", "death", "fake_death", "disconnect");
		self initalize_chaos_vars();
		break;
	}
} //Desc: Invokes the client reinitialization upon death
function catch_end_game_notify()
{ //Call on: N/A
	level flag::clear("end_game_chaos");
	level waittill("end_game");
	level flag::set("end_game_chaos");
	thread game_complete();
} //Desc: If something other than the gamemode timer ends the game (i.e. all players died and used up all revives before timer ran out), make sure game_complete still runs.
function players_still_playing()
{ //Call on: None | Returns: bool 
	players = getPlayers();
	//Find anyone who still has a multiplier - if any exist, add them to array. Kill anyone who has no multiplier
	level.players_still_playing = [];
	for(i=0;i<players.size;i++)
	{
		if((players[i].chaos_multiplier > 1 && players[i].sessionstate != "spectator") || (level.ugxm_settings["game_time"] - level.tgTimerTime.toalSec > 0))
			level.players_still_playing[level.players_still_playing.size] = players[i];
		else
			if(players[i].sessionstate != "spectator") players[i] [[level.player_becomes_zombie]]();
	}
	if(level.players_still_playing.size == 0) 
		return false;
	return true;
} //Desc: Checks to see if any alive players are still doing valid actions which extend the game time
function game_complete()
{ //Call on: None 
	/#iPrintLnBold("^5> Chaos Timer ran out, but game could still be active..."); #/
	thread players_still_playing();
	players = getPlayers();

	//If any players are still playing, keep the game going until everyone has lost
	while(1)
	{
		if(!players_still_playing() || level flag::get("end_game_chaos"))
		if(!players_still_playing())
			break;
		wait 0.1;
	}

	// Find highest score of the players (will only show one, even if there are multiple players with the same highest score)
	winner_score = "2";
	for(i=0;i<players.size;i++)
	{
		comparison = ugxm_util::compareStringNumbers(players[i].chaosscore_string, winner_score);
		if(comparison > 0)
			winner_score = players[i].chaosscore_string;
	}
	
	// Go through the players and find any player with this highest score (ties) (these are the winners)
	// Also, you can go ahead and do the endgame stuff here
	winners = [];

	for(i=0;i<players.size;i++)
	{
		comparison = ugxm_util::compareStringNumbers(players[i].chaosscore_string, winner_score);
		if(comparison == 0)
			winners[winners.size] = players[i];
			
		players[i] TakeAllWeapons();
		players[i].ignoreme = true;
		players[i] freezeControls(true);
	}

	level.ugxm_game_winners = winners;
	level.ugxm_game_winners_chaos_score = winner_score;
	/#iPrintLnBold("^5level.ugxm_game_winners_chaos_score = " + winner_score); #/
	level notify("end_game");
} //Desc: Handles end-game processing. Called from ugxm_init()

function createStreakBar()
{ //Call on: Player 
	if(isDefined(self.combofrozen) && self.combofrozen) return;
	self notify("create_new_streakbar");
	self endon("create_new_streakbar");
	if(isDefined(self.chaos_streakbar)) self.chaos_streakbar ugxm_util::destroyElem();
	if(level.ugxm_settings["chaosmode_coop_mode"])
	{

	}
	self.chaos_streakbar = self ugxm_util::createPrimaryProgressBar();
	self.chaos_streakbar.bar.color = (0, 1, 0);
	self.chaos_streakbar ugxm_util::updateBar(0.995, -0.2);
	wait 3; 
	self.chaos_streakbar.bar.color = (1, 1, 0);
	wait 1;
	self.chaos_streakbar.bar.color = (1, 0.5, 0);
	wait 0.5;
	self.chaos_streakbar.bar.color = (1, 0, 0);
} //Desc: Creates the progress bar in the center of the screen which indicates the player's time remaining for their multiplier streak.
function createMultiplier()
{ //Call on: Player 
	if(!isDefined(self.chaos_mutli))
	{
		self.chaos_mutli = newScoreHudElem(self);
		self.chaos_mutli.hidewheninmenu = false;
		self.chaos_mutli.horzAlign = "center";
		self.chaos_mutli.vertAlign = "middle";
		self.chaos_mutli.alignX = "right";
		self.chaos_mutli.alignY = "middle";
 		self.chaos_mutli.x = -5;
		self.chaos_mutli.y = 90;
		self.chaos_mutli.font = "big";
		self.chaos_mutli.fontscale = 2.5;
		self.chaos_mutli.archived = false;
		self.chaos_mutli.color = (1, 1, 0);
	}
} //Desc: Creates the multiplier text HUD in the center of the screen which indicates the player's current multiplier.
function createRawScore()
{ //Call on: Player 
	//self setClientDvar("ugxm_chaosraw_client_vis", 1);
} //Desc: Un-hides the client dvar for the the client's raw chaos score in the center of the screen.
function updateRawScore(amount)
{ //Call on: Player
	amount = amount * level.zombie_vars[getPlayers()[0].team]["zombie_point_scalar"];; 
	self.rawscore = safeAddToNum(self.rawscore, amount);
	
	//self setClientDvar("ugxm_chaosraw", commaFormat(self.rawscore));
	//self setClientDvar("ugxm_chaosscore_client_vis", 1);
} //Desc: Updates the client dvar for the the client's raw chaos score in the center of the screen.
function updateChaosHUD()
{ //Call on: Player 
	thread updateMenuMedals();
	//self setClientDvar("ugxm_chaosscore", commaFormat(self.chaosscore_string));
	players = getPlayers();
	///for(i=0;i<players.size;i++)
	//	for(k=0;k<players.size;k++)
	//		players[i] setClientDvar("ugxm_player_" + k + "_miniscore", commaFormat(players[k].chaosscore_string) + " | " + players[k].chaos_multiplier + "x");
} //Desc: Updates the client dvar for the client's total chaos score in the upper right corner of the screen. Adds comma formatting before setting.
function updateMenuMedals()
{ //Call on: None
	players = getPlayers();

	winner_score = "2";
	for(i=0;i<players.size;i++)
	{
		comparison = ugxm_util::compareStringNumbers(players[i].chaosscore_string, winner_score);
		if(comparison > 0)
			winner_score = players[i].chaosscore_string;
	}

	if(players.size > 1)
	{
		first = "-1"; second = "-1"; third = "-1"; last = "-1";

		//iPrintLnBold("^3Eval scores for player screen: " + players[k].playername);
		for(i=0; i<players.size; i++)
		{
			//iPrintLnBold("^3Eval player for score screen: " + players[i].playername);
			if(ugxm_util::compareStringNumbers(players[i].chaosscore_string, first) > 0)
			{
				//Shift everyone else down a position.
				if(isDefined(level.ugxm_chaosmode_medals["last_place"])) level.ugxm_chaosmode_medals["last_place"] = level.ugxm_chaosmode_medals["third_place"];
				if(isDefined(level.ugxm_chaosmode_medals["third_place"])) level.ugxm_chaosmode_medals["third_place"] = level.ugxm_chaosmode_medals["second_place"];
				if(isDefined(level.ugxm_chaosmode_medals["second_place"])) level.ugxm_chaosmode_medals["second_place"] = level.ugxm_chaosmode_medals["first_place"];

				level.ugxm_chaosmode_medals["first_place"] = players[i];
				first = level.ugxm_chaosmode_medals["first_place"].chaosscore_string;

				//iPrintLnBold("^5New First place: " + level.ugxm_chaosmode_medals["first_place"].playername + " @ " + first);
			}
			else if(ugxm_util::compareStringNumbers(players[i].chaosscore_string, second) > 0 || players.size >= 2)
			{
				//Shift everyone else down a position.
				if(isDefined(level.ugxm_chaosmode_medals["last_place"])) level.ugxm_chaosmode_medals["last_place"] = level.ugxm_chaosmode_medals["third_place"];
				if(isDefined(level.ugxm_chaosmode_medals["third_place"])) level.ugxm_chaosmode_medals["third_place"] = level.ugxm_chaosmode_medals["second_place"];

				level.ugxm_chaosmode_medals["second_place"] = players[i];
				second = level.ugxm_chaosmode_medals["second_place"].chaosscore_string;
				//iPrintLnBold("^5New Second place: " + level.ugxm_chaosmode_medals["second_place"].playername + " @ " + second);
			}
			else if(ugxm_util::compareStringNumbers(players[i].chaosscore_string, third) > 0 || players.size >= 3)
			{
				//Shift everyone else down a position.
				if(isDefined(level.ugxm_chaosmode_medals["last_place"])) level.ugxm_chaosmode_medals["last_place"] = level.ugxm_chaosmode_medals["third_place"];

				level.ugxm_chaosmode_medals["third_place"] = players[i];
				third = level.ugxm_chaosmode_medals["third_place"].chaosscore_string;
				//iPrintLnBold("^5New Third place: " + level.ugxm_chaosmode_medals["third_place"].playername + " @ " + third);
			}
			else 
			{
				level.ugxm_chaosmode_medals["last_place"] = players[i];
				last = level.ugxm_chaosmode_medals["last_place"].chaosscore_string;
				//iPrintLnBold("^5Last place: " + level.ugxm_chaosmode_medals["last_place"].playername + " @ " + last);
			}
		}
	}

	for(i=0; i<players.size; i++)
	{
		for(k=0; k<players.size; k++)
		{
			if(players.size > 1)
			{
				//if(isDefined(level.ugxm_chaosmode_medals["first_place"])) players[i] setClientDvar("ugxm_player_" + level.ugxm_chaosmode_medals["first_place"] GetEntityNumber() + "_medal", "ugxm_1st_place");
				//if(isDefined(level.ugxm_chaosmode_medals["second_place"])) players[i] setClientDvar("ugxm_player_" + level.ugxm_chaosmode_medals["second_place"] GetEntityNumber() + "_medal", "ugxm_2nd_place");
				//if(isDefined(level.ugxm_chaosmode_medals["third_place"])) players[i] setClientDvar("ugxm_player_" + level.ugxm_chaosmode_medals["third_place"] GetEntityNumber() + "_medal", "ugxm_3rd_place");
				//if(isDefined(level.ugxm_chaosmode_medals["last_place"])) players[i] setClientDvar("ugxm_player_" + level.ugxm_chaosmode_medals["last_place"] GetEntityNumber() + "_medal", "blank");
			}
		}
	}
} //Desc figures out who's in first, second, third, and last place, then sets the dvars accordingly to display medals by names on HUD.
function updateMultiplier(multi)
{ //Call on: Player 
	if(multi > self.highest_multiplier) self.highest_multiplier = multi;
	if(isDefined(self.chaos_mutli))
	{		
		self.chaos_mutli setText("x" + multi);
		self.chaos_mutli.alpha = 0.85;
		self.chaos_mutli.fontscale = 3.8;
		//self.chaos_mutli.label = "x"; //no longer a functionality in BO3??
		wait 0.125;
		self.chaos_mutli.fontscale = 3.3;
		wait 0.125;
		self.chaos_mutli.fontscale = 2.7;
	}
} //Desc: Updates the value of the client's multiplier HUD. Generally you want to use increaseScoreMultiplier() to invoke this function rather than calling it alone.

function increaseScoreMultiplier()
{ //Call on: Player 
	multi = self.chaos_multiplier + 1;
	self.lastMultiplierTime = getTime();
	self thread createStreakBar();
	self createMultiplier();
	self createRawScore();
	self thread updateMultiplier(multi);
	self.chaos_multiplier = multi;

	//Since CoD5 only supports signed 32 bit ints, you cant store a number larger than +-2,147,483,647. So to get around this, I'm storing each digit as a separate int in an array, and then combining them as a string for the HUD
	number = [];
	number_string = "";
	amount = safeMultiplyToNum(self.rawscore, multi); //h ow much we are adding to their overall score
	if(amount == "0" || amount == "")  //they lost their combo, don't reset their score but update the hud for coop.
	{	
		return; 
	}
	//if(multi <= 0) return; //they lost their combo, don't reset their score.

	length = amount.size;

	//iPrintLnBold("^5Score increase==============");
	//iPrintLnBold("> Amount: " + amount);

	if(self.chaosscore_string != "") self.old_chaosscore_string = self.chaosscore_string; //saves the string while it is erased in case the game ends while it's still erased...
	self.chaosscore_string = safeAddToNum(self.chaosscore_string, amount);

	self updateChaosHUD();
} //Desc: ++increments the value of the client's multiplier and then invokes all necessary HUD updates
function safeMultiplyToNum(arg1, arg2)
{ //Call on: N/A
	arg1 = ugxm_util::string(arg1);
	arg2 = ugxm_util::string(arg2);
	length = arg1.size;

	if(arg2.size != arg1.size) //easier to just pad the shorter arg with leading zeros.
	{
		if(arg1.size < arg2.size)
		{
			difference = arg2.size - arg1.size;
			zeros = "";
			for(i=0;i<difference;i++)
				zeros = zeros + "0";
			arg1 = zeros + arg1;
			length = arg2.size;
		}
		else
		{
			difference = arg1.size - arg2.size;
			zeros = "";
			for(i=0;i<difference;i++)
				zeros = zeros + "0";
			arg2 = zeros + arg2;
			length = arg1.size;
		}
		
	}

	//iPrintLnBold("^3safeMultiplyToNum==============");
	//iPrintLnBold("> param 1: " + arg1);
	//iPrintLnBold("> param 2: " + arg2);

	finalSums = [];
	
	for(i=length; i>0; i--)
	{
		carryOut = 0;
		finalDigit = "";
		finalString = "";
		currentArg1 = getSubStr(arg1, i - 1, i);
		if(currentArg1 == "") currentArg1 = "0";

		//printLn("> ^2Running against this digit of arg1: " + currentArg1);

		for(k=length; k>0; k--)
		{
			currentArg2 = getSubStr(arg2, k - 1, k);
			if(currentArg2 == "") currentArg2 = "0";

			//printLn("> Performing new multiplication: " + currentArg1 + " x " + currentArg2 + " | " + carryOut);	

			remainder = 0;
			multiplication = int(currentArg1) * int(currentArg2);
			if(carryOut > 0)
			{
				multiplication = multiplication + carryOut;
				carryOut = 0;
			}

			if(multiplication > 9)
			{
				//printLn(">> total after num to mult is greater than 9 (" + multiplication + ")");
				multiplication = ugxm_util::string(multiplication);
				carryOut = int(multiplication[0]);
				//printLn(">> carryOut: " + carryOut);
				for(m=1;m<multiplication.size;m++)
						remainder = remainder + int(multiplication[m]);

				//printLn(">> remainder: " + remainder);

				finalDigit = ugxm_util::string(remainder);
				if(k == 1 && carryOut > 0)
				{
					finalDigit = multiplication;
					//printLn(">> last digit is being worked on, add carryout to remainder! | " + multiplication);
				}
			}
			else
			{
				//printLn(">> total after num to multi is less than or equal to 9 (" + multiplication + ")");
				finalDigit = multiplication;
			}
			finalString = finalDigit + finalString;
		}

		zeros = "";
		for(j=0;j<finalSums.size;j++)
			zeros = zeros + "0";
		finalSums[finalSums.size] = finalString + zeros;
		//printLn(">> ^5Result string: " + finalString + zeros);
	}

	total = "";
	for(i=0;i<finalSums.size;i++)
		total = safeAddToNum(total, finalSums[i]);

	//iPrintLnBold(">> MULT RESULT: " + trimLeadingZeros(total));

	return trimLeadingZeros(total);
} //Desc: Multiplies two string numbers and returns the string result;
function safeAddToNum(originalSafeTotal, amount) //REQUIEM-231
{ //Call on: N/A
	amount = ugxm_util::string(amount);
	if(amount == "") amount = "0";
	if(IsInt(amount)) amount = amount + " ";
	if(IsInt(originalSafeTotal)) originalSafeTotal = originalSafeTotal + " ";
	if(originalSafeTotal == "") originalSafeTotal = "0";
	length = amount.size;

	if(originalSafeTotal.size != amount.size) //easier to just pad the shorter arg with leading zeros.
	{
		if(amount.size < originalSafeTotal.size)
		{
			difference = originalSafeTotal.size - amount.size;
			zeros = "";
			for(i=0;i<difference;i++)
				zeros = zeros + "0";
			amount = zeros + amount;
			length = originalSafeTotal.size;
		}
		else
		{
			difference = amount.size - originalSafeTotal.size;
			zeros = "";
			for(i=0;i<difference;i++)
				zeros = zeros + "0";
			originalSafeTotal = zeros + originalSafeTotal;
			length = amount.size;
		}
		
	}

	
	//iPrintLnBold("^5safeAddToNum==============");
	//iPrintLnBold("> Amount param to add: " + amount);
	//iPrintLnBold("> ...adding to: " + originalSafeTotal);
	

	finalString = "";
	finalDigit = "";
	carryOut = 0;
	for(i=length; i>0; i--)
	{
		currentNum = getSubStr(amount, i - 1, i);
		if(currentNum == "") currentNum = "0";
		originalSafeNum = getSubStr(originalSafeTotal, i - 1, i);
		if(originalSafeNum == "") originalSafeNum = "0";

		//printLn("> Performing new addition: " + currentNum + " + " + originalSafeNum + " | " + carryOut);	
		
		remainder = 0;
		addition = int(currentNum) + int(originalSafeNum);
		if(carryOut > 0)
		{
			addition = int(currentNum) + carryOut + int(originalSafeNum);
			carryOut = 0;
		}

		if(addition > 9)
		{
			//printLn(">> total after num to add is greater than 9 (" + addition + ")");
			addition = ugxm_util::string(addition);
			carryOut = int(addition[0]);
			//printLn(">> carryOut: " + carryOut);
			for(k=1;k<addition.size;k++)
				remainder = remainder + int(addition[k]);
			//printLn(">> remainder: " + remainder);

			finalDigit = ugxm_util::string(remainder);
			if(i == 1 && carryOut > 0)
			{
				finalDigit = addition;
				//printLn(">> last digit is being worked on, add carryout to remainder!");
			}
		}
		else
		{
			//printLn(">> total after num to add is less than or equal to 9 (" + addition + ")");
			finalDigit = addition;
		}
		finalString = finalDigit + finalString;
	}

	//iPrintLnBold(">> ADD RESULT: " + trimLeadingZeros(finalString));
	return trimLeadingZeros(finalString);
} //Desc: Safely adds a numerical value to a numerical total without having to worry about exceeding MAX_INT. Currently there is no need to worry about the amount param being greater than MAX_INT. Time to reinvent a fucking addition calculator -_-
function trimLeadingZeros(input)
{ // Call on: N/A
	input = ugxm_util::string(input);
	if(input == "" || input == " ") return input;

	output = "";
	for(i=0;i<input.size;i++)
	{
		if(input[i] != "0")
		{
			output = getSubStr(input, i, input.size);
			break; //break if we don't find a leading zero right away, or break once we've hit them all.
		}
	}
	return output;
} //Desc: Trims off leading zeros from string-formatted numbers, then returns the trimmed result.

function scoreMultiplierMonitor()
{ //Call on: Player 
	level endon("end_game");
	self endon("disconnect");
	self giveSelfRevive(3); //start them with 3 self-revives
	timeout = level.ugxm_chaos["multi_timeout"] * 1000; //timeout in ms	
	while(1)
	{
		wait 0.2;

		if(!isDefined(timeout)) //UGXMBO3-58
			timeout = level.ugxm_chaos["multi_timeout"] * 1000; //timeout in ms	

		//Multiplier Lost!
		if(self.chaos_multiplier != 1 && (getTime() - self.lastMultiplierTime >= timeout) && !self.combofrozen)
		{
			self destroyChaosHUD();
			self.rawscore = 0;
			self loseAllPerks();
			self hideComboFeed();
			self.chaos_multiplier = 1;
			self thread ugxm_util::play_pooled_announcer_vox("combo_lost");
			players = getPlayers();
			//for(i=0;i<players.size;i++)
			//	for(k=0;k<players.size;k++)
			//		players[i] setClientDvar("ugxm_player_" + k + "_miniscore", commaFormat(players[k].chaosscore_string) + " | " + players[k].chaos_multiplier + "x");
		}
	}
} //Desc: Monitors the player's multiplier streaks, and terminates it if it times out

function giveComboFreeze()
{ //Call on: Player
	/*
	level endon("end_game");
	if(self hasWeapon("zombie_knuckle_crack")) return;
	self giveWeapon("zombie_knuckle_crack");
	self SetWeaponAmmoClip("zombie_knuckle_crack", 1);
	self SetActionSlot(2, "weapon","zombie_knuckle_crack");
	lastweapon = self getCurrentWeapon();
	while(1)
	{
		self waittill("weapon_change");
		weapon = self getCurrentWeapon();
		if(weapon == "zombie_knuckle_crack")
		{
			self takeWeapon(weapon);
			self SetActionSlot(2, "");
			self thread freezeComboBar();
			self switchToWeapon(lastweapon);
			break;
		}
		else lastweapon = weapon;
	}
	*/
} //Desc: Add a combo freeze to the player's inventory and waits for them to use it.
function freezeComboBar()
{ //Call on: Player
	self thread createStreakBar();
	self notify("create_new_streakbar");
	self.combofrozen = true;
	self.chaos_streakbar.bar.color = (0, 1, 1);
	self.chaos_streakbar.bar scaleOverTime( 0.01, level.primaryProgressBarWidth, self.chaos_streakbar.height );
	wait level.ugxm_chaos["combofreeze_length"];
	self.combofrozen = false;
	self thread createStreakBar();
} //Desc: Freezes the combo timeout bar

function zombieKilled()
{ //Call on: None 
	level endon("end_game");
	lastkilltime = 0;
	while(1)
	{
		level waittill("zombie_died", zombie, forcedPlayer); //REQUIEM-157
		time = getTime();
		timeout = level.ugxm_chaos["ks_timeout"] * 1000; //ms
		if((isDefined(forcedPlayer) && isPlayer(forcedPlayer)) || (isDefined(zombie.attacker) && isPlayer(zombie.attacker)))
		{
			player = zombie.attacker;
			hitlocation = zombie.damagelocation;
			mod = zombie.damagemod;
			weapon = zombie.damageweapon;
			distance = distance(zombie.origin, player.origin);
			thread dropDogTags(zombie.origin);
			scorebonus = 0;

			if(isDefined(forcedPlayer) && isPlayer(forcedPlayer)) 
			{
				player = forcedPlayer;
				mod = "MOD_BULLET";
			}

			// Reward Types, in order of value (most valuable will be rewarded in a case where multiple types are triggered in one kill)
			if(mod == "MOD_GRENADE" || mod == "MOD_PROJECTILE")
			{
				player combofeed("Grenade +400");
				scorebonus += 400;
			}
			else if(isDefined(hitlocation) && (hitlocation == "head" || hitlocation == "helmet"))
			{
				player combofeed("Headshot +300");
				scorebonus += 300;
			}
			else if(isDefined(distance) && (distance >= level.ugxm_chaos["longshot_dist"]))
			{
				player combofeed("Longshot +150");
				scorebonus += 150;
			}
			else if(mod == "MOD_MELEE")
			{
				player combofeed("Stab +150");
				scorebonus += 150;
			}
			else
			{
				player combofeed("Regular Kill +50");
				scorebonus += level.ugxm_chaos["kill_score"];
			}

			//Did they continue a killstreak?
			if(time - player.lastkilltime <= timeout && player.killstreak_count < 5)
				player.killstreak_count++;

			player updateRawScore(scorebonus);
			player increaseScoreMultiplier();
			player.lastkilltime = time;
		}
	}
} //Desc: Waits for the killed zombie level notify, then processes any client rewards for the kill. Invokes all required value and HUD updaters.
function dropDogTags(pos)
{ //Call on: None | Args: Origin 
	level endon("end_game");
	
	zone = zm_zonemgr::get_zone_from_position(pos, true);
	if(!isDefined(zone))
		return;

	pos = ugxm_util::playergroundpos(pos + (0,0,0));
	tags = spawn("script_model", pos + (0,0,40));
	tags setModel("p7_dogtags_enemy");
	tags thread dogTagsFloat();
	time = 0;
	while (isdefined(tags))
	{
		if(time >= 45) //45 second timeout, don't want unlimited tags otherwise gSpawn limit is a potential problem
		{
			tags notify ("powerup_grabbed");
			tags delete();
		}
		else
		{
			players = getPlayers();

			for (i = 0; i < players.size; i++)
			{
				if (isDefined(distance (players[i].origin, tags.origin)) && distance (players[i].origin, tags.origin) < 64)
				{
					players[i] playlocalsound("dogtags_rattle");
					wait 0.1;
					players[i] increaseScoreMultiplier();
					players[i] thread comboannounce("Tags Grabbed!");
					tags notify ("powerup_grabbed");
					tags delete();
					
				}
			}
		}
		time += 0.1;
		wait 0.1;
	}
} //Desc: Spawns a dogtag at the specified position.
function dogTagsFloat()
{ //Call on: Ent 
	self endon ("powerup_grabbed");
	level endon("end_game");

	while (isdefined(self))
	{
		waittime = randomfloatrange(2.5, 5);
		yaw = RandomInt( 360 );
		if( yaw > 300 )
		{
			yaw = 300;
		}
		else if( yaw < 60 )
		{
			yaw = 60;
		}
		yaw = self.angles[1] + yaw;
		self rotateto ((-60 + randomint(120), yaw, -45 + randomint(90)), waittime, waittime * 0.5, waittime * 0.5);
		wait randomfloat (waittime - 0.1);
	}
} //Desc: Spins/floats the dogtag drops until they are grabbed.

function killcomboMonitor()
{ //Call on: Player 
	self endon("disconnect");
	level endon("end_game");

	while(1)
	{
		time = getTime();
		timeout = level.ugxm_chaos["ks_timeout"] * 1000; //ms
		scorebonus = 0;
		if(time - self.lastkilltime > timeout || self.killstreak_count >= 5)
		{
			if(self.killstreak_count == 5)
			{
				self combofeed("Multi Kill +1000");
				self thread comboannounce("Multi Kill +1000");
				self thread ugxm_util::play_pooled_announcer_vox("multi_kill");
				scorebonus += 1000;
			}
			else if(self.killstreak_count == 4)
			{
				self combofeed("Quad Kill +800");
				self thread comboannounce("Quad Kill +800");
				self thread ugxm_util::play_pooled_announcer_vox("quad_kill");
				scorebonus += 800;
			}
			else if(self.killstreak_count == 3)
			{
				self combofeed("Triple Kill +600");
				self thread comboannounce("Triple Kill +600");
				self thread ugxm_util::play_pooled_announcer_vox("triple_kill");
				scorebonus += 600;
			}
			self.killstreak_count = 0;
			self updateRawScore(scorebonus);
		}
		wait 0.1;
	}
} //Desc: Monitors the player's kill combos, and terminates it if it times out
function nukedMonitor()
{ //Call on: Player
	level endon("end_game");
	self endon("disconnect");
	while(1)
	{
		self waittill("nuke_triggered");
		/# self iPrintLnBold(self.zombie_nuked.size + " nuked"); #/
		for(i=0;i<self.zombie_nuked.size;i++)
		{ 
			wait randomFloatRange(0.1, 0.5);
			self increaseScoreMultiplier();
		}
		wait 1;
		self thread ugxm_util::play_pooled_announcer_vox("holy_shit");
	}
} //Desc: Waits for nuke notify, then increases score multiplier by how many zombies have been nuked.

//////////|Perks|\\\\\\\\\\
function perkMonitor()
{ //Call on: Player 
	level endon("end_game");
	self endon("disconnect");
	while(1)
	{
		if ((self flag::exists( "in_beastmode" )) && (self flag::get( "in_beastmode" )))
		{
			iPrintLnBold("Beast Mode is not allowed outside of the Classic Gamemode!");
			wait 2.5;
			level notify("end_game");
		}

		streak = self.chaos_multiplier;
		if(streak >= 20 && !self hasPerk(PERK_SLEIGHT_OF_HAND))
		{
			self thread comboannounce("Sleight of Hand!", (0,1,1));
			self chaos_setPerK(PERK_SLEIGHT_OF_HAND);
		}
		if(streak >= 40 && !self hasPerk(PERK_DOUBLETAP2))
		{
			self thread comboannounce("Double-Tap 2.0!", (0,1,1));
			self chaos_setPerK(PERK_DOUBLETAP2);
		}
		if(streak >= 60 && !self hasPerk(PERK_STAMINUP))
		{
			self thread comboannounce("Stamin-Up!", (0,1,1));
			self chaos_setPerK(PERK_STAMINUP);
		}
		if(streak >= 80 && !self hasPerk(PERK_DEAD_SHOT))
		{
			self thread comboannounce("Deadshot!", (0,1,1));
			self chaos_setPerK(PERK_DEAD_SHOT);
		}
		//if(streak >= 100 && !self hasPerk("specialty_extraammo"))
		//{
		//	self thread comboannounce("Bandolier!", (0,1,01));
		//	//self setClientDvar("player_clipSizeMultiplier", 1.5);
		//	//@todo
		//	self chaos_setPerK("specialty_extraammo");
		//}
		if(streak >= 100 && (!self hasPerk(PERK_JUGGERNOG) || self.maxhealth != level.zombie_vars["zombie_perk_juggernaut_health"]))
		{
			if(!self hasPerk(PERK_JUGGERNOG)) self thread comboannounce("Juggernaut!", (0,1,1));
			self chaos_setPerK(PERK_JUGGERNOG);
		}
		wait 0.1;
	}
} //Desc: Actively gives the player a specific perk which corresponds to their current multiplier
function chaos_setPerK(perk)
{ //Call on: Player | Args: String 
	if(!isDefined(self.chaos_perk_index)) self.chaos_perk_index = 0;
	if(!isDefined(self.chaos_perks)) self.chaos_perks = [];


	if(perk == PERK_JUGGERNOG && self hasPerk(PERK_JUGGERNOG)) //REQUIEM-213 they went into laststand which altered their health, don't give them a second jugg icon
	{
		self zm_perks::perk_set_max_health_if_jugg( PERK_JUGGERNOG, true, false );
		return;
	}

	self setPerk(perk);

	if(perk == PERK_JUGGERNOG)
	{
		self zm_perks::perk_set_max_health_if_jugg( PERK_JUGGERNOG, true, false );
	}

	self thread ugxm_util::play_pooled_announcer_vox("perk_acquired");

	self zm_perks::set_perk_clientfield( perk, PERK_STATE_OWNED );

	self.chaos_perks[self.chaos_perks.size] = true;
	self.chaos_perk_index++;
} //Desc: Sets a perk on the player, then creates the hudelem for the shader.
function giveSelfRevive(amount)
{ //Call on: Player | Args: Int 
	if(!isDefined(amount)) amount = 1;
	if(!isDefined(self.chaos_self_revive_count)) self.chaos_self_revive_count = 0;
	self.chaos_self_revive_count += amount;
	//self setClientDvar("ugxm_chaosrevive", self.chaos_self_revive_count);
	//self setClientDvar("ugxm_chaosrevive_visible", 1);
} //Desc: Adds the specified amount of self-revives to the client's total.
function chaosSelfRevive()
{ //Call on: Player 
	level endon("end_game");
	self endon("disconnect");
	while(1)
	{
		self util::waittill_any("player_downed", "gungame_death");
		if(self.chaos_self_revive_count > 0)
			giveSelfRevive(-1); //actual revive is in maps\_zombiemode::ugxm_self_revive() called by player_damage_override();
	}
} //Desc: Decrements the client's total self-revives by one. Actual revive is handled in _zombiemode.gsc
function loseAllPerks()
{ //Call on: Player 
	self unsetPerk(PERK_SLEIGHT_OF_HAND);
	self zm_perks::set_perk_clientfield( PERK_SLEIGHT_OF_HAND, PERK_STATE_NOT_OWNED );
	self unsetPerk(PERK_DOUBLETAP2);
	self zm_perks::set_perk_clientfield( PERK_DOUBLETAP2, PERK_STATE_NOT_OWNED );
	self unsetPerk(PERK_STAMINUP);
	self zm_perks::set_perk_clientfield( PERK_STAMINUP, PERK_STATE_NOT_OWNED );
	self unsetPerk(PERK_DEAD_SHOT);
	self zm_perks::set_perk_clientfield( PERK_DEAD_SHOT, PERK_STATE_NOT_OWNED );
	self unsetPerk("specialty_extraammo");
	self unsetPerk(PERK_JUGGERNOG);
	self zm_perks::set_perk_clientfield( PERK_JUGGERNOG, PERK_STATE_NOT_OWNED );
	//self setClientDvar("player_sprintSpeedScale", 1.5);
	//self setClientDvar("player_clipSizeMultiplier", 1);

	self zm_perks::perk_set_max_health_if_jugg( "health_reboot", true, true );

	self.chaos_perk_index = 0;
	for(i=0; i<self.chaos_perks.size;i++)
		self.chaos_perks[i] ugxm_util::destroy_hud();
	self.chaos_perks = [];
} //Desc: Remove all perks from the player, generally called upon multiplier timeout. Also clears all perk hudelems
function destroyChaosHUD()
{ //Call on: Player 
	if(isDefined(self.chaos_streakbar)) self.chaos_streakbar ugxm_util::destroyElem();
	if(isDefined(self.chaos_mutli)) self.chaos_mutli destroy();
	//self setClientDvar("ugxm_chaosraw_client_vis", 0);
} //Desc: Removes relevant chaos hudelems from client.

//////////|Combo Feed/Announce|\\\\\\\\\\
function comboannounce(text, color)
{ //Call on: Player | Args: String 
	self notify("new_comboannounce");
	self endon("new_comboannounce");
	if(isDefined(self.combo_announce_hud)) self.combo_announce_hud destroy();
	self.combo_announce_hud = newScoreHudElem(self);
	self.combo_announce_hud.hidewheninmenu = true;
	self.combo_announce_hud.horzAlign = "center";
	self.combo_announce_hud.vertAlign = "middle";
	self.combo_announce_hud.alignX = "center";
	self.combo_announce_hud.alignY = "middle";
	self.combo_announce_hud.x = 0;
	self.combo_announce_hud.y = -155;
	self.combo_announce_hud.font = "big";
	self.combo_announce_hud.fontscale = 3;
	self.combo_announce_hud.archived = false;
	self.combo_announce_hud.alpha = 0;
	if(isDefined(color)) self.combo_announce_hud.color = color;
	else self.combo_announce_hud.color = (1, 1, 0);
	self.combo_announce_hud setText(text);
	self.combo_announce_hud fadeOverTime(0.5);
	self.combo_announce_hud.alpha = 1;
	wait 1.5; 
	self.combo_announce_hud fadeOverTime(0.25);
	self.combo_announce_hud MoveOverTime(0.5);
	self.combo_announce_hud.alpha = 0;
	self.combo_announce_hud.y = -400;
	wait 0.5;
	if(isDefined(self.combo_announce_hud)) self.combo_announce_hud destroy();
} //Desc: Display the specified text as a notification on the top center of the client's screen.
function comboannounce_monitor()
{ //Call on: Player
	level endon("end_game");
	self endon("disconnect");
	while(1)
	{
		self waittill("comboannounce", msg, color);
		if(!isDefined(color)) color = (1,1,1);
		self thread comboannounce(msg, color);
	}
} //Desc: I need to be able to call this func from zombiemode_powerups to tell player he lost points etc. Instead of having external calls to this function, I use notifies to avoid the precache limit of funcs.
function combofeed(text)
{ //Call on: Player | Args: String 
	pushBackCombofeed();
	self.ugxm_combofeed[0] = text;
	//self setClientDvar("ugxm_combofeed_0", text);
	//self setClientDvar("ugxm_combofeed_visible", 1);
} //Desc: Display the specified text as a notification in the right center of the client's screen.
function pushBackCombofeed()
{ //Call on: Player 
	players = getplayers();
	for(i = self.ugxm_combofeed.size - 1; i > 0; i--)
	{
		self.ugxm_combofeed[i] = self.ugxm_combofeed[i - 1];
		//self setClientDvar("ugxm_combofeed_" + i, self.ugxm_combofeed[i]); 
	}
} //Desc: Used for stacking combofeed messages - adds the newest combofeed message to the beginning of the array, pushing the rest back. The last entry of the array is overwritten.
function hideComboFeed()
{ //Call on: Player 
	//self setClientDvar("ugxm_combofeed_visible", 0);
	self.ugxm_combofeed[0] = " ";
	self.ugxm_combofeed[1] = " ";
	self.ugxm_combofeed[2] = " ";
	self.ugxm_combofeed[3] = " ";
	self.ugxm_combofeed[4] = " ";
} //Desc: Hides the combofeed for the client via dvar.

//////////|Care Packages|\\\\\\\\\\
function carePackageDropper()
{ //Call on: None 
	level endon("end_game"); 
	level.ugxm_chaos["pkgs_on_map"] = 0;
	while(1)
	{
		timer = 0;
		if(level.ugxm_chaos["pkgs_on_map"] < level.ugxm_chaos["max_care_pkgs"])
		{
			thread dropCarePackage();

			waittime =  level.ugxm_chaos["pkg_drop_interval"] + randomIntRange(-15, 15);
			/# waittime = 1; #/
			while(waittime - timer > 0)
			{
				wait 1;
				timer++;
			}
		}
		wait 0.1;
	}
} //Desc: Drops a care package every 15-45 seconds when less than the max number are spawned.
function dropCarePackage()
{ //Call on: None 
	level.ugxm_chaos["pkgs_on_map"]++;
	level.ugxm_chaos["total_pkgs_dropped"]++;
	pkg = spawn("script_model", getValidRandomSpawnpoint() + (0,0,60));
	pkg setModel("ugx_care_package");
	pkg physicsLaunch(pkg.origin, (0, 0, 0)); //drop it to the ground
	pkg determineCarePackageContents();
	wait 1; //wait for it to drop
	pkg.grabTrig = spawn("trigger_radius", pkg.origin, 0, 50, 100);
	pkg.grabTrig setHintString("Press &&1 for Bonus Pickup: " + pkg.contentsString);
	pkg.grabTrig setCursorHint("HINT_NOICON");
	pkg.grabTrig EnableLinkTo();
	pkg.grabTrig LinkTo(pkg); 

	//pkg.lightfx = Spawn( "script_model", self.origin );
	//pkg.lightfx.angles = self.angles + (-90, 0, 0);
	//pkg.lightfx SetModel( "tag_origin" );
	//playfxontag(level._effect["lght_marker"], pkg.lightfx, "tag_origin");
	
	//pkg setWayPointHUD("waypoint_" + pkg.reward, pkg.origin[2], (1, 1, 0));
	
	objPoint = newHudElem();
	objPoint.x = pkg.origin[0];
	objPoint.y = pkg.origin[1];
	objPoint.z = pkg.origin[2] + (30);
	objPoint.isFlashing = false;
	objPoint.isShown = true;
	objPoint.fadeWhenTargeted = true;
	objPoint.archived = false;
	objPoint.alpha = 1;
	
	objPoint setShader( "ugxm_" + pkg.reward, level.objPointSize, level.objPointSize );
	objPoint setWaypoint( true, "ugxm_" + pkg.reward );

	while(1)
	{
		pkg.grabTrig waittill("trigger", player);
		//if(player in_revive_trigger()) continue;

		//if(is_player_valid(player) && player useButtonPressed())
		if(player useButtonPressed())
		{
			player giveCarePackageReward(pkg.reward);
			player combofeed("Care Package +500");
			player updateRawScore(500);
			player increaseScoreMultiplier();
			player increaseScoreMultiplier();
			player.health = player.maxhealth; //Care Packages award full health.
			level.ugxm_chaos["pkgs_on_map"]--;
			break;
		}
	}
	objPoint setWayPoint(false);
	objPoint Destroy();
	pkg removeCarePackage();
} //Desc: Spawns a care package at a random location on the map.
function determineCarePackageContents()
{ //Call on: Ent 
	rand = randomInt(15);
	switch(rand)
	{
		case 11:	
		case 10:
		case 9:
			self.contentsString = "Bonus Points (+10,000)";
			self.reward = "10k";
				break;
		case 8:
		case 7:
		case 6:
		//	self.contentsString = "Combo Freezer"; //@todo
		//	self.reward = "snowflake";
		//		break;
		case 5:
		//case 4:
		//	self.contentsString = "Sentry Gun";
	//		self.reward = "sentry";
	//			break;
		case 3:
		case 2:
			self.contentsString = "Extra Time (+60sec)";
			self.reward = "60sec";
				break;
		case 1:
		case 0:
			self.contentsString = "Extra Self-Revive";
			self.reward = "selfrevive";
				break;
		default:
			self.contentsString = "Bonus Points (+5,000)";
			self.reward = "5k";
				break;
	}
} //Desc: Chooses the reward assigned to the care package.
function giveCarePackageReward(reward)
{ //Call on: Player 
	switch(reward)
	{
		case "5k":
			self updateRawScore(5000);
			self thread comboannounce("5k Points Bonus!", (0,1,0));
			self thread ugxm_util::play_pooled_announcer_vox("points_bonus");
			break;
		case "10k":
			self updateRawScore(10000);
			self thread comboannounce("10k Points Bonus!", (0,1,0));
			self thread ugxm_util::play_pooled_announcer_vox("points_bonus");
			break;
		case "snowflake":
			self thread giveComboFreeze();
			self thread comboannounce("Combo Freezer!", (0,1,0));
			self thread ugxm_util::play_pooled_announcer_vox("combo_freezer");
			break;
		case "sentry":
			self thread comboannounce("Sentry Gun!", (0,1,0));
			//thread maps\ugxm_powerups::sentry_gun(self, false);
			self thread ugxm_util::play_pooled_announcer_vox("sentry_gun");
			self thread monitorTurretKills();
			break;
		case "60sec":
			self thread comboannounce("Time Extension!", (0,1,0));
			self thread ugxm_util::play_pooled_announcer_vox("time_extension");
			level.tgTimerTime.seconds = level.tgTimerTime.seconds - 59;
			level.tgTimerTime.toalSec = level.tgTimerTime.toalSec - 59;
			thread recreateTimerHUD(level.ugxm_settings["game_time"] - level.tgTimerTime.toalSec);
			break;
		case "selfrevive":
			self thread comboannounce("Self-Revive!", (0,1,0));
			self ugxm_util::play_pooled_announcer_vox("self_revive");
			self giveSelfRevive();
			break;
	}
} //Desc: Give the player the reward assigned to the care package.
function monitorTurretKills()
{ //Call on: Player
	self.turret endon("death");
	self.turret endon("turret_deactivated");
	while(1)
	{
		self waittill("turret_killed_zombie", origin);
		self increaseScoreMultiplier();
	}
} //Desc: Handles multiplier increases from turrets and manually drops dogtags for killed zombies.
function recreateTimerHUD(time)
{ //Call on: None
	if(isDefined(level.tgTimer)) level.tgTimer Destroy();
	level.tgTimer = NewHudElem();
	level.tgTimer.foreground = false; 
	level.tgTimer.sort = 2; 
	level.tgTimer.hidewheninmenu = false; 
	level.tgTimer.font = "big";
	level.tgTimer.fontScale = 2.5;
	level.tgTimer.alignX = "center"; 
	level.tgTimer.alignY = "top";
	level.tgTimer.horzAlign = "center"; 
	level.tgTimer.vertAlign = "top";	
	level.tgTimer.x = 0; 
	level.tgTimer.y = 27; 
	level.tgTimer.alpha = 0;
	level.tgTimer SetTimer(time);
	level.tgTimer.alpha = 1;
} //Desc: Destroys the level.tgTimer HUD and recreates it with a new time. simply doing setTime on it is not reliable for some reason, probably because there is still an old thread running on it.
function removeCarePackage()
{ //Call on: Ent 
	if(isDefined(self.waypoint)) self.waypoint Destroy();
	self.grabTrig delete();
	self delete();
} //Desc: Despawns the specified care package.

//////////|Gun Spawning|\\\\\\\\\\
function initGunLocations()
{ //Call on: None 
	if(!isDefined(level.ugxm_chaos["gunspawns"])) level.ugxm_chaos["gunspawns"] = [];

	//if(level.ugxm_chaos["gun_location_count"] > 5) level.ugxm_chaos["gun_location_count"] = 5; //REQUIEM-224 more than 14 causes a G-spawn error apparently.

	/# iPrintLnBold("^5[DEBUG] Gun locations to spawn: " + level.ugxm_chaos["gun_location_count"]); #/

	//level.ugxm_chaos["gunspawns"] = struct::get_array( "start_zone_spawners", "targetname" );
	for(i=0;i<game["random_spawn_positions"].size; i++)
	{
		if(i > level.ugxm_chaos["gun_location_count"] || i > level.ugxm_chaos["gun_location_max"])
			break;

		point = game["random_spawn_positions"][i];

		if(is_point_in_history(point))
			continue;

		level.ugxm_chaos["used_nodes"][level.ugxm_chaos["used_nodes"].size] = point;

		level.ugxm_chaos["gunspawns"][i] = spawn("script_origin", point);
		level.ugxm_chaos["gunspawns"][i] thread createGunLocation();
		/#iPrintLnBold("^5[DEBUG] Gun spot spawned at " + level.ugxm_chaos["gunspawns"][i].origin); #/
	}	

} //Desc: Despawns any existing gun locations, then spawns a new random set
function createGunLocation()
{ //Call on: Ent 
	//self.weapon_name = weighted_choice(level.ugxm_lottery["weapon"]);
	self.weapon_ent = zm_magicbox::treasure_chest_ChooseWeightedRandomWeapon( getPlayers()[0] );
	self.weapon = zm_utility::spawn_weapon_model( self.weapon_ent, undefined, self.origin + (0,0,40), self.angles, undefined ); 
	self.grabTrig = spawn("trigger_radius", self.origin, 0, 50, 100);
	self.grabTrig setCursorHint("HINT_NOICON");
	self.grabTrig EnableLinkTo();
	self.grabTrig LinkTo(self); 
	self.weapon thread spinPickup();

	while(1)
	{
		//@fixme still don't know how to get a proper weapon name hintstring to show up even after looking through all the scripts. 
		//self.grabTrig setHintString("Press &&1 to grab " + self.weapon_ent.displayName);

		cursor_hint = "HINT_WEAPON";
		cursor_hint_weapon = self.weapon_ent;
		self.grabTrig setCursorHint( cursor_hint, cursor_hint_weapon ); 
		self.grabTrig TriggerEnable(true);

		level.ugxm_chaos["objective_index"]++;
		self thread gunspawnFX(true);
		self.weapon show();
		while(1)
		{
			self.grabTrig waittill("trigger", player);
			//if(player in_revive_trigger()) continue;

			//if(is_player_valid(player) && player useButtonPressed())
			if(player useButtonPressed())
			{
				player ugxm_util::weapon_give(self.weapon_ent, false);
				player combofeed("New Weapon +500");
				player updateRawScore(500);
				player increaseScoreMultiplier();
				player thread ugxm_util::play_pooled_announcer_vox("gun_acquired");
				break;
			}
		}
		self.weapon hide();
		self.grabTrig TriggerEnable(false);
		self thread gunspawnFX(false);
		wait level.ugxm_chaos["gun_cooldown_time"];
		//if(WeaponClass(self.weapon_name) == "grenade" || WeaponClass(self.weapon_name) == "item" || isDefined(level.ugxm_wonder[self.weapon_name]) || isDefined(level.ugxm_special[self.weapon_name])) //REQUIEM-232 change to a new item to prevent special weapon abuse
		//{
		//	self.weapon_name = "pistol_burst";
		//	self.weapon setModel(GetWeaponWorldModel(GetWeapon(self.weapon_name))); 
		//}
	}
	//thread moveAndRefreshGuns();
} //Desc: Spawns the gun model and trig at the location struct, then waits to be triggered. Gives the player the specified weapon.
function spinPickup()
{ //Call on: Ent 
	wait(randomFloatRange(0.1,1));
	while(isDefined(self))
	{
		self rotateyaw( 360, 3, 0, 0 );
		wait 2.9;
	}
} //Desc: 360-deg rotation for the weaponmodels of the gun spawns.
function gunspawnFX(active)
{ //Call on: Ent 
	
	if(isDefined(self.basefx)) self.basefx delete();
	if(isDefined(self.lightfx)) self.lightfx delete();

	//Sky FX
	if(active) 
	{
		self.lightfx = Spawn( "script_model", self.origin );
		self.lightfx.angles = self.angles + (-90, 0, 0);
		self.lightfx SetModel( "tag_origin" );
		playfxontag(level._effect["lght_marker"], self.lightfx, "tag_origin");
	}

	//Base FX
	fwd = ( 0, 0, 1 );
	right = ( 0, -1, 0 );
	
	self.basefx = SpawnFx( GUN_SPOT_FX, self.origin, fwd, right );
	TriggerFx( self.basefx, 0.001 );
	
} //Desc: Creates and triggers the oldchool-mode fx on the gun location

function getValidRandomSpawnpoint()
{
	points = array::randomize(game["random_spawn_positions"]);
	foreach(point in points)
	{
		if(!is_point_in_history(point))
		{
			return point;
		}
	}

	level.ugxm_chaos["used_nodes"] = []; //this might be because we ran out of unused nodes, clear the history!
	/# printLn("^1>>>> Ran out of spawnpoints for stuff! clearing the array!"); #/
	return getValidRandomSpawnpoint();
}
function is_point_in_history(point)
{
	if(!isDefined(level.ugxm_chaos["used_nodes"])) level.ugxm_chaos["used_nodes"] = [];

	if(game["random_spawn_positions"].size <= level.ugxm_chaos["gunspawns"].size)
	{
		level.ugxm_chaos["used_nodes"] = []; //this might be because we ran out of unused nodes, clear the history!
		/# printLn("^1>>>> Ran out of spawnpoints for stuff! clearing the array!"); #/
	}

	age_threshold = 10; //how old does a point have to be before it can be resused? - not implemented.
	for(i=0;i<level.ugxm_chaos["used_nodes"].size;i++)
		if(distance(level.ugxm_chaos["used_nodes"][i], point) < 10)
			return true; //point has been used.
	return false; //point has never been used.
}
