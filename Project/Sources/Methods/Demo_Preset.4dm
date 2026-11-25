// Demo_Preset -- apply a named preset (text, size, unit, face, font) and run it.
// The preset table lives in the model so the form does not duplicate it.

#DECLARE($index : Integer)

var $lab : cs.OutlineLab
$lab:=Form.lab
If ($lab=Null)
	return 
End if 

$lab.applyPreset($index)
Demo_Sync
