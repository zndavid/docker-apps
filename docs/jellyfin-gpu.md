# Optional Jellyfin GPU access on the QNAP

`docker-compose.jellyfin-gpu.yml` adds `/dev/dri` device access. Keep it out of the
base stack until the NAS exposes usable GPU devices; a missing device mapping
can prevent container creation. Passing the device does not itself enable
hardware transcoding in Jellyfin.

The TS-251+ J1900 is a legacy Intel GPU. Use **VAAPI**, with `i965` if supported
by the current image/driver, rather than assuming modern Intel QSV, HEVC, AV1
or HDR tone-mapping support.

## Enable after checking the NAS

1. On the NAS, inspect:

   ```bash
   ls -l /dev/dri
   ```

   Confirm a render device such as `/dev/dri/renderD128` exists. Do not create
   fake devices or make the container privileged if it is absent.
2. Add `docker-compose.jellyfin-gpu.yml` in the media stack's Portainer
   **Additional paths**. Leave relative path volumes off. Set
   `JELLYFIN_LIBVA_DRIVER_NAME=i965` for this legacy GPU (use `iHD` only when
   moving to hardware/driver that supports it), then redeploy.
3. Check capabilities using the bundled helper as the application user:

   ```bash
   docker exec --user abc jellyfin /usr/lib/jellyfin-ffmpeg/vainfo --display drm --device /dev/dri/renderD128
   ```

   LinuxServer normally grants `abc` access to mounted GPU devices. If the
   probe fails, inspect permissions/driver availability rather than granting
   broad access. Keep software decoding enabled if the current image lacks
   the required legacy driver or the NAS kernel cannot support the device.
4. In **Dashboard -> Playback -> Transcoding**, select **VAAPI**, use the
   verified render path, and enable only decoding/encoding capabilities
   reported by `vainfo`. Start with a compatible H.264 test; leave HDR
   tone-mapping and unsupported codecs disabled.
5. Force a test transcode by lowering the client bitrate and inspect the
   FFmpeg log for successful VAAPI use. Direct Play alone does not test it.

If this fails, disable hardware acceleration in Jellyfin, remove the GPU
Additional path and redeploy. The base stack remains usable without GPU access.

- [LinuxServer device setup](https://docs.linuxserver.io/images/docker-jellyfin/#hardware-acceleration)
- [Jellyfin Intel GPU support](https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/intel/)
