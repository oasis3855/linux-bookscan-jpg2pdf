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

use File::Basename;
use PDF::Create;
use Image::Size;
#use Encode::Guess qw/euc-jp shiftjis iso-2022-jp/;	# 必要な場合
use Encode::Guess;
#use Data::Dumper;

binmode(STDOUT, "utf8");


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
open(FH, ">$strOutputFilename") or die($strOutputFilename."に書き込めません\n$!");
close(FH);

sub_make_pdf();

print("PDF作成終了\n");

exit();


# 初期データの入力
sub sub_user_input_init {

	if($#ARGV == 1 && length($ARGV[0])>1 && length($ARGV[1])>1)
	{
		$strBaseDir = $ARGV[0];
		$strOutputFilename = $ARGV[1];
	}

	# 対象ディレクトリの入力
	print("入力jpgファイルの格納ディレクトリを、絶対または相対ディレクトリで入力。\n（例：/home/user/, ./）");
	if(length($strBaseDir)>0){ print("[$strBaseDir] :"); }
	else{ print(":"); }
	$_ = <STDIN>;
	chomp();
	if(length($_)<=0){
		if(length($strBaseDir)>0){ $_ = $strBaseDir; }	# スクリプトの引数のデフォルトを使う場合
		else{ die("終了（理由：ディレクトリが入力されませんでした）\n"); }
	}
	if(substr($_,-1) ne '/'){ $_ .= '/'; }	# ディレクトリは / で終わるように修正
	unless(-d $_){ die("終了（理由：ディレクトリ ".$_." が存在しません）\n"); }
	unless($_ =~ m/^\// || $_ =~ m/^.\//){ $strBaseDir = "./".$_; }
	else{ $strBaseDir = $_; }
	{
	my $enc = Encode::Guess->guess($strBaseDir); # エンコード形式の判定
	$strBaseDir = $enc->decode($strBaseDir); # input encode → utf8
	}
	print("対象ディレクトリ : " . $strBaseDir . "\n\n");

	$strInputScanPath = $strBaseDir . '*.jpg';
	print("対象jpeg検索パス : " . $strInputScanPath . "\n\n");

	# 出力pdfファイル名の入力
	print("出力PDFファイルのフルパスを入力。\n（例：/home/user/012.pdf, ./012.pdf）");
	if(length($strOutputFilename)>0){ print("[$strOutputFilename] :"); }
	else{ print(":"); }
	$_ = <STDIN>;
	chomp();
	if(length($_)<=0){
		if(length($strOutputFilename)>0){ $_ = $strOutputFilename; }	# スクリプトの引数のデフォルトを使う場合
		else{ die("終了（理由：ファイル名が入力されませんでした）\n"); }
	}
	if(-d $_){ die("終了（理由：".$_." はディレクトリです）\n"); }
	unless($_ =~ m/^\// || $_ =~ m/^.\//){ $strOutputFilename = "./".$_; }
	else{ $strOutputFilename = $_; }
	{
	my $enc = Encode::Guess->guess($strOutputFilename); # エンコード形式の判定
	$strOutputFilename = $enc->decode($strOutputFilename); # input encode → utf8
	}
	print("出力ファイル : " . $strOutputFilename . "\n\n");


	print("PDF属性の著作者名を入力（無い場合は改行のみ）：");
	$_ = <STDIN>;
	chomp;
	$strAuthor = $_;
	if(length($strAuthor)>0){
	{
	my $enc = Encode::Guess->guess($strAuthor); # エンコード形式の判定
	$strAuthor = $enc->decode($strAuthor); # input encode → utf8
	}
	}
	print("Author : " . $strAuthor . "\n\n");
	
	# PDF属性はutf16のため変換
	if(length($strAuthor)>0){ $strAuthor = Encode::encode('utf16', $strAuthor); }

	print("PDF属性のタイトルを入力（無い場合は改行のみ）：");
	$_ = <STDIN>;
	chomp;
	$strTitle = $_;
	if(length($strTitle)>0){
	{
	my $enc = Encode::Guess->guess($strTitle); # エンコード形式の判定
	$strTitle = $enc->decode($strTitle); # input encode → utf8
	}
	}
	print("Title : " . $strTitle . "\n\n");

	# PDF属性はutf16のため変換
	if(length($strTitle)>0){ $strTitle = Encode::encode('utf16', $strTitle); }

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
	@arrFiles = glob($strInputScanPath);
	@arrFiles = sort(@arrFiles);
	if($#arrFiles < 0){ die("対象ファイルが見つからない\n"); }
	printf("対象ファイル数：%d個\n", $#arrFiles+1);

	print("PDF作成を開始します。リターンキーを押してください : ");
	<STDIN>;

	# initialize PDF
	my $pdf = new PDF::Create('filename'     => $strOutputFilename,
				'Author'       => $strAuthor,
				'Title'        => $strTitle,
				'CreationDate' => [ localtime ], );

	# 用紙をポートレート（縦＞横）で置いた場合のPDFサイズ
	my $width_paper = $pdf->get_page_size($strPaperSize)->[2];	# 用紙 横サイズ
	my $height_paper = $pdf->get_page_size($strPaperSize)->[3];	# 用紙 縦サイズ

	foreach(@arrFiles){

		my $strImageFIle = $_;
		my ($width, $height) = imgsize($strImageFIle);
		if($width<=0 || $height<=0){print("$strImageFIle error\n"); next; }
		print($strImageFIle."\n");

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
		my $image = $pdf->image($strImageFIle);
		$page->image('image' => $image, 'xpos' => 0, 'ypos' => 0, 'xscale' => $nRatio, 'yscale' => $nRatio);
	}

	# Close the file and write the PDF
	$pdf->close;

}

