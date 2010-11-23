#!/usr/bin/perl
# Perl module used by the aggregator programs.

use warnings;
use strict;
use POSIX q{strftime};

sub logpng {
	my $log=shift;
	my $basename=shift;
	my $desc=$log->{description};
	$desc=~s/[^a-zA-Z0-9]//g;
	return "$basename.$desc.png";
}

sub aggregate {
	my $fh=shift;
	my $basename=shift;
	
	my $success=0;
	my $failed=0;
	my $total=0;
	my $old=0;
	
	open (STATS, ">>$basename.stats") || die "$basename.stats: $!";
	print STATS strftime("%m/%d/%Y %H:%M", gmtime);
	
	foreach my $log (@_) {
		my $onesuccess=0;
		my $onefailed=0;
		my $oneother=0;
		
		print $fh "<li><a href=\"".$log->{url}."\">".$log->{description}."</a><br>\n";
		if (length $log->{notes}) {
			print $fh "Notes: ".$log->{notes}."<br>\n";
		}
		my ($basebasename)=($basename)=~m/(?:.*\/)?(.*)/;
		print $fh "<img src=\"".logpng($log, $basebasename)."\" alt=\"graph\">\n";
		my $logurl=$log->{logurl}."overview".$log->{logext}."\n";
		if ($logurl=~m#.*://#) {
			if (! open (LOG, "wget --tries=3 --timeout=5 --quiet -O - $logurl |")) {
				print $fh "<b>wget error</b>\n";
			}
		}
		else {
			open (LOG, $logurl) || print $fh "<b>cannot open $logurl</b>\n";
		}
		my @lines=<LOG>;
		if (! close LOG) {
			print $fh "<b>failed</b> to download <a href=\"$logurl\">summary log</a>";
			print STATS "\t0";
			next;
		}
		if (! @lines) {
			print $fh "<b>empty</b> <a href=\"$logurl\">log</a>";
		}
		else {
			print $fh "<ul>\n";
		}
		foreach my $line (@lines) {
			chomp $line;
			my ($arch, $date, $builder, $ident, $status, $notes) = 
				$line =~ /^(.*?)\s+\((.*?)\)\s+(.*?)\s+(.*?)\s+(.*?)(?:\s+(.*))?$/;
			if (! defined $status) {
				print $fh "<li><b>unparsable</b> entry:</i> $line\n";
			}
			else {
				$date=~s/[^A-Za-z0-9: ]//g; # untrusted string
				my $shortdate=`TZ=GMT LANG=C date -d '$date' '+%b %d %H:%M'`;
				chomp $shortdate;
				if (! length $shortdate) {
					$shortdate=$date;
				}
				my $unixdate=`TZ=GMT LANG=C date -d '$date' '+%s'`;
				if (length $unixdate && 
				    (time - $unixdate) > ($log->{frequency}+1) * 60*60*24)  {
					$shortdate="<b>$shortdate</b>";
					$old++;
				}
				if ($status eq 'failed') {
					$status='<b>failed</b>';
					$failed++;
					$onefailed++;
				}
				elsif ($status eq 'success') {
					$success++;
					$onesuccess++;
				}
				else {
					$oneother++;
				}
				$total++;
				if (defined $notes && length $notes) {
					$notes="($notes)";
				}
				else {
					$notes="";
				}
				print $fh "<li>$arch $shortdate $builder <a href=\"".$log->{logurl}."$ident".$log->{logext}."\">$status</a> $ident $notes\n";
			}
		}
		print $fh "</ul>\n";
		print STATS "\t";
		if ($onesuccess+$onefailed+$oneother > 0) {
			print STATS ($onesuccess / ($onesuccess+$onefailed+$oneother) * 100);
		}
		else {
			print STATS 0;
		}
	}
	print STATS "\t";
	if ($success+$failed > 0) {
		print STATS $success / ($success+$failed) * 100;
	}
	else {
		print STATS 0;
	}
	print STATS "\n";
	close STATS;
	
	# plot the stats
	my $c=2;
	foreach my $log (@_) {
		my $png=logpng($log, $basename);
		open (GNUPLOT, "| gnuplot") || die "gnuplot: $!";
		print GNUPLOT qq{
			set timefmt "%m/%d/%Y %H:%M"
			set xdata time
			set format x "%m/%y"
			set yrange [-2 to 102]
			set terminal png size 640,128
			set output '$png'
			set key off
		};
		$c++;
		print GNUPLOT "plot '$basename.stats' using 1:$c title \"".$log->{description}."\" with lines";
		close GNUPLOT;
	}
	
	return ($total, $failed, $success, $old);
}

1