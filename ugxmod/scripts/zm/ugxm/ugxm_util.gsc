#using scripts\shared\array_shared;
#using scripts\shared\flag_shared;
#using scripts\zm\_zm_weapons;
#using scripts\zm\_zm_blockers;
#using scripts\zm\_zm_utility;
#insert scripts\shared\shared.gsh;
#insert scripts\zm\_zm_perks.gsh;

function is_gamemode_weapon_allowed(weapon)
{
	if(weapon.weapclass == "item")
		return false;
	if(weapon.weapclass == "melee")
		return false;
	if(weapon.weapclass == "grenade")
		return false;
	if(weapon == level.weaponNone)
		return false;

	if(weapon.name == "idgun_1" || weapon.name == "idgun_2" || weapon.name == "idgun_3" || weapon.name == "idgun_4") //zm_zod
		return false;

	return true;
}

function force_zombie_health_vars()
{
	last_change = 0;
	level.zombie_vars["zombie_health_increase_multiplier"] = 0;
	level.zombie_vars["zombie_health_increase"] = 0;

	while(1)
	{
		if(level.round_number > last_change)
		{
			level.zombie_vars["zombie_health_increase_multiplier"] = 0;
			level.zombie_vars["zombie_health_increase"] = 0;
			last_change = level.round_number;
		}

		WAIT_SERVER_FRAME;
	}
}

function auto_doors_power_etc(open_all_doors = false, turn_on_power = false)
{
	if(!isDefined(level.zones))
		while(!IsDefined(level.zones))
			wait 0.1;

	if(open_all_doors)
	{
		trigs = getEntArray("trigger_use", "classname");
		for(i=0;i<trigs.size; i++)
		{
			if(!isDefined(trigs[i])) continue;
			if(!isDefined(trigs[i].script_flag)) continue;
			trigs[i] notify("trigger", level, true);
			wait 0.001;
		}

		foreach(zone_flag in getArrayKeys(level.zone_flags))
			level flag::set(zone_flag);

		level flag::set("open_all_blockers"); //the code above takes care of any generic blockers but if the mapper has any custom blockers, use this flag in your trig while loop to skip waiting 
										// or implement my force arg to your trigger waittill statement (see ugx modtools path _zombiemode_blocker_new.gsc, search for "force")

		zm_blockers::open_all_zbarriers(); //open all the windows for zombies

		//UGXMBO3-26 Not sure if any 3arc maps use flag blockers but here we go
		flag_blockers = GetEntArray( "flag_blocker", "targetname" );
		foreach(blocker in flag_blockers)
			level flag::set( blocker.script_flag_wait );
	}

	//UGXMBO3-26 - specifically for SoE and maybe other 3arc maps, turns on all power boxes
	if(level.script == "zm_zod" || level.script == "zm_dlc4" || level.script == "zm_genesis" || level.script == "zm_stalingrad" || level.script == "zm_island" || level.script == "zm_castle") 
	{
		stair_step = getEntArray("stair_step", "targetname");
		stair_clips = getEntArray("stair_clip", "targetname");
		stair_step = array_combine(stair_step, stair_clips);
		for(i=0;i<stair_step.size; i++)
		{
			if(!isDefined(stair_step[i])) continue;
			stair_step[i] NotSolid();
			stair_step[i] ConnectPaths();
			stair_step[i] hide();
		}
	}

	if(turn_on_power)
	{
		power_boxes = getEntArray("use_elec_switch", "targetname");
		for(i=0;i<power_boxes.size; i++)
		{
			power_boxes[i] notify("trigger", level, true);
			wait 0.001;
		}
	}
}

