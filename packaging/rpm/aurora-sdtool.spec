%global appid io.github.franzjeger.AuroraSDTool

# _metainfodir is a Fedora macro. Define it when absent so the spec also builds
# on openSUSE and on a non-RPM host with rpm-tools installed.
%{!?_metainfodir: %global _metainfodir %{_datadir}/metainfo}

# The payload is a prebuilt NativeAOT binary: nothing to compile, nothing to
# strip, and no build-id to extract.
%global debug_package %{nil}
%global __strip /bin/true
%global __brp_strip %{nil}
%global __brp_strip_static_archive %{nil}
%global __brp_check_rpaths %{nil}
%undefine _missing_build_ids_terminate_build

Name:           aurora-sdtool
Version:        3.2.0
Release:        1%{?dist}
Summary:        Aurora game trainer manager for Steam Play titles

License:        LicenseRef-proprietary
URL:            https://www.cheathappens.com/
Source0:        %{name}-%{version}.tar.gz

ExclusiveArch:  x86_64
BuildRequires:  coreutils
BuildRequires:  sed

Requires:       bash
Requires:       fontconfig
Requires:       freetype
Requires:       expat
Requires:       zlib
Requires:       bzip2-libs
Requires:       libpng
Requires:       libX11
Requires:       libxcb
Requires:       libXau
Requires:       libXdmcp
Requires:       libstdc++
Requires:       libgcc

Recommends:     libicu
Recommends:     xorg-x11-server-Xwayland
Suggests:       steam

%description
Aurora SD Tool installs the Aurora game trainer and registers it as a Steam
Play compatibility tool, so a game launched from Steam starts with Aurora
attached to it.

It detects Proton builds across every Steam library folder, including Flatpak
and distribution-packaged runners, allows a Proton version to be selected per
game or globally, and handles non-Steam launchers such as Ubisoft Connect and
the Epic Games Store.

This package adds Linux desktop integration on top of the upstream Steam Deck
build: an XDG-compliant layout, a launcher that works from a read-only prefix,
startup diagnostics, and support for distributions other than SteamOS.

The application itself is proprietary software published by CheatHappens and is
redistributed unmodified. A CheatHappens account is required.

%prep
%setup -q

%build
# Nothing to build — the payload ships prebuilt.

%install
bash ./scripts/install.sh --quiet --prefix %{_prefix} --destdir %{buildroot}

%check
desktop-file-validate %{buildroot}%{_datadir}/applications/%{name}.desktop || :
appstreamcli validate --no-net \
    %{buildroot}%{_metainfodir}/%{appid}.metainfo.xml || :

%files
# README, CHANGELOG and the upstream documentation are placed under
# %%{_datadir}/doc by the install script, so no %%doc directive here.
%license LICENSE LEGAL.md
%{_bindir}/%{name}
%dir %{_prefix}/lib/%{name}
%{_prefix}/lib/%{name}/AuroraLauncher
%{_prefix}/lib/%{name}/aurora-compat-launch
%{_prefix}/lib/%{name}/libSkiaSharp.so
%{_prefix}/lib/%{name}/libHarfBuzzSharp.so
%{_prefix}/lib/%{name}/SHA256SUMS
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/256x256/apps/%{name}.png
%{_metainfodir}/%{appid}.metainfo.xml
%{_datadir}/doc/%{name}/

%changelog
* Sat Aug 08 2026 aurora-sdtool-linux packaging contributors - 3.2.0-1
- Initial package, built on upstream 3.2.0.
- Adds an XDG-compliant layout, a launcher that survives a read-only prefix,
  startup diagnostics and desktop integration.
