# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
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
# This plugin creates a png file by using the ploticus graph utility.
# See http://meta.wikimedia.org/wiki/EasyTimeline for more information.

package Foswiki::Plugins::EasyTimelinePlugin;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName $NO_PREFS_IN_TOPIC $SHORTDESCRIPTION
);

use Digest::MD5 qw( md5_hex );

#the MD5 and hash table are used to create a unique name for each timeline
use File::Path;

our $VERSION = '$Rev$';
our $RELEASE = '1.0';
our $SHORTDESCRIPTION = 'shot desc';
our $NO_PREFS_IN_TOPIC = 1;
our $pluginName = 'EasyTimelinePlugin';

my $HASH_CODE_LENGTH    = 32;
my %hashed_math_strings = ();

my $tmpDir  = '/tmp/' . $pluginName . "$$";
my $tmpFile = '/tmp/' . $pluginName . "$$" . '/' . $pluginName . "$$";

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }
    
    # need a path to script in tool directory
    unless( $Foswiki::cfg{Plugins}{$pluginName}{EasyTimelineScript} ){
        # throw error, do not init
        Foswiki::Func::writeWarning(
            "$pluginName cant find EasyTimeline.pl - Try running configure");
        return 0;
    }
    # need a path to Ploticus
    unless( $Foswiki::cfg{Plugins}{$pluginName}{PloticusCmd} ){
        # throw error, do not init
        Foswiki::Func::writeWarning(
            "$pluginName cant find Ploticus (pl) - Try running configure");
        return 0;
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
      if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # Pass everything within <easytimeline> tags to handleTimeline function
    $_[0] =~ s/<easytimeline>(.*?)<\/easytimeline>/&handleTimeline($1)/giseo;
}

# =========================
sub handleTimeline {

    # Create topic directory "pub/$web/$topic" if needed
    my $dir = Foswiki::Func::getPubDir() . "/$web/$topic";
    unless ( -e "$dir" ) {
        umask(002);
        mkpath( $dir, 0, 0755 )
          or return
          "<noc>EasyTimelinePlugin Error: *folder $dir could not be created*";
    }

    # compute the MD5 hash of this string
    my $hash_code = md5_hex("EASYTIMELINE$_[0]");

    # store the string in a hash table, indexed by the MD5 hash
    $hashed_math_strings{"$hash_code"} = $_[0];

    my $image = "${dir}/graph${hash_code}.png";

    # don't do anything if it already exists
    if ( open TMP, "$image" ) {
        close TMP;
    }
    else {

        # Create tmp dir
        unless ( -e "$tmpDir" ) {
            umask(002);
            mkpath( $tmpDir, 0, 0755 )
              or return "<noc>EasyTimelinePlugin Error: *tmp folder $tmpDir could not be created*";
        }

        # output the timeline text into the tmp file
        open OUTFILE, ">$tmpFile.txt"
          or return "<noc>EasyTimelinePlugin Error: could not create file";
        print OUTFILE $_[0];
        close OUTFILE;

        # run the command and create the png
        my $cmd =
            '/usr/bin/perl ' .
            $Foswiki::cfg{Plugins}{$pluginName}{EasyTimelineScript} . # /var/www/html/foswiki/tools/EasyTimeline.pl
            ' -i %INFILE|F% -m -P ' .
            $Foswiki::cfg{Plugins}{$pluginName}{PloticusCmd} . # /usr/local/bin/pl
            ' -T %TMPDIR|F% -A ' .
            $Foswiki::cfg{ScriptUrlPath} . 'view' . $Foswiki::cfg{ScriptSuffix} . # /bin/view/
            '/%WEB|F%';
        &writeDebug("Command: $cmd");
        my ( $output, $status ) = Foswiki::Sandbox->sysCommand(
            $cmd,
            INFILE => $tmpFile . '.txt',
            WEB    => $web,
            TMPDIR => $tmpDir,
        );
        &writeDebug("EasyTimelinePlugin: output $output status $status");
        if ($status) {
            
            my @errLines;
            cleanTmp($tmpDir) unless $debug;
            
            return Error( "Error when executing command. Maybe Ploticus is not installed? Status: $status; Output: $output; Text: <pre>" . $hashed_math_strings{$hash_code} . "</pre>" );
        }
        if ( -e "$tmpFile.err" ) {

            # errors in rendering so remove created files
            open( ERRFILE, "$tmpFile.err" );
            my @errLines = <ERRFILE>;
            close(ERRFILE);
            cleanTmp($tmpDir) unless $debug;
            return &showError( $status, $output, join( "", @errLines ) );
        }

        # Attach created png file to topic, but hide it pr. default.
        my @stats = stat "$tmpFile.png";
        Foswiki::Func::saveAttachment(
            $web, $topic,
            "graph$hash_code.png",
            {
                file     => "$tmpFile.png",
                filesize => $stats[7],
                filedate => $stats[9],
                comment  => '<nop>EasyTimelinePlugin: Timeline graphic',
                hide     => 1,
                dontlog  => 1
            }
        );

        if ( -e "$tmpFile.map" ) {

            # Attach created map file to topic, but hide it pr. default.
            my @stats = stat "$tmpFile.map";
            Foswiki::Func::saveAttachment(
                $web, $topic,
                "graph$hash_code.map",
                {
                    file     => "$tmpFile.map",
                    filesize => $stats[7],
                    filedate => $stats[9],
                    comment  =>
                      '<nop>EasyTimelinePlugin: Timeline clientside map file',
                    hide    => 1,
                    dontlog => 1
                }
            );

        }
        # Clean up temporary files
        cleanTmp($tmpDir) unless $debug;
    }

    if ( -e "${dir}/graph${hash_code}.map" ) {

        open( MAP, "${dir}/graph${hash_code}.map" )
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
          . "graph${hash_code}.png\">\n";
    }
    else {
        $html =
            "<img src=\""
          . Foswiki::Func::getPubUrlPath()
          . "/$web/$topic/"
          . "graph${hash_code}.png\">\n";
    }
}

# =========================
sub showError {
    my ( $status, $output, $text ) = @_;

    $output =~ s/^.*: (.*)/$1/;
    my $line = 1;
    $text =~ s/\n/sprintf("\n%02d: ", $line++)/ges;
    $output .= "<pre>$text\n</pre>";
    return "<noautolink><font color=\"red\"><nop>EasyTimelinePlugin Error ($status): $output</font></noautolink>";
}

sub Error {
    return "<noautolink><font color=\"red\"><nop>EasyTimelinePlugin Error: ".  shift . "</font></noautolink>";
}

sub writeDebug {
    &Foswiki::Func::writeDebug( "$pluginName - " . $_[0] ) if $Foswiki::cfg{Plugins}{$pluginName}{Debug};
}

sub cleanTmp {
    my $dir    = shift;
    my $rmfile = "";
    if ( $dir =~ /^([-\@\w\/.]+)$/ ) {
        $dir = $1;
    }
    else {
        die "Couldn't untaint $dir";
    }
    opendir( DIR, $dir );
    my @files = readdir(DIR);
    while ( my $file = pop @files ) {
        if ( "$dir/$file" =~ /^([-\@\w\/.]+)$/ ) {
            $rmfile = $1;
        }
        else {
            die "Couldn't untaint $rmfile";
        }
        if ( ( $file !~ /^\./ ) && ( -f "$rmfile" ) ) {
            unlink("$rmfile");
        }
    }
    close(DIR);
    rmdir("$dir");
}

sub logWarning {
    Foswiki::Func::writeWarning(@_);
}

1;