//@fixme this is from WaW, doesn't work 100% of the time
function set_zombie_run_cycle(speed)
{
	self set_run_speed(speed);

	//iPrintLnBold("Setting " + speed);

	switch(self.zombie_move_speed)
	{
	case "walk":
		rand = randomintrange(1, 8);         
		//iPrintLnBold("walk rand " + rand);
		self set_run_anim( "walk" + rand );                         
		self.run_combatanim = level.scr_anim[self.animname]["walk" + rand];
		break;
	case "run":                                
		rand = randomintrange(1, 6);
		//iPrintLnBold("run rand " + rand);
		self set_run_anim( "run" + rand );               
		self.run_combatanim = level.scr_anim[self.animname]["run" + rand];
		break;
	case "sprint":                             
		rand = randomintrange(14, 16);
		self set_run_anim( "sprint" + rand );          
		//iPrintLnBold("sprint rand " + rand);             
		self.run_combatanim = level.scr_anim[self.animname]["sprint" + rand];
		break;
	}
}
//@fixme this is from WaW
function set_run_speed(speed)
{
	rand = randomintrange( level.zombie_move_speed, level.zombie_move_speed + 35 ); 
	
//	self thread print_run_speed( rand );
	if(isDefined(speed))
	{
		self.zombie_move_speed = speed; 
	}
	else if( rand <= 35 )
	{
		self.zombie_move_speed = "walk"; 
	}
	else if( rand <= 70 )
	{
		self.zombie_move_speed = "run"; 
	}
	else
	{	
		self.zombie_move_speed = "sprint"; 
	}
}
//@fixme this is from WaW
function set_run_anim( anime, alwaysRunForward )
{	
	//this is good for slower run animations like patrol walks
	if( isdefined( alwaysRunForward ) )
		self.alwaysRunForward = alwaysRunForward;
	else
		self.alwaysRunForward = true;
		
	self.a.combatrunanim = level.scr_anim[ self.animname ][ anime ];
	self.run_noncombatanim = self.a.combatrunanim;
	self.walk_combatanim = self.a.combatrunanim;
	self.walk_noncombatanim = self.a.combatrunanim;
	self.preCombatRunEnabled = false;
}

function array_combine( array1, array2 )
{
	if( !array1.size )
		return array2; 

	array3 = [];
	
	keys = getarraykeys( array1 );
	for( i = 0;i < keys.size;i ++ )
	{
		key = keys[ i ];
		array3[ array3.size ] = array1[ key ]; 
	}	

	keys = getarraykeys( array2 );
	for( i = 0;i < keys.size;i ++ )
	{
		key = keys[ i ];
		array3[ array3.size ] = array2[ key ];
	}
	
	return array3; 
}

function play_pooled_announcer_vox(sound)
{
	index = self getEntityNumber();
	if(!isDefined(level.pending_announcer_vox)) level.pending_announcer_vox = [];
	if(!isDefined(level.pending_announcer_vox[index])) level.pending_announcer_vox[index] = [];
	level.pending_announcer_vox[index][level.pending_announcer_vox[index].size] = sound;
}
function pooled_announcer_vox()
{
	self endon("disconnect");
	index = self getEntityNumber();
	if(!isDefined(level.pending_announcer_vox)) level.pending_announcer_vox = [];
	if(!isDefined(level.pending_announcer_vox[index])) level.pending_announcer_vox[index] = [];

	while(1)
	{
		if(level.pending_announcer_vox[index].size > 0)
		{
			//iPrintln("** Playing pooled VOX: " + level.pending_announcer_vox[index][0]);
			//iPrintLnBold("** Playing pooled VOX: " + level.pending_announcer_vox[index][0]);
			self playlocalsound(level.pending_announcer_vox[index][0]);
			wait 2;
			newarray = [];
			if(level.pending_announcer_vox[index].size > 1) //remove the first index from the array and rebuild.
			{
				for(i=1;i<level.pending_announcer_vox[index].size;i++)
					newarray[newarray.size] = level.pending_announcer_vox[index][i];
				level.pending_announcer_vox[index] = newarray;
			}
			else
				level.pending_announcer_vox[index] = newarray;
		}
		WAIT_SERVER_FRAME;
	}
}

function array_reverse( array )
{
	array2 = [];
	for( i = array.size - 1; i >= 0; i -- )
		array2[ array2.size ] = array[ i ];
	return array2;
}

function get_array_random(array)
{
	temp = array::randomize(array);
	return temp[randomInt(temp.size)];
}

function game_setting(key, val)
{
	if(!isDefined(level.ugxm_settings))
		level.ugxm_settings = [];
	
	level.ugxm_settings[key] = val;
}
function boss_setting(key, val)
{
	if(!isDefined(level.ugxm_boss))
		level.ugxm_boss = [];
		
	level.ugxm_boss[key] = val;
}
function powerup_setting(key, val)
{
	if(!isDefined(level.ugxm_powerup_settings))
		level.ugxm_powerup_settings = [];
		
	level.ugxm_powerup_settings[key] = val;
}
function gungame_setting(key, val)
{
	if(!isDefined(level.ugxm_gungame))
		level.ugxm_gungame = [];
		
	level.ugxm_gungame[key] = val;
}
function add_gun(val)
{
	if(!isDefined(level.ugxm_guns))
		level.ugxm_guns = [];
		
	level.ugxm_guns[level.ugxm_guns.size] = val;
}
function add_gungame_gun(key, val)
{
	if(!isDefined(level.ugxm_gungame))
		level.ugxm_gungame = [];
		
	if(!isDefined(level.ugxm_gungame["guns"]))
		level.ugxm_gungame["guns"] = [];
		
	level.ugxm_gungame["guns"][key] = val;
}


