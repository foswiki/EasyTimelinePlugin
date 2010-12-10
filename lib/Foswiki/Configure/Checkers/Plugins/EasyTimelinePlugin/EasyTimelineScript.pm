package Foswiki::Configure::Checkers::Plugins::EasyTimelinePlugin::EasyTimelineScript;

use warnings;
use strict;

use Foswiki::Configure::Checker ();
our @ISA = qw( Foswiki::Configure::Checker );

sub check {
    my $this = shift;

    my $cmd = $Foswiki::cfg{Plugins}{EasyTimelinePlugin}{EasyTimelineScript};
    $cmd =~ s/\$Foswiki::cfg{DataDir}/$Foswiki::cfg{DataDir}/
      ;    # by default, the command uses a path relative to the data directory

    if ($cmd) {
        if ( !-e $cmd ) {
            return $this->ERROR(<<'HERE');
This file does not exist. Have your entered the path correctly?
HERE
        }
        if ( !-x $cmd ) {
            return $this->ERROR(<<'HERE');
This command cannot be executed. Does the web server user have the required permissions?
HERE
        }
    }
}

1;
