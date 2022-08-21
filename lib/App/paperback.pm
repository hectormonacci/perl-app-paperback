package App::paperback;

use v5.10;
use strict;
# use warnings;
our $VERSION = 0.39;

use Exporter;
our @ISA    = qw(Exporter);
our @EXPORT = qw(openInputFile openOutputFile newPageInOutputFile
	copyPageFromInputToOutput closeInputFile closeOutputFile);

my ($GformNr, $GinFile, $GpageObjNr, $Groot, $Gpos, $GobjNr, $Gstream, $GoWid, $GoHei);
my (@Gkids, @Gcounts, @GformBox, @Gobject, @Gparents, @Gto_be_created);
my (%Gold, %Gresources, %GpageXObject, %GoldObject);

# ISO 216 paper sizes in pt:
my $AH = 841.8898; # [A] A4 ~ 297 mm (H)
my $AW = 595.2756; # [A] A4 ~ 210 mm (W)
my $BH = $AW;      # [B] A5 ~ 210 mm (H)
my $BW = 419.5276; # [B] A5 ~ 148 mm (W)
my $CH = $BW;      # [C] A6 ~ 148 mm (H)
my $CW = 297.6378; # [C] A6 ~ 105 mm (W)
# + 1 mm (2.8346 pt) to account for rounding in ISO 216 (148+148=296):
my $CG = 422.3622; # [C] A6 $CH + 1 mm (H)
my $BG = $CG;      # [B] A5 $BW + 1 mm (W)

# US paper sizes in pt:
my $DH =  792; # [D] US Letter Full (H)
my $DW =  612; # [D] US Letter Full (W)
my $EH =  $DW; # [E] US Letter Half (H)
my $EW =  396; # [E] US Letter Half (W)
my $FH =  $EW; # [F] US Letter Quarter (H)
my $FW =  306; # [F] US Letter Quarter (W)
my $GH = 1008; # [G] US Legal Full (H)
my $GW =  $DW; # [G] US Legal Full (W)
my $HH =  $DW; # [H] US Legal Half (H)
my $HW =  504; # [H] US Legal Half (W)
my $IH =  $HW; # [I] US Legal Quarter (H)
my $IW =  $FW; # [I] US Legal Quarter (W)

# Page reordering and position offset schemas for "4 up":
my @P_4_UP = (16,1,13,4,2,15,3,14,12,5,9,8,6,11,7,10);
my @X_A6_ON_A4 = (0,$CW,$CW,$AW,0,$CW,$CW,$AW,0,$CW,$CW,$AW,0,$CW,$CW,$AW);
my @Y_A6_ON_A4 = ($CG,$CG,$CH,$CH,$CG,$CG,$CH,$CH,$CG,$CG,$CH,$CH,$CG,$CG,$CH,$CH);
my @X_QT_ON_LT = (0,$FW,$FW,$DW,0,$FW,$FW,$DW,0,$FW,$FW,$DW,0,$FW,$FW,$DW);
my @Y_QT_ON_LT = ($FH,$FH,$FH,$FH,$FH,$FH,$FH,$FH,$FH,$FH,$FH,$FH,$FH,$FH,$FH,$FH);
my @X_QG_ON_LG = (0,$IW,$IW,$GW,0,$IW,$IW,$GW,0,$IW,$IW,$GW,0,$IW,$IW,$GW);
my @Y_QG_ON_LG = ($IH,$IH,$IH,$IH,$IH,$IH,$IH,$IH,$IH,$IH,$IH,$IH,$IH,$IH,$IH,$IH);

# Page reordering and position offset schemas for "2 up":
my @P_2_UP = (16,1,15,2,14,3,13,4,12,5,11,6,10,7,9,8);
my @Y_A5_ON_A4 = ($BG,0,$AH,$BG,$BG,0,$AH,$BG,$BG,0,$AH,$BG,$BG,0,$AH,$BG);
my @X_A5_ON_A4 = ($BH,$BH,0,0,$BH,$BH,0,0,$BH,$BH,0,0,$BH,$BH,0,0);
my @Y_HT_ON_LT = ($EW,0,$DH,$EW,$EW,0,$DH,$EW,$EW,0,$DH,$EW,$EW,0,$DH,$EW);
my @X_HT_ON_LT = ($EH,$EH,0,0,$EH,$EH,0,0,$EH,$EH,0,0,$EH,$EH,0,0);
my @Y_HG_ON_LG = ($HW,0,$GH,$HW,$HW,0,$GH,$HW,$HW,0,$GH,$HW,$HW,0,$GH,$HW);
my @X_HG_ON_LG = ($HH,$HH,0,0,$HH,$HH,0,0,$HH,$HH,0,0,$HH,$HH,0,0);

