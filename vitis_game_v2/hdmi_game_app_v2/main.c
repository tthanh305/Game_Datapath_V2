
/**
 * @file main.c
 * @brief EBAZ4205 HDMI Game - Static Datapath Test
 *
 * Hardware:
 *   FPGA : Zynq-7000 XC7Z010 (EBAZ4205)
 *   HDMI : External HDMI extension board
 *
 * Project:
 *   Game_Test = 06_hdmi_test + Game Datapath
 *
 * Test configuration:
 *   HDMI output : 1280x720 @ 60 Hz
 *   Game logic  : 640x480 coordinates
 *   Game control: Disabled (static rendering)
 *
 * Expected display:
 *   - Black background
 *   - 16 red targets (4x4 grid)
 *   - One green ship
 *   - No projectile or movement
 */

#include <stdio.h>
#include <stdint.h>

#include "xparameters.h"
#include "hdmi_axi.h"
#include "sleep.h"

/* HDMI AXI base address from current hardware platform */
#define HDMI_AXI_BASE_ADDR \
    XPAR_PATTERN_HDMI_AXI_0_BASEADDR

/* Fixed HDMI configuration */
#define GAME_HDMI_TIMING  HDMI_AXI_TIMING_720P
#define GAME_HDMI_PATTERN HDMI_AXI_PATTERN_COLOR_BARS

/* Maximum wait for MMCM lock/reconfiguration */
#define HDMI_TIMEOUT_MS  2000U

int main(void)
{
    Hdmiaxi hdmi;
    int32_t ret;

    printf("\n");
    printf("========================================\n");
    printf("   EBAZ4205 GALAXIAN ARCADE GAME\n");
    printf("========================================\n");
    printf("Output Resolution : 1280x720 @ 60Hz\n");
    printf("Sound Output      : Retro Buzzer on Pin D18\n");
    printf("Display Mode      : Galaxian Dynamic Arcade\n");
    printf("========================================\n\n");

    /* STEP 1: Initialize HDMI AXI driver */
    printf("[1] Initializing HDMI AXI driver...\n");

    HdmiaxiInit(&hdmi, HDMI_AXI_BASE_ADDR);

    printf("    AXI Base Address: 0x%08lX\n",
           (unsigned long)HDMI_AXI_BASE_ADDR);

    /* STEP 2: Reset HDMI controller to default VGA timing */
    printf("[2] Resetting HDMI controller...\n");

    HdmiaxiReset(&hdmi);

    /* STEP 3: Wait for initial MMCM lock */
    printf("[3] Waiting for initial MMCM lock...\n");

    ret = HdmiaxiWaitReconfig(
        &hdmi,
        HDMI_TIMEOUT_MS
    );

    if (ret != 0) {
        printf("ERROR: Initial MMCM lock failed!\n");
        printf("Status Register: 0x%08lX\n",
               (unsigned long)HdmiaxiGetStatus(&hdmi));
        return -1;
    }

    printf("    Initial MMCM lock successful.\n");

    /* STEP 4: Configure fixed HDMI output at 720p */
    printf("[4] Configuring HDMI 1280x720 @ 60Hz...\n");

    ret = HdmiaxiSetControl(
        &hdmi,
        GAME_HDMI_TIMING,
        GAME_HDMI_PATTERN
    );

    if (ret != 0) {
        printf("ERROR: HDMI configuration failed!\n");
        return -1;
    }

    /* STEP 5: Wait for MMCM reconfiguration */
    printf("[5] Waiting for HDMI reconfiguration...\n");

    ret = HdmiaxiWaitReconfig(
        &hdmi,
        HDMI_TIMEOUT_MS
    );

    if (ret != 0) {
        printf("ERROR: MMCM reconfiguration timeout!\n");
        printf("Status Register: 0x%08lX\n",
               (unsigned long)HdmiaxiGetStatus(&hdmi));
        return -1;
    }

    printf("    HDMI reconfiguration successful.\n");

    /* STEP 6: Print final HDMI hardware status */
    printf("[6] HDMI hardware status:\n");

    HdmiaxiPrintInfo(&hdmi);

    printf("\n");
    printf("========================================\n");
    printf("   GALAXIAN ARCADE GAME IS RUNNING!\n");
    printf("========================================\n");
    printf("Controls:\n");
    printf("  KEY4 (U19) : Move Left\n");
    printf("  KEY1 (T19) : Move Right\n");
    printf("  KEY2 (P19) : Menu UP / Pause\n");
    printf("  KEY5 (V20) : Menu DOWN / Restart\n");
    printf("  KEY3 (U20) : Laser Fire / Select Option\n");
    printf("Audio:\n");
    printf("  Buzzer on D18 with multi-tone retro sound effects\n");
    printf("\n");

    /* STEP 7: Keep application running */
    while (1) {
        sleep(1);
    }

    return 0;
}
