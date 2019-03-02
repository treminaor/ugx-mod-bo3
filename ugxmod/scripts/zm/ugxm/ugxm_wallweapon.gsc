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
#using scripts\shared\util_shared;

#using scripts\zm\_zm_score;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;

#using scripts\shared\system_shared;

//UGX
//#using scripts\zm\ugxm\ugxm_util;

#precache( "model", "ugx_weapon_box");
#precache( "xanim", "ugx_weapon_box_spin");
#precache( "xanim", "ugx_weapon_box_spin_back");

#using_animtree("ugx_box_anims");

//#namespace ugxm_wallweapon;


#insert scripts\shared\shared.gsh;
//#insert scripts\shared\version.gsh;

REGISTER_SYSTEM_EX( "ugxm_wallweapon", &__init__, &__main__, "zm" ) //level._loadStarted

function __init__()
{
	level.scr_anim["ugx_weapon_box_spin"] = %ugx_weapon_box_spin;
	level.scr_anim["ugx_weapon_box_spin_back"] = %ugx_weapon_box_spin_back;

	
}

function __main__()
{
	//trigs = getEntArray("ugx_wallweapon", "targetname");
	//for(i=0;i<trigs.size;i++)
	//	trigs[i] thread ugx_wallweapon_think();

	weapon_spawns = [];
	weapon_spawns = struct::get_array( "weapon_upgrade", "targetname" ); 

	/*IPrintLn("^5 weapon_spawn __main__");

	for ( i = 0; i < weapon_spawns.size; i++ )
	{
		iPrintLn("^1wallweapon spawn " + i);
		weapon_spawns[i].weapon = GetWeapon( weapon_spawns[i].zombie_weapon_upgrade );

		weapon_model = getEnt(weapon_spawns[i].target, "targetname");
		if(isDefined(weapon_model))
		{
			iPrintLn("^2wallweapon model defined " + i);

			weapon_box_model = getEnt(weapon_model.target, "targetname");
			if(isDefined(weapon_box_model))
			{
				iPrintLn("^5wallweapon box model " + i);
				weapon_spawns[i] thread ugx_wallweapon_spin(weapon_box_model);
			}
		}
	}*/
}

function getZombieWeapon(weapon_string)
{
	weapon = getWeapon(weapon_string);
	keys = getArrayKeys(level.zombie_weapons);
	for(i=0;i<level.zombie_weapons.size;i++)
	{
		//iPrintLn("Checking " + keys[i].displayName + " against " + weapon_string + " (" + weapon.displayName + ")");
		if(keys[i] == weapon)
		{
			//iPrintLn("^5found " + keys[i].displayName);
			return keys[i];
		}
		//else
		//	iPrintLn("^ " + keys[i].displayName + " is not it");

		//wait 1;
	}
	//iPrintLn("^3 FAILED");
	return weapon;
}

