package App::paperback;

use v5.10;
use strict;
# use warnings;
our $VERSION = "1.19";

my ($GinFile, $GpageObjNr, $GrootNr, $Gpos, $GobjNr, $Gstream, $GoWid, $GoHei);
my (@Gkids, @Gcounts, @GmediaBox, @Gobject, @Gparents, @Gto_be_created);
my (%GpageXObject, %GObjects, %Gpaper);

my $cr = '\s*(?:\015|\012|(?:\015\012))';

# ISO 216 paper sizes in pt (four decimals will do):
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

# Paper surfaces in square pts (expressed as HxW in points):
%Gpaper = (
	QuarterLetter => $FH*$FW, # 121_176
	A6            => $CH*$CW, # 124_867…
	QuarterLegal  => $IH*$IW, # 154_224
	HalfLetter    => $EH*$EW, # 242_352
	A5            => $BH*$BW, # 249_735…
	HalfLegal     => $HH*$HW, # 308_448
	Letter        => $DH*$DW, # 484_704
	A4            => $AH*$AW, # 501_156…
	Legal         => $GH*$GW, # 616_896
);

# Page reordering and position offset schemas for "4 up":
my @P_4UP_13PLUS = (16,1,13,4,2,15,3,14,12,5,9,8,6,11,7,10);
my @P_4UP_9PLUS = (12,1,9,4,2,11,3,10,6,7,9999,9999,8,5);
my @P_4UP_5PLUS = (8,1,5,4,2,7,3,6);
my @P_4UP_1PLUS = (4,1,9999,9999,2,3);
my @X_A6_ON_A4 = (0,$CW,$CW,$AW,0,$CW,$CW,$AW,0,$CW,$CW,$AW,0,$CW,$CW,$AW);
my @Y_A6_ON_A4 = ($CG,$CG,$CH,$CH,$CG,$CG,$CH,$CH,$CG,$CG,$CH,$CH,$CG,$CG,$CH,$CH);
my @X_QT_ON_LT = (0,$FW,$FW,$DW,0,$FW,$FW,$DW,0,$FW,$FW,$DW,0,$FW,$FW,$DW);
my @Y_QT_ON_LT = ($FH,$FH,$FH,$FH,$FH,$FH,$FH,$FH,$FH,$FH,$FH,$FH,$FH,$FH,$FH,$FH);
my @X_QG_ON_LG = (0,$IW,$IW,$GW,0,$IW,$IW,$GW,0,$IW,$IW,$GW,0,$IW,$IW,$GW);
my @Y_QG_ON_LG = ($IH,$IH,$IH,$IH,$IH,$IH,$IH,$IH,$IH,$IH,$IH,$IH,$IH,$IH,$IH,$IH);

# Page reordering and position offset schemas for "2 up":
my @P_2UP_13PLUS = (1,16,2,15,3,14,4,13,5,12,6,11,7,10,8,9);
my @P_2UP_9PLUS = (1,12,2,11,3,10,4,9,5,8,6,7);
my @P_2UP_5PLUS = (1,8,2,7,3,6,4,5);
my @P_2UP_1PLUS = (1,4,2,3);
my @X_A5_ON_A4 = ($BH,$BH,0,0,$BH,$BH,0,0,$BH,$BH,0,0,$BH,$BH,0,0);
my @Y_A5_ON_A4 = ($BG,0,$AH,$BG,$BG,0,$AH,$BG,$BG,0,$AH,$BG,$BG,0,$AH,$BG);
my @X_HT_ON_LT = ($EH,$EH,0,0,$EH,$EH,0,0,$EH,$EH,0,0,$EH,$EH,0,0);
my @Y_HT_ON_LT = ($EW,0,$DH,$EW,$EW,0,$DH,$EW,$EW,0,$DH,$EW,$EW,0,$DH,$EW);
my @X_HG_ON_LG = ($HH,$HH,0,0,$HH,$HH,0,0,$HH,$HH,0,0,$HH,$HH,0,0);
my @Y_HG_ON_LG = ($HW,0,$GH,$HW,$HW,0,$GH,$HW,$HW,0,$GH,$HW,$HW,0,$GH,$HW);

