package objects;

#if (!flash && sys)
import flixel.addons.display.FlxRuntimeShader;
#end

#if sys
import openfl.display.BitmapData;
import openfl.display.PNGEncoderOptions;
import openfl.geom.ColorTransform;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
#end

class FlareonCharacter extends Character
{
	static inline final MOUTH_OFFSET_X:Float = 130;
	static inline final MOUTH_OFFSET_Y:Float = 300;
	static inline final BOUNCE_DURATION:Float = 0.12;
	static inline final BOUNCE_HEIGHT:Float = 12;
	static inline final MISS_FLASH_DURATION:Float = 0.15;
	static inline final SING_POSE_DURATION:Float = 0.18;
	static inline final HEY_POSE_DURATION:Float = 0.6;
	static inline final ACTION_POSE_DURATION:Float = 0.32;
	static inline final HIT_POSE_DURATION:Float = 0.35;

	var tail:FlxSprite;
	var body:FlxSprite;
	var head:FlxSprite;
	var mouth:FlxSprite;

	var time:Float = 0;
	var singPoseTime:Float = 0;
	var singTimer:Float = 0;
	var bounceTimer:Float = 0;
	var missFlashTimer:Float = 0;
	var currentAnim:String = 'idle';
	var mouthIsOpen:Bool = false;

	public function new(x:Float, y:Float, ?character:String = 'flareon', ?isPlayer:Bool = false)
	{
		super(x, y, character, isPlayer);

		curCharacter = character;
		healthIcon = 'flareon-pixel';
		healthColorArray = [247, 123, 62];
		singDuration = 4;
		noAntialiasing = true;
		antialiasing = false;
		hasMissAnimations = true;

		offset.set();
		origin.set(width * 0.5, height * 0.5);

		tail = makePart('tail');
		body = makePart('torso');
		head = makePart('head');
		mouth = makePart('mouth');

		for (anim in [
			'idle', 'idle-loop', 'hey',
			'singLEFT', 'singDOWN', 'singUP', 'singRIGHT',
			'singLEFT-loop', 'singDOWN-loop', 'singUP-loop', 'singRIGHT-loop',
			'singLEFTmiss', 'singDOWNmiss', 'singUPmiss', 'singRIGHTmiss',
			'pre-attack', 'attack', 'dodge', 'hurt', 'hit', 'scared'
		])
			addOffset(anim);

		playAnim('idle', true);
	}

	function makePart(image:String):FlxSprite
	{
		var spr = new FlxSprite();
		spr.loadGraphic(Paths.image(image));
		spr.antialiasing = false;
		spr.flipX = flipX;
		return spr;
	}

