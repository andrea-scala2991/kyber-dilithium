#include <stdio.h>
#include <xil_io.h>
#include <xparameters.h>
#include <xscugic.h>
#include <xil_exception.h>
#include <xil_cache.h>
#include <sleep.h>
#include "xaxicdma.h"
#include "xaxicdma_hw.h"   // for register offsets / masks
#include "xtime_l.h"

// --- Configuration Constants ---
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

// --- Global Variables ---
static XAxiCdma AxiCdmaInstance;
static XScuGic GicInstance;

volatile static int DmaDone = 0;
volatile static int NttDone = 0;

// Input and output buffers
static volatile u32 Input_coeffs  [COEFF_COUNT] __attribute__ ((aligned(32)));
static volatile u32 Output_coeffs [COEFF_COUNT] __attribute__ ((aligned(32)));

// --- Function Prototypes ---
int Setup_Interrupt_System(XScuGic *GicInstancePtr);
void DmaIsr(void *CallbackRef);
void NttIsr(void *CallbackRef);
int NTT_Transfer_And_Execute(u32 *SrcAddr, u32 *DestAddr, u32 NttMode);
int Setup_CDMA(void);
int Reset_CDMA(XAxiCdma *InstancePtr);

int Reset_CDMA(XAxiCdma *InstancePtr)
{
    XAxiCdma_Reset(InstancePtr);

    int Timeout = 1000000;
    while (Timeout--) {
        if (XAxiCdma_ResetIsDone(InstancePtr)) {
            /* Re-enable driver interrupts after reset */
            XAxiCdma_IntrEnable(InstancePtr, XAXICDMA_XR_IRQ_ALL_MASK);
            xil_printf("CDMA reset complete.\r\n");
            return XST_SUCCESS;
        }
    }

    xil_printf("ERROR: CDMA reset timeout!\r\n");
    return XST_FAILURE;
}

/*****************************************************************************/
/**
* @brief DMA Interrupt Handler
******************************************************************************/
void DmaIsr(void *CallbackRef)
{
    XAxiCdma *InstancePtr = (XAxiCdma *)CallbackRef;
    u32 IrqStatus;

    /* Read Status Register (W1C) */
    IrqStatus = Xil_In32(InstancePtr->BaseAddr + XAXICDMA_SR_OFFSET);

    /* Clear by writing back (W1C) */
    Xil_Out32(InstancePtr->BaseAddr + XAXICDMA_SR_OFFSET, IrqStatus);

    /* Check for errors */
    if (IrqStatus & XAXICDMA_XR_IRQ_ERROR_MASK) {
        xil_printf("CDMA ERROR: 0x%08X\r\n", IrqStatus);
        XAxiCdma_Reset(InstancePtr);
        DmaDone = 1; /* wake waiting thread even on error */
        return;
    }

    /* Successful transfer (IOC) */
    if (IrqStatus & XAXICDMA_XR_IRQ_IOC_MASK) {
        DmaDone = 1;
    }
}

/*****************************************************************************/
/**
* @brief NTT Interrupt Handler
******************************************************************************/
void NttIsr(void *CallbackRef)
{
    if (!NttDone) {
        /* Acknowledge NTT interrupt */
        Xil_Out32(NTT_CTRL_ADDR + NTT_IRQ_CLEAR, 1);
        NttDone = 1;

        /* Disable the NTT interrupt to prevent retriggering until re-enabled */
        XScuGic_Disable(&GicInstance, NTT_IRQ_ID);

        /* small delay then clear ack */
        usleep(1);
        Xil_Out32(NTT_CTRL_ADDR + NTT_IRQ_CLEAR, 0);
    }
}

/*****************************************************************************/
/**
* @brief CDMA Setup using standard driver
******************************************************************************/
int Setup_CDMA(void)
{
    XAxiCdma_Config *CfgPtr;
    int Status;

    xil_printf("Initializing CDMA...\r\n");

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

    /* Make sure interrupts are enabled in the driver (will re-enable after reset too) */
    XAxiCdma_IntrEnable(&AxiCdmaInstance, XAXICDMA_XR_IRQ_ALL_MASK);

    xil_printf("CDMA Initialized Successfully.\r\n");
    return XST_SUCCESS;
}

