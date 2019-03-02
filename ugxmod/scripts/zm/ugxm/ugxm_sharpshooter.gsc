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
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;
#using scripts\zm\_zm_zonemgr;

#using scripts\shared\math_shared;

#using scripts\shared\ai\zombie_utility;
//#using scripts\mp\gametypes_zm\_globallogic;

//UGX
#using scripts\zm\ugxm\ugxm_util;

#define SHARPSHOOTER 3

REGISTER_SYSTEM( "ugxm_sharpshooter", &__init__, undefined )
function __init__()
{
	callback::on_spawned(&on_player_spawned_sharpshooter); //UGXMBO3-57
}

function prepare_sharpshooter()
{
	if(level.ugxm_settings["gamemode"] != SHARPSHOOTER)
		return;

	ugxm_util::game_setting("allow_ugx_bossround", false);
	ugxm_util::game_setting("allow_ugx_powerups", true);	
	ugxm_util::game_setting("allow_wall_guns", false);
	ugxm_util::game_setting("allow_mbox", false);
	ugxm_util::game_setting("allow_weap_cabinet", false);
	ugxm_util::game_setting("allow_pay_turrets", false);
	ugxm_util::game_setting("allow_perks", false);
	ugxm_util::game_setting("allow_pap", false);
	ugxm_util::game_setting("grenades_disallowed", true);
	ugxm_util::game_setting("dont_increase_zombie_health", true);

	ugxm_util::game_setting("allow_gobblegums", false);

	ugxm_util::powerup_setting("full_ammo", false);
	ugxm_util::powerup_setting("double_points", false);
	ugxm_util::powerup_setting("insta_kill", false);
	ugxm_util::powerup_setting("nuke", false);
	ugxm_util::powerup_setting("carpenter", false);
	ugxm_util::powerup_setting("fire_sale", false);
	ugxm_util::powerup_setting("bonfire_sale", false);
	ugxm_util::powerup_setting("free_perk", false);
	ugxm_util::powerup_setting("minigun", false);

	//UGXMBO3 Powerup Drops
	ugxm_util::powerup_setting("invulnerability", true);
	ugxm_util::powerup_setting("terminator", true);
	ugxm_util::powerup_setting("quickfoot", true);
	ugxm_util::powerup_setting("multiplier", true);
	ugxm_util::powerup_setting("killshot", true);
	ugxm_util::powerup_setting("gun_1up", false);
	ugxm_util::powerup_setting("points_1up", true);
	ugxm_util::powerup_setting("pap_gun_upgrade", true);

	level.gamemode_is_competative = true;
		
	if(getPlayers().size > 1)
		ugxm_util::powerup_setting("invisibility", true);

	level.ugxm_settings["endgame_text"] = "Sharpshooter Over!";

	thread ugxm_util::auto_doors_power_etc(false, true);
	thread init();
}

function init()
{
	//@todo
	//if(level.ugxm_settings["custom_guns"]) //Custom Sharpshooter, check for weapon filters
	//	level.ugxm_sharpshooter["guns"]	= getArrayKeys(level.ugxm_settings["gun_list_final"]);

	level.ugxm_sharpshooter["interval"] = 30;
	level.ugxm_sharpshooter["time_untill_switch"] = level.ugxm_sharpshooter["interval"];
	level.ugxm_sharpshooter["current_gun"] = "none";
	level.ugxm_sharpshooter["rounds_since_rankchange"] = 0;
	
	level.ugxm_sharpshooter["guns"] = getArrayKeys(level.ugxm_gungame["guns"]);

	if(level.ugxm_sharpshooter["guns"].size == 0)
		return;
	
	thread main();
	thread perks_zombie_kill_monitor();
	next_gun();
}

function on_player_spawned_sharpshooter()
{
	if(!level flag::get("voting_complete"))	
		level flag::wait_till("voting_complete");

	if(level.ugxm_settings["gamemode"] != SHARPSHOOTER)
		return;

	self.score = 0;
	self.score_total = 0;
	self.old_score = 0;
	self thread gunHandler();
	self perks_init();
}