my ( $IN_FILE, $OUT_FILE );


##########################################################
sub main {
##########################################################
  my $input = $ARGV[0];
  my $num_pag_input; my $pgSizeInput;
  my $numPagImposed = 0;
  my $sayUsage = "Usage: paperback file.pdf (will produce 'file-paperback.pdf').";
  my $sayVersion = "This is paperback v${VERSION}, (c) 2022 Hector M. Monacci.";
  my $sayHelp = <<"END_MESSAGE";

${sayUsage}

  All pages in the input PDF file will be imposed on a new PDF with
  bigger paper size, ready to be duplex-printed, folded and put together
  into signatures, according to its original page size. Input PDF is 
  always assumed to be composed of vertical pages of the same size.

  Input page sizes allowed are A5, A6, Half Letter, Quarter Letter,
  Half Legal and Quarter Legal. Other sizes give an error message.

  Only PDF v1.4 is supported as input, although many higher-labeled
  PDF files are correctly handled since they are essentially v1.4 PDF
  files stamped as something more modern.

ISO 216 normalised (international) page sizes:

  Input page sizes A6 (105 x 148 mm) and A5 (148 x 210 mm) produce
  an output page size of A4 (210 x 297 mm). Four A6 pages will be put
  on each A4 page, or two A5 pages will be put on each A4 page. 
  Before that, input pages will be reordered and reoriented so as to
  produce a final PDF fit for duplex 'long-edge-flip' printing.

ANSI normalised (US) page sizes:

  Input page sizes Quarter Letter (4.25 x 5.5 in) and Half Letter (5.5
  x 8,5 in) produce a Letter output page size (8.5 x 11 in). Input
  page sizes Quarter Legal (4.25 x 7 in) and Half Legal (7 x 8,5 in)
  produce a Legal output page size (8.5 x 14 in). Four Quarter-Letter
  pages will be put on each Letter page, two Half-Letter pages will be
  put on each Letter page, four Quarter-Legal pages will be put on each
  Legal page, or two Half-Legal pages will be put on each Legal page.
  Before that, input pages will be reordered and reoriented so as to 
  produce a final PDF fit for duplex 'long-edge-flip' printing.

${sayVersion}
END_MESSAGE

  die "[!] $sayUsage\n"
    if ! defined $input;
  do {print STDERR "$sayHelp" and exit}
    if $input =~ "^-h\$" or $input =~ "^--help\$";
  do {print STDERR "${sayVersion}\n" and exit}
    if $input =~ "^-v\$" or $input =~ "^--version\$";
  die "[!] File '$input' can't be found or read.\n"
    unless -r $input;
  ($num_pag_input, $pgSizeInput) = openInputFile($input);
  die "[!] File '$input' is not a valid v1.4 PDF file.\n"
    if $num_pag_input == 0;

  my ($rot_extra, $pagesPerSheet, @x, @y, @p);
  for ($pgSizeInput) {
       if ($_ eq "A6") { $pagesPerSheet = 4; @x = @X_A6_ON_A4; @y = @Y_A6_ON_A4; }
    elsif ($_ eq "A5") { $pagesPerSheet = 2; @x = @X_A5_ON_A4; @y = @Y_A5_ON_A4; }
    elsif ($_ eq "QT") { $pagesPerSheet = 4; @x = @X_QT_ON_LT; @y = @Y_QT_ON_LT; }
    elsif ($_ eq "QG") { $pagesPerSheet = 4; @x = @X_QG_ON_LG; @y = @Y_QG_ON_LG; }
    elsif ($_ eq "HT") { $pagesPerSheet = 2; @x = @X_HT_ON_LT; @y = @Y_HT_ON_LT; }
    elsif ($_ eq "HG") { $pagesPerSheet = 2; @x = @X_HG_ON_LG; @y = @Y_HG_ON_LG; }
    else {die "[!] Bad page size ($pgSizeInput). See 'paperback -h' to learn more.\n"}
  }

  my $rotation;
  my $target_page;
  my ($name) = $input =~ /(.+)\.[^.]+$/;
  my $num_pliegos;

  openOutputFile("${name}-paperback.pdf");
  $num_pliegos = $num_pag_input >> 4;
  ($rot_extra, @p) = $pagesPerSheet == 4 ? (0, @P_4_UP) : (90, @P_2_UP);
  for (0..$num_pliegos) {
    for (0..15) {
      newPageInOutputFile() unless $_ % $pagesPerSheet > 0 or $numPagImposed == 0;
      $target_page = $p[$_] + ($numPagImposed >> 4) * 16;
      next if $target_page > $num_pag_input;

      $rotation = $_ % 4 > 1 ? $rot_extra + 180 : $rot_extra;
      copyPageFromInputToOutput ({page => $target_page,
        rotate => $rotation, x => $x[$_], y => $y[$_]});
      ++$numPagImposed;
      last if $numPagImposed == $num_pag_input;
    }
  }
  closeInputFile();
  closeOutputFile();
}

