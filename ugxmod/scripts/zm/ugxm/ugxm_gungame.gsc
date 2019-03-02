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

#insert scripts\zm\_zm_utility.gsh;

#using scripts\zm\_load;
#using scripts\zm\_zm;
#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;
#using scripts\zm\_zm_zonemgr;

#using scripts\shared\math_shared;

#using scripts\shared\ai\zombie_utility;

#using scripts\zm\ugxm\ugxm_powerups;
#using scripts\zm\ugxm\ugxm_util;

#define GUNGAME 1

REGISTER_SYSTEM( "ugxm_gungame", &__init__, undefined )
function __init__()
{
	callback::on_spawned(&on_player_spawned_gungame); //UGXMBO3-57
}

function sortWeaponsByCost(array) //highest first, highest = least rare
{
	keys = getArrayKeys(array);
	newarray = [];

	for(i=1; i < keys.size; i++)
	{
	   	for(k=0; k < keys.size - i; k++)
	   	{
	   		weapon1 = keys[k];
			weapon2 = keys[k+1];

			weight1 = level.zombie_weapons[weapon1].cost;
			if(!isDefined(weight1)) 
			{
				//iPrintLnBold("ERROR>> " + weapon1.name + " has no cost defined");
				weight1 = 100;
				//weight1 = get_weight_of_unique(weapon1);
			}

			weight2 = level.zombie_weapons[weapon2].cost;
			if(!isDefined(weight2)) 
			{
				//iPrintLnBold("ERROR>> " + weapon2.name + " has no cost defined");
				weight2 = 100;
				//weight2 = get_weight_of_unique(weapon2);
			}

			//iPrintLnBold("Comparing " + weapon1.name + ": " + weight1 + " to " + weapon2.name + ": " + weight2);
			if(weight1 > weight2)
			{
			   temp = keys[k]; 
			   keys[k] = keys[k + 1]; 
			   keys[k + 1] = temp;
			}
	   	}
	}

	keys = ugxm_util::array_reverse(keys);

   	for(x=0; x < keys.size; x++) 
   	{
   		if(!ugxm_util::is_gamemode_weapon_allowed(keys[x]))
			continue;
   		newarray[keys[x]] = level.zombie_weapons[keys[x]]; //initialize values of the resorted keys in a new array
   	}

   return newarray;
}

function build_weapon_list()
{
	temparray = [];
	temparray = sortWeaponsByCost(level.zombie_weapons); //sort that shit out

	level.ugxm_settings["gun_list_final"] = temparray;

	weapon_keys = getArrayKeys(level.ugxm_settings["gun_list_final"]);
	for(i=0; i<weapon_keys.size; i++)
	{
		//iPrintLnBold("^5Setting " + weapon_keys[i].name + " (" + weapon_keys[i].weapclass + ") to " + level.ugxm_settings["score_script"]);
		level.ugxm_settings["gun_list_final"][weapon_keys[i]] = level.ugxm_settings["score_script"]; //add the weapon from this class to the end of the final list
		weapClass = weapon_keys[i].weapclass;
		//weight = level.ugxm_lottery["weapon"][weapon_keys[i]];
		
		//if(maps\_zombiemode_weapons::is_sniper_rifle(weapon_keys[i]))
		//	weapClass = "sniper";
		//if(isDefined(weight) && weight != 0 && weight <= 15)
		//	weapClass = "wonder";
		if(weapClass == "rocketlauncher")
			weapClass = "pistol"; //classify the launcher as a pistol for now, don't know what I want to do with it yet

		if(weapClass == "rifle") 		level.ugxm_settings["score_script"] = level.ugxm_settings["score_script"] + 2000;
		else if(weapClass == "mg") 		level.ugxm_settings["score_script"] = level.ugxm_settings["score_script"] + 3000;
		else if(weapClass == "sniper") 	level.ugxm_settings["score_script"] = level.ugxm_settings["score_script"] + 250;
		else if(weapClass == "smg") 	level.ugxm_settings["score_script"] = level.ugxm_settings["score_script"] + 1000;
		else if(weapClass == "spread") 	level.ugxm_settings["score_script"] = level.ugxm_settings["score_script"] + 500;
		else if(weapClass == "pistol") 	level.ugxm_settings["score_script"] = level.ugxm_settings["score_script"] + 500;
		else if(weapClass == "wonder") 	level.ugxm_settings["score_script"] = level.ugxm_settings["score_script"] + randomIntRange(5000,7000);
		else 					 		level.ugxm_settings["score_script"] = level.ugxm_settings["score_script"] + randomIntRange(250,1000);
		
		if(i > 0) //don't add this onto the first gun, it's too much.
			level.ugxm_settings["score_script"] = level.ugxm_settings["score_script"] + randomIntRange(0,300); //spice up each score a little each game.
	}
}

