#!/usr/bin/perl

# save this file in UTF-8 (linux) or Shift-JIS (Windows ActivePerl)
# ******************************************************
# Software name : Divide and Contrast adjust of Image files 
#          （書籍イメージ化用ツール：jpegファイルを左右分割、コントラスト調整）
#
# Copyright (C) INOUE Hirokazu, All Rights Reserved
#     http://oasis.halfmoon.jp/
#
# image-divider.pl
# version 0.1 (2010/December/06)
# version 0.2 (2012/January/10)
# version 0.3 (2012/March/08)
# version 0.3.1 (2012/March/09)
# version 0.4  (2015/March/20)
#
# GNU GPL Free Software
#
# このプログラムはフリーソフトウェアです。あなたはこれを、フリーソフトウェア財
# 団によって発行された GNU 一般公衆利用許諾契約書(バージョン2か、希望によっては
# それ以降のバージョンのうちどれか)の定める条件の下で再頒布または改変することが
# できます。
# 
# このプログラムは有用であることを願って頒布されますが、*全くの無保証* です。
# 商業可能性の保証や特定の目的への適合性は、言外に示されたものも含め全く存在し
# ません。詳しくはGNU 一般公衆利用許諾契約書をご覧ください。
# 
# あなたはこのプログラムと共に、GNU 一般公衆利用許諾契約書の複製物を一部受け取
# ったはずです。もし受け取っていなければ、フリーソフトウェア財団まで請求してく
# ださい(宛先は the Free Software Foundation, Inc., 59 Temple Place, Suite 330
# , Boston, MA 02111-1307 USA)。
#
# http://www.opensource.jp/gpl/gpl.ja.html
# ******************************************************

use strict;
use warnings;
use utf8;

my $flag_os = 'linux';  # linux/windows
my $flag_charcode = 'utf8';     # utf8/shiftjis

use Encode::Guess qw/euc-jp shiftjis iso-2022-jp/;  # 必要ないエンコードは削除すること
use Image::Magick;
use Image::ExifTool;
use Image::Size;
use File::Basename;
use File::Glob;
use File::Temp qw/tempfile/;

#use Data::Dumper;

# IOの文字コードを規定
if($flag_charcode eq 'utf8'){
    binmode(STDIN, ":utf8");
    binmode(STDOUT, ":utf8");
    binmode(STDERR, ":utf8");
}
if($flag_charcode eq 'shiftjis'){
    binmode(STDIN, "encoding(sjis)");
    binmode(STDOUT, "encoding(sjis)");
    binmode(STDERR, "encoding(sjis)");
}


my $strInputDir = './';         # 入力ファイルのあるディレクトリ
my $strOutputDir = './';        # 出力ディレクトリ
my $strSearchPattern = '*.jpg'; # 対象ファイル（検索文字列）
my $nTrimRate = 0;              # 周囲を切り取る率（0〜50）％
my $nCenterOverlapRate = 0;     # LR/RL切り分け時、ページ中央を重複させる
my $flag_LR = 'LR';             # ページ順 LR または RL、左右に2分割しない場合は N

my $nGamma = 0.4;               # 画像補正値：ガンマ
my $nUnsharpMaskAmount = 0;     # アンシャープマスクの強さ指定（0はOFF）
my $nSharpenAmount = 0.0;         # シャープネスの強さ指定（0はOFF）
my $nBlackThreshold = 20;       # 画像補正値：黒レベル強制（％）
my $nWhiteThreshold = 80;       # 画像補正値：白レベル強制（％）
my $nQuality = 85;              # jpeg保存クオリティ

sub_main();
exit;