main() if not caller();


##########################################################
sub newPageInOutputFile {
##########################################################
  die "[!] No output file, you have to call openOutputFile first" if !$Gpos;
  writePage() if defined $Gstream and length($Gstream) > 0;

  ++$GobjNr;
  $GpageObjNr = $GobjNr;
  undef %GpageXObject;

  return;
}


##########################################################
sub copyPageFromInputToOutput {
##########################################################
  die "[!] No output file, you have to call openOutputFile first" if !$Gpos;
  my $param      = $_[0];
  my $pagenumber = $param->{'page'}   or 1;
  my $x          = $param->{'x'}      or 0;
  my $y          = $param->{'y'}      or 0;
  my $rotate     = $param->{'rotate'} or 0;

  my $fSource = "${GinFile}_${pagenumber}";
  ++$GformNr;
  my $name = "Fm${GformNr}";
  my $refNr = getPage( $pagenumber );
  die "[!] ${fSource} can't be used. Concatenate streams!" if !defined $refNr;
  die "[!] Page ${pagenumber} doesn't exist in file ${GinFile}" if !$refNr;

  if ( defined $x and defined $y and defined $rotate ) {
    $Gstream .= "q\n" . calcMatrix($x, $y, $rotate) ."\n/Gs0 gs\n/${name} Do\nQ\n";
  } else {
    $Gstream .= "\n/Gs0 gs\n/${name} Do\n";
  }
  $GpageXObject{$name} = $refNr;

  return;
}


##########################################################
sub setInitGrState {
##########################################################
  ++$GobjNr;

  $Gobject[$GobjNr] = $Gpos;
  my $out_line = "${GobjNr} 0 obj<</Type/ExtGState/SA false/SM 0.02/TR2 /Default"
    . ">>endobj\n";
  $Gpos += syswrite $OUT_FILE, $out_line;
  return;
}


##########################################################
sub createPageResourceDict {
##########################################################
  my $resourceDict = "/ProcSet[/PDF/Text]";
  if ( %GpageXObject ) {
    $resourceDict .= "/XObject<<";
    $resourceDict .= "/$_ $GpageXObject{$_} 0 R" for sort keys %GpageXObject;
    $resourceDict .= ">>";
  }
  $resourceDict .= "/ExtGState<<\/Gs0 4 0 R>>";
  return $resourceDict;
}


##########################################################
sub writePageResourceDict {
##########################################################
  my $resourceDict = $_[0];
  my $resourceObject;
  if ( exists $Gresources{$resourceDict} ) {
    $resourceObject = $Gresources{$resourceDict};  # Found one identical, use it
  } else {
    ++$GobjNr;
    if ( keys(%Gresources) < 10 ) {
      $Gresources{$resourceDict} = $GobjNr;  # Save first 10 resources
    }
    $resourceObject = $GobjNr;
    $Gobject[$GobjNr] = $Gpos;
    $resourceDict   = "${GobjNr} 0 obj<<${resourceDict}>>endobj\n";
    $Gpos += syswrite $OUT_FILE, $resourceDict;
  }
  return $resourceObject;
}


