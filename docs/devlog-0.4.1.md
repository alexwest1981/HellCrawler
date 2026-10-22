# HellCrawler 0.4.1: the village is a ring of houses now

0.3.0 shipped the world map and a village painted as one wide street. This release turns that street into something you can walk around, fixes the map so the whole painting is on screen, and brings the browser build in under 200 MB.

## The map was never crooked

The map looked tilted because the code tilted it. A value in the map file, `lutning`, pushed every row of the image a little further sideways the lower it sat, which is what gave the picture its CRT warp. The painting is flat. Set the value to zero and the warp is gone.

That was the complaint I answered first, and it was the smaller half of the problem: the map still did not show itself in full. I kept measuring the drawing code. The drawing was right, and the crop came from somewhere else.

The view renders at 1.75 times the window size and is scaled down, which is where the sharpness comes from. The container that puts the rendered view on screen kept a scale of 1.0, so it showed the top left corner of a 3360x1890 image inside a 1920x1080 window. Fifty-seven percent of the width and 57 percent of the height, with the rest cut away. No change to the map's zoom was ever going to bring it back.

I found it with a landmark. The frozen lake sits at 40.8 percent across and 61.2 percent down the painting, and covers 10.1 percent of it. On screen it sat at 67.1 and 79.0, covering 3.5 percent. A picture displayed in full keeps those numbers, and this one did not, which is what a crop looks like. With the container scaling down as it should, the same landmark lands at 40.6 and 59.6.

The map is drawn at 0.375 now and fills the view. The information strip moved below the picture instead of lying on top of it, so nothing covers the art, and its type came down: the place name from 12 px to 9, the detail line from 10 to 8, the legend from 9 to 7. Place markers are kept inside the frame and above the strip, which matters now that the map uses the space the strip used to take.

## Six buildings, one ring

The street is a ring of 18 m with six buildings and a well on it, inside a wall at 26 m, and the gate opening measures 13 m. The gate's width is stored once, and that number sets both the size of the gate model and the gap the wall leaves for it, so the two cannot drift apart.

The houses are built from parts the way houses are: beams, plaster, stone footings, shutters, chimneys, barrels and crates. Between 40,444 and 98,100 triangles each. The shop is the heavy one because the forge and the smoke live there.

Textures are laid in metres rather than in UV turns. The models' own UV maps were uneven, so a tile stretched on one wall and shrank on the next, and measuring in metres fixed it: 1.4 m per stone, 1.5 for plaster, 1.6 for timber, 1.8 for roof tiles, 1.0 for iron. The first attempt made stones larger than the door, which is how the metre scale got picked.

Windows have reveals now. The frame sits 0.22 m into the wall and the glass a little behind it, so a window reads as a hole in a wall rather than a picture pasted on the facade. Beams stop at the openings instead of crossing the panes. Doors are built as doors: a solid bottom, planks with grain lines between them, a jamb with a reveal, hinges, iron bands, a ring handle and a threshold, with the leaf set back into the opening.

Headings and labels use a signed distance field font, so they stay sharp at any window size. They were 4x4 pixel blocks before.

Clicking a house takes you into it, wherever it stands in the ring. A and D turn the street to the next building, round as many times as you like.

## Under 200 MB in the browser

The web build has a ceiling of 200 MB, and it was sitting at 287. Three things brought it down.

Textures above 1024 px were scaled to 1024. The ground was a 4096 square with a normal map to match, and 44 textures were over the line. The sources went from 107 MB to 30 MB. A wall face covers a few hundred pixels on a 1920 wide screen, so 1024 leaves more detail than the screen can show.

The dungeon tiles use lossy compression at 0.9 instead of lossless. That alone took the pack from 193 MB to 149 MB. I tried VRAM compression first, which got it to 123 MB, and rejected it: the stone walls came out with blocky edges that were easy to see in the dark.

The last 5 MB came from `assets/ui/byn.png`, an older village painting that no longer had a caller in the game.

The browser build is 149 MB of pack plus 37 MB of WebAssembly, 186 MB in total. Windows and Linux are 153 MB each. I checked a dungeon floor and a wall after the compression, on screenshots, before uploading.

## The art in the build

The six buildings, the gate, the wall and the props in the street are modelled for the game by `tools/gen_by_hus3d.py` and rebuilt with one command. The textures on them are Quaternius kits under CC0, listed with their licence files in `CREDITS.md`, and the sprites and tiles are drawn from our own sheets.

## What is thin

The street is six buildings because the game has six places to walk into. A seventh means a model in Blender, a line in `data/by.json` and a rebuild.

The Windows build compiles and launches. It has never been played on a Windows machine, and every measurement in this post comes from Linux on an NVIDIA card.

The browser build is the one I have tested least: it is built and it uploads, and I have not played it in a browser yet.
