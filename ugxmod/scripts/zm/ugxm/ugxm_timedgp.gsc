/*
	Created by Andy King (treminaor) for UGX-Mods.com. © UGX-Mods 2016
	Please include credit if you use this script and do not distribute edited versions of it without our permission.
	Contact: general@ugx-mods.com
*/

#using scripts\shared\flag_shared;

#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_utility;

#using scripts\shared\ai\zombie_death;
#using scripts\shared\ai\zombie_utility;

#using scripts\zm\ugxm\ugxm_chaosmode;

#insert scripts\shared\shared.gsh;

//default round_wait func but without a check for zero zombies alive, which allows for continuous spawning
function round_wait_override()
{
	level endon("restart_round");
	level endon( "kill_round" );

	wait( 1 );

	while( 1 )
	{
		should_wait = ( level.zombie_total > 0 || level.intermission );	
		if( !should_wait )
		{
			return;
		}			
			
		if( level flag::get( "end_round_wait" ) )
		{
			return;
		}
		wait( 1.0 );
	}
}

function timed_gameplay()
{
	level.isTimedGameplay = true;

	if(!isDefined(level.ugxm_settings["timed_hud_offset"]))
		level.ugxm_settings["timed_hud_offset"] = 0;

	if(!isDefined(level.ugxm_settings["game_time"]))
		level.ugxm_settings["game_time"] = 120;

	wait 0.4;

	level.tgTimerTime = SpawnStruct();

	level.tgTimerTime.days = 0;
	level.tgTimerTime.hours = 0;
	level.tgTimerTime.minutes = 0;
	level.tgTimerTime.seconds = 0;
	level.tgTimerTime.toalSec = 0;
	
	level.tgTimer.foreground = false; //hudelem created in ugxm_init::init();
	level.tgTimer.sort = 2; 
	level.tgTimer.hidewheninmenu = false; 
	level.tgTimer.font = "big";

	if(!isDefined(level.tgTimer.fontScale))	
		level.tgTimer.fontScale = 1;

	//@fixme these overrides are needed for Chaos Mode to take over the timer HUD, but if you only use isDefined to check them, it doesnt work because the game sets some defaults for alignment
	if(!IS_TRUE(level.ugxm_settings["timed_gp_custom_hud_location"]))
		level.tgTimer.alignX = "left"; 
	
	if(!IS_TRUE(level.ugxm_settings["timed_gp_custom_hud_location"]))
		level.tgTimer.alignY = "bottom";

	if(!IS_TRUE(level.ugxm_settings["timed_gp_custom_hud_location"]))
		level.tgTimer.horzAlign = "left";  
	
	if(!IS_TRUE(level.ugxm_settings["timed_gp_custom_hud_location"]))
		level.tgTimer.vertAlign = "bottom";
	
	if(!isDefined(level.tgTimer.x))
		level.tgTimer.x = 40; 
	
	if(!isDefined(level.tgTimer.y))
		level.tgTimer.y = - 65 + level.ugxm_settings["timed_hud_offset"]; 
	
	level.tgTimer.alpha = 0;
	
	//if((level.ugxm_settings["gamemode"] == 3 || level.ugxm_settings["gamemode"] == 4 || level.ugxm_settings["gamemode"] == 5 || level.ugxm_settings["gamemode"] == 6) && level.ugxm_settings["game_time"] != -1)
	if(IS_TRUE(level.ugxm_settings["timer_goes_down"]) && level.ugxm_settings["game_time"] != -1)
	{
		level.tgTimer SetTimer(level.ugxm_settings["game_time"]);
	}
	else
	{
		level.tgTimer SetTimerUp(0);
	}
	
	thread timed_gameplay_bg_counter();
	
	level.tgTimer.alpha = 1;
}
function timed_gameplay_bg_counter_flash()
{
	on = false;
	
	while(1)
	{
		wait 0.25;

		ss_time_left = level.ugxm_settings["game_time"] - level.tgTimerTime.toalSec;

		if(ss_time_left <= 10)
		{
			on = !on;
		}
		else
		{
			on = false;
		}
		
		if(on)
		{
			if(isDefined(level.tgTimer)) level.tgTimer.color = (1, 0.1, 0);
		}
		else
		{
			if(isDefined(level.tgTimer)) level.tgTimer.color = (1, 1, 1);
		}
		
		if(ss_time_left <= 0 && level.ugxm_settings["gamemode"] == 3) //@fixme gamemode specific checks outside of gamemode.gsc are against new standard
		{
			return;
		}
	}
}
function timed_gameplay_bg_counter()
{
	level endon("end_game");
	if(IS_TRUE(level.ugxm_settings["timed_gp_flash_low_time"]) && level.ugxm_settings["game_time"] != -1)
		thread timed_gameplay_bg_counter_flash();

	level.ugxm_settings["extended_time"] = false;
		
	// need to have a code timer to get text for game over screen
	while(1)
	{	
		if(level.tgTimerTime.seconds >= 59) //REQUIEM-182
		{
			level.tgTimerTime.seconds = 0;
			level.tgTimerTime.minutes ++;
		}
		
		if(level.tgTimerTime.minutes >= 59) //REQUIEM-182
		{
			level.tgTimerTime.minutes = 0;
			level.tgTimerTime.hours ++;
		}
		
		if(level.tgTimerTime.hours >= 23) //REQUIEM-182
		{
			level.tgTimerTime.hours = 0;
			level.tgTimerTime.days ++;
		}
		
		level.tgTimerTime.seconds ++;
		level.tgTimerTime.toalSec ++;

		wait 1;

		/# printLn("^5<Tick>"); #/
		
		//@fixme gamemode-specific checks outside of gamemode files are against new standard, remove and replace.
		if((level.ugxm_settings["gamemode"] == 3 || level.ugxm_settings["gamemode"] == 4 || level.ugxm_settings["gamemode"] == 5 || level.ugxm_settings["gamemode"] == 6) && level.ugxm_settings["game_time"] != -1
			&& !level.ugxm_settings["extended_time"])
		{
			ss_time_left = level.ugxm_settings["game_time"] - level.tgTimerTime.toalSec;

			/# printLn(ss_time_left + " seconds left in game"); #/
			
			if(ss_time_left <= 0 && level.ugxm_settings["gamemode"] == 3)
			{
				//ugxm_sharpshooter::game_complete();
				return;
			}
			if(ss_time_left <= 0 && level.ugxm_settings["gamemode"] == 4)
			{
				//ugxm_bountyhunter::game_complete();
				return;
			}
			if(ss_time_left <= 0 && level.ugxm_settings["gamemode"] == 5)
			{
				//ugxm_kingofthehill::game_complete();
				return;
			}
			if(ss_time_left <= 0 && level.ugxm_settings["gamemode"] == 6)
			{
				thread ugxm_chaosmode::game_complete();
				level.ugxm_settings["extended_time"] = true;
				//return;
			}
		}
	}
}