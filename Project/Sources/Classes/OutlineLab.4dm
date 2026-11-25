// OutlineLab -- the demo's model. It owns one component instance, one font
// scan and one parameter set, and derives everything the form displays:
//
//  * the raw component envelope (ok / error, exitCode, elapsed time)
//  * the metric lines (advance vs ink bounds, glyphs vs characters)
//  * an annotated SVG that overlays the em box, baseline and advance on the
//    glyph outline, used as the interactive preview
//
// Keeping this in a class keeps the form methods to one line each.

property target : Text
property outline : cs.TextToSVG.TextOutline
property scanner : cs.FontScanner
property fonts : Collection
property cliVersion : Text

property fontIndex : Integer
property faceIndex : Integer
property fontPathOverride : Text
property text : Text
property fontSize : Real
property units : Text

property showGuides : Boolean
property zoom : Real

property result : Object
property metrics : Object
property exactSvg : Text
property annotatedSvg : Text
property preview : Picture

property status : Text
property errorCode : Text
property errorMessage : Text
property errorHint : Text
property elapsedMs : Integer
property logLines : Collection

Class constructor()
	This.target:=Choose(Is Windows; "Windows-x64"; "macOS-universal")
	This.outline:=cs.TextToSVG.TextOutline.new(This.target)
	This.scanner:=cs.FontScanner.new()
	This.fonts:=This.scanner.scan()
	This.fontIndex:=This.preferIndex("Arial")
	If (This.fontIndex<0)
		This.fontIndex:=0
	End if 

	This.faceIndex:=0
	This.fontPathOverride:=""
	This.text:="AV Office"
	This.fontSize:=10
	This.units:="mm"
	This.showGuides:=True
	This.zoom:=1
	This.logLines:=New collection
	This.exactSvg:=""
	This.annotatedSvg:=""
	This.status:="ready"
	This.errorCode:=""
	This.errorMessage:=""
	This.errorHint:=""
	This.elapsedMs:=0
	This.cliVersion:=This.readVersion()