function groundpos( origin )
{
	return bullettrace( origin, ( origin + ( 0, 0, -100000 ) ), 0, self )[ "position" ];
}

function playergroundpos(origin)
{
	return playerphysicstrace(origin, ( origin + ( 0, 0, -100000 ) ));
}

function create_custom_hud(alpha, player, text, index, color, xOffset, yOffset, type, alignX, alignY, horzAlign, vertAlign, fontScale)
{
	if(!isDefined(xOffset))
		xOffset = 0;
		
	if(!isDefined(type))
		type = "text";
	
	infoHud = create_simple_hud(player);
	infoHud.foreground = false; 
	infoHud.sort = 2; 
	infoHud.hidewheninmenu = false; 
	infoHud.alignX = alignX; 
	infoHud.alignY = alignY;
	infoHud.horzAlign = horzAlign; 
	infoHud.vertAlign = vertAlign;
	infoHud.x = 19 + xOffset; 
	infoHud.y = -190 + (index * 10 * fontScale) + yOffset; 
	infoHud.alpha = alpha;
	infoHud.color = color;
	infoHud.fontScale = fontScale;

	if(type == "text")
		infoHud SetText(text);
	else if(type == "timerup")
		infoHud SetTimerUp(text);
	else if(type == "timer")
		infoHud SetTimer(text);
	else if(type == "value")
		infoHud SetValue(text);
	
	return infoHud;
}

function create_info_hud(player, text, index, color, xOffset, type)
{
	if(!isDefined(xOffset))
		xOffset = 0;
		
	if(!isDefined(type))
		type = "text";
	
	infoHud = create_simple_hud(player);
	infoHud.foreground = false; 
	infoHud.sort = 2; 
	infoHud.hidewheninmenu = false; 
	infoHud.alignX = "left"; 
	infoHud.alignY = "bottom";
	infoHud.horzAlign = "left"; 
	infoHud.vertAlign = "bottom";
	infoHud.x = 19 + xOffset; 
	infoHud.y = -190 + (index * 10); 
	infoHud.alpha = 1;
	infoHud.color = color;
	
	if(type == "text")
		infoHud SetText(text);
	else if(type == "timerup")
		infoHud SetTimerUp(text);
	else if(type == "timer")
		infoHud SetTimer(text);
	else if(type == "value")
		infoHud SetValue(text);
	
	return infoHud;
}

function create_simple_hud( client )
{
	if( IsDefined( client ) )
	{
		hud = NewClientHudElem( client ); 
	}
	else
	{
		hud = NewHudElem(); 
	}

	level.hudelem_count++; 

	hud.foreground = true; 
	hud.sort = 1; 
	hud.hidewheninmenu = false; 

	return hud; 
}
function destroy_hud()
{
	level.hudelem_count--; 
	self Destroy(); 
}

function which_weapon_gets_the_ammo(newweapon)
{
	weapons = self GetWeaponsListPrimaries();
	foreach(weapon in weapons)
	{
		if(weapon.rootWeapon == newweapon.rootWeapon)
		{
			return weapon;
		}
	}
	return newweapon;
}

