#!/usr/bin/perl

# save this file in UTF-8 (linux) or Shift-JIS (Windows ActivePerl)
# ******************************************************
# Software name : Divide and Contrast adjust of Image files 
#          （書籍イメージ化用ツール：jpegファイルを左右分割、コントラスト調整）
#
# Copyright (C) INOUE Hirokazu, All Rights Reserved
#     http://oasis.halfmoon.jp/
#
# div-contrast-img.pl
# version 0.1 (2010/December/06)
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

use Image::Magick;
use Image::ExifTool;
use Image::Size;
use File::Basename;

#use Data::Dumper;

my $strInputDir = './';			# 入力ファイルのあるディレクトリ
my $strOutputDir = './';		# 出力ディレクトリ
my $strSearchPattern = '*.jpg';	# 対象ファイル（検索文字列）
my $nTrimRate = 0;				# 周囲を切り取る率（0〜50）％
my $flag_LR = 'LR';				# ページ順 LR または RL

my $nGamma = 0.4;				# 画像補正値：ガンマ
my $nBlackThreshold = 20;		# 画像補正値：黒レベル強制（％）
my $nWhiteThreshold = 80;		# 画像補正値：白レベル強制（％）
my $nQuality = 85;				# jpeg保存クオリティ


my @arrScan = undef;	# ファイル一覧を一時的に格納する配列

print("指定されたフォルダの全ファイルを左右二分割、コントラスト調整します\n");

sub_user_input_init();

sub_scan_imagefiles();

