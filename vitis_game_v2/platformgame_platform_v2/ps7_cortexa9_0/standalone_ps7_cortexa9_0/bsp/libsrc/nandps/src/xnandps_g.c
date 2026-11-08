#include "xnandps.h"

XNandPs_Config XNandPs_ConfigTable[] __attribute__ ((section (".drvcfg_sec"))) = {

	{
		"arm,pl353-smc-r2p1", /* compatible */
		0xe000e000, /* flashbase */
		0xe1000000, /* ranges */
		0x8 /* nand-bus-width */
	},
	 {
		 NULL
	}
};