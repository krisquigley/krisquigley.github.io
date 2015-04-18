#!/usr/bin/env sh
rake publish
pushd build
git push origin gh-pages:master
popd