function gunHandler()
{
	level endon("end_game");
	self endon("disconnect");
	self endon("ugxm_stop_forcing_weapon");
	
	while(1)
	{
		if(isDefined(self.ugxm_pause_forcing_weapons) && self.ugxm_pause_forcing_weapons)
		{
			self TakeAllWeapons();
			wait 0.1;
			continue;
		}
		
		list = self getWeaponsList(); for(i=0;i<list.size;i++) if(list[i].weapclass == "offhand") self takeWeapon(list[i]); //9/9/2013 - treminaor: universally take all offhand weapons, no naming required
		
		cw = self getCurrentWeapon();
		weapons = self GetWeaponsListPrimaries();
		
		gun = level.ugxm_sharpshooter["current_gun"];

		if(IS_TRUE(self.ugxm_gg_ss_temp_use_upgrade))
		{
			if(isDefined(level.zombie_weapons[gun.rootWeapon].upgrade))
				gun = level.zombie_weapons[gun.rootWeapon].upgrade;
		}
		
		if(weapons.size != 1 || cw.name != gun.name)
		{
			self TakeAllWeapons();
			self GiveWeapon(gun);
			self SwitchToWeapon(gun);
		}
		
		self giveMaxAmmo(cw);
		self AllowMelee( false );
		
		wait 0.1;
	}
}

function main()
{
	wait 0.4;
	level endon("end_game");
	
	level.ugxm_sharpshooter["next_switch_hud"] = ugxm_util::create_info_hud(undefined, "Time until next switch:", 0, (1,1,1));

	while(1)
	{
		if ((self flag::exists( "in_beastmode" )) && (self flag::get( "in_beastmode" )))
		{
			iPrintLnBold("Beast Mode is not allowed outside of the Classic Gamemode!");
			wait 2.5;
			level notify("end_game");
		}

		if(level.ugxm_sharpshooter["time_untill_switch"] < 1)
			level.ugxm_sharpshooter["time_untill_switch"] = 1;
		
		players = getPlayers();
		if(level.ugxm_settings["game_time"] != -1)
		{
			if(isDefined(level.tgTimerTime))
			{
				time_left = level.ugxm_settings["game_time"] - level.tgTimerTime.toalSec;
				
				if(time_left - 1 <= level.ugxm_sharpshooter["interval"]) // need -1 because for some reason the times are a little off, and it wont count it
				{
					level.ugxm_sharpshooter["next_switch_hud"] SetText("^5This is the last gun!");
					level.ugxm_sharpshooter["next_switch_hud_val"] ugxm_util::destroy_hud();
				}
			}
			else
			{
				if(isDefined(level.ugxm_sharpshooter["next_switch_hud_val"])) level.ugxm_sharpshooter["next_switch_hud_val"] ugxm_util::destroy_hud();
				level.ugxm_sharpshooter["next_switch_hud_val"] = ugxm_util::create_info_hud(undefined, level.ugxm_sharpshooter["interval"], 0, (0.1,0.688,0.903), 125 - 19, "timer");
			}
		}
		else
		{
			if(isDefined(level.ugxm_sharpshooter["next_switch_hud_val"])) level.ugxm_sharpshooter["next_switch_hud_val"] ugxm_util::destroy_hud();
			level.ugxm_sharpshooter["next_switch_hud_val"] = ugxm_util::create_info_hud(undefined, level.ugxm_sharpshooter["interval"], 0, (0.1,0.688,0.903), 125 - 19, "timer");
		}
		
		
		while(level.ugxm_sharpshooter["time_untill_switch"] > 0)
		{
			level.ugxm_sharpshooter["time_untill_switch"] -= 0.1;
			wait 0.1;
		}
		
		level.ugxm_sharpshooter["time_untill_switch"] = level.ugxm_sharpshooter["interval"];
		players = getPlayers();
		for(i=0;i<players.size;i++)
		{
			players[i].ugxm_gg_ss_temp_use_upgrade = false;
			players[i] thread ugxm_util::play_pooled_announcer_vox("switching_guns");
		}
		next_gun();
	}
}

