#!/bin/bash

set -e

SELF_DIR=`dirname "$0"`
TMP_DIR=$SELF_DIR/tmp

usage () {
    echo "usage:" 
    echo "  $0 <book_id>"
    echo ""
    echo "where: "
    echo "  <book_id> is the id of the book in the main page url"
    echo "            for example: the id of http://ncode.syosetu.com/n6316bn/ is n6316bn"
}

if [[ $# != 1 ]]; then
    usage
    exit 1
fi

NOVEL_ID="$1"
TXT_OUT="$SELF_DIR/output.txt"
EPUB_OUT="$SELF_DIR/output.epub"
BASE_URL="http://ncode.syosetu.com/"
MAIN_URL=$BASE_URL/$NOVEL_ID

# IP will be banned if pages are loaded too fast
SLEEP_TIME=1

if [[ -e $TMP_DIR ]]; then
    rm -r $TMP_DIR
fi
mkdir $TMP_DIR

# Load main page
wget -q $MAIN_URL -O $TMP_DIR/$NOVEL_ID.html
sleep $SLEEP_TIME
NOVEL_TITLE=`pcregrep -Mo '(?s)<p class=\"novel_title\">.*?</p>' $TMP_DIR/$NOVEL_ID.html | sed -E 's/<[^>]*>//g'`
WRITER_NAME=`pcregrep -Mo '(?s)<div class=\"novel_writername\">.*?</div>' $TMP_DIR/$NOVEL_ID.html | grep -P '<a .*?>.*?</a>' | sed -E 's/<[^>]*>//g'`
NOVEL_SUMMARY=`pcregrep -Mo '(?s)<div id=\"novel_ex\">.*?</div>' $TMP_DIR/$NOVEL_ID.html | sed -E 's/<[^>]*>//g'`
CHAPTER_LIST=`pcregrep -Mo '(?s)<dd class=\"subtitle\">.*?</dd>' $TMP_DIR/$NOVEL_ID.html | grep -P 'href=\".*?\"' | sed -E 's/^.*href=\"(.*?)\".*$/\1/g' | cut -d'/' -f3`

echo "Found the following novel:"
echo "Title: $NOVEL_TITLE"
echo "Author: $WRITER_NAME"
echo "Summary:"
echo "$NOVEL_SUMMARY"
echo "Number of chapters: `echo $CHAPTER_LIST | wc -w`"
echo

if [[ -e $TXT_OUT ]]; then
    rm $TXT_OUT
fi
touch $TXT_OUT

echo "% $NOVEL_TITLE" >> $TXT_OUT
echo "% $WRITER_NAME" >> $TXT_OUT
echo "$NOVEL_SUMMARY" >> $TXT_OUT
# 2 empty lines
echo >> $TXT_OUT
echo >> $TXT_OUT

for chapter_page in $CHAPTER_LIST; do
    wget -q $MAIN_URL/$chapter_page -O $TMP_DIR/$chapter_page.html
    sleep $SLEEP_TIME
    chapter_title=`pcregrep -Mo '(?s)<p class=\"novel_subtitle\">.*?</p>' $TMP_DIR/$chapter_page.html | sed -E 's/<[^>]*>//g'`
    chapter_paragraph=`pcregrep --buffer-size=100K -Mo '(?s)<div id=\"novel_honbun\" class=\"novel_view\">.*?</div>' $TMP_DIR/$chapter_page.html | grep -P '<p id=\"L[0-9]+\">.*?</p>'`
    echo "$chapter_title"
    echo "# $chapter_title" >> $TXT_OUT
    echo >> $TXT_OUT
    printf %s "$chapter_paragraph" |
    while IFS= read -r paragraph; do
        text=`echo $paragraph | sed -E 's/<[^>]*>//g' | sed -E 's/&quot;/"/g'`
        # double space = new line
        echo "$text  " >> $TXT_OUT
    done
    # 2 empty lines
    echo >> $TXT_OUT
    echo >> $TXT_OUT
done
echo

if [[ -e $EPUB_OUT ]]; then
    rm $EPUB_OUT
fi

echo "Convert raw txt to epub"
pandoc $TXT_OUT -o $EPUB_OUT

echo "Done"

rm -r $TMP_DIR
