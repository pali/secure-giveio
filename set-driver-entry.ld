/* Entry point is always function DriverEntry() */
ENTRY(DriverEntry)

SECTIONS
{
	/* On IX86 function DriverEntry() has symbol name _DriverEntry@8 */
	ASSERT(DEFINED("_DriverEntry@8") || DEFINED(DriverEntry), "Error: Function DriverEntry() was not defined")
	DriverEntry = DEFINED("_DriverEntry@8") ? "_DriverEntry@8" : DriverEntry;
}
/* INSERT command is required to not override default linker script */
INSERT BEFORE .reloc;