function weapon_give(weapon, give_random_attachment = false)
{
	if(!flag::exists("weapon_give_in_progress"))
		self flag::init("weapon_give_in_progress");

	if(self flag::get("weapon_give_in_progress"))	
		self flag::wait_till_clear( "weapon_give_in_progress" ); //if they get two weapons simultaneously for whatever reason, this will keep them from exceeding their inventory size and triggering the engine gun stealing
	
	self flag::set("weapon_give_in_progress");

	current_weapon = self getCurrentWeapon();

	//shitty compatibility between passing a string name or weapon ent to this function, for now.
	if(IsWeapon(weapon))
		weap = weapon;
	else
		weap = getWeapon(weapon);

	//iPrintLn("cw: " + current_weapon.name + ", new weap: " + weap.name);
	player_has_this_weapon = self zm_weapons::has_weapon_or_attachments(weap);
	player_has_upgrade = self zm_weapons::has_upgrade(weap);
	//iPrintLn("player_has_this_weapon: " + player_has_this_weapon + ", player_has_upgrade: " + player_has_upgrade);

	if( player_has_this_weapon)
	{
		weap = self which_weapon_gets_the_ammo(weap);
		ammo_given = self zm_weapons::ammo_give(weap); 

		if(ammo_given)
			self SwitchToWeapon(weap);

		//iPrintLn("^2Giving ammo for " + weap.name + ", done.");
		self flag::clear("weapon_give_in_progress");
		return;
	}
	else if(player_has_upgrade)
	{
		weap = level.zombie_weapons[weap.rootWeapon].upgrade;
		ammo_given = self ammo_give(weap); 
		if(ammo_given)
			self SwitchToWeapon(weap);
	}
	else if(zm_weapons::get_upgrade_weapon(current_weapon) == weap) //if they have the base weap and this new one is the upgraded form, replace the base with the upgrade.
	{
		//iPrintLn("^2Replacing weapon with upgraded " + weap.name + ", done.");
		self TakeWeapon(current_weapon);
		self giveWeapon(weap);
		self GiveMaxAmmo(weap);
		self SwitchToWeapon(weap);
		self flag::clear("weapon_give_in_progress");
		return;
	}
	//else //rest of the function is an else case for if the player does not have any form of the weap - in other words, give them a new fresh one with random attachments
	
	//iPrintLn("^3Giving brand-new " + weap.name);

	weapon_limit = zm_utility::get_player_weapon_limit( self );
	primaryWeapons = self GetWeaponsListPrimaries();
	
	//iPrintln("^5primaryWeapons.size [" + primaryWeapons.size + "], weapon limit [" + weapon_limit + "]");
	if(primaryWeapons.size >= weapon_limit)
	{
		//iPrintln("^1primaryWeapons.size [" + primaryWeapons.size + "] > weapon limit [" + weapon_limit + "]!");
		current_weapon = self getCurrentWeapon(); // get his current weapon
		self TakeWeapon(current_weapon);
	}
	self.inventorySize = weapon_limit;

	if(give_random_attachment && weap.name != "tesla_gun" && weap.name != "ray_gun")
	{
		//CalcWeaponOptions(  <camo>, <lens>, [reticle], [tag], [emblem], [paintshop], [isShowcaseWeapon] )
		options = self CalcWeaponOptions(RandomInt(125), 5, randomInt(10), 5, 5, 5, 1 );

		attachments = GetRandomCompatibleAttachmentsForWeapon(weap, 4);

		if(isDefined(attachments) && attachments.size > 1)
			weap = getWeapon(weap.name, attachments[0], attachments[1], attachments[2], attachments[3]);

		//Usage: GetWeapon( <weaponname>, [attachmentname_1 or array of attachments], [attachmentname_2], [attachmentname_3], [attachmentname_4], [attachmentname_5], [attachmentname_6], [attachmentname_7], [attachmentname_8] )
		//Summary: Get the requested weapon object based on game mode agnostic weapon name string
		//Example: GetWeapon( "ar_standard", "acog" );
		//Arg: //Mandatory//<weaponname> the name of the base weapon to return
		//Arg: //Optional//[attachmentname_1 or array of attachments] the name of the first attachment to return
		//Arg: //Optional//[attachmentname_2] the name of the second attachment to return
		//Arg: //Optional//[attachmentname_3] the name of the third attachment to return
		//Arg: //Optional//[attachmentname_4] the name of the fourth attachment to return
		//Arg: //Optional//[attachmentname_5] the name of the fifth attachment to return
		//Arg: //Optional//[attachmentname_6] the name of the sixth attachment to return
		//Arg: //Optional//[attachmentname_7] the name of the seventh attachment to return
		//Arg: //Optional//[attachmentname_8] the name of the eighth attachment to return
	}

	if(!isDefined(weap)) //in case trying to generate attachments above failed.
		weap = getWeapon(weapon);
	
	self giveWeapon(weap,options);
	self GiveMaxAmmo(weap);
	self SwitchToWeapon(weap);

	self flag::clear("weapon_give_in_progress");
}

function ammo_give(weapon)
{
	//shitty compatibility between passing a string name or weapon ent to this function, for now.
	if(isDefined(weapon.name))
		weap = weapon;
	else
		weap = getWeapon(weapon);

	weap = getWeapon(weapon);
	self giveMaxAmmo(weap);
}


function commaFormat(value)
{
	temp = "";
	num = string(value);
	size = num.size;
	if(size <= 3) return num; //no commas necessary
	for(i = size - 3; i >= 0; i -= 3)
	{
		if (i > 0) temp = "," + getsubstr(num, i, 3 + i) + temp;
 		else temp = getsubstr(num, i, 3) + temp;
	}
	if (i < 0) temp = getsubstr(num, 0, 3 + i) + temp;
	return temp;
}

