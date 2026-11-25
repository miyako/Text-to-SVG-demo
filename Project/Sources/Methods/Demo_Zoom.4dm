// Demo_Zoom -- crop the annotated preview to 1/factor of the content box.
// The SVG is rebuilt, not scaled: the picture stays vector at every level.

#DECLARE($factor : Real)

var $lab : cs.OutlineLab
$lab:=Form.lab
If ($lab=Null)
	return 
End if 

$lab.zoom:=$factor
$lab.buildGuides()
$lab.renderPreview()
Demo_Sync
