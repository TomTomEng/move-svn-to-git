#!/bin/bash

if [ -z $3 ]; then
	echo "usage $0"
	echo "1. svn location"
	echo "2. git url"	
	echo "3. component name (should be equal in svn/git)"
	exit -1
else
	# init process logfile arguments
	SVN_LOCATION=$1
	GIT_URL=$2
	COMPONENT_NAME=$3

	export TAGS_SVN=`svn ls $SVN_LOCATION/tags | grep "$COMPONENT_NAME" | cut -f1 -d'/' | tr "\n" "," | sed 's/,$//'`
	echo '====================================== tags retrieved'
	export BRANCHES_SVN=`svn ls $SVN_LOCATION/branches | grep "$COMPONENT_NAME" | cut -f1 -d'/' | tr "\n" "," | sed 's/,$//'`
	echo '====================================== branches retrieved'

	git svn init --prefix=svn/ --trunk=trunk/$COMPONENT_NAME $SVN_LOCATION
	git config --local svn.authorsfile authors.txt
	echo '====================================== repo inited'

	if [ $BRANCHES_SVN ]; then
		git config --add svn-remote.svn.branches branches/{$BRANCHES_SVN}:refs/remotes/svn/*
	fi
	if [ $TAGS_SVN ]; then
		git config --add svn-remote.svn.tags tags/{$TAGS_SVN}:refs/remotes/svn/tags/*
	fi

	echo '====================================== repo configured'
	git svn fetch

	echo '====================================== svn fetched'
	git checkout svn/trunk

	echo '====================================== switched to master in git'
	git branch -d master
	git checkout -b master

	echo '====================================== restoring tags'
	# convert svn tags (which are now git remote branches) to actual git tags
	git for-each-ref refs/remotes/svn/tags | cut -d / -f 5- | grep -v @ | while read tagname; do git tag "$tagname" "svn/tags/$tagname"; git branch -rd "svn/tags/$tagname"; done

	echo '====================================== restoring branches'
	# convert svn branches to actual git branches (and skip trunk!)
	git for-each-ref refs/remotes/svn | cut -d / -f 4- | grep -v trunk | grep -v @  | while read branchname; do git branch "$branchname" "svn/$branchname"; git branch -rd "svn/$branchname"; done

	echo '====================================== check one root remains'
	# check manually that exactly one root remains.
	git rev-list --max-parents=0 --all # should show one commit

	echo '====================================== adding remotes'
	# add remote, and push it all
	git remote add origin $GIT_URL
	git push origin --all
	git push origin --tags

	# done!
fi
