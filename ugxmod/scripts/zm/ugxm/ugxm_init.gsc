#using scripts\codescripts\struct;

//@todo causing a clientfield error right now, probably todo with the order of execution? - update, need to call from CSC as well, which means we need a UGXM CSC hook.
//#using scripts\zm\_zm_perk_electric_cherry;

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\math_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\array_shared;

#using scripts\zm\_zm;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_zonemgr;
#using scripts\zm\_zm_unitrigger;
#using scripts\zm\gametypes\_zm_gametype;

//UGXMBO3-20
#using scripts\zm\_zm_perk_electric_cherry_fixed;

#using scripts\zm\ugxm\ugxm_wallweapon;
#using scripts\zm\ugxm\ugxm_gungame;
#using scripts\zm\ugxm\ugxm_chaosmode;
#using scripts\zm\ugxm\ugxm_sharpshooter;
#using scripts\zm\ugxm\ugxm_timedgp;
#using scripts\zm\ugxm\ugxm_powerups;
#using scripts\zm\ugxm\ugxm_util;

#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\zm\_zm_perks.gsh;

#insert scripts\zm\ugxm\ugxm_header.gsh;

#namespace ugxm;

#precache("material", "ugxmbo3_logo");
#precache( "menu", "popup_leavegame" );
#precache( "menu", "ugxm_vote_host" );

/*
@todo Hide Round Counter - doesnt seem possible, at least from gsc.
@todo Fix TGP Timer placement.
@todo high prio - make the weapon spawn generation not need structs so the mod can be run on anything when released.
@todo high prio - coop death in gungame and another modes should be timed respawn not last stand
@todo high prio - gungame powerups like terminator, invincibility, etc
*/

function autoexec __init__()
{
	init_vars();
	ugxm_powerups::init_powerups();
	ugxm_chaosmode::chaosmode_menu_var_init();
	callback::on_spawned( &on_player_spawned );
	thread post_gamemode_selection();
}

function init_vars()
{
	level.player_movement_suppressed = true; //don't let players move until vote is complete.

	level.ugxm_settings = [];
	level.ugxm_timed_gameplay_disallowed = [];
	level.ugx_painkiller_respawn_logic = [];

	if(isDefined(level.tgTimer)) level.tgTimer Destroy();
	level.tgTimer = NewHudElem();
	level.ugxm_settings["timed"] = false;
	level.ugxm_settings["timed_hud_offset"] = 0;
	level.ugxm_settings["score_script"] = 0; 
	level.ugxm_settings["game_time"] = 900; // For gamemodes with a limited time. Needs to be here because it's read before the inits are called.

	level.initial_round_wait_func = &wait_for_gamemode_selection;
	level.custom_game_over_hud_elem = &ugxm_game_over;

	level flag::init("voting_complete");

	ARRAY_ADD(level.zombie_death_event_callbacks, &on_zombie_died);
}

function wait_for_gamemode_selection() //level.initial_round_wait_func override: delays the start of round 1 until we're ready.
{
	level waittill("voting_complete");
}

