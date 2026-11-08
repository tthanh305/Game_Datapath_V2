# Additional clean files
cmake_minimum_required(VERSION 3.16)

if("${CONFIG}" STREQUAL "" OR "${CONFIG}" STREQUAL "")
  file(REMOVE_RECURSE
  "E:\\Game_Datapath_V2\\vitis_game_v2\\platformgame_platform_v2\\zynq_fsbl\\zynq_fsbl_bsp\\include\\diskio.h"
  "E:\\Game_Datapath_V2\\vitis_game_v2\\platformgame_platform_v2\\zynq_fsbl\\zynq_fsbl_bsp\\include\\ff.h"
  "E:\\Game_Datapath_V2\\vitis_game_v2\\platformgame_platform_v2\\zynq_fsbl\\zynq_fsbl_bsp\\include\\ffconf.h"
  "E:\\Game_Datapath_V2\\vitis_game_v2\\platformgame_platform_v2\\zynq_fsbl\\zynq_fsbl_bsp\\include\\sleep.h"
  "E:\\Game_Datapath_V2\\vitis_game_v2\\platformgame_platform_v2\\zynq_fsbl\\zynq_fsbl_bsp\\include\\xilffs.h"
  "E:\\Game_Datapath_V2\\vitis_game_v2\\platformgame_platform_v2\\zynq_fsbl\\zynq_fsbl_bsp\\include\\xilffs_config.h"
  "E:\\Game_Datapath_V2\\vitis_game_v2\\platformgame_platform_v2\\zynq_fsbl\\zynq_fsbl_bsp\\include\\xilrsa.h"
  "E:\\Game_Datapath_V2\\vitis_game_v2\\platformgame_platform_v2\\zynq_fsbl\\zynq_fsbl_bsp\\include\\xiltimer.h"
  "E:\\Game_Datapath_V2\\vitis_game_v2\\platformgame_platform_v2\\zynq_fsbl\\zynq_fsbl_bsp\\include\\xtimer_config.h"
  "E:\\Game_Datapath_V2\\vitis_game_v2\\platformgame_platform_v2\\zynq_fsbl\\zynq_fsbl_bsp\\lib\\libxilffs.a"
  "E:\\Game_Datapath_V2\\vitis_game_v2\\platformgame_platform_v2\\zynq_fsbl\\zynq_fsbl_bsp\\lib\\libxilrsa.a"
  "E:\\Game_Datapath_V2\\vitis_game_v2\\platformgame_platform_v2\\zynq_fsbl\\zynq_fsbl_bsp\\lib\\libxiltimer.a"
  )
endif()
