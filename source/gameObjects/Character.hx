package gameObjects;

/**
	The character class initialises any and all characters that exist within gameplay. For now, the character class will
	stay the same as it was in the original source of the game. I'll most likely make some changes afterwards though!
**/
import base.compatibility.PsychChar;
import base.feather.ScriptHandler;
import dependency.FNFSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import haxe.Json;
import song.Conductor;
import states.PlayState;
import sys.FileSystem;
import sys.io.File;

using StringTools;

enum abstract CharacterOrigin(String) to String
{
	var UNDERSCORE;
	var FOREVER_FEATHER; // need to come up with a format for this, maybe.
	var PSYCH_ENGINE;
	var FUNKIN_COCOA;
}

typedef CharacterData =
{
	var flipX:Bool;
	var flipY:Bool;
	var offsetX:Float;
	var offsetY:Float;
	var camOffsetX:Float;
	var camOffsetY:Float;
	var quickDancer:Bool;
	var singDuration:Float;
	var headBopSpeed:Int;
	var healthColor:Array<Float>;
	var antialiasing:Bool;
	var adjustPos:Bool;
	var noteSkin:String;
	var splashSkin:String;
	var icon:String;
}

class Character extends FNFSprite
{
	public var debugMode:Bool = false;

	public var isPlayer:Bool = false;
	public var curCharacter:String = 'bf';

	public var holdTimer:Float = 0;
	public var heyTimer:Float = 0.6;

	public var specialAnim:Bool = false;

	public var hasMissAnims:Bool = false;
	public var danceIdle:Bool = false;

	public var characterType:String = UNDERSCORE;
	public var characterData:CharacterData;

	public var characterScripts:Array<ScriptHandler> = [];

	public var idleSuffix:String = '';

	public function new(?isPlayer:Bool = false)
	{
		super(x, y);
		this.isPlayer = isPlayer;
	}

	public function setCharacter(x:Float, y:Float, character:String):Character
	{
		curCharacter = character;
		var tex:FlxAtlasFrames;

		characterData = {
			flipX: isPlayer,
			flipY: false,
			offsetY: 0,
			offsetX: 0,
			camOffsetY: 0,
			camOffsetX: 0,
			singDuration: 4,
			headBopSpeed: 2,
			healthColor: [255, 255, 255],
			antialiasing: true,
			adjustPos: !character.startsWith('gf'),
			noteSkin: "NOTE_assets",
			splashSkin: 'noteSplashes',
			icon: null,
			quickDancer: false
		};

		if (characterData.icon == null)
			characterData.icon = character;

		if (animation.getByName('danceRight') != null)
			danceIdle = true;

		if (FileSystem.exists(Paths.characterModule(character, character, PSYCH_ENGINE)))
			characterType = PSYCH_ENGINE;

		switch (curCharacter)
		{
			case 'placeholder':
				// hardcoded placeholder so it can be used on errors;
				frames = Paths.getSparrowAtlas('placeholder', 'characters/$character');

				animation.addByPrefix('idle', 'Idle', 24, false);
				animation.addByPrefix('singLEFT', 'Left', 24, false);
				animation.addByPrefix('singDOWN', 'Down', 24, false);
				animation.addByPrefix('singUP', 'Up', 24, false);
				animation.addByPrefix('singRIGHT', 'Right', 24, false);

				if (!isPlayer)
				{
					addOffset("idle", 0, -350);
					addOffset("singLEFT", 22, -353);
					addOffset("singDOWN", 17, -375);
					addOffset("singUP", 8, -334);
					addOffset("singRIGHT", 50, -348);
					characterData.camOffsetX = 30;
					characterData.camOffsetY = 330;
					characterData.offsetY = -350;
				}
				else
				{
					addOffset("idle", 0, -10);
					addOffset("singLEFT", 33, -6);
					addOffset("singDOWN", -48, -31);
					addOffset("singUP", -45, 11);
					addOffset("singRIGHT", -61, -14);
					characterData.camOffsetY = -5;
				}

				playAnim('idle');
				characterData.healthColor = [161, 161, 161];

			default:
				if (characterType == PSYCH_ENGINE)
					generatePsychChar(character);
				else
				{
					try
					{
						generateUnderscoreChar(character); // old system, for now i guess;
					}
					catch (e)
					{
						trace('$character is/was null');
						return setCharacter(x, y, 'placeholder');
					}
				}
		}

		var missAnimations:Array<String> = ['singLEFTmiss', 'singDOWNmiss', 'singUPmiss', 'singRIGHTmiss'];

		for (missAnim in missAnimations)
		{
			if (animOffsets.exists(missAnim))
				hasMissAnims = true;
		}

		recalcDance();
		dance();

		antialiasing = characterData.antialiasing;

		flipX = characterData.flipX;
		flipY = characterData.flipY;

		if (isPlayer) // fuck you ninjamuffin lmao
		{
			// Doesn't flip for BF, since his are already in the right place???
			if (!curCharacter.startsWith('bf'))
				flipLeftRight();
			//
		}
		else if (curCharacter.startsWith('bf'))
			flipLeftRight();

		if (characterData.adjustPos)
		{
			x += characterData.offsetX;
			y += (characterData.offsetY - (frameHeight * scale.y));
		}

		this.x = x;
		this.y = y;

		return this;
	}