function post_gamemode_selection()
{	
	level waittill("voting_complete");

	generate_random_spawnpoints();

	foreach(player in getPlayers())
	{
		player FreezeControls(false);
		player EnableWeapons();
		player setClientUIVisibilityFlag( "hud_visible", 1 );
		player setClientUIVisibilityFlag( "weapon_hud_visible", 1 );

		if(player GetEntityNumber() != 0) player.waiting_for_host ugxm_util::destroy_hud();
		player thread remove_fadeToBlack();
		
		if(isDefined(player.fadeToBlack))
		{
			player.fadeToBlack FadeOverTime(2.5);
			player.fadeToBlack.alpha = 0;
		}
	}

	level.player_movement_suppressed = false;

	ugxm_gungame::prepare_gungame();
	ugxm_chaosmode::prepare_chaosmode();
	ugxm_sharpshooter::prepare_sharpshooter();
	prepare_arcademode();

	ugxm_powerups::check_stock_powerups();

	if(IS_TRUE(level.ugxm_settings["painkiller_respawn"])) //UGXMBO3-11
	{
		level.whoswho_laststand_func = &painkiller_respawn;
		foreach(player in getPlayers())
		{
			//@fixme this is hacky, if we get _zm.gsc we can make this better later.
			player.lives = 9999;
			player SetPerk(PERK_WHOSWHO); //shouldn't actually have any effect because I redefined the Who's Who action function, required for a check in player_damage_override.
		}
	}

	if(IS_TRUE(level.ugxm_settings["grenades_disallowed"]))
	{
		foreach(player in getPlayers())
		{
			//player zm_utility::set_player_lethal_grenade(level.weaponNone); //can't use the actual function, thanks 3arc. //@fixme uncomment and erase next two lines once 3arc drops the utility gsh
			player notify( "new_lethal_grenade", level.weaponNone );
			player.current_lethal_grenade = level.weaponNone;
		}
	}

	if(isDefined(level.ugxm_powerup_settings["powerup_drop_chance"]))
	{
		//@todo not fully supported yet, aidan originally used a 0-100% scale and 3arc seems to be using an inverted scale where 0 is 100% and a regular chance is 2000... do some math to convert or change the old vars
		if(level.ugxm_powerup_settings["powerup_drop_chance"] == 0)
			level.zombie_vars["zombie_powerup_drop_max_per_round"] = 0;
	}
	if(IS_FALSE(level.ugxm_powerup_settings["using_custom_powerups"]))
	{
		//@todo not supported yet
	}
	if(IS_FALSE(level.ugxm_settings["allow_ugx_bossround"]))
	{
		//@todo not supported yet, do we want to?
	}
	if(IS_FALSE(level.ugxm_settings["allow_ugx_powerups"]))
	{
		//@todo not supported yet
	}
	if(IS_FALSE(level.ugxm_settings["allow_perks"]))
	{
		vending_triggers = GetEntArray( "zombie_vending", "targetname" );

		foreach(trig in vending_triggers)
			trig TriggerEnable( false );
	}

	if(IS_FALSE(level.ugxm_settings["allow_gobblegums"]))
	{
		bgb_triggers = GetEntArray("bgb_machine_use", "targetname");
		foreach(zbar in bgb_triggers)
		{
			if(isDefined(zbar.unitrigger_stub))
				thread zm_unitrigger::unregister_unitrigger(zbar.unitrigger_stub);
		}
	}

	//UGXMBO3-56 check for individual perk disables
	{
		//if ( isdefined( level._custom_perks[ perk ] ) && isdefined( level._custom_perks[ perk ].hint_string ) )
		//valid = self [[ level.custom_perk_validation ]]( player );

		level.custom_perk_validation = &ugxm_custom_perk_validation;

		vending_triggers = GetEntArray( "zombie_vending", "targetname" );
		foreach(trig in vending_triggers)
		{
			if(IS_FALSE(level.ugxm_settings[trig.script_noteworthy]))
			{
				if(isdefined(level._custom_perks[trig.script_noteworthy].hint_string))
				{
					level._custom_perks[trig.script_noteworthy].hint_string = undefined;
					trig SetHintString("Perk is disabled in this gamemode.");
				}
			}
		}
	}

	if(IS_FALSE(level.ugxm_settings["allow_pap"]))
	{
		level.pack_a_punch.power_on_callback = &disable_pap_for_gamemode;
	}
	if(IS_FALSE(level.ugxm_settings["allow_mbox"]))
	{
		foreach(chest in level.chests)
		{
			if(isDefined(chest.unitrigger_stub))
			{
				thread zm_unitrigger::unregister_unitrigger(chest.unitrigger_stub);
			}
			if ( IsDefined( chest.pandora_light ) )
			{
				chest.pandora_light delete();
			}

			chest.zbarrier clientfield::set( "magicbox_closed_glow", false );
		}
	}
	if(IS_FALSE(level.ugxm_settings["allow_wall_guns"]))
	{
		level.func_override_wallbuy_prompt = &disable_wallbuys_for_gamemode;
	}

	if(level.ugxm_settings["timed"])
	{
		//SoE (and probably the rest of the maps) bug out if you disable the Margwa rounds...
		if(level.script != "zm_zod" && level.script != "zm_dlc4" && level.script != "zm_genesis" && level.script != "zm_stalingrad" && level.script != "zm_island" && level.script != "zm_castle") 
		{
			level.next_dog_round = 9999; //cheap way to disable dogs after zm_usermap::main() runs.
			level.noRoundNumber = true; //judging from the code it seems to disable a lot of between-round sounds, effects, etc. Makes the round transition seamless??
		}
		
		level.zombie_vars["zombie_between_round_time"] = 0; //remove the delay at the end of each round 
		level.zombie_round_start_delay = 0; //remove the delay before zombies start to spawn

		if(IS_TRUE(level.ugxm_settings["dont_increase_zombie_health"]))
			thread ugxm_util::force_zombie_health_vars();

		level.round_wait_func = &ugxm_timedgp::round_wait_override; //this has to happen before zm::round_start() runs!
		thread ugxm_timedgp::timed_gameplay(); //important to wait until after gamemodes are prepared because they may preset some settings for the timer etc.
	}
}

