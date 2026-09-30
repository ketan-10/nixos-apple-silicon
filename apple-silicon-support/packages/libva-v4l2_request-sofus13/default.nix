{
  lib,
  stdenv,
  fetchFromGitHub,
  meson,
  ninja,
  pkg-config,
  libva,
  libdrm,
  linuxHeaders,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "libva-v4l2_request-sofus13";
  version = "1.3";

  src = fetchFromGitHub {
    owner = "sofus13";
    repo = "libva-v4l2_request";
    tag = finalAttrs.version;
    hash = "sha256-qN/IEte/kFd2Zi9DSPTYSehCkE3MenV9a8n0LBXuICQ=";
  };

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
  ];

  buildInputs = [
    libva
    libdrm
    linuxHeaders
  ];

  mesonFlags = [
    "-Ddriverdir=${placeholder "out"}/lib/dri"
  ];

  postInstall = ''
    mv $out/lib/dri/v4l2_request{,-sofus13}_drv_video.so
  '';

  meta = {
    description = "VA-API (libva) backend driver for V4L2 stateless video decoders using the Media Request API";
    longDescription = ''
      A fork of the upstream https://xff.cz/git/libva-v4l2_request/ with a few fixes that were noticed with AVD. It itself is a fork of https://github.com/bootlin/libva-v4l2-request.

      When support is available in the kernel and hardware, this allows hardware decoding of MPEG-2, H.264, HEVC, VP8, VP9 and AV1 through VA-API. AVD has support for all of these apart from VP8 and MPEG-2, though AV-1 is only supported on M3+.
    '';
    homepage = "https://github.com/sofus13/libva-v4l2_request";
    license = lib.licenses.gpl3Plus;
    maintainers = [ lib.maintainers.sempiternal-aurora ];
    platforms = lib.platforms.linux;
  };
})
