#include <stdio.h>
#include <stdlib.h>
#include "platform.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "xparameters_ps.h"
#include "xaxidma.h"
#include "xtime_l.h"
#include "sleep.h"
#include "image.h"

#define TX_DMA_ID                 XPAR_PS2PL_DMA_DEVICE_ID
#define TX_DMA_MM2S_LENGTH_ADDR  (XPAR_PS2PL_DMA_BASEADDR + 0x28)
#define RX_DMA_ID                 XPAR_PL2PS_DMA_DEVICE_ID
#define RX_DMA_S2MM_LENGTH_ADDR  (XPAR_PL2PS_DMA_BASEADDR + 0x58)

#define TX_BUFFER (XPAR_DDR_MEM_BASEADDR + 0x08000000)
#define RX_BUFFER (XPAR_DDR_MEM_BASEADDR + 0x10000000)

#define N          0x20   // image width and height (32)
#define NUM_PIXELS 0x400  // total pixels (32*32 = 1024)
#define PRINT_COUNT 10    // how many pixels to print for comparison

XAxiDma TxDma;
XAxiDma RxDma;

int main()
{
    Xil_DCacheDisable();

    XTime preExecCyclesFPGA  = 0;
    XTime postExecCyclesFPGA = 0;
    XTime preExecCyclesSW    = 0;
    XTime postExecCyclesSW   = 0;

    print("HELLO 1\r\n");
    init_platform();

    u8  *TxBufferPtr = (u8  *)TX_BUFFER;
    u32 *RxBufferPtr = (u32 *)RX_BUFFER;
    int Status;

    // Step 1: Initialize TX-DMA
    XAxiDma_Config *TxDmaConfig = XAxiDma_LookupConfig(TX_DMA_ID);
    if (!TxDmaConfig) { xil_printf("No config found for TX DMA\r\n"); return XST_FAILURE; }
    if (XAxiDma_CfgInitialize(&TxDma, TxDmaConfig) != XST_SUCCESS) {
        xil_printf("TX DMA init failed\r\n"); return XST_FAILURE;
    }
    XAxiDma_IntrDisable(&TxDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);
    XAxiDma_IntrDisable(&TxDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);

    // Step 2: Initialize RX-DMA
    XAxiDma_Config *RxDmaConfig = XAxiDma_LookupConfig(RX_DMA_ID);
    if (!RxDmaConfig) { xil_printf("No config found for RX DMA\r\n"); return XST_FAILURE; }
    if (XAxiDma_CfgInitialize(&RxDma, RxDmaConfig) != XST_SUCCESS) {
        xil_printf("RX DMA init failed\r\n"); return XST_FAILURE;
    }
    XAxiDma_IntrDisable(&RxDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);
    XAxiDma_IntrDisable(&RxDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);

    print("HELLO 2\r\n");

    // Fill TX buffer with image pixels
    for (int i = 0; i < NUM_PIXELS; i++)
        TxBufferPtr[i] = pixels[i];

    // Clear RX buffer with distinctive pattern to prove FPGA writes it
    for (int i = 0; i < NUM_PIXELS; i++)
        RxBufferPtr[i] = 0x00000000;

    print("HELLO 3\r\n");

    // Step 3: Setup and run DMA transfers
    Status = XAxiDma_SimpleTransfer(&RxDma, (u32)RxBufferPtr,
                                     NUM_PIXELS * sizeof(u32), XAXIDMA_DEVICE_TO_DMA);
    if (Status != XST_SUCCESS) { xil_printf("RX DMA setup failed\r\n"); return XST_FAILURE; }
    print("RX DMA transfer setup successful\r\n");

    Status = XAxiDma_SimpleTransfer(&TxDma, (u32)TxBufferPtr,
                                     NUM_PIXELS * sizeof(u8), XAXIDMA_DMA_TO_DEVICE);
    if (Status != XST_SUCCESS) { xil_printf("TX DMA setup failed\r\n"); return XST_FAILURE; }
    print("TX DMA transfer setup successful\r\n");

    // Time only the actual FPGA processing
    XTime_GetTime(&preExecCyclesFPGA);
    while (XAxiDma_Busy(&TxDma, XAXIDMA_DMA_TO_DEVICE));
    while (XAxiDma_Busy(&RxDma, XAXIDMA_DEVICE_TO_DMA));
    XTime_GetTime(&postExecCyclesFPGA);

    int sent     = Xil_In32(TX_DMA_MM2S_LENGTH_ADDR);
    int received = Xil_In32(RX_DMA_S2MM_LENGTH_ADDR);
    printf("Bytes sent to PL:       %d\r\n", sent);
    printf("Bytes received from PL: %d\r\n", received);
    if (sent == NUM_PIXELS && received == NUM_PIXELS * (int)sizeof(u32))
        print("FPGA processing successful\r\n");
    else
        print("FPGA processing failed\r\n");

    print("HELLO 4\r\n");

    // Step 5: SW debayering reference
    XTime_GetTime(&preExecCyclesSW);

    u8 *img = pixels;
    int pixel_out = 0;

    static u8 Red[NUM_PIXELS];
    static u8 Green[NUM_PIXELS];
    static u8 Blue[NUM_PIXELS];

    for (int row = 0; row < N; row++) {

        // Precompute clamped row indices
        int rm = (row > 0)           ? row - 1 : 0;
        int rp = (row < N - 1)  ? row + 1 : row;
        int rm_off = rm * N;  // row-1 offset into img
        int r_off  = row * N; // current row offset
        int rp_off = rp * N;  // row+1 offset

        int is_top    = (row == 0);
        int is_bottom = (row == N - 1);
        int blue_line = ((row & 1) == 0);

        for (int col = 0; col < N; col++) {


            int cm = (col > 0)          ? col - 1 : 0;
            int cp = (col < N - 1) ? col + 1 : col;

            int is_left  = (col == 0);
            int is_right = (col == N - 1);


            u8 d0 = img[rp_off + cp];
            u8 d1 = img[rp_off + col];
            u8 d2 = img[rp_off + cm];
            u8 d3 = img[r_off  + cp];
            u8 d4 = img[r_off  + col];
            u8 d5 = img[r_off  + cm];
            u8 d6 = img[rm_off + cp];
            u8 d7 = img[rm_off + col];
            u8 d8 = img[rm_off + cm];

            //See if 3x3 at borders
            if (is_left)       { d2 = 0; d5 = 0; d8 = 0; }
            else if (is_right) { d0 = 0; d3 = 0; d6 = 0; }

            if (is_top)        { d6 = 0; d7 = 0; d8 = 0; }
            else if (is_bottom){ d0 = 0; d1 = 0; d2 = 0; }

            if (blue_line) {
                if ((col & 1) == 0) {
                    // case2: center is Green on GB row
                    Green[pixel_out] = d4;
                    Red[pixel_out]   = (d1 + d7) / 2;
                    Blue[pixel_out]  = (d3 + d5) / 2;
                } else {
                    // case4: center is Blue
                    Green[pixel_out] = (d1 + d3 + d5 + d7) / 4;
                    Red[pixel_out]   = (d0 + d2 + d6 + d8) / 4;
                    Blue[pixel_out]  = d4;
                }
            } else {
                if ((col & 1) == 0) {
                    // case3: center is Red
                    Green[pixel_out] = (d1 + d3 + d5 + d7) / 4;
                    Red[pixel_out]   = d4;
                    Blue[pixel_out]  = (d0 + d2 + d6 + d8) / 4;
                } else {
                    // case1: center is Green on RG row
                    Green[pixel_out] = d4;
                    Red[pixel_out]   = (d3 + d5) / 2;
                    Blue[pixel_out]  = (d1 + d7) / 2;
                }
            }

            pixel_out++;
        }
    }

    XTime_GetTime(&postExecCyclesSW);
    print("HELLO 5\r\n");


    // PRINT ROUTINE 1: FPGA output pixels
    u32 *ptr_results = (u32 *)RX_BUFFER;
    for (int i = 0; i < NUM_PIXELS; i++) {
        u32 pixel_rgb = ptr_results[i];
        u8 b =  pixel_rgb & 0xFF;
        u8 g = (pixel_rgb >> 8) & 0xFF;
        u8 r = (pixel_rgb >> 16) & 0xFF;
        xil_printf("%5d |  %3d   |  %3d   |  %3d   | 0x%08X\r\n",
                    i, r, g, b, pixel_rgb);
    }

    // PRINT ROUTINE 2: SW reference pixels
    xil_printf("\r\n--- START OF ALL SOFTWARE RGB RESULTS ---\r\n");
    xil_printf("Index |   Red  |  Green |  Blue  | \r\n");
    xil_printf("------------------------------------------\r\n");
    for (int i = 0; i < NUM_PIXELS; i++) {
    	xil_printf("%5d |  %3d   |  %3d   |  %3d   |\r\n",
    			i, Red[i], Green[i], Blue[i]);
    }

    int total_pixel_errors = 0;
    u32 *accel_res = (u32*)RX_BUFFER;

    for (int i = 0; i < NUM_PIXELS; i++) {
    	u8 accel_b =  accel_res[i] & 0xFF;
        u8 accel_g = (accel_res[i] >> 8) & 0xFF;
        u8 accel_r = (accel_res[i] >> 16) & 0xFF;

        if (accel_r != Red[i] || accel_g != Green[i] || accel_b != Blue[i]) {
        	total_pixel_errors++;
            xil_printf("\r\n Mismatched pixels : %d", i);
        }
    }

        xil_printf("\n --- New Error Report ---");
        int percentage_error_int = (total_pixel_errors * 100) / NUM_PIXELS;
        int percentage_error_frac = ((total_pixel_errors * 10000) / NUM_PIXELS) % 100;

        xil_printf("\r\n--- ERROR REPORT ---\r\n");
        xil_printf("Total Mismatched Pixels: %d out of %d\r\n", total_pixel_errors, NUM_PIXELS);
        xil_printf("Total Percentage Error: %d.%02d %%\r\n", percentage_error_int, percentage_error_frac);
        xil_printf("---------------------\r\n");

        XTime fpga_cycles = postExecCyclesFPGA - preExecCyclesFPGA;
        printf("FPGA Execution Time: %llu clock cycles\r\n", (unsigned long long)fpga_cycles);

        XTime sw_cycles = postExecCyclesSW - preExecCyclesSW;
        printf("SW Execution Time: %llu clock cycles\r\n", (unsigned long long)sw_cycles); //Xil_printf doesnt support llu

        if (fpga_cycles > 0) {
            int speedup_int = (int)(sw_cycles / fpga_cycles);
            int speedup_frac = (int)((sw_cycles * 100 / fpga_cycles) % 100);
            xil_printf("Speed up is: %d.%02dx\r\n", speedup_int, speedup_frac);
        } else {
            xil_printf("Speed up is: N/A (FPGA time is 0)\r\n");
        }


    print("COMPLETED\r\n");

    cleanup_platform();
    return 0;
}