function ugxm_custom_perk_validation(player)
{
	if(IS_FALSE(level.ugxm_settings[self.script_noteworthy]))
		return false;

	return true;
}

function painkiller_respawn()
{

	if(IsDefined(level.ugx_painkiller_respawn_logic))
	{
		if(IsArray(level.ugx_painkiller_respawn_logic))
		{
			for(i = 0; i < level.ugx_painkiller_respawn_logic.size; i ++)
			{
			self thread [[level.ugx_painkiller_respawn_logic[i]]]();
			}
		}
		else
		{
			self thread [[level.ugx_painkiller_respawn_logic]]();
		}
	}

	self.health = self.maxhealth;
	self EnableInvulnerability();
	self.ignoreme = true; 

	painkiller_time = 5 + (int(level.round_number * 0.35));
	
	if( !IsDefined(self.introblack) )
	{
		self.introblack = NewClientHudElem(self); 
		self.introblack.x = 0; 
		self.introblack.y = 0; 
		self.introblack.horzAlign = "fullscreen"; 
		self.introblack.vertAlign = "fullscreen"; 
		self.introblack.foreground = true;
		self.introblack SetShader( "black", 640, 480 );
		self.introblack.alpha = 1; 

		self.introblack FadeOverTime( 0.5 ); 
		self.introblack.alpha = 0; 
	}
	
	spawns = struct::get_array("initial_spawn", "script_noteworthy");
	self SetOrigin( spawns[self GetEntityNumber()].origin );
	self.angles = spawns[self GetEntityNumber()].angles;

	// PainKiller HUD
	painkiller = newclientHudElem(self);
	painkiller.alignX = "center";
	painkiller.alignY = "middle";
	painkiller.horzAlign = "center";
	painkiller.vertAlign = "middle";
	painkiller.y = painkiller.y - 50;
	painkiller.foreground = true;
	painkiller.fontScale = 3;
	painkiller.alpha = 1;
	painkiller.color = ( 1, 0, 0 );
	painkiller SetText( "Painkiller" );
	
	painkillercd = newclientHudElem(self);
	painkillercd.alignX = "center";
	painkillercd.alignY = "middle";
	painkillercd.horzAlign = "center";
	painkillercd.vertAlign = "middle";
	painkillercd.foreground = true;
	painkillercd.fontScale = 3;
	painkillercd.alpha = 1;
	painkillercd.color = ( 1, 0, 0 );
	painkillercd SetTimer(painkiller_time);
	
	// Wait 4
	wait painkiller_time - 1;
	
	// Fade out
	painkiller FadeOverTime(1);
	painkillercd FadeOverTime(1);
	painkiller.alpha = 0;
	painkillercd.alpha = 0;
	painkiller.color = (1,1,1);
	painkillercd.color = (1,1,1);
	
	wait 1;
	
	painkiller ugxm_util::destroy_hud();
	painkillercd ugxm_util::destroy_hud();

	self.ignoreme = false;
	
	self DisableInvulnerability();
	//self.ugxm_gungame_death = false;
}

