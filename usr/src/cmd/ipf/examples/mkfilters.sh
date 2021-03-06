#!/bin/perl
# for best results, bring up all your interfaces before running this

if ($^O =~ m/^irix/i)
{
    &irix_mkfilters || regular_mkfilters || die $!;
}
else
{
    &regular_mkfilters || irix_mkfilters || die $!;
}

foreach $i (keys %ifaces) {
	$net{$i} = $inet{$i}."/".$netmask{$i} if (defined($inet{$i}));
}
#
# print out route suggestions
#
print "#\n";
print "# The following routes should be configured, if not already:\n";
print "#\n";
foreach $i (keys %ifaces) {
	next if (($i =~ /lo/) || !defined($net{$i}) || defined($ppp{$i}));
	print "# route add $inet{$i} localhost 0\n";
}
print "#\n";

#
# print out some generic filters which people should use somewhere near the top
#
print "block in log quick from any to any with ipopts\n";
print "block in log quick proto tcp from any to any with short\n";

$grpi = 0;

foreach $i (keys %ifaces) {
	if (!defined($inet{$i})) {
		next;
	}

	$grpi += 100;
	$grpo = $grpi + 50;

	if ($i !~ /lo/) {
		print "pass out on $i all head $grpo\n";
		print "block out from 127.0.0.0/8 to any group $grpo\n";
		print "block out from any to 127.0.0.0/8 group $grpo\n";
		print "block out from any to $inet{$i}/32 group $grpo\n";
		print "pass in on $i all head $grpi\n";
		print "block in from 127.0.0.0/8 to any group $grpi\n";
		print "block in from $inet{$i}/32 to any group $grpi\n";
		foreach $j (keys %ifaces) {
			if ($i ne $j && $j !~ /^lo/ && defined($net{$j})) {
				print "block in from $net{$j} to any group $grpi\n";
			}
		}
	}
}

sub irix_mkfilters
{
    open(NETSTAT, "/usr/etc/netstat -i|") || return 0;
    
    while (defined($line = <NETSTAT>))
    {
	if ($line =~ m/^Name/)
	{
	    next;
	}
	elsif ($line =~ m/^(\S+)/)
	{
	    open(I, "/usr/etc/ifconfig $1|") || return 0;
	    &scan_ifconfig;
	    close I;		# being neat... - Allen
	}
    }
    close NETSTAT;			# again, being neat... - Allen
    return 1;
}

sub regular_mkfilters
{
    open(I, "ifconfig -a|") || return 0;
    &scan_ifconfig;
    close I;			# being neat... - Allen
    return 1;
}

sub scan_ifconfig
{
    while (<I>) {
	chop;
	if (/^[a-zA-Z]+\d+:/) {
	    ($iface = $_) =~ s/^([a-zA-Z]+\d+).*/$1/;
	    $ifaces{$iface} = $iface;
	    next;
	}
	if (/inet/) {
	    if (/\-\-\>/) { # PPP, (SLIP?)
			($inet{$iface} = $_) =~ s/.*inet ([^ ]+) \-\-\> ([^ ]+).*/$1/;
			($ppp{$iface} = $_) =~ s/.*inet ([^ ]+) \-\-\> ([^ ]+).*/$2/;
		    } else {
			($inet{$iface} = $_) =~ s/.*inet ([^ ]+).*/$1/;
		    }
	}
	if (/netmask/) {
	    ($mask = $_) =~ s/.*netmask ([^ ]+).*/$1/;
		    $mask =~ s/^/0x/ if ($mask =~ /^[0-9a-f]*$/);
	    $netmask{$iface} = $mask;
	}
	if (/broadcast/) {
	    ($bcast{$iface} = $_) =~ s/.*broadcast ([^ ]+).*/$1/;
	}
    }
}
    
