# FFmpeg Binary Notice

Filmtone Desktop bundles FFmpeg command-line binaries for local video import,
HDR-to-SDR preparation, and MP4 export.

- FFmpeg version: 8.1
- Target: macOS arm64
- License reported by `ffmpeg -L`: GNU Lesser General Public License version
  2.1 or later
- Build configuration:
  `--arch=arm64 --cc=clang --disable-autodetect --enable-libzimg --enable-videotoolbox --disable-ffplay --disable-doc --disable-debug --disable-network --disable-indevs --disable-outdevs`
- No `--enable-gpl`, `--enable-nonfree`, `libx264`, or `libx265` flags are
  used in this bundled build.
- The bundled binaries are dynamically linked only to macOS system libraries
  and Apple frameworks.

Source code is available from the FFmpeg project:
https://ffmpeg.org/download.html

This build also statically links zimg 3.0.6 for the `zscale` filter. zimg is
distributed under the license copied in `../zimg/COPYING`.

Bundled binary checksums:

```text
230c4995a321bd6d9d407ade2d2f21e4ee05dab0797f751266d7488007400f8f  ffmpeg
9763185a2d2fdf8843e604b6d84eb24d80682ef799f89dbe935bb3442e59ad52  ffprobe
```