##########################################################
sub writePageStream {
##########################################################
  ++$GobjNr;
  $Gobject[$GobjNr] = $Gpos;
  $Gpos += syswrite $OUT_FILE, "${GobjNr} 0 obj<</Length " . length($Gstream)
    . ">>stream\n${Gstream}\nendstream\nendobj\n";
  $Gobject[$GpageObjNr] = $Gpos;
  $Gstream = "";
  return;
}


##########################################################
sub writePageResources {
##########################################################
  my $parent = $_[0]; my $resourceObject = $_[1];
  $Gpos += syswrite $OUT_FILE, "${GpageObjNr} 0 obj<</Type/Page/Parent ${parent} 0 "
    . "R/Contents ${GobjNr} 0 R/Resources ${resourceObject} 0 R>>endobj\n";
  push @{ $Gkids[0] }, $GpageObjNr;
  return;
}


##########################################################
sub writePage {
##########################################################
  if ( !$Gparents[0] ) {
    ++$GobjNr;
    $Gparents[0] = $GobjNr;
  }
  my $parent = $Gparents[0];
  my $resourceObject = writePageResourceDict(createPageResourceDict());
  writePageStream();
  writePageResources($parent, $resourceObject);
  ++$Gcounts[0];
  writePageNodes(8) if $Gcounts[0] > 9;
  return;
}


##########################################################
sub closeOutputFile {
##########################################################
  return if !$Gpos;

  writePage() if $Gstream;
  my $endNode = writeEndNode();

  my $out_line = "1 0 obj<</Type/Catalog/Pages ${endNode} 0 R>>endobj\n";
  $Gobject[1] = $Gpos;
  $Gpos += syswrite $OUT_FILE, $out_line;
  my $qty = $#Gobject;
  my $startxref = $Gpos;
  my $xrefQty = $qty + 1;
  $out_line = "xref\n0 ${xrefQty}\n0000000000 65535 f \n";
  $out_line .= sprintf "%.10d 00000 n \n", $_ for @Gobject[1..$qty];
  $out_line .= "trailer\n<<\n/Size ${xrefQty}\n/Root 1 0 R\n"
    . ">>\nstartxref\n${startxref}\n%%EOF\n";

  syswrite $OUT_FILE, $out_line;
  close $OUT_FILE;

  $Gpos = 0;
  return;
}


##########################################################
sub writePageNodes {
##########################################################
  my $qtyChildren = $_[0];
  my $i     = 0;
  my $j     = 1;
  my $nodeObj;

  while ( $qtyChildren < $#{ $Gkids[$i] } ) {
    # Imprimir padre actual y pasar al siguiente nivel:
    if ( !$Gparents[$j] ) {
      ++$GobjNr;
      $Gparents[$j] = $GobjNr;
    }

    $nodeObj =
      "${Gparents[$i]} 0 obj<</Type/Pages/Parent ${Gparents[$j]} 0 R\n/Kids [";
    $nodeObj .= "${_} 0 R " for @{ $Gkids[$i] };
    $nodeObj .= "]\n/Count ${Gcounts[$i]}>>endobj\n";
    $Gobject[ $Gparents[$i] ] = $Gpos;
    $Gpos += syswrite $OUT_FILE, $nodeObj;

    $Gcounts[$j] += $Gcounts[$i];
    $Gcounts[$i] = 0;
    $Gkids[$i]   = [];
    push @{ $Gkids[$j] }, $Gparents[$i];
    undef $Gparents[$i];
    ++$i;
    ++$j;
  }
  return;
}