	function flipLeftRight():Void
	{
		// get the old right sprite
		var oldRight = animation.getByName('singRIGHT').frames;

		// set the right to the left
		animation.getByName('singRIGHT').frames = animation.getByName('singLEFT').frames;

		// set the left to the old right
		animation.getByName('singLEFT').frames = oldRight;

		// insert ninjamuffin screaming I think idk I'm lazy as hell

		if (animation.getByName('singRIGHTmiss') != null)
		{
			var oldMiss = animation.getByName('singRIGHTmiss').frames;
			animation.getByName('singRIGHTmiss').frames = animation.getByName('singLEFTmiss').frames;
			animation.getByName('singLEFTmiss').frames = oldMiss;
		}
	}

	override function update(elapsed:Float)
	{
		if (!debugMode && animation.curAnim != null)
		{
			if (heyTimer > 0)
			{
				heyTimer -= elapsed;
				if (heyTimer <= 0)
				{
					if (specialAnim && animation.curAnim.name == 'hey' || animation.curAnim.name == 'cheer')
					{
						specialAnim = false;
						dance();
					}
					heyTimer = 0;
				}
			}
			else if (specialAnim && animation.curAnim.finished)
			{
				specialAnim = false;
				dance();
			}

			if (!isPlayer && !specialAnim)
			{
				if (animation.curAnim.name.startsWith('sing'))
					holdTimer += elapsed;

				if (holdTimer >= Conductor.stepCrochet * characterData.singDuration * 0.001)
				{
					dance();
					holdTimer = 0;
				}
			}

			var curCharSimplified:String = simplifyCharacter();
			switch (curCharSimplified)
			{
				case 'gf':
					if (animation.curAnim.name == 'hairFall' && animation.curAnim.finished)
						playAnim('danceRight');
					if ((animation.curAnim.name.startsWith('sad')) && (animation.curAnim.finished))
						playAnim('danceLeft');
			}

			// Post idle animation (think Week 4 and how the player and mom's hair continues to sway after their idle animations are done!)
			if (animation.curAnim.finished && animation.curAnim.name == 'idle')
			{
				// We look for an animation called 'idlePost' to switch to
				if (animation.getByName('idlePost') != null)
					// (( WE DON'T USE 'PLAYANIM' BECAUSE WE WANT TO FEED OFF OF THE IDLE OFFSETS! ))
					animation.play('idlePost', true, false, 0);
			}
		}

		super.update(elapsed);
	}

	private var danced:Bool = false;

	/**
	 * FOR GF DANCING SHIT
	 */
	public function dance(?forced:Bool = false)
	{
		if (!debugMode && animation.curAnim != null && !specialAnim)
		{
			// reset color if it's not white;
			if (color != 0xFFFFFFFF)
				color = 0xFFFFFFFF;

			specialAnim = false;

			var curCharSimplified:String = simplifyCharacter();
			switch (curCharSimplified)
			{
				case 'gf':
					if ((!animation.curAnim.name.startsWith('hair')) && (!animation.curAnim.name.startsWith('sad')))
					{
						danced = !danced;

						if (danced)
							playAnim('danceRight', forced);
						else
							playAnim('danceLeft', forced);
					}
				default:
					// Left/right dancing, think Skid & Pump

					if (animation.getByName('danceLeft') != null && animation.getByName('danceRight') != null)
					{
						danced = !danced;
						if (danced)
							playAnim('danceRight', forced);
						else
							playAnim('danceLeft', forced);
					}
					else
						playAnim('idle', forced);
			}
		}
	}

	private var settingCharacterUp:Bool = true;

