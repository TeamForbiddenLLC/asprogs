namespace CGame {

void EntityEvent( const EntityState @ent, int ev, int parm, bool predicted )
{
    bool viewer = IsViewerEntity( ent.number );
    auto @cam = CGame::Camera::GetMainCamera();

	if( viewer && ( ev < PREDICTABLE_EVENTS_MAX ) && ( predicted != cam.playerPrediction ) ) {
		return;
	}

	switch( ev ) {
		case EV_NONE:
            break;

		case EV_ITEM_RESPAWN:
			cgEnts[ent.number].respawnTime = cg.time;
			//trap_S_StartRelativeSound( cgs.media.sfxItemRespawn, ent->number, CHAN_AUTO,
			//						   cg_volume_effects->value, ATTN_IDLE );
			break;

		default:
			break;
    }    
}

}