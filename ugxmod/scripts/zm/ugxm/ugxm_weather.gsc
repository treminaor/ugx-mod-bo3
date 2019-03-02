#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#precache( "fx", "dlc0/factory/fx_snow_player_os_factory" );
#precache( "fx", "weather/fx_rain_system_drop_impact" );

#namespace ugxm_weather;

REGISTER_SYSTEM( "ugxm_weather", &__init__, undefined )

function __init__()
{
	level._effect["snow"] = "dlc0/factory/fx_snow_player_os_factory";
	level._effect["rain"] = "weather/fx_rain_system_drop_impact";

	callback::on_spawned( &on_player_spawned );
}

function on_player_spawned()
{
	self thread weather_loop();
}

function weather_loop()
{
	self endon( "death" );
	self endon( "disconnect" );
	
	self notify( "weatherStart" );	
	self endon( "weatherStart" );

	for (;;)
	{

		if(isDefined(level.ugxm_settings["weatherType"]))
		{
			if(level.ugxm_settings["weatherType"] == "snow")
				PlayFX(level._effect["snow"], self.origin);

			if(level.ugxm_settings["weatherType"] == "rain")
				PlayFX(level._effect["rain"], self.origin);
		}
		
		wait(0.3);
	}
}
