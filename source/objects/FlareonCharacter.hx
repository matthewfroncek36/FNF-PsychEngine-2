package objects;

#if (!flash && sys)
import flixel.addons.display.FlxRuntimeShader;
#end

#if sys
import haxe.Json;
import openfl.display.BitmapData;
import openfl.display.PNGEncoderOptions;
import openfl.geom.ColorTransform;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
import sys.FileSystem;
import sys.io.File;
#end

class FlareonCharacter extends Character
{
	static inline final MOUTH_OFFSET_X:Float = 130;
	static inline final MOUTH_OFFSET_Y:Float = 300;
	static inline final FIREBALL_MOUTH_OFFSET_X:Float = 270;
	static inline final FIREBALL_MOUTH_OFFSET_Y:Float = 205;
	static inline final BOUNCE_DURATION:Float = 0.12;
	static inline final BOUNCE_HEIGHT:Float = 12;
	static inline final MISS_FLASH_DURATION:Float = 0.15;
	static inline final SING_POSE_DURATION:Float = 0.18;
	static inline final HEY_POSE_DURATION:Float = 0.6;
	static inline final ACTION_POSE_DURATION:Float = 0.32;
	static inline final HIT_POSE_DURATION:Float = 0.35;
	static inline final FIREBALL_WIDTH:Int = 96;
	static inline final FIREBALL_HEIGHT:Int = 54;
	static inline final FIREBALL_DURATION:Float = 0.28;
	static inline final FIREBALL_TRAVEL:Float = 250;

	var tail:FlxSprite;
	var backLegBack:FlxSprite;
	var backLegFront:FlxSprite;
	var body:FlxSprite;
	var frontLegBack:FlxSprite;
	var frontLegFront:FlxSprite;
	var head:FlxSprite;
	var mouth:FlxSprite;
	var fireball:FlxSprite;

	var time:Float = 0;
	var singPoseTime:Float = 0;
	var singTimer:Float = 0;
	var bounceTimer:Float = 0;
	var missFlashTimer:Float = 0;
	var fireballTimer:Float = 0;
	var fireballFade:Float = 0;
	var currentAnim:String = 'idle';
	var currentMouthShape:String = '';
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
		backLegBack = makeOptionalPart('backlegback');
		backLegFront = makeOptionalPart('backlegfront');
		body = makePart('torso');
		frontLegBack = makeOptionalPart('frontlegback');
		frontLegFront = makeOptionalPart('frontlegfront');
		head = makePart('head');
		mouth = new FlxSprite();
		mouth.makeGraphic(12, 6, 0xFF000000);
		mouth.antialiasing = false;
		mouth.visible = false;
		fireball = new FlxSprite();
		makeFireballGraphic();
		fireball.antialiasing = false;
		fireball.visible = false;

