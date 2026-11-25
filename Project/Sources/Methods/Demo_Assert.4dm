// Demo_Assert -- append one row to the evidence collection.
// Kept as a method (not a class) so Demo_SelfTest stays a readable list of
// cases: every row carries its own expected/actual detail string.

#DECLARE($checks : Collection; $name : Text; $passed : Boolean; $detail : Text)

If ($checks=Null)
	return 
End if 

$checks.push(New object("check"; $name; "passed"; $passed; "detail"; $detail))
