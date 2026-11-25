// Demo_Examples -- write a small, curated set of artifacts from one component
// call each. Used for the README figures and as a fast "does it really work"
// check that does not depend on the form.
//
// Output: /tmp/tts-demo/examples/{case}.svg and examples/index.json

var $lab : cs.OutlineLab
$lab:=cs.OutlineLab.new()
$lab.fontSize:=10

var $folder : 4D.Folder
$folder:=Folder("/tmp/tts-demo/examples"; fk posix path)
If ($folder.exists)
	// 4D.Folder.delete() refuses a non-empty folder (error 651); the classic
	// command with Delete with contents is the one that actually clears it.
	DELETE FOLDER($folder.path; Delete with contents)
End if 
$folder.create()

var $cases : Collection
$cases:=New collection( \
	New object("name"; "latin"; "text"; "AV Office"; "units"; "mm"; "note"; "Arial, 9 glyphs, ligature-free"); \
	New object("name"; "ligature"; "text"; "ﬁle"; "units"; "mm"; "note"; "U+FB01 renders as one glyph"); \
	New object("name"; "japanese"; "text"; "日本語"; "units"; "mm"; "note"; "Hiragino Sans, three glyphs"); \
	New object("name"; "points"; "text"; "AV Office"; "units"; "pt"; "note"; "same numerals, pt label"))

var $index : Collection
$index:=New collection

var $case : Object
var $file : 4D.File
For each ($case; $cases)
	$lab.fontIndex:=$lab.preferIndex(Choose($case.name="japanese"; "Hiragino Sans"; "Arial"))
	$lab.text:=$case.text
	$lab.units:=$case.units
	$lab.convert()
	$file:=$folder.file($case.name+".svg")
	$file.setText($lab.exactSvg)
	$index.push(New object( \
		"name"; $case.name; \
		"text"; $case.text; \
		"font"; $lab.fontFileName(); \
		"units"; $lab.units; \
		"note"; $case.note; \
		"ok"; ($lab.errorCode=""); \
		"glyphCount"; Choose($lab.metrics=Null; 0; $lab.metrics.glyphCount); \
		"advance"; Choose($lab.metrics=Null; 0; Num($lab.metrics.advance.x)); \
		"bytes"; Length($lab.exactSvg)))
End for each 

var $indexFile : 4D.File
$indexFile:=$folder.file("index.json")
$indexFile.setText(JSON Stringify(New object("component"; $lab.cliVersion; "target"; $lab.target; "cases"; $index); *))
