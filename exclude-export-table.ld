SECTIONS
{
	/* GCC puts Export Table into .edata section, so discard it */
	/DISCARD/ :
	{
		*(.edata)
	}
}
/* INSERT command is required to not override default linker script */
INSERT BEFORE .reloc;
