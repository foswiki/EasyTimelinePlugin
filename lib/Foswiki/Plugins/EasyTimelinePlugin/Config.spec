# ---+ Plugins
# ---++ EasyTimelinePlugin
# **COMMAND M**
# Path to Ploticus on your system
$Foswiki::cfg{Plugins}{EasyTimelinePlugin}{PloticusCmd} = '/usr/local/bin/pl';
# **COMMAND M**
# Path to the EasyTimeline.pl script (should be in your tools directory)
$Foswiki::cfg{Plugins}{EasyTimelinePlugin}{EasyTimelineScript} = '$Foswiki::cfg{DataDir}/../tools/EasyTimeline.pl';
# **BOOLEAN**
# Debug flag
$Foswiki::cfg{Plugins}{EasyTimelinePlugin}{Debug} = 0;

1;
