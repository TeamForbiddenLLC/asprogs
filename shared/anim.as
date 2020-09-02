namespace GS {

namespace Anim {

// The parts must be listed in draw order
enum Part {
	LOWER = 0,
	UPPER,
	HEAD,
	PMODEL_PARTS
}

// -Torso DEATH frames and Legs DEATH frames must be the same.

// ANIMATIONS

enum Anim {
	ANIM_NONE = 0,
	BOTH_DEATH1,       //Death animation
	BOTH_DEAD1,        //corpse on the ground
	BOTH_DEATH2,
	BOTH_DEAD2,
	BOTH_DEATH3,
	BOTH_DEAD3,

	LEGS_STAND_IDLE,
	LEGS_WALK_FORWARD,
	LEGS_WALK_BACK,
	LEGS_WALK_LEFT,
	LEGS_WALK_RIGHT,

	LEGS_RUN_FORWARD,
	LEGS_RUN_BACK,
	LEGS_RUN_LEFT,
	LEGS_RUN_RIGHT,

	LEGS_JUMP_LEG1,
	LEGS_JUMP_LEG2,
	LEGS_JUMP_NEUTRAL,
	LEGS_LAND,

	LEGS_CROUCH_IDLE,
	LEGS_CROUCH_WALK,

	LEGS_SWIM_FORWARD,
	LEGS_SWIM_NEUTRAL,

	LEGS_WALLJUMP,
	LEGS_WALLJUMP_LEFT,
	LEGS_WALLJUMP_RIGHT,
	LEGS_WALLJUMP_BACK,

	LEGS_DASH,
	LEGS_DASH_LEFT,
	LEGS_DASH_RIGHT,
	LEGS_DASH_BACK,

	TORSO_HOLD_BLADE,
	TORSO_HOLD_PISTOL,
	TORSO_HOLD_LIGHTWEAPON,
	TORSO_HOLD_HEAVYWEAPON,
	TORSO_HOLD_AIMWEAPON,

	TORSO_SHOOT_BLADE,
	TORSO_SHOOT_PISTOL,
	TORSO_SHOOT_LIGHTWEAPON,
	TORSO_SHOOT_HEAVYWEAPON,
	TORSO_SHOOT_AIMWEAPON,

	TORSO_WEAPON_SWITCHOUT,
	TORSO_WEAPON_SWITCHIN,

	TORSO_DROPHOLD,
	TORSO_DROP,

	TORSO_SWIM,

	TORSO_PAIN1,
	TORSO_PAIN2,
	TORSO_PAIN3,

	PMODEL_TOTAL_ANIMATIONS
}

enum Channel {
	BASE_CHANNEL,
	EVENT_CHANNEL,
	PLAYERANIM_CHANNELS
}

class MoveAnim {
	int moveflags = 0;              // moving direction
	array<int> animState(PMODEL_PARTS, 0);
}

class AnimBuffer {
	array<int> newanim(PMODEL_PARTS, 0);
}

class AnimState {
	int anim = 0;
	int frame = 0;
	int64 startTimestamp = 0;
	float lerpFrac = 0.0f;
}

class PModelAnimState {
	// animations in the mixer
	array<array<AnimState>> curAnims(PMODEL_PARTS, array<GS::Anim::AnimState>(PLAYERANIM_CHANNELS));
	array<AnimBuffer> buffer(PLAYERANIM_CHANNELS);

	// results
	array<int> frame(PMODEL_PARTS, 0);
	array<int> oldframe(PMODEL_PARTS, 0);
	array<float> lerpFrac(PMODEL_PARTS, 0.0f);

	void ClearEventAnimations() {
		for( int i = LOWER; i < PMODEL_PARTS; i++ ) {
			buffer[EVENT_CHANNEL].newanim[i] = ANIM_NONE;
			curAnims[i][EVENT_CHANNEL].anim = ANIM_NONE;
			frame[i] = 0;
			oldframe[i] = 0;
			lerpFrac[i] = 0.0f;
		}
	}

	void AddAnimation( int loweranim, int upperanim, int headanim, int channel ) {
		array<int> newanim(PMODEL_PARTS);

		newanim[LOWER] = loweranim;
		newanim[UPPER] = upperanim;
		newanim[HEAD] = headanim;

		AnimBuffer @buf = @buffer[channel];

		for( int i = LOWER; i < PMODEL_PARTS; i++ ) {
			// ignore new events if in death
			if( channel != BASE_CHANNEL && buf.newanim[i] != ANIM_NONE && ( buf.newanim[i] <= BOTH_DEAD1 ) ) {
				continue;
			}

			if( newanim[i] != ANIM_NONE && ( newanim[i] < PMODEL_TOTAL_ANIMATIONS ) ) {
				buf.newanim[i] = newanim[i];
			}
		}
	}

	/*
	* BASE_CHANEL plays continuous animations forced to loop.
	* if the same animation is received twice it will *not* restart
	* but continue looping.
	*
	* EVENT_CHANNEL overrides base channel and plays until
	* the animation is finished. Then it returns to base channel.
	* If an animation is received twice, it will be restarted.
	* If an event channel animation has a loop setting, it will
	* continue playing it until a new event chanel animation
	* is fired.
	*/
	void AnimToFrame( int64 curTime, PModelAnimSet @animSet ) {
		for( int i = LOWER; i < PMODEL_PARTS; i++ ) {
			for( int channel = BASE_CHANNEL; channel < PLAYERANIM_CHANNELS; channel++ ) {
				AnimState @thisAnim = @curAnims[i][channel];

				// see if there are new animations to be played
				if( buffer[channel].newanim[i] != ANIM_NONE ) {
					if( channel == EVENT_CHANNEL ||
						( channel == BASE_CHANNEL && buffer[channel].newanim[i] != thisAnim.anim ) ) {
						thisAnim.anim = buffer[channel].newanim[i];
						thisAnim.startTimestamp = curTime;
					}

					buffer[channel].newanim[i] = ANIM_NONE;
				}

				if( thisAnim.anim != 0 ) {
					bool forceLoop = channel == BASE_CHANNEL;

					thisAnim.lerpFrac = FrameForTime( thisAnim.frame, curTime, thisAnim.startTimestamp,
						animSet.frametime[thisAnim.anim], animSet.firstframe[thisAnim.anim], animSet.lastframe[thisAnim.anim],
						animSet.loopingframes[thisAnim.anim], forceLoop );

					// the animation was completed
					if( thisAnim.frame < 0 ) {
						thisAnim.anim = ANIM_NONE;
					}
				}
			}
		}

		// we set all animations up, but now select which ones are going to be shown
		for( int i = LOWER; i < PMODEL_PARTS; i++ ) {
			int lastframe = frame[i];
			int channel = ( curAnims[i][EVENT_CHANNEL].anim != ANIM_NONE ) ? EVENT_CHANNEL : BASE_CHANNEL;

			frame[i] = curAnims[i][channel].frame;
			lerpFrac[i] = curAnims[i][channel].lerpFrac;

			if( lastframe == 0 || oldframe[i] == 0 ) {
				oldframe[i] = frame[i];
			} else if( frame[i] != lastframe ) {
				oldframe[i] = lastframe;
			}
		}
	}
}

class PModelAnimSet {
	array<int> firstframe(PMODEL_TOTAL_ANIMATIONS);
	array<int> lastframe(PMODEL_TOTAL_ANIMATIONS);
	array<int> loopingframes(PMODEL_TOTAL_ANIMATIONS);
	array<float> frametime(PMODEL_TOTAL_ANIMATIONS);
}

// movement flags for animation control
const int ANIMMOVE_FRONT =     0x00000001;  //	Player is pressing fordward
const int ANIMMOVE_BACK  =     0x00000002;  //	Player is pressing backpedal
const int ANIMMOVE_LEFT  =     0x00000004;  //	Player is pressing sideleft
const int ANIMMOVE_RIGHT =     0x00000008;  //	Player is pressing sideright
const int ANIMMOVE_WALK  =     0x00000010;  //	Player is pressing the walk key
const int ANIMMOVE_RUN   =     0x00000020;  //	Player is running
const int ANIMMOVE_DUCK  =     0x00000040;  //	Player is crouching
const int ANIMMOVE_SWIM  =     0x00000080;  //	Player is swimming
const int ANIMMOVE_AIR   =     0x00000100;  //	Player is at air, but not jumping

const float MOVEDIREPSILON = 0.3f;
const float WALKEPSILON    = 5.0f;
const float RUNEPSILON     = 100.0f;

void SetBaseAnimUpper( MoveAnim @pmanim, int carried_weapon )
{
	//SWIMMING
	if( ( pmanim.moveflags & ANIMMOVE_SWIM ) != 0 ) {
		pmanim.animState[UPPER] = TORSO_SWIM;
        return;
    }

	switch( carried_weapon ) {
		case WEAP_NONE:
			pmanim.animState[UPPER] = TORSO_HOLD_BLADE; // fixme: a special animation should exist
			break;
		case WEAP_GUNBLADE:
			pmanim.animState[UPPER] =  TORSO_HOLD_BLADE;
			break;
		case WEAP_LASERGUN:
			pmanim.animState[UPPER] =  TORSO_HOLD_PISTOL;
			break;
		case WEAP_ROCKETLAUNCHER:
		case WEAP_GRENADELAUNCHER:
			pmanim.animState[UPPER] =  TORSO_HOLD_HEAVYWEAPON;
			break;
		case WEAP_ELECTROBOLT:
			pmanim.animState[UPPER] =  TORSO_HOLD_AIMWEAPON;
			break;
		case WEAP_RIOTGUN:
		case WEAP_PLASMAGUN:
		default:
			pmanim.animState[UPPER] =  TORSO_HOLD_LIGHTWEAPON;
			break;
	}
}

void SetBaseAnimLower( MoveAnim @pmanim ) {
	//SWIMMING
	if( ( pmanim.moveflags & ANIMMOVE_SWIM ) != 0 ) {
		if( ( pmanim.moveflags & ANIMMOVE_FRONT ) != 0 ) {
			pmanim.animState[LOWER] = LEGS_SWIM_FORWARD;
		} else {
			pmanim.animState[LOWER] = LEGS_SWIM_NEUTRAL;
		}
	}
	//CROUCH
	else if(  ( pmanim.moveflags & ANIMMOVE_DUCK ) != 0 ) {
		if( ( pmanim.moveflags & ( ANIMMOVE_WALK | ANIMMOVE_RUN ) ) != 0 ) {
			pmanim.animState[LOWER] = LEGS_CROUCH_WALK;
		} else {
			pmanim.animState[LOWER] = LEGS_CROUCH_IDLE;
		}
	}
	//FALLING
	else if( ( pmanim.moveflags & ANIMMOVE_AIR ) != 0 ) {
		pmanim.animState[LOWER] = LEGS_JUMP_NEUTRAL;
	}
	// RUN
	else if( ( pmanim.moveflags & ANIMMOVE_RUN ) != 0 ) {
		//front/backward has priority over side movements
		if( ( pmanim.moveflags & ANIMMOVE_FRONT ) != 0 ) {
			pmanim.animState[LOWER] = LEGS_RUN_FORWARD;

		} else if( ( pmanim.moveflags & ANIMMOVE_BACK ) != 0 ) {
			pmanim.animState[LOWER] = LEGS_RUN_BACK;

		} else if( ( pmanim.moveflags & ANIMMOVE_RIGHT ) != 0 ) {
			pmanim.animState[LOWER] = LEGS_RUN_RIGHT;

		} else if( ( pmanim.moveflags & ANIMMOVE_LEFT ) != 0 ) {
			pmanim.animState[LOWER] = LEGS_RUN_LEFT;

		} else {   //is moving by inertia
			pmanim.animState[LOWER] = LEGS_WALK_FORWARD;
		}
	}
	//WALK
	else if( ( pmanim.moveflags & ANIMMOVE_WALK ) != 0 ) {
		//front/backward has priority over side movements
		if( ( pmanim.moveflags & ANIMMOVE_FRONT ) != 0 ) {
			pmanim.animState[LOWER] = LEGS_WALK_FORWARD;

		} else if( ( pmanim.moveflags & ANIMMOVE_BACK ) != 0 ) {
			pmanim.animState[LOWER] = LEGS_WALK_BACK;

		} else if( ( pmanim.moveflags & ANIMMOVE_RIGHT ) != 0 ) {
			pmanim.animState[LOWER] = LEGS_WALK_RIGHT;

		} else if( ( pmanim.moveflags & ANIMMOVE_LEFT ) != 0 ) {
			pmanim.animState[LOWER] = LEGS_WALK_LEFT;

		} else {   //is moving by inertia
			pmanim.animState[LOWER] = LEGS_WALK_FORWARD;
		}
	} else {   // STAND
		pmanim.animState[LOWER] = LEGS_STAND_IDLE;
	}
}

void SetBaseAnims( MoveAnim @pmanim, int carried_weapon ) {
	for( int part = 0; part < PMODEL_PARTS; part++ ) {
		switch( part ) {
			case LOWER:
				SetBaseAnimLower( @pmanim );
				break;
			case UPPER:
				SetBaseAnimUpper( @pmanim, carried_weapon );
				break;
			case HEAD:
			default:
				pmanim.animState[part] = 0;
				break;
		}
	}
}

int EncodeAnimState(int lower, int upper, int head) {
    return ((lower&0x3F)|((upper&0x3F )<<6)|((head&0xF)<<12));
}

void DecodeAnimState(int frame, int &out lower, int &out upper, int &out head) {
    lower = frame & 0x3F;
    upper = (frame >> 6) & 0x3F;
    head = (frame >> 12) & 0xF;
}

int UpdateBaseAnims( EntityState @state, Vec3 &in velocity ) {
	MoveAnim pmanim;
	Vec3 mins, maxs;
    Vec3 playerboxCrouchMins, playerboxCrouchMaxs;

	GS::BBoxForEntityState( state, mins, maxs );
    GS::GetPlayerCrouchSize( playerboxCrouchMins, playerboxCrouchMaxs );

	// determine if player is at ground, for walking or falling
	// this is not like having groundEntity, we are more generous with
	// the tracing size here to include small steps
    Vec3 point = state.origin - Vec3(0, 0, 1.6 * STEPSIZE);
    Trace trace;

	if( !trace.doTrace( state.origin, mins, maxs, point, state.number, MASK_PLAYERSOLID ) || 
        ( trace.fraction < 1.0f && !IsWalkablePlane( trace.planeNormal ) && !trace.startSolid ) ) {
		pmanim.moveflags |= ANIMMOVE_AIR;
	}  

	// crouching : fixme? : it assumes the entity is using the player box sizes
	if( maxs == playerboxCrouchMaxs ) {
		pmanim.moveflags |= ANIMMOVE_DUCK;
	}

	// find out the water level
	int waterlevel = WaterLevel( @state, mins, maxs );
	if( waterlevel >= 2 || ( waterlevel != 0 && ( pmanim.moveflags & ANIMMOVE_AIR ) != 0 ) ) {
		pmanim.moveflags |= ANIMMOVE_SWIM;
	}

	// find out what are the base movements the model is doing
    Vec3 movedir = velocity;
    movedir.z = 0;

	float xyspeedcheck = movedir.normalize();
	if( xyspeedcheck > WALKEPSILON ) {
        float dot;
        Mat3 viewaxis;
        Vec3( 0, state.angles.y, 0 ).anglesToAxis( viewaxis );

		// if it's moving to where is looking, it's moving forward
        dot = movedir * viewaxis.y;
		if( dot > MOVEDIREPSILON ) {
			pmanim.moveflags |= ANIMMOVE_RIGHT;
		} else if( -dot > MOVEDIREPSILON ) {
			pmanim.moveflags |= ANIMMOVE_LEFT;
		}

        dot = movedir * viewaxis.x;
		if( dot > MOVEDIREPSILON ) {
			pmanim.moveflags |= ANIMMOVE_FRONT;
		} else if( -dot > MOVEDIREPSILON ) {
			pmanim.moveflags |= ANIMMOVE_BACK;
		}

		if( xyspeedcheck > RUNEPSILON ) {
			pmanim.moveflags |= ANIMMOVE_RUN;
		} else if( xyspeedcheck > WALKEPSILON ) {
			pmanim.moveflags |= ANIMMOVE_WALK;
		}
	}

	SetBaseAnims( @pmanim, state.weapon );
	return EncodeAnimState( pmanim.animState[LOWER], pmanim.animState[UPPER], pmanim.animState[HEAD] );
}

}

}
