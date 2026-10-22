# HellCrawler 0.4.0: the village is a ring of houses now

0.3.0 shipped the world map and a painted village. This release puts the village on a street that turns, with six buildings modelled in Blender, and shows the whole world map at once, flat and without the tilt it had.

## The map was never crooked

The map looked tilted because the code tilted it. A number in the map file, `lutning`, pushed every row of the image a little further sideways the lower it sat, which is what gave the picture its CRT warp. The painting itself is flat. Set the number to zero and the warp is gone.

That was the complaint I answered first, and it was the smaller half of the problem: the map still did not show itself in full. I kept measuring the drawing code. The drawing was right, and the crop came from somewhere else.

The view renders at 1.75 times the window size and is then scaled down, which is where the sharpness comes from. The container that puts the rendered view on screen kept a scale of 1.0, so it showed the top left corner of a 3360x1890 image inside a 1920x1080 window. Fifty-seven percent of the width and 57 percent of the height. The rest was simply cut away, and no amount of fixing the map's zoom was ever going to bring it back.

I found it by picking a landmark. The frozen lake sits at 40.8 percent across and 61.2 percent down the painting, and covers 10.1 percent of it. On screen it sat at 67.1 and 79.0, covering 3.5 percent. A picture that is displayed in full keeps those numbers. It was a crop. With the container scaling down as it should, the same landmark lands at 40.6 and 59.6.

The map is now drawn at 0.375 and fills the view from corner to corner. The information strip moved below the picture instead of lying on it, and its type came down: the place name from 12 px to 9, the detail line from 10 to 8, the legend from 9 to 7.

## Six buildings, one ring

The old village was a flat painting. The new one is a street that turns all the way round: six buildings and a well on a ring of 18 m, inside a wall at 26 m, with the gate opening at 13 m. The gate's width is stored once, and that one number sets both the size of the gate model and the gap the wall leaves for it, so the two cannot drift apart.

The houses are made of parts the way houses are: beams, plaster, stone footings, shutters, chimneys, barrels and crates. Between 40,444 and 98,100 triangles each. The shop is the heavy one because the forge and the smoke live there.

Textures are laid in metres rather than in UV turns. The models' UV maps were uneven, so a tile stretched in one wall and shrank in the next, and measuring in metres fixed that: 1.4 m per stone, 1.5 for plaster, 1.6 for timber, 1.8 for roof tiles, 1.0 for iron. The first attempt made stones larger than the door, which is how the metre scale got picked.

Windows have reveals now. The frame sits 0.22 m into the wall and the glass a little behind it, so a window reads as a hole rather than a picture pasted on the facade. Beams stop at the openings instead of running across the panes. Doors are built as doors: a solid bottom, planks with grain lines between them, a jamb with a reveal, hinges, iron bands, a ring handle and a threshold, with the leaf set back into the opening.

Headings and labels use a signed distance field font, so they stay sharp at any window size. They were 4x4 pixel blocks before.

Clicking a house takes you into it, wherever it stands in the ring, and A and D turn the street to the next building, round as many times as you like.

## The art in the build

The six buildings, the gate, the wall and the props in the street are modelled for the game by `tools/gen_by_hus3d.py` and rebuilt with one command. The textures on them are Quaternius kits under CC0, listed with their licence files in `CREDITS.md`, and the sprites and tiles come from Alex's own sheets.

## Numbers

The builds are 254 MB on Windows and Linux, and a 250 MB pack plus 37 MB of WebAssembly for the browser. The pack roughly doubled this release because the village's models and textures travel inside it. The game runs at 1920x1080 with 1.75x supersampling, and the village is rendered in its own viewport at 1.5x on top of that.

## What is thin

The browser build is 286 MB of download. It works, and it takes a while to arrive the first time.

The street is six buildings because the game has six places to walk into. A seventh means a model in Blender, a line in `data/by.json` and a rebuild, so the ring stays at six for now.

The Windows build compiles and launches. It has never been played on a Windows machine, and every measurement in this post comes from Linux on an NVIDIA card. The sound is in and has still not been judged by an ear in a real speaker.