function compareStringNumbers(num1, num2)
{ //Args: (string) num1, (string) num2
	if(num1.size > num2.size)
	{
		append = "";
		for(i=0; i<(num1.size - num2.size); i++)	
			append += "0";
		num2 = append + num2;
	}
	if(num2.size > num1.size)
	{
		append = "";
		for(i=0; i<(num2.size - num1.size); i++)	
			append += "0";
		num1 = append + num1;
	}

	///# printLn("^1############# String Number Comparison ##############"); #/
	///# printLn("num1: " + num1); #/
	///# printLn("num2: " + num2); #/
	
	for(i=0; i<num1.size; i++)
	{
		comp1 = int(getSubStr(num1, i - 1, i));
		comp2 = int(getSubStr(num2, i - 1, i));
		if(comp1 > comp2) {
			///# printLn("num1 wins"); #/
			return 1;
		}
		else if(comp1 < comp2) {
			///# printLn("num2 wins"); #/
			return -1;
		}
		//if they are equal then continue the loop until we find one number that is larger than the second.
	}
	///# printLn("nums are equal!"); #/
	return 0; //the numbers are equal
}

function createBar( color, width, height, flashFrac )
{
	barElem = newClientHudElem(	self );
	barElem.x = 0 ;
	barElem.y = 0;
	barElem.frac = 0;
	barElem.color = color;
	barElem.sort = -2;
	barElem.shader = "white";
	barElem setShader( "white", width, height );
	barElem.hidden = false;
	if ( isDefined( flashFrac ) )
	{
		barElem.flashFrac = flashFrac;
//		barElem thread flashThread();
	}
	barElem.hidewheninmenu = false; 
	//barElem.alignX = "left"; 
	//barElem.alignY = "bottom";
	//barElem.horzAlign = "left"; 
	//barElem.vertAlign = "bottom";

	barElemFrame = newClientHudElem( self );
	barElemFrame.elemType = "icon";
	barElemFrame.x = 0;
	barElemFrame.y = 0;
	barElemFrame.width = width;
	barElemFrame.height = height;
	barElemFrame.xOffset = 0;
	barElemFrame.yOffset = 0;
	barElemFrame.bar = barElem;
	barElemFrame.barFrame = barElemFrame;
	barElemFrame.children = [];
	barElemFrame.sort = -1;
	barElemFrame.color = (1,1,1);
	barElemFrame setParent( level.uiParent );
	//barElemFrame setShader( "progress_bar_fg", width, height );
	barElemFrame.hidden = false;
	barElemFrame.hidewheninmenu = false; 
	//barElemFrame.alignX = "left"; 
	//barElemFrame.alignY = "bottom";
	//barElemFrame.horzAlign = "left"; 
	//barElemFrame.vertAlign = "bottom";

	barElemBG = newClientHudElem( self );
	barElemBG.elemType = "bar";
	if ( !level.splitScreen )
	{
		barElemBG.x = -2;
		barElemBG.y = -2;
	}
	barElemBG.width = width;
	barElemBG.height = height;
	barElemBG.xOffset = 0;
	barElemBG.yOffset = 0;
	barElemBG.bar = barElem;
	barElemBG.barFrame = barElemFrame;
	barElemBG.children = [];
	barElemBG.sort = -3;
	barElemBG.color = (0,0,0);
	barElemBG.alpha = 0.5;
	barElemBG setParent( level.uiParent );
	//barElemBG.alignX = "left"; 
	//barElemBG.alignY = "bottom";
	//barElemBG.horzAlign = "left"; 
	//barElemBG.vertAlign = "bottom";
	if ( !level.splitScreen )
		barElemBG setShader( "black", width + 4, height + 2 );
	else
		barElemBG setShader( "black", width + 0, height + 0 );
	barElemBG.hidden = false;

	return barElemBG;
}


function createPrimaryProgressBar()
{
	level.primaryProgressBarHeight = 3;
	level.primaryProgressBarY = -125; //yOffset

	bar = createBar( (1, 1, 1), level.primaryProgressBarWidth, level.primaryProgressBarHeight );
	if ( level.splitScreen )
		bar setPoint("TOP", undefined, level.primaryProgressBarX, level.primaryProgressBarY);
	else
		bar setPoint("BOTTOM", undefined, level.primaryProgressBarX, level.primaryProgressBarY);

	return bar;
}

