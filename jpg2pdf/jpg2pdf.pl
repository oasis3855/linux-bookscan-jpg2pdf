#!/usr/bin/perl

# ******************************************************
# Software name :convert jpeg to pdf (複数のjpeg ファイルをpdfに変換)
# jpg2pdf.pl
# version 0.1 (2010/December/07)
#
# Copyright (C) INOUE Hirokazu, All Rights Reserved
#     http://oasis.halfmoon.jp/
#
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

my $flag_os = 'linux';	# linux/windows
my $flag_charcode = 'utf8';		# utf8/shiftjis

use File::Basename;
use PDF::Create;
# use PDF::API2;
use Image::Size;
use Encode::Guess qw/euc-jp shiftjis iso-2022-jp/;
# use Encode::Guess;
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

my $strBaseDir = '';		# （入力jpegファイル）基準ディレクトリ
my $strInputScanPath = './*.jpg';	# 入力ファイルの検索パス
my $strOutputFilename = '';	# 出力 PDF
my $strAuthor = '';
my $strTitle='';
my $strPaperSize = 'A4';

my @arrFiles = ();	# 画像ファイルの配列

print("\n".basename($0)." - 複数のjpeg ファイルをpdfに変換\n\n");

sub_user_input_init();


# ファイルへの書き込みが出来るか検査する
open(FH, ">".sub_conv_to_local_charset($strOutputFilename)) or die($strOutputFilename."に書き込めません\n$!");
close(FH);

sub_make_pdf();

print("PDF作成終了\n");

exit();


