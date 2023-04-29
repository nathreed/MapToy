# MapToy

This is an experimental renderer for Mapbox Vector Tiles (MVT) using SpriteKit and SwiftUI.

Mostly, I created this to learn more about the MVT format and drawing maps in general. It's not meant to be used in anything real.

## Screenshots

10x10 map
insert screenshot

1x1 (single tile)
insert screenshot

## Use

- choose .mbtiles file to open
- input tile coordinates to render (optionally you can do an S x S square map by providing S and the tile coordinates of the top-left tile)
- hit go

Display of multiple tiles in an S x S grid is not performant at the moment - it uses individual `SpriteView`s in a `Grid` for each tile. This is not a good approach (a 10x10 map can take 10+ seconds to load on my machine). This should probably be rewritten so that one `SpriteView` renders all the tiles. Also, I haven't profiled this to be sure that none of the (naive) logic to massage stuff around for display isn't causing performance problems with SwiftUI updates, so that could be part of the issue.