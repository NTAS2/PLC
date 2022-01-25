#!/usr/bin/perl
use IO::Socket;
use Sys::Hostname;
use Getopt::Long;
use Switch;
use POSIX qw(strftime);
use Config::Simple;

my $cfg=new Config::Simple('envStatus.conf');

my $server_ipaddress = $cfg->param('Server'); 
my $server_port = $cfg->param('Port'); 
my $repeat=$cfg->param('Repeat');
my $interval=$cfg->param('Interval');
my $formatting=$cfg->param('Format');

#Command line arguments can be a. Port b. Username  of Database c.Password of database; 
GetOptions ("port=i" => \$server_port,
	    "server_ipaddress=s" => \$server_ipaddress,
	);
my $host = hostname();
my $platform= $host;
print "Connecting to $server_ipaddress: $server_port ----- I'm $platform \n";


   
while(1){ 
    # Initiate communication
    $socketreceiver = IO::Socket::INET->new(PeerAddr=>$server_ipaddress,PeerPort=>$server_port,Proto=>"tcp",Type=>SOCK_STREAM) or die ("Cannot connect to $server_ipaddress:$server_port :$@\n");
    $status=getMyNetStatus($host);
    print strftime("%Y-%m-%d %H:%M:%S", localtime) ." NET " . substr($status,0,19) . "\n";
    informHost($socketreceiver,"NET","$status");
    close($socketreceiver); 
    $socketreceiver = IO::Socket::INET->new(PeerAddr=>$server_ipaddress,PeerPort=>$server_port,Proto=>"tcp",Type=>SOCK_STREAM) or die ("Cannot connect to $server_ipaddress:$server_port :$@\n");
    $status=getMyProcStatus($host);
    print strftime("%Y-%m-%d %H:%M:%S", localtime) ." PROC " . substr($status,0,19) . "\n";
    informHost($socketreceiver,"PROC","$status");
    close($socketreceiver);
    if ( $repeat =~ /True/i ) {
	print strftime("%Y-%m-%d %H:%M:%S", localtime) . " Repeating in $interval [s].\n";
	sleep($interval);
    } else {
	print strftime("%Y-%m-%d %H:%M:%S", localtime) . " One hit wonder.\n";
	last;
    }
}
    


#If I endup here, there are problems.
exit(0);


# Sub_routines ( note the subroutine is slightly modified than original one)
sub informHost{
    my ($SAC,$type,$message) = @_;
    print $SAC "$platform;$type;$message\n";
    print $SAC "<<END>>\n";
    
#    print "Sent: ";
#    if ( $formatting =~ /short/i ) {
#	print "(short) $platform;$type;" . substr($message,0,20);
#    } else {
#	print "(std) $platform;$type;$message";
#    }
#    print "<<END>>\n";
    
}

sub getMyNetStatus{
    my ($platform) = @_;
    
    my $tstatus=strftime "%Y-%m-%d %H:%M:%S", localtime;
    my $status;
    switch($platform){
	case 'Coms-MacBook-Pro.local' {
	    $status=`/sbin/ifconfig | grep -E 'ether|media|inet |status' `;
	}
	case /project-HP/ {
	    $status=`/cygdrive/c/Windows/System32/ipconfig.exe /all | grep -E 'IPv4|Media state|Gateway|Lease|Ethernet' | grep -v 'Bluetooth' `;
	    $status2=`/cygdrive/c/Windows/System32/wbem/wmic NIC where NetEnabled=true get Name, speed,adaptertype`;
	    $status="$status\r\nWMIC\r\n$status2";
	}
	case /ubuntu/ {
	    $status=`ifconfig | grep -E 'ether|media|inet |packet|Metric' `;
	    $status2=`sudo /sbin/mii-tool`;
	    $status="$status\r\n$status2";
	}
	case /COM-PC/ {
	    $status=`/cygdrive/c/Windows/System32/ipconfig.exe /all | grep -E 'IPv4|Media state|Gateway|Lease|Ethernet' | grep -v 'Bluetooth' `;
	}
	case /lin\d/ {
	    $status=`ifconfig | grep -E 'ether|media|inet |packet|Metric' `;
	    $status2=`sudo /sbin/mii-tool`;
	    $status="$status\r\n$status2";
	}
	case /con\d/ {
	    $status=`ifconfig | grep -E 'ether|media|inet |packet|Metric' `;
	    $status2=`sudo /sbin/mii-tool`;
	    $status="$status\r\n$status2";
	}
	case /tGW/ {
	    $status=`ifconfig | grep -E 'ether|media|inet |packet|Metric' `;
	    $status2=`sudo /sbin/mii-tool`;
	    $status="$status\r\n$status2";
	}
	case /xrk-desktop/ {
	    $status=`ifconfig | grep -E 'ether|media|inet |packet|Metric' `;
	    $status2=`sudo /sbin/mii-tool`;
	    $status="$status\r\n$status2";
	}
	case /helicon/i {
	    $status=`ifconfig | grep -E 'ether|media|inet |packet|Metric' `;
	    $status2=`ip link`;
	    $status="$status\r\n$status2";
	}
	else {
	    
	    print "else:$platform\n";
	    
	}
    }
    #print "NET status: $status\n";
    if(length($status)==0){
	print "status length = 0.\n";
	$status="$platform:Unknow platform. ERROR.\n";
    }
    return "$tstatus\n$status\n";
}

sub getMyProcStatus{
    my ($platform) = @_;
    
    my $tstatus=strftime "%Y-%m-%d %H:%M:%S", localtime;
    switch($platform){
	case 'Coms-MacBook-Pro.local' {
	    $status=`ps -afu com | grep -E -v '/System/|/usr/|/sbin/' 2>&1`;
	}
	case /project-HP/ {
	    $status=`ps -elfW | grep -E 'perl' `;
	}
	case /ubuntu/ {
	    $status=`ps -elf | grep -E -v '/System/|/usr/|/sbin/' `;
	}
	case /tGW/ {
	    $status=`ps -elf | grep -E capdump `;
	    $status2=`ps -elf | grep -E ConsumerControl `;
	    $status3=`ps -elf | grep -E EnvStatus `;
	    $status="$status\r\n$status2\r\n$status3";
	}
	case 'mma-sender' {
	    
	}
	case /lin/ {
	    $status=`ps -elf | grep -E capdump `;
	    $status2=`ps -elf | grep -E ConsumerControl `;
	    $status3=`ps -elf | grep -E EnvStatus `;
	    $status="$status\r\n$status2\r\n$status3";
	}
	case /con/ {
	    $status=`ps -elf | grep -E capdump `;
	    $status2=`ps -elf | grep -E ConsumerControl `;
	    $status3=`ps -elf | grep -E EnvStatus `;
	    $status="$status\r\n$status2\r\n$status3";
	}
	case /xrk-desktop/ {
	    $status=`ps -elf | grep -E -v '/System/|/usr/|/sbin/' `;
	}
	case /Helicon/i {
	    $status=`ps -elf | grep -E -v '/System/|/usr/|/sbin/' `;
	}
	
	else {
	    
	}
    }
    if(length($status)==0){
	$status="Unknow platform ,$platform, ERROR.\n";
    }
    return "$tstatus\n$status";
}
