// Demo_Render -- redraw the preview from the current metrics only.
// Used by the guides checkbox and the zoom buttons: no component call, so the
// rasterisation cost is the only cost paid.

var $lab : cs.OutlineLab
$lab:=Form.lab
If ($lab=Null)
	return 
End if 

$lab.buildGuides()
$lab.renderPreview()
Demo_Sync
