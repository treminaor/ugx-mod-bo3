function zombie_monitor()
{
	while(1)
	{
		zombies = GetAiSpeciesArray("axis");
		if(isDefined(zombies))
		{
			for ( i = 0; i < zombies.size; i++ )
			{
				if(!isDefined(zombies[i].death_event_watch))
				{
					thread zombie_death_event(zombies[i]);
				}
			}
		}
		wait 0.05;
	}
}

function zombie_death_event( zombie )
{
	zombie.death_event_watch = true;
	zombie waittill( "death" );
	
	if( isdefined( zombie.attacker ) && isplayer( zombie.attacker ) )
	{
		level notify("zombie_died", zombie, zombie.attacker);
	}
}