function disable_wallbuys_for_gamemode(player)
{
	self.stub.cursor_hint = "HINT_NONE"; //disables the hintstring
	return false; //disables trigger
}

function disable_pap_for_gamemode()
{
	trigger = getEnt(self.targetname, "target");
	trigger TriggerEnable(false);
}

function on_player_spawned()
{
	if(IsDefined(level._player_custom_spawn_logic))
	{
		if(IsArray(level._player_custom_spawn_logic))
		{
			for(i = 0; i < level._player_custom_spawn_logic.size; i ++)
			{
				self thread [[level._player_custom_spawn_logic[i]]]();
			}
		}
		else
		{
			self thread [[level._player_custom_spawn_logic]]();
		}
	}

	self thread ugxm_util::pooled_announcer_vox();
	
	if(IS_FALSE(level.passed_introscreen)) //don't do this if the game is in progress, just let them play.
	{
		self thread wait_for_host_hud();

		self FreezeControls(true);
		self DisableWeapons();

		if(self GetEntityNumber() == 0)
		{
			self createGameMenu();
		}
	}
}

function remove_fadeToBlack()
{
	self.fadeToBlack FadeOverTime( 2.0 );
	self.fadeToBlack.alpha = 0; 
	wait 2;
	self.fadeToBlack ugxm_util::destroy_hud();
}

function wait_for_host_hud()
{
	level endon("voting_complete");

	if(isDefined(self.fadeToBlack)) self.fadeToBlack Destroy();
	self.fadeToBlack = NewHudElem(); 
	self.fadeToBlack.x = 0; 
	self.fadeToBlack.y = 0;
	self.fadeToBlack.alpha = 0;
	self.fadeToBlack.horzAlign = "fullscreen"; 
	self.fadeToBlack.vertAlign = "fullscreen"; 
	self.fadeToBlack.foreground = false; 
	self.fadeToBlack.sort = 50; 
	self.fadeToBlack SetShader( "black", 640, 480 ); 	
	self.fadeToBlack.alpha = 1; 

	if(self getEntityNumber() == 0) return;

	/# self iPrintLn("^2Creating 'Waiting for host' HUD..."); #/

	if(isDefined(self.waiting_for_host)) self.waiting_for_host Destroy();
	self.waiting_for_host = newclientHudElem(self);
	self.waiting_for_host.alignX = "center";
	self.waiting_for_host.alignY = "middle";
	self.waiting_for_host.horzAlign = "center";
	self.waiting_for_host.vertAlign = "middle";
	self.waiting_for_host.y = self.waiting_for_host.y - 50;
	self.waiting_for_host.foreground = true;
	self.waiting_for_host.fontScale = 3;
	self.waiting_for_host.color = ( 1, .75, 0 );
	self.waiting_for_host SetText( "Waiting for host to start game." );
	while(1)
	{
		self.waiting_for_host.alpha = 0.1;
		self.waiting_for_host fadeOverTime(0.5);
		self.waiting_for_host.alpha = 1;
		wait 0.5;
		self.waiting_for_host fadeOverTime(0.5);
		self.waiting_for_host.alpha = 0.1;
		wait 0.5;
	}
}

function menu_test()
{
	wait 3;
	iPrintLn("Opening Menu");
	wait 1;
	self OpenMenu( "popup_leavegame" );	
	while(1)
	{
		self waittill("menu_response", menu, response);
		iPrintLn("menu: " + menu);
		iPrintLn("response: " + response);
	}
}

