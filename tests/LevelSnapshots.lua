--!strict
-- Committed generator snapshots for P0.5 (ISSUES #14). Pinned levels {1,10,25,40}
-- per restaurant, serialized deterministically by RealConfig.spec's serializeLevel.
-- Regenerate ONLY on an intentional generator/config change, after human review:
-- run the serializer in Studio (see RealConfig.spec) and paste the output here.
-- Not a *.spec module, so the TestRunner skips it (it's data, required by the spec).

return {
	["fastfood:1"] = [[
fastfood#1 g=4/12/19 dur=0
@2.00 hurried [fries] p=1.820
@20.00 family [fries] p=1.820
@38.00 family [fries] p=1.820
@56.00 casual [fries] p=1.820]],

	["fastfood:10"] = [[
fastfood#10 g=10/16/22 dur=0
@2.00 hurried [cola] p=1.232
@14.26 hurried [cola] p=1.232
@25.70 hurried [cola] p=1.232
@38.41 family [cola] p=1.232
@50.39 family [fries] p=1.232
@62.76 family [cola] p=1.232]],

	["fastfood:25"] = [[
fastfood#25 g=48/78/105 dur=0
@2.00 hurried [cola,fries] p=0.965
@8.06 casual [cola] p=0.965
@14.81 hurried [cola] p=0.965
@21.14 family [cola] p=0.965
@28.12 hurried [fries,cola] p=0.965
@34.21 casual [cheeseburger] p=0.965
@40.91 casual [fries,cola] p=0.965
@46.93 casual [cheeseburger,fries] p=0.965
@54.30 casual [cola] p=0.965
@61.50 family [fries] p=0.965
@68.32 family [cheeseburger,cola] p=0.965
@75.61 family [cheeseburger] p=0.965
@82.72 hurried [fries] p=0.965]],

	["fastfood:40"] = [[
fastfood#40 g=128/208/281 dur=77
@2.00 hurried [cheeseburger] p=0.800
@5.61 casual [cola,cheeseburger] p=0.800
@9.48 hurried [cola,cola,cheeseburger] p=0.800
@12.96 casual [cheeseburger,cheeseburger] p=0.800
@16.43 casual [cheeseburger] p=0.800
@19.69 hurried [fries,cheeseburger,cola] p=0.800
@23.26 casual [fries,cheeseburger,cola] p=0.800
@26.58 family [cola,cheeseburger] p=0.800
@29.76 family [cheeseburger,cheeseburger,fries] p=0.800
@32.98 casual [cheeseburger,cola,cola] p=0.800
@36.69 casual [cheeseburger,cheeseburger] p=0.800
@40.05 family [cola,cola] p=0.800
@43.90 casual [fries,cola,fries] p=0.800
@47.30 casual [fries] p=0.800
@50.40 casual [cheeseburger] p=0.800
@53.58 hurried [cheeseburger,cheeseburger] p=0.800
@57.03 family [fries] p=0.800
@60.72 casual [cheeseburger] p=0.800]],

	["sushi:1"] = [[
sushi#1 g=6/15/24 dur=0
@2.00 critic [green_tea] p=1.820
@20.00 critic [green_tea] p=1.820
@38.00 casual [green_tea] p=1.820
@56.00 casual [salmon_nigiri] p=1.820]],

	["sushi:10"] = [[
sushi#10 g=41/67/91 dur=0
@2.00 critic [salmon_nigiri] p=1.232
@18.18 tourist [green_tea] p=1.232
@34.35 critic [tuna_roll] p=1.232
@50.53 critic [tuna_roll] p=1.232
@66.70 critic [salmon_nigiri] p=1.232
@82.88 casual [green_tea] p=1.232
@99.05 tourist [salmon_nigiri] p=1.232
@115.23 critic [salmon_nigiri] p=1.232]],

	["sushi:25"] = [[
sushi#25 g=94/153/207 dur=0
@2.00 tourist [salmon_nigiri,tuna_roll] p=0.965
@10.95 casual [tuna_roll,green_tea] p=0.965
@19.91 critic [green_tea,green_tea] p=0.965
@28.86 critic [green_tea] p=0.965
@37.82 casual [salmon_nigiri] p=0.965
@46.77 casual [green_tea] p=0.965
@55.73 casual [salmon_nigiri] p=0.965
@64.68 casual [miso_soup,tuna_roll] p=0.965
@73.64 tourist [tuna_roll,miso_soup] p=0.965
@82.59 casual [salmon_nigiri] p=0.965
@91.55 tourist [green_tea] p=0.965
@100.50 tourist [miso_soup,tuna_roll] p=0.965
@109.46 critic [tuna_roll,green_tea] p=0.965
@118.41 tourist [salmon_nigiri] p=0.965]],

	["sushi:40"] = [[
sushi#40 g=151/246/333 dur=83
@2.00 tourist [green_tea,miso_soup] p=0.800
@5.26 casual [green_tea] p=0.800
@8.50 critic [miso_soup,tuna_roll] p=0.800
@11.81 casual [green_tea,green_tea,tuna_roll] p=0.800
@15.56 casual [green_tea,green_tea] p=0.800
@18.67 casual [miso_soup,miso_soup] p=0.800
@22.12 tourist [tuna_roll,salmon_nigiri] p=0.800
@25.60 tourist [salmon_nigiri,salmon_nigiri] p=0.800
@29.16 critic [miso_soup,green_tea] p=0.800
@32.75 casual [miso_soup] p=0.800
@36.35 critic [miso_soup] p=0.800
@39.95 casual [tuna_roll,tuna_roll] p=0.800
@43.57 casual [green_tea] p=0.800
@46.63 tourist [tuna_roll] p=0.800
@49.86 critic [tuna_roll,salmon_nigiri,green_tea] p=0.800
@53.61 tourist [green_tea,miso_soup,green_tea] p=0.800
@57.44 tourist [tuna_roll,tuna_roll] p=0.800
@60.93 critic [tuna_roll,salmon_nigiri,salmon_nigiri] p=0.800]],
}
