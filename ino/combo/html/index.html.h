R"EOF(

<!DOCTYPE html>
<html>

<head>
    <title>Управление светом</title>
    <meta charset="utf-8">
    <link rel="stylesheet" href="main-min.css">
    <link rel="stylesheet" href="spectrum-min.css">
</head>

<body>

<div class=loading>Идет загрузка 1, подождите</div>

<div id=mainContent style="display:none">

<div id="boxOuter">
<div class="square"><div class="inner docontrolWrapper">
Свет:
<label><input id="do1" type=checkbox value="Свет1" class=docontrol>1</label>
<label><input id="do2" type=checkbox value="Свет2" class=docontrol>2</label>
<label><input id="do3" type=checkbox value="Свет3" class=docontrol>3</label>
<label><input id="do4" type=checkbox value="Свет4" class=docontrol>4</label>
</div></div>
<div class="square"><div class="inner dmxwrapper">
    <input type=text class=dmx id=dmx1>
    <input type=text class=dmx id=dmx2>
</div></div>
<div class="square"><div class="inner smokecontrolWrapper">
Дым:
<input id="smoke1" type=button value="1" class=smoke>
<input id="smoke2" type=button value="2" class=smoke>
<input id="smoke3" type=button value="3" class=smoke>
<input id="smoke5" type=button value="5" class=smoke>
<input id="smoke10" type=button value="10" class=smoke>
<input id="smoke20" type=button value="20" class=smoke>
</div></div>
</div>

</div>

<div class=loading>Идет загрузка 2, подождите</div>
<script src="jquery-3.2.1.min.js"></script>
<div class=loading>Идет загрузка 3, подождите</div>
<script src="colorcalc-min.js"></script>
<div class=loading>Идет загрузка 4, подождите</div>
<script src="script-min.js"></script>
<div class=loading>Идет загрузка 5, подождите</div>
<script src="spectrum-min.js"></script>
<div class=loading>Идет загрузка 6, подождите</div>

</body>
</html>

)EOF"