if($#arrScan < 0){die("処理対象ファイルが見つかりません\n"); }
printf("処理対象ファイル数：%d\n", $#arrScan+1);

if($flag_LR eq 'RL'){
	my $i = 1;
	foreach(@arrScan) {
		sub_split_image($_, $i, 'R');
		$i++;
		sub_split_image($_, $i, 'L');
		$i++;
	}
}
elsif($flag_LR eq 'LR'){
	my $i = 1;
	foreach(@arrScan) {
		sub_split_image($_, $i, 'L');
		$i++;
		sub_split_image($_, $i, 'R');
		$i++;
	}
}
else{
	my $i = 1;
	foreach(@arrScan) {
		sub_split_image($_, $i, 'N');
		$i++;
	}
}

exit();

# 対象ディレクトリ、処理形式などのユーザ入力（コンソール版）
sub sub_user_input_init {

	# 入力ディレクトリの入力
	print("入力ファイルのあるディレクトリを、絶対または相対ディレクトリで入力。\n（例：/home/user/, ./）： ");
	$_ = <STDIN>;
	chomp();
	if(length($_)<=0){ die("終了（理由：ディレクトリが入力されませんでした）\n"); }
	if(substr($_,-1) ne '/'){ $_ .= '/'; }	# ディレクトリは / で終わるように修正
	unless(-d $_){ die("終了（理由：ディレクトリ ".$_." が存在しません）\n"); }
	$strInputDir = $_;
	print("入力ディレクトリ : " . $strInputDir . "\n");

	# 出力ディレクトリの入力
	print("出力ディレクトリを、絶対または相対ディレクトリで入力。\n（例：/home/user/, ./）： ");
	$_ = <STDIN>;
	chomp();
	if(length($_)<=0){ die("終了（理由：ディレクトリが入力されませんでした）\n"); }
	if(substr($_,-1) ne '/'){ $_ .= '/'; }	# ディレクトリは / で終わるように修正
	unless(-d $_){ die("終了（理由：ディレクトリ ".$_." が存在しません）\n"); }
	$strOutputDir = $_;
	print("出力ディレクトリ : " . $strOutputDir . "\n");

	# ページ順の入力
	print("ページ順（右左=RL、左右=LR）または左右分割無し（N）を入力 [LR/RL/N] ： ");
	$_ = <STDIN>;
	chomp();
	if(length($_)<=0){ die("終了（理由：何も入力されませんでした）\n"); }
	if(uc($_) eq 'LR'){ $flag_LR = 'LR'; }
	elsif(uc($_) eq 'RL'){ $flag_LR = 'RL'; }
	elsif(uc($_) eq 'N'){ $flag_LR = 'N'; }
	else{ die("終了（理由：LR, RL以外が入力されました）\n"); }

	# トリム
	print("周囲を切り取る率(%)を入力 (0 〜 50) [0]： ");
	$_ = <STDIN>;
	chomp();
	if(length($_)<=0){ $nTrimRate = 0; }
	elsif(int($_)<0 || int($_)>50){ die("終了（理由：0〜50を入力してください）\n"); }
	else{ $nTrimRate = int($_); }
	print("Trim=".$nTrimRate."(%)\n");

	# ガンマ値
	print("画像補正のガンマ値入力 (0.0 〜 1.0) [0.4] ： ");
	$_ = <STDIN>;
	chomp();
	if(length($_)<=0){ $nGamma = 0.4; }
	elsif($_<0.0 || $_>1.0){ die("終了（理由：0〜1を入力してください）\n"); }
	else{ $nGamma = $_; }
	print("Gamma=".$nGamma."\n");

	# 黒レベル
	print("強制的に黒とみなすレベル（%） (0 〜 50) [20] ： ");
	$_ = <STDIN>;
	chomp();
	if(length($_)<=0){ $nBlackThreshold = 20; }
	elsif(int($_)<0 || int($_)>50){ die("終了（理由：0〜50を入力してください）\n"); }
	else{ $nBlackThreshold = int($_); }
	$nBlackThreshold .= '%';
	print("BlackThreshold=".$nBlackThreshold."\n");

	# 白レベル
	print("強制的に白とみなすレベル（%） (50 〜 100) [80] ： ");
	$_ = <STDIN>;
	chomp();
	if(length($_)<=0){ $nWhiteThreshold = 80; }
	elsif(int($_)<50 || int($_)>100){ die("終了（理由：50〜100を入力してください）\n"); }
	else{ $nWhiteThreshold = int($_); }
	$nWhiteThreshold .= '%';
	print("WhiteThreshold=".$nWhiteThreshold."\n");

	# jpegクオリティ
	print("jpeg保存クオリティ（%） (50 〜 100) [85] ： ");
	$_ = <STDIN>;
	chomp();
	if(length($_)<=0){ $nQuality = 85; }
	elsif(int($_)<50 || int($_)>100){ die("終了（理由：50〜100を入力してください）\n"); }
	else{ $nQuality = int($_); }
	print("JpegQuality=".$nQuality."\n");


}

# 対象画像ファイルを配列に格納して、ソートする
sub sub_scan_imagefiles {

	@arrScan = glob($strInputDir . $strSearchPattern);
	@arrScan = sort { uc($a) cmp uc($b) } @arrScan;		# ソート

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
	
	my $image = Image::Magick->new();
	my $image_check = undef;

	# 画像読み込み
	$image_check = $image->Read($input_filename);

	if($image_check){ die("$@"); }

	# 画像サイズの画面表示
	my ($width, $height) = imgsize($input_filename);	# 画像サイズ読み込み
	my $width_trim = int($width/2*$nTrimRate/100);
	my $height_trim = int($height*$nTrimRate/100);

	print("fullsize=".($flag_LR eq 'N' ? $width : int($width/2)).",".$height.", trim=".$width_trim.",".$height_trim."\n");

	# インデックスカラー、グレーの場合は、フルカラーに戻す（画像調整のため）
	$image->Set(type=>'TrueColor');

	# 画像切り抜き（クリップ）
	if($nTrimRate>0)
	{
		if($lr eq 'L') {
			$image->Crop('width'=>(int($width/2)-$width_trim*2), 'height'=>($height-$height_trim*2), 'x'=>(0+$width_trim), 'y'=>(0+$height_trim));
		}
		elsif($lr eq 'R') {
			$image->Crop('width'=>int(int($width/2)-$width_trim*2), 'height'=>($height-$height_trim*2), 'x'=>(int($width/2)+$width_trim), 'y'=>(0+$height_trim));
		}
		else {
			$image->Crop('width'=>int($width-$width_trim*4), 'height'=>($height-$height_trim*2), 'x'=>(0+$width_trim*2), 'y'=>(0+$height_trim));
		}
	}

	# 黒・白しきい値
	$image->BlackThreshold(threshold=>$nBlackThreshold);	# 設定値以下は黒になる
	$image->WhiteThreshold(threshold=>$nWhiteThreshold);	# 設定値以上は白になる
	# ガンマ補正
	$image->Gamma(gamma=>$nGamma);

	# 画像の保存
	$image->Set(quality=>$nQuality);		# 保存クオリティ（%）
	$image->Write($output_filename);


}

# スクリプト終了 EOF

