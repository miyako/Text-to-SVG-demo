// Demo_CycleZoom -- the picture canvas itself is clickable: 1x, 2x, 4x, 8x, 1x.

var $lab : cs.OutlineLab
$lab:=Form.lab
If ($lab=Null)
	return 
End if 

var $next : Real
Case of 
	: ($lab.zoom<1.5)
		$next:=2
	: ($lab.zoom<2.5)
		$next:=4
	: ($lab.zoom<4.5)
		$next:=8
	Else 
		$next:=1
End case 

$lab.zoom:=$next
$lab.buildGuides()
$lab.renderPreview()
Demo_Sync
