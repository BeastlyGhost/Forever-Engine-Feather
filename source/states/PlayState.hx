package states;

import base.FeatherDependencies.Events;
import base.FeatherDependencies.ScriptHandler;
import base.ScoreUtils;
import dependency.FNFSprite;
import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.graphics.FlxGraphic;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.system.FlxSound;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import flixel.util.FlxTimer;
import gameObjects.*;
import gameObjects.Character;
import gameObjects.Strumline.Receptor;
import gameObjects.userInterface.*;
import openfl.media.Sound;
import song.ChartParser;
import song.Conductor;
import song.Song;
import song.SongFormat.SwagSong;
import song.SongFormat.TimedEvent;
import states.editors.CharacterOffsetEditor;
import states.menus.*;
import states.substates.GameOverSubstate;
#if desktop
import dependency.Discord;
#end

class PlayState extends MusicBeatState
{
	// for Static Access to this Class;
	public static var main:PlayState;

	// Scripts;
	public static var moduleArray:Array<ScriptHandler> = [];

	// Notes;
	public var unspawnNotes:Array<Note> = [];

	public static var timedEvents:Array<TimedEvent> = [];

	// Song;
	public static var SONG:SwagSong;
	public static var songMusic:FlxSound;
	public static var songLength:Float = 0;
	public static var vocals:FlxSound;

	public var generatedMusic:Bool = false;

	public static var curStage:String = '';

