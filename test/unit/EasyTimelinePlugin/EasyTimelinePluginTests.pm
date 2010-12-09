package EasyTimelinePluginTests;

use strict;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Foswiki::Func;
use Foswiki::Plugins::EasyTimelinePlugin;

use File::Temp qw/ tempdir /;

sub new {
    my $self = shift()->SUPER::new(@_);

}

sub loadExtraConfig {
    my $this = shift;
    $this->SUPER::loadExtraConfig();

    $Foswiki::cfg{Plugins}{EasyTimelinePlugin}{Enabled} = 1;
    $Foswiki::cfg{Plugins}{EasyTimelinePlugin}{EasyTimelineScript} =
      $ENV{FOSWIKI_HOME} . '/tools/EasyTimeline.pl';
    $Foswiki::cfg{Plugins}{EasyTimelinePlugin}{PloticusCmd} = $ENV{PLOTICUS}
      || '/usr/bin/pl';
    $Foswiki::cfg{Plugins}{EasyTimelinePlugin}{Debug} = 0;
}

# Set up the test fixture
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

sub test_timeline {
    my $this = shift;

#<<<  do not let perltidy touch this
    my $timeline = <<'HERE';
%TIMELINE%
ImageSize = width:270 height:300
PlotArea  = left:45 right:0 bottom:20 top:20
AlignBars = early

DateFormat = yyyy
Period     = from:1944 till:2005
TimeAxis   = orientation:vertical
ScaleMajor = unit:year increment:4 start:1944

Colors=
  id:1   value:rgb(1,0.4,0.2)
  id:2   value:rgb(0.8,0.6,0)
  id:3   value:rgb(1,0.8,0)
  id:4   value:rgb(1,0.6,0.2)
  id:5   value:rgb(0.6,0.2,0.2)

PlotData=
  bar:Leaders width:25 mark:(line,black) align:left fontsize:S shift:(25,-5) anchor:middle

  from:start till:1952 color:1  text:"1944-1952_Sveinn Bj�rnsson"
  from:1952  till:1968 color:2  text:"1952-1968_�sgeir �sgeirsson"
  from:1968  till:1980 color:3  text:"1968-1980_Kristj�n Eldj�rn"
  from:1980  till:1996 color:4  text:"1980-1996_Vigd�s Finnbogad�ttir"
  from:1996  till:end  color:5  text:"1996-_�lafur Ragnar Gr�msson"
%ENDTIMELINE%
HERE
#>>>
    my $got =
      Foswiki::Func::expandCommonVariables( $timeline, $this->{test_topic},
        $this->{test_web}, );
    my $expected =
      "<img src=\"/pub/$this->{test_web}/$this->{test_topic}/graph.*\.png\">";
    $this->assert_matches( $expected, $got );
}

sub test_untaintPath {
    my $this = shift;

    my $p = '/foo/bar/baz.png';
    $this->assert_equals( Foswiki::Plugins::EasyTimelinePlugin::untaintPath($p),
        $p, 'Unix like path' );
    $p = 'C:/PROGRA~1/bar/baz.png';
    $this->assert_equals( Foswiki::Plugins::EasyTimelinePlugin::untaintPath($p),
        $p, 'Windows like path' );
    $this->assert_null(
        Foswiki::Plugins::EasyTimelinePlugin::untaintPath('./rm -Rf *'),
        'Unix like bad path' );
    $this->assert_null(
        Foswiki::Plugins::EasyTimelinePlugin::untaintPath('/a/path;rm -Rf *'),
        'Unix like bad path 2' );
    $this->assert_null(
        Foswiki::Plugins::EasyTimelinePlugin::untaintPath(
            '/a/path && rm -Rf *'),
        'Unix like bad path 3'
    );
}

sub test_cleanTmp {
    my $this = shift;

    my $tmpdir = tempdir();
    $this->assert( -d $tmpdir, "tmp directory ($tmpdir) has been created" );
    Foswiki::Plugins::EasyTimelinePlugin::cleanTmp($tmpdir);
    $this->assert( !-d $tmpdir, "tmp directory ($tmpdir) has been removed" );
}

sub test_renderLink {
    my $this = shift;

    $this->assert_equals(
        Foswiki::Plugins::EasyTimelinePlugin::renderLink(
            'http://foswiki.org', 'Foswiki'
        ),
        '[[http://foswiki.org|Foswiki]]'
    );

    $this->assert_equals(
        Foswiki::Plugins::EasyTimelinePlugin::renderLink(
            "$this->{test_web}.$this->{test_topic}",
            'Test Link'
        ),
        '[['
          . Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
            'view' )
          . '|Test Link]]'
    );
}

1;
