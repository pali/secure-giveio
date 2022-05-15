# Default CFLAGS. Enable warnings, size optimizations and stripping of extra symbols.
CFLAGS = -Wall -Wextra -Os -s

# Default CPPFLAGS. None.
CPPFLAGS =

# Default LDFLAGS. GCC generate lot of unused sections and symbols. Drop them in default LDFLAGS.
LDFLAGS = -Wl,--gc-sections

# MinGW-w64 version before 7.0.0 for AMD64 has bug in wdm.h file (included by ntddk.h file) and
# ntddk.h file cannot be included if macro __INTRINSIC_DEFINED__InterlockedAdd64 is not defined.
MINGWCPPFLAGS = $(if $(shell printf "\#if defined(_M_AMD64) && defined(__MINGW64_VERSION_MAJOR) && __MINGW64_VERSION_MAJOR < 7\n\#error\n\#endif\n" | $(CC) -E -include windows.h -o /dev/null - 2>&1),-D__INTRINSIC_DEFINED__InterlockedAdd64)

# GCC does not support __declspec(code_seg("segname")) declarator. Instead it supports different
# syntax: __attribute__((section("segname"))) or __declspec(section("segname")). Fix support for
# __declspec(code_seg("segname")) via preprocessor macro code_seg.
GCCCPPFLAGS = -D"code_seg(segname)=section(segname)"

# GCC does not include DDK include directory by default. It is subdirectory of default MinGW
# include directory, so include all /ddk/ subdirectories.
DDKCPPFLAGS = $(shell $(CC) $(CPPFLAGS) $(CFLAGS) -E -Wp,-v -o /dev/null - 2>&1 </dev/null | sed -n 's/^ \(.*\)/-I\1\/ddk/p')

# NT sys drivers are just ordinary native NT executables.
NATIVELDFLAGS = -Wl,--subsystem,native

# Disable usage of MinGW runtime auto import support and do not use GCC or MinGW standard lib
# and startup files. NT sys drivers have own entry point and also own standard library.
NOCRTLDFLAGS = -nostartfiles -nodefaultlibs -nostdlib -Wl,--disable-auto-import -Wl,--disable-stdcall-fixup

# GCC by default does not create PE executable with relocation info. This is required for
# native NT executables (which are also NT sys drivers). GNU LD's --dynamicbase should do it
# but is broken. Relocation info for PE executables can be generated only by GCC's -pie as
# resulted file needs to be executable and not DLL library.
RELOCLDFLAGS = -pie -Wl,--dynamicbase -Wl,--nxcompat

# GCC's -pie is broken and it automatically generates export symbol table. But NT sys driver
# does not export any symbols (for this purpose there are NT sys DLL libraries), so it should
# not have any export table. GNU LD's --exclude-all-symbols is also broken, it cause generation
# of empty export table and puts name of the output executable/driver as name of the library
# which is another nonsense. Use custom linker script exclude-export-table.ld to _really_
# exclude export table from final executable binary as -pie and --exclude-all-symbols are broken.
NOEXPORTLDFLAGS = -Wl,--exclude-all-symbols -T exclude-export-table.ld

# Set layout for NT sys drivers with default values. Because GNU's LD is broken and put discardable
# init sections in the middle of the PE binary, use linker script set-init-sections.ld to put
# all discardable sections (which are not loaded at runtime) at the end of the binary.
SYSSECLDFLAGS = -Wl,--image-base,0x10000 -Wl,--stack,0x40000 -Wl,--section-alignment,0x1000 -Wl,--file-alignment,0x200 -T set-init-sections.ld

# Entry point for NT sys driver is always function DriverEntry(). Due to symbol mangling,
# entry point symbol on IX86 is _DriverEntry@8 and on AMD64 is DriverEntry. To avoid adding
# Makefile ifdef based on compilation flags or target, define entry point via linker script
# set-driver-entry.ld which do it correctly based on defined symbol.
SYSENTRYLDFLAGS = -T set-driver-entry.ld

# All NT sys drivers have to be linked with ntoskrnl.exe which contains common driver functions.
SYSLIBS = -lntoskrnl

# Compile NT sys driver via GCC and then call fixup script. GCC and GNU's LD are broken
# and put lot of nonsense characteristics into PE executable which are fully unsuitable
# for NT sys drivers. Fixup script should modify and fix final PE executable to not
# contain GCC's nonsense data.
.SUFFIXES: .sys .c
.c.sys:
	$(CC) $(CFLAGS) $(CPPFLAGS) $(MINGWCPPFLAGS) $(GCCCPPFLAGS) $(DDKCPPFLAGS) $(LDFLAGS) $(NATIVELDFLAGS) $(NOCRTLDFLAGS) $(RELOCLDFLAGS) $(NOEXPORTLDFLAGS) $(SYSSECLDFLAGS) $(SYSENTRYLDFLAGS) -o $@ $< $(SYSLIBS)
	perl fix-sys-characterstics.pl $@ || { rm -f $@; false; }


giveio.sys: giveio.c

clean:
	$(RM) giveio.sys
