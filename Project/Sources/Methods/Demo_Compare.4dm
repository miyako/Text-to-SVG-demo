// Demo_Compare -- four component calls, one per supported unit, with the same
// numerals. Shows that fontSize is expressed *in* the requested unit.

var $lab : cs.OutlineLab
$lab:=Form.lab
If ($lab=Null)
	return 
End if 

Form.panelTitle:="UNIT LADDER — fontSize 10 in mm, pt, px and in"
Form.svgText:=$lab.compareUnits()