##########################################################
sub writeEndNode {
##########################################################
  my $nodeObj;
  my $endNode = $Gparents[-1]; # content of the last element
  my $si = $#Gparents;         # index   of the last element

  my $min = defined $Gparents[0] ? 0 : 1;
  for ( my $i = $min ; $Gparents[$i] ne $endNode ; ++$i ) {
    if ( defined $Gparents[$i] ) { # Only defined if there are kids
      # Find parent of current parent:
      my $node;
      for ( my $j = $i + 1 ; ( !$node ) ; ++$j ) {
        if ( $Gparents[$j] ) {
          $node = $Gparents[$j];
          $Gcounts[$j] += $Gcounts[$i];
          push @{ $Gkids[$j] }, $Gparents[$i];
        }
      }

      $nodeObj  = "${Gparents[$i]} 0 obj<</Type/Pages/Parent ${node} 0 R\n/Kids [";
      $nodeObj .= "${_} 0 R " for @{ $Gkids[$i] };
      $nodeObj .= "]/Count ${Gcounts[$i]}>>endobj\n";
      $Gobject[ $Gparents[$i] ] = $Gpos;
      $Gpos += syswrite $OUT_FILE, $nodeObj;
    }
  }

  # Arrange and print the end node:
  $nodeObj  = "${endNode} 0 obj<</Type/Pages/Kids [";
  $nodeObj .= "${_} 0 R " for @{ $Gkids[$si] };
  $nodeObj .= "]/Count ${Gcounts[$si]}/MediaBox \[0 0 ";
  $nodeObj .= "${GoWid} ${GoHei}\]>>endobj\n";
  $Gobject[$endNode] = $Gpos;
  $Gpos += syswrite $OUT_FILE, $nodeObj;
  return $endNode;
}


##########################################################
sub calcMatrix {
##########################################################
  my $x = $_[0]; my $y = $_[1]; my $rotate = $_[2];
  my $str = "1 0 0 1 ${x} ${y} cm\n";

  if ($rotate) {
    my $upperX = 0; my $upperY = 0;
    my $radian = sprintf( "%.6f", $rotate / 57.2957795 );  # approx.
    my $Cos    = sprintf( "%.6f", cos($radian) );
    my $Sin    = sprintf( "%.6f", sin($radian) );
    my $negSin = $Sin * -1;
    $str .= "${Cos} ${Sin} ${negSin} ${Cos} ${upperX} ${upperY} cm\n";
  }
  return $str;
}


##########################################################
sub getRoot {
##########################################################
  my ( $xref, $tempRoot, $buf );

  sysseek $IN_FILE, -50, 2;
  sysread $IN_FILE, $buf, 100;
  die "[!] File ${GinFile} is encrypted, cannot be used, aborting"
    if $buf =~ m'Encrypt'o;
  if ( $buf =~ m'\bstartxref\s+(\d+)'o ) {
    $xref = $1;
    # stat[7] = filesize
    die "[!] Invalid XREF, aborting" if $xref > (stat($GinFile))[7];
    $tempRoot = getRootFromXrefSection( $xref );
  }

  $tempRoot or return 0; # No Root object in ${GinFile}, aborting
  saveOldObjects();
  return $tempRoot;
}


##########################################################
sub getRootFromXrefSection {
##########################################################
  my $xref = $_[0];
  my ( $i, $rooty, $qty, $incoming_line, $buf );

  sysseek $IN_FILE, $xref += 5, 0;
  ($incoming_line, $qty, $i) = extractContent();

  while ($qty) {
    for ( my $l = 1 ; $l <= $qty ; ++$l ) {
      sysread $IN_FILE, $incoming_line, 20;
      if ( $incoming_line =~ m'^\s?(\d+) \d+ (\w)\s*'o ) {
        $GoldObject{$i} = int($1) unless $2 ne "n" or exists $GoldObject{$i};
      }
      ++$i;
    }
    ($incoming_line, $qty, $i) = extractContent();
  }

  while ($incoming_line) {
    $buf .= $incoming_line;
    $rooty = $1 if $buf =~ m'\/Root\s+(\d+)\s{1,2}\d+\s{1,2}R'so;
    last if $rooty;
    sysread $IN_FILE, $incoming_line, 30;
  }

  return $rooty;
}


##########################################################
sub getObject {
##########################################################
  my $index = $_[0];
  return 0 if ! defined $GoldObject{$index};
  my $buf;
  my ( $offs, $size ) = @{ $GoldObject{$index} };

  sysseek $IN_FILE, $offs, 0;
  sysread $IN_FILE, $buf, $size;
  return $buf;
}


