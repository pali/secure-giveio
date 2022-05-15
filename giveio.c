/* (c) 2022 Pali Rohár <pali@kernel.org>, GPLv2+ */

#include <ntifs.h>
#include <ntddk.h>

/*
 * FX_SAVE_AREA and KTRAP_FRAME structures have same size in all NT kernel versions. Also offset of
 * EFlags member in KTRAP_FRAME structure is same. Just these sizes and offsets are arch specific.
 */
#if defined(_M_IX86)
#define FX_SAVE_AREA_SIZE 0x210
#define TRAP_FRAME_SIZE 0x8C
#define EFLAGS_TRAP_OFFSET 0x70
#elif defined(_M_AMD64)
#define FX_SAVE_AREA_SIZE 0x0
#define TRAP_FRAME_SIZE 0x190
#define EFLAGS_TRAP_OFFSET 0x178
#else
#error "Unsupported processor"
#endif

/*
 * Calculate offset of KTRAP_FRAME structure from Thread InitialStack pointer and offset of EFlags
 * member in KTRAP_FRAME structure. Offsets are same for all NT kernel versions.
 */
#define GetTrapFrameFromInitialStack(InitialStack) ((ULONG_PTR)(InitialStack) - TRAP_FRAME_SIZE - FX_SAVE_AREA_SIZE)
#define GetEFlagsFromTrapFrame(TrapFrame) *(PULONG)((ULONG_PTR)(TrapFrame) + EFLAGS_TRAP_OFFSET)

#define EFLAGS_IOPL3 0x3000UL

static NTSTATUS NTAPI DriverDispatchCreate(IN PDEVICE_OBJECT DeviceObject, IN PIRP Irp)
{
	NTSTATUS status;

	(VOID)DeviceObject;

	/*
	 * Security check: Allow I/O port access only for processes with SeTcbPrivilege in their
	 * Access token. Same security check is done in NtSetInformationProcess(ProcessUserModeIOPL)
	 * call (it is not implemented in new NT kernels anymore) to prevent unprivileged process to
	 * access I/O ports.
	 */
	if (!SeSinglePrivilegeCheck(SeExports->SeTcbPrivilege, Irp->RequestorMode)) {
		status = STATUS_PRIVILEGE_NOT_HELD;
	} else {
		/*
		 * Set IOPL in EFlags for the current thread to 3 which allows Ring 3 (User Mode)
		 * to access all I/O ports. This change affects only current thread.
		 */
		GetEFlagsFromTrapFrame(GetTrapFrameFromInitialStack(IoGetInitialStack())) |= EFLAGS_IOPL3;
		status = STATUS_SUCCESS;
	}

	Irp->IoStatus.Status = status;
	Irp->IoStatus.Information = 0;
	IoCompleteRequest(Irp, IO_NO_INCREMENT);
	return status;
}

static VOID NTAPI DriverUnload(IN PDRIVER_OBJECT DriverObject)
{
	UNICODE_STRING symbolicLinkName;

	RtlInitUnicodeString(&symbolicLinkName, L"\\DosDevices\\giveio");
	IoDeleteSymbolicLink(&symbolicLinkName);
	IoDeleteDevice(DriverObject->DeviceObject);
}

#if defined(_MSC_VER) && _MSC_VER < 1800
#pragma code_seg("INIT")
#else
__declspec(code_seg("INIT"))
#endif
NTSTATUS NTAPI DriverEntry(IN PDRIVER_OBJECT DriverObject, IN PUNICODE_STRING RegistryPath)
{
	UNICODE_STRING deviceName, symbolicLinkName;
	PDEVICE_OBJECT deviceObject;
	NTSTATUS status;

	(VOID)RegistryPath;

	DriverObject->DriverUnload = DriverUnload;
	DriverObject->MajorFunction[IRP_MJ_CREATE] = DriverDispatchCreate;

	RtlInitUnicodeString(&deviceName, L"\\Device\\giveio");
	status = IoCreateDevice(DriverObject, 0, &deviceName, FILE_DEVICE_UNKNOWN, 0, FALSE, &deviceObject);
	if (!NT_SUCCESS(status))
		return status;

	RtlInitUnicodeString(&symbolicLinkName, L"\\DosDevices\\giveio");
	status = IoCreateSymbolicLink(&symbolicLinkName, &deviceName);
	if (!NT_SUCCESS(status)) {
		IoDeleteDevice(deviceObject);
		return status;
	}

	return STATUS_SUCCESS;
}