function createGameMenu()
{
	level flag::wait_till("initial_blackscreen_passed");

	// DEBUG - REMOVE EVERYTHING HERE
	self remove_fadeToBlack();
	self thread menu_test();
	if(true)
		return;
	//END DEBUG CODE

	self setClientUIVisibilityFlag( "hud_visible", 0 );
	self setClientUIVisibilityFlag( "weapon_hud_visible", 0 );

	self remove_fadeToBlack();

	//UGXMBO3-19
	logo = ugxm_util::create_simple_hud(self);
	//logo.foreground = true; 
	logo.sort = 2; 
	logo.hidewheninmenu = false; 
	logo.alignX = "center"; 
	logo.alignY = "middle";
	logo.horzAlign = "center";
	logo.vertAlign = "middle";
	logo.x = 0; 
	logo.y = -110;
	logo SetShader( "ugxmbo3_logo", 128, 128 );

	level.ugxm_mainmenu = [];
	level.ugxm_mainmenu["first_index"] = 0;

	self thread timedGameplyMenuHUD();
	self thread createMenuItemHUD(-3, "UGX Mod - BO3 Edition v0.1.2", true);
	self thread createMenuItemHUD(-2, "Visit our website www.UGX-Mods.com for more!", true);
	self thread createMenuItemHUD(-1, "Cycle though menu options using [{+melee}]/[{+attack}] - select using [{+activate}]. Toggle Timed Gameplay On/Off with ([{+gostand}])");
	self thread createMenuItemHUD(0);
	self thread createMenuItemHUD(1);
	self thread createMenuItemHUD(2);
	self thread createMenuItemHUD(3);
	self thread createMenuItemHUD(4, "CHAOS Mode (coming back in a later update!");

	level.ugxm_mainmenu["current_index"] = level.ugxm_mainmenu["first_index"];

	while(1)
	{
		if(self MeleeButtonPressed()) 
		{
			level.ugxm_mainmenu["current_index"]--;
			if(level.ugxm_mainmenu["current_index"] < level.ugxm_mainmenu["first_index"])
				level.ugxm_mainmenu["current_index"] = level.ugxm_mainmenu["size"];

			while(self MeleeButtonPressed())
				wait 0.001;
		}
		if(self AttackButtonPressed())
		{
			level.ugxm_mainmenu["current_index"]++;	
			if(level.ugxm_mainmenu["current_index"] > level.ugxm_mainmenu["size"])
				level.ugxm_mainmenu["current_index"] = level.ugxm_mainmenu["first_index"];

			while(self AttackButtonPressed())
				wait 0.001;
		}
		if(self UseButtonPressed())
		{
			if(level.ugxm_mainmenu["current_index"] != 4)
			{
				fixGameModeIndex();
				break;
			}
			else
			{
				iPrintLn("CHAOS Mode is currently disabled until a later update. Sorry! Working on potential fixes.");
				while(self UseButtonPressed())
					wait 0.001;
			}
		}
		if(self JumpButtonPressed())
		{
			if(!IS_TRUE(level.ugxm_timed_gameplay_disallowed[getFixedGameModeIndex(level.ugxm_mainmenu["current_index"])]))
				level.ugxm_settings["timed"] = !level.ugxm_settings["timed"];

			while(self JumpButtonPressed())
				wait 0.001;
		}
		wait 0.001;
	}
	self.destoryGameMenu = true;

	level notify("voting_complete");
	level flag::set("voting_complete");

	hudElem = newClientHudElem(self);
	hudElem.alignX = "center";
	hudElem.alignY = "middle";
	hudElem.horzAlign = "center";
	hudElem.vertAlign = "middle";
	hudElem.y = 0;

	hudElem.foreground = true;
	hudElem.font = "default";
	hudElem.fontScale = 2;
	hudElem.alpha = 1;
	hudElem.color = ( 1.0, 1.0, 1.0 );
	hudElem setText(any_gamemode_to_text(level.ugxm_settings["gamemode"]));

	foreach(player in getPlayers())
		player thread ugxm_util::play_pooled_announcer_vox("gamemode_" + level.ugxm_settings["gamemode"]);

	self.timedhudElem FadeOverTime(2.5);
	self.timedhudElem.alpha = 0;
	hudElem FadeOverTime(2.5);
	hudElem.alpha = 0;
	logo FadeOverTime(2.5);
	logo.alpha = 0;

	wait 2.5;
	self.timedhudElem Destroy();
	hudElem Destroy();
	logo Destroy();
}
function timedGameplyMenuHUD()
{
	level endon("voting_complete");
	lastToggle = false;
	lastIndex = -1;

	self.timedhudElem = newClientHudElem(self);
	self.timedhudElem.alignX = "center";
	self.timedhudElem.alignY = "middle";
	self.timedhudElem.horzAlign = "center";
	self.timedhudElem.vertAlign = "middle";
	self.timedhudElem.x = 90;
	self.timedhudElem.y = 0;

	self.timedhudElem.foreground = true;
	self.timedhudElem.font = "default";
	self.timedhudElem.fontScale = 1;
	self.timedhudElem.alpha = 1;
	self.timedhudElem.color = ( 1.0, 1.0, 1.0 );
	self.timedhudElem setText("Timed Gameplay: Off");

	while(1)
	{
		if(level.ugxm_mainmenu["current_index"] != lastIndex ||
			level.ugxm_settings["timed"] != lastToggle ||
			IS_TRUE(level.ugxm_timed_gameplay_disallowed[getFixedGameModeIndex(level.ugxm_mainmenu["current_index"])])
		)
		{
			if(IS_TRUE(level.ugxm_timed_gameplay_disallowed[getFixedGameModeIndex(level.ugxm_mainmenu["current_index"])]))
				self.timedhudElem setText("Timed Gameplay: Forced");
			else if(!level.ugxm_settings["timed"])	
				self.timedhudElem setText("Timed Gameplay: Off");
			else
				self.timedhudElem setText("Timed Gameplay: On");

			lastIndex = level.ugxm_mainmenu["current_index"];
			lastToggle = level.ugxm_settings["timed"];
		}
		WAIT_SERVER_FRAME;
	}
}