##########################################################
sub writeToBeCreated {
##########################################################
  my $elObje = $_[0];
  my ( $out_line, $part, $strPos);

  for (@Gto_be_created) {
    my $old_one = $_->[0];
    my $new_one = $_->[1];
    $elObje = getObject($old_one);
    if ( $elObje =~ m'^(\d+ \d+ obj\s*<<)(.+)(>>\s*stream)'os ) {
      $part  = $2;
      $strPos = length($1) + length($2) + length($3);
      renew_ddR_and_populate_to_be_created($part);
      $out_line = "${new_one} 0 obj\n<<${part}>>stream";
      $out_line .= substr( $elObje, $strPos );
    } else {
      $elObje = substr( $elObje, length($1) ) if $elObje =~ m'^(\d+ \d+ obj\s*)'os;
      renew_ddR_and_populate_to_be_created($elObje);
      $out_line = "${new_one} 0 obj ${elObje}";
    }
    $Gobject[$new_one] = $Gpos;
    $Gpos += syswrite $OUT_FILE, $out_line;
  }
  undef @Gto_be_created;
  return;
}


##########################################################
sub getInputPageDimensions {
##########################################################
  # Find root:
  my $elObje = getObject($Groot);

  # Find pages:
  if ( $elObje =~ m'/Pages\s+(\d+)\s{1,2}\d+\s{1,2}R'os ) {
    $elObje = getObject($1);
  } else {
    return "unknown";
  }

  $elObje = xformObjForThisPage($elObje, 1);
  (undef, undef) = getResources( $elObje );
  return 0 if ! defined $GformBox[2] or ! defined $GformBox[3];
  my $multi = int($GformBox[2]) * int($GformBox[3]);
  my $measuresInMm = int($GformBox[2] / 72 * 25.4) . " x "
    . int($GformBox[3] / 72 * 25.4) . " mm";

  if ($multi > 119_780 and $multi < 121_780) { # US 1/4 letter: 120780
    $GoWid  = $DW;
    $GoHei = $DH;
    return "QT";
  }
  if ($multi > 123_443 and $multi < 125_443) { # ISO A6: 124443
    $GoWid  = $AW;
    $GoHei = $AH;
    return "A6";
  }
  if ($multi > 152_720 and $multi < 154_720) { # US 1/4 legal: 153720
    $GoWid  = $GW;
    $GoHei = $GH;
    return "QG";
  }
  if ($multi > 241_352 and $multi < 243_352) { # USstatement: 242352
    $GoWid  = $DW;
    $GoHei = $DH;
    return "HT";
  } 
  if ($multi > 248_305 and $multi < 250_305) { # ISO A5: 249305
    $GoWid  = $AW;
    $GoHei = $AH;
    return "A5";
  }
  if ($multi > 307_448 and $multi < 309_448) { # US 1/2 legal: 308448
    $GoWid  = $GW;
    $GoHei = $GH;
    return "HG";
  }
  if ($multi > 483_704 and $multi < 485_704) { # US letter: 484704
    return "USletter, ${measuresInMm}";
  }
  if ($multi > 499_395 and $multi < 501_395) { # ISO A4: 500395
    return "A4, ${measuresInMm}";
  }
  if ($multi > 615_896 and $multi < 617_896) { # US legal: 616896
    return "USlegal, ${measuresInMm}";
  }
  return "unknown, ${measuresInMm}";
}


##########################################################
sub getPage {
##########################################################
  my $pagenumber = $_[0];

  my ( $reference, $formRes, $formCont );

  my $fSource = "${GinFile}_${pagenumber}";

  # Find root:
  my $elObje = getObject($Groot);

  # Find pages:
  if ( $elObje =~ m'/Pages\s+(\d+)\s{1,2}\d+\s{1,2}R'os ) {
    $elObje = getObject($1);
  } else {
    die "[!] Didn't find Pages section in '${GinFile}' - aborting";
  }

  $elObje = xformObjForThisPage($elObje, $pagenumber);
  ($formRes, $formCont) = getResources( $elObje );

  $reference = writeRes($elObje, $formRes, $formCont);

  writeToBeCreated($elObje);

  return $reference;
}