		for (anim in [
			'idle', 'idle-loop', 'hey',
			'singLEFT', 'singDOWN', 'singUP', 'singRIGHT',
			'singLEFT-loop', 'singDOWN-loop', 'singUP-loop', 'singRIGHT-loop',
			'singLEFTmiss', 'singDOWNmiss', 'singUPmiss', 'singRIGHTmiss',
			'pre-attack', 'attack', 'shoot', 'dodge', 'hurt', 'hit', 'scared'
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

	function makeOptionalPart(image:String):FlxSprite
	{
		if (Paths.fileExists('images/$image.png', IMAGE))
			return makePart(image);

		var spr = new FlxSprite();
		spr.makeGraphic(1, 1, 0x00000000);
		spr.visible = false;
		spr.active = false;
		spr.antialiasing = false;
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
		updateFireball(elapsed);
		holdTimer = currentAnim.startsWith('sing') ? holdTimer + elapsed : 0;
		if (!debugMode && !isPlayer && holdTimer >= Conductor.stepCrochet * (0.0011 #if FLX_PITCH / (FlxG.sound.music != null ? FlxG.sound.music.pitch : 1) #end) * singDuration)
		{
			dance();
			holdTimer = 0;
		}

		tail.update(elapsed);
		backLegBack.update(elapsed);
		backLegFront.update(elapsed);
		body.update(elapsed);
		frontLegBack.update(elapsed);
		frontLegFront.update(elapsed);
		head.update(elapsed);
		mouth.update(elapsed);
		fireball.update(elapsed);
	}

	function makeFireballGraphic()
	{
		fireball.makeGraphic(FIREBALL_WIDTH, FIREBALL_HEIGHT, 0x00000000, true);
		var pixels = fireball.pixels;
		var centerY:Float = FIREBALL_HEIGHT * 0.5;

		for (ix in 0...FIREBALL_WIDTH)
		{
			var taper:Float = 1 - ix / FIREBALL_WIDTH;
			var flameRadius:Float = 7 + taper * 20;
			var coreRadius:Float = 4 + taper * 12;
			var noseBoost:Float = ix > FIREBALL_WIDTH * 0.68 ? 7 : 0;

			for (iy in 0...FIREBALL_HEIGHT)
			{
				var dist:Float = Math.abs(iy - centerY);
				if (dist <= flameRadius + noseBoost)
				{
					var color:Int = 0xFFFF2A00;
					if (dist <= flameRadius - 5 && ix < FIREBALL_WIDTH * 0.82)
						color = 0xFFFF7A1A;
					if (dist <= coreRadius && ix < FIREBALL_WIDTH * 0.66)
						color = 0xFFFFFF4A;
					if (ix > FIREBALL_WIDTH * 0.82 && dist > 7)
						color = 0xFFFF0000;
					pixels.setPixel32(ix, iy, color);
				}
			}
		}

		fireball.updateHitbox();
	}

	function applyIdle(elapsed:Float)
	{
		time += elapsed;

		var bodyBob = Math.sin(time * 2) * 3;
		var bodyBreath = 1 + Math.sin(time * 1.2) * 0.02;
		positionPart(body, 0, bodyBob, 0, bodyBreath, bodyBreath);
		positionLegs(0, bodyBob, 0, bodyBreath, bodyBreath, Math.sin(time * 2.8) * 2.2, Math.sin(time * 2.2) * 1.4, Math.sin(time * 1.6) * 0.5);

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
		mouthIsOpen = isSingingPose(anim);

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
				positionLegs(-4 - attackPulse * 2, 1 + bodyBob, -0.25 - loopWave * 0.25, 1, 1, -5 - attackPulse * 3, attackPulse * 1.8, 1.5 + attackPulse * 2);
				positionPart(head, -5 - attackPulse * 3, headBob, -0.5 - loopWave * 1.5);
				positionPart(tail, -45 - attackPulse * 2, 5 + bodyBob, -5 - tailFlick);
			case 'singDOWN':
				positionPart(body, 2, 5 + bodyBob + attackPulse * 3, loopWave * 0.2, 1.02 + attackPulse * 0.015, 0.98 - attackPulse * 0.015);
				positionLegs(2, 5 + bodyBob + attackPulse * 3, loopWave * 0.2, 1.02 + attackPulse * 0.015, 0.98 - attackPulse * 0.015, loopWave, attackPulse * 4, 3 + attackPulse * 2);
				positionPart(head, 5, headBob + attackPulse * 2, loopWave);
				positionPart(tail, -40, 20 + bodyBob + attackPulse * 2, tailFlick * 0.7);
			case 'singUP':
				positionPart(body, 2, -4 + bodyBob - attackPulse * 3, 0.2 + loopWave * 0.2, 0.99 - attackPulse * 0.01, 1.02 + attackPulse * 0.02);
				positionLegs(2, -4 + bodyBob - attackPulse * 3, 0.2 + loopWave * 0.2, 0.99 - attackPulse * 0.01, 1.02 + attackPulse * 0.02, 2 + attackPulse * 2, -attackPulse * 3, -1.5 - attackPulse);
				positionPart(head, 5, headBob - attackPulse * 3, 0.5 + loopWave * 1.25);
				positionPart(tail, -35, bodyBob - attackPulse, 10 + tailFlick);
			case 'singRIGHT':
				positionPart(body, 5 + attackPulse * 2, 1 + bodyBob, 0.25 + loopWave * 0.25, 1, 1);
				positionLegs(5 + attackPulse * 2, 1 + bodyBob, 0.25 + loopWave * 0.25, 1, 1, 5 + attackPulse * 3, attackPulse * 1.8, 1.5 + attackPulse * 2);
				positionPart(head, 15 + attackPulse * 3, headBob, 0.5 + loopWave * 1.5);
				positionPart(tail, -35 + attackPulse * 2, 5 + bodyBob, 5 + tailFlick);
			case 'idle':
				positionPart(body, 0, 0, 0, 1, 1);
				positionLegs(0, 0, 0, 1, 1);
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
				positionLegs(0, -4 - pop * 5, wave * 0.35, 1 + pop * 0.015, 1 - pop * 0.01, wave * 2, -pop * 2, -pop);
				positionPart(head, 0, -10 - pop * 7, wave * 2.2);
				positionPart(tail, -40, 10 - pop * 3, pop * 10 + Math.sin(singPoseTime * 24) * 5);
			case 'pre-attack':
				var p:Float = easePose(singPoseTime, ACTION_POSE_DURATION);
				var shake:Float = Math.sin(singPoseTime * 42) * p;
				positionPart(body, -12 * p, 10 * p, -6 * p + shake, 1.04, 0.96);
				positionLegs(-12 * p, 10 * p, -6 * p + shake, 1.04, 0.96, -8 * p, 4 * p, 5 * p);
				positionPart(head, -14 * p, 2 * p, -8 * p + shake * 1.5);
				positionPart(tail, -58 * p - 40, 18 * p, 20 * p + Math.sin(singPoseTime * 22) * 4);
			case 'attack':
				var p:Float = easePose(singPoseTime, ACTION_POSE_DURATION);
				var strike:Float = Math.sin(p * Math.PI);
				positionPart(body, 18 * strike + 4 * p, -7 * strike, 5 * strike, 1.03 + strike * 0.03, 0.98);
				positionLegs(18 * strike + 4 * p, -7 * strike, 5 * strike, 1.03 + strike * 0.03, 0.98, 10 * strike, -4 * strike, -4 * strike);
				positionPart(head, 34 * strike + 8 * p, -12 * strike, 9 * strike);
				positionPart(tail, -44 - 18 * strike, 4 - 5 * strike, -16 * strike + Math.sin(singPoseTime * 26) * 3);
			case 'shoot':
				var p:Float = easePose(singPoseTime, FIREBALL_DURATION);
				var blast:Float = Math.sin(Math.min(p, 1) * Math.PI);
				positionPart(body, -8 * blast + 2 * p, -3 * blast, -3 * blast, 1.02 + blast * 0.02, 0.98);
				positionLegs(-8 * blast + 2 * p, -3 * blast, -3 * blast, 1.02 + blast * 0.02, 0.98, -7 * blast, -3 * blast, 4 * blast);
				positionPart(head, 22 * blast + 8 * p, -8 * blast, 6 * blast);
				positionPart(tail, -54 - 10 * blast, 8 - 4 * blast, -20 * blast + Math.sin(singPoseTime * 28) * 3);
				mouthIsOpen = true;
			case 'dodge':
				var p:Float = easePose(singPoseTime, ACTION_POSE_DURATION);
				var dip:Float = Math.sin(p * Math.PI);
				positionPart(body, -24 * dip, 18 * dip, -11 * dip, 1.02, 0.95);
				positionLegs(-24 * dip, 18 * dip, -11 * dip, 1.02, 0.95, -12 * dip, 7 * dip, 6 * dip);
				positionPart(head, -20 * dip, 12 * dip, -14 * dip);
				positionPart(tail, -48 - 12 * dip, 20 * dip, 18 * dip + Math.sin(singPoseTime * 20) * 2);
			case 'hurt', 'hit':
				var p:Float = easePose(singPoseTime, HIT_POSE_DURATION);
				var decay:Float = 1 - p;
				var shake:Float = Math.sin(singPoseTime * 75) * 5 * decay;
				positionPart(body, -8 * decay + shake, 6 * decay, -4 * decay + shake * 0.4, 1, 1);
				positionLegs(-8 * decay + shake, 6 * decay, -4 * decay + shake * 0.4, 1, 1, -5 * decay + shake, 3 * decay, 4 * decay);
				positionPart(head, -12 * decay + shake * 1.2, 4 * decay, -7 * decay + shake * 0.5);
				positionPart(tail, -46 + shake, 8 * decay, 12 * decay - shake);
			case 'scared':
				var shake:Float = Math.sin(singPoseTime * 70) * 3;
				var shiver:Float = Math.sin(singPoseTime * 42) * 2;
				positionPart(body, shake, 7 + shiver, shiver * 0.5, 0.98, 1.02);
				positionLegs(shake, 7 + shiver, shiver * 0.5, 0.98, 1.02, Math.sin(singPoseTime * 60) * 4, shiver * 1.5, 2);
				positionPart(head, 5 + shake * 1.4, -2 + shiver, shake * 1.2);
				positionPart(tail, -52 + shake, 10 + shiver, 28 + Math.sin(singPoseTime * 55) * 5);
		}

		setMouth(mouthIsOpen);
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

	function isSingingPose(anim:String):Bool
		return anim.startsWith('sing');

	function isFireballAnim(anim:String):Bool
		return getPoseAnim(anim) == 'shoot';

	function positionPart(spr:FlxSprite, offsetX:Float, offsetY:Float, angleValue:Float = 0, scaleX:Float = 1, scaleY:Float = 1)
	{
		var direction:Float = flipX ? -1 : 1;
		spr.x = x + offsetX * direction;
		spr.y = y + offsetY;
		spr.angle = angleValue * direction;
		spr.scale.set(scale.x * scaleX, scale.y * scaleY);
		spr.flipX = flipX;
	}

	function positionLegs(offsetX:Float, offsetY:Float, angleValue:Float = 0, scaleX:Float = 1, scaleY:Float = 1, stride:Float = 0, lift:Float = 0, brace:Float = 0)
	{
		var rearShift:Float = -stride * 0.35 - brace * 0.25;
		var frontShift:Float = stride * 0.45 + brace * 0.35;
		var rearLift:Float = lift * 0.25 + Math.max(brace, 0) * 0.35;
		var frontLift:Float = -lift * 0.45 - Math.max(-brace, 0) * 0.35;
		var rearAngle:Float = angleValue - stride * 0.035 - brace * 0.08;
		var frontAngle:Float = angleValue + stride * 0.045 + brace * 0.1;
		var rearScaleY:Float = scaleY + Math.max(brace, 0) * 0.004;
		var frontScaleY:Float = scaleY + Math.max(-brace, 0) * 0.004;

		positionPart(backLegBack, offsetX + rearShift * 0.75, offsetY + rearLift + 1, rearAngle, scaleX, rearScaleY);
		positionPart(backLegFront, offsetX + rearShift, offsetY + rearLift - lift * 0.15, rearAngle * 0.8, scaleX, rearScaleY);
		positionPart(frontLegBack, offsetX + frontShift * 0.8, offsetY + frontLift + lift * 0.2, frontAngle * 0.85, scaleX, frontScaleY);
		positionPart(frontLegFront, offsetX + frontShift, offsetY + frontLift - 1, frontAngle, scaleX, frontScaleY);
	}

	function updateMouth()
	{
		mouth.scale.set(head.scale.x, head.scale.y);
		mouth.updateHitbox();

		var mouthPoint = getHeadLocalPoint(getMouthOffsetX(), getMouthOffsetY());
		mouth.x = mouthPoint.x - mouth.width * 0.5;
		mouth.y = mouthPoint.y - mouth.height * 0.5;
		mouth.angle = head.angle;
		mouth.flipX = flipX;
		mouth.antialiasing = head.antialiasing;
		mouth.alpha = head.alpha;
		mouth.visible = head.visible && mouthIsOpen;
	}

	function getMouthOffsetX():Float
		return isFireballAnim(currentAnim) ? FIREBALL_MOUTH_OFFSET_X : MOUTH_OFFSET_X;

	function getMouthOffsetY():Float
		return isFireballAnim(currentAnim) ? FIREBALL_MOUTH_OFFSET_Y : MOUTH_OFFSET_Y;

	function getHeadLocalPoint(localX:Float, localY:Float):Dynamic
	{
		var direction:Float = flipX ? -1 : 1;
		var scaledOriginX:Float = head.origin.x * head.scale.x;
		var scaledOriginY:Float = head.origin.y * head.scale.y;
		var scaledLocalX:Float = localX * direction * head.scale.x;
		var scaledLocalY:Float = localY * head.scale.y;
		var relativeX:Float = scaledLocalX - scaledOriginX;
		var relativeY:Float = scaledLocalY - scaledOriginY;
		var angleRadians:Float = head.angle * Math.PI / 180;
		var cos:Float = Math.cos(angleRadians);
		var sin:Float = Math.sin(angleRadians);

		return {
			x: head.x + scaledOriginX + relativeX * cos - relativeY * sin,
			y: head.y + scaledOriginY + relativeX * sin + relativeY * cos
		};
	}

	function updateFireball(elapsed:Float)
	{
		if (debugMode && isFireballAnim(currentAnim))
			fireballTimer = FIREBALL_DURATION - (singPoseTime % FIREBALL_DURATION);
		else if (fireballTimer > 0)
			fireballTimer = Math.max(0, fireballTimer - elapsed);

		if (!isFireballAnim(currentAnim) || fireballTimer <= 0)
		{
			fireball.visible = false;
			fireball.alpha = 0;
			fireballFade = 0;
			return;
		}

		var direction:Float = flipX ? -1 : 1;
		var progress:Float = 1 - fireballTimer / FIREBALL_DURATION;
		var muzzlePoint = getHeadLocalPoint(FIREBALL_MOUTH_OFFSET_X, FIREBALL_MOUTH_OFFSET_Y);
		var startX:Float = muzzlePoint.x + (flipX ? -FIREBALL_WIDTH : 0);
		var startY:Float = muzzlePoint.y - FIREBALL_HEIGHT * 0.5;

		fireball.x = startX + FIREBALL_TRAVEL * progress * direction;
		fireball.y = startY - Math.sin(progress * Math.PI) * 10;
		fireball.flipX = flipX;
		fireball.angle = head.angle;
		fireballFade = 1 - Math.max(0, progress - 0.72) / 0.28;
		fireball.alpha = fireballFade;
		fireball.visible = true;
		fireball.scale.set(scale.x, scale.y);
		fireball.updateHitbox();
	}

	function setMouth(open:Bool)
	{
		var shape = getMouthShape(open);
		if (currentMouthShape != shape.name)
		{
			drawMouthGraphic(shape.name, shape.width, shape.height);
			currentMouthShape = shape.name;
		}
		mouth.updateHitbox();
	}

	function getMouthShape(open:Bool):Dynamic
	{
		if (!open)
			return {name: 'closed', width: 12, height: 5};

		return switch(getPoseAnim(currentAnim))
		{
			case 'singLEFT':
				{name: 'singLEFT', width: 18, height: 8};
			case 'singDOWN':
				{name: 'singDOWN', width: 15, height: 15};
			case 'singUP':
				{name: 'singUP', width: 10, height: 17};
			case 'singRIGHT':
				{name: 'singRIGHT', width: 18, height: 8};
			case 'shoot':
				{name: 'shoot', width: 24, height: 13};
			default:
				{name: 'open', width: 12, height: 10};
		}
	}

	function drawMouthGraphic(shapeName:String, widthValue:Int, heightValue:Int)
	{
		mouth.makeGraphic(widthValue, heightValue, 0x00000000, true);
		var pixels = mouth.pixels;
		var centerX:Float = (widthValue - 1) * 0.5;
		var centerY:Float = (heightValue - 1) * 0.5;
		var radiusX:Float = Math.max(widthValue * 0.5, 1);
		var radiusY:Float = Math.max(heightValue * 0.5, 1);

		for (ix in 0...widthValue)
		{
			for (iy in 0...heightValue)
			{
				var normalizedX:Float = (ix - centerX) / radiusX;
				var normalizedY:Float = (iy - centerY) / radiusY;
				var inside:Bool = normalizedX * normalizedX + normalizedY * normalizedY <= 1;

				switch(shapeName)
				{
					case 'closed':
						inside = iy >= Std.int(centerY) && iy <= Std.int(centerY) + 1 && ix > 1 && ix < widthValue - 2;
					case 'singLEFT':
						inside = inside && iy >= Math.floor(ix * 0.18) && iy <= heightValue - 1 - Math.floor(ix * 0.08);
					case 'singRIGHT':
						inside = inside && iy >= Math.floor((widthValue - ix) * 0.18) && iy <= heightValue - 1 - Math.floor((widthValue - ix) * 0.08);
					case 'singUP':
						inside = inside && iy < heightValue - 1;
					case 'shoot':
						inside = inside || (ix > widthValue * 0.65 && Math.abs(iy - centerY) <= 3);
				}

				if (inside)
					pixels.setPixel32(ix, iy, 0xFF000000);
			}
		}

		mouth.updateHitbox();
	}

	function setPartsColor(colorValue:FlxColor)
	{
		for (spr in [tail, backLegBack, backLegFront, body, frontLegBack, frontLegFront, head])
			spr.color = colorValue;
	}

	#if sys
	public function makeSpritesheet(?outputFolder:String = 'example_mods/images', ?sheetName:String = 'flareon-generated', framePadding:Int = 24, columns:Int = 8, ?characterFolder:String):Bool
	{
		if (columns < 1)
			columns = 1;

		var frames:Array<Dynamic> = [];
		var exportAnims = getSheetAnimationSpecs();
		for (anim in exportAnims)
			addSheetFrames(frames, anim.anim, anim.duration, anim.frames);

		var oldX:Float = x;
		var oldY:Float = y;
		var oldTime:Float = time;
		var oldSingPoseTime:Float = singPoseTime;
		var oldAnim:String = currentAnim;
		var oldMouthOpen:Bool = mouthIsOpen;
		var oldFireballTimer:Float = fireballTimer;
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
			drawSheetPart(sheet, backLegBack, drawX, drawY);
			drawSheetPart(sheet, backLegFront, drawX, drawY);
			drawSheetPart(sheet, body, drawX, drawY);
			drawSheetPart(sheet, frontLegBack, drawX, drawY);
			drawSheetPart(sheet, frontLegFront, drawX, drawY);
			drawSheetPart(sheet, head, drawX, drawY);
			if (mouthIsOpen)
				drawSheetPart(sheet, mouth, drawX, drawY);
			if (fireball.visible)
				drawSheetPart(sheet, fireball, drawX, drawY);

			xml.add('\t<SubTexture name="${frame.name}" x="${cellX}" y="${cellY}" width="${frameWidth}" height="${frameHeight}" frameX="0" frameY="0" frameWidth="${frameWidth}" frameHeight="${frameHeight}"/>\n');
		}

		xml.add('</TextureAtlas>');

		ensureDirectory(outputFolder);
		if (characterFolder == null)
			characterFolder = getDefaultCharacterFolder(outputFolder);
		if (characterFolder != null && characterFolder.length > 0)
			ensureDirectory(characterFolder);

		File.saveBytes('$outputFolder/$sheetName.png', sheet.encode(sheet.rect, new PNGEncoderOptions()));
		File.saveContent('$outputFolder/$sheetName.xml', xml.toString());
		if (characterFolder != null && characterFolder.length > 0)
			File.saveContent('$characterFolder/$sheetName.json', Json.stringify(makeCharacterJson(sheetName, outputFolder, exportAnims), null, "\t"));
		sheet.dispose();

		x = oldX;
		y = oldY;
		time = oldTime;
		singPoseTime = oldSingPoseTime;
		currentAnim = oldAnim;
		mouthIsOpen = oldMouthOpen;
		fireballTimer = oldFireballTimer;
		setPartsColor(oldPartColor);
		poseForSheetFrame(currentAnim, singPoseTime);
		fireballTimer = oldFireballTimer;
		updateFireball(0);
		return true;
	}

	function getSheetAnimationSpecs():Array<Dynamic>
	{
		var ordered:Array<String> = [
			'idle', 'idle-loop', 'danceLeft', 'danceRight', 'hey',
			'singLEFT', 'singDOWN', 'singUP', 'singRIGHT',
			'singLEFT-loop', 'singDOWN-loop', 'singUP-loop', 'singRIGHT-loop',
			'singLEFTmiss', 'singDOWNmiss', 'singUPmiss', 'singRIGHTmiss',
			'pre-attack', 'attack', 'shoot', 'dodge', 'hurt', 'hit', 'scared'
		];
		var names:Array<String> = [];
		for (anim in ordered)
			if (hasAnimation(anim) && !names.contains(anim))
				names.push(anim);
		for (anim in animOffsets.keys())
			if (!names.contains(anim))
				names.push(anim);

		return [for (anim in names) {
			anim: anim,
			duration: getSheetAnimationDuration(anim),
			frames: getSheetAnimationFrameCount(anim),
			loop: isSheetAnimationLooped(anim)
		}];
	}

	function getSheetAnimationDuration(anim:String):Float
	{
		if (anim.endsWith('-loop'))
			return 0.35;
		if (isIdleAnim(anim))
			return 0.8;
		if (anim == 'hey')
			return HEY_POSE_DURATION;
		if (anim.startsWith('sing'))
			return SING_POSE_DURATION;
		if (anim == 'hurt' || anim == 'hit')
			return HIT_POSE_DURATION;
		if (anim == 'shoot')
			return FIREBALL_DURATION;
		if (anim == 'scared')
			return 0.5;
		return ACTION_POSE_DURATION;
	}

	function getSheetAnimationFrameCount(anim:String):Int
	{
		if (isIdleAnim(anim) || anim == 'scared')
			return 8;
		if (anim.startsWith('sing') && !anim.endsWith('-loop'))
			return 4;
		return 6;
	}

	function isSheetAnimationLooped(anim:String):Bool
		return isIdleAnim(anim) || anim.endsWith('-loop') || anim == 'scared';

	function makeCharacterJson(sheetName:String, outputFolder:String, exportAnims:Array<Dynamic>):Dynamic
	{
		return {
			animations: [for (anim in exportAnims) {
				anim: anim.anim,
				name: anim.anim,
				fps: 24,
				loop: anim.loop,
				indices: [],
				offsets: getSheetAnimationOffsets(anim.anim)
			}],
			image: getCharacterImagePath(outputFolder, sheetName),
			scale: jsonScale,
			sing_duration: singDuration,
			healthicon: healthIcon,
			position: positionArray,
			camera_position: cameraPosition,
			flip_x: originalFlipX,
			no_antialiasing: noAntialiasing,
			healthbar_colors: healthColorArray,
			vocals_file: vocalsFile,
			_editor_isPlayer: isPlayer
		};
	}

	function getSheetAnimationOffsets(anim:String):Array<Int>
	{
		var daOffset = animOffsets.get(anim);
		if (daOffset == null || daOffset.length < 2)
			return [0, 0];
		return [Std.int(daOffset[0]), Std.int(daOffset[1])];
	}

	function getCharacterImagePath(outputFolder:String, sheetName:String):String
	{
		var normalized:String = outputFolder.replace('\\', '/');
		if (normalized.endsWith('/images'))
			return sheetName;

		var marker:String = '/images/';
		var markerIndex:Int = normalized.lastIndexOf(marker);
		if (markerIndex > -1)
			return normalized.substr(markerIndex + marker.length) + '/' + sheetName;

		if (normalized.startsWith('images/'))
			return normalized.substr('images/'.length) + '/' + sheetName;
		return sheetName;
	}

	function getDefaultCharacterFolder(outputFolder:String):String
	{
		var normalized:String = outputFolder.replace('\\', '/');
		if (normalized.endsWith('/images'))
			return normalized.substr(0, normalized.length - '/images'.length) + '/characters';

		var marker:String = '/images/';
		var markerIndex:Int = normalized.lastIndexOf(marker);
		if (markerIndex > -1)
			return normalized.substr(0, markerIndex) + '/characters';
		return 'example_mods/characters';
	}

	function ensureDirectory(path:String)
	{
		if (path == null || path.length < 1 || FileSystem.exists(path))
			return;

		var parent:String = haxe.io.Path.directory(path);
		if (parent != null && parent.length > 0 && parent != path)
			ensureDirectory(parent);
		FileSystem.createDirectory(path);
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
		{
			applyIdle(0);
			mouthIsOpen = false;
		}
		else
			applyPose(anim);

		updateMouth();
		fireballTimer = isFireballAnim(anim) ? FIREBALL_DURATION - Math.min(poseTime, FIREBALL_DURATION) : 0;
		updateFireball(0);
	}

	function getSheetBounds():Rectangle
	{
		var bounds = new Rectangle(Math.POSITIVE_INFINITY, Math.POSITIVE_INFINITY, 0, 0);
		includeSheetPartBounds(bounds, tail);
		includeSheetPartBounds(bounds, backLegBack);
		includeSheetPartBounds(bounds, backLegFront);
		includeSheetPartBounds(bounds, body);
		includeSheetPartBounds(bounds, frontLegBack);
		includeSheetPartBounds(bounds, frontLegFront);
		includeSheetPartBounds(bounds, head);
		if (mouthIsOpen)
			includeSheetPartBounds(bounds, mouth);
		if (fireball.visible)
			includeSheetPartBounds(bounds, fireball);
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
		for (spr in [tail, backLegBack, backLegFront, body, frontLegBack, frontLegFront, head])
		{
			copyPartValues(spr);
			updateDropShadowFrameInfo(spr);
			spr.draw();
		}

		copyPartValues(mouth, mouthIsOpen);
		updateDropShadowFrameInfo(mouth);
		mouth.draw();

		copyPartValues(fireball, fireball.visible);
		fireball.alpha = alpha * fireballFade;
		updateDropShadowFrameInfo(fireball);
		fireball.draw();
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
			mouthIsOpen = false;
			singTimer = switch(AnimName)
			{
				case 'hey': HEY_POSE_DURATION;
				case 'shoot': FIREBALL_DURATION;
				case 'hurt', 'hit': HIT_POSE_DURATION;
				default: ACTION_POSE_DURATION;
			}
			if (AnimName == 'shoot')
			{
				mouthIsOpen = true;
				fireballTimer = FIREBALL_DURATION;
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
