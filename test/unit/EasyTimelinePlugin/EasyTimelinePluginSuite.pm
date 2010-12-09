package EasyTimelinePluginSuite;

use strict;

use Unit::TestSuite;
our @ISA = 'Unit::TestSuite';

sub name { 'EasyTimelinePluginSuite' }

sub include_tests { qw(EasyTimelinePluginTests) }

1;
