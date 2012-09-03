# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/sys-libs/glibc/glibc-2.12.1-r3.ebuild,v 1.12 2012/06/08 22:06:51 vapier Exp $

inherit eutils versionator libtool toolchain-funcs flag-o-matic gnuconfig multilib multiprocessing

DESCRIPTION="GNU libc6 (also called glibc2) C library"
HOMEPAGE="http://www.gnu.org/software/libc/libc.html"

LICENSE="LGPL-2"
KEYWORDS="~amd64 ~ia64 ~mips ~ppc ~ppc64 ~s390 ~sh ~sparc ~x86"
RESTRICT="strip" # strip ourself #46186
EMULTILIB_PKG="true"

# Configuration variables
if [[ ${PV} == *_p* ]] ; then
RELEASE_VER=${PV%_p*}
BRANCH_UPDATE=""
SNAP_VER=${PV#*_p}
else
RELEASE_VER=${PV}
BRANCH_UPDATE=""
SNAP_VER=""
fi
MANPAGE_VER=""                                 # pregenerated manpages
INFOPAGE_VER=""                                # pregenerated infopages
LIBIDN_VER=""                                  # it's integrated into the main tarball now
PATCH_VER="8"                                  # Gentoo patchset
PORTS_VER=${RELEASE_VER}                       # version of glibc ports addon
LT_VER=""                                      # version of linuxthreads addon
NPTL_KERN_VER=${NPTL_KERN_VER:-"2.6.9"}        # min kernel version nptl requires
#LT_KERN_VER=${LT_KERN_VER:-"2.4.1"}           # min kernel version linuxthreads requires

IUSE="debug gd hardened multilib selinux profile vanilla crosscompile_opts_headers-only ${LT_VER:+glibc-compat20 nptl linuxthreads}"
S=${WORKDIR}/glibc-${RELEASE_VER}${SNAP_VER:+-${SNAP_VER}}

# Here's how the cross-compile logic breaks down ...
#  CTARGET - machine that will target the binaries
#  CHOST   - machine that will host the binaries
#  CBUILD  - machine that will build the binaries
# If CTARGET != CHOST, it means you want a libc for cross-compiling.
# If CHOST != CBUILD, it means you want to cross-compile the libc.
#  CBUILD = CHOST = CTARGET    - native build/install
#  CBUILD != (CHOST = CTARGET) - cross-compile a native build
#  (CBUILD = CHOST) != CTARGET - libc for cross-compiler
#  CBUILD != CHOST != CTARGET  - cross-compile a libc for a cross-compiler
# For install paths:
#  CHOST = CTARGET  - install into /
#  CHOST != CTARGET - install into /usr/CTARGET/

export CBUILD=${CBUILD:-${CHOST}}
export CTARGET=${CTARGET:-${CHOST}}
if [[ ${CTARGET} == ${CHOST} ]] ; then
	if [[ ${CATEGORY/cross-} != ${CATEGORY} ]] ; then
		export CTARGET=${CATEGORY/cross-}
	fi
fi

[[ ${CTARGET} == hppa* ]] && NPTL_KERN_VER=${NPTL_KERN_VER/2.6.9/2.6.20}

is_crosscompile() {
	[[ ${CHOST} != ${CTARGET} ]]
}

# Why SLOT 2.2 you ask yourself while sippin your tea ?
# Everyone knows 2.2 > 0, duh.
SLOT="2.2"

# General: We need a new-enough binutils for as-needed
# arch: we need to make sure our binutils/gcc supports TLS
DEPEND=">=sys-devel/gcc-3.4.4
	arm? ( >=sys-devel/binutils-2.16.90 >=sys-devel/gcc-4.1.0 )
	x86? ( >=sys-devel/gcc-4.3 )
	amd64? ( >=sys-devel/binutils-2.19 >=sys-devel/gcc-4.3 )
	ppc? ( >=sys-devel/gcc-4.1.0 )
	ppc64? ( >=sys-devel/gcc-4.1.0 )
	>=sys-devel/binutils-2.15.94
	${LT_VER:+nptl? (} >=sys-kernel/linux-headers-${NPTL_KERN_VER} ${LT_VER:+)}
	>=app-misc/pax-utils-0.1.10
	virtual/os-headers
	!<sys-apps/sandbox-1.2.18.1-r2
	!<sys-apps/portage-2.1.2
	selinux? ( sys-libs/libselinux )"
RDEPEND="!sys-kernel/ps3-sources
	selinux? ( sys-libs/libselinux )"

if [[ ${CATEGORY/cross-} != ${CATEGORY} ]] ; then
	DEPEND="${DEPEND} !crosscompile_opts_headers-only? ( ${CATEGORY}/gcc )"
	[[ ${CATEGORY} == *-linux* ]] && DEPEND="${DEPEND} ${CATEGORY}/linux-headers"
else
	DEPEND="${DEPEND} !vanilla? ( >=sys-libs/timezone-data-2007c )"
	RDEPEND="${RDEPEND}
		vanilla? ( !sys-libs/timezone-data )
		!vanilla? ( sys-libs/timezone-data )"
fi

SRC_URI=$(
	upstream_uris() {
		echo mirror://gnu/glibc/$1 ftp://sources.redhat.com/pub/glibc/{releases,snapshots}/$1 mirror://gentoo/$1
	}
	gentoo_uris() {
		local devspace="HTTP~vapier/dist/URI HTTP~azarah/glibc/URI"
		devspace=${devspace//HTTP/http://dev.gentoo.org/}
		echo mirror://gentoo/$1 ${devspace//URI/$1}
	}

	TARNAME=${PN}
	if [[ -n ${SNAP_VER} ]] ; then
		TARNAME="${PN}-${RELEASE_VER}"
		[[ -n ${PORTS_VER} ]] && PORTS_VER=${SNAP_VER}
		upstream_uris ${TARNAME}-${SNAP_VER}.tar.bz2
	else
		upstream_uris ${TARNAME}-${RELEASE_VER}.tar.bz2
	fi
	[[ -n ${LIBIDN_VER}    ]] && upstream_uris glibc-libidn-${LIBIDN_VER}.tar.bz2
	[[ -n ${PORTS_VER}     ]] && upstream_uris ${TARNAME}-ports-${PORTS_VER}.tar.bz2
	[[ -n ${LT_VER}        ]] && upstream_uris ${TARNAME}-linuxthreads-${LT_VER}.tar.bz2
	[[ -n ${BRANCH_UPDATE} ]] && gentoo_uris glibc-${RELEASE_VER}-branch-update-${BRANCH_UPDATE}.patch.bz2
	[[ -n ${PATCH_VER}     ]] && gentoo_uris glibc-${RELEASE_VER}-patches-${PATCH_VER}.tar.bz2
	[[ -n ${MANPAGE_VER}   ]] && gentoo_uris glibc-manpages-${MANPAGE_VER}.tar.bz2
	[[ -n ${INFOPAGE_VER}  ]] && gentoo_uris glibc-infopages-${INFOPAGE_VER}.tar.bz2
)

# eblit-include [--skip] <function> [version]
eblit-include() {
	local skipable=false
	[[ $1 == "--skip" ]] && skipable=true && shift
	[[ $1 == pkg_* ]] && skipable=true

	local e v func=$1 ver=$2
	[[ -z ${func} ]] && die "Usage: eblit-include <function> [version]"
	for v in ${ver:+-}${ver} -${PVR} -${PV} "" ; do
		e="${FILESDIR}/eblits/${func}${v}.eblit"
		if [[ -e ${e} ]] ; then
			source "${e}"
			return 0
		fi
	done
	${skipable} && return 0
	die "Could not locate requested eblit '${func}' in ${FILESDIR}/eblits/"
}

# eblit-run-maybe <function>
# run the specified function if it is defined
eblit-run-maybe() {
	[[ $(type -t "$@") == "function" ]] && "$@"
}

# eblit-run <function> [version]
# aka: src_unpack() { eblit-run src_unpack ; }
eblit-run() {
	eblit-include --skip common "${*:2}"
	eblit-include "$@"
	eblit-run-maybe eblit-$1-pre
	eblit-${PN}-$1
	eblit-run-maybe eblit-$1-post
}

src_unpack()  { eblit-run src_unpack  ; }
src_compile() { eblit-run src_compile ; }
src_test()    { eblit-run src_test    ; }
src_install() { eblit-run src_install ; }

# FILESDIR might not be available during binpkg install
for x in setup {pre,post}inst ; do
	e="${FILESDIR}/eblits/pkg_${x}.eblit"
	if [[ -e ${e} ]] ; then
		. "${e}"
		eval "pkg_${x}() { eblit-run pkg_${x} ; }"
	fi
done

pkg_setup() {
	eblit-run pkg_setup

	# Static binary sanity check #332927
	if [[ ${ROOT} == "/" ]] && \
	   has_version "<${CATEGORY}/${P}" && \
	   built_with_use sys-apps/coreutils static
	then
		eerror "Please rebuild coreutils with USE=-static, then install"
		eerror "glibc, then you may rebuild coreutils with USE=static."
		die "Avoiding system meltdown #332927"
	fi
}

eblit-src_unpack-pre() {
	GLIBC_PATCH_EXCLUDE+=" 5021_all_2.9-fnmatch.patch"
}

eblit-src_unpack-post() {
	if use hardened ; then
		cd "${S}"
		einfo "Patching to get working PIE binaries on PIE (hardened) platforms"
		gcc-specs-pie && epatch "${FILESDIR}"/2.12/glibc-2.12-hardened-pie.patch
		epatch "${FILESDIR}"/2.10/glibc-2.10-hardened-configure-picdefault.patch
		epatch "${FILESDIR}"/2.10/glibc-2.10-hardened-inittls-nosysenter.patch

		einfo "Patching Glibc to support older SSP __guard"
		epatch "${FILESDIR}"/2.10/glibc-2.10-hardened-ssp-compat.patch

		einfo "Installing Hardened Gentoo SSP and FORTIFY_SOURCE handler"
		cp -f "${FILESDIR}"/2.6/glibc-2.6-gentoo-stack_chk_fail.c \
			debug/stack_chk_fail.c || die
		cp -f "${FILESDIR}"/2.10/glibc-2.10-gentoo-chk_fail.c \
			debug/chk_fail.c || die

		if use debug ; then
			# When using Hardened Gentoo stack handler, have smashes dump core for
			# analysis - debug only, as core could be an information leak
			# (paranoia).
			sed -i \
				-e '/^CFLAGS-backtrace.c/ iCFLAGS-stack_chk_fail.c = -DSSP_SMASH_DUMPS_CORE' \
				debug/Makefile \
				|| die "Failed to modify debug/Makefile for debug stack handler"
			sed -i \
				-e '/^CFLAGS-backtrace.c/ iCFLAGS-chk_fail.c = -DSSP_SMASH_DUMPS_CORE' \
				debug/Makefile \
				|| die "Failed to modify debug/Makefile for debug fortify handler"
		fi

		# Build nscd with ssp-all
		sed -i \
			-e 's:-fstack-protector$:-fstack-protector-all:' \
			nscd/Makefile \
			|| die "Failed to ensure nscd builds with ssp-all"
	fi
	cd "${S}"

	# Reconstructed / Edited Patch0: glibc-fedora.patch
	epatch "${FILESDIR}"/lts6/glibc-2.12-fedora-hybrid.patch

	# Patch1: glibc-ia64-lib64.patch
	# This patch needs additional work
	# ia64 && epatch "${FILESDIR}"/lts6/glibc-ia64-lib64.patch

	# Patch2: glibc-rh587360.patch
	# Note: Omitted because it's part of el-2.12 -> 2.12.1
	# epatch "${FILESDIR}"/lts6/glibc-rh587360.patch

	# Patch3: glibc-rh582738.patch
	epatch "${FILESDIR}"/lts6/glibc-rh582738.patch

	# Patch4: glibc-getlogin-r.patch
	# Note: Omitted because it's part of el-2.12 -> 2.12.1
	# epatch "${FILESDIR}"/lts6/glibc-getlogin-r.patch

	# Patch5: glibc-localedata.patch
	# Note: Omitted because it's part of el-2.12 -> 2.12.1
	# epatch "${FILESDIR}"/lts6/glibc-localedata.patch

	# Patch6: glibc-rh593396.patch
	# Note: Omitted because it's part of el-2.12 -> 2.12.1
	# epatch "${FILESDIR}"/lts6/glibc-rh593396.patch

	# Patch7: glibc-recvmmsg.patch
	# Note: Omitted because it's part of el-2.12 -> 2.12.1
	# epatch "${FILESDIR}"/lts6/glibc-recvmmsg.patch

	# Patch8: glibc-aliasing.patch
	epatch "${FILESDIR}"/lts6/glibc-aliasing.patch

	# Patch9: glibc-rh593686.patch
	epatch "${FILESDIR}"/lts6/glibc-rh593686.patch

	# Patch10: glibc-rh607461.patch
	epatch "${FILESDIR}"/lts6/glibc-rh607461.patch

	# Patch11: glibc-rh621959.patch
	epatch "${FILESDIR}"/lts6/glibc-rh621959.patch

	# Patch12: glibc-rh607010.patch
	epatch "${FILESDIR}"/lts6/glibc-rh607010.patch

	# Patch13: glibc-rh630801.patch
	# Note: Omitted because it's part of el-2.12 -> 2.12.1
	# epatch "${FILESDIR}"/lts6/glibc-rh630801.patch

	# Patch14: glibc-rh631011.patch
	# Note: Provided as Gentoo patch:
	# 0060_all_glibc-2.12-sse4-x86-static-strspn.patch
	# epatch "${FILESDIR}"/lts6/glibc-rh631011.patch

	# Patch15: glibc-rh641128.patch
	epatch "${FILESDIR}"/lts6/glibc-rh641128.patch

	# Patch16: glibc-rh642584.patch
	epatch "${FILESDIR}"/lts6/glibc-rh642584.patch

	# Patch17: glibc-rh643822.patch
	# This patch has been trimmed down to just the first
	# hunk of the patch.  The second half was provided in
	# the gentoo patch: 0061_all_glibc-double-expansion.patch
	epatch "${FILESDIR}"/lts6/glibc-rh643822-1st-half.patch

	# Patch18: glibc-rh645672.patch
	# Covered by Gentoo patch-set patch:
	# 0060_all_glibc-ld-audit-setuid.patch
	# epatch "${FILESDIR}"/lts6/glibc-rh645672.patch

	# Patch19: glibc-rh580498.patch
	epatch "${FILESDIR}"/lts6/glibc-rh580498.patch

	# Patch20: glibc-rh615090.patch
	epatch "${FILESDIR}"/lts6/glibc-rh615090.patch

	# Patch21: glibc-rh623187.patch
	epatch "${FILESDIR}"/lts6/glibc-rh623187.patch

	# Patch22: glibc-rh646954.patch
	epatch "${FILESDIR}"/lts6/glibc-rh646954.patch

	# Patch23: glibc-rh647448.patch
	epatch "${FILESDIR}"/lts6/glibc-rh647448.patch

	# Patch24: glibc-rh615701.patch
	epatch "${FILESDIR}"/lts6/glibc-rh615701.patch

	# Patch25: glibc-rh652661.patch
	# Already applied...
	# epatch "${FILESDIR}"/lts6/glibc-rh652661.patch

	# Patch26: glibc-rh656530.patch
	epatch "${FILESDIR}"/lts6/glibc-rh656530.patch

	# Patch27: glibc-rh656014.patch
	epatch "${FILESDIR}"/lts6/glibc-rh656014.patch

	# Patch28: glibc-rh661982.patch
	epatch "${FILESDIR}"/lts6/glibc-rh661982.patch

	# Patch29: glibc-rh601686.patch
	epatch "${FILESDIR}"/lts6/glibc-rh601686.patch

	# Patch30: glibc-rh676076.patch
	epatch "${FILESDIR}"/lts6/glibc-rh676076.patch

	# Patch31: glibc-rh667974.patch
	epatch "${FILESDIR}"/lts6/glibc-rh667974.patch

	# Patch32: glibc-rh625893.patch
	# Provided by Gentoo Patch 0010_all_glibc-locale-output-quote.patch
	# epatch "${FILESDIR}"/lts6/glibc-rh625893.patch

	# Patch33: glibc-rh681054.patch
	# We have excluded Gentoo's 5021_all_2.9-fnmatch.patch
	# in favor of the solution implemented in this patch.
	epatch "${FILESDIR}"/lts6/glibc-rh681054.patch

	# Patch34: glibc-rh689471.patch
	epatch "${FILESDIR}"/lts6/glibc-rh689471.patch

	# Patch35: glibc-rh692177.patch
	epatch "${FILESDIR}"/lts6/glibc-rh692177.patch

	# Patch36: glibc-rh692838.patch
	epatch "${FILESDIR}"/lts6/glibc-rh692838.patch

	# Patch37: glibc-rh703480.patch
	epatch "${FILESDIR}"/lts6/glibc-rh703480.patch

	# Patch38: glibc-rh705465.patch
	epatch "${FILESDIR}"/lts6/glibc-rh705465.patch

	# Patch39: glibc-rh703481.patch
	epatch "${FILESDIR}"/lts6/glibc-rh703481.patch

	# Patch40: glibc-rh694386.patch
	epatch "${FILESDIR}"/lts6/glibc-rh694386.patch

	# Patch41: glibc-rh676591.patch
	epatch "${FILESDIR}"/lts6/glibc-rh676591.patch

	# Patch42: glibc-rh711987.patch
	epatch "${FILESDIR}"/lts6/glibc-rh711987.patch

	# Patch43: glibc-rh695595.patch
	epatch "${FILESDIR}"/lts6/glibc-rh695595.patch

	# No Patch44 in the EL SRPM spec file.

	# Patch45: glibc-rh695963.patch
	epatch "${FILESDIR}"/lts6/glibc-rh695963.patch

	# Patch46: glibc-rh713134.patch
	epatch "${FILESDIR}"/lts6/glibc-rh713134.patch

	# Patch47: glibc-rh714823.patch
	epatch "${FILESDIR}"/lts6/glibc-rh714823.patch

	# Patch48: glibc-rh718057.patch
	epatch "${FILESDIR}"/lts6/glibc-rh718057.patch

	# Patch49: glibc-rh688980.patch
	epatch "${FILESDIR}"/lts6/glibc-rh688980.patch

	# Patch50: glibc-rh712248.patch
	epatch "${FILESDIR}"/lts6/glibc-rh712248.patch

	# Patch51: glibc-rh731042.patch
	epatch "${FILESDIR}"/lts6/glibc-rh731042.patch

	# Patch52: glibc-rh730379.patch
	epatch "${FILESDIR}"/lts6/glibc-rh730379.patch

	# Patch53: glibc-rh700507.patch
	epatch "${FILESDIR}"/lts6/glibc-rh700507.patch

	# Patch54: glibc-rh699724.patch
	epatch "${FILESDIR}"/lts6/glibc-rh699724.patch

	# Patch55: glibc-rh736346.patch
	epatch "${FILESDIR}"/lts6/glibc-rh736346.patch

	# Patch56: glibc-rh737778.patch
	epatch "${FILESDIR}"/lts6/glibc-rh737778.patch

	# Patch57: glibc-rh738665.patch
	epatch "${FILESDIR}"/lts6/glibc-rh738665.patch

	# Patch58: glibc-rh738763.patch
	epatch "${FILESDIR}"/lts6/glibc-rh738763.patch

	# Patch59: glibc-rh739184.patch
	epatch "${FILESDIR}"/lts6/glibc-rh739184.patch

	# Patch60: glibc-rh711927.patch
	epatch "${FILESDIR}"/lts6/glibc-rh711927.patch

	# Patch61: glibc-rh754116.patch
	# Revert out the portion of this patch dealing with:
	# * locales/es_CR (LC_ADDRESS): Fix character names in lang_ab.
	epatch "${FILESDIR}"/lts6/glibc-rh754116-v2.patch

	# Patch62: glibc-rh766484.patch
	epatch "${FILESDIR}"/lts6/glibc-rh766484.patch

	# Patch63: glibc-rh767692.patch
	epatch "${FILESDIR}"/lts6/glibc-rh767692.patch

	# Patch64: glibc-rh769594.patch
	# Original failed --dry-run due to being split up.
	epatch "${FILESDIR}"/lts6/patch64-glibc-rh769594-r2.patch

	# Patch65: glibc-rh769594-2.patch
	epatch "${FILESDIR}"/lts6/glibc-rh769594-2.patch

	# Patch66: glibc-rh767692-2.patch
	epatch "${FILESDIR}"/lts6/glibc-rh767692-2.patch

	# Patch67: glibc-rh783999.patch
	epatch "${FILESDIR}"/lts6/glibc-rh783999.patch

	# Patch68: glibc-rh795328.patch
	epatch "${FILESDIR}"/lts6/glibc-rh795328.patch

	# Patch69: glibc-rh794815.patch
	epatch "${FILESDIR}"/lts6/glibc-rh794815.patch

	# Patch70: glibc-rh795328-2.patch
	epatch "${FILESDIR}"/lts6/glibc-rh795328-2.patch

	# Patch71: glibc-rh802855.patch
	epatch "${FILESDIR}"/lts6/glibc-rh802855.patch

	# Patch72: glibc-rh813859.patch
	epatch "${FILESDIR}"/lts6/glibc-rh813859.patch
}

maint_pkg_create() {
	local base="/usr/local/src/gnu/glibc/glibc-${PV:0:1}_${PV:2:1}"
	cd ${base}
	local stamp=$(date +%Y%m%d)
	local d
	for d in libc ports ; do
		#(cd ${d} && cvs up)
		case ${d} in
			libc)  tarball="${P}";;
			ports) tarball="${PN}-ports-${PV}";;
		esac
		rm -f ${tarball}*
		ln -sf ${d} ${tarball}
		tar hcf - ${tarball} --exclude-vcs | lzma > "${T}"/${tarball}.tar.lzma
		du -b "${T}"/${tarball}.tar.lzma
	done
}
