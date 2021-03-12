#!/bin/bash
set -x
### buildDoc.sh based on https://github.com/maltfield/rtd-github-pages.git

## install dependencies
apt-get update
apt-get -y install git rsync python3-sphinx python3-sphinx-rtd-theme python3-stemmer python3-git python3-pip python3-virtualenv python3-setuptools

python3 -m pip install --upgrade rinohtype pygments

pwd
ls -lah
export SOURCE_DATE_EPOCH=$(git log -1 --pretty=%ct)

docroot=`mktemp -d`

export REPO_NAME="${GITHUB_REPOSITORY##*/}"

## build docs

### clean up old builds
make -C docs clean

### get a list of branches, excluding 'HEAD' and 'gh-pages'
versions="`git for-each-ref '--format=%(refname:lstrip=-1)' refs/remotes/origin/ | grep -viE '^(HEAD|gh-pages)$'`"
for current_version in ${versions}; do
	export current_version
	git checkout ${current_version}

	echo "INFO: building sites for ${current_version}"

	#skip branch without doc/ sphinx config
	if [ ! -e 'docs/conf.py' ];then
		echo -e "\tINFO: Couldn't find 'docs/conf.py' (skipped)"
		continue
	fi

	echo "INFO: building docs"

	#HTML
	sphinx-build -b html docs/ docs/_build/html/${current_version} -D language="en"

	rsync -av "docs/_build/html/" "${docroot}/"
done

git checkout master

## update github pages
git config --global user.name "${GITHUB_ACTOR}"
git config --global user.email "${GITHUB_ACTOR}@users.noreply.github.com"

pushd "${docroot}"

git init
git remote add deploy "https://token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
git checkout -b gh-pages

touch .nojekyll

# add redirect from the docroot to our default docs language/version
cat > index.html <<EOF
<!DOCTYPE html>
<html>
   <head>
      <title>helloWorld Docs</title>
      <meta http-equiv = "refresh" content="0; url='/${REPO_NAME}/en/master/'" />
   </head>
   <body>
      <p>Please wait while you're redirected to our <a href="/${REPO_NAME}/en/master/">documentation</a>.</p>
   </body>
</html>
EOF

cat > README.md <<EOF
# GitHub Pages Cache
 
Nothing to see here. The contents of this branch are essentially a cache that's not intended to be viewed on github.com.
 
 
If you're looking to update our documentation, check the relevant development branch's 'docs/' dir.
 
For more information on how this documentation is built using Sphinx, Read the Docs, and GitHub Actions/Pages, see:
 
 * https://tech.michaelaltfield.net/2020/07/18/sphinx-rtd-github-pages-1
EOF

git add .

msg="Updating Docs for commit ${GITHUB_SHA} made on `date -d"@${SOURCE_DATE_EPOCH}" --iso-8601=seconds` from ${GITHUB_REF} by ${GITHUB_ACTOR}"
git commit -am "${msg}"

git push deploy gh-pages --force

popd

exit 0