/*****************************************************************************/
/**
* @brief Sets up the GIC and connects ISRs
******************************************************************************/
int Setup_Interrupt_System(XScuGic *GicInstancePtr)
{
    XScuGic_Config *GicConfig;
    int Status;

    /* Initialize the GIC */
    GicConfig = XScuGic_LookupConfig(XPAR_SCUGIC_0_DEVICE_ID);
    if (!GicConfig)
        return XST_FAILURE;

    Status = XScuGic_CfgInitialize(GicInstancePtr, GicConfig, GicConfig->CpuBaseAddress);
    if (Status != XST_SUCCESS)
        return XST_FAILURE;

    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
                                 (Xil_ExceptionHandler)XScuGic_InterruptHandler,
                                 GicInstancePtr);
    Xil_ExceptionEnable();

    /* Connect DMA ISR */
    Status = XScuGic_Connect(GicInstancePtr, CDMA_IRQ_ID,
                             (Xil_ExceptionHandler)DmaIsr,
                             (void *)&AxiCdmaInstance);
    if (Status != XST_SUCCESS)
        return XST_FAILURE;

    /* Connect NTT ISR */
    Status = XScuGic_Connect(GicInstancePtr, NTT_IRQ_ID,
                             (Xil_ExceptionHandler)NttIsr,
                             (void *)NTT_CTRL_ADDR);
    if (Status != XST_SUCCESS)
        return XST_FAILURE;

    /* Enable interrupts at GIC */
    XScuGic_Enable(GicInstancePtr, CDMA_IRQ_ID);
    XScuGic_Enable(GicInstancePtr, NTT_IRQ_ID);

    xil_printf("Interrupt System Setup Complete.\r\n");
    return XST_SUCCESS;
}

/*****************************************************************************/
/**
* @brief Performs NTT or INTT operation with DMA
******************************************************************************/
int NTT_Transfer_And_Execute(u32 input_coeffs[], u32 output_coeffs[], u32 NttMode)
{
    int Status;
    const char *ModeStr = (NttMode == NTT_MODE_FORWARD) ? "NTT (Forward)" : "INTT (Inverse)";

    xil_printf("\nStarting %s Cycle...\r\n", ModeStr);

    /* --- Step 1: DRAM -> BRAM --- */
    DmaDone = 0;

    Status = Reset_CDMA(&AxiCdmaInstance);
    if (Status != XST_SUCCESS) return Status;

    /* Flush source so DMA reads latest CPU-updated data */
    Xil_DCacheFlushRange((UINTPTR)input_coeffs, TRANSFER_LEN_BYTES);

    /* Start DMA: DRAM -> BRAM
     * Note: BRAM_BASE_ADDR is an AXI slave address; ensure it is DMA-accessible.
     */
    DmaDone = 0;
    Status = XAxiCdma_SimpleTransfer(&AxiCdmaInstance,
                                     (UINTPTR)input_coeffs,
                                     BRAM_BASE_ADDR,
                                     TRANSFER_LEN_BYTES,
                                     NULL, NULL);

    if (Status != XST_SUCCESS) {
        u32 err = Xil_In32(AxiCdmaInstance.BaseAddr + XAXICDMA_SR_OFFSET);
        xil_printf("ERROR: CDMA Transfer failed (DRAM -> BRAM). Status reg = 0x%08X\r\n", err);
        XAxiCdma_DumpRegisters(&AxiCdmaInstance);
        return Status;
    }

    /* wait for DMA completion */
    while (!DmaDone) {}

    /* --- Step 2: Start NTT --- */
    NttDone = 0;

    /* Re-enable NTT interrupt just before starting the core */
    XScuGic_Enable(&GicInstance, NTT_IRQ_ID);

    /* Start the NTT core (AP_START + MODE bit if needed) */
    Xil_Out32(NTT_CTRL_ADDR + NTT_AP_CTRL, 0x01 | (NttMode ? 0x02 : 0x0));
    Xil_Out32(NTT_CTRL_ADDR + NTT_AP_CTRL, 0x0);

    /* Wait for NTT to signal completion via ISR */
    while (!NttDone) {}

    /* --- Step 3: BRAM -> DRAM --- */
    DmaDone = 0;

    Status = Reset_CDMA(&AxiCdmaInstance);
    if (Status != XST_SUCCESS) return Status;

    /* Invalidate destination range BEFORE the DMA writes */
    Xil_DCacheInvalidateRange((UINTPTR)output_coeffs, TRANSFER_LEN_BYTES);

    DmaDone = 0;
    Status = XAxiCdma_SimpleTransfer(&AxiCdmaInstance,
                                     BRAM_BASE_ADDR,
                                     (UINTPTR)output_coeffs,
                                     TRANSFER_LEN_BYTES,
                                     NULL, NULL);
    if (Status != XST_SUCCESS) {
        u32 err = Xil_In32(AxiCdmaInstance.BaseAddr + XAXICDMA_SR_OFFSET);
        xil_printf("ERROR: CDMA Transfer failed (BRAM -> DRAM). Status reg = 0x%08X\r\n", err);
        XAxiCdma_DumpRegisters(&AxiCdmaInstance);
        return Status;
    }

    /* wait for DMA completion */
    while (!DmaDone) {}

    /* Invalidate again AFTER DMA completes so CPU reads updated memory */
    Xil_DCacheInvalidateRange((UINTPTR)output_coeffs, TRANSFER_LEN_BYTES);

    xil_printf("%s Cycle Complete.\r\n", ModeStr);
    return XST_SUCCESS;
}

