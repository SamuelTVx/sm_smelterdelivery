OX INSTALL QUIDE

1. Download all dependencies!
Dependencies:
	ox_inventory | https://github.com/overextended/ox_inventory
	ox_lib | https://github.com/overextended/ox_lib
	ox_target | https://github.com/overextended/ox_target

2. Add Images to your inventory
	ox_inventory > web > build > images
	Paste images from folder images to ox_inventory > web > build > img

3. Add Items to your inventory
	ox_inventory > data> items.lua

	['iron_ore'] = {
		label = 'Iron Ore',
		description = "",
		weight = 75,
		stack = true
	},

	['iron'] = {
		label = 'Iron Ingot',
		description = "",
		weight = 125,
		stack = true
	},

	['steel_ore'] = {
		label = 'Component',
		description = "",
		weight = 75,
		stack = true
	},

	['steel'] = {
		label = 'Steel Ingot',
		description = "",
		weight = 125,
		stack = true
	},

	['component'] = {
		label = 'Component',
		description = "",
		weight = 150,
		stack = true
	},


4. add ensure sm_smelterdelivery into your server.cfg (make sure to start it after ox_lib and your target system!)

5. Enjoy your script!