function next_gun()
{
	if(!isDefined(level.ugxm_sharpshooter["history"])) level.ugxm_sharpshooter["history"] = [];
	if(level.ugxm_sharpshooter["history"].size >= level.ugxm_sharpshooter["guns"].size) level.ugxm_sharpshooter["history"] = []; //we've used every single gun, reset the history
	
	valid = false;
	while(!valid)
	{
		level.ugxm_sharpshooter["current_gun"] = level.ugxm_sharpshooter["guns"][RandomInt(level.ugxm_sharpshooter["guns"].size)];
		count = 0;
		for(i=0; i<level.ugxm_sharpshooter["history"].size; i++)
			if(level.ugxm_sharpshooter["history"][i] != level.ugxm_sharpshooter["current_gun"])
				count++;
	
		if(count >= level.ugxm_sharpshooter["history"].size && ugxm_util::is_gamemode_weapon_allowed(level.ugxm_sharpshooter["current_gun"])) 
			valid = true; //we went through the entire history and did not find a match, use it.
	}
	level.ugxm_sharpshooter["history"][level.ugxm_sharpshooter["history"].size] = level.ugxm_sharpshooter["current_gun"];
	
	if(isDefined(level.ugxm_sharpshooter["next_switch_hud_val"])) 
		level.ugxm_sharpshooter["next_switch_hud_val"] ugxm_util::destroy_hud();
	level.ugxm_sharpshooter["next_switch_hud_val"] = ugxm_util::create_info_hud(undefined, level.ugxm_sharpshooter["interval"], 0, (0.1,0.688,0.903), 125 - 19, "timer");
}

function increase_rank()
{
	increase = false;
	
	if(level.ugxm_sharpshooter["rank_increase_override"] != -1 && level.ugxm_sharpshooter["rounds_since_rankchange"] >= level.ugxm_sharpshooter["rank_increase_override"])
		increase = true;
	if(get_chance_result(level.ugxm_sharpshooter["rank_increase_chance"], 100))
		increase = true;
		
	if(!increase)
		return;
		
	level.ugxm_sharpshooter["rounds_since_rankchange"] = 0;
	
	level.ugxm_sharpshooter["rank"] += level.ugxm_sharpshooter["rank_increase_amount"];
	
	if(level.ugxm_sharpshooter["rank"] >= level.ugxm_sharpshooter["guns"].size)
		level.ugxm_sharpshooter["rank"] = level.ugxm_sharpshooter["guns"].size - 1;
}

function get_chance_result(chance, inclusive_upper_bound)
{
	rand = randomint(inclusive_upper_bound + 1);
	
	// Need this because the below if doesn't handle this one case properly if rand = 0
	if(chance == 0)
		return false;
	
	if(rand <= chance)
		return true;
		
	return false;
}

function game_complete()
{
	players = getPlayers();
	
	// Find highest score of the players (will only show one, even if there are multiple players with the same highest score)
	winner_score = 0;
	for(i=0;i<players.size;i++)
	{
		if(players[i].stats["kills"] >= winner_score)
		{
			winner_score = players[i].stats["kills"];
		}
	}
	
	// Go through the players and find any player with this highest score (these are the winners)
	// Also, you can go ahead and do the endgame stuff here
	winners = [];
	for(i=0;i<players.size;i++)
	{
		if(players[i].stats["kills"] == winner_score)
		{
			winners[winners.size] = players[i];
		}
			
		players[i] TakeAllWeapons();
		players[i].ignoreme = true;
		players[i] freezeControls(true);
	}
	
	level.ugxm_game_winners = winners;
	level notify("end_game");
}

function perks_init()
{
	self.ss_perks = [];
	self.ss_perks["progress_bar"] = ugxm_util::create_progressbar( self, (1, 0, 0), 120, 4 );
	self.ss_perkstext = ugxm_util::create_simple_hud();
	self.ss_perkstext.alignX = "center";
	self.ss_perkstext.alignY = "top";
	self.ss_perkstext.horzAlign = "center";
	self.ss_perkstext.vertAlign = "top";
	self.ss_perkstext.fontscale = 1;
	self.ss_perkstext.x = -100;
	self.ss_perkstext.y = 5;
	self.ss_perkstext.alpha = 1;
	self.ss_perkstext SetText("Perk Unlock:");

	self.ss_perks["perk_level"] = 0;
	self.ss_perks["kills_per_perk"] = 20;
	self.ss_perks["kills"] = 0;
	self.ss_perks["perk_shaders"] = [];
}

