#include <stdio.h>
#include <xil_io.h>
#include <xparameters.h>
#include <xscugic.h>
#include <xil_exception.h>
#include <xil_cache.h>
#include <sleep.h>
#include "xaxicdma.h"
#include "xaxicdma_hw.h"
#include "xtime_l.h"

// --- Print Macros ------------------------------------------------------------
#define DEBUG_PRINTS  0     // set to 0 to disable debug prints
#define TIMING_PRINTS 1     // set to 0 to disable timing prints

#if DEBUG_PRINTS
  #define DPRINT(...) xil_printf(__VA_ARGS__)
#else
  #define DPRINT(...) do {} while (0)
#endif

#if TIMING_PRINTS
  #define TPRINT(...) xil_printf(__VA_ARGS__)
#else
  #define TPRINT(...) do {} while (0)
#endif

// --- Configuration Constants -------------------------------------------------
#define COEFF_COUNT             256
#define TRANSFER_LEN_BYTES      (COEFF_COUNT * sizeof(u32))

// Base Addresses
#define BRAM_BASE_ADDR          XPAR_AXI_NTT_UNIT_0_S01_AXI_BASEADDR
#define NTT_CTRL_ADDR           XPAR_AXI_NTT_UNIT_0_S00_AXI_BASEADDR

// Interrupt IDs
#define NTT_IRQ_ID              XPAR_FABRIC_AXI_NTT_UNIT_0_VEC_ID
#define CDMA_IRQ_ID             XPAR_FABRIC_AXICDMA_0_VEC_ID

// NTT Control Offsets
#define NTT_AP_CTRL             0x00
#define NTT_IRQ_CLEAR           0x04
#define NTT_MODE_FORWARD        0
#define NTT_MODE_INVERSE        1

// --- Global Variables --------------------------------------------------------
static XAxiCdma AxiCdmaInstance;
static XScuGic GicInstance;

volatile static int DmaDone = 0;
volatile static int NttDone = 0;

XTime t_start, t_end;


// Input and output buffers
static volatile u32 Input_coeffs  [COEFF_COUNT] __attribute__ ((aligned(32)));
static volatile u32 Output_coeffs [COEFF_COUNT] __attribute__ ((aligned(32)));

// --- Function Prototypes -----------------------------------------------------
int Setup_Interrupt_System(XScuGic *GicInstancePtr);
void DmaIsr(void *CallbackRef);
void NttIsr(void *CallbackRef);
int NTT_Transfer_And_Execute(u32 *SrcAddr, u32 *DestAddr, u32 NttMode);
int Setup_CDMA(void);
int Reset_CDMA(XAxiCdma *InstancePtr);

// -----------------------------------------------------------------------------
// CDMA Reset
// -----------------------------------------------------------------------------
int Reset_CDMA(XAxiCdma *InstancePtr)
{
    XAxiCdma_Reset(InstancePtr);

    int Timeout = 1000000;
    while (Timeout--) {
        if (XAxiCdma_ResetIsDone(InstancePtr)) {
            XAxiCdma_IntrEnable(InstancePtr, XAXICDMA_XR_IRQ_ALL_MASK);
            DPRINT("CDMA reset complete.\r\n");
            return XST_SUCCESS;
        }
    }

    xil_printf("ERROR: CDMA reset timeout!\r\n");
    return XST_FAILURE;
}

// -----------------------------------------------------------------------------
// DMA Interrupt Handler
// -----------------------------------------------------------------------------
void DmaIsr(void *CallbackRef)
{
    XAxiCdma *InstancePtr = (XAxiCdma *)CallbackRef;
    u32 IrqStatus;

    IrqStatus = Xil_In32(InstancePtr->BaseAddr + XAXICDMA_SR_OFFSET);
    Xil_Out32(InstancePtr->BaseAddr + XAXICDMA_SR_OFFSET, IrqStatus);

    if (IrqStatus & XAXICDMA_XR_IRQ_ERROR_MASK) {
        //xil_printf("CDMA ERROR: 0x%08X\r\n", IrqStatus);
        XAxiCdma_Reset(InstancePtr);
        DmaDone = 1;
        return;
    }

    if (IrqStatus & XAXICDMA_XR_IRQ_IOC_MASK)
        DmaDone = 1;
}

// -----------------------------------------------------------------------------
// NTT Interrupt Handler
// -----------------------------------------------------------------------------
void NttIsr(void *CallbackRef)
{
    if (!NttDone) {
        Xil_Out32(NTT_CTRL_ADDR + NTT_IRQ_CLEAR, 1);
        NttDone = 1;
        XScuGic_Disable(&GicInstance, NTT_IRQ_ID);
        usleep(1);
        Xil_Out32(NTT_CTRL_ADDR + NTT_IRQ_CLEAR, 0);
    }
}