##########################################################
sub writeRes {
##########################################################
  my $elObje = $_[0]; my $formRes = $_[1]; my $formCont = $_[2];
  my $out_line;

  $elObje = getObject($formCont);
  $elObje =~ m'^(\d+ \d+ obj\s*<<)(.+)(>>\s*stream)'so;
  my $strPos = length($1) + length($2) + length($3);
  my $newPart = "<</Type/XObject/Subtype/Form/FormType 1/Resources ${formRes}"
    . "/BBox \[ $GformBox[0] $GformBox[1] $GformBox[2] $GformBox[3]\] ${2}";
  ++$GobjNr;
  $Gobject[$GobjNr] = $Gpos;
  my $reference = $GobjNr;
  renew_ddR_and_populate_to_be_created($newPart);
  $out_line = "${reference} 0 obj\n${newPart}>>\nstream";
  $out_line .= substr( $elObje, $strPos );
  $Gpos += syswrite $OUT_FILE, $out_line;
  return $reference;
}


##########################################################
sub xformObjForThisPage {
##########################################################
  my $elObje = $_[0]; my $pagenumber = $_[1];
  my ( $vector, @pageObj, @pageObjBackup, $pageAccumulator);

  if ($elObje =~ m'/Kids\s*\[([^\]]+)'os ) {
    $vector = $1;
  } else {
    return 0;
  }
  $pageAccumulator = 0;

  push @pageObj, $1 while $vector =~ m'(\d+)\s{1,2}\d+\s{1,2}R'go;
  while ( $pageAccumulator < $pagenumber ) {
    @pageObjBackup = @pageObj;
    undef @pageObj;
    for (@pageObjBackup) {
      $elObje = getObject($_);
      if ( $elObje =~ m'/Count\s+(\d+)'os ) {
        if ( ( $pageAccumulator + $1 ) < $pagenumber ) {
          $pageAccumulator += $1;
        } else {
          $vector = $1 if $elObje =~ m'/Kids\s*\[([^\]]+)'os ;
          push @pageObj, $1 while $vector =~ m'(\d+)\s{1,2}\d+\s{1,2}R'gso;
          last;
        }
      } else {
        ++$pageAccumulator;
      }
      last if $pageAccumulator == $pagenumber;
    }
  }
  return $elObje;
}


##########################################################
sub getResources {
##########################################################
  my $obj = $_[0];
  my ($resources, $formCont);

  # Assume all input PDF pages have the same dimensions as first MediaBox found:
  if (! @GformBox) {
    if ( $obj =~ m'MediaBox\s*\[\s*([\S]+)\s+([\S]+)\s+([\S]+)\s+([\S]+)\s*\]'os ) {
      @GformBox = ($1, $2, $3, $4);
    }
  }

  if ( $obj =~ m'/Contents\s+(\d+)'so ) {
    $formCont = $1;
  } elsif ( $obj =~ m'/Contents\s*\[\s*(\d+)\s{1,2}\d+\s{1,2}R\s*\]'so ) {
    $formCont = $1;
  }

  $resources = getResourcesFromObj($obj);

  return ($resources, $formCont);
}


##########################################################
sub getResourcesFromObj {
##########################################################
  my $obj = $_[0];
  my $resources;

  if ( $obj =~ m'^(.+/Resources)'so ) {
    if ( $obj =~ m'Resources(\s+\d+\s{1,2}\d+\s{1,2}R)'os ) { # Reference (95%)
      $resources = $1;
    } else {  # The resources are a dictionary. The whole is copied (morfologia.pdf)
      my $k;
      ( undef, $obj ) = split /\/Resources/, $obj;
      $obj =~ s/<</#<</gs;
      $obj =~ s/>>/>>#/gs;
      for ( split /#/, $obj ) {
        if ( m'\S's ) {
          $resources .= $_;
          ++$k if m'<<'s;
          --$k if m'>>'s;
          last if $k == 0;
        }
      }
    }
  }
  return $resources;
}


