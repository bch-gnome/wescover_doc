#!/bin/bash
set -x
### buildDoc.sh based on https://github.com/maltfield/rtd-github-pages.git

## install dependencies
pwd
ls -lah
export SOURCE_DATE_EPOCH=$(git log -1 --pretty=%ct)

docroot=`mktemp -d`

export REPO_NAME="${GITHUB_REPOSITORY##*/}"

## build docs

### clean up old builds
make -C doc clean

### get a list of branches, excluding 'HEAD' and 'gh-pages'
versions="`git for-each-ref '--format=%(refname:lstrip=-1)' refs/remotes/origin/ | grep -viE '^(HEAD|gh-pages)$'`"
for current_version in ${versions}; do
	export current_version
	git checkout ${current_version}

	echo "INFO: building sites for ${current_version}"

	#skip branch without doc/ sphinx config
	if [ ! -e 'doc/conf.py' ];then
		echo -e "\tINFO: Couldn't find 'doc/conf.py' (skipped)"
		continue
	fi

	languages="en `find doc/locales/ -mindepth 1 -maxdepth 1 -type d -exec basename '{}' \;`"
	for current_language in ${languages}; do
		export current_language

		echo "INFO: building for ${current_language}"
	
		# HTML
		sphinx-build -b html doc/ doc/_build/html/${current_language}/${current_version} -D language="${current_language}"

		# PDF 
		sphinx-build -b rinoh doc/ doc/_build/rinoh -D language="${current_language}"
		mkdir -p "${docroot}/${current_language}/${current_version}"
		cp "doc/_build/rinoh/target.pdf" "${docroot}/${current_language}/${current_version}/helloWorld-docs_${current_language}_${current_version}.pdf"

		# copy static assets into docroot
		rsync -av "doc/_build/html/" "${docroot}/"
	done
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