function create_progressbar(player, color, width, height, x, y)
{
	if(!isDefined(x)) x = 0;
	if(!isDefined(y)) y = 0;
	barElem = create_simple_hud(player);
	barElem.x = 0;
	barElem.y = 0;
	barElem.frac = 0;
	barElem.color = color;
	barElem.sort = -2;
	barElem.shader = "white";
	barElem setShader("white", width, height);
	
	barElemBG = create_simple_hud(player);
	barElemBG.elemType = "bar";
	barElemBG.x = -2;
	barElemBG.y = -2;
	barElemBG.width = width;
	barElemBG.height = height;
	barElemBG.xOffset = 0;
	barElemBG.yOffset = 0;
	barElemBG.bar = barElem;
	barElemBG.children = [];
	barElemBG.sort = -3;
	barElemBG.color = (0,0,0);
	barElemBG.alpha = 0.5;
	barElemBG setShader( "black", width + 4, height + 4 );

	barElemBG setPoint("TOP", undefined, 0 + x, 10 + y);
	
	barElem.y += 2; // Must do this after
	
	barElemBG.bar_element = barElem;
	
	barElemBG progressbar_setvalue(0, 100);
	return barElemBG;
}
function progressbar_setvalue(value, total)
{
	if(total < 1 || value > total || value < 0)
		return;
	
	self.bar.frac = value;
	
	if(value == 0)
	{
		self.bar setShader("black", 1, self.height);
		self.bar.alpha = 0;
		return;
	}
	else
	{
		self.bar setShader("white", 1, self.height);
		self.bar.alpha = 1;
	}	
	
	width = int((value / total) * self.width);
	
	if(width == 0)
		width = 1;
	
	self.bar setShader(self.bar.shader, width, self.height);
}

function string(input)
{
	return "" + input;
}

function destroyElem()
{
	tempChildren = [];

	for ( index = 0; index < self.children.size; index++ )
		tempChildren[index] = self.children[index];

	for ( index = 0; index < tempChildren.size; index++ )
		tempChildren[index] setParent( self getParent() );
		
	if ( self.elemType == "bar" )
	{
		self.bar destroy();
		if(isDefined(self.barFrame)) self.barFrame destroy(); //UGX_SCRIPT: fixing treyarch fails.
	}
		
	self destroy();
}

function setParent( element )
{
	if ( isDefined( self.parent ) && self.parent == element )
		return;
		
	if ( isDefined( self.parent ) )
		self.parent removeChild( self );

	self.parent = element;
	self.parent addChild( self );

	if ( isDefined( self.point ) )
		self setPoint( self.point, self.relativePoint, self.xOffset, self.yOffset );
	else
		self setPoint( "TOPLEFT" );
}

function getParent()
{
	if(!isDefined(self.parent)) self.parent = level.uiParent; //UGX_SCRIPT: fixing treyarch fails.
	return self.parent;
}

function addChild( element )
{
	element.index = self.children.size;
	self.children[self.children.size] = element;
}

function removeChild( element )
{
	element.parent = undefined;

	if ( self.children[self.children.size-1] != element )
	{
		self.children[element.index] = self.children[self.children.size-1];
		self.children[element.index].index = element.index;
	}
	self.children[self.children.size-1] = undefined;
	
	element.index = undefined;
}

function updateChildren()
{
	for ( index = 0; index < self.children.size; index++ )
	{
		child = self.children[index];
		child setPoint( child.point, child.relativePoint, child.xOffset, child.yOffset );
	}
}

function setPoint( point, relativePoint, xOffset, yOffset, moveTime )
{
	if ( !isDefined( moveTime ) )
		moveTime = 0;

	element = self getParent();

	if ( moveTime )
		self moveOverTime( moveTime );
	
	if ( !isDefined( xOffset ) )
		xOffset = 0;
	self.xOffset = xOffset;

	if ( !isDefined( yOffset ) )
		yOffset = 0;
	self.yOffset = yOffset;
		
	self.point = point;

	self.alignX = "center";
	self.alignY = "middle";

	if ( isSubStr( point, "TOP" ) )
		self.alignY = "top";
	if ( isSubStr( point, "BOTTOM" ) )
		self.alignY = "bottom";
	if ( isSubStr( point, "LEFT" ) )
		self.alignX = "left";
	if ( isSubStr( point, "RIGHT" ) )
		self.alignX = "right";

	if ( !isDefined( relativePoint ) )
		relativePoint = point;

	self.relativePoint = relativePoint;

	relativeX = "center";
	relativeY = "middle";

	if ( isSubStr( relativePoint, "TOP" ) )
		relativeY = "top";
	if ( isSubStr( relativePoint, "BOTTOM" ) )
		relativeY = "bottom";
	if ( isSubStr( relativePoint, "LEFT" ) )
		relativeX = "left";
	if ( isSubStr( relativePoint, "RIGHT" ) )
		relativeX = "right";

	if ( element == level.uiParent )
	{
		self.horzAlign = relativeX;
		self.vertAlign = relativeY;
	}
	else
	{
		self.horzAlign = element.horzAlign;
		self.vertAlign = element.vertAlign;
	}


	if ( relativeX == element.alignX )
	{
		offsetX = 0;
		xFactor = 0;
	}
	else if ( relativeX == "center" || element.alignX == "center" )
	{
		offsetX = int(element.width / 2);
		if ( relativeX == "left" || element.alignX == "right" )
			xFactor = -1;
		else
			xFactor = 1;	
	}
	else
	{
		offsetX = element.width;
		if ( relativeX == "left" )
			xFactor = -1;
		else
			xFactor = 1;
	}
	self.x = element.x + (offsetX * xFactor);

	if ( relativeY == element.alignY )
	{
		offsetY = 0;
		yFactor = 0;
	}
	else if ( relativeY == "middle" || element.alignY == "middle" )
	{
		offsetY = int(element.height / 2);
		if ( relativeY == "top" || element.alignY == "bottom" )
			yFactor = -1;
		else
			yFactor = 1;	
	}
	else
	{
		offsetY = element.height;
		if ( relativeY == "top" )
			yFactor = -1;
		else
			yFactor = 1;
	}
	self.y = element.y + (offsetY * yFactor);
	
	self.x += self.xOffset;
	self.y += self.yOffset;
	
	switch ( self.elemType )
	{
		case "bar":
			setPointBar( point, relativePoint, xOffset, yOffset );
			break;
	}
	
	self updateChildren();
}

