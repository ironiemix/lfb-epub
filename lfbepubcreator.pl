#!/usr/bin/perl 

# Dieses Skript erzeugt ein epub für ein
# Unterverzeichnis auf dem Lehrerfortbildungsserver
# http://www.lehrerfortbildung-bw.de/
#
# GPLv3
# 2014/2015 Frank Schiebel <frank@linuxmuster.net>
#
# Zusätzliche Software für den LFB-Server
# perl-File-Copy-Recursive
# perl-Filforeach (@images) {
# perl-HTML-TokeParser-Simple
# pandoc
#
#
# Perl-Libs
use strict;
use warnings;
use Getopt::Std;
use File::Path;
use File::Slurp;
use File::Copy::Recursive qw(dircopy);
use HTML::TokeParser::Simple;
use HTML::TreeBuilder;

# Settings
# Wo liegen die kleinen Bildchen im System?
my $PIXPATH="/srv/www/lfb/pix";
# LFB-URL
my $LFBBASEURI="http://lehrerfortbildung-bw.de";
# Wo soll die HTML-Version des Seitenbereichs erzeugt werden,
# aus dem das ePub generiert wird 
my $BUILDDIR="/root/create_epub/";
# Basis der HTM-Quellen für mason
my $HTMLBASE="/srv/www/lfb";
# Debugausgaben?
my $DEBUG=1;
# Loglevel: 
# 4 - Alle Messages
# 3 - Info
# 2 - Warning
# 1 - Errors only
my $LOGLEVEL=4;
# Ausgabe in eine Datei oder in mehrere?
my $MULTIFILE=0;
# Befehl um das epub zu erzeugen
my $EPUBCMD = "/usr/bin/pandoc -f html -o ebook.epub ";


# Kommandozeilenoptionen
#
# -s <Source-Unterverzeichnis>
#
my %options=();
getopts("s:", \%options);

