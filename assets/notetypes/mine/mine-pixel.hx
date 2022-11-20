function generateNote(newNote)
{
	var framesArg:String = 'mines';

	newNote.loadGraphic(Paths.image('mine/skins/pixel/mines', 'notetypes'), true, 17, 17);
	newNote.animation.add(Receptor.actions[newNote.noteData] + 'Scroll', [0, 1, 2, 3, 4, 5, 6, 7], 12);
	newNote.animation.play(stringSect + 'Scroll');

	newNote.isMine = true;
	newNote.antialiasing = false;
	newNote.setGraphicSize(Std.int(newNote.width * PlayState.daPixelZoom));
	newNote.updateHitbox();
}

function generateSustain(newNote)
{
	newNote.kill();
}


function onHit(newNote)
{
	PlayState.health -= 0.0875;
}