#!/usr/bin/perl

# GNU GPL Free Software. (C) 2010 INOUE Hirokazu
# PDFファイルの用紙サイズをA4に合わせるスクリプト

use strict;
use warnings;
use PDF::API2;
use PDF::API2::Page;
use File::Basename;

my $pdf_input_fname;
my $pdf_output_fname;
my $num_pages;
my $str_paper_alias = 'A4';
my ( $num_size_x, $num_size_y ) = ( 210.0, 297.0 );    # 経過表示でサイズを示すために使う$str_paper_aliasの縦横サイズ

if ( $#ARGV != 1 ) {
    die(    basename($0)
          . " - resize pdf paper size to '"
          . $str_paper_alias
          . "'\nusage : "
          . basename($0)
          . " [input pdf] [output pdf]\n" );
}
$pdf_input_fname  = $ARGV[0];
$pdf_output_fname = $ARGV[1];

if ( !-f $pdf_input_fname ) { die("Error : input pdf file not found\n"); }
if ( -d $pdf_output_fname ) { die("Error : output pdf file name is directory\n"); }

# 入力PDFファイルを開き、ページ数を取得
my $pdf_from = PDF::API2->open($pdf_input_fname);
$num_pages = $pdf_from->pages();
if ( $num_pages < 1 ) { die("Error : input pdf have no page\n"); }
print "input pdf pages = " . $num_pages . "\n";

# 出力PDFファイルのオブジェクトを作成し、用紙サイズを指定する
my $pdf_to = PDF::API2->new();
$pdf_to->mediabox($str_paper_alias);

for ( my $i = 1 ; $i <= $num_pages ; $i++ ) {

    # 入力PDFの各ページの「サイズ」を取得する
    my $page_dummy = $pdf_from->openpage($i);
    my ( $llx_in, $lly_in, $urx_in, $ury_in ) = $page_dummy->get_mediabox();

    # 出力PDFオブジェクトに、新しいページを1ページ追加し、「サイズ」を取得する
    my $page = $pdf_to->page();
    my ( $llx, $lly, $urx, $ury ) = $page->get_mediabox();

    # リサイズ率を計算する
    my $num_resize;
    if   ( $urx / $urx_in * $ury_in < $ury ) { $num_resize = $urx / $urx_in; }
    else                                     { $num_resize = $ury / $ury_in; }

    printf( "page %3d (%4dx%4d) resize %3d%%\n", $i, int( $num_size_x * $urx_in / $urx ),
        int( $num_size_y * $ury_in / $ury ), int( $num_resize * 100 ) );

    # 入力PDFをを読み込んで、リサイズして、出力PDFのページにコピーする
    my $gfx = $page->gfx();
    my $xo  = $pdf_to->importPageIntoForm( $pdf_from, $i );
    $gfx->formimage( $xo, 0, 0, $num_resize );
}

$pdf_to->saveas($pdf_output_fname);
