# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2009 - 2010 Andrew Jones, http://andrew-jones.com
# Copyright (C) 2006 Mike Marion
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# =========================
#
# This plugin creates an image by using the ploticus graph utility.
# See http://meta.wikimedia.org/wiki/EasyTimeline for more information.

package Foswiki::Plugins::EasyTimelinePlugin;

# =========================
use vars qw(
 $VERSION $RELEASE $pluginName $NO_PREFS_IN_TOPIC $SHORTDESCRIPTION
);

use Foswiki::Func ();
use Foswiki::Sandbox ();
use Digest::MD5 qw( md5_hex );
#the MD5 and hash table are used to create a unique name for each timeline
use File::Path;

our $VERSION = '$Rev$';
our $RELEASE = '1.3';
our $SHORTDESCRIPTION = 'Generate graphical timeline diagrams from markup text';
our $NO_PREFS_IN_TOPIC = 1;
our $pluginName = 'EasyTimelinePlugin';

my $png_or_gif;


# =========================
sub initPlugin {
    my ( $topic, $web ) = @_;
    
    # need a path to script in tool directory
    unless( $Foswiki::cfg{Plugins}{$pluginName}{EasyTimelineScript} ){
        # throw error, do not init
        logWarning(
            "$pluginName cant find EasyTimeline.pl - Try running configure");
        return 0;
    }
    # need a path to Ploticus
    unless( $Foswiki::cfg{Plugins}{$pluginName}{PloticusCmd} ){
        # throw error, do not init
        logWarning(
            "$pluginName cant find Ploticus (pl) - Try running configure");
        return 0;
    }
    
    # On Windows, the EasyTimeline script will produce a gif, not a png
    if( $Foswiki::cfg{OS} eq 'WINDOWS' ){
        $png_or_gif = 'gif';
    } else {
        $png_or_gif = 'png';
    }

    # Plugin correctly initialized
    writeDebug(
        "- Foswiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK");
    
    return 1;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    Foswiki::Func::writeDebug("- ${pluginName}::commonTagsHandler( $_[2].$_[1] )")
      if $Foswiki::cfg{Plugins}{$pluginName}{Debug};

    # Old syntax, using <easytimeline>.....</easytimeline>
    #$_[0] =~ s/<easytimeline>(.*?)<\/easytimeline>/&handleTimeline($1, $_[2], $_[1])/giseo;
    
    # New syntax, using %TIMELINE%.....%ENDTIMELINE%
    $_[0] =~ s/%TIMELINE%\s*(.*?)%ENDTIMELINE%/&handleTimeline($1, $_[2], $_[1])/egs;
}

