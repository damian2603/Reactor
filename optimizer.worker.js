/* Reactor Studio 4.1 — worker restored from exact optimizer functions in index.html. */
'use strict';
importScripts('./fuel_data.js?v=20261023');
const DB={"fuels":[["TBU","thorium",120,18],["LEU-235","uranium",240,50],["LEU-233","uranium",288,60],["HEU-235","uranium",960,300],["HEU-233","uranium",1152,360],["MIX-239","mixed",310,57.5],["MIX-241","mixed",468,97.5],["LEN-236","neptunium",180,36],["HEN-236","neptunium",720,216],["LEP-239","plutonium",210,40],["LEP-241","plutonium",330,70],["HEP-239","plutonium",840,240],["HEP-241","plutonium",1320,420],["LEA-242","americium",384,94],["HEA-242","americium",1536,564],["LECM-243","curium",420,112],["LECM-245","curium",324,68],["LECM-247","curium",276,54],["HECM-243","curium",1680,672],["HECM-245","curium",1296,408],["HECM-247","curium",1104,324],["LEB-248","berkelium",270,52],["HEB-248","berkelium",1080,312],["LECF-249","californium",432,116],["LECF-251","californium",450,120],["HECF-249","californium",1728,696],["HECF-251","californium",1800,720],["XEN-298","xenorium",4536,768]],"sinks":{"tin":[120,["lapis_heat_sink-2"]],"iron":[80,["gold_heat_sink"]],"gold":[120,["water_heat_sink","redstone_heat_sink"]],"lead":[60,["iron_heat_sink"]],"water":[60,["fission_reactor_solid_fuel_cell|#nuclearcraft:moderators"]],"slime":[145,["water_heat_sink","lead_heat_sink"]],"boron":[160,["quartz_heat_sink","#nuclearcraft:fission_reactor_casing|#nuclearcraft:moderators"]],"empty":[0,[]],"lapis":[120,["fission_reactor_solid_fuel_cell","#nuclearcraft:fission_reactor_casing"]],"silver":[170,["glowstone_heat_sink>2","tin_heat_sink|fission_reactor_irradiation_chamber"]],"quartz":[90,["#nuclearcraft:moderators"]],"purpur":[95,["#nuclearcraft:fission_reactor_casing","iron_heat_sink"]],"cobalt":[75,["fission_reactor_irradiation_chamber"]],"copper":[80,["glowstone_heat_sink"]],"diamond":[150,["water_heat_sink","quartz_heat_sink"]],"arsenic":[135,["#nuclearcraft:moderators>3"]],"emerald":[160,["fission_reactor_solid_fuel_cell","#nuclearcraft:moderators"]],"lithium":[130,["lead_heat_sink-2"]],"platinum":[180,["fission_reactor_irradiation_chamber","#nuclearcraft:moderators"]],"redstone":[90,["fission_reactor_solid_fuel_cell"]],"fluorite":[160,["gold_heat_sink","prismarine_heat_sink"]],"obsidian":[40,["glowstone_heat_sink-2"]],"enderium":[120,["#nuclearcraft:fission_reactor_casing^3"]],"aluminum":[175,["quartz_heat_sink","lapis_heat_sink"]],"magnesium":[110,["#nuclearcraft:fission_reactor_casing","#nuclearcraft:moderators"]],"cryotheum":[160,["fission_reactor_solid_fuel_cell>2"]],"glowstone":[130,["#nuclearcraft:moderators>2"]],"manganese":[150,["fission_reactor_solid_fuel_cell>2"]],"end_stone":[40,["enderium_heat_sink"]],"netherite":[150,["obsidian_heat_sink","fission_reactor_irradiation_chamber"]],"carobbiite":[140,["end_stone_heat_sink","fission_reactor_irradiation_chamber"]],"prismarine":[115,["water_heat_sink"]],"villiaumite":[180,["redstone_heat_sink","end_stone_heat_sink"]],"active_water":[250,["fission_reactor_solid_fuel_cell|#nuclearcraft:moderators"]],"nether_brick":[70,["obsidian_heat_sink"]],"empty_active":[0,[]],"liquid_helium":[140,["redstone_heat_sink","#nuclearcraft:fission_reactor_casing"]],"active_redstone":[270,["fission_reactor_solid_fuel_cell"]],"active_enderium":[360,["#nuclearcraft:fission_reactor_casing^3"]],"liquid_nitrogen":[185,["copper_heat_sink","purpur_heat_sink"]],"active_cryotheum":[480,["fission_reactor_solid_fuel_cell>2"]],"active_liquid_helium":[420,["redstone_heat_sink","#nuclearcraft:fission_reactor_casing"]],"active_liquid_nitrogen":[555,["copper_heat_sink","purpur_heat_sink"]]},"presets":[{"id":"HEU235_5x7x5_13_LINII_4_FUEL_MBTool","name":"5×7×5 · 13 linii","desc":"4 Fuel Cells, 7 Irradiatorów","dims":[3,5,3],"grid":["I","boron","enderium","boron",".","boron","enderium","boron","enderium","M","quartz","boron","quartz","diamond","quartz","boron","quartz","boron","F","M","I","M","water","M","I","M","F","M","arsenic","M","arsenic","prismarine","arsenic","M","arsenic","M","I","M","F","M","arsenic","M","F","M","I"],"wall":[[0,0,0,"nuclearcraft:fission_reactor_casing"],[1,0,0,"nuclearcraft:fission_reactor_casing"],[2,0,0,"nuclearcraft:fission_reactor_casing"],[3,0,0,"nuclearcraft:fission_reactor_casing"],[4,0,0,"nuclearcraft:fission_reactor_casing"],[0,0,1,"nuclearcraft:fission_reactor_casing"],[1,0,1,"nuclearcraft:fission_reactor_casing"],[2,0,1,"nuclearcraft:fission_reactor_casing"],[3,0,1,"nuclearcraft:fission_reactor_casing"],[4,0,1,"nuclearcraft:fission_reactor_casing"],[0,0,2,"nuclearcraft:fission_reactor_casing"],[1,0,2,"nuclearcraft:fission_reactor_casing"],[2,0,2,"nuclearcraft:fission_reactor_casing"],[3,0,2,"nuclearcraft:fission_reactor_casing"],[4,0,2,"nuclearcraft:fission_reactor_casing"],[0,0,3,"nuclearcraft:fission_reactor_casing"],[1,0,3,"nuclearcraft:fission_reactor_casing"],[2,0,3,"nuclearcraft:fission_reactor_casing"],[3,0,3,"nuclearcraft:fission_reactor_casing"],[4,0,3,"nuclearcraft:fission_reactor_casing"],[0,0,4,"nuclearcraft:fission_reactor_casing"],[1,0,4,"nuclearcraft:fission_reactor_casing"],[2,0,4,"nuclearcraft:fission_reactor_casing"],[3,0,4,"nuclearcraft:fission_reactor_casing"],[4,0,4,"nuclearcraft:fission_reactor_casing"],[0,1,0,"nuclearcraft:fission_reactor_casing"],[1,1,0,"nuclearcraft:irradiator"],[2,1,0,"nuclearcraft:irradiator"],[3,1,0,"nuclearcraft:irradiator"],[4,1,0,"nuclearcraft:fission_reactor_casing"],[0,1,1,"nuclearcraft:fission_reactor_casing"],[4,1,1,"nuclearcraft:fission_reactor_casing"],[0,1,2,"nuclearcraft:fission_reactor_casing"],[4,1,2,"nuclearcraft:fission_reactor_casing"],[0,1,3,"nuclearcraft:fission_reactor_casing"],[4,1,3,"nuclearcraft:fission_reactor_casing"],[0,1,4,"nuclearcraft:fission_reactor_casing"],[1,1,4,"nuclearcraft:fission_reactor_casing"],[2,1,4,"nuclearcraft:fission_reactor_casing"],[3,1,4,"nuclearcraft:fission_reactor_casing"],[4,1,4,"nuclearcraft:fission_reactor_casing"],[0,2,0,"nuclearcraft:fission_reactor_casing"],[1,2,0,"nuclearcraft:irradiator"],[2,2,0,"nuclearcraft:fission_reactor_casing"],[3,2,0,"nuclearcraft:irradiator"],[4,2,0,"nuclearcraft:fission_reactor_casing"],[0,2,1,"nuclearcraft:fission_reactor_casing"],[4,2,1,"nuclearcraft:fission_reactor_casing"],[0,2,2,"nuclearcraft:fission_reactor_casing"],[4,2,2,"nuclearcraft:fission_reactor_casing"],[0,2,3,"nuclearcraft:fission_reactor_casing"],[4,2,3,"nuclearcraft:fission_reactor_casing"],[0,2,4,"nuclearcraft:fission_reactor_casing"],[1,2,4,"nuclearcraft:fission_reactor_casing"],[2,2,4,"nuclearcraft:fission_reactor_casing"],[3,2,4,"nuclearcraft:fission_reactor_casing"],[4,2,4,"nuclearcraft:fission_reactor_casing"],[0,3,0,"nuclearcraft:fission_reactor_casing"],[1,3,0,"nuclearcraft:irradiator"],[2,3,0,"nuclearcraft:fission_reactor_controller"],[3,3,0,"nuclearcraft:irradiator"],[4,3,0,"nuclearcraft:fission_reactor_casing"],[0,3,1,"nuclearcraft:fission_reactor_casing"],[4,3,1,"nuclearcraft:fission_reactor_casing"],[0,3,2,"nuclearcraft:fission_reactor_casing"],[4,3,2,"nuclearcraft:fission_reactor_casing"],[0,3,3,"nuclearcraft:fission_reactor_casing"],[4,3,3,"nuclearcraft:fission_reactor_casing"],[0,3,4,"nuclearcraft:fission_reactor_casing"],[1,3,4,"nuclearcraft:fission_reactor_port"],[2,3,4,"nuclearcraft:fission_reactor_port"],[3,3,4,"nuclearcraft:fission_reactor_casing"],[4,3,4,"nuclearcraft:fission_reactor_casing"],[0,4,0,"nuclearcraft:fission_reactor_casing"],[1,4,0,"nuclearcraft:fission_reactor_casing"],[2,4,0,"nuclearcraft:fission_reactor_casing"],[3,4,0,"nuclearcraft:fission_reactor_casing"],[4,4,0,"nuclearcraft:fission_reactor_casing"],[0,4,1,"nuclearcraft:fission_reactor_casing"],[4,4,1,"nuclearcraft:fission_reactor_casing"],[0,4,2,"nuclearcraft:fission_reactor_casing"],[4,4,2,"nuclearcraft:fission_reactor_casing"],[0,4,3,"nuclearcraft:fission_reactor_casing"],[4,4,3,"nuclearcraft:fission_reactor_casing"],[0,4,4,"nuclearcraft:fission_reactor_casing"],[1,4,4,"nuclearcraft:fission_reactor_casing"],[2,4,4,"nuclearcraft:fission_reactor_casing"],[3,4,4,"nuclearcraft:fission_reactor_casing"],[4,4,4,"nuclearcraft:fission_reactor_casing"],[0,5,0,"nuclearcraft:fission_reactor_casing"],[1,5,0,"nuclearcraft:fission_reactor_casing"],[2,5,0,"nuclearcraft:fission_reactor_casing"],[3,5,0,"nuclearcraft:fission_reactor_casing"],[4,5,0,"nuclearcraft:fission_reactor_casing"],[0,5,1,"nuclearcraft:fission_reactor_casing"],[4,5,1,"nuclearcraft:fission_reactor_casing"],[0,5,2,"nuclearcraft:fission_reactor_casing"],[4,5,2,"nuclearcraft:fission_reactor_casing"],[0,5,3,"nuclearcraft:fission_reactor_casing"],[4,5,3,"nuclearcraft:fission_reactor_casing"],[0,5,4,"nuclearcraft:fission_reactor_casing"],[1,5,4,"nuclearcraft:fission_reactor_casing"],[2,5,4,"nuclearcraft:fission_reactor_casing"],[3,5,4,"nuclearcraft:fission_reactor_casing"],[4,5,4,"nuclearcraft:fission_reactor_casing"],[0,6,0,"nuclearcraft:fission_reactor_casing"],[1,6,0,"nuclearcraft:fission_reactor_casing"],[2,6,0,"nuclearcraft:fission_reactor_casing"],[3,6,0,"nuclearcraft:fission_reactor_casing"],[4,6,0,"nuclearcraft:fission_reactor_casing"],[0,6,1,"nuclearcraft:fission_reactor_casing"],[1,6,1,"nuclearcraft:fission_reactor_casing"],[2,6,1,"nuclearcraft:fission_reactor_casing"],[3,6,1,"nuclearcraft:fission_reactor_casing"],[4,6,1,"nuclearcraft:fission_reactor_casing"],[0,6,2,"nuclearcraft:fission_reactor_casing"],[1,6,2,"nuclearcraft:fission_reactor_casing"],[2,6,2,"nuclearcraft:fission_reactor_casing"],[3,6,2,"nuclearcraft:fission_reactor_casing"],[4,6,2,"nuclearcraft:fission_reactor_casing"],[0,6,3,"nuclearcraft:fission_reactor_casing"],[1,6,3,"nuclearcraft:fission_reactor_casing"],[2,6,3,"nuclearcraft:fission_reactor_casing"],[3,6,3,"nuclearcraft:fission_reactor_casing"],[4,6,3,"nuclearcraft:fission_reactor_casing"],[0,6,4,"nuclearcraft:fission_reactor_casing"],[1,6,4,"nuclearcraft:fission_reactor_casing"],[2,6,4,"nuclearcraft:fission_reactor_casing"],[3,6,4,"nuclearcraft:fission_reactor_casing"],[4,6,4,"nuclearcraft:fission_reactor_casing"]],"irradiators":7},{"id":"NC_HEU235_5x7x5_4F_12L_8IRR_MBTool","name":"5×7×5 · 12 linii","desc":"4 Fuel Cells, 8 Irradiatorów","dims":[3,5,3],"grid":["I","boron","enderium","boron",".","boron","enderium","boron","enderium","M","quartz","boron","quartz","diamond","quartz","boron","quartz","boron","F","boron","I","M","water","M","I","M","F","M","arsenic","M","arsenic","prismarine","arsenic","M","arsenic","M","I","M","F","M","arsenic","M","F","M","I"],"wall":[[0,0,0,"nuclearcraft:fission_reactor_casing"],[1,0,0,"nuclearcraft:fission_reactor_casing"],[2,0,0,"nuclearcraft:fission_reactor_casing"],[3,0,0,"nuclearcraft:fission_reactor_casing"],[4,0,0,"nuclearcraft:fission_reactor_casing"],[0,0,1,"nuclearcraft:fission_reactor_casing"],[1,0,1,"nuclearcraft:fission_reactor_casing"],[2,0,1,"nuclearcraft:fission_reactor_casing"],[3,0,1,"nuclearcraft:fission_reactor_casing"],[4,0,1,"nuclearcraft:fission_reactor_casing"],[0,0,2,"nuclearcraft:fission_reactor_casing"],[1,0,2,"nuclearcraft:fission_reactor_casing"],[2,0,2,"nuclearcraft:fission_reactor_casing"],[3,0,2,"nuclearcraft:fission_reactor_casing"],[4,0,2,"nuclearcraft:fission_reactor_casing"],[0,0,3,"nuclearcraft:fission_reactor_casing"],[1,0,3,"nuclearcraft:fission_reactor_casing"],[2,0,3,"nuclearcraft:fission_reactor_casing"],[3,0,3,"nuclearcraft:fission_reactor_casing"],[4,0,3,"nuclearcraft:fission_reactor_casing"],[0,0,4,"nuclearcraft:fission_reactor_casing"],[1,0,4,"nuclearcraft:fission_reactor_casing"],[2,0,4,"nuclearcraft:fission_reactor_casing"],[3,0,4,"nuclearcraft:fission_reactor_casing"],[4,0,4,"nuclearcraft:fission_reactor_casing"],[0,1,0,"nuclearcraft:fission_reactor_casing"],[1,1,0,"nuclearcraft:irradiator"],[2,1,0,"nuclearcraft:irradiator"],[3,1,0,"nuclearcraft:irradiator"],[4,1,0,"nuclearcraft:fission_reactor_casing"],[0,1,1,"nuclearcraft:fission_reactor_casing"],[4,1,1,"nuclearcraft:fission_reactor_casing"],[0,1,2,"nuclearcraft:fission_reactor_casing"],[4,1,2,"nuclearcraft:fission_reactor_casing"],[0,1,3,"nuclearcraft:fission_reactor_casing"],[4,1,3,"nuclearcraft:fission_reactor_casing"],[0,1,4,"nuclearcraft:fission_reactor_casing"],[1,1,4,"nuclearcraft:fission_reactor_casing"],[2,1,4,"nuclearcraft:fission_reactor_casing"],[3,1,4,"nuclearcraft:fission_reactor_casing"],[4,1,4,"nuclearcraft:fission_reactor_casing"],[0,2,0,"nuclearcraft:fission_reactor_casing"],[1,2,0,"nuclearcraft:irradiator"],[2,2,0,"nuclearcraft:fission_reactor_casing"],[3,2,0,"nuclearcraft:irradiator"],[4,2,0,"nuclearcraft:fission_reactor_casing"],[0,2,1,"nuclearcraft:fission_reactor_casing"],[4,2,1,"nuclearcraft:fission_reactor_casing"],[0,2,2,"nuclearcraft:fission_reactor_casing"],[4,2,2,"nuclearcraft:fission_reactor_casing"],[0,2,3,"nuclearcraft:fission_reactor_casing"],[4,2,3,"nuclearcraft:fission_reactor_casing"],[0,2,4,"nuclearcraft:fission_reactor_casing"],[1,2,4,"nuclearcraft:fission_reactor_casing"],[2,2,4,"nuclearcraft:fission_reactor_casing"],[3,2,4,"nuclearcraft:fission_reactor_casing"],[4,2,4,"nuclearcraft:fission_reactor_casing"],[0,3,0,"nuclearcraft:fission_reactor_casing"],[1,3,0,"nuclearcraft:irradiator"],[2,3,0,"nuclearcraft:fission_reactor_controller"],[3,3,0,"nuclearcraft:irradiator"],[4,3,0,"nuclearcraft:fission_reactor_casing"],[0,3,1,"nuclearcraft:fission_reactor_casing"],[4,3,1,"nuclearcraft:fission_reactor_casing"],[0,3,2,"nuclearcraft:fission_reactor_casing"],[4,3,2,"nuclearcraft:fission_reactor_casing"],[0,3,3,"nuclearcraft:fission_reactor_casing"],[4,3,3,"nuclearcraft:fission_reactor_casing"],[0,3,4,"nuclearcraft:fission_reactor_casing"],[1,3,4,"nuclearcraft:fission_reactor_port"],[2,3,4,"nuclearcraft:fission_reactor_port"],[3,3,4,"nuclearcraft:fission_reactor_casing"],[4,3,4,"nuclearcraft:fission_reactor_casing"],[0,4,0,"nuclearcraft:fission_reactor_casing"],[1,4,0,"nuclearcraft:irradiator"],[2,4,0,"nuclearcraft:fission_reactor_casing"],[3,4,0,"nuclearcraft:fission_reactor_casing"],[4,4,0,"nuclearcraft:fission_reactor_casing"],[0,4,1,"nuclearcraft:fission_reactor_casing"],[4,4,1,"nuclearcraft:fission_reactor_casing"],[0,4,2,"nuclearcraft:fission_reactor_casing"],[4,4,2,"nuclearcraft:fission_reactor_casing"],[0,4,3,"nuclearcraft:fission_reactor_casing"],[4,4,3,"nuclearcraft:fission_reactor_casing"],[0,4,4,"nuclearcraft:fission_reactor_casing"],[1,4,4,"nuclearcraft:fission_reactor_casing"],[2,4,4,"nuclearcraft:fission_reactor_casing"],[3,4,4,"nuclearcraft:fission_reactor_casing"],[4,4,4,"nuclearcraft:fission_reactor_casing"],[0,5,0,"nuclearcraft:fission_reactor_casing"],[1,5,0,"nuclearcraft:fission_reactor_casing"],[2,5,0,"nuclearcraft:fission_reactor_casing"],[3,5,0,"nuclearcraft:fission_reactor_casing"],[4,5,0,"nuclearcraft:fission_reactor_casing"],[0,5,1,"nuclearcraft:fission_reactor_casing"],[4,5,1,"nuclearcraft:fission_reactor_casing"],[0,5,2,"nuclearcraft:fission_reactor_casing"],[4,5,2,"nuclearcraft:fission_reactor_casing"],[0,5,3,"nuclearcraft:fission_reactor_casing"],[4,5,3,"nuclearcraft:fission_reactor_casing"],[0,5,4,"nuclearcraft:fission_reactor_casing"],[1,5,4,"nuclearcraft:fission_reactor_casing"],[2,5,4,"nuclearcraft:fission_reactor_casing"],[3,5,4,"nuclearcraft:fission_reactor_casing"],[4,5,4,"nuclearcraft:fission_reactor_casing"],[0,6,0,"nuclearcraft:fission_reactor_casing"],[1,6,0,"nuclearcraft:fission_reactor_casing"],[2,6,0,"nuclearcraft:fission_reactor_casing"],[3,6,0,"nuclearcraft:fission_reactor_casing"],[4,6,0,"nuclearcraft:fission_reactor_casing"],[0,6,1,"nuclearcraft:fission_reactor_casing"],[1,6,1,"nuclearcraft:fission_reactor_casing"],[2,6,1,"nuclearcraft:fission_reactor_casing"],[3,6,1,"nuclearcraft:fission_reactor_casing"],[4,6,1,"nuclearcraft:fission_reactor_casing"],[0,6,2,"nuclearcraft:fission_reactor_casing"],[1,6,2,"nuclearcraft:fission_reactor_casing"],[2,6,2,"nuclearcraft:fission_reactor_casing"],[3,6,2,"nuclearcraft:fission_reactor_casing"],[4,6,2,"nuclearcraft:fission_reactor_casing"],[0,6,3,"nuclearcraft:fission_reactor_casing"],[1,6,3,"nuclearcraft:fission_reactor_casing"],[2,6,3,"nuclearcraft:fission_reactor_casing"],[3,6,3,"nuclearcraft:fission_reactor_casing"],[4,6,3,"nuclearcraft:fission_reactor_casing"],[0,6,4,"nuclearcraft:fission_reactor_casing"],[1,6,4,"nuclearcraft:fission_reactor_casing"],[2,6,4,"nuclearcraft:fission_reactor_casing"],[3,6,4,"nuclearcraft:fission_reactor_casing"],[4,6,4,"nuclearcraft:fission_reactor_casing"]],"irradiators":8},{"id":"NC_HEU235_5x7x5_4F_11L_10IRR_MBTool","name":"5×7×5 · 11 linii","desc":"4 Fuel Cells, 10 Irradiatorów","dims":[3,5,3],"grid":["I","boron","enderium","boron",".","boron","enderium","boron","enderium","M","quartz","boron","quartz","diamond","quartz","boron","quartz","boron","F","boron","I","boron","water","M","I","M","F","M","arsenic","M","arsenic","prismarine","arsenic","M","arsenic","M","I","M","F","M","arsenic","M","F","M","I"],"wall":[[0,0,0,"nuclearcraft:fission_reactor_casing"],[1,0,0,"nuclearcraft:fission_reactor_casing"],[2,0,0,"nuclearcraft:fission_reactor_casing"],[3,0,0,"nuclearcraft:fission_reactor_casing"],[4,0,0,"nuclearcraft:fission_reactor_casing"],[0,0,1,"nuclearcraft:fission_reactor_casing"],[1,0,1,"nuclearcraft:fission_reactor_casing"],[2,0,1,"nuclearcraft:fission_reactor_casing"],[3,0,1,"nuclearcraft:fission_reactor_casing"],[4,0,1,"nuclearcraft:fission_reactor_casing"],[0,0,2,"nuclearcraft:fission_reactor_casing"],[1,0,2,"nuclearcraft:fission_reactor_casing"],[2,0,2,"nuclearcraft:fission_reactor_casing"],[3,0,2,"nuclearcraft:fission_reactor_casing"],[4,0,2,"nuclearcraft:fission_reactor_casing"],[0,0,3,"nuclearcraft:fission_reactor_casing"],[1,0,3,"nuclearcraft:fission_reactor_casing"],[2,0,3,"nuclearcraft:fission_reactor_casing"],[3,0,3,"nuclearcraft:fission_reactor_casing"],[4,0,3,"nuclearcraft:fission_reactor_casing"],[0,0,4,"nuclearcraft:fission_reactor_casing"],[1,0,4,"nuclearcraft:fission_reactor_casing"],[2,0,4,"nuclearcraft:fission_reactor_casing"],[3,0,4,"nuclearcraft:fission_reactor_casing"],[4,0,4,"nuclearcraft:fission_reactor_casing"],[0,1,0,"nuclearcraft:fission_reactor_casing"],[1,1,0,"nuclearcraft:irradiator"],[2,1,0,"nuclearcraft:irradiator"],[3,1,0,"nuclearcraft:irradiator"],[4,1,0,"nuclearcraft:fission_reactor_casing"],[0,1,1,"nuclearcraft:fission_reactor_casing"],[4,1,1,"nuclearcraft:fission_reactor_casing"],[0,1,2,"nuclearcraft:fission_reactor_casing"],[4,1,2,"nuclearcraft:fission_reactor_casing"],[0,1,3,"nuclearcraft:fission_reactor_casing"],[4,1,3,"nuclearcraft:fission_reactor_casing"],[0,1,4,"nuclearcraft:fission_reactor_casing"],[1,1,4,"nuclearcraft:fission_reactor_casing"],[2,1,4,"nuclearcraft:fission_reactor_casing"],[3,1,4,"nuclearcraft:fission_reactor_casing"],[4,1,4,"nuclearcraft:fission_reactor_casing"],[0,2,0,"nuclearcraft:fission_reactor_casing"],[1,2,0,"nuclearcraft:irradiator"],[2,2,0,"nuclearcraft:fission_reactor_casing"],[3,2,0,"nuclearcraft:irradiator"],[4,2,0,"nuclearcraft:fission_reactor_casing"],[0,2,1,"nuclearcraft:fission_reactor_casing"],[4,2,1,"nuclearcraft:fission_reactor_casing"],[0,2,2,"nuclearcraft:fission_reactor_casing"],[4,2,2,"nuclearcraft:fission_reactor_casing"],[0,2,3,"nuclearcraft:fission_reactor_casing"],[4,2,3,"nuclearcraft:fission_reactor_casing"],[0,2,4,"nuclearcraft:fission_reactor_casing"],[1,2,4,"nuclearcraft:fission_reactor_casing"],[2,2,4,"nuclearcraft:fission_reactor_casing"],[3,2,4,"nuclearcraft:fission_reactor_casing"],[4,2,4,"nuclearcraft:fission_reactor_casing"],[0,3,0,"nuclearcraft:fission_reactor_casing"],[1,3,0,"nuclearcraft:irradiator"],[2,3,0,"nuclearcraft:fission_reactor_controller"],[3,3,0,"nuclearcraft:irradiator"],[4,3,0,"nuclearcraft:fission_reactor_casing"],[0,3,1,"nuclearcraft:fission_reactor_casing"],[4,3,1,"nuclearcraft:fission_reactor_casing"],[0,3,2,"nuclearcraft:fission_reactor_casing"],[4,3,2,"nuclearcraft:fission_reactor_casing"],[0,3,3,"nuclearcraft:fission_reactor_casing"],[4,3,3,"nuclearcraft:fission_reactor_casing"],[0,3,4,"nuclearcraft:fission_reactor_casing"],[1,3,4,"nuclearcraft:fission_reactor_port"],[2,3,4,"nuclearcraft:fission_reactor_port"],[3,3,4,"nuclearcraft:fission_reactor_casing"],[4,3,4,"nuclearcraft:fission_reactor_casing"],[0,4,0,"nuclearcraft:fission_reactor_casing"],[1,4,0,"nuclearcraft:irradiator"],[2,4,0,"nuclearcraft:irradiator"],[3,4,0,"nuclearcraft:irradiator"],[4,4,0,"nuclearcraft:fission_reactor_casing"],[0,4,1,"nuclearcraft:fission_reactor_casing"],[4,4,1,"nuclearcraft:fission_reactor_casing"],[0,4,2,"nuclearcraft:fission_reactor_casing"],[4,4,2,"nuclearcraft:fission_reactor_casing"],[0,4,3,"nuclearcraft:fission_reactor_casing"],[4,4,3,"nuclearcraft:fission_reactor_casing"],[0,4,4,"nuclearcraft:fission_reactor_casing"],[1,4,4,"nuclearcraft:fission_reactor_casing"],[2,4,4,"nuclearcraft:fission_reactor_casing"],[3,4,4,"nuclearcraft:fission_reactor_casing"],[4,4,4,"nuclearcraft:fission_reactor_casing"],[0,5,0,"nuclearcraft:fission_reactor_casing"],[1,5,0,"nuclearcraft:fission_reactor_casing"],[2,5,0,"nuclearcraft:fission_reactor_casing"],[3,5,0,"nuclearcraft:fission_reactor_casing"],[4,5,0,"nuclearcraft:fission_reactor_casing"],[0,5,1,"nuclearcraft:fission_reactor_casing"],[4,5,1,"nuclearcraft:fission_reactor_casing"],[0,5,2,"nuclearcraft:fission_reactor_casing"],[4,5,2,"nuclearcraft:fission_reactor_casing"],[0,5,3,"nuclearcraft:fission_reactor_casing"],[4,5,3,"nuclearcraft:fission_reactor_casing"],[0,5,4,"nuclearcraft:fission_reactor_casing"],[1,5,4,"nuclearcraft:fission_reactor_casing"],[2,5,4,"nuclearcraft:fission_reactor_casing"],[3,5,4,"nuclearcraft:fission_reactor_casing"],[4,5,4,"nuclearcraft:fission_reactor_casing"],[0,6,0,"nuclearcraft:fission_reactor_casing"],[1,6,0,"nuclearcraft:fission_reactor_casing"],[2,6,0,"nuclearcraft:fission_reactor_casing"],[3,6,0,"nuclearcraft:fission_reactor_casing"],[4,6,0,"nuclearcraft:fission_reactor_casing"],[0,6,1,"nuclearcraft:fission_reactor_casing"],[1,6,1,"nuclearcraft:fission_reactor_casing"],[2,6,1,"nuclearcraft:fission_reactor_casing"],[3,6,1,"nuclearcraft:fission_reactor_casing"],[4,6,1,"nuclearcraft:fission_reactor_casing"],[0,6,2,"nuclearcraft:fission_reactor_casing"],[1,6,2,"nuclearcraft:fission_reactor_casing"],[2,6,2,"nuclearcraft:fission_reactor_casing"],[3,6,2,"nuclearcraft:fission_reactor_casing"],[4,6,2,"nuclearcraft:fission_reactor_casing"],[0,6,3,"nuclearcraft:fission_reactor_casing"],[1,6,3,"nuclearcraft:fission_reactor_casing"],[2,6,3,"nuclearcraft:fission_reactor_casing"],[3,6,3,"nuclearcraft:fission_reactor_casing"],[4,6,3,"nuclearcraft:fission_reactor_casing"],[0,6,4,"nuclearcraft:fission_reactor_casing"],[1,6,4,"nuclearcraft:fission_reactor_casing"],[2,6,4,"nuclearcraft:fission_reactor_casing"],[3,6,4,"nuclearcraft:fission_reactor_casing"],[4,6,4,"nuclearcraft:fission_reactor_casing"]],"irradiators":10}],"fixtures":[{"name":"6×6×6","dims":[4,4,4],"grid":["boron","F","M","I","I","M","quartz","boron","end_stone","I","redstone","liquid_helium","enderium","boron","I","boron","quartz","M","liquid_helium","M","M","arsenic","redstone","liquid_helium","I","M","F","boron","boron","quartz","M","quartz","boron","I","M","F","F","M","I","M","M","arsenic","M","I","I","M","F","boron","I","boron","quartz","boron","M","arsenic","boron","quartz","F","M","I","boron","boron","quartz","boron","enderium"],"expected":{"lines":17,"cooling":4155,"heat":3954.9999999999995},"origin":"Designer z gry"},{"name":"7×7×7","dims":[5,5,5],"grid":["I","boron","fluorite","gold","redstone","cryotheum","I","prismarine","water","F","F","lapis","I","platinum","lapis","redstone","villiaumite","platinum","redstone","liquid_helium","enderium","end_stone","boron","liquid_helium","enderium","M","quartz","boron","fluorite","gold","F","M","I","I","water","M","I","M","M","platinum","I","I","M","F","emerald","boron","boron","quartz","aluminum","lapis","F","cryotheum","I","prismarine","fluorite","M","F","M","I","prismarine","I","M","F","M","I","M","I","M","M","M","quartz","boron","I","M","F","M","I","boron","water","M","I","M","F","M","I","cryotheum","F","M","I","lapis","F","M","I","I","platinum","boron","I","boron","quartz","boron","I","boron","quartz","boron","I",".","I","M","arsenic","M","liquid_helium","cryotheum","I","lapis","F","redstone","F","redstone","liquid_helium","lapis","liquid_helium","lapis","liquid_helium","boron","enderium"],"expected":{"lines":34,"cooling":8315,"heat":8110.000000000001},"origin":"wcześniejszy schemat kontrolny"}]};
DB.fuels=globalThis.NC_FUEL_CATALOG || DB.fuels;
const SINKS=DB.sinks, PRESETS=DB.presets;
const DIR=[[1,0,0],[-1,0,0],[0,1,0],[0,-1,0],[0,0,1],[0,0,-1]];
const passive=Object.keys(SINKS).filter(t=>SINKS[t][0]>0&&!t.startsWith('active_'));
const activeTypes=Object.keys(SINKS).filter(t=>t.startsWith('active_')&&SINKS[t][0]>0);
const clamp=(v,a,b)=>Math.min(b,Math.max(a,v));
const key=p=>p.join(',');
function idx(x,y,z,w,d){return y*w*d+z*w+x}
function wallsForDims(dims,irr){const [iw,ih,id]=dims,[w,h,d]=dims.map(x=>x+2),wall={};
 for(let y=0;y<h;y++)for(let z=0;z<d;z++)for(let x=0;x<w;x++)if(x===0||y===0||z===0||x===w-1||y===h-1||z===d-1)wall[key([x,y,z])]='R';
 const controller=[Math.floor(w/2),Math.floor(h/2),0],ports=[[Math.floor(w/2),Math.floor(h/2),d-1],[1,Math.floor(h/2),d-1]];
 wall[key(controller)]='C';for(const p of ports)wall[key(p)]='P';
 const candidates=[];
 for(let y=1;y<h-1;y++)for(let z=0;z<d;z++)for(let x=0;x<w;x++)if(wall[key([x,y,z])]==='R'&&((x>0&&x<w-1&&(z===0||z===d-1))||(z>0&&z<d-1&&(x===0||x===w-1))))candidates.push([x,y,z]);
 for(let z=1;z<d-1;z++)for(let x=1;x<w-1;x++)for(const y of [0,h-1])if(wall[key([x,y,z])]==='R')candidates.push([x,y,z]);
 for(const p of candidates.slice(0,Math.max(0,irr)))wall[key(p)]='A';return wall;
}
function machineSlots(dims){return Object.values(wallsForDims(dims,9999)).filter(x=>x==='A').length}
function neighbor(i,w,h,d){let z=Math.floor(i/w)%d,y=Math.floor(i/(w*d)),x=i%w;return DIR.map(([dx,dy,dz])=>{let a=x+dx,b=y+dy,c=z+dz;return a>=0&&b>=0&&c>=0&&a<w&&b<h&&c<d?idx(a,b,c,w,d):-1})}
function parseRule(s){const match=s.match(/([><=^\-])(\d+)$/);return {op:match?match[1]:'>',n:match?+match[2]:1,types:(match?s.slice(0,match.index):s).split('|'),casing:s.includes('casing')}}
const RULES={};
for(const [k,v] of Object.entries(SINKS))RULES[k]=v[1].map(parseRule);
const GEOM_CACHE=new Map();
function geometry(w,h,d){let id=w+','+h+','+d;if(GEOM_CACHE.has(id))return GEOM_CACHE.get(id);const N=w*h*d,coords=Array.from({length:N},(_,i)=>[i%w,Math.floor(i/(w*d)),Math.floor(i/w)%d]),nb=coords.map((_,i)=>neighbor(i,w,h,d));let triads=orientedTriads(w,h,d);let data={coords,nb,triads};GEOM_CACHE.set(id,data);return data}
function simulation(g,w,h,d,p){const N=g.length,{coords,nb}=geometry(w,h,d);const fs=[],ms=[],ics=[],sinks=[];
 for(let i=0;i<N;i++){let t=g[i];if(t==='F')fs.push(i);else if(t==='M')ms.push(i);else if(t==='I')ics.push(i);else if(SINKS[t]&&SINKS[t][0]>0)sinks.push(i)}
 const fuelSet=new Set(fs),modSet=new Set(ms),activeM=new Set(ms.filter(i=>nb[i].some(j=>fuelSet.has(j))));
 const direct=new Set();for(let i of [...fs,...activeM]){direct.add(i);for(let j of nb[i])if(j>=0)direct.add(j)}
 let lines=0,badI=[],linePerI={},iBase=0;for(let i of ics){let n=0;let [x,y,z]=coords[i];for(let [dx,dy,dz] of DIR){let ax=x+dx,ay=y+dy,az=z+dz,bx=x+2*dx,by=y+2*dy,bz=z+2*dz;if(bx<0||bx>=w||by<0||by>=h||bz<0||bz>=d)continue;let mid=idx(ax,ay,az,w,d),end=idx(bx,by,bz,w,d);if(activeM.has(mid)&&fuelSet.has(end))n++}linePerI[i]=n;lines+=n;if(!n)badI.push(i)}
 let heatMult=0,energyMult=0,mh=0,me=0;for(let f of fs){let [x,y,z]=coords[f],extra=0;for(const [dx,dy,dz] of DIR){for(let dist=1;dist<=4;dist++){let ax=x+dx*dist,ay=y+dy*dist,az=z+dz*dist;if(ax<0||ay<0||az<0||ax>=w||ay>=h||az>=d)break;const t=g[idx(ax,ay,az,w,d)];if(t==='F'){extra++;break}if(t==='M'){let bx=x+dx*(dist+1),by=y+dy*(dist+1),bz=z+dz*(dist+1);if(bx>=0&&by>=0&&bz>=0&&bx<w&&by<h&&bz<d&&g[idx(bx,by,bz,w,d)]==='F'){extra++;break}}else break}}
  heatMult+=(extra+1)*(extra+2)/2;energyMult+=(extra+1);let adj=nb[f].filter(i=>activeM.has(i)).length;mh+=adj*(extra+1)/3;me+=adj*(extra+1)/6;}
 const valid=new Set(),second=new Set();
 function outer(i,v){let [x,y,z]=coords[i],d0=DIR[v];let a=x+d0[0],b=y+d0[1],c=z+d0[2];return a<0||b<0||c<0||a>=w||b>=h||c>=d}
 function attached(j){if(j<0)return false;return nb[j].some(n=>fuelSet.has(n)||direct.has(n)||(second.has(n)&&g[n]!=='.'))}
 function mt(i,v,t){let j=nb[i][v];if(t==='#nuclearcraft:fission_reactor_casing')return outer(i,v);if(j<0)return false;let cur=g[j];if(t==='#nuclearcraft:moderators')return activeM.has(j)&&attached(j);if(t==='fission_reactor_solid_fuel_cell')return cur==='F'&&attached(j);if(t==='fission_reactor_irradiation_chamber')return cur==='I'&&attached(j);if(t.endsWith('_heat_sink')){let name=t.slice(0,-10);return valid.has(j)&&(cur===name||cur==='active_'+name)&&attached(j)}return false}
 function matches(i,v,types){return types.some(t=>mt(i,v,t))}
 function ruleOK(i,r){if(r.op==='^'){const out=DIR.map((_,v)=>matches(i,v,r.types));return [[0,2,4],[0,2,5],[0,3,4],[0,3,5],[1,2,4],[1,2,5],[1,3,4],[1,3,5]].some(arr=>arr.every(n=>out[n]))}if(r.op==='-'){return [[0,1],[2,3],[4,5]].some(([a,b])=>matches(i,a,r.types)&&matches(i,b,r.types))}let count=DIR.reduce((n,_,v)=>n+(matches(i,v,r.types)?1:0),0);return r.op==='>'?count>=r.n:r.op==='<'?count<r.n:r.op==='='?count===r.n:false}
 function check(i){const t=g[i];return (RULES[t]||[]).every(r=>ruleOK(i,r))}
 // Valid blocks are added only after their prerequisites are valid. Dependent cycles cannot activate themselves.
 for(let pass=0;pass<N+1;pass++){let added=0;for(let i of sinks){if(valid.has(i))continue;if(check(i)){valid.add(i);second.add(i);nb[i].filter(n=>n>=0).forEach(n=>second.add(n));added++}}if(!added)break}
 // Revalidate to avoid incorrect exact/at-most neighboring checks.
 for(let pass=0;pass<Math.min(N,25);pass++){second.clear();for(const i of valid){second.add(i);for(const j of nb[i])if(j>=0)second.add(j)}let toRemove=sinks.filter(i=>valid.has(i)&&!check(i));if(!toRemove.length)break;for(const i of toRemove)valid.delete(i)}
 const badSinks=sinks.filter(i=>!valid.has(i)),badMods=ms.filter(i=>!activeM.has(i));let cooling=[...valid].reduce((n,i)=>n+SINKS[g[i]][0],0);
 const baseHeat=p.heat*(heatMult+Math.max(.1,p.moderation)*mh),radiHeat=lines*15*p.machines,heat=baseHeat+radiHeat,net=heat-cooling;
 const speed=lines*p.rate/10,recipeTicks=speed>0?Math.max(1,Math.ceil(p.recipeBaseTicks/speed)):Infinity,perMinute=Number.isFinite(recipeTicks)?1200*p.machines*p.recipeOutputCount/recipeTicks:0;
 const ratio=cooling>0?heat/Math.max(1,cooling):heat;const mult=(ratio>0?Math.max(0,Math.round((Math.log10(ratio)/(1+Math.exp(Math.min(600,ratio)))+1)*100)/100):0);
 const energy=p.power*(energyMult+me*p.moderation)*mult;
 const coolantBy={};for(let i of valid){let t=g[i];if(t.startsWith('active_'))coolantBy[t]=(coolantBy[t]||0)+10}
 const counts={};for(let t of g)if(t!=='.')counts[t]=(counts[t]||0)+1;
 return {lines,perMinute,recipeTicks,heat,baseHeat,cooling,net,radiHeat,badI,badSinks,badMods,valid,activeM,linePerI,fuelCells:fs.length,mods:ms.length,chambers:ics.length,sinks:sinks.length,counts,energy,heatMult,modHeat:mh,validCount:valid.size,coolantBy,excess:cooling-heat,limit:p.machines};
}
let rngSeed=0x92ab35dd;
function rand(){rngSeed^=rngSeed<<13;rngSeed^=rngSeed>>>17;rngSeed^=rngSeed<<5;return (rngSeed>>>0)/4294967296}
function pick(a){return a[(rand()*a.length)|0]}
function randomInt(a,b){return a+Math.floor(rand()*(b-a+1))}
function shuffle(arr){let a=arr.slice();for(let i=a.length-1;i>0;i--){let j=(rand()*(i+1))|0;[a[i],a[j]]=[a[j],a[i]]}return a}
let CURRENT_LIMITS={};
function limitFor(t){if(t==='.'||t==='F'||t==='M'||t==='I')return Infinity;return CURRENT_LIMITS[t]===undefined?9999:CURRENT_LIMITS[t]}
function orientedTriads(w,h,d){let o=[];for(let y=0;y<h;y++)for(let z=0;z<d;z++)for(let x=0;x<w;x++)for(const [dx,dy,dz] of DIR){let bx=x+2*dx,by=y+2*dy,bz=z+2*dz,ax=x+dx,ay=y+dy,az=z+dz;if(bx>=0&&by>=0&&bz>=0&&bx<w&&by<h&&bz<d)o.push([idx(x,y,z,w,d),idx(ax,ay,az,w,d),idx(bx,by,bz,w,d)])}return o}
function statsForSearch(g,dims,p){let r=simulation(g,...dims,{...p,machines:0});
 const slots=machineSlots(dims),limit=Math.min(slots,p.machines);
 const reserve=Math.max(0,p.reserve),perMachine=15*r.lines;
 let machines=limit;
 if(p.autoMachines){
  let budget=r.cooling-r.baseHeat-reserve;
  if(p.safeAtFull)budget=Math.min(budget,r.cooling-p.heat*(r.heatMult+r.modHeat)-reserve);
  machines=r.lines>0?Math.max(0,Math.min(limit,Math.floor((budget+1e-7)/perMachine))):0;
 }
 r.machines=machines;r.radiHeat=machines*perMachine;r.heat=r.baseHeat+r.radiHeat;r.net=r.heat-r.cooling;r.excess=-r.net;
 r.perMinute=Number.isFinite(r.recipeTicks)?1200*machines*p.recipeOutputCount/r.recipeTicks:0;
 r.fullHeat=p.heat*(r.heatMult+r.modHeat)+r.radiHeat;
 r.fullNet=r.fullHeat-r.cooling;
 r.invalidCount=r.badI.length+r.badSinks.length;
 const counts={};for(const t of g)counts[t]=(counts[t]||0)+1;
 r.limitsOK=r.fuelCells>0&&r.fuelCells<=p.maxFuel&&Object.entries(counts).every(([t,v])=>v<=limitFor(t));
 r.layoutOK=r.invalidCount===0&&r.limitsOK;
 r.safe=r.layoutOK&&r.lines>0&&r.machines>0&&r.net<=-reserve+1e-7&&(!p.safeAtFull||r.fullNet<=-reserve+1e-7);
 return r
}
function merit(s,p){if(!s.limitsOK||s.fuelCells<1)return -1e7-s.invalidCount*1000;
 const over=Math.max(0,s.net+p.reserve,p.safeAtFull?s.fullNet+p.reserve:0),bad=s.invalidCount;
 let target=0;
 if(p.goal==='neutronium')target=s.perMinute*65;
 else if(p.goal==='lines')target=s.lines*150;
 else if(p.goal==='energy')target=s.energy/6;
 else if(p.goal==='cooling')target=s.excess;
 else if(p.goal==='efficiency')target=s.perMinute*65-s.fuelCells*300;
 let soft=target - (Math.pow(over,0.95)*36) - (bad*1400) - 1.1*s.fuelCells -.05*s.sinks -.5*s.badMods.length;
 if(s.safe)soft+=Math.min(200,Math.max(0,-s.net-p.reserve)*0.065);
 return soft
}
function safeRank(s,p){if(!s.safe)return -Infinity;return merit(s,p)}
const NONCORE=t=>!['F','M','I'].includes(t);
function coreOnly(grid){return grid.map(t=>NONCORE(t)?'.':t)}
function removeDangling(core,dims){const [w,h,d]=dims,geo=geometry(w,h,d),g=core;
 for(let n=0;n<2;n++)for(let i=0;i<g.length;i++)if(g[i]==='M'&&!geo.nb[i].some(j=>j>=0&&g[j]==='F'))g[i]='.';
 for(let i=0;i<g.length;i++)if(g[i]==='I'){
  const [x,y,z]=geo.coords[i];let ok=false;
  for(const [dx,dy,dz] of DIR){const ax=x+dx,ay=y+dy,az=z+dz,bx=x+2*dx,by=y+2*dy,bz=z+2*dz;if(bx>=0&&by>=0&&bz>=0&&bx<w&&by<h&&bz<d&&g[idx(ax,ay,az,w,d)]==='M'&&g[idx(bx,by,bz,w,d)]==='F')ok=true}
  if(!ok)g[i]='.';
 }
 return g
}
function randomCore(dims,p){let [w,h,d]=dims,triads=shuffle(geometry(w,h,d).triads);let g=Array(w*h*d).fill('.');let target=randomInt(1,Math.max(1,Math.min(p.maxFuel,Math.ceil(g.length/5),7)));
 for(let it=0;it<90 && g.filter(t=>t==='F').length<target;it++){
  const tr=pick(triads);if(!tr)break;const [u,v,t]=tr; if(!NONCORE(g[u])&&g[u]!=='F'||!NONCORE(g[v])&&g[v]!=='M'||!NONCORE(g[t])&&g[t]!=='I')continue;
  if(g[u]!=='F'&&g.filter(t=>t==='F').length>=p.maxFuel)continue;
  if(rand()<.4&&g[t]==='.')g[t]='I';else g[t]='I';g[v]='M';g[u]='F';
 }
 if(!g.includes('F')){let t=pick(triads);if(t){g[t[0]]='F';g[t[1]]='M';g[t[2]]='I'}}return g
}
function mutateCore(parent,dims,p,energy=1){const core=coreOnly(parent),[w,h,d]=dims,triads=geometry(w,h,d).triads;let g=core.slice();if(!p.allowCore)return g;
 const nOps=energy>1?randomInt(2,6):randomInt(1,3);
 for(let t=0;t<nOps;t++){
  const mode=rand();
  if(mode<.24){ // delete or move an existing source or chamber
   let existing=[];for(let i=0;i<g.length;i++)if(['F','M','I'].includes(g[i]))existing.push(i);
   if(existing.length){let a=pick(existing);g[a]='.'}
  } else if(mode<.85){ // add proper triad, reusing existing moderator and cells
   let trial=shuffle(triads).slice(0,Math.min(90,triads.length)).filter(([f,m,c])=>(g[f]==='F'||g[f]==='.')&&(g[m]==='M'||g[m]==='.')&&(g[c]==='I'||g[c]==='.')&&(g[f]==='F'||g.filter(x=>x==='F').length<p.maxFuel));
   if(trial.length){let weighted=trial.map(a=>({a,b:(g[a[0]]==='F'?4:0)+(g[a[1]]==='M'?5:0)+(g[a[2]]==='I'?5:0)+rand()*7})).sort((a,b)=>b.b-a.b);const [f,m,c]=pick(weighted.slice(0,Math.min(7,weighted.length))).a;g[f]='F';g[m]='M';g[c]='I'}
  } else { // exchange blocks: explore different connectivity
   const a=randomInt(0,g.length-1),b=randomInt(0,g.length-1);[g[a],g[b]]=[g[b],g[a]]
  }
 }
 while(g.filter(t=>t==='F').length>p.maxFuel){let fi=[];for(let i=0;i<g.length;i++)if(g[i]==='F')fi.push(i);g[pick(fi)]='.'}
 removeDangling(g,dims);
 if(!g.includes('F'))return randomCore(dims,p);
 return g
}
function buildCooling(core,dims,p,style=0,parent=null){let [w,h,d]=dims,free=shuffle(Array.from({length:core.length},(_,i)=>i).filter(i=>core[i]==='.'));
 let options=[...passive,...(p.allowActive?activeTypes:[])].filter(t=>limitFor(t)>0);
 options.sort((a,b)=>SINKS[b][0]-SINKS[a][0]);
 let base=parent&&parent.length===core.length?parent.map((t,i)=>core[i]==='.'&&SINKS[t]&&options.includes(t)?t:core[i]):core.slice();
 let g=base.slice(),cnt={};for(const t of g)cnt[t]=(cnt[t]||0)+1;
 let r=statsForSearch(g,dims,p);
 // Dependent coolers (e.g. aluminum) only activate after their required neighbors exist.
 for(let round=0;round<2;round++){
  if(round===0)free=shuffle(free);
  for(const i of free){let old=g[i];if(old!=='.'&&rand()>.25)continue;
   let viable=[];const sampled=style%3===0?options:shuffle(options).slice(0,Math.min(options.length,style%3===1?15:9));
   for(const t of sampled){if(t===old||(cnt[t]||0)>=limitFor(t))continue;g[i]=t;const s=simulation(g,w,h,d,{...p,machines:0});if(s.valid.has(i)){
    const gain=s.cooling-(r.cooling||0);if(gain>0)viable.push([t,gain])
   }}
   g[i]=old;
   if(viable.length){viable.sort((a,b)=>b[1]-a[1]);let selected=rand()<.16?pick(viable.slice(0,Math.min(4,viable.length))):viable[0];if(old!=='.')cnt[old]--;g[i]=selected[0];cnt[selected[0]]=(cnt[selected[0]]||0)+1;r=statsForSearch(g,dims,p)}
  }
 }
 // Remove blocks that cannot cool. Exact and upper-bound placement rules can invalidate a neighbor.
 for(let step=0;step<Math.min(g.length,12);step++){let errors=r.badSinks;if(!errors.length)break;for(let i of errors){cnt[g[i]]--;g[i]='.'}r=statsForSearch(g,dims,p)}
 return {g,s:r}
}
function localCoolerSearch(seed,dims,p,steps=20){let best=seed.slice(),last=statsForSearch(best,dims,p),[w,h,d]=dims,opts=[...passive,...(p.allowActive?activeTypes:[])].filter(t=>limitFor(t)>0);
 let bestScore=merit(last,p);
 for(let q=0;q<steps;q++){
  let i=randomInt(0,best.length-1);if(['F','M','I'].includes(best[i]))continue;
  let t=pick([...opts,'.']);if(t===best[i])continue;
  if(best.filter(x=>x===t).length>=limitFor(t))continue;
  let g=best.slice();g[i]=t;let s=statsForSearch(g,dims,p);let score=merit(s,p); // keep local improvements, including escape from invalid layouts
  if(score>bestScore+0.0001){best=g;bestScore=score;last=s}
 }
 return {g:best,s:last}
}
function candidateFrom(parent,dims,p,iteration){let mode=iteration%13;
 let core;
 if(!parent||mode===0||mode===7)core=randomCore(dims,p);
 else if(mode===1||mode===4||mode===10)core=coreOnly(parent);
 else core=mutateCore(parent,dims,p,mode===3?2:1);
 const reuse=(mode===1||mode===4||mode===10)?parent:(parent&&rand()<.6?parent:null);
 let trial=buildCooling(core,dims,p,iteration,reuse);
 if(mode===1||mode===5||mode===10)trial=localCoolerSearch(trial.g,dims,p,24);
 return trial
}
const state={g:[]};
function v3SearchValue(s,p){
 const over=Math.max(0,s.net+p.reserve,p.safeAtFull?s.fullNet+p.reserve:0),bad=s.invalidCount;
 let val;
 // Reward smooth improvement towards the next whole-tick speed threshold.
 const continuousRate=(s.lines*p.rate/10)*(1200/Math.max(1,p.recipeBaseTicks))*s.machines;
 if(p.goal==='neutronium')val=150*s.perMinute+Math.min(continuousRate, s.perMinute*1.22)*4;
 else if(p.goal==='lines')val=360*s.lines+10*s.perMinute;
 else if(p.goal==='energy')val=s.energy/4;
 else if(p.goal==='cooling')val=s.excess*3 + s.perMinute*8;
 else val=150*s.perMinute-800*s.fuelCells;
 // A gradually decreasing soft penalty helps navigate from infeasible to stable cores.
 return val - (Math.pow(over,0.88)*100)-(bad*4100)-Math.max(0,s.fuelCells-p.maxFuel)*20000-
   (s.badMods?.length||0)*100- s.fuelCells*3 - s.sinks*.1 + (s.safe?400:0);
}
function v3CoreCrossover(a,b,dims,p){
 if(!a||!b)return randomCore(dims,p);
 const [w,h,d]=dims,ga=coreOnly(a),gb=coreOnly(b),cut=randomInt(0,h-1),axis=randomInt(0,2),out=ga.slice(),coords=geometry(w,h,d).coords;
 for(let i=0;i<out.length;i++)if(coords[i][axis]>=cut)out[i]=gb[i];
 let surplus=out.filter(t=>t==='F').length-p.maxFuel;
 while(surplus-->0){const fi=[];out.forEach((t,i)=>{if(t==='F')fi.push(i)});out[pick(fi)]='.'}
 removeDangling(out,dims);
 return out.includes('F')?out:randomCore(dims,p)
}
function v3CoreTune(a,dims,p){
 let g=coreOnly(a);const triads=geometry(...dims).triads;
 const attempts=randomInt(1,3),coreIndices=[];
 for(let q=0;q<attempts;q++){
  const action=rand();
  if(action<.63){ // lay or share an exact F-M-I beam
   const fuelNum=g.reduce((n,t)=>n+(t==='F'),0);
   let potentials=[];
   for(let k=0;k<Math.min(200,triads.length);k++){
    let tr=pick(triads),[f,m,c]=tr;
    if(!(['.','F'].includes(g[f])&&['.','M'].includes(g[m])&&['.','I'].includes(g[c])))continue;
    if(g[f]==='.'&&fuelNum>=p.maxFuel)continue;
    // Favor two-way sharing and avoid extra Fuel Cells when equivalent.
    const score=(g[f]==='F'?6:0)+(g[m]==='M'?7:0)+(g[c]==='I'?9:0)+rand()*6;
    potentials.push({tr,score});
   }
   potentials.sort((x,y)=>y.score-x.score);
   if(potentials.length){let [f,m,c]=pick(potentials.slice(0,Math.min(7,potentials.length))).tr;g[f]='F';g[m]='M';g[c]='I'}
  }else if(action<.83){
   const list=[];g.forEach((t,i)=>{if(t!=='F'&&t!=='.')list.push(i)});if(list.length)g[pick(list)]='.';
  }else{
   const list=[];g.forEach((t,i)=>{if(t==='F'||t==='M'||t==='I')list.push(i)});
   if(list.length){let i=pick(list),j=randomInt(0,g.length-1);[g[i],g[j]]=[g[j],g[i]]}
  }
 }
 while(g.filter(t=>t==='F').length>p.maxFuel){let i=[];g.forEach((t,j)=>{if(t==='F')i.push(j)});g[pick(i)]='.'}
 removeDangling(g,dims);
 return g.includes('F')?g:randomCore(dims,p);
}
function v3TrialScore(obj,p){return v3SearchValue(obj.s,p)}
function v3CoolingRefine(seed,dims,p,iterations=22){
 const options=[...passive,...(p.allowActive?activeTypes:[]),'.'].filter(t=>t==='.'||limitFor(t)>0);
 let g=seed.slice(),s=statsForSearch(g,dims,p),value=v3SearchValue(s,p);
 const positions=g.map((t,i)=>!['F','M','I'].includes(t)?i:-1).filter(i=>i>=0);
 let best={g:g.slice(),s},bestScore=value;
 const tabu=new Map(), tenure=7;
 const ranked=options.filter(t=>t!=='.').sort((a,b)=>SINKS[b][0]-SINKS[a][0]);
 for(let step=0;step<iterations&&positions.length;step++){
  const at=pick(positions),old=g[at];
  const next=step%4===0?pick(ranked.slice(0,Math.min(10,ranked.length))):pick(options);
  if(next===old||g.filter(t=>t===next).length>=limitFor(next))continue;
  g[at]=next;let cand=statsForSearch(g,dims,p),score=v3SearchValue(cand,p);
  const reverse=at+'|'+next+'|'+old;
  const forbidden=(tabu.get(at+'|'+old+'|'+next)||-1)>step;
  if((forbidden&&score<=bestScore)||cand.badSinks.length>1){g[at]=old;continue}
  const temp=Math.max(5,500*(1-step/iterations));
  if(score>=value||rand()<Math.exp(clamp((score-value)/temp,-45,0))){
   value=score;s=cand;tabu.set(reverse,step+tenure);
   if(score>bestScore&&cand.invalidCount===0){bestScore=score;best={g:g.slice(),s:cand}}
  }else g[at]=old;
 }
 return best;
}
function v3SmartCandidate(parent,dims,p,iteration,elite){
 let core;
 const roll=rand();
 if(!p.allowCore){core=coreOnly(parent||state.g);let trial=buildCooling(core,dims,p,iteration%13,parent);return {g:trial.g.slice(),s:statsForSearch(trial.g,dims,p)};}
 if(!parent||roll<.13)core=randomCore(dims,p);
 else if(roll<.30&&elite.length>1)core=v3CoreCrossover(parent,pick(elite).g,dims,p);
 else if(roll<.67)core=v3CoreTune(parent,dims,p);
 else if(roll<.88)core=mutateCore(parent,dims,p,roll<.78?1:2);
 else core=coreOnly(parent);
 const ch=core.join('/');
 // Mix cold starts, warm starts, and two distinct randomized cooling layouts.
 let useParent=parent&&rand()<.51?parent:null;
 let result=buildCooling(core,dims,p,iteration%13,useParent);
 let best={g:result.g.slice(),s:statsForSearch(result.g,dims,p)},bs=v3TrialScore(best,p);
 if(rand()<.52){
  let alt=buildCooling(core,dims,p,(iteration*7+3)%13,rand()<.5?null:useParent);
  let r=statsForSearch(alt.g,dims,p),v=v3TrialScore({s:r},p);
  if(v>bs){best={g:alt.g.slice(),s:r};bs=v}
 }
 if(iteration%3===0||rand()<.4){let r=v3CoolingRefine(best.g,dims,p,iteration%9===0?36:16);if(v3TrialScore(r,p)>bs)best=r}
 return best
}
function canonicalGrid(g,dims){
 const [w,h,d]=dims;
 const transforms=[];
 for(let reflect=0;reflect<2;reflect++)for(let rot=0;rot<(w===d?4:2);rot++)transforms.push([reflect,rot]);
 let winner=null;
 for(const [reflect,rot] of transforms){
  const a=Array(g.length);
  for(let y=0;y<h;y++)for(let z=0;z<d;z++)for(let x=0;x<w;x++){
   let u=reflect?w-1-x:x,v=z;
   if(w===d){for(let q=0;q<rot;q++){const old=u;u=d-1-v;v=old}}
   else if(rot===1){u=w-1-u;v=d-1-v}
   a[idx(u,y,v,w,d)]=g[idx(x,y,z,w,d)];
  }
  const hash=a.join('|');
  if(winner===null||hash<winner)winner=hash;
 }
 return winner;
}
let stopped=false,paused=false;
let launchId=0;
self.onmessage=ev=>{const data=ev.data||{};
 if(data.type==='stop'){stopped=true;return}
 if(data.type==='pause'){paused=!!data.value;return}
 if(data.type==='start'){const id=++launchId;stopped=false;paused=false;runWorker(data,id).catch(e=>self.postMessage({type:'error',message:String(e)}));}
};
const waitTick=()=>new Promise(resolve=>setTimeout(resolve,0));
async function runWorker(data,id){
 const {dims,p,seed,iterations,index,limits}=data;
 if(p.goal==='energy'&&dims.reduce((a,b)=>a*b,1)>220){
  await self.runLargeEnergy(data,()=>stopped||id!==launchId,()=>paused);
  return;
 }
 CURRENT_LIMITS=limits||{};state.g=seed.slice();rngSeed=data.rng>>>0;
 const seen=new Set(),elites=[],seedObjs=[seed,...PRESETS.filter(t=>t.dims.join(',')===dims.join(',')).map(t=>t.grid)];
 let work={g:seed.slice(),s:statsForSearch(seed,dims,p)},best=null,near=null;
 const grade=x=>v3SearchValue(x.s,p);
 // Stream diverse stable candidates instead of only new global records.
 const reportedBuckets=new Map(),reportedGrids=new Set();
 let sent=0,lastAlternative=-99;
 const MAX_CANDIDATES=110;
 function report(c,it=-1){
 if(!c||!c.s||(p.goal!=='energy'&&!c.s.lines))return;
 const s=c.s,score=grade(c),improved=s.safe&&(!best||score>grade(best));
 if(improved)best={g:c.g.slice(),s};
 if(!s.safe){
  if(s.layoutOK&&(!near||score>grade(near))){
   near={g:c.g.slice(),s};
   if(!best&&index===0&&sent<8&&(it<0||it-lastAlternative>=25)){
    self.postMessage({type:'candidate',grid:c.g,index,kind:'near'});sent++;
    if(it>=0)lastAlternative=it;
   }
  }
  return;
 }
 const hash=canonicalGrid(c.g,dims);
 const bucket=[s.lines,s.machines,s.fuelCells,Math.floor(Math.max(0,-s.net)/250)].join('|');
 const previous=reportedBuckets.get(bucket);
 if(previous===undefined||score>previous)reportedBuckets.set(bucket,score);
 if(reportedGrids.has(hash))return;
 const novelBucket=previous===undefined;
 const meaningfulImprovement=previous!==undefined&&score>previous+25;
 const sample=it>=0&&it-lastAlternative>=11;
 if(improved||(sent<MAX_CANDIDATES&&sample&&(novelBucket||meaningfulImprovement))||(it<0&&sent<MAX_CANDIDATES)){
  self.postMessage({type:'candidate',grid:c.g,index,kind:improved?'best':'alternative'});
  reportedGrids.add(hash);sent++;
  if(it>=0)lastAlternative=it;
 }
}
 for(const g of seedObjs){if(g.length!==seed.length)continue;let cand={g:g.slice(),s:statsForSearch(g,dims,p)};elites.push(cand);report(cand);seen.add(canonicalGrid(g,dims));}
 let unique=0,steps=0;
 for(let it=0;it<iterations;it++){
  if(stopped||id!==launchId)break;
  if(paused){await waitTick();it--;continue}
  const r=rand();const parent=(r<.12?null:r<.50&&best?best.g:r<.8&&elites.length?pick(elites).g:work.g);
  const candidate=v3SmartCandidate(parent,dims,p,it,elites);
  const fingerprint=canonicalGrid(candidate.g,dims);
  if(!seen.has(fingerprint)){
   seen.add(fingerprint);unique++;
   report(candidate,it);
   if(grade(candidate)>=grade(work)||rand()<Math.exp(Math.max(-40,(grade(candidate)-grade(work))/Math.max(20,1100*(1-it/iterations)))))work=candidate;
   if(candidate.s.invalidCount===0&&candidate.s.limitsOK){elites.push(candidate);elites.sort((a,b)=>grade(b)-grade(a));const known=new Set();const filtered=[];for(const cand of elites){const k=canonicalGrid(coreOnly(cand.g),dims);if(!known.has(k)){filtered.push(cand);known.add(k)}if(filtered.length>=12)break}elites.splice(0,elites.length,...filtered)}
  }
  steps=it+1;
  if(it%12===0){self.postMessage({type:'progress',index,done:steps,unique});await waitTick();}
  if(seen.size>22000)seen.clear();
 }
 if(best)self.postMessage({type:'candidate',grid:best.g,index});
 self.postMessage({type:'done',index,done:steps,unique});
}

// Load the same FE/t rules as the browser (classic Worker importScripts).
importScripts('./fe_optimizer.js?v=20261023-fe1');
importScripts('./large_energy.worker.js?v=20261023-big1');