my ( $IN_FILE, $OUT_FILE );


##########################################################
sub main {
##########################################################
  my $input = $ARGV[0];
  my ($inpPgNum, $inpPgSize);
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
  x 8.5 in) produce a Letter output page size (8.5 x 11 in). Input
  page sizes Quarter Legal (4.25 x 7 in) and Half Legal (7 x 8.5 in)
  produce a Legal output page size (8.5 x 14 in). Four Quarter-Letter
  pages will be put on each Letter page, two Half-Letter pages will be
  put on each Letter page, four Quarter-Legal pages will be put on each
  Legal page, or two Half-Legal pages will be put on each Legal page.
  Before that, input pages will be reordered and reoriented so as to 
  produce a final PDF fit for duplex 'long-edge-flip' printing.

For further details, please try 'perldoc paperback'.

${sayVersion}
END_MESSAGE

  die "[!] ${sayUsage}\n"
    if ! defined $input;
  do {print STDERR "${sayHelp}" and exit}
    if $input =~ "^-h\$" or $input =~ "^--help\$";
  do {print STDERR "${sayVersion}\n" and exit}
    if $input =~ "^-v\$" or $input =~ "^--version\$";
  die "[!] File '${input}' can't be found or read.\n"
    unless -r $input;
  ($inpPgNum, $inpPgSize) = openInputFile($input);
  die "[!] File '${input}' is not a valid v1.4 PDF file.\n"
    if $inpPgNum == 0;

  my ($pgPerOutputPage, @x, @y);
  for ($inpPgSize) {
    if    ($_ eq "A6") { $pgPerOutputPage = 4; @x = @X_A6_ON_A4; @y = @Y_A6_ON_A4; }
    elsif ($_ eq "A5") { $pgPerOutputPage = 2; @x = @X_A5_ON_A4; @y = @Y_A5_ON_A4; }
    elsif ($_ eq "QT") { $pgPerOutputPage = 4; @x = @X_QT_ON_LT; @y = @Y_QT_ON_LT; }
    elsif ($_ eq "QG") { $pgPerOutputPage = 4; @x = @X_QG_ON_LG; @y = @Y_QG_ON_LG; }
    elsif ($_ eq "HT") { $pgPerOutputPage = 2; @x = @X_HT_ON_LT; @y = @Y_HT_ON_LT; }
    elsif ($_ eq "HG") { $pgPerOutputPage = 2; @x = @X_HG_ON_LG; @y = @Y_HG_ON_LG; }
    else {die "[!] Bad page size (${inpPgSize}). Try 'paperback -h' for more info.\n"}
  }

  my ($name) = $input =~ /(.+)\.[^.]+$/;
  openOutputFile("${name}-paperback.pdf");
  my ($rot_extra, @p);
  if ($pgPerOutputPage == 4) {
    $rot_extra = 0;
    for ($inpPgNum) {
      if    ($_ >= 13) { @p = @P_4UP_13PLUS; }
      elsif ($_ >= 9 ) { @p = @P_4UP_9PLUS;  } 
      elsif ($_ >= 5 ) { @p = @P_4UP_5PLUS;  } 
      else             { @p = @P_4UP_1PLUS;  }
    }
  } else {
    $rot_extra = 90;
    for ($inpPgNum) {
      if    ($_ >= 13) { @p = @P_2UP_13PLUS; } 
      elsif ($_ >= 9 ) { @p = @P_2UP_9PLUS;  } 
      elsif ($_ >= 5 ) { @p = @P_2UP_5PLUS;  } 
      else             { @p = @P_2UP_1PLUS;  }
    }
  }
  my $lastSignature = $inpPgNum >> 4;
  my ($rotation, $target_page);
  for (my $thisSignature = 0; $thisSignature <= $lastSignature; ++$thisSignature) {
    for (0..15) {
      newPageInOutputFile() if $_ % $pgPerOutputPage == 0;
      $target_page = $p[$_] + 16 * $thisSignature;
      next if $target_page > $inpPgNum;

      $rotation = $_ % 4 > 1 ? $rot_extra + 180 : $rot_extra;
      copyPageFromInputToOutput ({page => $target_page,
        rotate => $rotation, x => $x[$_], y => $y[$_]});
      ++$numPagImposed;
      last if $numPagImposed == $inpPgNum;
    }
  }
  closeInputFile();
  closeOutputFile();
}