sub sub_main {
    my @arrScan = undef;    # ファイル一覧を一時的に格納する配列

    print("指定されたフォルダの全ファイルを左右二分割、コントラスト調整します\n");

    sub_user_input_init();
    if(sub_check_same_dir()){
        die("入出力ディレクトリが同一です\n");
    }

    sub_scan_imagefiles(\@arrScan);

    if($#arrScan < 0){die("処理対象ファイルが見つかりません\n"); }
    printf("処理対象ファイル数：%d\n", $#arrScan+1);

    if($flag_LR eq 'RL'){
        my $i = 1;
        foreach(@arrScan) {
            sub_split_image(sub_conv_to_flagged_utf8($_), $i, 'R');
            $i++;
            sub_split_image(sub_conv_to_flagged_utf8($_), $i, 'L');
            $i++;
        }
    }
    elsif($flag_LR eq 'LR'){
        my $i = 1;
        foreach(@arrScan) {
            sub_split_image(sub_conv_to_flagged_utf8($_), $i, 'L');
            $i++;
            sub_split_image(sub_conv_to_flagged_utf8($_), $i, 'R');
            $i++;
        }
    }
    else{
        my $i = 1;
        foreach(@arrScan) {
            sub_split_image(sub_conv_to_flagged_utf8($_), $i, 'N');
            $i++;
        }
    }
}

# 対象ディレクトリ、処理形式などのユーザ入力（コンソール版）
sub sub_user_input_init {

    # プログラムの第1引数は、入力ディレクトリ
    if($#ARGV >= 0 && length($ARGV[0])>1)
    {
        $strInputDir = sub_conv_to_flagged_utf8($ARGV[0]);
    }
    # 入力ディレクトリの入力
    print("入力ディレクトリを、絶対または相対ディレクトリで入力。".
        "\n（例：/home/user/, ./）[".$strInputDir."] :");
    $_ = <STDIN>;
    chomp();
    unless(length($_)<=0){ $strInputDir = $_; }
    if(substr($strInputDir,-1) ne '/'){ $strInputDir .= '/'; }  # ディレクトリは / で終わるように修正
    unless(-d sub_conv_to_local_charset($strInputDir)){ die("終了（理由：ディレクトリ ".$strInputDir." が存在しません）\n"); }
    print("入力ディレクトリ : " . $strInputDir . "\n");


    # プログラムの第2引数は、出力ディレクトリ
    if($#ARGV >= 1 && length($ARGV[1])>1)
    {
        $strOutputDir = sub_conv_to_flagged_utf8($ARGV[1]);
    }
    # 出力ディレクトリの入力
    print("出力ディレクトリを、絶対または相対ディレクトリで入力。".
        "\n（例：/home/user/, ./）[".$strOutputDir."] :");
    $_ = <STDIN>;
    chomp();
    unless(length($_)<=0){ $strOutputDir = $_; }
    if(substr($strOutputDir,-1) ne '/'){ $strOutputDir .= '/'; }    # ディレクトリは / で終わるように修正
    unless(-d sub_conv_to_local_charset($strOutputDir)){ die("終了（理由：ディレクトリ ".$strOutputDir." が存在しません）\n"); }
    print("出力ディレクトリ : " . $strOutputDir . "\n");
    
    # 入出力先が同一の場合はエラー
    if($strInputDir eq $strOutputDir){ die("終了（入出力ディレクトリが同じです）\n"); }


    # ページ順の入力
    print("ページ順（右左=RL、左右=LR）または左右分割無し（N）を入力 (LR/RL/N) [N] :");
    $_ = <STDIN>;
    chomp();
    if(length($_)<=0){ $flag_LR = 'N'; }
    elsif(uc($_) eq 'LR'){ $flag_LR = 'LR'; }
    elsif(uc($_) eq 'RL'){ $flag_LR = 'RL'; }
    elsif(uc($_) eq 'N'){ $flag_LR = 'N'; }
    else{ die("終了（理由：LR, RL以外が入力されました）\n"); }
    print("ページ順=".$flag_LR."\n");


    # 画像の周囲を切り抜き（トリム）
    print("周囲を切り取る率(%)を入力 (0 〜 50) [0]： ");
    $_ = <STDIN>;
    chomp();
    if(length($_)<=0){ $nTrimRate = 0; }
    elsif(int($_)<0 || int($_)>50){ die("終了（理由：0〜50を入力してください）\n"); }
    else{ $nTrimRate = int($_); }
    print("Trim=".$nTrimRate."%\n");

    # ページ左右切り分け時、ページ中央をオーバーラップさせる割合
    if($flag_LR ne 'N'){
        print("切り分けページ中央のオーバーラップ率(%)を入力 (0 〜 10) [0]： ");
        $_ = <STDIN>;
        chomp();
        if(length($_)<=0){ $nCenterOverlapRate = 0; }
        elsif(int($_)<0 || int($_)>10){ die("終了（理由：0〜50を入力してください）\n"); }
        else{ $nCenterOverlapRate = int($_); }
        print("CenterOverlap=".$nCenterOverlapRate."%\n");
    }

    # ガンマ値
    print("画像補正のガンマ値入力。1.0の場合は処理OFF (0.0 〜 1.0) [1.0] ： ");
    $_ = <STDIN>;
    chomp();
    if(length($_)<=0){ $nGamma = 1.0; }
    elsif($_<0.0 || $_>1.0){ die("終了（理由：0〜1を入力してください）\n"); }
    else{ $nGamma = $_; }
    print("Gamma=".$nGamma."\n");

    # 黒レベル
    print("強制的に黒とみなすレベル（%） (0 〜 50) [0] ： ");
    $_ = <STDIN>;
    chomp();
    if(length($_)<=0){ $nBlackThreshold = 0; }
    elsif(int($_)<0 || int($_)>50){ die("終了（理由：0〜50を入力してください）\n"); }
    else{ $nBlackThreshold = int($_); }
    $nBlackThreshold .= '%';
    print("BlackThreshold=".$nBlackThreshold."\n");

    # 白レベル
    print("強制的に白とみなすレベル（%） (50 〜 100) [100] ： ");
    $_ = <STDIN>;
    chomp();
    if(length($_)<=0){ $nWhiteThreshold = 100; }
    elsif(int($_)<50 || int($_)>100){ die("終了（理由：50〜100を入力してください）\n"); }
    else{ $nWhiteThreshold = int($_); }
    $nWhiteThreshold .= '%';
    print("WhiteThreshold=".$nWhiteThreshold."\n");

    # アンシャープマスク
    print("アンシャープマスク強さ入力。0はOFF (0, 1〜10) [0] ： ");
    $_ = <STDIN>;
    chomp();
    if(length($_)<=0){ $nUnsharpMaskAmount = 0; }
    elsif(int($_)<0 || int($_)>10){ die("終了（理由：0〜10を入力してください）\n"); }
    else{ $nUnsharpMaskAmount = int($_); }
    print("UnsharpMaskAmount=".$nUnsharpMaskAmount."\n");

    # シャープネス
    print("シャープネス強さ入力。0はOFF (0〜2.0) [0] ： ");
    $_ = <STDIN>;
    chomp();
    if(length($_)<=0){ $nSharpenAmount = 0.0; }
    elsif($_<0 || $_>2.0){ die("終了（理由：0.0〜2.0を入力してください）\n"); }
    else{ $nSharpenAmount = $_ + 0.0; }
    print("SharpenAmount=".$nSharpenAmount."\n");

    # jpegクオリティ
    print("jpeg保存クオリティ（%） (50 〜 100) [85] ： ");
    $_ = <STDIN>;
    chomp();
    if(length($_)<=0){ $nQuality = 85; }
    elsif(int($_)<50 || int($_)>100){ die("終了（理由：50〜100を入力してください）\n"); }
    else{ $nQuality = int($_); }
    print("JpegQuality=".$nQuality."%\n");


}

# 入力・出力が同じディレクトリでないか、確認する
# 戻り値 1:同一ディレクトリ, 0:別のディレクトリ
sub sub_check_same_dir {
    # 出力側ディレクトリに、テンポラリファイルを作成する
    my ($fh, $filename) = File::Temp::tempfile(DIR => sub_conv_to_local_charset($strOutputDir), SUFFIX => '.tmp');
    print($fh "test\n");
    close($fh);
    if(-f sub_conv_to_local_charset($strInputDir) . basename($filename)){
        # 入力側ディレクトリに、テンポラリファイルが見つかったら、同一ディレクトリと判定
        unlink($filename);
        return 1;
    }
    unlink($filename);
    return 0;
}

# 対象画像ファイルを配列に格納して、ソートする
sub sub_scan_imagefiles {
    my $arrScan_ref = shift;    # 引数（対象画像ファイル名の配列）

    # CORE::globに渡すパスは、スペース文字をバックスラッシュでエスケープする
    #my $escape_char = ' ';
    #$strInputDir =~ s/([$escape_char])/'\\' . $1/eg;

    @$arrScan_ref = File::Glob::glob(sub_conv_to_local_charset($strInputDir . $strSearchPattern));
    @$arrScan_ref = sort { uc($a) cmp uc($b) } @$arrScan_ref;       # ソート

}

# 画像を（必要があれば）分割して書き出す
#
# sub_split_image(string ファイル名, int 番号, string 左右)
#
# 例：sub_split_image("image0001.jpg", 50, 'L')
#     → image0001.jpgの左半分を0050.jpgとして保存
#     string左右：L=左半分, R=右半分, N=切り出し無し
#
sub sub_split_image {
    my $input_filename = shift;
    my $seq_no = shift;
    my $lr = shift;
    
    my $output_filename = sprintf("%s%04d.jpg", $strOutputDir, $seq_no);
    
    print($input_filename." -> ".$output_filename."\n");
    if(!(-f sub_conv_to_local_charset($input_filename))){ die("ファイル $input_filename が存在しない\n"); }
    eval{
        if(!(-r sub_conv_to_local_charset($input_filename))){ die("ファイル $input_filename に読み込み属性がない"); }
        my $image = Image::Magick->new();

        # 画像読み込み
        $image->Read($input_filename) and die('ファイル '.$input_filename.' の読み込みに失敗');

        # 元画像サイズ
        my ($width, $height) = Image::Size::imgsize(sub_conv_to_local_charset($input_filename));
        # 画像サイズ読み込み
        if(!defined($width) || !defined($height) || $width <= 0 || $height <= 0){
            die("ファイル $input_filename の縦横ピクセル数が読み取れない");
        }
        # トリム サイズ
        my $width_trim = int( ($lr eq 'N' ? $width:$width/2)*$nTrimRate/100 );
        my $height_trim = int($height*$nTrimRate/100);

        # インデックスカラー、グレーの場合は、フルカラーに戻す（画像調整のため）
        $image->Set(type=>'TrueColor') and die("(imagemagick:set true color) $input_filename");

        # 画像切り抜き（クリップ）の位置、サイズ算出
        my $width_crop;
        my $height_crop;
        my $x_start;
        my $y_start;
        if($lr eq 'L') {
            $width_crop = int($width/2)-$width_trim*2;
            $height_crop = $height-$height_trim*2;
            $x_start = 0+$width_trim;
            $y_start = 0+$height_trim;
        }
        elsif($lr eq 'R') {
            $width_crop = int(int($width/2)-$width_trim*2);
            $height_crop = $height-$height_trim*2;
            $x_start = int($width/2)+$width_trim;
            $y_start = 0+$height_trim;
        }
        else {
            $width_crop = int($width-$width_trim*2);
            $height_crop = $height-$height_trim*2;
            $x_start = 0+$width_trim*2;
            $y_start = 0+$height_trim;
        }

        # ページ中央のオーバーラップがある場合のクリップ座標の調整
        if($nCenterOverlapRate > 0){
            $width_crop += int($width/2*$nCenterOverlapRate/100);
            if($lr eq 'R'){ $x_start -= int($width/2*$nCenterOverlapRate/100); }
        }

        # 画像切り抜き（クリップ）
        if($nTrimRate>0 || $lr ne 'N' || $nCenterOverlapRate > 0) {
            $image->Crop('width'=>$width_crop, 'height'=>$height_crop, 'x'=>$x_start, 'y'=>$y_start) and die("(imagemagick:crop) $input_filename");
        }

        # 黒・白しきい値
        if($nBlackThreshold ne '0%') {
            $image->BlackThreshold(threshold=>$nBlackThreshold) and die("(imagemagick:black threshold) $input_filename");    # 設定値以下は黒になる
        }
        if($nWhiteThreshold ne '100%') {
            $image->WhiteThreshold(threshold=>$nWhiteThreshold) and die("(imagemagick:white threshold) $input_filename");    # 設定値以上は白になる
        }

        # ガンマ補正
        if($nGamma < 1.0) {
            $image->Gamma(gamma=>$nGamma) and die("(imagemagick:gamma) $input_filename");
        }
        
        # アンシャープマスク
        if($nUnsharpMaskAmount != 0){
            # geometry=>'SIGMAxAMOUNTxTHRESHOLD'  例 '0.0x3.0'
            $image->UnsharpMask('0.0x'.int($nUnsharpMaskAmount).'.0') and die("(imagemagick:unsharpmask) $input_filename");
        }

        # シャープネス
        if($nSharpenAmount != 0.0){
            # geometry=>'SIGMAxAMOUNT'  例 '0.0x1.0'
            $image->Sharpen('0.0x'.$nSharpenAmount.'') and die("(imagemagick:sharpen) $input_filename");
        }

        # 画像の保存
        $image->Set(quality=>$nQuality);        # 保存クオリティ（%）
        $image->Write(sub_conv_to_local_charset($output_filename)) and die("ファイル $input_filename に書き込み保存できない");

        # 情報の画面表示
        print(" original=".$width."x".$height.
            ", start:x=".$x_start.",y=".$y_start."(trim=".$width_trim."x".$height_trim."), ".$lr.
            ", cripsize=".$width_crop."x".$height_crop."\n");
    };
    if($@){
        my $str = $@;
        chomp($str);
        print("画像変換エラー : ".$str."\n");
    }
    return;
}


# 任意の文字コードの文字列を、UTF-8フラグ付きのUTF-8に変換する
sub sub_conv_to_flagged_utf8{
    my $str = shift;
    my $enc_force = undef;
    if(@_ >= 1){ $enc_force = shift; }      # デコーダの強制指定

    if(!defined($str) || $str eq ''){ return(''); }     # $strが存在しない場合
    if(Encode::is_utf8($str)){ return($str); }  # 既にflagged utf-8に変換済みの場合
    
    # デコーダが強制的に指定された場合
    if(defined($enc_force)){
        if(ref($enc_force)){
            $str = $enc_force->decode($str);
            return($str);
        }
        elsif($enc_force ne '')
        {
            $str = Encode::decode($enc_force, $str);
        }
    }

    my $enc = Encode::Guess->guess($str);   # 文字列のエンコードの判定

    unless(ref($enc)){
        # エンコード形式が2個以上帰ってきた場合 （shiftjis or utf8）
        my @arr_encodes = split(/ /, $enc);
        if(grep(/^$flag_charcode/, @arr_encodes) >= 1){
            # $flag_charcode と同じエンコードが検出されたら、それを優先する
            $str = Encode::decode($flag_charcode, $str);
        }
        elsif(lc($arr_encodes[0]) eq 'shiftjis' || lc($arr_encodes[0]) eq 'euc-jp' || 
            lc($arr_encodes[0]) eq 'utf8' || lc($arr_encodes[0]) eq 'us-ascii'){
            # 最初の候補でデコードする
            $str = Encode::decode($arr_encodes[0], $str);
        }
    }
    else{
        # UTF-8でUTF-8フラグが立っている時以外は、変換を行う
        unless(ref($enc) eq 'Encode::utf8' && utf8::is_utf8($str) == 1){
            $str = $enc->decode($str);
        }
    }

    return($str);
}

###### ユーザ入出力・画面表示文字コード変換 共通サブルーチン

# 任意の文字コードの文字列を、UTF-8フラグ無しのUTF-8に変換する
sub sub_conv_to_unflagged_utf8{
    my $str = shift;

    # いったん、フラグ付きのUTF-8に変換
    $str = sub_conv_to_flagged_utf8($str);

    return(Encode::encode('utf8', $str));
}


# UTF8から現在のOSの文字コードに変換する
sub sub_conv_to_local_charset{
    my $str = shift;

    # UTF8から、指定された（OSの）文字コードに変換する
    $str = Encode::encode($flag_charcode, $str);
    
    return($str);
}


# 引数で与えられたファイルの エンコードオブジェクト Encode::encode を返す
sub sub_get_encode_of_file{
    my $fname = shift;      # 解析するファイル名

    # ファイルを一気に読み込む
    open(FH, "<".sub_conv_to_local_charset($fname));
    my @arr = <FH>;
    close(FH);
    my $str = join('', @arr);       # 配列を結合して、一つの文字列に

    my $enc = Encode::Guess->guess($str);   # 文字列のエンコードの判定

    # エンコード形式の表示（デバッグ用）
    print("Automatick encode ");
    if(ref($enc) eq 'Encode::utf8'){ print("detect : utf8\n"); }
    elsif(ref($enc) eq 'Encode::Unicode'){
        print("detect : ".$$enc{'Name'}."\n");
    }
    elsif(ref($enc) eq 'Encode::XS'){
        print("detect : ".$enc->mime_name()."\n");
    }
    elsif(ref($enc) eq 'Encode::JP::JIS7'){
        print("detect : ".$$enc{'Name'}."\n");
    }
    else{
        # 二つ以上のエンコードが推定される場合は、$encに文字列が返る
        print("unknown (".$enc.")\n");
    }

    # エンコード形式が2個以上帰ってきた場合 （例：shiftjis or utf8）でテクと失敗と扱う
    unless(ref($enc)){
        $enc = '';
    }

    # ファイルがHTMLの場合 Content-Type から判定する
    if(lc($fname) =~ m/html$/ || lc($fname) =~ m/htm$/){
        my $parser = HTML::HeadParser->new();
        unless($parser->parse($str)){
            my $content_enc = $parser->header('content-type');
            if(defined($content_enc) && $content_enc ne '' && lc($content_enc) =~ m/text\/html/ ){
                if(lc($content_enc) =~ m/utf-8/){ $enc = 'utf8'; }
                elsif(lc($content_enc) =~ m/shift_jis/){ $enc = 'shiftjis'; }
                elsif(lc($content_enc) =~ m/euc-jp/){ $enc = 'euc-jp'; }
                
                print("HTML Content-Type detect : ". $content_enc ." (is overrided)\n");
#               $enc = $content_enc;
            }
        }
    }

    return($enc);
}



# スクリプト終了 EOF

