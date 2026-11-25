// Demo_Sync -- copy the model state into the form's data sources.
//
// Form fields are plain values (text, collections of text), never the model
// object itself, so the control contents stay inspectable in the debugger.

var $lab : cs.OutlineLab
$lab:=Form.lab
If ($lab=Null)
	return 
End if 

Form.versionText:="component "+$lab.cliVersion+" · "+$lab.target+" · protocol 1"
Form.statusText:=$lab.headline()
Form.metricsText:=$lab.metricsText()
Form.logText:=$lab.logText()
Form.fontPathText:=$lab.fontPath()
Form.faceHint:="face "+String($lab.faceIndex)+" inside the file"
Form.sizeHint:="unit label only: "+$lab.units+" (numbers never rescale)"
Form.legend:="grey dashed = em box · red = baseline · blue dashed = advance · green = ink bounds · click the canvas to zoom"
Form.panelTitle:="RAW COMPONENT OUTPUT — value.svg ("+String(Length($lab.exactSvg))+" bytes)"
Form.svgText:=$lab.exactSvg

If ($lab.metrics=Null)
	Form.errorText:="FAIL "+$lab.errorCode+" · exit "+String($lab.result.exitCode)+" · "+String($lab.elapsedMs)+" ms"+Char(13)\
		+$lab.errorMessage+Char(13)+Char(13)+$lab.errorHint
Else 
	Form.errorText:="OK · exit "+String($lab.result.exitCode)+" · "+String($lab.elapsedMs)+" ms"+Char(13)\
		+"No error. Change a parameter, or pick a preset that is known to fail, to see the error envelope."
End if 

If (Form.fontDrop#Null)
	Form.fontDrop.index:=$lab.fontIndex
End if 