// CODER_MOD: Austin (8/4/08): port progress bar script from MP
function setPointBar( point, relativePoint, xOffset, yOffset )
{
	self.bar.horzAlign = self.horzAlign;
	self.bar.vertAlign = self.vertAlign;
	
	self.bar.alignX = "left";
	self.bar.alignY = self.alignY;
	self.bar.y = self.y;
	
	if ( self.alignX == "left" )
		self.bar.x = self.x;
	else if ( self.alignX == "right" )
		self.bar.x = self.x - self.width;
	else
		self.bar.x = self.x - int(self.width / 2);
	
	if ( self.alignY == "top" )
		self.bar.y = self.y;
	else if ( self.alignY == "bottom" )
		self.bar.y = self.y;

	self updateBar( self.bar.frac );
}


function updateBar( barFrac, rateOfChange )
{
	if ( self.elemType == "bar" )
		updateBarScale( barFrac, rateOfChange );
}


function updateBarScale( barFrac, rateOfChange ) // rateOfChange is optional and is in "(entire bar lengths) per second"
{
	barWidth = int(self.width * barFrac + 0.5); // (+ 0.5 rounds)

	if ( !barWidth )
		barWidth = 1;

	self.bar.frac = barFrac;
	self.bar setShader( self.bar.shader, barWidth, self.height );


	//if barWidth is bigger than self.width then we are drawing more than 100%
	if ( isDefined( rateOfChange ) && barWidth < self.width ) 
	{
		if ( rateOfChange > 0 )
		{
			//printLn( "scaling from: " + barWidth + " to " + self.width + " at " + ((1 - barFrac) / rateOfChange) );
			self.bar scaleOverTime( (1 - barFrac) / rateOfChange, self.width, self.height );
		}
		else if ( rateOfChange < 0 )
		{
			//printLn( "scaling from: " + barWidth + " to " + 0 + " at " + (barFrac / (-1 * rateOfChange)) );
			self.bar scaleOverTime( barFrac / (-1 * rateOfChange), 1, self.height );
		}
	}
	self.bar.rateOfChange = rateOfChange;
	self.bar.lastUpdateTime = getTime();
}
/* End UGXM Gungame */