	// Story Mode;
	public static var isStoryMode:Bool = false;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];
	public static var storyDifficulty:Int = 2;

	// Player;
	public static var deaths:Int = 0;
	public static var campaignScore:Int = 0;
	public static var campaingMisses:Int = 0;
	public static var health:Float = 1; // mario;

	// Characters;
	public static var opponent:Character;
	public static var gf:Character;
	public static var boyfriend:Boyfriend;

	// used by events, stores characters and character names in maps;
	public static var playerMap:Map<String, Character> = new Map();
	public static var opponentMap:Map<String, Character> = new Map();
	public static var spectatorMap:Map<String, Character> = new Map();

	// Custom;
	public static var assetModifier:String = 'base';
	public static var changeableSkin:String = 'default';

	// Discord RPC;
	public static var songDetails:String = "";
	public static var detailsSub:String = "";
	public static var detailsPausedText:String = "";
	public static var iconRPC:String = "";
	public static var storyDifficultyText:String = "";

	// Events;
	public var startingSong:Bool = false;
	public var endingSong:Bool = false;
	public var startedCountdown:Bool = false;

	public static var clearStored:Bool = false;

	public var skipCountdown:Bool = false;
	public var inCutscene:Bool = false;
	public var canPause:Bool = true;
	public var paused:Bool = false;

	// Cameras;
	private var camFollow:FlxObject;
	private var camFollowPos:FlxObject;

	public static var camHUD:FlxCamera;
	public static var camGame:FlxCamera;
	public static var dialogueHUD:FlxCamera;

	private static var prevCamFollow:FlxObject;

	public var camDisplaceX:Float = 0;
	public var camDisplaceY:Float = 0; // might not use depending on result

	public static var cameraSpeed:Float = 1;
	public static var defaultCamZoom:Float = 1.05;
	public static var forceZoom:Array<Float>;

	public static var cameraBumpSpeed:Float = 4;

	// User Interface and Objects
	public static var uiHUD:ClassHUD;
	public static var daPixelZoom:Float = 6;

	public static var stageBuild:Stage;

	public static var stageGroup:FlxTypedGroup<Stage>;

	public static var ratingPlacement:FlxPoint;
	public static var comboPlacement:FlxPoint;

	// strumlines
	public static var dadStrums:Strumline;
	public static var bfStrums:Strumline;

	public static var strumLines:FlxTypedGroup<Strumline>;
	public static var strumHUD:Array<FlxCamera> = [];

	// stores all UI Cameras in an array
	private var allUIs:Array<FlxCamera> = [];

	// Other;
	public static var lastRating:FlxSprite;
	public static var lastTiming:FlxSprite;
	public static var lastCombo:Array<FlxSprite>;

	// groups, used to sort through ratings and combo;
	public var judgementsGroup:FlxTypedGroup<FNFSprite>;
	public var comboGroup:FlxTypedGroup<FNFSprite>;

	public var gfSpeed:Int = 1;

	public var legacyGf:Bool = false;

	function resetStatics()
	{
		GameOverSubstate.resetDeathVariables();
		Events.getScriptEvents();

		ScoreUtils.resetAccuracy();
		PlayState.SONG.validScore = true;
		deaths = 0;
		health = 1;

		timedEvents = [];
		moduleArray = [];
		lastCombo = [];

		clearStored = false;
		Conductor.shouldStartSong = false;
		defaultCamZoom = 1.05;
		cameraBumpSpeed = 4;
		cameraSpeed = 1;

		forceZoom = [0, 0, 0, 0];

		assetModifier = 'base';
		changeableSkin = 'default';
	}

	inline function checkTween(isDad:Bool = false):Bool
	{
		if (isDad && Init.trueSettings.get('Centered Notefield'))
			return false;
		if (skipCountdown)
			return false;
		return true;
	}

	public function generateCharacters()
	{
		opponent = new Character();
		boyfriend = new Boyfriend();
		gf = new Character();

		gf.setCharacter(0, 0, SONG.gfVersion);
		gf.scrollFactor.set(0.95, 0.95);

		opponent.setCharacter(0, 0, SONG.player2);
		boyfriend.setCharacter(0, 0, SONG.player1);

		// add characters
		if (stageBuild.spawnGirlfriend)
			add(gf);

		add(stageBuild.layers);

		add(opponent);
		add(boyfriend);
		add(stageBuild.foreground);

		// force them to dance
		opponent.dance();
		gf.dance();
		boyfriend.dance();

		characterPostGeneration();
	}

	public function regenerateCharacters()
	{
		remove(gf);
		remove(opponent);
		remove(boyfriend);
		remove(stageBuild.layers);
		remove(stageBuild.foreground);

		// add characters
		if (stageBuild.spawnGirlfriend)
			add(gf);

		add(stageBuild.layers);

		add(opponent);
		add(boyfriend);

		add(stageBuild.foreground);

		// force them to dance
		opponent.dance();
		gf.dance();
		boyfriend.dance();

		characterPostGeneration();
	}

	public function characterPostGeneration()
	{
		boyfriend.setPosition(stageBuild.stageJson.bfPos[0], stageBuild.stageJson.bfPos[1]);
		opponent.setPosition(stageBuild.stageJson.dadPos[0], stageBuild.stageJson.dadPos[1]);
		gf.setPosition(stageBuild.stageJson.gfPos[0], stageBuild.stageJson.gfPos[1]);

		stageBuild.repositionPlayers(curStage, boyfriend, gf, opponent);
		stageBuild.dadPosition(curStage, boyfriend, gf, opponent, new FlxPoint(gf.getMidpoint().x - 100, boyfriend.getMidpoint().y - 100));
		defaultCamZoom = stageBuild.stageJson.defaultZoom;
	}

	// at the beginning of the playstate
	override public function create()
	{
		super.create();

		FlxG.mouse.visible = false;

		main = this;

		// reset any values and variables that are static
		resetStatics();

		// stop any existing music tracks playing
		resetMusic();
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		// create the game camera
		camGame = new FlxCamera();

		// create the hud camera (separate so the hud stays on screen)
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);
		allUIs.push(camHUD);
		FlxG.cameras.setDefaultDrawTarget(camGame, true);

		// default song
		if (SONG == null)
			SONG = Song.loadFromJson('test', 'test');

		Conductor.mapBPMChanges(SONG);
		Conductor.changeBPM(SONG.bpm);

		curStage = "";
		if (SONG.stage != null)
			curStage = SONG.stage;

		ScriptHandler.callScripts(moduleArray);

		ratingPlacement = new FlxPoint();
		comboPlacement = new FlxPoint();

		ratingPlacement.set();
		comboPlacement.set();

		stageGroup = new FlxTypedGroup<Stage>();
		add(stageGroup);

		stageBuild = new Stage(curStage);
		stageGroup.add(stageBuild);

		if (SONG.gfVersion == null || SONG.gfVersion.length < 1)
			SONG.gfVersion = stageBuild.returnGFtype(curStage);

		// set up characters
		generateCharacters();

		if (SONG.assetModifier != null && SONG.assetModifier.length > 1)
			assetModifier = SONG.assetModifier;
		changeableSkin = Init.trueSettings.get("UI Skin");

		// set song position before beginning
		Conductor.songPosition = -(Conductor.crochet * 4);

		// EVERYTHING SHOULD GO UNDER THIS, IF YOU PLAN ON SPAWNING SOMETHING LATER ADD IT TO STAGEBUILD OR FOREGROUND
		// darken everything but the arrows and ui via a flxsprite
		var darknessBG:FlxSprite = new FlxSprite(FlxG.width * -0.5, FlxG.height * -0.5).makeGraphic(FlxG.width * 2, FlxG.height * 2, FlxColor.BLACK);
		darknessBG.alpha = (100 - Init.trueSettings.get('Stage Opacity')) / 100;
		darknessBG.scrollFactor.set(0, 0);
		add(darknessBG);

		// strum setup
		strumLines = new FlxTypedGroup<Strumline>();

		// generate the song
		generateSong(SONG.song);

		var camPos:FlxPoint = new FlxPoint(gf.getMidpoint().x - 100, boyfriend.getMidpoint().y - 100);

		// set the camera position to the center of the stage
		camPos.set(gf.x + (gf.frameWidth / 2), gf.y + (gf.frameHeight / 2));

		// create the game camera
		camFollow = new FlxObject(0, 0, 1, 1);
		camFollow.setPosition(camPos.x, camPos.y);
		camFollowPos = new FlxObject(0, 0, 1, 1);
		camFollowPos.setPosition(camPos.x, camPos.y);
		// check if the camera was following someone previously
		if (prevCamFollow != null)
		{
			camFollow = prevCamFollow;
			prevCamFollow = null;
		}

		add(camFollow);
		add(camFollowPos);

		// actually set the camera up
		FlxG.camera.follow(camFollowPos, LOCKON, 1);
		FlxG.camera.zoom = defaultCamZoom;
		FlxG.camera.focusOn(camFollow.getPosition());

		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);

		// initialize ui elements
		startingSong = true;
		startedCountdown = true;
		// canPause = false;

		//
		var downscroll = Init.trueSettings.get('Downscroll');
		var centered = Init.trueSettings.get('Centered Notefield');

		var placement = (FlxG.width / 2);
		var height = (downscroll ? FlxG.height - 200 : 0);

		dadStrums = new Strumline(placement - (FlxG.width / 4), height, [opponent], downscroll, false, true, checkTween(true), false, 4);
		bfStrums = new Strumline(placement + (!centered ? (FlxG.width / 4) : 0), height, [boyfriend], downscroll, true, false, checkTween(false), true, 4);

		dadStrums.visible = !centered;

		strumLines.add(dadStrums);
		strumLines.add(bfStrums);

		// strumline camera setup
		strumHUD = [];
		for (i in 0...strumLines.length)
		{
			// generate a new strum camera
			strumHUD[i] = new FlxCamera();
			strumHUD[i].bgColor.alpha = 0;

			strumHUD[i].cameras = [camHUD];
			allUIs.push(strumHUD[i]);
			FlxG.cameras.add(strumHUD[i], false);
			// set this strumline's camera to the designated camera
			strumLines.members[i].cameras = [strumHUD[i]];
		}
		add(strumLines);

		// cache shit
		displayScore(0, false, true);
		for (note in unspawnNotes)
		{
			for (strumline in strumLines)
			{
				var splash:NoteSplash = createSplash(note.noteType, 0, strumline);
				if (splash != null)
					splash.visible = false;
			}
		}
		//

		uiHUD = new ClassHUD();
		uiHUD.alpha = 0;
		add(uiHUD);
		uiHUD.cameras = [camHUD];
		//

		if (Init.trueSettings.get('Judgement Recycling'))
		{
			judgementsGroup = new FlxTypedGroup<FNFSprite>();
			comboGroup = new FlxTypedGroup<FNFSprite>();
			add(judgementsGroup);
			add(comboGroup);
		}

		// create a hud over the hud camera for dialogue
		dialogueHUD = new FlxCamera();
		dialogueHUD.bgColor.alpha = 0;
		FlxG.cameras.add(dialogueHUD, false);

		//
		if (stageBuild.sendMessage)
		{
			if (stageBuild.messageText.length > 1)
				logTrace(stageBuild.messageText, 3, true, dialogueHUD);
		}
		Controls.keyEventTrigger.add(keyEventTrigger);

		Paths.clearUnusedMemory();

		// call the funny intro cutscene depending on the song
		songCutscene(false);

		callFunc('postCreate', []);
	}

	inline public static function copyKey(arrayToCopy:Array<FlxKey>):Array<FlxKey>
	{
		var copiedArray:Array<FlxKey> = arrayToCopy.copy();
		var i:Int = 0;
		var len:Int = copiedArray.length;

		while (i < len)
		{
			if (copiedArray[i] == NONE)
			{
				copiedArray.remove(NONE);
				--i;
			}
			i++;
			len = copiedArray.length;
		}
		return copiedArray;
	}

	var keysHeld:Array<Bool> = [];

	/*
	 * Main Input System Function
	**/
	public function inputHandler(key:Int, state:KeyState)
	{
		keysHeld[key] = (state == PRESSED);

		if (state == PRESSED)
		{
			if (generatedMusic)
			{
				var previousTime:Float = Conductor.songPosition;
				Conductor.songPosition = songMusic.time;
				// improved this a little bit, maybe its a lil
				var possibleNoteList:Array<Note> = [];
				var pressedNotes:Array<Note> = [];

				bfStrums.allNotes.forEachAlive(function(daNote:Note)
				{
					if ((daNote.noteData == key) && daNote.canBeHit && !daNote.isSustainNote && !daNote.tooLate && !daNote.wasGoodHit)
						possibleNoteList.push(daNote);
				});
				possibleNoteList.sort((a, b) -> Std.int(a.strumTime - b.strumTime));

				// if there is a list of notes that exists for that control
				if (possibleNoteList.length > 0)
				{
					var eligable = true;
					var firstNote = true;
					// loop through the possible notes
					for (coolNote in possibleNoteList)
					{
						for (noteDouble in pressedNotes)
						{
							if (Math.abs(noteDouble.strumTime - coolNote.strumTime) < 10)
								firstNote = false;
							else
								eligable = false;
						}

						if (eligable)
						{
							goodNoteHit(coolNote, bfStrums); // then hit the note
							pressedNotes.push(coolNote);
						}
						// end of this little check
					}
					//
				}
				else // else just call bad notes
					if (!Init.trueSettings.get('Ghost Tapping'))
					{
						if (!inCutscene && !endingSong)
							missNoteCheck(true, key, bfStrums, Init.trueSettings.get("Display Miss Judgement"));
					}
				Conductor.songPosition = previousTime;
			}

			if (bfStrums.receptors.members[key] != null && bfStrums.receptors.members[key].animation.curAnim.name != 'confirm')
				bfStrums.receptors.members[key].playAnim('pressed');
		}
		else
		{
			// receptor reset
			if (key >= 0 && bfStrums.receptors.members[key] != null)
				bfStrums.receptors.members[key].playAnim('static');
		}
	}

	public function keyEventTrigger(action:String, key:Int, state:KeyState)
	{
		if (paused || inCutscene || bfStrums.autoplay)
			return;

		switch (action)
		{
			// RESET = Quick Game Over Screen
			case "reset":
				if (!startingSong && !isStoryMode)
					health = 0;
			case "left" | "down" | "up" | "right":
				var actions = ["left", "down", "up", "right"];
				var index = actions.indexOf(action);
				inputHandler(index, state);
		}
		callFunc(state == PRESSED ? 'onKeyPress' : 'onKeyRelease', [action]);
	}

	override public function destroy()
	{
		Controls.keyEventTrigger.remove(keyEventTrigger);
		super.destroy();
	}

	@:isVar public static var songSpeed(get, default):Float = 0;

	inline static function get_songSpeed()
		return FlxMath.roundDecimal(songSpeed, 2);

	inline static function set_songSpeed(value:Float):Float
	{
		var offset:Float = songSpeed / value;
		for (note in bfStrums.allNotes)
		{
			if (note.isSustainNote && !note.animation.curAnim.name.endsWith('end'))
			{
				note.scale.y *= offset;
				note.updateHitbox();
			}
		}
		for (note in dadStrums.allNotes)
		{
			if (note.isSustainNote && !note.animation.curAnim.name.endsWith('end'))
			{
				note.scale.y *= offset;
				note.updateHitbox();
			}
		}

		return cast songSpeed = value;
	}

	public function updateSectionCamera(value:String, isPlayer:Bool = false)
	{
		var char = opponent;

		if (value == "center")
			return;

		switch (value)
		{
			case 'bf':
				char = boyfriend;
			case 'dad':
				char = opponent;
			case 'gf':
				char = gf;
		}

		var getCenterX = isPlayer ? char.getMidpoint().x - 100 : char.getMidpoint().x + 100;
		var getCenterY = char.getMidpoint().y - 100;

		if (isPlayer)
		{
			switch (curStage)
			{
				case 'limo':
					getCenterX = char.getMidpoint().x - 300;
				case 'mall':
					getCenterY = char.getMidpoint().y - 200;
				case 'school':
					getCenterX = char.getMidpoint().x - 200;
					getCenterY = char.getMidpoint().y - 200;
				case 'schoolEvil':
					getCenterX = char.getMidpoint().x - 200;
					getCenterY = char.getMidpoint().y - 200;
			}
		}

		camFollow.setPosition(getCenterX
			+ camDisplaceX
			+ char.characterData.camOffsets[0], getCenterY
			+ camDisplaceY
			+ char.characterData.camOffsets[1]);

		if (char.curCharacter == 'mom')
			vocals.volume = 1;
	}

	override public function update(elapsed:Float)
	{
		callFunc('update', [elapsed]);

		stageBuild.stageUpdateConstant(elapsed, boyfriend, gf, opponent);

		super.update(elapsed);

		if (health > 2)
			health = 2;

		// dialogue checks
		if (dialogueBox != null && dialogueBox.alive)
		{
			// wheee the shift closes the dialogue
			if (Controls.getPressEvent("skip"))
				dialogueBox.closeDialog();

			// the change I made was just so that it would only take accept inputs
			if (Controls.getPressEvent("accept") && dialogueBox.textStarted)
			{
				FlxG.sound.play(openfl.media.Sound.fromFile(dialogueBox.acceptPath + dialogueBox.portraitData.acceptSound + "." + Paths.SOUND_EXT));
				dialogueBox.curPage += 1;
				if (dialogueBox.curPage == dialogueBox.dialogueData.dialogue.length)
					dialogueBox.closeDialog()
				else
					dialogueBox.updateDialog();
			}
		}

		if (!inCutscene)
		{
			if (startedCountdown)
			{
				// pause the game if the game is allowed to pause and enter is pressed
				if (Controls.getPressEvent("pause") && canPause)
					pauseGame();

				if (!isStoryMode)
				{
					if (Controls.getPressEvent("autoplay"))
					{
						PlayState.SONG.validScore = false;
						bfStrums.autoplay = !bfStrums.autoplay;
						uiHUD.autoplayMark.visible = bfStrums.autoplay;
						uiHUD.scoreBar.visible = !bfStrums.autoplay;
					}

					if (FlxG.keys.justPressed.SEVEN)
					{
						resetMusic();
						if (FlxG.keys.pressed.SHIFT)
							Main.switchState(this, new states.editors.ChartingState());
						else
							Main.switchState(this, new states.editors.OriginalChartingState());
						PlayState.SONG.validScore = false;
					}

					if (FlxG.keys.justPressed.EIGHT)
					{
						resetMusic();
						Main.switchState(this, new states.editors.CharacterOffsetEditor());
					}
				}
			}

			if (generatedMusic && PlayState.SONG.notes[curSection] != null)
			{
				var lastMustHit:Bool = PlayState.SONG.notes[Std.int(lastSection)].mustHitSection;
				if (PlayState.SONG.notes[curSection].mustHitSection != lastMustHit)
				{
					camDisplaceX = 0;
					camDisplaceY = 0;
				}

				var cameraPos = Init.trueSettings.get('Camera Position');
				if (cameraPos != 'none')
				{
					// lock camera according to your options;
					updateSectionCamera(cameraPos, cameraPos == 'bf');
				}
				else
				{
					if (!PlayState.SONG.notes[curSection].mustHitSection)
						updateSectionCamera('dad');
					else
						updateSectionCamera('bf', true);
				}
			}

			Conductor.songPosition += elapsed * 1000;

			if (Conductor.songPosition >= 0)
				Conductor.shouldStartSong = true;

			if (startingSong && startedCountdown && Conductor.shouldStartSong)
				startSong();

			if (!startingSong)
			{
				if (Conductor.songPosition >= Conductor.lastPosition)
					Conductor.lastPosition = Conductor.songPosition;
			}

			var lerpVal = (elapsed * 2.4) * cameraSpeed;
			camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));

			var easeLerp = 1 - Main.framerateAdjust(0.05);
			// camera stuffs
			FlxG.camera.zoom = FlxMath.lerp(defaultCamZoom + forceZoom[0], FlxG.camera.zoom, easeLerp);
			for (hud in allUIs)
				hud.zoom = FlxMath.lerp(1 + forceZoom[1], hud.zoom, easeLerp);

			// not even forcezoom anymore but still
			FlxG.camera.angle = FlxMath.lerp(0 + forceZoom[2], FlxG.camera.angle, easeLerp);
			for (hud in allUIs)
				hud.angle = FlxMath.lerp(0 + forceZoom[3], hud.angle, easeLerp);

			deathCheck();

			// spawn in the notes from the array
			if ((unspawnNotes[0] != null) && ((unspawnNotes[0].strumTime - Conductor.songPosition) < 3500))
			{
				var dunceNote:Note = unspawnNotes[0];
				var strumline:Strumline = (dunceNote.mustPress ? bfStrums : dadStrums);

				callFunc('noteSpawn', [dunceNote, dunceNote.noteData, dunceNote.noteType, dunceNote.isSustainNote]);

				// push note to its correct strumline
				strumLines.members[
					Math.floor((dunceNote.noteData + (dunceNote.mustPress ? 4 : 0)) / strumline.keyAmount)
				].addNote(dunceNote);
				unspawnNotes.splice(unspawnNotes.indexOf(dunceNote), 1);
			}

			noteCalls();
			parseEventColumn();

			callFunc('postUpdate', [elapsed]);
		}
	}

	var isDead:Bool = false;

	inline function deathCheck():Bool
	{
		if (health <= 0 && startedCountdown && !isDead)
		{
			paused = true;
			persistentUpdate = false;
			persistentDraw = false;

			resetMusic();

			deaths += 1;

			openSubState(new GameOverSubstate(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));

			FlxG.sound.play(Paths.sound('$assetModifier/' + GameOverSubstate.deathNoise));

			#if DISCORD_RPC
			Discord.changePresence("GAME OVER - " + songDetails, detailsSub, iconRPC);
			#end
			isDead = true;
			return true;
		}
		return false;
	}

	function noteCalls()
	{
		// reset strums
		for (strumline in strumLines)
		{
			for (receptor in strumline.receptors)
			{
				if (strumline.autoplay && receptor.animation.curAnim.name == 'confirm' && receptor.animation.curAnim.finished)
					receptor.playAnim('static', true);
			}
		}

		// if the song is generated
		if (generatedMusic && startedCountdown)
		{
			for (strumline in strumLines)
			{
				// set the notes x and y
				var downscrollMultiplier:Int = (strumline.downscroll ? -1 : 1) * FlxMath.signOf(songSpeed);

				strumline.allNotes.forEachAlive(function(daNote:Note)
				{
					if (daNote != null)
					{
						var roundedSpeed = FlxMath.roundDecimal(daNote.noteSpeed, 2);
						var receptorPosX:Float = strumline.receptors.members[Math.floor(daNote.noteData)].x;
						var receptorPosY:Float = strumline.receptors.members[Math.floor(daNote.noteData)].y /* + Note.swagWidth / 6 */;
						//
						var psuedoY:Float = (downscrollMultiplier * -((Conductor.songPosition - daNote.strumTime) * (0.45 * roundedSpeed)));
						var psuedoX = 25 + daNote.noteVisualOffset;

						daNote.y = receptorPosY
							+ daNote.offsetY
							+ (Math.cos(flixel.math.FlxAngle.asRadians(daNote.noteDirection)) * psuedoY)
							+ (Math.sin(flixel.math.FlxAngle.asRadians(daNote.noteDirection)) * psuedoX);
						// painful math equation
						daNote.x = receptorPosX
							+ (Math.cos(flixel.math.FlxAngle.asRadians(daNote.noteDirection)) * psuedoX)
							+ (Math.sin(flixel.math.FlxAngle.asRadians(daNote.noteDirection)) * psuedoY);

						// also set note rotation
						daNote.angle = -daNote.noteDirection;

						// shitty note hack I hate it so much
						var center:Float = receptorPosY + Note.swagWidth / 2;
						if (daNote.isSustainNote)
						{
							var stringSect = Receptor.colors[daNote.noteData];

							daNote.y -= ((daNote.height / 2) * downscrollMultiplier);
							if ((daNote.animation.getByName(stringSect + 'holdend') != null
								&& daNote.animation.curAnim.name.endsWith('holdend'))
								&& (daNote.prevNote != null))
							{
								daNote.y -= ((daNote.prevNote.height / 2) * downscrollMultiplier);
								if (strumline.downscroll)
								{
									daNote.y += (daNote.height * 2);
									if (daNote.endHoldOffset == Math.NEGATIVE_INFINITY)
									{
										// set the end hold offset yeah I hate that I fix this like this
										daNote.endHoldOffset = (daNote.prevNote.y - (daNote.y + daNote.height));
									}
									else
										daNote.y += daNote.endHoldOffset;
								}
								else // this system is funny like that
									daNote.y += ((daNote.height / 2) * downscrollMultiplier);
							}

							if (downscrollMultiplier < 0)
							{
								daNote.flipY = true;
								if ((daNote.parentNote != null && daNote.parentNote.wasGoodHit)
									&& daNote.y - daNote.offset.y * daNote.scale.y + daNote.height >= center
									&& (strumline.autoplay || (daNote.wasGoodHit || (daNote.prevNote.wasGoodHit && !daNote.canBeHit))))
								{
									var swagRect = new FlxRect(0, 0, daNote.frameWidth, daNote.frameHeight);
									swagRect.height = (center - daNote.y) / daNote.scale.y;
									swagRect.y = daNote.frameHeight - swagRect.height;
									daNote.clipRect = swagRect;
								}
							}
							else if (downscrollMultiplier > 0)
							{
								if ((daNote.parentNote != null && daNote.parentNote.wasGoodHit)
									&& daNote.y + daNote.offset.y * daNote.scale.y <= center
									&& (strumline.autoplay || (daNote.wasGoodHit || (daNote.prevNote.wasGoodHit && !daNote.canBeHit))))
								{
									var swagRect = new FlxRect(0, 0, daNote.width / daNote.scale.x, daNote.height / daNote.scale.y);
									swagRect.y = (center - daNote.y) / daNote.scale.y;
									swagRect.height -= swagRect.y;
									daNote.clipRect = swagRect;
								}
							}
						}
						// hell breaks loose here, we're using nested scripts!
						mainControls(daNote, strumline);

						// check where the note is and make sure it is either active or inactive
						if (daNote.y > FlxG.height)
						{
							daNote.active = false;
							daNote.visible = false;
						}
						else
						{
							daNote.visible = true;
							daNote.active = true;
						}

						if (!daNote.tooLate && daNote.strumTime < Conductor.songPosition - (ScoreUtils.msThreshold) && !daNote.wasGoodHit)
						{
							if ((!daNote.tooLate) && (daNote.mustPress))
							{
								if (!daNote.isSustainNote)
								{
									daNote.tooLate = true;
									for (note in daNote.childrenNotes)
										note.tooLate = true;
									daNote.noteMiss();

									// when the note is declared "late", stop this function if it's a mine;
									if (daNote.ignoreNote || daNote.isMine)
										return;

									vocals.volume = 0;
									missNoteCheck((Init.trueSettings.get('Ghost Tapping')) ? true : false, daNote.noteData, strumline,
										Init.trueSettings.get("Display Miss Judgement"));
								}
								else if (daNote.isSustainNote)
								{
									if (daNote.parentNote != null)
									{
										var parentNote = daNote.parentNote;
										if (!parentNote.tooLate)
										{
											var breakFromLate:Bool = false;
											for (note in parentNote.childrenNotes)
											{
												if (note.tooLate && !note.wasGoodHit)
													breakFromLate = true;
											}
											if (!breakFromLate)
											{
												missNoteCheck((Init.trueSettings.get('Ghost Tapping')) ? true : false, daNote.noteData, strumline,
													Init.trueSettings.get("Display Miss Judgement"));
												for (note in parentNote.childrenNotes)
													note.tooLate = true;
											}
											//
										}
									}
								}
							}
						}

						// if the note is off screen (above)
						if ((((!strumline.downscroll) && (daNote.y < -daNote.height))
							|| ((strumline.downscroll) && (daNote.y > (FlxG.height + daNote.height))))
							&& (daNote.tooLate || daNote.wasGoodHit))
							strumline.removeNote(daNote);
					}
				});

				// unoptimised asf camera control based on strums
				strumCameraRoll(strumline.receptors, (strumline == bfStrums));
			}
		}

		// reset bf's animation
		for (boyfriend in bfStrums.characters)
		{
			if ((boyfriend != null && boyfriend.animation != null)
				&& (boyfriend.holdTimer > Conductor.stepCrochet * (4 / 1000) && (!keysHeld.contains(true) || bfStrums.autoplay)))
			{
				if (boyfriend.animation.curAnim.name.startsWith('sing') && !boyfriend.animation.curAnim.name.endsWith('miss'))
					boyfriend.dance();
			}
		}
	}

	function goodNoteHit(coolNote:Note, strumline:Strumline)
	{
		if (!coolNote.wasGoodHit)
		{
			coolNote.wasGoodHit = true;
			vocals.volume = 1;

			callFunc(coolNote.mustPress ? 'goodNoteHit' : 'opponentNoteHit', [coolNote, strumline]);

			var receptors = strumline.receptors.members[coolNote.noteData];
			if (receptors != null)
				receptors.playAnim('confirm', true);

			coolNote.noteHit();

			for (character in strumline.characters)
			{
				// reset color if it's not white;
				if (character.color != 0xFFFFFFFF)
					character.color = 0xFFFFFFFF;
				characterPlayAnimation(coolNote, character);
			}

			// special thanks to sam, they gave me the original system which kinda inspired my idea for this new one
			if (strumline.displayJudges)
			{
				// get the note ms timing
				var noteDiff:Float = Math.abs(coolNote.strumTime - Conductor.songPosition);
				// get the timing
				var isLate:Bool = coolNote.strumTime < Conductor.songPosition ? true : false;

				// loop through all avaliable judgements
				var foundRating:Int = 4;
				var lowestThreshold:Float = Math.POSITIVE_INFINITY;

				for (myRating in 0...ScoreUtils.judges.length)
				{
					var myThreshold:Float = ScoreUtils.judges[myRating].timing;
					if (noteDiff <= myThreshold && (myThreshold < lowestThreshold))
					{
						foundRating = myRating;
						lowestThreshold = myThreshold;
					}
				}

				if (!coolNote.ignoreNote)
				{
					if (coolNote.isMine)
						ScoreUtils.minesHit++;
					else if (!coolNote.isSustainNote)
					{
						increaseCombo(foundRating, coolNote.noteData, strumline);
						popUpScore(foundRating, isLate, strumline, coolNote);
						if (coolNote.childrenNotes.length > 0)
							ScoreUtils.notesHit++;
						healthCall(ScoreUtils.judges[foundRating].health);
					}
					else if (coolNote.parentNote != null)
					{
						// call updated accuracy stuffs
						if (coolNote.parentNote != null)
						{
							ScoreUtils.updateInfo(100, true, coolNote.parentNote.childrenNotes.length);
							healthCall(100 / coolNote.parentNote.childrenNotes.length);
						}
					}
				}

				// create note splash if you hit a "sick" note;
				if (!coolNote.isSustainNote && coolNote.mustPress && foundRating == 0 || coolNote.noteSplash)
					createSplash(coolNote.noteType, coolNote.noteData, strumline);
			}

			if (!coolNote.isSustainNote)
				strumline.removeNote(coolNote);
		}
	}

	public function missNoteCheck(?includeAnimation:Bool = false, direction:Int = 0, strumline:Strumline, popMiss:Bool = false, lockMiss:Bool = false)
	{
		if (strumline.autoplay)
			return;

		if (includeAnimation)
		{
			var stringDirection:String = Receptor.actions[direction];

			FlxG.sound.play(Paths.soundRandom('$assetModifier/miss', 1, 3), FlxG.random.float(0.1, 0.2));

			for (character in strumline.characters)
			{
				var missString:String = '';
				if (character.hasMissAnims)
					missString = 'miss';

				character.playAnim('sing' + stringDirection.toUpperCase() + missString, lockMiss);

				// fake misses;
				var missColor = character.characterData.missColor;
				if (missString == null || missString == '')
					character.color = FlxColor.fromRGB(Std.int(missColor[0]), Std.int(missColor[1]), Std.int(missColor[2])); // *sad spongebob image* bwoomp.
			}
		}
		decreaseCombo(popMiss);
	}

	function characterPlayAnimation(coolNote:Note, character:Character)
	{
		// alright so we determine which animation needs to play
		// get alt strings and stuffs
		var stringArrow:String = '';
		var altString:String = '';

		var baseString = 'sing' + Receptor.actions[coolNote.noteData].toUpperCase();

		// I tried doing xor and it didnt work lollll
		if (coolNote.noteAlt > 0)
			altString = '-alt';
		if (((SONG.notes[curSection] != null) && (SONG.notes[curSection].altAnim)) && (character.animOffsets.exists(baseString + '-alt')))
		{
			if (altString != '-alt')
				altString = '-alt';
			else
				altString = '';
		}

		var noteSuffix:String = coolNote.noteSuffix != null && coolNote.noteSuffix != '' ? coolNote.noteSuffix : '';

		if (coolNote.noteString != null && coolNote.noteString != '')
			stringArrow = coolNote.noteString;
		else
			stringArrow = baseString + altString + noteSuffix;

		if (character != null)
		{
			if (character.animOffsets.exists(stringArrow))
				character.playAnim(stringArrow, true);
			if (coolNote.noteTimer > 0)
			{
				character.specialAnim = true;
				character.heyTimer = coolNote.noteTimer;
			}
			character.holdTimer = 0;
		}
	}

	private function mainControls(daNote:Note, strumline:Strumline):Void
	{
		var notesPressedAutoplay = [];

		// here I'll set up the autoplay functions
		if (strumline.autoplay)
		{
			// check if the note was a good hit
			if (daNote.strumTime <= Conductor.songPosition)
			{
				// kill the note, then remove it from the array
				if (strumline.displayJudges)
					notesPressedAutoplay.push(daNote);

				if (!daNote.isMine)
					goodNoteHit(daNote, strumline);
			}
		}

		if (!strumline.autoplay)
		{
			// check if anything is held
			if (keysHeld.contains(true))
			{
				// check notes that are alive
				strumline.allNotes.forEachAlive(function(coolNote:Note)
				{
					if ((coolNote.parentNote != null && coolNote.parentNote.wasGoodHit)
						&& coolNote.canBeHit
						&& coolNote.mustPress
						&& !coolNote.tooLate
						&& coolNote.isSustainNote
						&& keysHeld[coolNote.noteData])
						goodNoteHit(coolNote, strumline);
				});
			}
		}
	}

	private function strumCameraRoll(cStrum:FlxTypedSpriteGroup<Receptor>, mustHit:Bool)
	{
		if (!Init.trueSettings.get('No Camera Note Movement'))
		{
			var camDisplaceExtend:Float = 15;
			if (PlayState.SONG.notes[curSection] != null)
			{
				if ((PlayState.SONG.notes[curSection].mustHitSection && mustHit)
					|| (!PlayState.SONG.notes[curSection].mustHitSection && !mustHit))
				{
					camDisplaceX = 0;
					if (cStrum.members[0].animation.curAnim.name == 'confirm')
						camDisplaceX -= camDisplaceExtend;
					if (cStrum.members[3].animation.curAnim.name == 'confirm')
						camDisplaceX += camDisplaceExtend;

					camDisplaceY = 0;
					if (cStrum.members[1].animation.curAnim.name == 'confirm')
						camDisplaceY += camDisplaceExtend;
					if (cStrum.members[2].animation.curAnim.name == 'confirm')
						camDisplaceY -= camDisplaceExtend;
				}
			}
		}
		//
	}

	override public function onFocus():Void
	{
		if (!paused)
			updateRPC(false);
		callFunc('onFocus', []);
		super.onFocus();
	}

	override public function onFocusLost():Void
	{
		if (canPause && !paused && !inCutscene && !bfStrums.autoplay && !Init.trueSettings.get('Auto Pause'))
			pauseGame();
		callFunc('onFocusLost', []);
		super.onFocusLost();
	}

	public function pauseGame()
	{
		// pause discord rpc
		updateRPC(true);

		// pause game
		paused = true;

		// update drawing stuffs
		persistentUpdate = false;
		persistentDraw = true;

		// stop all tweens and timers
		FlxTimer.globalManager.forEach(function(tmr:FlxTimer)
		{
			if (!tmr.finished)
				tmr.active = false;
		});

		FlxTween.globalManager.forEach(function(twn:FlxTween)
		{
			if (!twn.finished)
				twn.active = false;
		});

		// open pause substate
		openSubState(new states.substates.PauseSubstate(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));
	}

	public static function updateRPC(pausedRPC:Bool)
	{
		#if DISCORD_RPC
		var displayRPC:String = (pausedRPC) ? detailsPausedText : songDetails;

		if (health > 0)
		{
			if (Conductor.songPosition > 0 && !pausedRPC)
				Discord.changePresence(displayRPC, detailsSub, iconRPC, true, songLength - Conductor.songPosition);
			else
				Discord.changePresence(displayRPC, detailsSub, iconRPC);
		}
		#end
	}

	function popUpScore(ratingID:Int, late:Bool, strumline:Strumline, coolNote:Note)
	{
		// set up the rating
		var ratingScore:Int = 50;

		var gottenRating = strumline.autoplay ? 0 : ratingID;

		if (gottenRating != 0)
		// if it isn't a sick, and you had a sick combo, then it becomes not sick :(
		if (ScoreUtils.perfectCombo)
			ScoreUtils.perfectCombo = false;

		displayScore(gottenRating, late);
		uiHUD.colorHighlight(gottenRating, ScoreUtils.perfectCombo);

		ScoreUtils.updateInfo(Std.int(ScoreUtils.judges[ratingID].accuracy));
		ratingScore = ScoreUtils.judges[ratingID].score;
		ScoreUtils.score += ratingScore;
	}

	public function createSplash(noteType:String, noteData:Int, strumline:Strumline):NoteSplash
	{
		var note = Note.noteMap.get(noteType);
		for (i in 0...strumLines.length)
			strumLines.members[i].splashNotes.cameras = [strumHUD[i]];

		if (strumline.splashNotes != null)
		{
			var noteSplash:NoteSplash = ForeverAssets.generateNoteSplashes(strumline.splashNotes, assetModifier, changeableSkin, noteType, noteData);
			noteSplash.x = strumline.receptors.members[noteData].x;
			noteSplash.y = strumline.receptors.members[noteData].y;
			noteSplash.cameras = strumline.splashNotes.members[noteData].cameras;
			noteSplash.visible = true;
			return noteSplash;
		}
		return null;
	}

	public function decreaseCombo(?popMiss:Bool = false)
	{
		// painful if statement
		if (ScoreUtils.combo > 5 && gf.animOffsets.exists('sad'))
			gf.playAnim('sad');

		if (ScoreUtils.combo > 0)
			ScoreUtils.combo = 0; // bitch lmao
		else
			ScoreUtils.combo--;

		// misses
		ScoreUtils.score -= 10;
		ScoreUtils.misses++;

		// display negative combo
		if (popMiss)
			displayScore(4, true);

		uiHUD.colorHighlight(4, false);
		healthCall(ScoreUtils.judges[4].health);

		ScoreUtils.perfectCombo = false;
		ScoreUtils.updateInfo(0);
	}

	function increaseCombo(?baseRating:Int, ?direction = 0, ?strumline:Strumline)
	{
		// trolled this can actually decrease your combo if you get a bad/shit/miss
		if (baseRating != null)
		{
			if (ScoreUtils.judges[baseRating].accuracy > 0)
			{
				if (ScoreUtils.combo < 0)
					ScoreUtils.combo = 0;
				ScoreUtils.combo += 1;
			}
			else
				missNoteCheck(true, direction, strumline, false, Init.trueSettings.get("Display Miss Judgement"));
		}
	}

	// "Miss" Judgement Color;
	private var createdColor = FlxColor.fromRGB(204, 66, 66);

	public function displayScore(id:Int, late:Bool, ?cache:Bool = false)
	{
		//
		var rating = ForeverAssets.generateRating(ScoreUtils.judges[id].name, judgementsGroup, id, late, assetModifier, changeableSkin, 'UI');
		rating.setPosition(rating.x + ratingPlacement.x, rating.y + ratingPlacement.y);

		var timing:FNFSprite = null;

		if (Init.trueSettings.get("Display Timings"))
		{
			timing = ForeverAssets.generateTimings(ScoreUtils.judges[id].name, late, rating, judgementsGroup, assetModifier, changeableSkin, 'UI');
			timing.setPosition(rating.x + ratingPlacement.x, rating.y + ratingPlacement.y + 50);
		}

		if (!Init.trueSettings.get('Judgement Recycling'))
		{
			insert(members.indexOf(strumLines), rating);
			if (id != 0 && id != 4 && Init.trueSettings.get("Display Timings"))
				insert(members.indexOf(strumLines), timing);
		}

		if (Init.trueSettings.get('Fixed Judgements'))
		{
			// bound to camera
			if (!cache)
			{
				rating.cameras = [camHUD];
				if (timing != null)
					timing.cameras = [camHUD];
			}
			rating.screenCenter();
			if (timing != null)
				timing.screenCenter();
		}

		if (!cache)
		{
			var ratingName = ScoreUtils.judges[id].name;

			// return the actual rating to the array of judgements
			ScoreUtils.gottenJudgements.set(ratingName, ScoreUtils.gottenJudgements.get(ratingName) + 1);

			if (id > ScoreUtils.smallestRating)
				ScoreUtils.smallestRating = id;
		}
		else
		{
			rating.alpha = 0.00001;
			timing.alpha = 0.00001;
		}

		// COMBO
		var comboString:String = Std.string(ScoreUtils.combo);
		var negative = false;
		if ((comboString.startsWith('-')) || (ScoreUtils.combo == 0))
			negative = true;
		var stringArray:Array<String> = comboString.split("");
		// deletes all combo sprites prior to initalizing new ones
		if (lastCombo != null)
		{
			while (lastCombo.length > 0)
			{
				lastCombo[0].kill();
				lastCombo.remove(lastCombo[0]);
			}
		}

		for (scoreInt in 0...stringArray.length)
		{
			// numScore.loadGraphic(Paths.image('UI/' + pixelModifier + 'num' + stringArray[scoreInt]));
			var numScore = ForeverAssets.generateCombo('combo', comboGroup, stringArray[scoreInt], (!negative ? ScoreUtils.perfectCombo : false),
				assetModifier, changeableSkin, 'UI', negative, createdColor, scoreInt);
			numScore.setPosition(numScore.x + comboPlacement.x, numScore.y + comboPlacement.y);
			if (!Init.trueSettings.get('Judgement Recycling'))
				insert(members.indexOf(strumLines), numScore);

			if (Init.trueSettings.get('Fixed Judgements'))
			{
				numScore.cameras = [camHUD];
				numScore.y += 50;
			}
			numScore.x += 100;

			if (cache)
				numScore.alpha = 0.00001;

			if (Init.trueSettings.get("Simply Judgements"))
			{
				// centers combo
				numScore.y += 10;
				numScore.x -= 95;
				numScore.x -= ((comboString.length - 1) * 22);
				lastCombo.push(numScore);
			}
		}

		// actually sort through the groups;
		if (judgementsGroup != null)
			judgementsGroup.sort(FNFSprite.depthSorting, FlxSort.DESCENDING);
		if (comboGroup != null)
			comboGroup.sort(FNFSprite.depthSorting, FlxSort.DESCENDING);
	}

	function healthCall(?ratingMultiplier:Float = 0)
	{
		// health += 0.012;
		var healthBase:Float = 0.06;
		health += (healthBase * (ratingMultiplier / 100));
	}

	function startSong():Void
	{
		startingSong = false;

		if (!paused)
		{
			songMusic.play();
			vocals.play();

			songMusic.onComplete = finishSong;

			resyncVocals();

			#if desktop
			// Song duration in a float, useful for the time left feature
			songLength = songMusic.length;

			// Updating Discord Rich Presence (with Time Left)
			updateRPC(false);
			#end
		}

		callFunc('startSong', []);
	}

	private function generateSong(dataPath:String):Void
	{
		var songData = SONG;

		// set the song speed
		songSpeed = SONG.speed;

		Conductor.changeBPM(songData.bpm);

		// String that contains the mode defined here so it isn't necessary to call changePresence for each mode
		songDetails = CoolUtil.dashToSpace(SONG.song) + ' - ' + CoolUtil.difficultyString;

		// String for when the game is paused
		detailsPausedText = "Paused - " + songDetails;

		// set details for song stuffs
		detailsSub = "";

		// Updating Discord Rich Presence.
		updateRPC(false);

		songMusic = new FlxSound().loadEmbedded(Paths.inst(SONG.song), false, true);

		if (SONG.needsVoices)
			vocals = new FlxSound().loadEmbedded(Paths.voices(SONG.song), false, true);
		else
			vocals = new FlxSound();

		FlxG.sound.list.add(songMusic);
		FlxG.sound.list.add(vocals);

		// generate the chart
		unspawnNotes = ChartParser.parseBaseChart(SONG);
		timedEvents = ChartParser.parseEvents(SONG.events);

		for (i in timedEvents)
		{
			if (timedEvents.length > 0)
				loadedEventAction(i);
		}

		// give the game the heads up to be able to start
		generatedMusic = true;

		callFunc('generateSong', []);
	}

	function parseEventColumn()
	{
		while (timedEvents.length > 0)
		{
			var line:TimedEvent = timedEvents[0];
			if (line != null)
			{
				if (Conductor.songPosition < line.strumTime)
					break;

				eventTrigger(line.event, [line.val1, line.val2, line.val3]);
				timedEvents.shift();
			}
		}
	}

	function loadedEventAction(event:TimedEvent)
	{
		var params:Array<String> = [event.val1, event.val2, event.val3];

		if (Events.loadedEvents.get(event.event) != null)
		{
			var eventModule:ScriptHandler = Events.loadedEvents.get(event.event);
			eventModule.call('loadedEventAction', [params]);
		}
	}

	public var songSpeedTween:FlxTween;

	public function eventTrigger(event:String, params:Array<String>)
	{
		if (event == "Multiply Scroll Speed")
		{
			var mult:Float = Std.parseFloat(params[0]);
			var timer:Float = Std.parseFloat(params[1]);
			if (Math.isNaN(mult))
				mult = 1;
			if (Math.isNaN(timer))
				timer = 0;

			var speed = SONG.speed * mult;

			if (mult <= 0)
				songSpeed = speed;
			else
			{
				if (songSpeedTween != null)
					songSpeedTween.cancel();
				songSpeedTween = FlxTween.tween(this, {songSpeed: speed}, timer, {
					ease: ForeverTools.returnTweenEase(params[2]),
					onComplete: function(twn:FlxTween)
					{
						songSpeedTween = null;
					}
				});
			}
		}
		if (Events.loadedEvents.get(event) != null)
		{
			var eventModule:ScriptHandler = Events.loadedEvents.get(event);
			eventModule.call('eventTrigger', [params]);
		}

		callFunc('eventTrigger', [event, params]);
	}

	function resyncVocals():Void
	{
		if (!endingSong)
		{
			songMusic.pause();
			vocals.pause();
			Conductor.songPosition = songMusic.time;
			vocals.time = Conductor.songPosition;
			songMusic.play();
			vocals.play();
		}
	}

	override function stepHit()
	{
		super.stepHit();
		///*
		if (songMusic.time >= Conductor.songPosition + 20 || songMusic.time <= Conductor.songPosition - 20)
			resyncVocals();
		//*/

		for (strumline in strumLines)
		{
			strumline.allNotes.forEachAlive(function(coolNote:Note)
			{
				coolNote.stepHit(curStep);
			});
		}

		callFunc('stepHit', [curStep]);
	}

	private function charactersDance(curBeat:Int)
	{
		for (i in strumLines)
		{
			for (targetChar in i.characters)
			{
				if (targetChar != null)
				{
					if ((!targetChar.danceIdle && curBeat % targetChar.characterData.headBopSpeed == 0)
						|| (targetChar.danceIdle && curBeat % Math.round(gfSpeed * targetChar.characterData.headBopSpeed) == 0))
					{
						if (targetChar.animation.curAnim.name.startsWith("idle") // check if the idle exists before dancing
							|| targetChar.animation.curAnim.name.startsWith("dance"))
							targetChar.dance();
					}
				}
			}
		}

		if (gf != null && curBeat % Math.round(gfSpeed * gf.characterData.headBopSpeed) == 0)
		{
			if (gf.animation.curAnim.name.startsWith("idle") || gf.animation.curAnim.name.startsWith("dance"))
				gf.dance();
		}
	}

	override function beatHit()
	{
		super.beatHit();

		if ((FlxG.camera.zoom < 1.35 && curBeat % cameraBumpSpeed == 0) && (!Init.trueSettings.get('Reduced Movements')))
		{
			FlxG.camera.zoom += 0.015;
			camHUD.zoom += 0.05;
			for (hud in strumHUD)
				hud.zoom += 0.05;
		}

		if (SONG.notes[curSection] != null)
		{
			if (SONG.notes[curSection].changeBPM)
				Conductor.changeBPM(SONG.notes[curSection].bpm);
		}

		uiHUD.beatHit(curBeat);

		//
		charactersDance(curBeat);

		// stage stuffs
		stageBuild.stageUpdate(curBeat, boyfriend, gf, opponent);

		for (strumline in strumLines)
		{
			strumline.allNotes.forEachAlive(function(coolNote:Note)
			{
				coolNote.beatHit(curBeat);
			});
		}

		callFunc('beatHit', [curBeat]);
	}

	override function sectionHit()
	{
		super.sectionHit();

		if (generatedMusic && PlayState.SONG.notes[Std.int(curSection)] != null)
		{
			var lastMustHit:Bool = PlayState.SONG.notes[Std.int(lastSection)].mustHitSection;
			if (PlayState.SONG.notes[Std.int(curSection)].mustHitSection != lastMustHit)
			{
				camDisplaceX = 0;
				camDisplaceY = 0;
			}
		}

		callFunc('sectionHit', [curSection]);
	}

	/* ====== substate stuffs ====== */
	public static function resetMusic()
	{
		// simply stated, resets the playstate's music for other states and substates
		if (songMusic != null)
			songMusic.stop();

		if (vocals != null)
			vocals.stop();
	}

	override function openSubState(SubState:FlxSubState)
	{
		if (paused)
		{
			if (songMusic != null)
			{
				songMusic.pause();
				vocals.pause();
			}
		}

		super.openSubState(SubState);
	}

	override function closeSubState()
	{
		if (paused)
		{
			if (songMusic != null && !startingSong)
				resyncVocals();

			// resume all tweens and timers
			FlxTimer.globalManager.forEach(function(tmr:FlxTimer)
			{
				if (!tmr.finished)
					tmr.active = true;
			});

			FlxTween.globalManager.forEach(function(twn:FlxTween)
			{
				if (!twn.finished)
					twn.active = true;
			});

			paused = false;

			///*
			updateRPC(false);
			// */
		}

		Paths.clearUnusedMemory();

		super.closeSubState();
	}

	/*
		Extra functions and stuffs
	 */
	/// song end function at the end of the playstate lmao ironic I guess
	private var endSongEvent:Bool = false;

	function finishSong():Void
	{
		var onFinish:Void->Void = endSong;

		songMusic.volume = 0;
		vocals.volume = 0;
		vocals.pause();

		onFinish();
	}

	function endSong():Void
	{
		callFunc('endSong', []);

		canPause = false;
		endingSong = true;

		if (SONG.validScore)
			ScoreUtils.saveScore(SONG.song, ScoreUtils.score, storyDifficulty);

		deaths = 0;

		if (!isStoryMode)
		{
			// enable memory cleaning;
			clearStored = true;
			Main.switchState(this, new FreeplayMenu());
		}
		else
		{
			// set the campaign's score higher
			campaignScore += ScoreUtils.score;

			// remove a song from the story playlist
			storyPlaylist.remove(storyPlaylist[0]);

			// check if there aren't any songs left
			if ((storyPlaylist.length <= 0) && (!endSongEvent))
			{
				// play menu music
				ForeverTools.resetMenuMusic();

				// enable memory cleaning;
				clearStored = true;

				// set up transitions
				transIn = FlxTransitionableState.defaultTransIn;
				transOut = FlxTransitionableState.defaultTransOut;

				// change to the menu state
				Main.switchState(this, new StoryMenu());

				// save the week's score if the score is valid
				if (SONG.validScore)
					ScoreUtils.saveWeekScore(storyWeek, campaignScore, storyDifficulty);

				// flush the save
				FlxG.save.flush();
			}
			else
				songCutscene(true);
		}
		//
	}

	public function callDefaultSongEnd()
	{
		if (isStoryMode)
		{
			var difficulty:String = '-' + CoolUtil.difficultyFromNumber(storyDifficulty).toLowerCase();
			difficulty = difficulty.replace('-normal', '');

			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;

			PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0].toLowerCase() + difficulty, PlayState.storyPlaylist[0]);
			ForeverTools.killMusic([songMusic, vocals]);

			// deliberately did not use the main.switchstate as to not unload the assets
			FlxG.switchState(new PlayState());
		}
		else
		{
			// enable memory cleaning;
			clearStored = true;
			Main.switchState(this, new FreeplayMenu());
		}
	}

	var dialogueBox:DialogueBox;

	public function songCutscene(onEnd:Bool = false)
	{
		if (skipCutscenes())
			return onEnd ? endSong() : startCountdown();

		inCutscene = true;
		canPause = false;

		var cutscenePath = Paths.module('cutscene' + (onEnd ? '-end' : ''), 'songs/' + SONG.song.toLowerCase());
		callFunc(onEnd ? 'songEndCutscene' : 'songCutscene', []);

		// lol dumb check;
		if (!sys.FileSystem.exists(cutscenePath))
			callTextbox();
		//
	}

	inline function checkTextbox():Bool
	{
		var dialogueFileStr:String = 'dialogue';
		dialogueFileStr = (endingSong ? 'dialogueEnd' : 'dialogue');
		var dialogPath = Paths.file('songs/' + SONG.song.toLowerCase() + '/$dialogueFileStr.json');

		if (sys.FileSystem.exists(dialogPath))
			return true;

		return false;
	}

	public function callTextbox()
	{
		if (checkTextbox())
		{
			if (!endingSong)
				startedCountdown = false;

			var dialogueFileStr:String = 'dialogue';
			dialogueFileStr = (endingSong ? 'dialogueEnd' : 'dialogue');

			var dialogPath = Paths.file('songs/' + SONG.song.toLowerCase() + '/$dialogueFileStr.json');

			dialogueBox = DialogueBox.createDialogue(sys.io.File.getContent(dialogPath));
			dialogueBox.cameras = [dialogueHUD];
			add(dialogueBox);

			if (dialogueBox != null)
				dialogueBox.fadeInMusic();

			dialogueBox.whenDaFinish = endingSong ? endSong : startCountdown;
		}
		else
			(endingSong ? callDefaultSongEnd() : startCountdown());
	}

	inline public static function skipCutscenes():Bool
	{
		// pretty messy but an if statement is messier
		if (Init.trueSettings.get('Skip Text') != null && Std.isOfType(Init.trueSettings.get('Skip Text'), String))
		{
			switch (cast(Init.trueSettings.get('Skip Text'), String))
			{
				case 'never':
					return false;
				case 'freeplay only':
					if (!isStoryMode)
						return true;
					else
						return false;
				default:
					return true;
			}
		}
		return false;
	}

	var countdownPos:Int;
	var songPosCount:Int;

	public function startCountdown():Void
	{
		inCutscene = false;
		canPause = true;

		Conductor.songPosition = -(Conductor.crochet * 5);

		countdownPos = 0;

		// in case you want the song to start later, increase this number;
		songPosCount = 4;

		callFunc('startCountdown', []);

		camHUD.visible = true;

		var targetUIAlpha:Float = 1;
		if (!Init.trueSettings.get('Opaque UI'))
			targetUIAlpha = 0.8;

		FlxTween.tween(uiHUD, {alpha: targetUIAlpha}, (Conductor.crochet * 2) / 1000, {startDelay: (Conductor.crochet / 1000)});

		startedCountdown = true;

		var introGraphicNames:Array<String> = ['prepare', 'ready', 'set', 'go'];
		var introSoundNames:Array<String> = ['intro3', 'intro2', 'intro1', 'introGo'];

		var introGraphics:Array<FlxGraphic> = [];
		var introSounds:Array<Sound> = [];

		for (graphic in introGraphicNames)
			introGraphics.push(Paths.image(ForeverTools.returnSkinAsset('$graphic', assetModifier, changeableSkin, 'UI')));

		for (sound in introSoundNames)
			introSounds.push(Paths.sound('$assetModifier/$sound'));

		new FlxTimer().start(Conductor.crochet / 1000, function(tmr:FlxTimer)
		{
			if (!skipCountdown)
			{
				if (introGraphics[countdownPos] != null)
				{
					var count:FlxSprite = new FlxSprite().loadGraphic(introGraphics[countdownPos]);
					count.scrollFactor.set();
					count.updateHitbox();

					if (assetModifier == 'pixel')
						count.setGraphicSize(Std.int(count.width * PlayState.daPixelZoom));

					count.screenCenter();
					add(count);
					FlxTween.tween(count, {y: count.y += 50, alpha: 0}, Conductor.crochet / 1000, {
						ease: FlxEase.cubeInOut,
						onComplete: function(twn:FlxTween)
						{
							count.destroy();
						}
					});
					if (introSounds[countdownPos] != null)
						FlxG.sound.play(introSounds[countdownPos], 0.6);
					Conductor.songPosition = -(Conductor.crochet * songPosCount);

					// bop with countdown;
					charactersDance(curBeat);
				}

				songPosCount--;
				countdownPos++;

				callFunc('countdownTick', [countdownPos]);
			}
			else
			{
				Conductor.songPosition = -(Conductor.crochet * 1);
				Conductor.shouldStartSong = true;
			}
		}, 5);
	}

	override function add(Object:FlxBasic):FlxBasic
	{
		if (Init.trueSettings.get('Disable Antialiasing') && Std.isOfType(Object, FlxSprite))
			cast(Object, FlxSprite).antialiasing = false;
		return super.add(Object);
	}

	private function callFunc(key:String, args:Array<Dynamic>)
	{
		if (moduleArray != null)
		{
			for (i in moduleArray)
				i.call(key, args);
			if (generatedMusic)
				callLocalVariables();
		}
	}

	private function setVar(key:String, value:Dynamic)
	{
		var allSucceed:Bool = true;
		if (moduleArray != null)
		{
			for (i in moduleArray)
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

	function callLocalVariables()
	{
		// GENERAL
		setVar('add', add);
		setVar('remove', remove);
		setVar('openSubState', openSubState);

		setVar('logTrace', function(text:String, time:Float, onConsole:Bool = false)
		{
			logTrace(text, time, onConsole, dialogueHUD);
		});

		// CHARACTERS
		setVar('songName', PlayState.SONG.song.toLowerCase());

		if (boyfriend != null)
		{
			setVar('bf', boyfriend);
			setVar('boyfriend', boyfriend);
			setVar('player', boyfriend);
			setVar('bfName', boyfriend.curCharacter);
			setVar('boyfriendName', boyfriend.curCharacter);
			setVar('playerName', boyfriend.curCharacter);

			setVar('bfData', boyfriend.characterData);
			setVar('boyfriendData', boyfriend.characterData);
			setVar('playerData', boyfriend.characterData);
		}

		if (opponent != null)
		{
			setVar('dad', opponent);
			setVar('dadOpponent', opponent);
			setVar('opponent', opponent);
			setVar('dadName', opponent.curCharacter);
			setVar('dadOpponentName', opponent.curCharacter);
			setVar('opponentName', opponent.curCharacter);

			setVar('dadData', opponent.characterData);
			setVar('dadOpponentData', opponent.characterData);
			setVar('opponentData', opponent.characterData);
		}

		if (gf != null)
		{
			setVar('gf', gf);
			setVar('girlfriend', gf);
			setVar('spectator', gf);
			setVar('gfName', gf.curCharacter);
			setVar('girlfriendName', gf.curCharacter);
			setVar('spectatorName', gf.curCharacter);

			setVar('gfData', gf.characterData);
			setVar('girlfriendData', gf.characterData);
			setVar('spectatorData', gf.characterData);
		}

		if (bfStrums != null)
			setVar('bfStrums', bfStrums);
		if (dadStrums != null)
			setVar('dadStrums', dadStrums);
		if (strumLines != null)
			setVar('strumLines', strumLines);
		if (allUIs != null)
			setVar('allUIs', allUIs);
		if (camGame != null)
			setVar('camGame', camGame);
		if (camHUD != null)
			setVar('camHUD', camHUD);
		if (dialogueHUD != null)
			setVar('dialogueHUD', dialogueHUD);
		if (strumHUD != null)
			setVar('strumHUD', strumHUD);
		if (uiHUD != null)
			setVar('ui', uiHUD);

		setVar('score', ScoreUtils.score);
		setVar('combo', ScoreUtils.combo);
		setVar('hits', ScoreUtils.notesHit);
		setVar('mineHits', ScoreUtils.minesHit);
		setVar('misses', ScoreUtils.misses);
		setVar('health', health);
		setVar('deaths', deaths);

		setVar('curBeat', curBeat);
		setVar('curStep', curStep);
		setVar('curSection', curSection);
		setVar('lastBeat', lastBeat);
		setVar('lastStep', lastStep);
		setVar('lastSection', lastSection);

		setVar('set', function(key:String, value:Dynamic)
		{
			var dotList:Array<String> = key.split('.');

			if (dotList.length > 1)
			{
				var reflector:Dynamic = Reflect.getProperty(this, dotList[0]);

				for (i in 1...dotList.length - 1)
					reflector = Reflect.getProperty(reflector, dotList[i]);

				Reflect.setProperty(reflector, dotList[dotList.length - 1], value);
				return true;
			}

			Reflect.setProperty(this, key, value);
			return true;
		});

		setVar('get', function(variable:String)
		{
			var dotList:Array<String> = variable.split('.');

			if (dotList.length > 1)
			{
				var reflector:Dynamic = Reflect.getProperty(this, dotList[0]);

				for (i in 1...dotList.length - 1)
					reflector = Reflect.getProperty(reflector, dotList[i]);

				return Reflect.getProperty(reflector, dotList[dotList.length - 1]);
			}

			return Reflect.getProperty(this, variable);
		});
	}
}