function ugx_wallweapon_think()
{
	//self setCursorHint("HINT_NOICON");
	//self UseTriggerRequireLookAt(); //passed in setHintString below
	self.hacked = false;
	self.ugx_wallbuy = true;
	if(!IS_TRUE(level.ugxm_settings["allow_wall_guns"]))
	{
		return;
	}
	model = getEnt(self.target, "targetname");
	weapon_name = self.zombie_weapon_upgrade;
	weapon = getZombieWeapon(weapon_name);


	//weaponStruct = level.zombie_weapons[weapon];
	//cost = weaponStruct.cost;
	//ammo_cost = weaponStruct.ammo_cost;
	upgraded_ammo = 2000; //unknown

	//hint_string = zm_weapons::get_weapon_hint( weapon );
	hint_string = level.zombie_weapons[weapon].weapon_classname;
	cost = zm_weapons::get_weapon_cost( weapon );
	ammo_cost = zm_weapons::get_ammo_cost( weapon ); 
	upgraded_ammo = zm_weapons::get_upgraded_ammo_cost( weapon ); 


	/*
	cursor_hint = "HINT_WEAPON";
	cursor_hint_weapon = weapon;
	self setCursorHint( cursor_hint, cursor_hint_weapon ); 

	self.hint_string = &"ZOMBIE_WEAPONCOSTONLYFILL"; 			
	self SetHintString( self.hint_string, cost);
	*/

	self thread ugx_wallweapon_spin(model);

	while(1)
	{
		self waittill("trigger", player);

		if(!zm_utility::is_player_valid(player))
		{
			wait 0.5;
			continue;
		}

		weap = getWeapon(self.zombie_weapon_upgrade);
		//too lazy to bother cleaning any of this up, copied from the original script - should work fine.
		//player_has_weapon = player has_weapon_or_upgrade( self.zombie_weapon_upgrade );
		//player_has_weapon = player HasWeapon(weap);
		player_has_weapon = false;
		if( !player_has_weapon )
		{
			// else make the weapon show and give it
			if( player.score >= cost )
			{
				player zm_score::minus_to_player_score(cost);
				player playsound("zmb_cha_ching");
				self.respin = true;
				
				player giveWeapon(weap);
				player SwitchToWeapon(weap);


				// UGX_SCRIPT - challenges
				player.ugxm_challenge_bought_weapon = true;
				// UGX_SCRIPT END
			}
			else
			{
				player playsound("zmb_no_cha_ching");
				//player thread maps\nazi_zombie_sumpf_blockers::play_no_money_purchase_dialog();
			}
		}/*
		else
		{
			// MM - need to check and see if the player has an upgraded weapon.  If so, the ammo cost is much higher
			if(player has_elemental( self.zombie_weapon_upgrade ))
				ammo_cost = get_elemental_ammo_cost( self.zombie_weapon_upgrade ); 
			else if ( player has_upgrade( self.zombie_weapon_upgrade ))
				ammo_cost = get_upgraded_ammo_cost( self.zombie_weapon_upgrade ); 
			else
				ammo_cost = get_ammo_cost( self.zombie_weapon_upgrade );
			//treminaor: added swapping code for hacker device.
			if(isDefined(self.hacked) && self.hacked)
			{
				if(player has_upgrade( self.zombie_weapon_upgrade ) || player has_elemental(self.zombie_weapon_upgrade))
					ammo_cost = get_ammo_cost( self.zombie_weapon_upgrade );
				else
					ammo_cost = get_upgraded_ammo_cost( self.zombie_weapon_upgrade ); 
			}

			// if the player does have this then give him ammo.
			if( player.score >= ammo_cost )
			{
				if( player HasWeapon( self.zombie_weapon_upgrade ) && player has_upgrade( self.zombie_weapon_upgrade ) )
					ammo_given = player ammo_give( self.zombie_weapon_upgrade, true ); 
				else if( player has_upgrade( self.zombie_weapon_upgrade ) )
					ammo_given = player ammo_give( self.zombie_weapon_upgrade+"_upgraded" ); 
				else if( player has_elemental( self.zombie_weapon_upgrade ) )
					ammo_given = player ammo_give( self.zombie_weapon_upgrade+"_elemental" ); 
				else if( self.zombie_weapon_upgrade == "semtex" ) //dont let them buy semtex ammo when they have 4 already
				{
					if(player getammocount("semtex") == 4) //max ammo
						ammo_given = false;
					else 
						ammo_given = player ammo_give( self.zombie_weapon_upgrade );
				}
				else
					ammo_given = player ammo_give( self.zombie_weapon_upgrade ); 
				
				if( ammo_given )
						player maps\_zombiemode_score::minus_to_player_score( ammo_cost ); // this give him ammo to early
			}
			else
				player playsound("no_cha_ching");
		}
		*/
	}
}

function ugx_wallweapon_spin(model)
{
	length = getAnimLength(level.scr_anim["ugx_weapon_box_spin"]);
	length2 = getAnimLength(level.scr_anim["ugx_weapon_box_spin_back"]);

	tag = "tag_weapon";
	//if(is_sniper_rifle(self.zombie_weapon_upgrade)) tag = "tag_sniper";
	//if(self.zombie_weapon_upgrade == "cheytac") tag = "tag_sniper_long";
	//if(self.zombie_weapon_upgrade == "semtex") tag = "tag_sniper";
	offset = (0,0,5);
	if(isSubStr(self.zombie_weapon_upgrade, "thunderg")) offset = (0,0,5); 
	self.weap = spawn( "script_model", model getTagOrigin(tag) + offset);
	self.weap.angles  = model getTagAngles("tag_weapon");
	//self.weap setModel("wpn_t7_smg_ap9_world"); 
	self.weap setModel(GetWeaponWorldModel(GetWeapon(self.zombie_weapon_upgrade))); 
	self.weap LinkTo(model, tag);

	self.weap hide();

	
	while(1)
	{
		if(self ugx_wallweapon_isopen())
		{
			self.weap show();
			model useanimtree(#animtree);
			model AnimScripted( "ugx_weapon_box_spin", model.origin , model.angles, level.scr_anim["ugx_weapon_box_spin"]);
			model playsound("ugx_weapons_box_open");
			wait length;
			while(self ugx_wallweapon_isopen())
				wait 0.1;
			model useanimtree(#animtree);
			model AnimScripted( "ugx_weapon_box_spin_back", model.origin , model.angles, level.scr_anim["ugx_weapon_box_spin_back"]);
			model playsound("ugx_weapons_box_close");
			wait length2;
			self.weap hide();
		}
		wait 0.1;
	}

	
}

function ugx_wallweapon_isopen()
{
	if(isDefined(self.hacked) && self.hacked) return true;
	if(isDefined(self.respin))
	{
		self.respin = undefined;
		self.weap hide();
		return false;
	}
	players = getPlayers();
	open = false;
	for(i=0;i<players.size;i++)
		if(distance(self.origin, players[i] getOrigin()) < 200)
			open = true;

	return open;
}
/* End UGX Weapon Box */
