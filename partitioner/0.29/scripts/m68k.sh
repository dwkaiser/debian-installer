
DISK="$1"
[ -z "$DISK" ] && exit 1

case "`archdetect`" in
"m68k/amiga")
	amiga-fdisk $DISK
	;;
"m68k/atari")
	atari-fdisk $DISK
	;;
"m68k/mac")
	mac-fdisk $DISK
	;;
"m68k/*vme*")
	pmac-fdisk $DISK
	;;
"m68k/q40")
	atari-fdisk $DISK
	;;
"m68k/sun*")
	parted $DISK
	;;
*)
	parted $DISK
	;;
esac

if [ -x /usr/bin/update-dev ]; then
	logger -t "partitioner" "userdevfs: update-dev"
        /usr/bin/update-dev 2>&1 | logger -t "update-dev"
fi

exit $?