// -----------------------------------------------------------------------------
// CDMA Setup
// -----------------------------------------------------------------------------
int Setup_CDMA(void)
{
    XAxiCdma_Config *CfgPtr;
    int Status;

    DPRINT("Initializing CDMA...\r\n");

    CfgPtr = XAxiCdma_LookupConfig(XPAR_AXICDMA_0_DEVICE_ID);
    if (!CfgPtr) {
        xil_printf("ERROR: CDMA config lookup failed.\r\n");
        return XST_FAILURE;
    }

    Status = XAxiCdma_CfgInitialize(&AxiCdmaInstance, CfgPtr, CfgPtr->BaseAddress);
    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: CDMA initialization failed.\r\n");
        return XST_FAILURE;
    }

    XAxiCdma_IntrEnable(&AxiCdmaInstance, XAXICDMA_XR_IRQ_ALL_MASK);
    DPRINT("CDMA Initialized Successfully.\r\n");
    return XST_SUCCESS;
}

// -----------------------------------------------------------------------------
// Interrupt System Setup
// -----------------------------------------------------------------------------
int Setup_Interrupt_System(XScuGic *GicInstancePtr)
{
    XScuGic_Config *GicConfig;
    int Status;

    GicConfig = XScuGic_LookupConfig(XPAR_SCUGIC_0_DEVICE_ID);
    if (!GicConfig) return XST_FAILURE;

    Status = XScuGic_CfgInitialize(GicInstancePtr, GicConfig, GicConfig->CpuBaseAddress);
    if (Status != XST_SUCCESS) return XST_FAILURE;

    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
                                 (Xil_ExceptionHandler)XScuGic_InterruptHandler,
                                 GicInstancePtr);
    Xil_ExceptionEnable();

    Status = XScuGic_Connect(GicInstancePtr, CDMA_IRQ_ID,
                             (Xil_ExceptionHandler)DmaIsr,
                             (void *)&AxiCdmaInstance);
    if (Status != XST_SUCCESS) return XST_FAILURE;

    Status = XScuGic_Connect(GicInstancePtr, NTT_IRQ_ID,
                             (Xil_ExceptionHandler)NttIsr,
                             (void *)NTT_CTRL_ADDR);
    if (Status != XST_SUCCESS) return XST_FAILURE;

    XScuGic_Enable(GicInstancePtr, CDMA_IRQ_ID);
    XScuGic_Enable(GicInstancePtr, NTT_IRQ_ID);

    DPRINT("Interrupt System Setup Complete.\r\n");
    return XST_SUCCESS;
}

// -----------------------------------------------------------------------------
// NTT Transfer and Execute with Timing
// -----------------------------------------------------------------------------
int NTT_Transfer_And_Execute(u32 input_coeffs[], u32 output_coeffs[], u32 NttMode)
{
    int Status;
    const char *ModeStr = (NttMode == NTT_MODE_FORWARD) ? "NTT (Forward)" : "INTT (Inverse)";

    XTime_GetTime(&t_start); // start timing
    DPRINT("\nStarting %s Cycle...\r\n", ModeStr);

    // --- Step 1: DRAM -> BRAM ---
    DmaDone = 0;
    Status = Reset_CDMA(&AxiCdmaInstance);
    if (Status != XST_SUCCESS) return Status;

    Xil_DCacheFlushRange((UINTPTR)input_coeffs, TRANSFER_LEN_BYTES);

    DmaDone = 0;
    Status = XAxiCdma_SimpleTransfer(&AxiCdmaInstance,
                                     (UINTPTR)input_coeffs,
                                     BRAM_BASE_ADDR,
                                     TRANSFER_LEN_BYTES,
                                     NULL, NULL);
    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: CDMA Transfer failed (DRAM -> BRAM).\r\n");
        return Status;
    }

    while (!DmaDone) {}

    // --- Step 2: Start NTT ---
    NttDone = 0;
    XScuGic_Enable(&GicInstance, NTT_IRQ_ID);


    Xil_Out32(NTT_CTRL_ADDR + NTT_AP_CTRL, 0x01 | (NttMode ? 0x02 : 0x0));
    Xil_Out32(NTT_CTRL_ADDR + NTT_AP_CTRL, 0x0);

    while (!NttDone) {}


    // --- Step 3: BRAM -> DRAM ---
    DmaDone = 0;
    Status = Reset_CDMA(&AxiCdmaInstance);
    if (Status != XST_SUCCESS) return Status;

    Xil_DCacheInvalidateRange((UINTPTR)output_coeffs, TRANSFER_LEN_BYTES);

    DmaDone = 0;
    Status = XAxiCdma_SimpleTransfer(&AxiCdmaInstance,
                                     BRAM_BASE_ADDR,
                                     (UINTPTR)output_coeffs,
                                     TRANSFER_LEN_BYTES,
                                     NULL, NULL);
    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: CDMA Transfer failed (BRAM -> DRAM).\r\n");
        return Status;
    }

    while (!DmaDone) {}
    Xil_DCacheInvalidateRange((UINTPTR)output_coeffs, TRANSFER_LEN_BYTES);

    XTime_GetTime(&t_end); // end timing

    DPRINT("%s Cycle Complete.\r\n", ModeStr);
    return XST_SUCCESS;
}

