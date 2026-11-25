// Demo_Compile -- compile the project from the command line and report the
// result as JSON. tool4d has no --compile switch, so scripts/smoke.sh calls
// this method instead.

var $result : Object
$result:=Compile project(New object("targets"; New collection("x86_64_generic"; "arm64_macOS_lib")))

var $folder : 4D.Folder
$folder:=Folder("/tmp/tts-demo"; fk posix path)
If (Not($folder.exists))
	$folder.create()
End if 
var $file : 4D.File
$file:=$folder.file("compile.json")
$file.setText(JSON Stringify(New object("result"; $result); *))