function createMenuItemHUD(index, text = any_gamemode_to_text(getFixedGameModeIndex(index)), title_text = false)
{
	//ToDo: add death endon
	if(!isDefined(level.ugxm_mainmenu["size"])) level.ugxm_mainmenu["size"] = 0;
	if(!isDefined(level.ugxm_mainmenu["current_index"])) level.ugxm_mainmenu["current_index"] = 0;
	if(!isDefined(level.host_ugxmhudElem)) level.host_ugxmhudElem = [];
	
	gap = 15;

	level.host_ugxmhudElem[index] = newClientHudElem(self);
	level.host_ugxmhudElem[index].alignX = "center";
	level.host_ugxmhudElem[index].alignY = "middle";
	level.host_ugxmhudElem[index].horzAlign = "center";
	level.host_ugxmhudElem[index].vertAlign = "middle";
	level.host_ugxmhudElem[index].y = 0 + (index * gap);

	level.host_ugxmhudElem[index].foreground = true;
	level.host_ugxmhudElem[index].font = "default";
	level.host_ugxmhudElem[index].fontScale = 1.1;
	level.host_ugxmhudElem[index].alpha = 1;
	level.host_ugxmhudElem[index].color = ( 1.0, 1.0, 1.0 );
	if(title_text)
	{
		level.host_ugxmhudElem[index].fontScale = 1.3;
		level.host_ugxmhudElem[index].color = ( 1, 0.78254, 0.13725 );
	}
	
	level.host_ugxmhudElem[index] setText(text);

	flash = false;

	if(index > level.ugxm_mainmenu["size"])
		level.ugxm_mainmenu["size"]++;

	while(!isDefined(self.destoryGameMenu))
	{
		if(level.ugxm_mainmenu["current_index"] == index && !flash)
		{
			level.host_ugxmhudElem[index].color = (1.0, 1.0, 0);
			flash = true;
		}
		else if(flash)
		{
			level.host_ugxmhudElem[index].color = ( 1.0, 1.0, 1.0 );
			flash = false;
		}
		wait 0.1;
	}

	level.host_ugxmhudElem[index] Destroy();
}

