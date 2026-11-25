// Demo_Copy -- the component output goes to the clipboard verbatim, ready to
// paste into a browser, Illustrator or an .svg file.

var $lab : cs.OutlineLab
$lab:=Form.lab
If (($lab=Null) || ($lab.exactSvg=""))
	return 
End if 

SET TEXT TO PASTEBOARD($lab.exactSvg)
Form.panelTitle:="COPIED — "+String(Length($lab.exactSvg))+" bytes of SVG on the clipboard"
