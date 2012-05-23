# Copyright 1999-2010 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/dev-libs/libgcrypt/Attic/libgcrypt-1.4.5.ebuild,v 1.8 2010/10/16 15:43:31 arfrever dead $

EAPI="4"

inherit eutils flag-o-matic toolchain-funcs rpm lts6-rpm

DESCRIPTION="general purpose crypto library based on the code used in GnuPG"
HOMEPAGE="http://www.gnupg.org/"
SRPM="libgcrypt-1.4.5-9.el6_2.2.src.rpm"
SRC_URI="mirror://lts62/vendor/${SRPM}"
RESTRICT="mirror"

LICENSE="LGPL-2.1"
SLOT="0"
KEYWORDS="~alpha ~amd64 ~arm ~hppa ~ia64 ~m68k ~mips ~ppc ~ppc64 ~s390 ~sh ~sparc ~x86 ~amd64-fbsd ~sparc-fbsd ~x86-fbsd"
IUSE="static-libs"

RDEPEND=">=dev-libs/libgpg-error-1.5"
DEPEND="${RDEPEND}"

SRPM_PATCHLIST="
# make FIPS hmac compatible with fipscheck - non upstreamable
Patch2: libgcrypt-1.4.4-use-fipscheck.patch
# use /dev/urandom in the FIPS mode
Patch4: libgcrypt-1.4.5-urandom.patch
# fix tests in the FIPS mode, fix the FIPS-186-3 DSA keygen
Patch5: libgcrypt-1.4.5-tests.patch
# add configurable source of RNG seed in the FIPS mode
Patch6: libgcrypt-1.4.5-fips-cfgrandom.patch
# make the FIPS-186-3 DSA CAVS testable
Patch7: libgcrypt-1.4.5-cavs.patch
# add GCRYCTL_SET_ENFORCED_FIPS_FLAG
Patch8: libgcrypt-1.4.5-set-enforced-mode.patch
"

src_prepare() {
	epunt_cxx

	lts6_srpm_epatch || die
}

src_configure() {
	LDFLAGS="${LDFLAGS} -Wl,-z,relro"

	# --disable-padlock-support for bug #201917
	econf \
		--disable-padlock-support \
		--disable-dependency-tracking \
		--with-pic \
		--enable-noexecstack \
		--enable-pubkey-ciphers='dsa elgamal rsa' \
		$(use_enable static-libs static)
}

src_install() {
	emake DESTDIR="${D}" install || die "emake install failed"
	dodoc AUTHORS ChangeLog NEWS README* THANKS TODO

	use static-libs || find "${D}" -name '*.la' -delete
}