# =========================
sub handleTimeline {
    
    my( $text, $web, $topic ) = @_;
    
    my $tmpDir  = Foswiki::Func::getWorkArea( $pluginName ) . '/tmp/' . $pluginName . "$$";
    my $tmpFile = $tmpDir . '/' . $pluginName . "$$";
    my %hashed_math_strings = ();

    # Create topic directory "pub/$web/$topic" if needed
    my $dir = Foswiki::Func::getPubDir() . "/$web/$topic";
    unless ( -e "$dir" ) {
        umask( oct(777) - $Foswiki::cfg{RCS}{dirPermission} );
        mkpath( $dir, 0, 0755 )
          or return
          "!$pluginName Error: *folder $dir could not be created*";
    }

    # compute the MD5 hash of this string
    my $hash_code = md5_hex("EASYTIMELINE$text");

    # store the string in a hash table, indexed by the MD5 hash
    $hashed_math_strings{"$hash_code"} = $text;

    my $image = "${dir}/graph${hash_code}.$png_or_gif";

    # don't do anything if it already exists
    if ( open TMP, '<', "$image" ) {
        writeDebug("Image $image already exists");
        close TMP;
    }
    else {

        # Create tmp dir
        unless ( -e "$tmpDir" ) {
            umask( oct(777) - $Foswiki::cfg{RCS}{dirPermission} );
            mkpath( $tmpDir, 0, 0755 )
              or return "!$pluginName Error: *tmp folder $tmpDir could not be created*";
        }

        # convert links
        $text =~ s/\[\[([$Foswiki::regex{mixedAlphaNum}\._\:\/-]*)\]\[([$Foswiki::regex{mixedAlphaNum} \/&\._-]*)\]\]/&renderLink($1, $2, $web, $topic)/egs;
        
        # output the timeline text into the tmp file
        open OUTFILE, '>', "$tmpFile.txt"
          or return "!$pluginName Error: could not create file";
        print OUTFILE $text;
        close OUTFILE;

        # run the command and create the image
        my $cmd =
            'perl ' .
            $Foswiki::cfg{Plugins}{$pluginName}{EasyTimelineScript} . # /var/www/html/foswiki/tools/EasyTimeline.pl
            ' -i %INFILE|F% -m -P ' .
            $Foswiki::cfg{Plugins}{$pluginName}{PloticusCmd} . # /usr/local/bin/pl
            ' -T %TMPDIR|F% -A ' .
            $Foswiki::cfg{ScriptUrlPath} . 'view' . $Foswiki::cfg{ScriptSuffix}; # /bin/view/
        writeDebug("Command: $cmd");
        my ( $output, $status ) = Foswiki::Sandbox->sysCommand(
            $cmd,
            INFILE => $tmpFile . '.txt',
            TMPDIR => $tmpDir,
        );
        writeDebug("$pluginName: output $output status $status");
        if ($status) {
            
            my @errLines;
            cleanTmp($tmpDir) unless $Foswiki::cfg{Plugins}{$pluginName}{Debug};
            
            return showError( $status, $output,
                $hashed_math_strings{"$hash_code"} );
        }
        if ( -e "$tmpFile.err" ) {

            # errors in rendering so remove created files
            open( ERRFILE, '<', "$tmpFile.err" );
            my @errLines = <ERRFILE>;
            close(ERRFILE);
            cleanTmp($tmpDir) unless $Foswiki::cfg{Plugins}{$pluginName}{Debug};
            return showError( $status, $output, join( "", @errLines ) );
        }

        # Attach created png file to topic, but hide it pr. default.
        my @stats;
        @stats = stat "$tmpFile.$png_or_gif";
        Foswiki::Func::saveAttachment(
            $web, $topic,
            "graph$hash_code.$png_or_gif",
            {
                file     => "$tmpFile.$png_or_gif",
                filesize => $stats[7],
                filedate => $stats[9],
                comment  => "!$pluginName: Timeline graphic",
                hide     => 1,
                dontlog  => 1
            }
        );

        if ( -e "$tmpFile.map" ) {

            # Attach created map file to topic, but hide it pr. default.
            @stats = stat "$tmpFile.map";
            Foswiki::Func::saveAttachment(
                $web, $topic,
                "graph$hash_code.map",
                {
                    file     => "$tmpFile.map",
                    filesize => $stats[7],
                    filedate => $stats[9],
                    comment  =>
                      "!$pluginName: Timeline clientside map file",
                    hide    => 1,
                    dontlog => 1
                }
            );

        }
        # Clean up temporary files
        cleanTmp($tmpDir) unless $Foswiki::cfg{Plugins}{$pluginName}{Debug};
    }

    if ( -e "${dir}/graph${hash_code}.map" ) {

        open( MAP, '<', "${dir}/graph${hash_code}.map" )
          || logWarning(
            "map ${dir}/graph${hash_code}.map exists but read failed");
        my $mapinfo = "";
        while (<MAP>) {
            $mapinfo .= $_;
        }
        close(MAP);
        $html = "<map name=\"${hash_code}\">$mapinfo</map>\n";
        $html .=
            "<img usemap=\"#${hash_code}\" src=\""
          . Foswiki::Func::getPubUrlPath()
          . "/$web/$topic/"
          . "graph${hash_code}.$png_or_gif\">\n";
    }
    else {
        $html =
            "<img src=\""
          . Foswiki::Func::getPubUrlPath()
          . "/$web/$topic/"
          . "graph${hash_code}.$png_or_gif\">\n";
    }
}

# converts Foswiki style links into absolute Mediawiki style links that work with the EasyTimelne.pl script
# SMELL: Why are $web and $topic not used?
sub renderLink {
    # [[$link][$title]]
    my ($link, $title, $web, $topic) = @_;
    
    if( $link =~ m!^http://! ){
        return "[[$link|$title]]"
    } else {
        my ( $linkedWeb, $linkedTopic ) = Foswiki::Func::normalizeWebTopicName( '', $link );
        my $url = Foswiki::Func::getScriptUrl( $linkedWeb, $linkedTopic, 'view' );
        return "[[$url|$title]]";
    }
}

# =========================
sub cleanTmp {
    my $dir = shift;

    my $untaint_dir = Foswiki::Sandbox::untaint( $dir, \&untaintPath );
    unless( $untaint_dir ){
        logWarning("Couldn't untaint $dir");
        return;
    }
    opendir( DIR, $untaint_dir );
    my @files = readdir(DIR);
    while ( my $file = pop @files ) {
        my $rmfile = Foswiki::Sandbox::untaint( "$untaint_dir/$file", \&untaintPath );
        unless( $rmfile ){
            logWarning("Couldn't untaint $file" );
            return;
        }
        
        if ( -f $rmfile ) {
            unlink($rmfile);
        }
    }
    close(DIR);
    rmdir($untaint_dir);
}

sub untaintPath {
    my $p = shift;
    if ( ( $p =~ /^([-\@\w\/~.:]+)$/ ) && ( $p !~ /^\./ ) ) {
        return $1;
    }
    return undef;
}

# =========================
sub showError {
    my ( $status, $output, $text ) = @_;

    $output =~ s/^.*: (.*)/$1/;
    my $line = 1;
    $text =~ s/\n/sprintf("\n%02d: ", $line++)/ges;
    $output .= "<pre>$text\n</pre>";
    return "<noautolink><span class='foswikiAlert'>!$pluginName Error ($status): $output</span></noautolink>";
}

sub writeDebug {
    Foswiki::Func::writeDebug( "$pluginName - " . $_[0] ) if $Foswiki::cfg{Plugins}{$pluginName}{Debug};
}

sub logWarning {
    Foswiki::Func::writeWarning(@_);
}

1;
