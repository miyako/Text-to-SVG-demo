// Demo_OnErr -- diagnostic handler: records the error stack as JSON.
//
// Installed only around a specific guarded call, always with ek local, and
// removed immediately afterwards. Never left installed globally.

var $errors : Collection
$errors:=Last errors()
var $folder : 4D.Folder
$folder:=Folder("/tmp/tts-demo"; fk posix path)
If (Not($folder.exists))
	$folder.create()
End if 
var $file : 4D.File
$file:=$folder.file("error.json")
$file.setText(JSON Stringify(New object("errors"; $errors); *))

// SelfTest watches for this sentinel instead of trusting a boolean that a raised
// error may never reach.
var $sentinel : 4D.File
$sentinel:=$folder.file("formload-error.json")
$sentinel.setText(String(Milliseconds))