// -----------------------------------------------------------------------------
// Main
// -----------------------------------------------------------------------------
int main()
{
    int i, Status;
    double elapsed_us;
    int elapsed_us_int;

    xil_printf("===NTT Platform Test===\r\n");

    for (i = 0; i < COEFF_COUNT; i++) {
        Input_coeffs[i] = i;
        Output_coeffs[i] = 0;
    }

    Status = Setup_CDMA();
    if (Status != XST_SUCCESS) return XST_FAILURE;

    Status = Setup_Interrupt_System(&GicInstance);
    if (Status != XST_SUCCESS) return XST_FAILURE;

    Xil_DCacheFlushRange((UINTPTR)Input_coeffs, TRANSFER_LEN_BYTES);
    Xil_DCacheInvalidateRange((UINTPTR)Output_coeffs, TRANSFER_LEN_BYTES);

    DPRINT("Testing DDR->DDR CDMA transfer...\r\n");

    DmaDone = 0;
    Status = XAxiCdma_SimpleTransfer(&AxiCdmaInstance,
                                     (UINTPTR)Input_coeffs,
                                     (UINTPTR)Output_coeffs,
                                     TRANSFER_LEN_BYTES,
                                     NULL, NULL);
    while (!DmaDone) {}
    Xil_DCacheInvalidateRange((UINTPTR)Output_coeffs, TRANSFER_LEN_BYTES);

    DPRINT("DDR->DDR CDMA transfer complete!\r\n");

    for (i = 0; i < COEFF_COUNT; i++) {
        if (Input_coeffs[i] != Output_coeffs[i]) {
            xil_printf("DMA TRANSFER ERROR, MISMATCH: %u != %u\r\n",
                       (unsigned)Input_coeffs[i], (unsigned)Output_coeffs[i]);
            return 1;
        }
    }

    DPRINT("DDR->DDR verification OK.\r\n");

    // --- Forward NTT ---
    Status = NTT_Transfer_And_Execute((u32 *)Input_coeffs, (u32 *)Output_coeffs, NTT_MODE_FORWARD);

    elapsed_us = (double)(t_end - t_start) / (COUNTS_PER_SECOND / 1000000.0);
    elapsed_us_int = (int)elapsed_us;
    TPRINT("NTT runtime: %u us\r\n", elapsed_us_int);


    if (Status != XST_SUCCESS) return XST_FAILURE;



    xil_printf("NTT Coeffs[0]: %u\r\n", Output_coeffs[0]);
    xil_printf("NTT Coeffs[255]: %u\r\n", Output_coeffs[255]);

    // --- Inverse NTT ---
    Status = NTT_Transfer_And_Execute((u32 *)Output_coeffs, (u32 *)Input_coeffs, NTT_MODE_INVERSE);

    elapsed_us = (double)(t_end - t_start) / (COUNTS_PER_SECOND / 1000000.0);
    elapsed_us_int = (int)elapsed_us;
    TPRINT("INTT runtime: %u us\r\n", elapsed_us_int);


    if (Status != XST_SUCCESS) return XST_FAILURE;

    int Match = 1;
    for (i = 0; i < COEFF_COUNT; i++) {
        if (Input_coeffs[i] != (u32)i) {
            Match = 0;
            break;
        }
    }

    xil_printf("\n--- Final INTT Verification ---\r\n");
    xil_printf("Restored Coeffs[0]: %u (Expected: %u)\r\n", Input_coeffs[0], (u32)0);
    xil_printf("Restored Coeffs[255]: %u (Expected: %u)\r\n", Input_coeffs[255], (u32)255);

    if (Match)
        xil_printf("RESULT: PASS — Data restored successfully.\r\n");
    else
        xil_printf("RESULT: WARNING — Data mismatch (missing scaling factor?)\r\n");

    xil_printf("--- Test Complete ---\r\n");
    return 0;
}