function perks_zombie_kill_monitor()
{
	level endon("end_game");
	while(1)
	{
		level waittill("zombie_died", zombie, forcedPlayer); 
		if(!isPlayer(forcedPlayer))
			continue;
		if(forcedPlayer.ss_perks["perk_level"] >= 7)
		{
			if(isDefined(forcedPlayer.ss_perks["progress_bar"]))
			{
				forcedPlayer.ss_perks["progress_bar"].bar ugxm_util::destroy_hud();
				forcedPlayer.ss_perks["progress_bar"] ugxm_util::destroy_hud();
				forcedPlayer.ss_perkstext Destroy();
			}
			
			return;
		}
		
		forcedPlayer.ss_perks["kills"] ++;
		
		if(forcedPlayer.ss_perks["kills"] >= forcedPlayer.ss_perks["kills_per_perk"])
		{
			forcedPlayer.ss_perks["perk_level"] ++;
			forcedPlayer.ss_perks["kills"] = 0;
			forcedPlayer perks_update();
		}
		
		if(forcedPlayer.ss_perks["perk_level"] >= 7)
		{
			if(isDefined(forcedPlayer.ss_perks["progress_bar"]))
			{
				forcedPlayer.ss_perks["progress_bar"].bar ugxm_util::destroy_hud();
				forcedPlayer.ss_perks["progress_bar"] ugxm_util::destroy_hud();
				forcedPlayer.ss_perkstext Destroy();
			}	
		}
		else
		{
			forcedPlayer.ss_perks["progress_bar"] ugxm_util::progressbar_setvalue(forcedPlayer.ss_perks["kills"], forcedPlayer.ss_perks["kills_per_perk"]);
		}
	}
}

function perks_update()
{
	self perks_toggle(self.ss_perks["perk_level"], true);
	self.ss_perks["perk_shaders"][self.ss_perks["perk_level"]] = true;
}

function perks_toggle(index, enable)
{
	perk = undefined;
	switch( index )
	{
		case 7:
			//todo: is this possible in BO3? player_clipSizeMultiplier still exists but there's no such thing as a client dvar anymore. Probably a question for Reddit. Also specialty_scavengerseems to modify clipsize but it doesn't have any effect when set on a player.
			//perk = "specialty_extraammo"; //Bandolier
			break;

		case 5:
			perk = PERK_DEAD_SHOT;
			break;

		//case 5:
		//	perk = PERK_ELECTRIC_CHERRY; //@fixme we need the fixed Electric Cherry script or wait for 3arc to fix
		//	break;

		case 4:
			perk = PERK_JUGGERNOG;
			break;

		case 3:
			perk = PERK_STAMINUP; 
			break;

		case 2:
			perk = PERK_SLEIGHT_OF_HAND;
			break;

		case 1:
			perk = PERK_DOUBLETAP2;
			break;
		
		default:
			return;
	}
	
	if(enable)
	{
		//@todo bandolier
		//if(index == 7)
		//	self setClientDvar("player_clipSizeMultiplier", 1.5);
		if(index == 4)
		{
			//@todo this is probably not necessary anymore in BO3?
			self zm_perks::perk_set_max_health_if_jugg( PERK_JUGGERNOG, true, false );
		}
		self thread ugxm_util::play_pooled_announcer_vox("perk_acquired");
		self SetPerk(perk);
		self zm_perks::set_perk_clientfield( perk, PERK_STATE_OWNED );
	}
	else
	{
		//@todo
		//if(index == 7)
		//	self setClientDvar("player_clipSizeMultiplier", 1);
		if(index == 4)
		{
			self.maxhealth = 100;
		}	
		
		self UnSetPerk(perk);
		self zm_perks::set_perk_clientfield( perk, PERK_STATE_NOT_OWNED );
	}	
}

function perks_reset(downed)
{
	if(!isDefined(downed))
		downed = false;
		
	if(!downed && self HasPerk(PERK_JUGGERNOG))
		return;
	
	for(i=1;i<=self.ss_perks["perk_shaders"].size;i++) // start at 1, because 0 means no perks
	{
		self perks_toggle(i, false);
	}	
	
	self zm_perks::perk_set_max_health_if_jugg( "health_reboot", true, true );
	self.ss_perks["perk_shaders"] = [];
	self.ss_perks["kills"] = 0;
	self.ss_perks["perk_level"] = 0;
	
	if(isDefined(self.ss_perks["progress_bar"]))
		self.ss_perks["progress_bar"] ugxm_util::progressbar_setvalue(0, self.ss_perks["kills_per_perk"]);
	else
		self.ss_perks["progress_bar"] = ugxm_util::create_progressbar( self, (1, 0, 0), 120, 4 );
}