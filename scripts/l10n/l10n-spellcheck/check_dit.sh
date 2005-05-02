#!/bin/bash
#
# usage: check_dit <lang> <aspell-suffix> <D-I repository path> <output dir>
#
# check_dit - d-i translations spell-checker
#
# Packages: aspell, aspell-bin, aspell-${DICT}
#
# Author: Davide Viti <zinosat@tiscali.it> 2004, for the Debian Project
#

usage() {
    echo  "Usage:"
    echo  "$0 <lang> <aspell-suffix> <D-I repository path> <output dir>"
}

initialise() {
GATHER_MSGSTR_SCRIPT=./msgstr_extract.awk
GATHER_MSGID_SCRIPT=./msgid_extract.awk
CHECK_VAR=./check_var.pl

ALL_STRINGS=$DEST_DIR/${LANG}_all.txt
FILES_TO_KEEP="$ALL_STRINGS $FILES_TO_KEEP"

NO_VARS=$DEST_DIR/1_no_vars_${LANG}

ALL_UNKNOWN=$DEST_DIR/2_all_unkn_${LANG}
NEEDS_RM="$ALL_UNKNOWN $NEEDS_RM"

UNKN=$DEST_DIR/${LANG}_unkn_wl.txt
FILES_TO_KEEP="$UNKN $FILES_TO_KEEP"

SUSPECT_VARS=$DEST_DIR/${LANG}_var.txt
}

checks(){

if [ ! -d $BASE_SEARCH_DIR ] ; then
    echo $BASE_SEARCH_DIR does not exist
    exit 1
fi

if [ ! -f $GATHER_MSGSTR_SCRIPT ] ; then
    echo "$GATHER_MSGSTR_SCRIPT does not exist. You need it!"
    exit 1
fi

if [ ! -f $GATHER_MSGID_SCRIPT ] ; then
    echo "$GATHER_MSGID_SCRIPT does not exist. You need it!"
    exit 1
fi

if [ ! -f $CHECK_VAR ] ; then
    echo "$CHECK_VAR does not exist. You need it!"
    exit 1
fi

if [ ! -d $DEST_DIR ] ; then
    mkdir $DEST_DIR
fi

}

if [ -z "$4" ]
    then
    usage
    exit 1
fi

LANG=$1
DICT=$2
BASE_SEARCH_DIR=$3
DEST_DIR=$4

initialise	# initalise some variables
checks		# do an environment check

PO_FILE_LIST="${LANG}_file_list.txt"
NEEDS_RM="$PO_FILE_LIST $NEEDS_RM"

sh $PO_FINDER $BASE_SEARCH_DIR $LANG > $PO_FILE_LIST

rm -f $ALL_STRINGS
for LANG_FILE in `cat $PO_FILE_LIST`; do
    ENC=`cat $LANG_FILE | grep -e "^\"Content-Type:" | sed 's:^.*charset=::' | sed 's:\\\n\"::'`

    echo "$LANG_FILE" | grep -e ".po$" > /dev/null
    if  [ $? = 0 ] ; then

	echo $ENC | grep -iw "utf-8" > /dev/null
	if [ $? = 0 ]  ; then
	    if [ $HANDLE_SUSPECT_VARS = "yes" ] ; then
		$CHECK_VAR -s $LANG_FILE >> $SUSPECT_VARS
	    fi
	    awk -f $GATHER_MSGSTR_SCRIPT $LANG_FILE >> $ALL_STRINGS
	else
	    if [ $HANDLE_SUSPECT_VARS = "yes" ] ; then
		$CHECK_VAR -s $LANG_FILE | iconv --from $ENC --to utf-8 >> $SUSPECT_VARS
	    fi
	    awk -f $GATHER_MSGSTR_SCRIPT $LANG_FILE | iconv --from $ENC --to utf-8 >> $ALL_STRINGS
	fi

    else			# now deal with ".pot" files
	if [ $HANDLE_SUSPECT_VARS = "yes" ] ; then
	    $CHECK_VAR -s $LANG_FILE >> $SUSPECT_VARS
	fi
	awk -f $GATHER_MSGID_SCRIPT $LANG_FILE >> $ALL_STRINGS
    fi
done

if [ $HANDLE_SUSPECT_VARS = "yes" ] ; then
    if [ `ls -l $SUSPECT_VARS | awk '{print $5}'` -gt 0 ]; then
	FILES_TO_KEEP="$SUSPECT_VARS $FILES_TO_KEEP" 
	SUSPECT_EXIST=1
    else
	rm $SUSPECT_VARS
	SUSPECT_EXIST=0
    fi
fi

# remove ${ALL_THESE_VARIABLES} if they do not need to be spell checked
if [ $REMOVE_VARS = "yes" ] ; then
    NEEDS_RM="$NO_VARS $NEEDS_RM"
    grep -e "^-" $ALL_STRINGS | sed s/\$\{[a-zA-Z0-9_]*\}//g > $NO_VARS
    FILE_TO_CHECK=$NO_VARS
else
    FILE_TO_CHECK=$ALL_STRINGS
fi

# if a binary wl exists, use it
if [ -f ./wls/${LANG}_di_wl ] ; then
    WL_PARAM="--add-extra-dicts ./wls/${LANG}_di_wl"
fi

# spell check the selected strings eventually using a custom wl 
cat $FILE_TO_CHECK | aspell list --lang=$LANG --encoding=utf-8 $WL_PARAM $ASPELL_EXTRA_PARAM > $ALL_UNKNOWN

# sort all the unrecognized words (don't care about upper/lower case)
# count duplicates
# take note of unknown words
cat $ALL_UNKNOWN | sort -f | uniq -c > $UNKN

# if we're *not* handling suspecet vars (i.e. d-i manual), make this an empty string
if [ $HANDLE_SUSPECT_VARS = "no" ] ; then
    SUSPECT_EXIST=
fi

# build the entry of stats.txt for the current language (i.e "395 it 1")
echo `wc -l $UNKN | awk '{print $1}'` $LANG $SUSPECT_EXIST >> ${DEST_DIR}/stats.txt

rm $NEEDS_RM

if [ ! -d  $DEST_DIR/zip ] ; then
    mkdir $DEST_DIR/zip
fi

if [ ! -d  $DEST_DIR/nozip ] ; then
    mkdir $DEST_DIR/nozip
fi

# in the tgz file WL is iso-8859-1 (the way it has to be)
# in "nozip" it's utf-8 like the other files 
if [ -f ./wls/${LANG}_wl.txt ] ; then
    WORDLIST=./wls/${LANG}_wl.txt
    cat ${WORDLIST} | iconv --from iso-8859-1 --to utf-8 > $DEST_DIR/nozip/${LANG}_wl.txt
    cp ${WORDLIST} ${DEST_DIR}
    WL_ISO8859=${DEST_DIR}/${LANG}_wl.txt
fi

tar czf ${DEST_DIR}/${LANG}.tar.gz $FILES_TO_KEEP ${WL_ISO8859}

mv ${DEST_DIR}/${LANG}.tar.gz ${DEST_DIR}/zip

mv $FILES_TO_KEEP ${DEST_DIR}/nozip
rm -f ${WL_ISO8859}

echo "AddCharset UTF-8 .txt" > ${DEST_DIR}/nozip/.htaccess