function fixGameModeIndex() //UGX Mod v1.x had a different gamemode selection, instead of updating the code we just fix the index to match what it used to be for now.
{
	level.ugxm_settings["gamemode"] = getFixedGameModeIndex(level.ugxm_mainmenu["current_index"]);
}

function getFixedGameModeIndex(index)
{
	switch(index)
	{
		case 4: 
			return 6;
		default: 
			return index;
	}
}

function gamemode_to_text()
{
	switch(level.ugxm_settings["gamemode"])
	{
		case 0:
			return "classic";
		case 1:
			return "gungame";
		case 2:
			return "arcademode";
		case 3:
			return "sharpshooter";
		case 4:
			return "bountyhunter";
		case 5:
			return "kingofthehill";
		case 6:
			return "chaosmode";
	}
}
// made this after the one above. too lazy to go through and change all the other funcs to use this one....
function any_gamemode_to_text(num)
{
	switch(num)
	{
		case 0:
			return "Classic";
		case 1:
			return "Gungame";
		case 2:
			return "Arcademode";
		case 3:
			return "Sharpshooter";
		case 4:
			return "Bounty Hunter";
		case 5:
			return "King of the Hill";
		case 6:
			return "CHAOS Mode";
	}
}
function text_to_gamemode(text)
{
	switch(text)
	{
		case "classic":
			return 0;
		case "gungame":
			return 1;
		case "arcademode":
			return 2;
		case "sharpshooter":
			return 3;
		case "bountyhunter":
			return 4;
		case "kingofthehill":
			return 5;
		case "chaosmode":
			return 6;
	}
}

function on_zombie_died( willBeKilled, inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, sHitLoc, psOffsetTime, boneIndex, surfaceType )
{
	zombie = self;
	level notify("zombie_died", zombie, zombie.attacker);
}

//UGXMBO3-17
function generate_random_spawnpoints()
{
	minSearchRadius = 0;
	maxSearchRadius = 2500;
	halfHeight = 300;
	innerSpacing = 256;
	outerSpacing = innerSpacing * 2;
	max_per_volume = 2;

	game["random_spawn_positions"] = [];

	spawns = struct::get_array("initial_spawn", "script_noteworthy");
	queryResult = PositionQuery_Source_Navigation( spawns[0].origin + (256, 256, 0), minSearchRadius, 512, halfHeight, 90, undefined, 180 );
	ARRAY_ADD(game["random_spawn_positions"], queryResult.data[0].origin); //just to be nice, let's make sure at least one spot gets placed in the spawn area that isn't behind any doors.

	minSearchRadius = 1000;
	remaining_array = [];

	foreach(zone in level.zones)
	{
		if(isDefined(zone.volumes) && IsArray(zone.volumes) && zone.volumes.size > 0)
		{
			for(i=0;i<zone.volumes.size;i++)
			{
				//if(i < max_per_volume)
				//	break;
				//PositionQuery_PointArray( origin, minSearchRadius, maxSearchRadius, halfHeight, innerSpacing, reachableBy_Ent )
				queryResult = PositionQuery_Source_Navigation( zone.volumes[i].origin, minSearchRadius, maxSearchRadius, halfHeight, innerSpacing, undefined, outerSpacing );

				foreach(point in queryResult.data)
				{
					zone = zm_zonemgr::get_zone_from_position(point.origin, true);
					if(isDefined(zone))
					{
						ARRAY_ADD(game["random_spawn_positions"], point.origin);
					}
				}
			}
		}
	}

	//remaining_array = array::randomize(remaining_array);
	//foreach(point in remaining_array)
	//	ARRAY_ADD(game["random_spawn_positions"], point);
}