print_help() if not defined $options{s};
my $RELATIVEURI = $options{s};
$RELATIVEURI =~ s/\/*$//;

my $SOURCEPATH="$HTMLBASE/$RELATIVEURI";

if ( ! -d "$SOURCEPATH" ) {
    print "Quellverzeichnis $SOURCEPATH existiert nicht";
    exit 1;
} 


logit("HTML-Version wird im Verzeichnis: $BUILDDIR zusammengesetzt",3);
logit("Quellverzeichnis: $SOURCEPATH ist vorhanden",3);

rmtree $BUILDDIR;
mkdir $BUILDDIR;




# Array mit den Unterseiten erstellen

# wenn es eine hmenu.txt gibt.
my @subindexes;
if ( -e "$SOURCEPATH/hmenu.txt") {
    my @hmenuitems = read_hmenu("$SOURCEPATH/hmenu.txt");
    for(@hmenuitems){
        my $indexpage = $HTMLBASE . "$_";
        chop($indexpage);
        push @subindexes, $indexpage;
    }
}

# Bearbeite die index.html des Bereichs
file_exists_or_exit("$SOURCEPATH/index.html");
clean_html("$SOURCEPATH/index.html", \@subindexes);

sub print_help {
print <<"EOT";
    Verwendung: 
    
    $0 -s <Quellverzeichnis>

    <Quellverzeichnis>  ist das Unterverzeichnis unterhalb von
                        $HTMLBASE 
                        für welches das ePub erzeugt werden soll.
EOT
    exit 0
}

sub clean_html {
    my ($file, $subindexref) = @_;
    my $htmlfilelist = "ebook.html";
    my $html  = HTML::TreeBuilder->new;
    my $outhtml = HTML::TreeBuilder->new;
    my $root  = $html->parse_file($file);

    my $head  = $root->find( 'head');
    my $body  = $root->find( 'body');

    my $node=$outhtml->find('head');
    $node->replace_with($head);
    my $outbody = HTML::Element->new('body');

    my $title = $head->find('title');
    if( my $title_text = eval{ $title->content_array_ref->[0] } ) {
        print "... Document Title is: $title_text\n";
        my $h1 = HTML::Element->new('h1');
        $h1->push_content($title_text);
        $outbody->push_content($h1);
    }

        
    # Bilder ------------------------------------
    my @images = $body->look_down('_tag', 'img');
    foreach (@images) {
        my $imgsrc = $_->attr('src');

        # Fix: Absolute Pfade für LFB-Pix
        if ( $imgsrc =~ m/^\/pix/ ) {
            $imgsrc = $HTMLBASE . $imgsrc;
            $_->attr('src' , $imgsrc);
        }
    }

    # Links ------------------------------------
    my  @links = $body->look_down('_tag', 'a');
    foreach (@links) {
        my $ahref = $_->attr('href');

        # Absolute Links werden mit der LFB-Server
        # Basis-URL versehen
        if ( $ahref =~ m/^\// ) {
            $ahref = "$LFBBASEURI$ahref";
            $_->attr('href', $ahref);
        }
        # Relative Links müssen behandelt werden: 
        if ( $ahref =~ m/^\.\.\// ) {
            my $reluri = $RELATIVEURI;

            # Für jedes "../" am Beginn des Links
            # wird ein Verzeichnis im 
            # Pfad am Ende abgeschnitten
            while ( $ahref =~ m/^\.\./ ) {
                $ahref =~ s|^\.\./||;
                $reluri =~ s|(.*)(/.+?)$|$1|;
            }
            $ahref = $LFBBASEURI . "/" . $reluri . "/". $ahref;
            $_->attr('href', $ahref);
        }

    }

    # Modifizierter $body der Haupseite an $outbody 
    # anhängen
    my @bodyelements = $body->detach_content;
    foreach my $node (@bodyelements) {
        $outbody->push_content($node);
    }

    if ( $MULTIFILE ) {
        logit("Multifile ist gesetzt, erzeuge Hauptdatei ebook.html", 3);
        my $node=$outhtml->find('body');
        $node->replace_with($outbody);
        open (MYFILE, ">$BUILDDIR/ebook.html");
        print MYFILE $outhtml->as_HTML;
        close (MYFILE); 
    }


    # Unterseiten -------------------------------
    foreach (@{$subindexref}) { 
        

        my $subindexdir = $_;
        logit("Bearbeite $subindexdir", 3);
        my $indexpage .= $subindexdir . "index.html";

        file_exists_or_exit("$indexpage");

        # Medienverzeichnis ermitteln, anlegen und Medien 
        # kopieren
        my $mediadirname = $subindexdir;
        print "--------------- " . $subindexdir . "------------\n";
        $mediadirname =~ s|(.*)/(.+?)/$|$2|;
        my $singlehtmlname = $mediadirname;
        print "--------------- " . $singlehtmlname . "------------\n";
        $mediadirname = $BUILDDIR . $mediadirname; 
        logit("... Seitenmedien werden nach $mediadirname übernommen", 3);  
        my($num_of_files_and_dirs,$num_of_dirs,$depth_traversed) = dircopy($subindexdir,$mediadirname);
        logit ("... Kopierte Elemente: $num_of_files_and_dirs Kopierte Verzeichnisse: $num_of_dirs Rekursionstiefe: $depth_traversed", 3);
        if ( -e "$mediadirname/index.html" ) {
            unlink "$mediadirname/index.html";
            logit ("... Lösche kopierte index.html",3);
        }
        
        if ( $MULTIFILE ) {
            logit("Multifile ist gesetzt, erzeuge neuen OutTree", 3);
            $outhtml = HTML::TreeBuilder->new;
        }
        
        my $subhtml  = HTML::TreeBuilder->new;
        my $subroot  = $subhtml->parse_file("$indexpage");
        my $subhead  = $subroot->find('head');
        my $subbody  = $subroot->find('body');
        
        if ( $MULTIFILE ) {
            logit("Multifile ist gesetzt, erzeuge neuen OutTree", 3);
            $outhtml = HTML::TreeBuilder->new;
            # Head ersetzen i´mi dem der aktuellen Seite
            my $node=$outhtml->find('head');
            $node->replace_with($subhead);
            # Reset $outbody
            $outbody = HTML::Element->new('body');
        }
        

        my $title = $subhead->find('title');
        if( my $title_text = eval{ $title->content_array_ref->[0] } ) {
            print "... Title is: $title_text\n";
            my $h1 = HTML::Element->new('h1');
            $h1->push_content($title_text);
            $outbody->push_content($h1);
        }
        
        # Bilder ------------------------------------
        my @images = $subbody->look_down('_tag', 'img');
        foreach (@images) {
            my $imgsrc = $_->attr('src');

            # Fix: Absolute Pfade für LFB-Pix
            if ( $imgsrc =~ m/^\/pix/ ) {
                $imgsrc = $HTMLBASE . $imgsrc;
                $_->attr('src' , $imgsrc);
                next;
            }
            # FIXME ./
            # FIXME ../


            # Fix: Bilder, die zuvor im 
            # lokalen Verzeichns lagen, sind 
            # jetzt in $mediadirname
            if ( ! ($imgsrc =~ m/\//g)  ) {
                logit ("... ...IMG Oldsource: $imgsrc",3);
                $imgsrc = $mediadirname . "/" . $imgsrc;
                logit ("... ...IMG Newsource: $imgsrc",3);
                $_->attr('src' , $imgsrc);
            }
            
        }   
        # Modifizierter subbody an outbody anhängen
        my @bodyelements = $subbody->detach_content;
        foreach  $node (@bodyelements) {
            $outbody->push_content($node);
        }

        # Wenn Multifile: HTML Datei schreiben.
        if ( $MULTIFILE ) {
                logit("Multifile ist gesetzt, schreibe $singlehtmlname.html.", 3);
                $htmlfilelist = $htmlfilelist . " " . $singlehtmlname . ".html";
                my $node=$outhtml->find('body');
                $node->replace_with($outbody);
                open (MYFILE, ">$BUILDDIR/$singlehtmlname.html");
                print MYFILE $outhtml->as_HTML;
                close (MYFILE); 
        }
    }
    
    if ( ! $MULTIFILE ) {
        my $node=$outhtml->find('body');
        $node->replace_with($outbody);
        open (MYFILE, ">$BUILDDIR/ebook.html");
        print MYFILE $outhtml->as_HTML;
        close (MYFILE); 
    }

    $root->delete;
    $outhtml->delete;

    # Baue das epub
    $EPUBCMD = "$EPUBCMD $htmlfilelist";
    logit("Baue ePub mit Kommando: $EPUBCMD",3);
    system("cd $BUILDDIR && $EPUBCMD");
}

sub logit {
    my ($message, $level) = @_;
    if ( $DEBUG && $LOGLEVEL > $level ) {
        print "$message\n";
    }
}


# Prüfe ob die Datei existiert, wenn nicht
# Error Exit.
sub file_exists_or_exit {
    my ($file) = @_;
    if ( ! -e $file ) {
        logit("File $file doesnt exist.", 0);
        exit 1;
    }
}

# Lese hmenu.txt in einen Hash ein
# key   -> Name im Menü
# value -> index.html relativ zu $HTMLBASE
sub read_hmenu {
    my ($hmenufile) = @_;
    my @items = read_file($hmenufile) =~ /^.*=>(.*)$/mg; 
    return @items;
}

