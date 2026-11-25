// Demo_Refresh -- run the component once and push every derived value into the
// form. Every data-changing object method ends here.

var $lab : cs.OutlineLab
$lab:=Form.lab
If ($lab=Null)
	return 
End if 

$lab.convert()
Demo_Sync
