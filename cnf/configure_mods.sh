# In-tree perl modules discovery.

test "$mode" = 'buildmini' && return

# Since 5.10.1 the module dirs are flat, so there's no need
# for recursive search etc.
extdir() {
	for i in $1/*; do
		L=`echo ${i##*/} | sed -e 's!.*-!!'`
		if [ "$L" = "DynaLoader" ]; then
			# do nothing, it's DynaLoader
			true
		# just checking $i/$L.xs is NOT enough, since some extensions
		# like cpan/List-Util have .xs files with different names
		elif ls "$i" | grep -qE '.(xs|c)$'; then
			extadd "xs" "$i"
		elif [ -f "$i/Makefile.PL" -o -f "$i/Makefile" -o -d "$i/lib" -o -f "$i/$L.pm" ]; then
			extadd "noxs" "$i"
		fi
	done
}

extadd() {
	s=`modsymname "$2"`
	if [ "$s" = "dynaloader" ]; then
		msg "    skipping $2"
		return
	fi
	known_extensions="$known_extensions$2 "
	getenv o "only_$s"
	if [ -n "$onlyext" -a -z "$o" ]; then
		msg "    skipping $2"
		extadddisabled "$1" "$2"
		return
	fi
	getenv d "disable_$s"
	if [ -n "$d" -a "$d" != "0" ]; then
		msg "    disabled $2"
		extadddisabled "$1" "$2"
		return
	fi
	getenv t "static_$s"
	if [ "$1" = "xs" -a -n "$t" -a "$t" != "0" ]; then
		msg "    static $2"
		static_ext="$static_ext$2 "
	elif [ "$1" = "xs" -a -n "$allstatic" ]; then
		msg "    static $2"
		static_ext="$static_ext$2 "
	elif [ "$1" = "xs" ]; then
		msg "    dynamic $2"
		dynamic_ext="$dynamic_ext$2 "
	else 
		msg "    non-xs $2"
		nonxs_ext="$nonxs_ext$2 "
	fi
}

extadddisabled() {
	s=`modsymname "$2"`
	if [ "$1" = "xs" ]; then
		disabled_dynamic_ext="$disabled_dynamic_ext$2 "
	else
		disabled_nonxs_ext="$disabled_nonxs_ext$2 "
	fi
}

extonlyif() {
	m="$1"; shift
	s=`modsymname "$m"`
	if [ "$@" ]; then
		return
	else
		log "pre-disabling $s"
		msg "    pre-disabling $s"
		eval "disable_$s=1"
	fi

}

definetrimspaces() {
	v=`echo "$2" | sed -r -e 's/\s+/ /g' -e 's/^\s+//' -e 's/\s+$//'`
	define $1 "$v"
}

msg "Looking which extensions should be disabled"

# These are on unless hinted otherwise
define 'useposix' 'true'
define 'useopcode' 'true'

extonlyif Devel-NYTProf "$i_zlib" = 'define'
extonlyif DB_File "$i_db" = 'define'
extonlyif GDBM_File "$i_gdbm" = 'define'
extonlyif NDBM_File "$i_ndbm" = 'define'
extonlyif ODBM_File "$i_odbm" = 'define'
extonlyif I18N/Langinfo "$i_langinfo" = 'define' -a "$d_nl_langinfo" = 'define'
extonlyif IPC/SysV "$i_msg" = 'define' -o "$i_shm" = 'define' -o "$d_sem" = 'define'
extonlyif Opcode "$useopcode" = 'true'
extonlyif POSIX "$useposix" = 'true'
extonlyif Socket "$d_socket" = 'define'
extonlyif Sys/Syslog "$d_socket" = 'define'
extonlyif cpan/List-Util "$usedl" != 'undef'
extonlyif XS/APItest "$usedl" = 'define'
extonlyif XS/Typemap "$usedl" = 'define'
extonlyif VMS-DCLsym "$osname" = "vms"		# XXX: is it correct?
extonlyif VMS-Stdio "$osname" = "vms"
extonlyif VMS-Filespec "$osname" = "vms"
extonlyif Amiga-ARexx "$osname" = "amiga"
extonlyif Amiga-Exec "$osname" = "amiga"
extonlyif Win32 "$osname" = 'win32'		# XXX: or is it mingw32?
extonlyif Win32API-File "$osname" = 'win32'
extonlyif Win32CORE "$osname" = 'win32'

extonlyif Thread "$usethreads" = 'define'

known_extensions=
dynamic_ext=
static_ext=
nonxs_ext=

for d in ext cpan dist; do
	msg "Looking for extensions recursively under $d/"
	extdir $d
done

msg
msg "Static modules: $static_ext"
msg "Non-XS modules: $nonxs_ext"
msg "Dynamic modules: $dynamic_ext"

definetrimspaces 'static_ext' "$static_ext"
definetrimspaces 'nonxs_ext' "$nonxs_ext"
definetrimspaces 'dynamic_ext' "$dynamic_ext"
definetrimspaces 'known_extensions' "$known_extensions"

# Unless the user explictily asks us not to do it,
# allow building disabled mods with "make cpan/Some-Module"
# This only affects perl-cross Makefile via Makefile.config

if [ "$disabledmods" != 'define' ]; then
	define disabledmods 'define'
	definetrimspaces disabled_dynamic_ext "$disabled_dynamic_ext"
	definetrimspaces disabled_nonxs_ext "$disabled_nonxs_ext"
fi

# Some of the tests use $Config{'extensions'} to decide whether to do their
# thing or not. The original Configure has neither directory nor module names
# there. Instead, it uses weird old mid-road format, "File/Glob", for what
# should have been either File::Glob or ext/File-Glob.
#
# perl-cross keeps full directory names in ${...}_ext and $extensions,
# and does the conversion in configpm. This keeps things simple when writing
# Makefiles and so on, and at the same time doesn't break tests later.

definetrimspaces 'extensions' "$static_ext $dynamic_ext $nonxs_ext"