function prepare_gungame()
{
	level flag::init("weapons_list_built");
	build_weapon_list();
	level flag::set("weapons_list_built");

	if(level.ugxm_settings["gun_list_final"].size)
	{
		corrected_keys = getGunKeys(level.ugxm_settings["gun_list_final"], true); //reverse the fucking order
		corrected_array = [];
		for(i=0;i<corrected_keys.size;i++)
		{
			corrected_array[corrected_keys[i]] = level.ugxm_settings["gun_list_final"][corrected_keys[i]];
		}
		level.ugxm_gungame["guns"] = corrected_array;
	}

	keys = getGunKeys();
	level.ugxm_gungame["complete"] = level.ugxm_gungame["guns"][keys[keys.size-1]] + randomIntRange(3500,5500);

	if(level.ugxm_settings["gamemode"] != GUNGAME)
		return;

	level.ugxm_settings["timed_hud_offset"] = 20;

	/# printLn("prepare_gungame() running"); #/
	ugxm_util::game_setting("allow_ugx_bossround", false);
	ugxm_util::game_setting("allow_ugx_powerups", true);
	ugxm_util::powerup_setting("using_custom_powerups", true); //@todo

	ugxm_util::game_setting("dont_increase_zombie_health", true);
	
	//Stock BO3 powerup drops
	ugxm_util::powerup_setting("full_ammo", false);
	ugxm_util::powerup_setting("insta_kill", false); 
	ugxm_util::powerup_setting("double_points", false);
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
	ugxm_util::powerup_setting("gun_1up", true);
	ugxm_util::powerup_setting("points_1up", true);
	ugxm_util::powerup_setting("pap_gun_upgrade", true);
	
	if(getPlayers().size > 1)
	{
		ugxm_util::powerup_setting("gun_down_rand", true);
		ugxm_util::powerup_setting("invisibility", true);
		ugxm_util::game_setting("painkiller_respawn", true);
	}
	
	ugxm_util::game_setting("allow_gobblegums", false);
	ugxm_util::game_setting("allow_perks", true);
	ugxm_util::game_setting("specialty_additionalprimaryweapon", false);
	ugxm_util::game_setting("specialty_quickrevive", false);
	ugxm_util::game_setting("specialty_widowswine", false);

	ugxm_util::game_setting("allow_wall_guns", false);
	ugxm_util::game_setting("allow_mbox", false);
	ugxm_util::game_setting("allow_weap_cabinet", false);
	ugxm_util::game_setting("allow_pay_turrets", false);
	ugxm_util::game_setting("allow_pap", false);
	ugxm_util::game_setting("grenades_disallowed", true);

	ARRAY_ADD(level.ugx_painkiller_respawn_logic, &on_player_died_gungame);

	level.gamemode_is_competative = true;

	level.ugxm_settings["endgame_text"] = "Gungame Over!";

	//level.ugxm_gungame["guns"] = level.zombie_include_weapons;

	level.ugxm_gungame_scores = [];
	level.ugxm_gungame_scores["first_place"]	 = undefined; 
	level.ugxm_gungame_scores["second_place"]	 = undefined; 
	level.ugxm_gungame_scores["third_place"]	 = undefined; 
	level.ugxm_gungame_scores["last_place"]		 = undefined;
	/# printLn("prepare_gungame() done"); #/

	thread ugxm_util::auto_doors_power_etc(false, true);
	thread __main__();
}

