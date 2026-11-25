// FontScanner -- discovers the font files the demo can hand to Text-to-SVG.
//
// The component takes a font *file*, not a family name, so the demo has to
// offer real files. The scan is shallow (two levels) and limited to the
// extensions the shaper can open; .ttc collections are kept because they carry
// the faceIndex dimension of the API.

property fonts : Collection

Class constructor()
	This.fonts:=New collection

Function scan() : Collection
	var $roots : Collection
	var $seen : Object
	var $root : Text
	var $folder : 4D.Folder

	This.fonts:=New collection
	$seen:=New object
	$roots:=This.folders()
	For each ($root; $roots)
		$folder:=Folder($root; fk posix path)
		If ($folder.exists)
			This.collectInto($folder; This.fonts; $seen; 0)
		End if 
	End for each 
	This.fonts:=This.fonts.orderBy("name asc")
	return This.fonts

// Font folders of the current platform, as POSIX paths.
Function folders() : Collection
	var $roots : Collection

	$roots:=New collection
	If (Is Windows)
		// Per-user fonts live in %LOCALAPPDATA%\Microsoft\Windows\Fonts, but 4D
		// has no language-level way to read an environment variable, so only the
		// machine-wide folder is scanned. Documented in README.
		$roots.push(Folder(fk system folder).parent.path+"/Fonts")
	Else 
		$roots.push("/System/Library/Fonts")
		$roots.push("/System/Library/Fonts/Supplemental")
		$roots.push("/Library/Fonts")
		$roots.push(Folder(fk home folder).path+"/Library/Fonts")
	End if 
	return $roots

Function collectInto($folder : 4D.Folder; $found : Collection; $seen : Object; $depth : Integer)
	var $files : Collection
	var $subFolders : Collection
	var $extension : Text
	var $file : 4D.File
	var $subFolder : 4D.Folder

	If ($depth<=2)
		$files:=$folder.files()
		For each ($file; $files)
			// 4D.File.extension includes the leading dot (".ttc"), so normalise
			// once here instead of comparing stripped names everywhere.
			$extension:=Lowercase(String($file.extension))
			If (($extension=".ttf") || ($extension=".otf") || ($extension=".ttc"))
				If ($seen[$file.name]=Null)
					$seen[$file.name]:=True
					$found.push(New object(\
						"name"; $file.name; \
						"path"; $file.path; \
						"platformPath"; $file.platformPath; \
						"folder"; $folder.path; \
						"collection"; ($extension=".ttc")))
				End if 
			End if 
		End for each 

		$subFolders:=$folder.folders()
		For each ($subFolder; $subFolders)
			This.collectInto($subFolder; $found; $seen; $depth+1)
		End for each 
	End if 
