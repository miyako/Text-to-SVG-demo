// Demo_Compare -- four component calls, one per supported unit, with the same
// numerals. Shows that `units` is only a label: the geometry is identical in all four.

var $lab : cs.OutlineLab
$lab:=Form.lab
If ($lab=Null)
	return 
End if 

Form.panelTitle:="UNIT LADDER — fontSize 10 in mm, pt, px and in"
Form.svgText:=$lab.compareUnits()
