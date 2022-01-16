#!/bin/bash

INITIAL_SLEEP_SEC=5

read -p "画面キャプチャ枚数 (1-100)? : " PAGE_MAX
# PAGE_MAXが整数かどうかチェック (exprの終了ステータスが数値の場合0or1を利用)
expr $PAGE_MAX + 1 > /dev/null 2>&1
if [ $? -ge 2 -o -z "$PAGE_MAX" ]; then
    echo "整数以外または空白が入力されました"
    exit
fi
# ページ数の最小・最大をチェック
if [ $PAGE_MAX -lt 1 -o $PAGE_MAX -gt 100 ]; then
    echo "キャプチャ枚数が 1 〜 100 の範囲外です"
    exit
fi
echo "PAGE_MAX = $PAGE_MAX"



read -p "キャプチャ間インターバル秒数 (1-10)? : " INTERVAL_SLEEP_SEC
# INTERVAL_SLEEP_SECが整数かどうかチェック (exprの終了ステータスが数値の場合0or1を利用)
expr $INTERVAL_SLEEP_SEC + 1 > /dev/null 2>&1
if [ $? -ge 2 -o -z "$INTERVAL_SLEEP_SEC" ]; then
    echo "整数以外または空白が入力されました"
    exit
fi
# ページ数の最小・最大をチェック
if [ $INTERVAL_SLEEP_SEC -lt 1 -o $INTERVAL_SLEEP_SEC -gt 10 ]; then
    echo "インターバル秒数が 1 〜 10 の範囲外です"
    exit
fi
echo "INTERVAL_SLEEP_SEC = $INTERVAL_SLEEP_SEC"



read -p "キーボード入力のエミュレーション (Left/Right)? : " KEYBOARD_SHOT
# INTERVAL_SLEEP_SECが整数かどうかチェック (exprの終了ステータスが数値の場合0or1を利用)
if [ -z "$KEYBOARD_SHOT" ]; then
    echo "空白が入力されました"
    exit
fi
if [ "$KEYBOARD_SHOT" != 'Left' -a "$KEYBOARD_SHOT" != 'Right' ]; then
    echo "Left/Right以外が入力されました"
    exit
fi
echo "KEYBOARD_SHOT = $KEYBOARD_SHOT"

read -p "Enterキーを押すと、$INITIAL_SLEEP_SEC秒後から画面キャプチャを開始し、カレントディレクトリ（`pwd`）に画像を保存します :" STR_DUMMY

sleep $INITIAL_SLEEP_SEC

for ((PAGE_CUR=0 ; PAGE_CUR<PAGE_MAX ; PAGE_CUR++))
do
    CUR_TIME=`date '+%Y-%m-%d-%H-%M-%S-%3N'`
    echo "save image to ... $CUR_TIME.jpg"
    gnome-screenshot -f "$CUR_TIME.jpg"

    echo "key push ... $KEYBOARD_SHOT"
    xte "key $KEYBOARD_SHOT"

    echo "sleep ... $INTERVAL_SLEEP_SEC"
    sleep $INTERVAL_SLEEP_SEC
done

echo "終了しました"
/usr/bin/canberra-gtk-play --file=/usr/share/sounds/gnome/default/alerts/bark.ogg

