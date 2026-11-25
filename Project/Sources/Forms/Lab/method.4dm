// Lab form method.
//
// The model is built by Demo_Start *before* the form loads: a picture data
// source has to hold a real image the first time the picture input draws, so
// the first conversion cannot wait for On Load.

Case of 
	: (FORM Event.code=On Load)
		If (Form.lab=Null)
			Form.lab:=cs.OutlineLab.new()
			Form.lab.convert()
		End if 
		If (Form.fontDrop=Null)
			Form.fontDrop:=New object(\
				"values"; Form.lab.fonts.extract("name"); \
				"index"; Form.lab.fontIndex; \
				"currentValue"; "")
		End if 
		Demo_Sync

	: (FORM Event.code=On Unload)
		// Nothing to release: the model is a shared object owned by the caller.
		// The component instance frees its SystemWorker with the object.

End case 