main() if not caller();


##########################################################
sub newPageInOutputFile {
##########################################################
  die "[!] No output file, you must call openOutputFile first.\n" if !$Gpos;
  writePage() if $Gstream;

  ++$GobjNr;
  $GpageObjNr = $GobjNr;
  undef %GpageXObject;

  return;
}


##########################################################
sub copyPageFromInputToOutput {
##########################################################
  die "[!] No output file, you have to call openOutputFile first.\n" if !$Gpos;
  my $param      = $_[0];
  my $pagenumber = $param->{'page'}   or 1;
  my $x          = $param->{'x'}      or 0;
  my $y          = $param->{'y'}      or 0;
  my $rotate     = $param->{'rotate'} or 0;

  state $formNr; # Este uso de "state" requiere v5.10 (que salió en 2007)
  ++$formNr;

  my $name = "Fm${formNr}";
  my $refNr = getPage( $pagenumber );
  die "[!] Page ${pagenumber} in ${GinFile} can't be used. Concatenate streams!\n" 
    if !defined $refNr;
  die "[!] Page ${pagenumber} doesn't exist in file ${GinFile}.\n" if !$refNr;

  $Gstream .= "q\n" . calcRotateMatrix($x, $y, $rotate) ."\n/Gs0 gs\n/${name} Do\nQ\n";
  $GpageXObject{$name} = $refNr;

  return;
}


##########################################################
sub setInitGrState {
##########################################################
  ++$GobjNr;

  $Gobject[$GobjNr] = $Gpos;
  $Gpos += syswrite $OUT_FILE,
    "${GobjNr} 0 obj<</Type/ExtGState/SA false/SM 0.02/TR2 /Default>>endobj\n";
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
  $resourceDict .= "/ExtGState<</Gs0 4 0 R>>";
  return $resourceDict;
}


##########################################################
sub writePageResourceDict {
##########################################################
  my $resourceDict = $_[0];

  state %resources;

  # Found one identical, use it:
  return $resources{$resourceDict} if exists $resources{$resourceDict};
  ++$GobjNr;
  # Save first 10 resources:
  $resources{$resourceDict} = $GobjNr if keys(%resources) < 10;
  $Gobject[$GobjNr] = $Gpos;
  $resourceDict = "${GobjNr} 0 obj<<${resourceDict}>>endobj\n";
  $Gpos += syswrite $OUT_FILE, $resourceDict;
  return $GobjNr;
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
  my ($parent, $resourceObject) = ($_[0], $_[1]);
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
  my $i = 0;
  my $j = 1;
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
  $nodeObj .= "]/Count ${Gcounts[$si]}/MediaBox [0 0 ${GoWid} ${GoHei}]>>endobj\n";
  $Gobject[$endNode] = $Gpos;
  $Gpos += syswrite $OUT_FILE, $nodeObj;
  return $endNode;
}