	/**
	 * Recalculates Character Headbop Speed, used by GF-Like Characters;
	 * @author Shadow_Mario_
	**/
	public function recalcDance()
	{
		var lastDanceIdle:Bool = danceIdle;
		danceIdle = (animation.getByName('danceLeft' + idleSuffix) != null && animation.getByName('danceRight' + idleSuffix) != null);

		if (settingCharacterUp)
		{
			characterData.headBopSpeed = (danceIdle ? 1 : 2);
		}
		else if (lastDanceIdle != danceIdle)
		{
			var calc:Float = characterData.headBopSpeed;
			if (danceIdle)
				calc /= 2;
			else
				calc *= 2;

			characterData.headBopSpeed = Math.round(Math.max(calc, 1));
		}
		settingCharacterUp = false;
	}

	override public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		if (animation.getByName(AnimName) != null)
			super.playAnim(AnimName, Force, Reversed, Frame);

		if (curCharacter == 'gf')
		{
			if (AnimName == 'singLEFT')
				danced = true;
			else if (AnimName == 'singRIGHT')
				danced = false;

			if (AnimName == 'singUP' || AnimName == 'singDOWN')
				danced = !danced;
		}
	}

	public function simplifyCharacter():String
	{
		var base = curCharacter;

		if (base.contains('-'))
			base = base.substring(0, base.indexOf('-'));
		return base;
	}

	/**
	 * [Generates a Character in the Forever Engine Underscore Format]
	 * @param char returns the character that should be generated
	 */
	function generateUnderscoreChar(char:String = 'bf')
	{
		var pushedChars:Array<String> = [];

		var overrideFrames:String = null;
		var framesPath:String = null;

		if (!pushedChars.contains(char))
		{
			var script:ScriptHandler = new ScriptHandler(Paths.characterModule(char, 'config', UNDERSCORE));

			if (script.interp == null)
				trace("Something terrible occured! Skipping.");

			characterScripts.push(script);
			pushedChars.push(char);
		}

		var spriteType = "SparrowAtlas";

		try
		{
			var textAsset:String = Paths.characterModule(char, char + '.txt');

			// check if a text file exists with the character name exists, if so, it's a spirit-like character;
			if (FileSystem.exists(textAsset))
				spriteType = "PackerAtlas";
			else
				spriteType = "SparrowAtlas";
		}
		catch (e)
		{
			trace('Could not define Sprite Type, Uncaught Error: ' + e);
		}

		// frame overrides because having
		setVar('setFrames', function(newFrames:String, newFramesPath:String)
		{
			if (newFrames != null || newFrames != '')
				overrideFrames = newFrames;
			if (newFramesPath != null && newFramesPath != '')
				framesPath = newFramesPath;
		});

		switch (spriteType)
		{
			case "PackerAtlas":
				var sprPacker:String = (overrideFrames == null ? char : overrideFrames);
				var sprPath:String = (framesPath == null ? 'characters/$char' : framesPath);
				frames = Paths.getPackerAtlas(sprPacker, sprPath);
			default:
				var sprSparrow:String = (overrideFrames == null ? char : overrideFrames);
				var sprPath:String = (framesPath == null ? 'characters/$char' : framesPath);
				frames = Paths.getSparrowAtlas(sprSparrow, sprPath);
		}

		setVar('addByPrefix', function(name:String, prefix:String, ?frames:Int = 24, ?loop:Bool = false)
		{
			animation.addByPrefix(name, prefix, frames, loop);
		});

		setVar('addByIndices', function(name:String, prefix:String, indices:Array<Int>, ?frames:Int = 24, ?loop:Bool = false)
		{
			animation.addByIndices(name, prefix, indices, "", frames, loop);
		});

		setVar('addOffset', function(?name:String = "idle", ?x:Float = 0, ?y:Float = 0)
		{
			addOffset(name, x, y);
		});

		setVar('set', function(name:String, value:Dynamic)
		{
			Reflect.setProperty(this, name, value);
		});

		setVar('setSingDuration', function(amount:Int)
		{
			characterData.singDuration = amount;
		});

		setVar('setOffsets', function(x:Float = 0, y:Float = 0)
		{
			characterData.offsetX = x;
			characterData.offsetY = y;
		});

		setVar('setCamOffsets', function(x:Float = 0, y:Float = 0)
		{
			characterData.camOffsetX = x;
			characterData.camOffsetY = y;
		});

		setVar('setScale', function(?x:Float = 1, ?y:Float = 1)
		{
			scale.set(x, y);
		});

		setVar('setIcon', function(swag:String = 'face') characterData.icon = swag);

		setVar('quickDancer', function(quick:Bool = false)
		{
			characterData.quickDancer = quick;
		});

		setVar('setBarColor', function(rgb:Array<Float>)
		{
			if (characterData.healthColor != null)
				characterData.healthColor = rgb;
			else
				characterData.healthColor = [161, 161, 161];
			return true;
		});

		setVar('setDeathChar',
			function(char:String = 'bf-dead', lossSfx:String = 'fnf_loss_sfx', song:String = 'gameOver', confirmSound:String = 'gameOverEnd', bpm:Int)
			{
				states.substates.GameOverSubstate.bfType = char;
				states.substates.GameOverSubstate.deathNoise = lossSfx;
				states.substates.GameOverSubstate.deathTrack = song;
				states.substates.GameOverSubstate.leaveTrack = confirmSound;
				states.substates.GameOverSubstate.trackBpm = bpm;
			});

		setVar('get', function(variable:String)
		{
			return Reflect.getProperty(this, variable);
		});

		setVar('setGraphicSize', function(width:Int = 0, height:Int = 0)
		{
			setGraphicSize(width, height);
			updateHitbox();
		});

		setVar('playAnim', function(name:String, ?force:Bool = false, ?reversed:Bool = false, ?frames:Int = 0)
		{
			playAnim(name, force, reversed, frames);
		});

		setVar('isPlayer', isPlayer);
		setVar('characterData', characterData);
		if (PlayState.SONG != null)
			setVar('songName', PlayState.SONG.song.toLowerCase());
		setVar('flipLeftRight', flipLeftRight);

		if (characterScripts != null)
		{
			for (i in characterScripts)
				i.call('loadAnimations', []);
		}

		if (animation.getByName('danceLeft') != null)
			playAnim('danceLeft');
		else
			playAnim('idle');
	}

	public function setVar(key:String, value:Dynamic)
	{
		var allSucceed:Bool = true;
		if (characterScripts != null)
		{
			for (i in characterScripts)
			{
				i.set(key, value);

				if (!i.exists(key))
				{
					trace('${i.scriptFile} failed to set $key for its interpreter, continuing.');
					allSucceed = false;
					continue;
				}
			}
		}
		return allSucceed;
	}

	public var psychAnimationsArray:Array<PsychAnimArray> = [];

	/**
	 * [Generates a Character in the Psych Engine Format, as a Compatibility Layer for them]
	 * [@author Shadow_Mario_]
	 * @param char returns the character that should be generated
	 */
	function generatePsychChar(char:String = 'bf-psych')
	{
		var rawJson:String = null;
		var json:PsychEngineChar = null;

		if (FileSystem.exists(Paths.characterModule(char, char, PSYCH_ENGINE)))
			rawJson = File.getContent(Paths.characterModule(char, char, PSYCH_ENGINE));

		if (rawJson != null)
			json = cast Json.parse(rawJson);

		var spriteType:String = "SparrowAtlas";

		try
		{
			var textAsset:String = Paths.characterModule(char, json.image.replace('characters/', '') + '.txt');

			if (FileSystem.exists(textAsset))
				spriteType = "PackerAtlas";
			else
				spriteType = "SparrowAtlas";
		}
		catch (e)
		{
			trace('Could not define Sprite Type, Uncaught Error: ' + e);
		}

		switch (spriteType)
		{
			case "PackerAtlas":
				frames = Paths.getPackerAtlas(json.image.replace('characters/', ''), 'characters/$char');
			default:
				frames = Paths.getSparrowAtlas(json.image.replace('characters/', ''), 'characters/$char');
		}

		psychAnimationsArray = json.animations;
		for (anim in psychAnimationsArray)
		{
			var animAnim:String = '' + anim.anim;
			var animName:String = '' + anim.name;
			var animFps:Int = anim.fps;
			var animLoop:Bool = !!anim.loop; // Bruh
			var animIndices:Array<Int> = anim.indices;
			if (animIndices != null && animIndices.length > 0)
				animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop);
			else
				animation.addByPrefix(animAnim, animName, animFps, animLoop);

			if (anim.offsets != null && anim.offsets.length > 1)
				addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
		}
		characterData.flipX = json.flip_x;

		// characterData.icon = json.healthicon;
		characterData.antialiasing = !json.no_antialiasing;
		characterData.healthColor = json.healthbar_colors;
		characterData.singDuration = json.sing_duration;

		if (json.scale != 1)
		{
			setGraphicSize(Std.int(width * json.scale));
			updateHitbox();
		}

		if (animation.getByName('danceLeft') != null)
			playAnim('danceLeft');
		else
			playAnim('idle');

		characterData.camOffsetX = json.camera_position[0];
		characterData.camOffsetY = json.camera_position[1];

		setPosition(json.position[0], json.position[1]);

		return this;
	}
}
