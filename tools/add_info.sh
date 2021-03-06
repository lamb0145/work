#!/bin/bash
#
# TODO: need to add description and example for this one.

CODE_DIR=./
OUT_DIR=./
START_COMMIT=""
END_COMMIT="HEAD"
BZ_ID=""
BREW_ID=""

function usage() {
	echo "This script takes a RHEL git branch and generates a properly"
	echo "formatted set of patches that can be sent using git-send-email"
	echo " "
	echo "-b|--bugid <value>: Bugzilla id for patchset"
	echo "-t|--taskid <value>: Taskid of brew"
	echo "-l|--patchlist <value>: The patchlist"
	echo "-o|--outdir <value>: Output directory.  Default is /tmp/patches"
}

function set_info() {
	echo "" > /tmp/commit_msg
	echo "Bugzilla: https://bugzilla.redhat.com/show_bug.cgi?id=$1" >> /tmp/commit_msg
	echo "Build-Info: http://brewweb.devel.redhat.com/brew/taskinfo?taskID=$2" >> /tmp/commit_msg
	echo "git repo: https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git" >> /tmp/commit_msg
}

function insert_info() {
	echo "commit `head -1 $1 | cut -d ' ' -f 2`" >> /tmp/commit_msg

		BLANK_LINE=`sed -n '/^$/=' $1 |sed -n "1"p`
		let BLANK_LINE=BLANK_LINE-1

		sed -i "${BLANK_LINE} r /tmp/commit_msg" $1
		sed -i '/commit/d' /tmp/commit_msg
}

function rm_all() {
	rm -rf $1
	rm -rf /tmp/commit_id /tmp/commit_id_r
	rm /tmp/commit_msg
}

while [[ $# > 0 ]]
do
	key="$1"
	shift
	case $key in
		-b|--bugid)
			BZ_ID="$1"
			shift;;
		-t|--taskid)
			BREW_ID="$1"
			shift;;
		-l|--patchlist)
			PATCH_LIST="$1"
			shift;;
		-o|--outdir)
			OUT_DIR="$1"
			shift;;
		*)
			# unknown option
			usage
			exit 1;;
	esac
done

TMP_DIR="/tmp/patches$BZ_ID"
SRC_BRANCH=$(git config --local --get format.srcbranch)
DST_BRANCH=$(git config --local --get format.dstbranch)

#TODO: check the var

KERNEL_DIR=`pwd`

# do youself
echo "Are you ready ... y/n?"
read yn
if [ "$yn" != "y" ]; then
	echo "ABORTING..."
	exit 1
fi

cut -d ' ' -f 1 $PATCH_LIST > /tmp/commit_id_r
tac /tmp/commit_id_r > /tmp/commit_id

PATCH_NUMS=`cat /tmp/commit_id | wc -l`

echo "The initial number of patches is $PATCH_NUMS!"

# do some clean
i=1
mkdir ${TMP_DIR}
for line in `cat /tmp/commit_id`
do
	prefix=`printf "%04d" "$i"`
	git format-patch -s -1 $line --stdout > ${TMP_DIR}/$prefix.patch
	let i=i+1
done

# insert the info (eg. bugzilla id) to these patches
set_info $BZ_ID $BREW_ID
cd ${TMP_DIR}
for file in `ls *.patch`
do
	insert_info $file
done

# git am these patches to new branch
cd $KERNEL_DIR
git checkout ${DST_BRANCH}
git am -s ${TMP_DIR}/*.patch

# If there are not applied clean, do it yourself in another terminal, then choose "y" to continue.
echo "All patches are applied clean ... y/n?"
read yn
if [ "$yn" != "y" ]; then
	echo "ABORTING..."
	exit 1
fi

# Make the patches in the new branch
git format-patch --subject-prefix="$(git config --local --get format.rhelversion) BZ ${BZ_ID}" -s -$PATCH_NUMS --cover-letter -o $OUT_DIR
insert_info $OUT_DIR/0000*

rm_all $TMP_DIR