##########################################################
sub calcRotateMatrix {
##########################################################
  my $rotate = $_[2];
  my $str = "1 0 0 1 ${_[0]} ${_[1]} cm\n";

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
sub getRootAndMapGobjects {
##########################################################
  my ( $xref, $tempRoot, $buf, $buf2 );

  sysseek $IN_FILE, -150, 2;
  sysread $IN_FILE, $buf, 200;
  die "[!] File ${GinFile} is encrypted, cannot be used, aborting.\n"
    if $buf =~ m'Encrypt';

  if ($buf =~ m'/Prev\s+\d') { # "Versioned" PDF file (several xref sections)
    while ($buf =~ m'/Prev\s+(\d+)') {
      $xref = $1;
      sysseek $IN_FILE, $xref, 0;
      sysread $IN_FILE, $buf, 200;
      # Reading 200 bytes may NOT be enough. Read on till we find 1st %%EOF:
      until ($buf =~ m'%%EOF') {
        sysread $IN_FILE, $buf2, 200;
        $buf .= $buf2;
      }
    }
  } elsif ( $buf =~ m'\bstartxref\s+(\d+)' ) { # Non-versioned PDF file
    $xref = $1;
  } else {
    return 0;
  }
  
  # stat[7] = filesize
  die "[!] Invalid XREF, aborting.\n" if $xref > (stat($GinFile))[7];
  populateGobjects($xref);
  $tempRoot = getRootFromTraditionalXrefSection();
  return 0 unless $tempRoot; # No Root object in ${GinFile}, aborting
  return $tempRoot;
}


##########################################################
sub mapGobjectsFromTraditionalXref {
##########################################################
  my ( $idx, $qty, $readBytes );
  sysseek $IN_FILE, $_[0], 0;
  ($qty, $idx) = extractXrefSection();
  while ($qty) {
    for (1..$qty) {
      sysread $IN_FILE, $readBytes, 20;
      $GObjects{$idx} = $1 if $readBytes =~ m'^\s?(\d{10}) \d{5} n';
      ++$idx;
    }
    ($qty, $idx) = extractXrefSection();
  }
  return;
}


##########################################################
sub populateGobjects {
##########################################################
  my $xrefPos = $_[0];
  my $readBytes;

  sysseek $IN_FILE, $xrefPos, 0;
  sysread $IN_FILE, $readBytes, 22;

  if ($readBytes =~ /^(xref$cr)/) {              # Input PDF is v1.4 or lower
    mapGobjectsFromTraditionalXref($xrefPos + length($1));
  } elsif ($readBytes =~ m'^\d+\s+\d+\s+obj'i) { # Input PDF is v1.5 or higher
    die "[!] File '${GinFile}' uses xref streams (not a v1.4 PDF file).\n";
  } else {
    die "[!] File '${GinFile}' has a malformed xref table.\n";
  }
  
  addSizeToGObjects();
  return;
}


##########################################################
sub getRootFromTraditionalXrefSection {
##########################################################
  my $readBytes = " ";
  my $buf;
  while ($readBytes) {
    sysread $IN_FILE, $readBytes, 200;
    $buf .= $readBytes;
    return $1 if $buf =~ m'\/Root\s+(\d+)\s+\d+\s+R's;
  }
  return;
}


##########################################################
sub getObjectContent {
##########################################################
  my $index = $_[0];

  return 0 if (! defined $GObjects{$index});   # A non-1.4 PDF
  my ($buf, $buf2);
  my ($offset, $size) = @{ $GObjects{$index} };
  sysseek $IN_FILE, $offset, 0;
  sysread $IN_FILE, $buf, $size;
  return $buf;
}


##########################################################
sub writeToBeCreated {
##########################################################
  my ($objectContent, $out_line, $part, $strPos, $old_one, $new_one);

  for (@Gto_be_created) {
    $old_one = $_->[0];
    $new_one = $_->[1];
    $objectContent = getObjectContent($old_one);
    if ( $objectContent =~ m'^(\d+ \d+ obj\s*<<)(.+)(>>\s*stream)'s ) {
      $part = $2;
      $strPos = length($1) + length($2) + length($3);
      update_references_and_populate_to_be_created($part);
      $out_line = "${new_one} 0 obj\n<<${part}>>stream";
      $out_line .= substr( $objectContent, $strPos );
    } else {
      $objectContent = substr( $objectContent, length($1) ) 
        if $objectContent =~ m'^(\d+ \d+ obj\s*)'s;
      update_references_and_populate_to_be_created($objectContent);
      $out_line = "${new_one} 0 obj ${objectContent}";
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
  my $objectContent = getObjectContent($GrootNr);
  
  # Find pages:
  return "unknown" unless $objectContent =~ m'/Pages\s+(\d+)\s+\d+\s+R's;
  $objectContent = getObjectContent($1);
  $objectContent = xformObjForThisPage($objectContent, 1)
    unless $objectContent =~ m'MediaBox's;
  (undef, undef) = getPageResources( $objectContent );
  return "unknown" if ! defined $GmediaBox[2] or ! defined $GmediaBox[3];

  my $surface = $GmediaBox[2]*$GmediaBox[3];
  my $measuresInMm = int($GmediaBox[2] / 72 * 25.4) . " x "
    . int($GmediaBox[3] / 72 * 25.4) . " mm";

  for ($surface) {
    if (alike($_, $Gpaper{QuarterLetter})) {$GoWid = $DW; $GoHei = $DH; return "QT"};
    if (alike($_, $Gpaper{A6}))            {$GoWid = $AW; $GoHei = $AH; return "A6"};
    if (alike($_, $Gpaper{HalfLetter}))    {$GoWid = $DW; $GoHei = $DH; return "HT"};
    if (alike($_, $Gpaper{QuarterLegal}))  {$GoWid = $DW; $GoHei = $DH; return "QG"};
    if (alike($_, $Gpaper{A5}))            {$GoWid = $AW; $GoHei = $AH; return "A5"};
    if (alike($_, $Gpaper{HalfLegal}))     {$GoWid = $GW; $GoHei = $GH; return "HG"};
    if (alike($_, $Gpaper{Letter}))        {return "USletter, ${measuresInMm}"};
    if (alike($_, $Gpaper{A4}))            {return "A4, ${measuresInMm}"};
    if (alike($_, $Gpaper{Legal}))         {return "USlegal, ${measuresInMm}"};
  }
  return "unknown, ${measuresInMm}";
}


##########################################################
sub alike {
##########################################################
  my $hxw = $_[0]; my $namedHxw = $_[1];
  my $tolerance = 1500;
  return 0 if $hxw > $namedHxw + $tolerance or $hxw < $namedHxw - $tolerance;
  return 1;
}


##########################################################
sub getPage {
##########################################################
  my $pagenumber = $_[0];
  my ( $reference, $formRes, $formCont );

  # Find root:
  my $objectContent = getObjectContent($GrootNr);

  # Find pages:
  die "[!] Didn't find Pages section in '${GinFile}', aborting.\n" 
    unless $objectContent =~ m'/Pages\s+(\d+)\s+\d+\s+R's;
  $objectContent = getObjectContent($1);
  $objectContent = xformObjForThisPage($objectContent, $pagenumber);
  ($formRes, $formCont) = getPageResources( $objectContent );

  $reference = writeRes($formRes, $formCont);

  writeToBeCreated();

  return $reference;
}


##########################################################
sub writeRes {
##########################################################
  my ($formRes, $objNr) = ($_[0], $_[1]);

  my $objectContent = getObjectContent($objNr);
  $objectContent =~ m'^(\d+ \d+ obj\s*<<)(.+)(>>\s*stream)'s;
  my $strPos = length($1) + length($2) + length($3);
  my $newPart = "<</Type/XObject/Subtype/Form/FormType 1/Resources ${formRes}"
    . "/BBox [@{GmediaBox}] ${2}";

  ++$GobjNr;
  $Gobject[$GobjNr] = $Gpos;
  my $reference = $GobjNr;
  update_references_and_populate_to_be_created($newPart);
  my $out_line = "${reference} 0 obj\n${newPart}>>\nstream";
  $out_line .= substr( $objectContent, $strPos );
  $Gpos += syswrite $OUT_FILE, $out_line;
  return $reference;
}


##########################################################
sub xformObjForThisPage {
##########################################################
  my ($objectContent, $pagenumber) = ($_[0], $_[1]);
  my ($vector, @pageObj, @pageObjBackup, $pageAccumulator);

  return 0 unless $objectContent =~ m'/Kids\s*\[([^\]]+)'s;
  $vector = $1;

  $pageAccumulator = 0;

  push @pageObj, $1 while $vector =~ m'(\d+)\s+\d+\s+R'gs;
  while ( $pageAccumulator < $pagenumber ) {
    @pageObjBackup = @pageObj;
    undef @pageObj;
    for (@pageObjBackup) {
      $objectContent = getObjectContent($_);
      if ( $objectContent =~ m'/Count\s+(\d+)'s ) {
        if ( ( $pageAccumulator + $1 ) < $pagenumber ) {
          $pageAccumulator += $1;
        } else {
          $vector = $1 if $objectContent =~ m'/Kids\s*\[([^\]]+)'s ;
          push @pageObj, $1 while $vector =~ m'(\d+)\s+\d+\s+R'gs;
          last;
        }
      } else {
        ++$pageAccumulator;
      }
      last if $pageAccumulator == $pagenumber;
    }
  }
  return $objectContent;
}


##########################################################
sub getPageResources {
##########################################################
  my $objContent = $_[0];
  my ($resources, $formCont);

  # Assume all input PDF pages have the same dimensions as first MediaBox found:
  if (! @GmediaBox) {
    for ($objContent) {
      if (m'MediaBox\s*\[\s*([\S]+)\s+([\S]+)\s+([\S]+)\s+([\S]+)\s*\]'s) {
        @GmediaBox = ($1, $2, $3, $4);
      } elsif (m'MediaBox\s*(\d+)\s+\d+\s+R\b's) { # Size to be found in reference
        my $ref = getObjectContent($1);
        @GmediaBox = ($1, $2, $3, $4)
          if ($ref =~ m'\[\s*([\S]+)\s+([\S]+)\s+([\S]+)\s+([\S]+)\s*\]'s);
      }
    }
  }

  if ( $objContent =~ m'/Contents\s+(\d+)'s ) {
    $formCont = $1;
  } elsif ( $objContent =~ m'/Contents\s*\[\s*(\d+)\s+\d+\s+R\s*\]'s ) {
    $formCont = $1;
  }

  $resources = getResourcesFromObj($objContent);

  return ($resources, $formCont);
}


##########################################################
sub getResourcesFromObj {
##########################################################
  my $objContent = $_[0];
  my $resources;

  if ( $objContent =~ m'^(.+/Resources)'s ) {
    return $1 if $objContent =~ m'Resources\s+(\d+\s+\d+\s+R)'s; # Reference (95%)
    # The resources are a dictionary. The whole is copied (morfologia.pdf):
    my $k;
    ( undef, $objContent ) = split /\/Resources/, $objContent;
    $objContent =~ s/<</#<</gs;
    $objContent =~ s/>>/>>#/gs;
    for ( split /#/, $objContent ) {
      if ( m'\S's ) {
        $resources .= $_;
        ++$k if m'<<'s;
        --$k if m'>>'s;
        last if $k == 0;
      }
    }
  }
  return $resources;
}


##########################################################
sub getInputPageCount {
##########################################################  
  my ($objectContent, $inputPageCount);

  return 0 unless eval { $objectContent = getObjectContent($GrootNr); 1; };
  if ( $objectContent =~ m'/Pages\s+(\d+)\s+\d+\s+R's ) {
    $objectContent = getObjectContent($1);
    return $1 if $objectContent =~ m'/Count\s+(\d+)'s;
  }
  return 0;
}


##########################################################
sub openInputFile {
##########################################################
  $GinFile = $_[0];
  my ( $objectContent, $inputPageSize, $inputPageCount, $c );

  open( $IN_FILE, q{<}, $GinFile )
    or die "[!] Couldn't open '${GinFile}'.\n";
  binmode $IN_FILE;

  sysread $IN_FILE, $c, 5;
  return 0 if $c ne "%PDF-";

  # Find root
  $GrootNr = getRootAndMapGobjects();
  return 0 unless $GrootNr > 0;

  $inputPageSize = getInputPageDimensions();
  $inputPageCount = getInputPageCount();
  return ($inputPageCount, $inputPageSize);
}


##########################################################
sub addSizeToGObjects {
##########################################################
  my $size = (stat($GinFile))[7];  # stat[7] = filesize
  # Objects are sorted numerically (<=>) and in reverse order ($b $a)
  # according to their offset in the file: last first
  my @offset = sort { $GObjects{$b} <=> $GObjects{$a} } keys %GObjects;
  my $pos;

  for (@offset) {
    $pos = $GObjects{$_};
    $size -= $pos;
    $GObjects{$_} = [ $pos, $size ];
    $size = $pos;
  }
}


##########################################################
sub update_references_and_populate_to_be_created {
##########################################################
  # $xform translates an old object reference to a new one
  # and populates a table with what must be created
  state %known;
  my $xform = sub {
    return $known{$1} if exists $known{$1};
    push @Gto_be_created, [ $1, ++$GobjNr ];
    return $known{$1} = $GobjNr;
  };
  $_[0] =~ s/\b(\d+)\s+\d+\s+R\b/&$xform . ' 0 R'/eg;
  return;
}


##########################################################
sub extractXrefSection {
##########################################################
  my $readBytes = ""; my ($qty, $idx, $c);

  sysread $IN_FILE, $c, 1;
  sysread $IN_FILE, $c, 1 while $c =~ m'\s's;
  while ( $c =~ /[\d ]/ ) {
    $readBytes .= $c;
    sysread $IN_FILE, $c, 1;
  }
  ($idx, $qty) = ($1, $2) if $readBytes =~ m'^(\d+)\s+(\d+)';
  return ($qty, $idx);
}


##########################################################
sub openOutputFile {
##########################################################
  closeOutputFile() if $Gpos;

  my $outputfile = $_[0];
  my $pdf_signature = "%PDF-1.4\n%\â\ã\Ï\Ó\n"; # Keep it far from file beginning!

  open( $OUT_FILE, q{>}, $outputfile )
    or die "[!] Couldn't open file '${outputfile}'.\n";
  binmode $OUT_FILE;
  $Gpos = syswrite $OUT_FILE, $pdf_signature;

  $GobjNr      = 2;  # Objeto reservado 1 para raíz y 2 para nodo de pág. inicial
  $Gparents[0] = 2;

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
 my $rotate                 = 45;
 my ($num_Pages, $paper_Size) = 
   App::paperback::openInputFile($inputFile);
 App::paperback::openOutputFile($outputFile);
 App::paperback::newPageInOutputFile();
 App::paperback::copyPageFromInputToOutput( {
     page   => $desiredPage,
     rotate => $rotate,
     x      => $newPositionXinPoints,
     y      => $newPositionYinPoints
 } );
 App::paperback::closeInputFile();
 App::paperback::closeOutputFile();

=head1 DESCRIPTION

This module allows you to transform pages from an input PDF file
into a new PDF file. Input PDF should:

1. Conform to version 1.4 of PDF;

2. Consist of vertical-oriented pages of the same size;

3. Use page sizes of A5 or A6 or Half Letter or Quarter Letter
or Half Legal or Quarter Legal.

=cut