##########################################################
sub openInputFile {
##########################################################
  $GinFile = $_[0];
  my ( $elObje, $inputPageSize );

  open( $IN_FILE, q{<}, $GinFile )
    or die "[!] Couldn't open ${GinFile}";
  binmode $IN_FILE;

  # Find root
  $Groot = getRoot();

  # Find input page size:
  $inputPageSize = getInputPageDimensions();

  # Find pages
  return 0 unless eval { $elObje = getObject($Groot); 1; };
  if ( $elObje =~ m'/Pages\s+(\d+)\s{1,2}\d+\s{1,2}R'os ) {
    $elObje = getObject($1);
    return ($1, $inputPageSize) if $elObje =~ m'/Count\s+(\d+)'os;
  }
  return 0;
}


##########################################################
sub saveOldObjects {
##########################################################
  my $bytes = (stat($GinFile))[7];  # stat[7] = filesize
  # Objects are sorted in reverse order
  # (according to their offset in the file: last first)
  my @offset = sort { $GoldObject{$b} <=> $GoldObject{$a} } keys %GoldObject;

  my $saved;

  for (@offset) {
    $saved = $GoldObject{$_};
    $bytes -= $saved;
    $GoldObject{$_} = [ $saved, $bytes ] if ($_ !~ m'^xref'o);
    $bytes = $saved;
  }
}


##########################################################
sub renew_ddR_and_populate_to_be_created {
##########################################################
  # $xform translates an old object number to a new one
  # and populates a table with what must be created
  my $xform = sub { return $Gold{$1} if exists $Gold{$1};
    push @Gto_be_created, [ $1, ++$GobjNr ];
    return $Gold{$1} = $GobjNr;
  };
  $_[0] =~ s/\b(\d+)\s{1,2}\d+\s{1,2}R\b/&$xform . ' 0 R'/oegs;
  return;
}


##########################################################
sub extractContent {
##########################################################
  my ($incoming_line, $qty, $i, $c);

  sysread $IN_FILE, $c, 1;
  sysread $IN_FILE, $c, 1 while $c =~ m!\s!s;
  while ( (defined $c) and ($c ne "\n") and ($c ne "\r") ) {
    $incoming_line .= $c;
    sysread $IN_FILE, $c, 1;
  }
  if ( $incoming_line =~ m'^(\d+)\s+(\d+)'o ) {
    $i   = $1;
    $qty = $2;
  }

  return ($incoming_line, $qty, $i);
}


##########################################################
sub openOutputFile {
##########################################################
  closeOutputFile() if $Gpos;

  my $outputfile = $_[0];
  my $pdf_signature = "%PDF-1.4\n%\â\ã\Ï\Ó\n"; # Keep it far from file beginning!

  open( $OUT_FILE, q{>}, $outputfile )
    or die "[!] Couldn't open file ${outputfile}";
  binmode $OUT_FILE;
  $Gpos = syswrite $OUT_FILE, $pdf_signature;

  $GobjNr      = 2;  # Objeto reservado 1 para raíz y 2 para nodo lateral inicial
  $Gparents[0] = 2;

  newPageInOutputFile();
  setInitGrState();
  return;
}


##########################################################
sub closeInputFile {
##########################################################
  close $IN_FILE;
}

1;

__END__

=head1 NAME

App::paperback - Copy and transform pages from a PDF into a new PDF

=head1 SYNOPSIS

 use strict;
 use App::paperback;
 my $inputFile              = "some-A6-pages.pdf";
 my $outputFile             = "new-A4-pages.pdf";
 my $desiredPage            = 1;
 my $newPositionXinPoints   = 100;
 my $newPositionYinPoints   = 150;
 my $rotate                 = 90;
 my ($numPages, $paperSize) = openInputFile($inputFile);
 openOutputFile($outputFile);
 newPageInOutputFile();
 copyPageFromInputToOutput( {
     page => $desiredPage,
     rotate => $rotate,
     x => $newPositionXinPoints,
     y => $newPositionYinPoints
 } );
 closeInputFile();
 closeOutputFile();

=head1 DESCRIPTION

This module allows you to transform pages from an input PDF file
into a new PDF file. Input PDF should:

1. Conform to version 1.4 of PDF;

2. Consist of vertical-oriented pages of the same size;

3. Use page sizes of A5 or A6 or Half Letter or Quarter Letter
or Half Legal or Quarter Legal.

=cut
