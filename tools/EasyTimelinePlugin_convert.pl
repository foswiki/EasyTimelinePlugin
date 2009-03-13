#usr/bin/perl -w

# copy this script into your data directory and it will loop through all topics and convert the old EasyTimelinePlugin syntax to the new Foswiki one
# While this worked for me, I can not guarentee it will work for you.
# Always test on a copy of your data first!

use File::Find::Rule;

my @subdirs = File::Find::Rule->directory->in( '.' );

foreach $dir (@subdirs){
	next if ($dir =~ m/^_|^\.|^Trash$/);
	# open dir, loop through files, open files with .txt$, search for syntax, output if found
	opendir( DIR, $dir) or die "can't opendir: $!";
	while( defined ( $filename = readdir ( DIR ) ) ) {
		if( $filename =~ /.*\.txt$/ ) {
			
			open INFILE, "<", "$dir/$filename" or print "$! $filename\n";
			my $file;
			while( <INFILE> ) {
				$file .= $_;
			}
			close INFILE;
            $file =~ s/<easytimeline>(.*?)<\/easytimeline>/%TIMELINE%\n$1%ENDTIMELINE%/mgos;
			open OUTFILE, ">", "$dir/$filename" or print "$! $filename\n";
			print OUTFILE $file;
			close OUTFILE;
		}
	}
}
