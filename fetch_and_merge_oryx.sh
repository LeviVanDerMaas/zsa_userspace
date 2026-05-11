# In Oryx, the three main layout identifiers seem to be a LAYOUTID, REVISIONID, and BOARDTYPE.
# Namely, public layouts can be viewed in a GUI at configure.zsa.io/<BOARDTYPE>/layouts/<LAYOUTID>/<REVISIONID>.
# If you set REVISIONID as `latest` you get the most recent revision (compiled if logged out, WIP if logged in).
#
# You can download the source code of a public layout at https://oryx.zsa.io/source/<REVISIONID>
# You can also query the graphql api at https://oryx.zsa.io/graphql using the layoutID and revisionId (both referred to as hashId in the query)
# When querying with revisionId "latest", the returned revisionId will match that of the most recent compiled revision.

set -e

board="${1:-moonlander}" # board name, determines what keyBOARD dir to put it in
layout="${2:-ParaLanderMkII}" # Layout name, used to map to a layoutId and what keyMAP dir to put it in
revisionId="${3:-latest}"
case "$layout" in
  ParaLanderMkII)
    layoutId="QJ5Wg";;
  *)
    echo "ERROR: No layout matching $layout" >&2
    exit 1;;
esac

# Query layout info (this can be omitted if you already know the revisionId)
oryxInfo=$(
  jq -n \
    --arg layoutId "$layoutId" \
    --arg revisionId "$revisionId" \
    '{
      variables: {
        layoutId: $layoutId,
        revisionId: $revisionId
      },
      query: "query getLayout($layoutId: String!, $revisionId: String!) {
        layout(hashId: $layoutId, revisionId: $revisionId) {
          title
          geometry
          hashId
          revision { hashId title qmkVersion }
        }
      }"
    }' |
  curl --silent --location 'https://oryx.zsa.io/graphql' \
    --header 'Content-Type: application/json' \
    --data @- |
  jq -r '
    .data.layout as $l |
    .data.layout.revision as $r |
    {
      name: $l.title,
      board: $l.geometry,
      layoutId: $l.hashId,
      revisionId: $r.hashId,
      qmkVersion: $r.qmkVersion,
      desc: $r.title,
      url: "https://configure.zsa.io/" + $l.geometry + "/layouts/" + $l.hashId + "/" +  $r.hashId
    }
  '
)
revisionId=$(echo $oryxInfo | jq -r '.revisionId') # Need exact id to get the source
echo "Fetching the following layout from Oryx: $oryxInfo"

# Now download and unzip the source into the appropriate location
tmpZip="${TMPDIR:-/tmp}/oryxSource_${layout}_${revisionId}.zip"
curl -L "https://oryx.zsa.io/source/$revisionId" -o "$tmpZip"
git checkout -q oryx
keymapDir="$(git rev-parse --show-toplevel)/keyboards/zsa/$board/keymaps/$layout"
mkdir -p "$keymapDir"
unzip -ojq "$tmpZip" '*_source/*' -d "$keymapDir"
rm "$tmpZip"
git add "$keymapDir"
echo -e "Oryx: $layout ($board) to revision $revisionId\n\n$oryxInfo" | git commit -q -F - 1> /dev/null ||
  echo -e "\e[1;33mNo layout changes; no new commit made to oryx branch!\e[m"
git checkout -q main
git merge -Xignore-all-space oryx --no-edit -m "Main: merged with oryx revision $revisionId"
