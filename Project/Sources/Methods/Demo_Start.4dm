// Demo_Start -- open the lab, with or without a parameter.
//
// No parameter (On Startup, or the "Start" button): bring an existing lab
// window to the front, or ask the application worker to open one.
// With a parameter: build the model, convert once, then show the form.

var $title : Text
$title:="Text-to-SVG Lab"
var $window : Integer

If (Count parameters=0)
	ARRAY LONGINT($windows; 0)
	WINDOW LIST($windows)
	var $i : Integer
	For ($i; 1; Size of array($windows))
		$window:=$windows{$i}
		If ((Window process($window)=1) && (Get window title($window)=$title))
			var $left; $top; $right; $bottom : Integer
			GET WINDOW RECT($left; $top; $right; $bottom; $window)
			CALL FORM($window; Formula(SET WINDOW RECT($left; $top; $right; $bottom; $window)))
			return 
		End if 
	End for 
	CALL WORKER(1; Current method name; {})

Else 
	var $lab : cs.OutlineLab
	$lab:=cs.OutlineLab.new()
	$lab.convert()

	var $data : Object
	$data:=New object("lab"; $lab)

	$window:=Open form window("Lab"; Plain form window; Horizontally centered; Vertically centered)
	SET WINDOW TITLE($title; $window)
	DIALOG("Lab"; $data; *)
End if 