function timed_gameplay()
{
	level.isTimedGameplay = true;
	if(level.ugxm_settings["gamemode"] == 3 || level.ugxm_settings["gamemode"] == 5 || level.ugxm_settings["gamemode"] == 6) level.ugxm_settings["timed"] = true; //force timed gameplay for Sharpshooter, King of the Hill, and Chaos mode
	if(level.ugxm_settings["gamemode"] == 1) offset = 20; //move the hud down for gungame
	else offset = 0;

	if(level.ugxm_settings["gamemode"] == 6)
		level.ugxm_settings["game_time"] = 120;

	level.tgTimerTime = SpawnStruct();
	level.tgTimerTime.days = 0;
	level.tgTimerTime.hours = 0;
	level.tgTimerTime.minutes = 0;
	level.tgTimerTime.seconds = 0;
	level.tgTimerTime.toalSec = 0;
	
	wait 0.4;
	
	if(isDefined(level.tgTimer)) level.tgTimer Destroy();
	level.tgTimer = NewHudElem();
	level.tgTimer.foreground = false; 
	level.tgTimer.sort = 2; 
	level.tgTimer.hidewheninmenu = false; 
	level.tgTimer.font = "big";

	if(level.ugxm_settings["gamemode"] == 6)
		level.tgTimer.fontScale = 2.5;
	
	level.tgTimer.alignX = "left"; 
	if(level.ugxm_settings["gamemode"] == 6)
		level.tgTimer.alignX = "center"; 
	
	level.tgTimer.alignY = "bottom";
	if(level.ugxm_settings["gamemode"] == 6)
		level.tgTimer.alignY = "top";
	
	level.tgTimer.horzAlign = "left"; 
	if(level.ugxm_settings["gamemode"] == 6)
		level.tgTimer.horzAlign = "center"; 
	
	level.tgTimer.vertAlign = "bottom";
	if(level.ugxm_settings["gamemode"] == 6)
		level.tgTimer.vertAlign = "top";
	
	level.tgTimer.x = 19; 
	if(level.ugxm_settings["gamemode"] == 6)
		level.tgTimer.x = 0; 
	
	level.tgTimer.y = - 80 + offset; 
	if(level.ugxm_settings["gamemode"] == 6)
		level.tgTimer.y = 27; 
	
	level.tgTimer.alpha = 0;
	
	if((level.ugxm_settings["gamemode"] == 3 || level.ugxm_settings["gamemode"] == 4 || level.ugxm_settings["gamemode"] == 5 || level.ugxm_settings["gamemode"] == 6) && level.ugxm_settings["game_time"] != -1)
	{
		level.tgTimer SetTimer(level.ugxm_settings["game_time"]);
	}
	else
	{
		level.tgTimer SetTimerUp(0);
	}
	
	thread timed_gameplay_bg_counter();
	
	if(level.ugxm_settings["gamemode"] != 6)
	{
		level.tgTimerDes = create_simple_hud();
		level.tgTimerDes.foreground = false; 
		level.tgTimerDes.sort = 2; 
		level.tgTimerDes.hidewheninmenu = false; 
		level.tgTimerDes.alignX = "left"; 
		level.tgTimerDes.alignY = "bottom";
		level.tgTimerDes.horzAlign = "left"; 
		level.tgTimerDes.vertAlign = "bottom";
		level.tgTimerDes.x = 19; 
		level.tgTimerDes.y = - 80 + offset; 
		level.tgTimerDes.alpha = 1;
		
		text = "Timed Gameplay";
		level.tgTimerDes SetPulseFx( 70, 2910, 500 );
		
		already_printed = "";
		for(i=0;i<text.size;i++)
		{
			already_printed += text[i];
			level.tgTimerDes SetText(already_printed);
			
			if(text[i] != " ")
				wait(0.07);
		}
		
		wait(1);
		level.tgTimerDes FadeOverTime(1);
		level.tgTimerDes.alpha = 0;
		level.tgTimer FadeOverTime(1);
		level.tgTimer.alpha = 1;
		
		wait 1;
		
		level.tgTimerDes Destroy();
	}
	level.tgTimer.alpha = 1;
}
function timed_gameplay_bg_counter_flash()
{
	on = false;
	
	while(1)
	{
		wait 0.5;
		
		ss_time_left = level.ugxm_settings["game_time"] - level.tgTimerTime.toalSec;
		
		if(ss_time_left <= 5)
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
		
		if(ss_time_left <= 0 && level.ugxm_settings["gamemode"] == 3)
		{
			return;
		}
	}
}
function timed_gameplay_bg_counter()
{
	level endon("end_game");
	if((level.ugxm_settings["gamemode"] == 3 || level.ugxm_settings["gamemode"] == 4 || level.ugxm_settings["gamemode"] == 5 || level.ugxm_settings["gamemode"] == 6) && level.ugxm_settings["game_time"] != -1)
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

		
		
		if((level.ugxm_settings["gamemode"] == 3 || level.ugxm_settings["gamemode"] == 4 || level.ugxm_settings["gamemode"] == 5 || level.ugxm_settings["gamemode"] == 6) && level.ugxm_settings["game_time"] != -1
			&& !level.ugxm_settings["extended_time"])
		{
			ss_time_left = level.ugxm_settings["game_time"] - level.tgTimerTime.toalSec;

			/# printLn(ss_time_left + " seconds left in game"); #/
			
			if(ss_time_left <= 0 && level.ugxm_settings["gamemode"] == 6)
			{
				//thread maps\ugxm_chaosmode::game_complete();
				level.ugxm_settings["extended_time"] = true;
				//return;
			}
		}
	}
}