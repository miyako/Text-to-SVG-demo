// Demo_Save -- write the component SVG (physical units) and the annotated SVG
// to the Desktop, then let the OS open the exact output in its SVG viewer.

var $lab : cs.OutlineLab
$lab:=Form.lab
If (($lab=Null) || ($lab.exactSvg=""))
	return 
End if 

var $folder : 4D.Folder
$folder:=Folder(fk desktop folder)

var $stamp : Text
$stamp:=Replace string(String(Current date; ISO date; Current time); ":"; "-")
$stamp:=Replace string($stamp; " "; "_")

var $exact : 4D.File
$exact:=$folder.file("text-to-svg-outlines-"+$stamp+".svg")
$exact.setText($lab.exactSvg)

var $annotated : 4D.File
$annotated:=$folder.file("text-to-svg-preview-"+$stamp+".svg")
$annotated.setText($lab.annotatedSvg)

Form.panelTitle:="SAVED — "+$exact.name+" and "+$annotated.name+" on the Desktop"
var $opened : Text
$opened:=String(Open document($exact.platformPath))
