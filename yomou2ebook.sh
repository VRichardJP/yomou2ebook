#!/bin/bash

set -e

SELF_DIR=$(dirname $(realpath -s $0))
TMP_DIR=$SELF_DIR/tmp

usage () {
    echo "usage:" 
    echo "  $0 <main_url>"
    echo ""
    echo "where: "
    echo "  <main_url> is the url of the main page of the book"
    echo "             for example: http://ncode.syosetu.com/n6316bn"
}

if [[ $# != 1 ]]; then
    usage
    exit 1
fi

MAIN_URL="$1"
# remove trailing '/'
MAIN_URL=${1%/}
TXT_OUT="output.txt"
EPUB_OUT="output.epub"

# IP will be banned for a short time if pages are loaded too fast
SLEEP_TIME=0.1

if [[ -e $TMP_DIR ]]; then
    rm -r $TMP_DIR
fi
mkdir $TMP_DIR

pushd $TMP_DIR > /dev/null

# Load main page
wget -q $MAIN_URL -O main_page.html
sleep $SLEEP_TIME
# <p class="nover_title">XXX</p>
NOVEL_TITLE=`pcregrep -Mo '(?s)<p class=\"novel_title\">.*?</p>' main_page.html | sed -E 's/<[^>]*>//g'`
# <div class="novel_writername">...<a ...>XXX</a></div>
WRITER_NAME=`pcregrep -Mo '(?s)<div class=\"novel_writername\">.*?</div>' main_page.html | grep -Po '<a .*?>.*?</a>' | sed -E 's/<[^>]*>//g'`
# <div id="novel_ex">XXX</div>
NOVEL_SUMMARY=`pcregrep -Mo '(?s)<div id=\"novel_ex\">.*?</div>' main_page.html | sed -E 's/<[^>]*>//g'`
# <dd class="subtitle"><a href="XXX">...</a></dd>
CHAPTER_LIST=`pcregrep -Mo '(?s)<dd class=\"subtitle\">.*?</dd>' main_page.html | grep -Po 'href=\".*?\"' | sed -E 's/^.*href=\"([^"])\".*$/\1/g' | cut -d'/' -f3`

echo "Found the following novel:"
echo "Title: $NOVEL_TITLE"
echo "Author: $WRITER_NAME"
echo "Summary:"
echo "$NOVEL_SUMMARY"
echo "Number of chapters: `echo $CHAPTER_LIST | wc -w`"
echo ""

if [[ -e $TXT_OUT ]]; then
    rm $TXT_OUT
fi
touch $TXT_OUT

echo "% $NOVEL_TITLE" >> $TXT_OUT
echo "% $WRITER_NAME" >> $TXT_OUT
echo "$NOVEL_SUMMARY" >> $TXT_OUT
# 2 empty lines
echo "" >> $TXT_OUT
echo "" >> $TXT_OUT

for chapter_page in $CHAPTER_LIST; do
    wget -q $MAIN_URL/$chapter_page -O $chapter_page.html
    sleep $SLEEP_TIME
    # <p class="novel_subtitle">XXX</p>
    chapter_title=`pcregrep -Mo '(?s)<p class=\"novel_subtitle\">.*?</p>' $chapter_page.html | sed -E 's/<[^>]*>//g'`
    # <div id="novel_honbun" class="novel_view"><p id="L1">XXX</p><p id="L2">XXX</p>...</div>
    chapter_paragraph=`pcregrep --buffer-size=100K -Mo '(?s)<div id=\"novel_honbun\" class=\"novel_view\">.*?</div>' $chapter_page.html | grep -P '<p id=\"L[0-9]+\">.*?</p>'`
    echo "$chapter_title"
    echo "# $chapter_title" >> $TXT_OUT
    echo "" >> $TXT_OUT
    printf %s "$chapter_paragraph" |
    while IFS= read -r paragraph; do
        # parse image (if any)
        if [[ `echo $paragraph | grep -Po "<img .*/>"` ]]; then
            image=`echo $paragraph | grep -Po "<img .*/>"`
            line_id=`echo $paragraph | sed -E 's/^.*<p id=\"([^"]*)\">.*$/\1/g'`
            image_path=`echo $image | sed -E 's/^.*src=\"([^"]*)\".*$/\1/g'`
            image_name=`echo $image | sed -E 's/^.*alt=\"([^"]*)\".*$/\1/g'`
            wget -q http:$image_path -O ${chapter_page}_${line_id}.jpg
            sleep $SLEEP_TIME
            paragraph=`echo $paragraph | sed -E 's/<img [^>]*>/!['"$image_name"']('"${chapter_page}_${line_id}.jpg"')/g'`
        fi
        # fix " character
        text=`echo $paragraph | sed -E 's/<[^>]*>//g' | sed -E 's/&quot;/"/g'`
        # double space = new line
        echo "$text  " >> $TXT_OUT
    done
    # 2 empty lines
    echo "" >> $TXT_OUT
    echo "" >> $TXT_OUT
done
echo ""

if [[ -e $EPUB_OUT ]]; then
    rm $EPUB_OUT
fi

echo "Convert raw txt to epub"
pandoc $TXT_OUT -o $EPUB_OUT

cp $TXT_OUT $SELF_DIR
cp $EPUB_OUT $SELF_DIR

echo "Done"

popd > /dev/null
rm -r $TMP_DIR