function on_player_spawned_gungame()
{
	if(!level flag::get("voting_complete"))	
		level flag::wait_till("voting_complete");

	if(level.ugxm_settings["gamemode"] != GUNGAME)
		return;

	//iPrintLn("on_player_spawned_gungame() started");

	self TakeAllWeapons();
	self.score = 0;
	self.score_total = 0;
	self.old_score = 0;
	self AllowMelee( false );
	self.grenadeammo = 0;
	self.gunscore = 0;
	self thread score_monitor();
	self.gungame_more_points = false;
}

function __main__()
{
	thread winner_monitor();
}

function on_player_died_gungame()
{
	if(level.isTimedGameplay)
		new_score = Int(self.score_total * 0.87);
	else
		new_score = Int(self.score_total * 0.85);

	iPrintLn(self.playername + "^7 lost " + (self.score_total - new_score) + " points from dying!");
	
	self.score_total = new_score;	
	self.gunscore = 0;
}

function getGunKeys(array, reverse = false)
{
	if(!level flag::get("weapons_list_built"))	
		level flag::wait_till("weapons_list_built");

	if(!isDefined(array)) array = level.ugxm_gungame["guns"];

	revkeys = getArrayKeys(array);
	if(reverse)
	{
		keys = [];
		for(i=0;i<revkeys.size;i++)	keys[i] = revkeys[revkeys.size - (i+1)];
		return keys;
	}
	else
		return revkeys;
}
function winner_monitor()
{
	level waittill("winner");
	
	players = getPlayers();
	for(i=0;i<players.size;i++)
	{
		players[i].ignoreme = true;
		players[i] freezeControls(true);
	}
	
	level notify("end_game");
}

function update_menu_scores(keys)
{
	/* //@todo this has no display implantation which means its pointless right now.
	players = getPlayers();

	if(players.size > 1)
	{
		first = -1; second = -1; third = -1; last = -1;

		for(i=0; i<players.size; i++)
		{
			if(players[i].gunscore > first)
			{
				//Shift everyone else down a position.
				if(isDefined(level.ugxm_gungame_scores["last_place"])) level.ugxm_gungame_scores["last_place"] = level.ugxm_gungame_scores["third_place"];
				if(isDefined(level.ugxm_gungame_scores["third_place"])) level.ugxm_gungame_scores["third_place"] = level.ugxm_gungame_scores["second_place"];
				if(isDefined(level.ugxm_gungame_scores["second_place"])) level.ugxm_gungame_scores["second_place"] = level.ugxm_gungame_scores["first_place"];

				level.ugxm_gungame_scores["first_place"] = players[i];
				first = level.ugxm_gungame_scores["first_place"].gunscore;
				//iPrintLnBold("^5New First place: " + level.ugxm_gungame_scores["first_place"].playername + " @ " + first);
			}
			else if(players[i].gunscore > second || players.size >= 2)
			{
				//Shift everyone else down a position.
				if(isDefined(level.ugxm_gungame_scores["last_place"])) level.ugxm_gungame_scores["last_place"] = level.ugxm_gungame_scores["third_place"];
				if(isDefined(level.ugxm_gungame_scores["third_place"])) level.ugxm_gungame_scores["third_place"] = level.ugxm_gungame_scores["second_place"];

				level.ugxm_gungame_scores["second_place"] = players[i];
				second = level.ugxm_gungame_scores["second_place"].gunscore;
				//iPrintLnBold("^5New Second place: " + level.ugxm_gungame_scores["second_place"].playername + " @ " + second);
			}
			else if(players[i].gunscore > third || players.size >= 3)
			{
				//Shift everyone else down a position.
				if(isDefined(level.ugxm_gungame_scores["last_place"])) level.ugxm_gungame_scores["last_place"] = level.ugxm_gungame_scores["third_place"];

				level.ugxm_gungame_scores["third_place"] = players[i];
				third = level.ugxm_gungame_scores["third_place"].gunscore;
				//iPrintLnBold("^5New Third place: " + level.ugxm_gungame_scores["third_place"].playername + " @ " + third);
			}
			else 
			{
				level.ugxm_gungame_scores["last_place"] = players[i];
				last = level.ugxm_gungame_scores["last_place"].gunscore;
				//iPrintLnBold("^5Last place: " + level.ugxm_gungame_scores["last_place"].playername + " @ " + last);
			}
		}
	}
	
	for(i=0; i<players.size; i++)
	{
		for(k=0; k<players.size; k++)
		{
			if(players.size > 1)
			{
				if(isDefined(level.ugxm_gungame_scores["first_place"])) players[i] setClientDvar("ugxm_player_" + level.ugxm_gungame_scores["first_place"] GetEntityNumber() + "_medal", "ugxm_1st_place");
				if(isDefined(level.ugxm_gungame_scores["second_place"])) players[i] setClientDvar("ugxm_player_" + level.ugxm_gungame_scores["second_place"] GetEntityNumber() + "_medal", "ugxm_2nd_place");
				if(isDefined(level.ugxm_gungame_scores["third_place"])) players[i] setClientDvar("ugxm_player_" + level.ugxm_gungame_scores["third_place"] GetEntityNumber() + "_medal", "ugxm_3rd_place");
				if(isDefined(level.ugxm_gungame_scores["last_place"])) players[i] setClientDvar("ugxm_player_" + level.ugxm_gungame_scores["last_place"] GetEntityNumber() + "_medal", "blank");
			}
			if(isDefined(players[i]) && isAlive(players[i])) players[i] setClientDvar("ugxm_player_" + k + "_miniscore", ("Gun " + string(players[k].gunscore + 1) + " of " + string(level.ugxm_gungame["guns"].size - 1)));
		}
	}
	*/
}