	override function update(elapsed:Float)
	{
		if (debugMode)
			super.update(elapsed);

		if (missFlashTimer > 0)
		{
			missFlashTimer -= elapsed;
			setPartsColor(0xFF00A0FF);
		}
		else
			setPartsColor(color);

		if (isIdleAnim(currentAnim))
			applyIdle(elapsed);
		else
		{
			singPoseTime += elapsed;
			applyPose(currentAnim);

			if (!debugMode && !isHeldPose(currentAnim))
			{
				singTimer -= elapsed;
				if (singTimer <= 0)
				{
					var loopAnim:String = currentAnim + '-loop';
					if (currentAnim.startsWith('sing') && hasAnimation(loopAnim))
						playAnim(loopAnim);
					else
					{
						currentAnim = 'idle';
						specialAnim = false;
						heyTimer = 0;
						bounceTimer = BOUNCE_DURATION;
						mouthIsOpen = false;
						mouth.alpha = 0;
						mouth.visible = false;
					}
				}
			}
		}

		if (bounceTimer > 0)
		{
			bounceTimer -= elapsed;
			var bounceProgress = bounceTimer / BOUNCE_DURATION;
			head.y -= Math.sin(bounceProgress * Math.PI) * BOUNCE_HEIGHT;
		}

		updateMouth();
		holdTimer = currentAnim.startsWith('sing') ? holdTimer + elapsed : 0;
		if (!debugMode && !isPlayer && holdTimer >= Conductor.stepCrochet * (0.0011 #if FLX_PITCH / (FlxG.sound.music != null ? FlxG.sound.music.pitch : 1) #end) * singDuration)
		{
			dance();
			holdTimer = 0;
		}

		tail.update(elapsed);
		body.update(elapsed);
		head.update(elapsed);
		mouth.update(elapsed);
	}

	function applyIdle(elapsed:Float)
	{
		time += elapsed;

		var bodyBob = Math.sin(time * 2) * 3;
		var bodyBreath = 1 + Math.sin(time * 1.2) * 0.02;
		positionPart(body, 0, bodyBob, 0, bodyBreath, bodyBreath);

		var headBob = bodyBob * 0.3 + Math.sin(time * 2.2);
		var headWiggle = Math.sin(time * 4) * 2;
		positionPart(head, 5, bodyBob + headBob, headWiggle);

		var mouthBob = headBob * 0.5 + Math.sin(time * 3) * 0.5;
		positionPart(mouth, 0, mouthBob);
		mouth.angle = head.angle + Math.sin(time * 6) * 1.5;

		var tailWag = Math.sin(time * 3 + 0.5) * 12;
		positionPart(tail, -40, bodyBob + bodyBob * 0.6, tailWag);
		setMouth(false);
	}

	function applyPose(anim:String)
	{
		mouthIsOpen = true;

		var loopWave:Float = Math.sin(singPoseTime * 12);
		var tailWave:Float = Math.sin(singPoseTime * 18);
		var attackPulse:Float = anim.endsWith('-loop') ? 0 : Math.sin(Math.min(singPoseTime / SING_POSE_DURATION, 1) * Math.PI);
		var bodyBob:Float = loopWave * 1.5;
		var headBob:Float = loopWave * 1.2 + attackPulse * 2;
		var tailFlick:Float = tailWave * 4 + attackPulse * 5;

		switch(getPoseAnim(anim))
		{
			case 'singLEFT':
				positionPart(body, -4 - attackPulse * 2, 1 + bodyBob, -0.25 - loopWave * 0.25, 1, 1);
				positionPart(head, -5 - attackPulse * 3, headBob, -0.5 - loopWave * 1.5);
				positionPart(tail, -45 - attackPulse * 2, 5 + bodyBob, -5 - tailFlick);
			case 'singDOWN':
				positionPart(body, 2, 5 + bodyBob + attackPulse * 3, loopWave * 0.2, 1.02 + attackPulse * 0.015, 0.98 - attackPulse * 0.015);
				positionPart(head, 5, headBob + attackPulse * 2, loopWave);
				positionPart(tail, -40, 20 + bodyBob + attackPulse * 2, tailFlick * 0.7);
			case 'singUP':
				positionPart(body, 2, -4 + bodyBob - attackPulse * 3, 0.2 + loopWave * 0.2, 0.99 - attackPulse * 0.01, 1.02 + attackPulse * 0.02);
				positionPart(head, 5, headBob - attackPulse * 3, 0.5 + loopWave * 1.25);
				positionPart(tail, -35, bodyBob - attackPulse, 10 + tailFlick);
			case 'singRIGHT':
				positionPart(body, 5 + attackPulse * 2, 1 + bodyBob, 0.25 + loopWave * 0.25, 1, 1);
				positionPart(head, 15 + attackPulse * 3, headBob, 0.5 + loopWave * 1.5);
				positionPart(tail, -35 + attackPulse * 2, 5 + bodyBob, 5 + tailFlick);
			case 'idle':
				positionPart(body, 0, 0, 0, 1, 1);
				mouth.alpha = 0;
				mouth.visible = false;
			case 'hey':
				var frame:Int = getProceduralFrame(HEY_POSE_DURATION, 6);
				var pop:Float = switch(frame)
				{
					case 0: 0.25;
					case 1: 0.85;
					case 2, 3: 1;
					case 4: 0.65;
					default: 0.35;
				}
				var wave:Float = Math.sin(singPoseTime * 18);
				positionPart(body, 0, -4 - pop * 5, wave * 0.35, 1 + pop * 0.015, 1 - pop * 0.01);
				positionPart(head, 0, -10 - pop * 7, wave * 2.2);
				positionPart(tail, -40, 10 - pop * 3, pop * 10 + Math.sin(singPoseTime * 24) * 5);
			case 'pre-attack':
				var p:Float = easePose(singPoseTime, ACTION_POSE_DURATION);
				var shake:Float = Math.sin(singPoseTime * 42) * p;
				positionPart(body, -12 * p, 10 * p, -6 * p + shake, 1.04, 0.96);
				positionPart(head, -14 * p, 2 * p, -8 * p + shake * 1.5);
				positionPart(tail, -58 * p - 40, 18 * p, 20 * p + Math.sin(singPoseTime * 22) * 4);
			case 'attack':
				var p:Float = easePose(singPoseTime, ACTION_POSE_DURATION);
				var strike:Float = Math.sin(p * Math.PI);
				positionPart(body, 18 * strike + 4 * p, -7 * strike, 5 * strike, 1.03 + strike * 0.03, 0.98);
				positionPart(head, 34 * strike + 8 * p, -12 * strike, 9 * strike);
				positionPart(tail, -44 - 18 * strike, 4 - 5 * strike, -16 * strike + Math.sin(singPoseTime * 26) * 3);
			case 'dodge':
				var p:Float = easePose(singPoseTime, ACTION_POSE_DURATION);
				var dip:Float = Math.sin(p * Math.PI);
				positionPart(body, -24 * dip, 18 * dip, -11 * dip, 1.02, 0.95);
				positionPart(head, -20 * dip, 12 * dip, -14 * dip);
				positionPart(tail, -48 - 12 * dip, 20 * dip, 18 * dip + Math.sin(singPoseTime * 20) * 2);
			case 'hurt', 'hit':
				var p:Float = easePose(singPoseTime, HIT_POSE_DURATION);
				var decay:Float = 1 - p;
				var shake:Float = Math.sin(singPoseTime * 75) * 5 * decay;
				positionPart(body, -8 * decay + shake, 6 * decay, -4 * decay + shake * 0.4, 1, 1);
				positionPart(head, -12 * decay + shake * 1.2, 4 * decay, -7 * decay + shake * 0.5);
				positionPart(tail, -46 + shake, 8 * decay, 12 * decay - shake);
			case 'scared':
				var shake:Float = Math.sin(singPoseTime * 70) * 3;
				var shiver:Float = Math.sin(singPoseTime * 42) * 2;
				positionPart(body, shake, 7 + shiver, shiver * 0.5, 0.98, 1.02);
				positionPart(head, 5 + shake * 1.4, -2 + shiver, shake * 1.2);
				positionPart(tail, -52 + shake, 10 + shiver, 28 + Math.sin(singPoseTime * 55) * 5);
		}

		setMouth(true);
	}

	function easePose(time:Float, duration:Float):Float
		return Math.min(time / duration, 1);

	function getProceduralFrame(duration:Float, frames:Int):Int
		return Std.int(Math.min((singPoseTime / duration) * frames, frames - 1));

	function getPoseAnim(anim:String):String
		return anim.replace('-loop', '').replace('miss', '');

	function isIdleAnim(anim:String):Bool
		return anim == 'idle' || anim == 'idle-loop' || anim == 'danceLeft' || anim == 'danceRight';

	function isHeldPose(anim:String):Bool
		return anim.endsWith('-loop') || anim == 'scared';

	function positionPart(spr:FlxSprite, offsetX:Float, offsetY:Float, angleValue:Float = 0, scaleX:Float = 1, scaleY:Float = 1)
	{
		spr.x = x + offsetX;
		spr.y = y + offsetY;
		spr.angle = angleValue;
		spr.scale.set(scale.x * scaleX, scale.y * scaleY);
		spr.flipX = flipX;
	}

	function updateMouth()
	{
		var mouthOffset = flipX ? -MOUTH_OFFSET_X : MOUTH_OFFSET_X;
		mouth.x = head.x + mouthOffset;
		mouth.y = head.y + MOUTH_OFFSET_Y;
		mouth.angle = head.angle;
		mouth.flipX = flipX;
		mouth.scale.set(head.scale.x, head.scale.y);
		mouth.antialiasing = head.antialiasing;
		mouth.alpha = head.alpha;
		mouth.visible = head.visible && mouthIsOpen;
		mouth.updateHitbox();
	}

	function setMouth(open:Bool)
	{
		mouth.setGraphicSize(12, open ? 10 : 6);
		mouth.updateHitbox();
	}

	function setPartsColor(colorValue:FlxColor)
	{
		for (spr in [tail, body, head])
			spr.color = colorValue;
	}

	#if sys
	public function makeSpritesheet(?outputFolder:String = 'example_mods/images', ?sheetName:String = 'flareon-generated', framePadding:Int = 24, columns:Int = 4):Bool
	{
		if (columns < 1)
			columns = 1;

		var frames:Array<Dynamic> = [];
		addSheetFrames(frames, 'idle', 0.8, 8);
		addSheetFrames(frames, 'hey', HEY_POSE_DURATION, 6);
		for (anim in ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'])
		{
			addSheetFrames(frames, anim, SING_POSE_DURATION, 4);
			addSheetFrames(frames, anim + '-loop', 0.35, 6);
			addSheetFrames(frames, anim + 'miss', SING_POSE_DURATION, 4);
		}
		addSheetFrames(frames, 'pre-attack', ACTION_POSE_DURATION, 6);
		addSheetFrames(frames, 'attack', ACTION_POSE_DURATION, 6);
		addSheetFrames(frames, 'dodge', ACTION_POSE_DURATION, 6);
		addSheetFrames(frames, 'hurt', HIT_POSE_DURATION, 6);
		addSheetFrames(frames, 'hit', HIT_POSE_DURATION, 6);
		addSheetFrames(frames, 'scared', 0.5, 8);

		var oldX:Float = x;
		var oldY:Float = y;
		var oldTime:Float = time;
		var oldSingPoseTime:Float = singPoseTime;
		var oldAnim:String = currentAnim;
		var oldMouthOpen:Bool = mouthIsOpen;
		var oldPartColor:FlxColor = body.color;

		x = 0;
		y = 0;

		var minX:Float = Math.POSITIVE_INFINITY;
		var minY:Float = Math.POSITIVE_INFINITY;
		var maxX:Float = Math.NEGATIVE_INFINITY;
		var maxY:Float = Math.NEGATIVE_INFINITY;

		for (frame in frames)
		{
			poseForSheetFrame(frame.anim, frame.time);
			var bounds = getSheetBounds();
			minX = Math.min(minX, bounds.x);
			minY = Math.min(minY, bounds.y);
			maxX = Math.max(maxX, bounds.right);
			maxY = Math.max(maxY, bounds.bottom);
		}

		var frameWidth:Int = Std.int(Math.ceil(maxX - minX)) + framePadding * 2;
		var frameHeight:Int = Std.int(Math.ceil(maxY - minY)) + framePadding * 2;
		var rows:Int = Std.int(Math.ceil(frames.length / columns));
		var sheet = new BitmapData(frameWidth * columns, frameHeight * rows, true, 0x00000000);
		var xml = new StringBuf();
		xml.add('<?xml version="1.0" encoding="utf-8"?>\n');
		xml.add('<TextureAtlas imagePath="${sheetName}.png">\n');

		for (i in 0...frames.length)
		{
			var frame = frames[i];
			poseForSheetFrame(frame.anim, frame.time);
			var cellX:Int = (i % columns) * frameWidth;
			var cellY:Int = Std.int(i / columns) * frameHeight;
			var drawX:Float = cellX - minX + framePadding;
			var drawY:Float = cellY - minY + framePadding;

			drawSheetPart(sheet, tail, drawX, drawY);
			drawSheetPart(sheet, body, drawX, drawY);
			drawSheetPart(sheet, head, drawX, drawY);
			if (mouthIsOpen)
				drawSheetPart(sheet, mouth, drawX, drawY);

			xml.add('\t<SubTexture name="${frame.name}" x="${cellX}" y="${cellY}" width="${frameWidth}" height="${frameHeight}" frameX="0" frameY="0" frameWidth="${frameWidth}" frameHeight="${frameHeight}"/>\n');
		}

		xml.add('</TextureAtlas>');

		if (!FileSystem.exists(outputFolder))
			FileSystem.createDirectory(outputFolder);

		File.saveBytes('$outputFolder/$sheetName.png', sheet.encode(sheet.rect, new PNGEncoderOptions()));
		File.saveContent('$outputFolder/$sheetName.xml', xml.toString());
		sheet.dispose();

		x = oldX;
		y = oldY;
		time = oldTime;
		singPoseTime = oldSingPoseTime;
		currentAnim = oldAnim;
		mouthIsOpen = oldMouthOpen;
		setPartsColor(oldPartColor);
		poseForSheetFrame(currentAnim, singPoseTime);
		return true;
	}

	function addSheetFrames(frames:Array<Dynamic>, anim:String, duration:Float, frameCount:Int)
	{
		for (i in 0...frameCount)
		{
			var suffix:String = StringTools.lpad(Std.string(i), '0', 4);
			frames.push({
				anim: anim,
				name: '${anim}${suffix}',
				time: duration * (i / Math.max(frameCount - 1, 1))
			});
		}
	}

	function poseForSheetFrame(anim:String, poseTime:Float)
	{
		currentAnim = anim;
		singPoseTime = poseTime;
		time = poseTime;
		setPartsColor(anim.endsWith('miss') ? 0xFF00A0FF : color);

		if (isIdleAnim(anim))
			applyIdle(0);
		else
			applyPose(anim);

		updateMouth();
	}

	function getSheetBounds():Rectangle
	{
		var bounds = new Rectangle(Math.POSITIVE_INFINITY, Math.POSITIVE_INFINITY, 0, 0);
		includeSheetPartBounds(bounds, tail);
		includeSheetPartBounds(bounds, body);
		includeSheetPartBounds(bounds, head);
		if (mouthIsOpen)
			includeSheetPartBounds(bounds, mouth);
		return bounds;
	}

	function includeSheetPartBounds(bounds:Rectangle, spr:FlxSprite)
	{
		var source = spr.pixels;
		if (source == null)
			return;

		var matrix = getSheetPartMatrix(spr, 0, 0);
		for (point in [{x: 0.0, y: 0.0}, {x: source.width, y: 0.0}, {x: source.width, y: source.height}, {x: 0.0, y: source.height}])
		{
			var px:Float = matrix.a * point.x + matrix.c * point.y + matrix.tx;
			var py:Float = matrix.b * point.x + matrix.d * point.y + matrix.ty;
			var right:Float = bounds.right;
			var bottom:Float = bounds.bottom;

			if (bounds.x == Math.POSITIVE_INFINITY)
			{
				bounds.x = px;
				bounds.y = py;
				bounds.width = 0;
				bounds.height = 0;
				continue;
			}

			if (px < bounds.x)
			{
				bounds.x = px;
				bounds.width = right - px;
			}
			else if (px > right)
				bounds.width = px - bounds.x;

			if (py < bounds.y)
			{
				bounds.y = py;
				bounds.height = bottom - py;
			}
			else if (py > bottom)
				bounds.height = py - bounds.y;
		}
	}

	function drawSheetPart(sheet:BitmapData, spr:FlxSprite, offsetX:Float, offsetY:Float)
	{
		var source = spr.pixels;
		if (source == null || !spr.visible || spr.alpha <= 0)
			return;

		var colorValue:Int = spr.color;
		var transform = new ColorTransform(
			((colorValue >> 16) & 0xFF) / 255,
			((colorValue >> 8) & 0xFF) / 255,
			(colorValue & 0xFF) / 255,
			spr.alpha
		);
		sheet.draw(source, getSheetPartMatrix(spr, offsetX, offsetY), transform, null, null, false);
	}

	function getSheetPartMatrix(spr:FlxSprite, offsetX:Float, offsetY:Float):Matrix
	{
		var matrix = new Matrix();
		var scaleX:Float = spr.scale.x * (spr.flipX ? -1 : 1);
		matrix.translate(-spr.origin.x, -spr.origin.y);
		matrix.scale(scaleX, spr.scale.y);
		matrix.rotate(spr.angle * Math.PI / 180);
		matrix.translate(offsetX + spr.x + spr.origin.x, offsetY + spr.y + spr.origin.y);
		return matrix;
	}
	#end

	function copyPartValues(spr:FlxSprite, partVisible:Bool = true)
	{
		spr.cameras = cameras;
		spr.scrollFactor.copyFrom(scrollFactor);
		spr.offset.copyFrom(offset);
		spr.alpha = alpha;
		spr.visible = visible && partVisible;
		spr.shader = shader;
	}

	override public function draw()
	{
		for (spr in [tail, body, head])
		{
			copyPartValues(spr);
			updateDropShadowFrameInfo(spr);
			spr.draw();
		}

		copyPartValues(mouth, mouthIsOpen);
		updateDropShadowFrameInfo(mouth);
		mouth.draw();
	}

	function updateDropShadowFrameInfo(spr:FlxSprite)
	{
		#if (!flash && sys)
		if (spr.shader == null || spr.frame == null || !Std.isOfType(spr.shader, FlxRuntimeShader))
			return;

		var runtimeShader:FlxRuntimeShader = cast spr.shader;
		runtimeShader.setFloatArray('uFrameBounds', [spr.frame.uv.x, spr.frame.uv.y, spr.frame.uv.width, spr.frame.uv.height]);
		runtimeShader.setFloat('angOffset', spr.frame.angle * (Math.PI / 180));
		#end
	}

	override public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		specialAnim = false;
		if (Force || getPoseAnim(currentAnim) != getPoseAnim(AnimName))
			singPoseTime = 0;
		currentAnim = AnimName;
		_lastPlayedAnimation = AnimName;

		if (animation.exists(AnimName))
			animation.play(AnimName, Force, Reversed, Frame);

		if (AnimName.startsWith('sing'))
		{
			singTimer = AnimName.endsWith('-loop') ? 0 : SING_POSE_DURATION;
			if (AnimName.endsWith('miss'))
				missFlashTimer = MISS_FLASH_DURATION;
		}
		else if (isIdleAnim(AnimName))
		{
			currentAnim = 'idle';
			mouthIsOpen = false;
		}
		else
		{
			singTimer = switch(AnimName)
			{
				case 'hey': HEY_POSE_DURATION;
				case 'hurt', 'hit': HIT_POSE_DURATION;
				default: ACTION_POSE_DURATION;
			}
			if (AnimName == 'scared')
				singTimer = 0;
			if (AnimName == 'hurt' || AnimName == 'hit')
				missFlashTimer = HIT_POSE_DURATION;
		}

		if (hasAnimation(AnimName))
		{
			var daOffset = animOffsets.get(AnimName);
			offset.set(daOffset[0], daOffset[1]);
		}
	}

	override public function dance()
	{
		if (!debugMode && !skipDance && !specialAnim)
			playAnim('idle');
	}

	override public function hasAnimation(anim:String):Bool
		return animOffsets.exists(anim);

	override public function isAnimationFinished():Bool
		return currentAnim != 'scared' && !currentAnim.endsWith('-loop') && singTimer <= 0;
}