/*****************************************************************************/
/**
* @brief Main Function
******************************************************************************/
int main()
{
    int i, Status;

    xil_printf("=== VITIS NTT Platform Test (Standard CDMA Driver) ===\r\n");

    /* Initialize data */
    for (i = 0; i < COEFF_COUNT; i++) {
        Input_coeffs[i] = i;
        Output_coeffs[i] = 0;
    }

    /* Setup CDMA */
    Status = Setup_CDMA();
    if (Status != XST_SUCCESS)
        return XST_FAILURE;

    /* Setup GIC and interrupts */
    Status = Setup_Interrupt_System(&GicInstance);
    if (Status != XST_SUCCESS)
        return XST_FAILURE;

    /* DDR->DDR test: make sure to do cache maintenance every time */
    Xil_DCacheFlushRange((UINTPTR)Input_coeffs, TRANSFER_LEN_BYTES);
    Xil_DCacheInvalidateRange((UINTPTR)Output_coeffs, TRANSFER_LEN_BYTES);

    xil_printf("Testing DDR->DDR CDMA transfer...\r\n");

    /* reset flag and start transfer */
    DmaDone = 0;
    Status = XAxiCdma_SimpleTransfer(&AxiCdmaInstance,
                                     (UINTPTR)Input_coeffs,
                                     (UINTPTR)Output_coeffs,
                                     TRANSFER_LEN_BYTES,
                                     NULL, NULL);
    if (Status != XST_SUCCESS) {
        xil_printf("DDR->DDR CDMA test FAILED. Status = 0x%08X\r\n", Status);
    } else {
        xil_printf("DDR->DDR CDMA test started, waiting...\r\n");
    }

    while (!DmaDone) {}
    /* after completion invalidate so CPU sees updated DDR */
    Xil_DCacheInvalidateRange((UINTPTR)Output_coeffs, TRANSFER_LEN_BYTES);
    xil_printf("DDR->DDR CDMA transfer complete!\r\n");

    for (i = 0; i < COEFF_COUNT; i++) {
        if (Input_coeffs[i] != Output_coeffs[i]) {
            xil_printf("DMA TRANSFER ERROR, MISMATCH: %u != %u\r\n", (unsigned)Input_coeffs[i], (unsigned)Output_coeffs[i]);
            return 1;
        }
    }
    xil_printf("DDR->DDR verification OK.\r\n");

    /* Run Forward NTT */
    Status = NTT_Transfer_And_Execute((u32 *)Input_coeffs, (u32 *)Output_coeffs, NTT_MODE_FORWARD);
    if (Status != XST_SUCCESS)
        return XST_FAILURE;

    xil_printf("NTT Coeffs[0]: %u\r\n", Output_coeffs[0]);
    xil_printf("NTT Coeffs[255]: %u\r\n", Output_coeffs[255]);

    /* Run Inverse NTT */
    Status = NTT_Transfer_And_Execute((u32 *)Output_coeffs, (u32 *)Input_coeffs, NTT_MODE_INVERSE);
    if (Status != XST_SUCCESS)
        return XST_FAILURE;


    xil_printf("\n--- Final INTT Verification ---\r\n");
    xil_printf("Restored Coeffs[0]: %u \r\n", Input_coeffs[0]);
    xil_printf("Restored Coeffs[255]: %u \r\n", Input_coeffs[255]);


    xil_printf("--- Test Complete ---\r\n");
    return 0;
}
