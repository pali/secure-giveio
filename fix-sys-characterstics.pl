#!/usr/bin/perl
# (c) 2022 Pali Rohár <pali@kernel.org>, GPLv2+

use 5.00800;
BEGIN { $^H = 0x6F2 } # use strict
BEGIN { $^W = 1 } # use warnings

my $file = $ARGV[0];
die "$0: File argument was not specified\n" unless defined $file and length $file;
die "$0: Too many arguments\n" unless @ARGV == 1;
open my $fh, '+<', $file or die "$file: Cannot open file: $!\n";

sysread $fh, (my $mz_sig = ''), 2 or die "$file: Cannot read MZ signature: $!\n";
die "$file: File does not have MZ signature\n" unless $mz_sig eq 'MZ'; # IMAGE_DOS_SIGNATURE

sysseek $fh, 0x3C, 0 or die "$file: Cannot seek to NEW offset: $!\n";
sysread $fh, (my $pe_offset = ''), 2 or die "$file: Cannot read PE offset: $!\n";
$pe_offset = unpack 'v', $pe_offset;

sysseek $fh, $pe_offset, 0 or die "$file: Cannot seek to PE signature offset: $!\n";
sysread $fh, (my $pe_sig = ''), 4 or die "$file: Cannot read PE signature: $!\n";
die "$file: File does not have PE signature\n" unless $pe_sig eq "PE\x00\x00"; # IMAGE_NT_SIGNATURE

sysread $fh, (my $coff_sig = ''), 2 or die "$file: Cannot read COFF signature: $!\n";
die "$file: File has unknown COFF signature\n" unless $coff_sig eq "\x4c\x01" or $coff_sig eq "\x64\x86"; # IMAGE_FILE_MACHINE_I386 or IMAGE_FILE_MACHINE_AMD64

sysread $fh, (my $sections = ''), 2 or die "$file: Cannot read COFF sections: $!\n";
$sections = unpack 'v', $sections;

sysseek $fh, 12, 1 or die "$file: Cannot seek to COFF opt header size offset: $!\n";
sysread $fh, (my $opthdrsize = ''), 2 or die "$file: Cannot read COFF opt header size: $!\n";
$opthdrsize = unpack 'v', $opthdrsize;
die "$file: File does not have valid COFF opt header\n" unless $opthdrsize >= 72;

sysread $fh, (my $coff_characteristics = ''), 2 or die "$file: Cannot read COFF characteristics: $!\n";
$coff_characteristics = unpack 'v', $coff_characteristics;
die "$file: File is not relocable\n" if $coff_characteristics & 0x0001; # IMAGE_FILE_RELOCS_STRIPPED
die "$file: File is not executable image\n" unless $coff_characteristics & 0x0002; # IMAGE_FILE_EXECUTABLE_IMAGE
die "$file: File is DLL library\n" if $coff_characteristics & 0x2000; # IMAGE_FILE_DLL

sysread $fh, (my $opthdr_sig = ''), 2 or die "$file: Cannot read COFF opt header signature: $!\n";
die "$file: File does not have NT COFF opt header signature\n" unless $opthdr_sig eq "\x0b\x01" or $opthdr_sig eq "\x0b\x02"; # IMAGE_NT_OPTIONAL_HDR32_MAGIC or IMAGE_NT_OPTIONAL_HDR64_MAGIC

sysseek $fh, 68-2, 1 or die "$file: Cannot seek to NT COFF opt header subsystem: $!\n";
sysread $fh, (my $subsystem = ''), 2 or die "$file: Cannot read COFF opt header subsystem: $!\n";
die "$file: File is not Native sys driver\n" unless $subsystem eq "\x01\x00"; # IMAGE_SUBSYSTEM_NATIVE

sysseek $fh, $opthdrsize-68-2, 1 or die "$file: Cannot seek to first COFF section: $!\n";

while ($sections-- > 0) {
	sysread $fh, (my $name = ''), 8 or die "$file: Cannot read COFF section name: $!\n";
	$name =~ s/\x00+$//;

	sysseek $fh, 7*4, 1 or die "$file: Cannot seek to COFF section $name characteristics offset: $!\n";
	sysread $fh, (my $characteristics = ''), 4 or die "$file: Cannot read COFF section $name characteristics: $!\n";
	$characteristics = unpack 'V', $characteristics;
	my $orig_characteristics = $characteristics;

	if ($characteristics & 0x00F00000) { # IMAGE_SCN_ALIGN_MASK
		print "$file: Removing nonsense mem alignment characteristics in COFF section $name\n";
		$characteristics &= ~0x00F00000; # IMAGE_SCN_ALIGN_MASK
	}

	if (($characteristics & 0x00000020) and ($characteristics & 0x00000040)) { # IMAGE_SCN_CNT_CODE and IMAGE_SCN_CNT_INITIALIZED_DATA
		print "$file: Removing nonsense data characteristics for executable code in COFF section $name\n";
		$characteristics &= ~0x00000040; # IMAGE_SCN_CNT_INITIALIZED_DATA
	}

	if ($name eq '.rsrc' and ($characteristics & 0x80000000)) { # IMAGE_SCN_MEM_WRITE
		print "$file: Removing nonsense mem writable characteristics for read-only resources in COFF section $name\n";
		$characteristics &= ~0x80000000; # IMAGE_SCN_MEM_WRITE
	}

	if (($name eq '.idata' or $name eq 'INIT' or $name eq '.rsrc') and not ($characteristics & 0x02000000)) { # IMAGE_SCN_MEM_DISCARDABLE
		print "$file: Adding missing mem discardable characteristics in COFF section $name\n";
		$characteristics |= 0x02000000; # IMAGE_SCN_MEM_DISCARDABLE
	}

	if (not ($characteristics & 0x08000000) and not ($characteristics & 0x02000000)) { # IMAGE_SCN_MEM_NOT_PAGED and IMAGE_SCN_MEM_DISCARDABLE
		if ($name ne 'PAGE' and $name ne '.rsrc' and $name ne '.edata' and $name ne '.reloc') {
			print "$file: Adding missing mem non-paged characteristics in COFF section $name\n";
			$characteristics |= 0x08000000; # IMAGE_SCN_MEM_NOT_PAGED
		}
	}

	if ($orig_characteristics != $characteristics) {
		sysseek $fh, -4, 1 or die "$file: Cannot seek to COFF section $name characteristics: $!\n";
		syswrite $fh, (pack 'V', $characteristics), 4 or die "$file: Cannot update COFF section $name characteristics: $!\n";
	}
}

close $fh;
