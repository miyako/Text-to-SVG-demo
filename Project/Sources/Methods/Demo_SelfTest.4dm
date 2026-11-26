// Demo_SelfTest -- the headless evidence run.
//
// It exercises the same model class the form uses, checks the reference
// geometry published by the component, walks every accepted and rejected case,
// and writes /tmp/tts-demo/selftest.json plus the two SVG artifacts.
// scripts/smoke.sh runs it through tool4d and fails on any red row.
//
// Usage:
//   tool4d --project Project/Text-to-SVG-demo.4DProject \
//          --startup-method Demo_SelfTest --skip-onstartup --dataless

#DECLARE() : Object

var $lab : cs.OutlineLab
$lab:=cs.OutlineLab.new()

var $checks : Collection
$checks:=New collection

var $report : Object
$report:=New object(\
	"component"; "Text-to-SVG"; \
	"version"; $lab.cliVersion; \
	"target"; $lab.target; \
	"host"; Choose(Is Windows; "Windows"; "macOS"); \
	"compiled"; Is compiled mode; \
	"convertedAt"; String(Current date; ISO date; Current time))

// ------------------------------------------------------- component presence
Demo_Assert($checks; "target is the native one"; ($lab.target="macOS-universal") || ($lab.target="Windows-x64"); $lab.target)
Demo_Assert($checks; "version() answers protocol 1"; ($lab.cliVersion="0.1.2"); "version.value.version -> "+$lab.cliVersion)

var $fontCount : Integer
$fontCount:=$lab.fonts.length
Demo_Assert($checks; "font scan finds files"; ($fontCount>10); String($fontCount)+" .ttf/.otf/.ttc files on this host")

// ------------------------------------------------------------ reference case
$lab.fontPathOverride:=""
$lab.fontIndex:=$lab.preferIndex("Arial")
$lab.faceIndex:=0
$lab.text:="AV Office"
$lab.fontSize:=10
$lab.units:="mm"
$lab.showGuides:=True
$lab.convert()

Demo_Assert($checks; "Arial is present"; ($lab.fontIndex>=0); $lab.fontPath())