# 初期データの入力
sub sub_user_input_init {

	if($#ARGV == 1 && length($ARGV[0])>1 && length($ARGV[1])>1)
	{
		$strBaseDir = sub_conv_to_flagged_utf8($ARGV[0]);
		$strOutputFilename = sub_conv_to_flagged_utf8($ARGV[1]);
	}

	# 対象ディレクトリの入力
	print("入力jpgファイルの格納ディレクトリを、絶対または相対ディレクトリで入力。\n（例：/home/user/, ./）");
	if(length($strBaseDir)>0){ print("[$strBaseDir] :"); }
	else{ print(":"); }
	$_ = <STDIN>;
	chomp();
	$_ = sub_conv_to_flagged_utf8($_);
	if(length($_)<=0){
		if(length($strBaseDir)>0){ $_ = $strBaseDir; }	# スクリプトの引数のデフォルトを使う場合
		else{ die("終了（理由：ディレクトリが入力されませんでした）\n"); }
	}
	if(substr($_,-1) ne '/'){ $_ .= '/'; }	# ディレクトリは / で終わるように修正
	unless(-d sub_conv_to_local_charset($_)){ die("終了（理由：ディレクトリ ".$_." が存在しません）\n"); }
	unless($_ =~ m/^\// || $_ =~ m/^.\//){ $strBaseDir = "./".$_; }
	else{ $strBaseDir = $_; }
	print("対象ディレクトリ : " . $strBaseDir . "\n\n");

	$strInputScanPath = $strBaseDir . '*.jpg';
	print("対象jpeg検索パス : " . $strInputScanPath . "\n\n");

	# 出力pdfファイル名の入力
	print("出力PDFファイルのフルパスを入力。\n（例：/home/user/012.pdf, ./012.pdf）");
	if(length($strOutputFilename)>0){ print("[$strOutputFilename] :"); }
	else{ print(":"); }
	$_ = <STDIN>;
	chomp();
	$_ = sub_conv_to_flagged_utf8($_);
	if(length($_)<=0){
		if(length($strOutputFilename)>0){ $_ = $strOutputFilename; }	# スクリプトの引数のデフォルトを使う場合
		else{ die("終了（理由：ファイル名が入力されませんでした）\n"); }
	}
	if(-d sub_conv_to_local_charset($_)){ die("終了（理由：".$_." はディレクトリです）\n"); }
	unless($_ =~ m/^\// || $_ =~ m/^.\//){ $strOutputFilename = "./".$_; }
	else{ $strOutputFilename = $_; }
	print("出力ファイル : " . $strOutputFilename . "\n\n");


	print("PDF属性の著作者名を入力（無い場合は改行のみ）：");
	$_ = <STDIN>;
	chomp;
	$strAuthor = sub_conv_to_flagged_utf8($_);
	print("Author : " . $strAuthor . "\n\n");
	
	# PDF属性はutf16のため変換
#	if(length($strAuthor)>0){ $strAuthor = Encode::encode('utf16', $strAuthor); }

	print("PDF属性のタイトルを入力（無い場合は改行のみ）：");
	$_ = <STDIN>;
	chomp;
	$strTitle = sub_conv_to_flagged_utf8($_);
	print("Title : " . $strTitle . "\n\n");

	# PDF属性はutf16のため変換
#	if(length($strTitle)>0){ $strTitle = Encode::encode('utf16', $strTitle); }

	# 用紙サイズの入力
	print("用紙サイズ\n 1. A3\n 2. A4\n 3. A5\n 4. A6\n 5. Legal\n 6. Letter\n用紙サイズを選択 (1-6) [2]:");
	$_ = <STDIN>;
	chomp();
	if(length($_)<=0){ $_ = 2; }
	if(int($_)<1 || int($_)>6){ die("終了（入力範囲は 1 〜 6 です）\n"); }
	$_ = int($_);
	if($_ == 1){ $strPaperSize = 'A3'; }
	elsif($_ == 2){ $strPaperSize = 'A4'; }
	elsif($_ == 3){ $strPaperSize = 'A5'; }
	elsif($_ == 4){ $strPaperSize = 'A6'; }
	elsif($_ == 5){ $strPaperSize = 'legal'; }
	elsif($_ == 6){ $strPaperSize = 'letter'; }
	print("用紙サイズ : " . $strPaperSize . "\n\n");

}


# jpeg から pdf を作成する
sub sub_make_pdf{

	# 入力ファイルを検索して、配列に格納する。
	@arrFiles = glob(sub_conv_to_local_charset($strInputScanPath));
	@arrFiles = sort(@arrFiles);
	if($#arrFiles < 0){ die("対象ファイルが見つからない\n"); }
	printf("対象ファイル数：%d個\n", $#arrFiles+1);

	print("PDF作成を開始します。リターンキーを押してください : ");
	<STDIN>;

	# initialize PDF  （日本語のメタデータは、この状態ではエラーとなる）
	my $pdf = new PDF::Create('filename'     => $strOutputFilename,
				'Author'       => ($strAuthor ne '' ? Encode::encode('utf16', $strAuthor) : ''),
				'Title'        => ($strTitle ne '' ? Encode::encode('utf16', $strTitle) : ''),
				'CreationDate' => [ localtime ], );

	# 用紙をポートレート（縦＞横）で置いた場合のPDFサイズ
	my $width_paper = $pdf->get_page_size($strPaperSize)->[2];	# 用紙 横サイズ
	my $height_paper = $pdf->get_page_size($strPaperSize)->[3];	# 用紙 縦サイズ

	foreach(@arrFiles){

		my $strImageFile = sub_conv_to_flagged_utf8($_);
		my ($width, $height) = imgsize(sub_conv_to_local_charset($strImageFile));
		if($width<=0 || $height<=0){print("$strImageFile error\n"); next; }
		print($strImageFile."\n");

		# ページ幅を用紙サイズに合わせるための比率
		my $nRatio;
		my $x;		#PDF出力横
		my $y;		#PDF出力縦
		if($width < $height){
			# 用紙縦置き
			if($height_paper/$width_paper < $height/$width){
				# 基準より縦長 → 縦が「用紙サイズ縦」に収まるように比率決定
				$nRatio = $height_paper / $height;
			}
			else{
				# 基準より横長 → 横が「用紙サイズ横」に収まるように比率決定
				$nRatio = $width_paper / $width;
			}
			$x = int($width*$nRatio);
			$y = int($height*$nRatio);
		}
		else{
			# 用紙横置き
			if($height_paper/$width_paper < $width/$height){
				# 基準より横長 → 横が「用紙サイズ縦」に収まるように比率決定
				$nRatio = $height_paper / $width;
			}
			else{
				# 基準より縦長 → 縦が「用紙サイズ横」に収まるように比率決定
				$nRatio = $width_paper / $height;
			}
			$x = int($width*$nRatio);
			$y = int($height*$nRatio);
		}

		# 新しいページを追加
		my $container = $pdf->new_page('MediaBox' => [0, 0, $x, $y]);
	
		my $page = $container->new_page();

		# 画像を読み込んで貼りつけ
		my $image = $pdf->image(sub_conv_to_local_charset($strImageFile));
		$page->image('image' => $image, 'xpos' => 0, 'ypos' => 0, 'xscale' => $nRatio, 'yscale' => $nRatio);
	}

	# Close the file and write the PDF
	$pdf->close;

	# 日本語メタデータの書き込み試行 → いまのところエラー
#	my $pdf2 = PDF::API2->open(sub_conv_to_local_charset($strOutputFilename));
#	$pdf2->info(
#		'Author'       => ($strAuthor ne '' ? Encode::encode('utf16', $strAuthor) : '') ,
#		'Title'       => ($strTitle ne '' ? Encode::encode('utf16', $strTitle) : '')
#		);
#	$pdf2->update;
	


}


# 任意の文字コードの文字列を、UTF-8フラグ付きのUTF-8に変換する
sub sub_conv_to_flagged_utf8{
	my $str = shift;
	my $enc_force = undef;
	if(@_ >= 1){ $enc_force = shift; }		# デコーダの強制指定
	
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

	my $enc = Encode::Guess->guess($str);	# 文字列のエンコードの判定

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

