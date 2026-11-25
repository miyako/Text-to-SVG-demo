// The drop-down is object-based: 4D writes the selection back into
// Form.fontDrop.index, so the model only has to follow it.
If (Form.lab#Null)
	Form.lab.selectFont(Form.fontDrop.index)
	Demo_Refresh
End if 