var $ok : Boolean
$ok:=($lab.metrics#Null)
Demo_Assert($checks; "AV Office 10 mm converts"; $ok; $lab.status)

If ($ok)
	var $advance : Real
	$advance:=Num($lab.metrics.advance.x)
	var $ink : Object
	$ink:=$lab.metrics.inkBounds
	Demo_Assert($checks; "advance is 41.3135 mm"; (Abs($advance-41.3134765625)<0.0001); String($advance))
	Demo_Assert($checks; "glyphCount is 9"; ($lab.metrics.glyphCount=9); String($lab.metrics.glyphCount))
	Demo_Assert($checks; "ink box is 40.913 x 7.407 mm"; \
		(Abs(Num($ink.width)-40.9130859375)<0.0001) && (Abs(Num($ink.height)-7.4072265625)<0.0001); \
		String(Num($ink.width))+" x "+String(Num($ink.height)))
	Demo_Assert($checks; "ink starts above the baseline and only overshoots it slightly"; \
		(Num($ink.y)<0) && (Abs(Num($ink.y)+Num($ink.height))<=($lab.fontSize/50)); \
		"top "+String(Num($ink.y))+" mm, bottom "+String(Num($ink.y)+Num($ink.height))+" mm")
	Demo_Assert($checks; "pathData is closed outline data"; (Position("Z"; String($lab.metrics.pathData))>0) || (Position("z"; String($lab.metrics.pathData))>0); String(Length(String($lab.metrics.pathData)))+" bytes of path data")
	Demo_Assert($checks; "exact SVG is an svg document in mm"; \
		(Position("<svg"; $lab.exactSvg)=1) && (Position("mm\""; $lab.exactSvg)>0); String(Length($lab.exactSvg))+" bytes")
	Demo_Assert($checks; "annotated SVG carries the guides"; \
		(Position("<path"; $lab.annotatedSvg)>0) && (Position("non-scaling-stroke"; $lab.annotatedSvg)>0); String(Length($lab.annotatedSvg))+" bytes")
	Demo_Assert($checks; "em box spans the advance, not the padded view"; \
		(Position("x=\"0\" y=\"-10\" width=\"41.3134765625\""; $lab.annotatedSvg)>0); "em box width = advance 41.3134765625")
	var $dom : Text
	var $preview : Text
	$preview:=$lab.annotatedSvg
	$dom:=DOM Parse XML variable($preview)
	Demo_Assert($checks; "annotated SVG is well-formed XML"; (Length($dom)>0); "DOM reference "+$dom)
	If (Length($dom)>0)
		DOM CLOSE XML($dom)
	End if 
End if 

// -------------------------------------------------------------- ligature case
$lab.fontIndex:=$lab.preferIndex("HelveticaNeue")
If ($lab.fontIndex>=0)
	$lab.faceIndex:=0
	$lab.text:="office"
	$lab.convert()
	Demo_Assert($checks; "ligature: 6 characters, 4 glyphs"; ($lab.metrics#Null) && ($lab.metrics.glyphCount=4); \
		"characters "+String(Length("office"))+" -> glyphs "+String($lab.metrics.glyphCount))

	var $facePath : Text
	$facePath:=String($lab.metrics.pathData)
	$lab.faceIndex:=7
	$lab.convert()
	Demo_Assert($checks; "faceIndex 7 is a different face"; ($lab.metrics#Null) && (String($lab.metrics.pathData)#$facePath); \
		"face 0 and face 7 differ in pathData")
	$lab.faceIndex:=0
Else 
	Demo_Assert($checks; "ligature: HelveticaNeue available"; False; "no HelveticaNeue on this host; case not run")
End if 

// ------------------------------------------------------------------ CJK case
$lab.fontIndex:=$lab.preferIndex("Hiragino Sans")
$lab.faceIndex:=0
$lab.text:="日本語"
$lab.convert()
Demo_Assert($checks; "CJK: Japanese shapes to 3 glyphs"; ($lab.metrics#Null) && ($lab.metrics.glyphCount=3); $lab.status)

// --------------------------------------------------------------- empty cases
$lab.text:=""
$lab.convert()
Demo_Assert($checks; "empty text: ok, no ink, advance 0"; \
	($lab.metrics#Null) && ($lab.metrics.inkBounds=Null) && (Num($lab.metrics.advance.x)=0); $lab.status)

$lab.text:="   "
$lab.convert()
Demo_Assert($checks; "whitespace: 3 glyphs of advance, still no ink"; \
	($lab.metrics#Null) && ($lab.metrics.glyphCount=3) && ($lab.metrics.inkBounds=Null); "advance "+String(Num($lab.metrics.advance.x)))

// ------------------------------------------------------------- rejected cases
$lab.fontIndex:=$lab.preferIndex("Arial")
$lab.text:="مرحبا"
$lab.convert()
Demo_Assert($checks; "RTL is refused before shaping"; ($lab.errorCode="unsupported_layout"); $lab.errorCode+": "+$lab.errorMessage)

$lab.text:="日本語"
$lab.convert()
Demo_Assert($checks; "missing glyph is reported, not substituted"; ($lab.errorCode="missing_glyph"); $lab.errorCode+": "+$lab.errorMessage)

$lab.text:="Hi"
$lab.fontIndex:=$lab.preferIndex("Apple Color Emoji")
If ($lab.fontIndex>=0)
	$lab.convert()
	Demo_Assert($checks; "192 MiB emoji collection exceeds the font limit"; ($lab.errorCode="limit_exceeded"); $lab.errorCode+": "+$lab.errorMessage)
	$lab.fontIndex:=$lab.preferIndex("Arial")
End if 

$lab.fontPathOverride:="Arial.ttf"
$lab.text:="Hi"
$lab.convert()
Demo_Assert($checks; "a relative font path is rejected as invalid_argument"; ($lab.errorCode="invalid_argument"); $lab.errorCode+": "+$lab.errorMessage)
$lab.fontPathOverride:=""

$lab.fontSize:=10001
$lab.text:="Hi"
$lab.convert()
Demo_Assert($checks; "fontSize above 10000 is refused"; ($lab.errorCode="invalid_request"); $lab.errorCode+": "+$lab.errorMessage)

$lab.fontSize:=0
$lab.convert()
Demo_Assert($checks; "fontSize 0 is refused"; ($lab.errorCode="invalid_request"); $lab.errorCode+": "+$lab.errorMessage)
$lab.fontSize:=10

$lab.units:="cm"
$lab.convert()
Demo_Assert($checks; "unsupported unit is refused"; ($lab.errorCode="invalid_request"); $lab.errorCode+": "+$lab.errorMessage)
$lab.units:="mm"

var $long : Text
$long:=""
While (Length($long)<17000)
	$long:=$long+"AAAAAAAAAA"
End while 
$lab.text:=$long
$lab.convert()
Demo_Assert($checks; "text above 16384 UTF-8 bytes is refused"; ($lab.errorCode="limit_exceeded"); $lab.errorCode+": "+$lab.errorMessage)

// ------------------------------------------------------------ unit behaviour
$lab.text:="AV Office"
$lab.fontSize:=10
var $ladder : Text
$ladder:=$lab.compareUnits()
var $ladderData : Object
$ladderData:=$lab.unitLadder()
var $rows : Integer
$rows:=$ladderData.rows.query("ok = true").length
Demo_Assert($checks; "unit ladder answers for mm, pt, px and in"; ($rows=4) && ($ladderData.rows.length=4); String($rows)+" of 4 unit rows returned")
Demo_Assert($checks; "unit ladder: pathData identical in every unit"; $ladderData.identical; "identical="+String($ladderData.identical))
Demo_Assert($checks; "unit ladder: table does not invent a claim"; (Position("byte-identical"; $ladder)>0); "ladder text states the verified result")

$lab.units:="mm"
$lab.convert()
var $mmSvgHead : Text
$mmSvgHead:=Substring($lab.exactSvg; 1; 120)
var $mmPath : Text
$mmPath:=String($lab.metrics.pathData)
$lab.units:="pt"
$lab.convert()
Demo_Assert($checks; "units relabel the SVG but never rescale the geometry"; \
	($lab.metrics#Null) && (String($lab.metrics.pathData)=$mmPath) \
		&& (Position("mm\""; $mmSvgHead)>0) && (Position("pt\""; $lab.exactSvg)>0); \
	"pathData identical in mm and pt, width attribute changes suffix only")

// --------------------------------------------------------------- artifacts out
$lab.units:="mm"
$lab.text:="AV Office"
$lab.fontSize:=10
$lab.convert()

var $folder : 4D.Folder
$folder:=Folder("/tmp/tts-demo"; fk posix path)
If (Not($folder.exists))
	$folder.create()
End if 

var $exactFile : 4D.File
$exactFile:=$folder.file("selftest-outlines.svg")
$exactFile.setText($lab.exactSvg)
var $annotatedFile : 4D.File
$annotatedFile:=$folder.file("selftest-preview.svg")
$annotatedFile.setText($lab.annotatedSvg)

Demo_Assert($checks; "SVG artifacts are written"; $exactFile.exists && $annotatedFile.exists; $exactFile.path+" · "+$annotatedFile.path)

// A schema-valid form can still be a form 4D refuses to read. tool4d cannot open
// a form window, so object introspection is out of reach (FORM Get objects and
// FORM Convert to dynamic both fail without a window); FORM LOAD is the strongest
// engine-side check available, and it does fail on an unknown form name.
var $sentinel : 4D.File
$sentinel:=$folder.file("formload-error.json")
If ($sentinel.exists)
	$sentinel.delete()
End if 
ON ERR CALL("Demo_OnErr"; ek local)
FORM LOAD("Lab"; *)
ON ERR CALL(""; ek local)
Demo_Assert($checks; "4D loads the Lab form without raising an error"; Not($sentinel.exists); \
	Choose($sentinel.exists; "FORM LOAD raised, see "+$sentinel.path; "FORM LOAD(\"Lab\") clean"))
FORM UNLOAD

// ------------------------------------------------------------------- verdict
var $failed : Integer
$failed:=0
var $row : Object
For each ($row; $checks)
	If (Not($row.passed))
		$failed:=$failed+1
	End if 
End for each 

$report.checks:=$checks
$report.total:=$checks.length
$report.failed:=$failed
$report.passed:=($failed=0)
$report.artifacts:=New collection($exactFile.path; $annotatedFile.path)

var $reportFile : 4D.File
$reportFile:=$folder.file("selftest.json")
$reportFile.setText(JSON Stringify($report; *))

return $report