function ugxm_game_over(player, game_over, survived)
{
	if(isDefined(level.tgTimer)) level.tgTimer Destroy();

	players = getplayers();
	for(i=0;i<players.size;i++)
		if(!IS_TRUE(level.ugxm_settings["custom_sounds"])) players[i] playsound("game_over");

	game_over.alignX = "center";
	game_over.alignY = "middle";
	game_over.horzAlign = "center";
	game_over.vertAlign = "middle";
	game_over.y -= 130;
	game_over.foreground = true;
	game_over.fontScale = 3;
	game_over.alpha = 0;
	game_over.color = ( 1.0, 1.0, 1.0 );
	game_over.hidewheninmenu = true;

	if(isDefined(level.ugxm_settings["endgame_text"]))
		game_over SetText(level.ugxm_settings["endgame_text"]);
	else
		game_over SetText( "Game Over!" );

	game_over FadeOverTime( 1 );
	game_over.alpha = 1;
	if ( player isSplitScreen() )
	{
		game_over.fontScale = 2;
		game_over.y += 40;
	}

	if(level.ugxm_settings["timed"])
	{
		new_survived = NewClientHudElem( player );

		secondsTxt = "";
		minsTxt = "";
		hoursTxt = "";
		daysTxt = "";
		
		if(level.tgTimerTime.seconds > 0)
		{
			secondsTxt = level.tgTimerTime.seconds + "s ";
		}
		if(level.tgTimerTime.minutes > 0)
		{
			minsTxt = level.tgTimerTime.minutes + "m ";
		}
		if(level.tgTimerTime.hours > 0)
		{
			hoursTxt = level.tgTimerTime.hours + "h ";
		}
		if(level.tgTimerTime.days > 0)
		{
			daysTxt = level.tgTimerTime.days + "d ";
		}
		if(daysTxt + hoursTxt + minsTxt + secondsTxt == "")
		{
			secondsTxt = "0s";
		}

		new_survived.alignX = "center";
		new_survived.alignY = "middle";
		new_survived.horzAlign = "center";
		new_survived.vertAlign = "middle";
		new_survived.y -= 100;
		new_survived.foreground = true;
		new_survived.fontScale = 2;
		new_survived.alpha = 0;
		new_survived.color = ( 1.0, 1.0, 1.0 );
		new_survived.hidewheninmenu = true;
		if ( player isSplitScreen() )
		{
			new_survived.fontScale = 1.5;
			new_survived.y += 40;
		}

		survived.y -= 999; //Hide the one we don't wait, shame on Treyarch for not allowing a clean override.
		
		new_survived setText("You survived " + daysTxt + hoursTxt + minsTxt + secondsTxt);
		new_survived FadeOverTime(1);
		new_survived.alpha = 1;

		thread destory_game_over_hud(new_survived);
	}
}

function destory_game_over_hud(hud)
{
	wait( level.zombie_vars["zombie_intermission_time"] );
	hud Destroy();
}

function prepare_arcademode()
{
	ugxm_util::game_setting("allow_ugx_bossround", true);
	ugxm_util::game_setting("allow_ugx_powerups", true);
	ugxm_util::powerup_setting("using_custom_powerups", true); //@todo
	
	//UGXMBO3 Powerup Drops
	ugxm_util::powerup_setting("invulnerability", true);
	ugxm_util::powerup_setting("terminator", true);
	ugxm_util::powerup_setting("quickfoot", true);
	ugxm_util::powerup_setting("multiplier", false);
	ugxm_util::powerup_setting("killshot", false);
	ugxm_util::powerup_setting("gun_1up", false);
	ugxm_util::powerup_setting("points_1up", false);
	ugxm_util::powerup_setting("pap_gun_upgrade", false);
}