function score_monitor()
{
	//iPrintLnBold("score_monitor()");
	level endon("end_game");
	self endon("disconnect");
	self endon("ugxm_stop_forcing_weapon");

	self.score = 0;

	keys = getGunKeys();
	
	self.score_total = level.ugxm_gungame["guns"][keys[self.gunscore]];
	//iPrintLnBold("Setting self.score_total to: " + self.score_total);
	//tempWeap = getWeapon(keys[0]);
	tempWeap = keys[0];
	self giveWeapon(tempWeap);
	//iPrintLnBold("Giving 1st Weapon: " + keys[0].name);
	
	self thread gungame_score_hud();
	
	complete_score = level.ugxm_gungame["complete"];

	//iPrintLnBold("Score to win: " + complete_score);
	
	while(1)
	{
		if(IS_TRUE(self.ugxm_pause_forcing_weapons))
		{
			self TakeAllWeapons();
			wait 0.1;
			continue;
		}

		if ((self flag::exists( "in_beastmode" )) && (self flag::get( "in_beastmode" )))
		{
			iPrintLnBold("Beast Mode is not allowed outside of the Classic Gamemode!");
			wait 2.5;
			level notify("end_game");
		}

		update_menu_scores(keys);
		
		list = self getWeaponsList(); 

		for(i=0;i<list.size;i++) 
			if(list[i].weapClass == "offhand") 
				self takeWeapon(list[i]); //9/9/2013 - treminaor: universally take all offhand weapons, no naming required

		cw = self getCurrentWeapon();
		//self iPrintLn(cw.name);
		if(cw.name != "none")
		{
			if(self.score_total >= complete_score)
			{
				self.score_total = complete_score;
				level.ugxm_game_winners[0] = self;
				self.stats["score"] = complete_score;
				self TakeAllWeapons();
				//self iPrintLnBold("^1TAKING ALL WEAPS 2");
				
				wait 0.01;
				level notify("winner");
				return;
			}
			
			upped_gun = false;
			while(self.score_total >= level.ugxm_gungame["guns"][keys[self.gunscore + 1]])
			{
				self.gunscore ++;
				upped_gun = true;
			}
			
			if(upped_gun)
			{
				self.ugxm_gg_ss_temp_use_upgrade = false;
				self.ugxm_gg_ss_temp_use_elemental = false;
				//playsoundatposition("newgun", self.origin);
			}
			
			while(self.score_total < level.ugxm_gungame["guns"][keys[self.gunscore]]) // if this loop happens, the if and loop above didn't happen
			{
				self.gunscore --;
			}
			
			gun = keys[self.gunscore];

			//UGXMBO3-9
			if(IS_TRUE(self.ugxm_gg_ss_temp_use_upgrade))
			{
				if(isDefined(level.zombie_weapons[gun.rootWeapon].upgrade))
					gun = level.zombie_weapons[gun.rootWeapon].upgrade;
			}
			//if(isDefined(self.ugxm_gg_ss_temp_use_elemental) && self.ugxm_gg_ss_temp_use_elemental && isDefined(level.zombie_weapons[gun + "_elemental"]))
			//	gun += "_elemental";

			if(cw.rootWeapon != gun.rootWeapon && !is_allowed_other_gun(cw, gun)) //UGXMBO3-28?
			{
				self TakeAllWeapons();
				self ugxm_util::weapon_give(gun, true);
				self waittill("weapon_change_complete");
			}
			
			self giveMaxAmmo(cw);
			if(gun.type == "melee") //should never be true because of the current is_gamemode_weapon_allowed(), but someone may change their mind.
				self AllowMelee( true );
			else
				self AllowMelee( false );
		}
		else //they lost their gun, most likely from a ugxm_pause_forcing_weapons
		{
			gun = keys[self.gunscore];
			self ugxm_util::weapon_give(gun, true);
		}
	
		wait 0.05;
	}
	
}
function is_allowed_other_gun(cw, gun)
{
	if(IS_TRUE(self.beastmode))
		return true;

	if(WeaponHasAttachment(cw, "dualoptic")) //UGXMBO3-28 don't let dualoptic toggle force a new gun
	{
		name = GetSubStr(cw.rootWeapon.name, 10, cw.rootWeapon.name.size); //filter out "dualoptic_" from weapon name
		if(name == gun.rootWeapon.name) //as long as the gun they are supposed to have is equal to the name of this dualoptic, we're good.
			return true;
	} 
	
	if(isSubStr(cw.name, "zombie_perk_bottle_")) return true;
	if(cw.name == "zombie_knuckle_crack") return true;
	
	return false;
	
}
function gungame_score_hud()
{
	
	level endon("end_game");
	self endon("disconnect");
	
	self.gg_pt_start = ugxm_util::create_info_hud(self, "Points total:", 0, (1,1,1));
	self.gg_pl_start = ugxm_util::create_info_hud(self, "Points until next gun:", 1, (1,1,1));
	self.gg_gn_start = ugxm_util::create_info_hud(self, "Current Gun:", 2, (1,1,1));

	keys = getGunKeys();
	
	while(1)
	{
		wait 0.1;
		
		if(isDefined(self.gg_pt_end)) self.gg_pt_end ugxm_util::destroy_hud();
		self.gg_pt_end = ugxm_util::create_info_hud(self, self.score_total, 0, (0.1,0.688,0.903), 80 - 19, "value");
		
		points_left = level.ugxm_gungame["guns"][keys[self.gunscore + 1]] - self.score_total;
		if(!isDefined(points_left)) //UGXMBO3-25
			points_left = level.ugxm_gungame["complete"] - self.score_total; 
		
		if(points_left < 0)
			points_left = 0;
		
		if(isDefined(self.gg_pl_end)) self.gg_pl_end ugxm_util::destroy_hud();
		self.gg_pl_end = ugxm_util::create_info_hud(self, points_left, 1, (0.1,0.688,0.903), 120 - 19, "value");
		
		if(isDefined(self.gg_gn_end)) self.gg_gn_end ugxm_util::destroy_hud();
		//gunNum = (self.gunscore + 1) + " out of " + (keys.size - 1);
		gunNum = (self.gunscore + 1) + " out of " + (keys.size); //UGXMBO3-25
		self.gg_gn_end = ugxm_util::create_info_hud(self, gunNum, 2, (0.1,0.688,0.903), 83 - 19, "text");
	}	
}