Function readVersion() : Text
	var $version : Object
	var $label : Text

	$label:="?"
	$version:=This.outline.version()
	If ($version#Null)
		If ($version.value#Null)
			$label:=String($version.value.version)
		End if 
	End if 
	return $label

// ------------------------------------------------- helper functions

Function minOf($a : Real; $b : Real) : Real
	var $r : Real
	$r:=$b
	If ($a<$b)
		$r:=$a
	End if 
	return $r

Function maxOf($a : Real; $b : Real) : Real
	var $r : Real
	$r:=$b
	If ($a>$b)
		$r:=$a
	End if 
	return $r

// Numbers for SVG attributes and for the read-only panels.
//
// Two traps, both observed in tool4d 21R4 on a Japanese macOS host:
//   * String(value; "0.#####") returns "<<<<<<<" for any value with two or more
//     integer digits, so the format string cannot be used here at all;
//   * String(value) formats with the *host locale* decimal separator, which
//     would corrupt every SVG attribute on a comma-decimal system.
// So: take the plain string, normalise the separator, trim trailing zeros.
Function num($value : Real) : Text
	var $text : Text
	var $separator : Text

	If ($value=0)
		$value:=0 // never print "-0"
	End if 
	$text:=String($value)
	$separator:="."
	If (Position(","; String(1.5))>0)
		$separator:=","
	End if 
	If ($separator#".")
		$text:=Replace string($text; $separator; "."; *)
	End if 
	If (Position("."; $text)>0)
		While (Substring($text; Length($text); 1)="0")
			$text:=Substring($text; 1; Length($text)-1)
		End while 
		If (Substring($text; Length($text); 1)=".")
			$text:=Substring($text; 1; Length($text)-1)
		End if 
	End if 
	return $text

// Wrap a value in double quotes, so no string literal has to end with an
// escaped quote: that combination cannot be continued onto the next line.
Function q($value : Text) : Text
	return Char(34)+$value+Char(34)

Function pad($label : Text) : Text
	var $padded : Text

	$padded:=$label
	While (Length($padded)<14)
		$padded:=$padded+" "
	End while 
	return $padded

// --------------------------------------------------------------- font access

Function font() : Object
	var $font : Object

	$font:=Null
	If ((This.fontIndex>=0) && (This.fontIndex<This.fonts.length))
		$font:=This.fonts[This.fontIndex]
	End if 
	return $font

// Base name of the file actually shipped to the shaper, for labels and logs.
Function fontFileName() : Text
	var $path : Text
	var $name : Text

	// fontPath() is a platform path ("Macintosh HD:System:..."), so let 4D name
	// the file rather than splitting on a separator that is not "/".
	var $file : 4D.File

	$path:=This.fontPath()
	$name:=$path
	If ($path#"")
		Try
			$file:=File($path; fk platform path)
			$name:=$file.name
		Catch
			$name:=$path
		End try 
	End if 
	return $name

Function fontPath() : Text
	var $font : Object
	var $path : Text

	$path:=""
	If (This.fontPathOverride#"")
		$path:=This.fontPathOverride
	Else 
		$font:=This.font()
		If ($font#Null)
			$path:=String($font.platformPath)
		End if 
	End if 
	return $path

Function preferIndex($needle : Text) : Integer
	var $i : Integer
	var $found : Integer

	$found:=-1
	If ($needle#"")
		For ($i; 0; This.fonts.length-1)
			If (($found<0) && (Position($needle; This.fonts[$i].name; *)>0))
				$found:=$i
			End if 
		End for 
	End if 
	return $found

Function selectFont($index : Integer)
	If (($index>=0) && ($index<This.fonts.length))
		This.fontIndex:=$index
		This.fontPathOverride:=""
	End if 

// --------------------------------------------------------------- conversion

Function convert() : Object
	var $request : Object
	var $start : Integer

	$request:=New object(\
		"fontFile"; This.fontPath(); \
		"text"; This.text; \
		"fontSize"; This.fontSize; \
		"units"; This.units; \
		"faceIndex"; This.faceIndex)

	$start:=Milliseconds
	Try
		This.result:=This.outline.convert($request)
	Catch
		This.result:=New object("ok"; False; "exitCode"; -1; "error"; \
			New object("code"; "host_exception"; "message"; "the component call raised a 4D error"))
	End try 
	This.elapsedMs:=Milliseconds-$start
	If (This.elapsedMs<0)
		This.elapsedMs:=0
	End if 

	This.interpret()
	This.buildGuides()
	This.renderPreview()
	This.appendLog()
	return This.result

Function interpret()
	This.metrics:=Null
	This.exactSvg:=""
	This.errorCode:=""
	This.errorMessage:=""
	This.errorHint:=""
	This.status:=""
	This.annotatedSvg:=""

	If (This.result=Null)
		This.errorCode:="no_result"
		This.errorMessage:="the component returned nothing"
		This.errorHint:="check that Components/Text-to-SVG.4dbase is installed"
		This.status:=This.errorCode+": "+This.errorMessage
	Else 
		If ((This.result.ok=True) && (This.result.value#Null))
			This.metrics:=This.result.value
			This.exactSvg:=String(This.metrics.svg)
			This.status:="ok · "+String(This.metrics.glyphCount)+" glyphs · "+String(This.elapsedMs)+" ms"
		Else 
			If (This.result.error#Null)
				This.errorCode:=String(This.result.error.code)
				This.errorMessage:=String(This.result.error.message)
			End if 
			If (This.errorCode="")
				This.errorCode:="malformed_response"
				This.errorMessage:="no value and no error object"
			End if 
			This.errorHint:=This.hintFor(This.errorCode)
			This.status:=This.errorCode+": "+This.errorMessage
		End if 
	End if 

Function hintFor($code : Text) : Text
	var $hint : Text

	$hint:=""
	Case of 
		: ($code="unsupported_layout")
			$hint:="The shaper accepts Latin, Greek, Cyrillic and Japanese (Han, Hiragana, Katakana) only. Arabic, Hebrew and Indic scripts are rejected before any shaping."
		: ($code="missing_glyph")
			$hint:="The font has no glyph for at least one character. Choose a font with coverage instead of expecting a silent fallback."
		: ($code="invalid_argument")
			$hint:="fontFile must be an absolute, nonempty path to a real file. A relative name such as Arial.ttf cannot resolve inside the shaper process."
		: ($code="invalid_font")
			$hint:="fontFile must be a readable regular file in a supported format; 4D aliases and virtual paths fail here, resolve them to a platform path first."
		: ($code="limit_exceeded")
			$hint:="Hard limits: font file at most 64 MiB, text at most 16384 UTF-8 bytes. Apple Color Emoji is a 192 MiB .ttc, so it cannot be used at all."
		: ($code="invalid_request")
			$hint:="fontSize must be finite, positive and at most 10000; units must be mm, pt, px or in; faceIndex must exist in the file."
		: ($code="host_exception")
			$hint:="4D raised an error around the SystemWorker call; the component never produced an envelope."
		: ($code="malformed_response")
			$hint:="The process exited but stdout was not the documented protocol."
		Else 
			$hint:="See the component's Documentation/Classes/TextOutline.md for the full contract."
	End case 
	return $hint

// ------------------------------------------------------------------ geometry

Function mmPerUnit($unit : Text) : Real
	var $mm : Real

	Case of 
		: ($unit="mm")
			$mm:=1
		: ($unit="pt")
			$mm:=25.4/72
		: ($unit="in")
			$mm:=25.4
		: ($unit="px")
			$mm:=25.4/96
		Else 
			$mm:=1
	End case 
	return $mm

// The annotated preview: glyph outlines from the component plus em box,
// baseline, advance and ink-bounds guides, all in the request's own unit.
Function buildGuides()
	var $size : Real
	var $advance : Real
	var $ink : Object
	var $left : Real
	var $right : Real
	var $top : Real
	var $bottom : Real
	var $padding : Real
	var $width : Real
	var $height : Real
	var $zoomFactor : Real
	var $viewWidth : Real
	var $viewHeight : Real
	var $viewX : Real
	var $viewY : Real
	var $scale : Real
	var $svg : Text
	var $strokeW : Text
	var $emBox : Text
	var $baseline : Text
	var $advanceLine : Text
	var $inkBox : Text
	var $glyphs : Text

	This.annotatedSvg:=""

	If (This.metrics=Null)
		return 
	End if 

	$size:=This.fontSize
	If ($size<=0)
		$size:=10
	End if 

	$advance:=0
	If (This.metrics.advance#Null)
		$advance:=Num(This.metrics.advance.x)
	End if 
	$ink:=This.metrics.inkBounds

	$left:=0
	$right:=This.maxOf($advance; 0)
	$top:=-$size
	$bottom:=0
	If ($ink#Null)
		$left:=This.minOf($left; Num($ink.x))
		$right:=This.maxOf($right; Num($ink.x)+Num($ink.width))
		$top:=This.minOf($top; Num($ink.y))
		$bottom:=This.maxOf($bottom; Num($ink.y)+Num($ink.height))
	End if 

	$padding:=$size*0.16
	$left:=$left-$padding
	$right:=$right+$padding
	$top:=$top-$padding
	$bottom:=$bottom+$padding

	$width:=$right-$left
	$height:=$bottom-$top
	If ($width<=0)
		$width:=$size
	End if 
	If ($height<=0)
		$height:=$size
	End if 

	$zoomFactor:=This.maxOf(1; This.zoom)
	$viewWidth:=$width/$zoomFactor
	$viewHeight:=$height/$zoomFactor
	$viewX:=($left+$right)/2-$viewWidth/2
	$viewY:=($top+$bottom)/2-$viewHeight/2

	// 100 device pixels per unit keeps hairlines visible when the picture is
	// scaled down by the form object; the guides never scale with the zoom.
	$scale:=100
	$strokeW:="0.4"

	$svg:="<svg version=\"1.1\" xmlns=\"http://www.w3.org/2000/svg\""
	$svg:=$svg+" width="+This.q(This.num($viewWidth*$scale)+"px")
	$svg:=$svg+" height="+This.q(This.num($viewHeight*$scale)+"px")
	$svg:=$svg+" viewBox="+This.q(This.num($viewX)+" "+This.num($viewY)+" "+This.num($viewWidth)+" "+This.num($viewHeight))+">"
	$svg:=$svg+"<rect x="+This.q(This.num($viewX))+" y="+This.q(This.num($viewY))
	$svg:=$svg+" width="+This.q(This.num($viewWidth))+" height="+This.q(This.num($viewHeight))+" fill=\"#ffffff\"/>"

	If (This.showGuides)
		$emBox:="<rect x="+This.q("0")+" y="+This.q(This.num(-$size))+" width="+This.q(This.num($right))
		$emBox:=$emBox+" height="+This.q(This.num($size))+" fill=\"none\" stroke=\"#9aa8c7\" stroke-width="+This.q($strokeW)
		$emBox:=$emBox+" stroke-dasharray=\"1 1\" vector-effect=\"non-scaling-stroke\"/>"
		$svg:=$svg+$emBox

		$baseline:="<line x1="+This.q(This.num($viewX))+" y1=\"0\" x2="+This.q(This.num($viewX+$viewWidth))
		$baseline:=$baseline+" y2=\"0\" stroke=\"#e0453d\" stroke-width="+This.q($strokeW)+" vector-effect=\"non-scaling-stroke\"/>"
		$svg:=$svg+$baseline

		$advanceLine:="<line x1="+This.q(This.num($advance))+" y1="+This.q(This.num(-$size))
		$advanceLine:=$advanceLine+" x2="+This.q(This.num($advance))+" y2=\"0\" stroke=\"#2f6fed\" stroke-width="+This.q($strokeW)
		$advanceLine:=$advanceLine+" stroke-dasharray=\"1 0.6\" vector-effect=\"non-scaling-stroke\"/>"
		$svg:=$svg+$advanceLine

		If ($ink#Null)
			$inkBox:="<rect x="+This.q(This.num(Num($ink.x)))+" y="+This.q(This.num(Num($ink.y)))
			$inkBox:=$inkBox+" width="+This.q(This.num(Num($ink.width)))+" height="+This.q(This.num(Num($ink.height)))
			$inkBox:=$inkBox+" fill=\"none\" stroke=\"#1a9c5b\" stroke-width="+This.q($strokeW)+" vector-effect=\"non-scaling-stroke\"/>"
			$svg:=$svg+$inkBox
		End if 
	End if 

	If (This.metrics.pathData#Null)
		$glyphs:="<path fill-rule=\"nonzero\" fill=\"#14181f\" d="+This.q(String(This.metrics.pathData))+" />"
		$svg:=$svg+$glyphs
	End if 
	$svg:=$svg+"</svg>"
	This.annotatedSvg:=$svg



// SVG text -> 4D picture. The SVG engine keeps the content vector, so the same
// picture stays sharp at every size the form object is scaled to.
Function renderPreview()
	var $dom : Text
	var $picture : Picture
	var $svg : Text

	This.preview:=Null
	If (This.annotatedSvg#"")
		Try
			// DOM Parse XML variable needs a real variable: passing the property
			// path This.annotatedSvg raises error 59 and silently yields "".
			$svg:=This.annotatedSvg
			$dom:=DOM Parse XML variable($svg)
			If (Length($dom)>0)
				SVG EXPORT TO PICTURE($dom; $picture)
				DOM CLOSE XML($dom)
				If ($picture#Null)
					This.preview:=$picture
				End if 
			End if 
		Catch
			This.preview:=Null
		End try 
	End if 

// ---------------------------------------------------------------- reporting

Function metricsText() : Text
	var $lines : Collection
	var $font : Object
	var $fontName : Text
	var $characters : Integer
	var $advance : Real
	var $ink : Object
	var $inkWidth : Real
	var $inkHeight : Real
	var $factor : Real
	var $text : Text

	$lines:=New collection
	$font:=This.font()
	$fontName:="(none)"
	If ($font#Null)
		$fontName:=String($font.name)
	End if 

	If (This.metrics=Null)
		$lines.push(This.pad("STATUS")+This.errorCode)
		$lines.push(This.pad("MESSAGE")+This.errorMessage)
		If (This.errorHint#"")
			$lines.push(This.pad("WHY")+This.errorHint)
		End if 
		$lines.push(This.pad("REQUEST")+"fontSize "+This.num(This.fontSize)+" "+This.units+" · face "+String(This.faceIndex)\
			+" · "+String(Length(This.text))+" text units")
		$lines.push(This.pad("FONT")+$fontName)
		$lines.push(This.pad("FONT PATH")+This.fontPath())
		$text:=$lines.join(Char(13))
	Else 
		$characters:=Length(This.text)
		$advance:=0
		If (This.metrics.advance#Null)
			$advance:=Num(This.metrics.advance.x)
		End if 
		$ink:=This.metrics.inkBounds
		$inkWidth:=0
		$inkHeight:=0

		$lines.push(This.pad("TEXT")+"\""+This.text+"\"")
		$lines.push(This.pad("CHARACTERS")+String($characters)+" UTF-16 units · "+String(This.metrics.glyphCount)+" shaped glyphs")
		$lines.push(This.pad("FONT")+$fontName+"  face "+String(This.faceIndex)+"  ("+String(This.fonts.length)+" fonts scanned)")
		$lines.push(This.pad("FONT PATH")+This.fontPath())
		$lines.push(This.pad("SIZE")+This.num(This.fontSize)+" "+This.units+" per em · y grows downward, ascenders are negative")

		If ($ink#Null)
			$inkWidth:=Num($ink.width)
			$inkHeight:=Num($ink.height)
			$lines.push(This.pad("ADVANCE")+This.num($advance)+" "+This.units+"   (pen movement, side bearings included)")
			$lines.push(This.pad("INK BOUNDS")+"x "+This.num(Num($ink.x))+" · y "+This.num(Num($ink.y))+" · w "+This.num($inkWidth)\
				+" · h "+This.num($inkHeight)+" "+This.units)
			$lines.push(This.pad("INK vs ADVANCE")+"ink ends at "+This.num(Num($ink.x)+$inkWidth)+", so "+This.num($advance-$inkWidth)\
				+" "+This.units+" of the advance is white space")
		Else 
			$lines.push(This.pad("ADVANCE")+"0 "+This.units)
			$lines.push(This.pad("INK BOUNDS")+"null -- the text produced no ink")
		End if 

		$factor:=This.mmPerUnit(This.units)
		$lines.push(This.pad("PHYSICAL")+This.num($inkWidth*$factor)+" × "+This.num($inkHeight*$factor)+" mm of ink at this size")
		$lines.push(This.pad("SVG")+String(Length(This.exactSvg))+" bytes of outlined SVG · conversion "+String(This.elapsedMs)\
			+" ms · protocol 1")
		$lines.push(This.pad("GUIDES")+"grey dashed = em box · red = baseline · blue dashed = advance · green = ink bounds")
		$text:=$lines.join(Char(13))
	End if 
	return $text

Function headline() : Text
	var $line : Text

	$line:="Text-to-SVG "+This.cliVersion+" · "+This.target
	If (This.metrics#Null)
		$line:=$line+" · "+String(This.metrics.glyphCount)+" glyphs · "+This.num(This.fontSize)+" "+This.units
	Else 
		$line:=$line+" · "+This.errorCode+" · exit "+String(This.result.exitCode)
	End if 
	return $line

Function logText() : Text
	return This.logLines.join(Char(13))

Function appendLog()
	var $line : Text

	$line:=Time string(Current time)+"  "
	If (This.metrics#Null)
		$line:=$line+"ok    "+String(This.metrics.glyphCount)+" glyphs  ·  "+String(This.elapsedMs)+" ms"
	Else 
		$line:=$line+"fail  "+This.errorCode+"  ·  "+String(This.elapsedMs)+" ms"
	End if 
	This.logLines.insert(0; $line)
	While (This.logLines.length>10)
		This.logLines.pop()
	End while 

// ------------------------------------------------------------ unit comparison

Function compareUnits() : Text
	var $request : Object
	var $response : Object
	var $ink : Object
	var $unitList : Collection
	var $mm : Real
	var $out : Text
	var $line : Text
	var $first : Text
	var $unit : Text
	var $same : Boolean

	// The point of this table: `units` is a *label*, not a scale. The numerals
	// inside pathData, advance and inkBounds are byte-identical for every unit;
	// only the unit suffix of the generated <svg> width/height changes. So
	// "10 pt" and "10 mm" are the same drawing, physically 72 dpi apart.
	$unitList:=New collection("mm"; "pt"; "px"; "in")
	$out:="fontSize 10 in every unit, same font and text."+Char(13)
	$out:=$out+"The geometry never changes: units only relabel the SVG."+Char(13)+Char(13)
	$out:=$out+"UNIT   INK WIDTH   HEIGHT     ADVANCE    1 UNIT =   SVG SUFFIX"+Char(13)

	$first:=""
	For each ($unit; $unitList)
		$request:=New object("fontFile"; This.fontPath(); "text"; "AV Office"; "fontSize"; 10; "units"; $unit; "faceIndex"; This.faceIndex)
		Try
			$response:=This.outline.convert($request)
		Catch
			$response:=Null
		End try 
		If (($response#Null) && ($response.ok=True) && ($response.value#Null))
			$ink:=$response.value.inkBounds
			$mm:=This.mmPerUnit($unit)
			$line:=$unit+"   "+This.num(Num($ink.width))+"   "+This.num(Num($ink.height))
			$line:=$line+"   "+This.num(Num($response.value.advance.x))
			$line:=$line+"   "+This.num($mm)+" mm"
			$out:=$out+$line+Char(13)
		Else 
			$out:=$out+$unit+"   error"+Char(13)
		End if 
	End for each 

	$same:=(Position("<svg"; This.exactSvg)>0)
	If ($same)
		$out:=$out+Char(13)+"The host still reports "+This.units+" because the last request in the table was in "+This.units+"."
	End if 
	return $out

// ----------------------------------------------------------------- SVG files

Function annotatedFile($folder : 4D.Folder) : 4D.File
	var $file : 4D.File

	$file:=$folder.file("text-to-svg-preview.svg")
	$file.setText(This.annotatedSvg)
	return $file

Function exactFile($folder : 4D.Folder) : 4D.File
	var $file : 4D.File

	$file:=$folder.file("text-to-svg-outlines.svg")
	$file.setText(This.exactSvg)
	return $file

// ------------------------------------------------------------------ presets

Function presets() : Collection
	var $list : Collection

	$list:=New collection
	$list.push(New object("title"; "Latin · AV Office"; "text"; "AV Office"; "size"; 10; "units"; "mm"; "face"; 0; "font"; "Arial"; \
		"note"; "the reference case: 9 glyphs, the advance is wider than the ink"))
	$list.push(New object("title"; "Ligature · office"; "text"; "office"; "size"; 10; "units"; "mm"; "face"; 0; "font"; "HelveticaNeue"; \
		"note"; "6 characters, 4 glyphs: the shaper applies the ffi ligature"))
	$list.push(New object("title"; "Ligature · ﬁle"; "text"; "ﬁle"; "size"; 10; "units"; "mm"; "face"; 0; "font"; "HelveticaNeue"; \
		"note"; "the fl ligature is already one character in the text"))
	$list.push(New object("title"; "CJK · 日本語"; "text"; "日本語"; "size"; 10; "units"; "mm"; "face"; 0; "font"; "Hiragino Sans"; \
		"note"; "Japanese is supported; the font must carry the glyphs"))
	$list.push(New object("title"; "RTL · مرحبا"; "text"; "مرحبا"; "size"; 10; "units"; "mm"; "face"; 0; "font"; "Arial"; \
		"note"; "rejected: unsupported_layout, there is no bidi shaping"))
	$list.push(New object("title"; "Emoji font"; "text"; "Hi"; "size"; 10; "units"; "mm"; "face"; 0; "font"; "Apple Color Emoji"; \
		"note"; "rejected: limit_exceeded, the .ttc is 192 MiB"))
	$list.push(New object("title"; "Missing glyph"; "text"; "日本語"; "size"; 10; "units"; "mm"; "face"; 0; "font"; "Arial"; \
		"note"; "rejected: missing_glyph, Arial has no CJK coverage"))
	$list.push(New object("title"; "Empty text"; "text"; ""; "size"; 10; "units"; "mm"; "face"; 0; "font"; "Arial"; \
		"note"; "accepted: inkBounds null, advance 0, glyphCount 0"))
	$list.push(New object("title"; "Bad font path"; "text"; "Hi"; "size"; 10; "units"; "mm"; "face"; 0; "font"; ""; \
		"path"; "not-a-font.ttf"; "note"; "rejected: invalid_font, a relative path never resolves"))
	return $list

Function applyPreset($index : Integer)
	var $list : Collection
	var $preset : Object
	var $found : Integer

	$list:=This.presets()
	If (($index>=0) && ($index<$list.length))
		$preset:=$list[$index]

		This.text:=String($preset.text)
		This.fontSize:=$preset.size
		This.units:=String($preset.units)
		This.faceIndex:=$preset.face
		This.zoom:=1
		This.fontPathOverride:=""

		If ($preset.path#Null)
			This.fontPathOverride:=String($preset.path)
		Else 
			$found:=This.preferIndex(String($preset.font))
			If ($found>=0)
				This.fontIndex:=$found
			End if 
		End if 

		This.convert()
	End if 
