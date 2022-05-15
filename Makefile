# Default CFLAGS. Enable warnings and size optimizations.
CFLAGS = /W4 /O1

# Default CPPFLAGS. Disable asserts.
CPPFLAGS = /DNDEBUG

# Default LDFLAGS. Disable expected warnings and enable optimizations.
LDFLAGS = /OPT:REF /OPT:ICF /INCREMENTAL:NO /IGNORE:4010,4078

# Set platform specific CPPFLAGS and expand DDK_LIB_PATH
!if "$(_BUILDARCH)" == "AMD64"
MSVCCPPFLAGS = /D_AMD64_
DDK_LIB_PATH = $(DDK_LIB_PATH:*=amd64)
!else
MSVCCPPFLAGS = /D_X86_ /DSTD_CALL /Gz
DDK_LIB_PATH = $(DDK_LIB_PATH:*=i386)
!endif

# MSVC does not include DDK include directory by default.
DDKCPPFLAGS = /I$(SDK_INC_PATH) /I$(CRT_INC_PATH) /I$(DDK_INC_PATH)

# NT sys drivers are just ordinary native NT executables.
NATIVELDFLAGS = /SUBSYSTEM:native,4.00 /DRIVER

# Do not use MSVC standard lib and startup files.
# NT sys drivers have own entry point and also own standard library.
NOCRTLDFLAGS = /NODEFAULTLIB /SAFESEH:NO /MANIFEST:NO

# Set layout for NT sys drivers with default values.
SYSSECLDFLAGS = /BASE:0x10000 /STACK:0x40000,0x1000 /ALIGN:0x1000 /FILEALIGN:0x200 /MERGE:_PAGE=PAGE /MERGE:_TEXT=.text /SECTION:INIT,D

# Entry point for NT sys driver is always function DriverEntry().
SYSENTRYLDFLAGS = /ENTRY:DriverEntry

# All NT sys drivers have to be linked with ntoskrnl.exe which contains common driver functions.
# MSVC cannot find its import library automatically, so full path is required.
SYSLIBS = $(DDK_LIB_PATH)\ntoskrnl.lib

# Compile NT sys driver via MSVC cl and link.
.SUFFIXES: .sys .c
.c.sys:
	cl /nologo $(CFLAGS) $(CPPFLAGS) $(MSVCCPPFLAGS) $(DDKCPPFLAGS) /Fe$@ $< /link $(LDFLAGS) $(NATIVELDFLAGS) $(NOCRTLDFLAGS) $(SYSSECLDFLAGS) $(SYSENTRYLDFLAGS) $(SYSLIBS)


giveio.sys: giveio.c

clean:
	del /F giveio.sys giveio.obj
