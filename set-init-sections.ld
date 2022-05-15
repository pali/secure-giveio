SECTIONS
{
	/* Put .idata, INIT and .rsrc sections at the end as those are discardable like .reloc section */
	.idata BLOCK(__section_alignment__) :
	{
		*(.idata)
	}
	INIT BLOCK(__section_alignment__) :
	{
		*(INIT)
	}
	.rsrc BLOCK(__section_alignment__) :
	{
		*(.rsrc)
	}
}
/* GCC puts .reloc section at the end */
INSERT BEFORE .reloc;
