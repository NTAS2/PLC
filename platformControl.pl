#!/usr/bin/perl
# The aim of the script is to Query the controller for experimental configuration; If an experimental configuration is found, it would execute else it would sleep for 60 seconds and query again. 

# Date 21 March 2012.
# Technically, this script forms a TCP Client to be hosted in the traffic generating machines (Laptops/Mobile Controller)
# This script is supposed to read an experimental configuration, and depending on the platform execute the Sikuli scripts at the locations.

# Define IP address and Port  and platform for host to connect to ; 

# send QUERy ( informhost,)
# wait for reply ()
# if msg is FETCH inform host CONFIG, wait for response, parse it REPORT SUCCESS OR FAILURE and resend QUERY
# if msg is REPEATQUERY Sleep for 120 seconds, resend request
#! usr/bin/perl
use IO::Socket;
use Sys::Hostname;
use Getopt::Long;
use Switch;
use Net::Syslog;
use MIME::Base64;
use POSIX;

$pidfile="/var/log/platformControl.pid";

$server_ipaddress = '194.47.151.87'; # Controller IP address Option 1
$server_port = 1579 ; # Server Option 2
$platform = 'ndef' ; # Platform, used for running the traffic generators ( Sikuli in mma) # Option2
$RETRIES=3; # Amout of retries.
$SLEEPTIME=30;

my $syslog=new Net::Syslog(Facility=>'user',Priority=>'debug',SyslogHost=>"$server_ipaddress");
print Timestamp() . " Syslog to $server_ipaddress.\n";
if ( -e $pidfile) { 
	#PID do exist..
	open(PID,"$pidfile");
	$timest=<PID>;
	close(PID);
	if( (time-$timest)>3600 ) {
		$syslog->send("pC.$platform Process ID file found, but not written for an hr.",Priority=>'info');
	} else {
		#OK
		print Timestamp() . " Process exist, check $pidfile ?\n";

		$syslog->send("pC.$platform Process already running.\n",Priority=>'info');
		exit(1);
	}
}
print Timestamp(). " STARTS.";
updatePID($pidfile);

$SIG{'INT'} = 'INT_handler';

my $host = hostname();



#Command line arguments can be a. Port b. Username  of Database c.Password of database; 
GetOptions ("port=i" => \$server_port,
	    "server_ipaddress=s" => \$server_ipaddress,
            "platform=s"  => \$platform,
	    "host=s" => \$host,
	);
print "host = $host \n";
switch ($host) {
	case 'Coms-MacBook-Pro.local' {$platform='Mac';$server_port=1579;}#1580
	case 'project-HP' {$platform='Windows';$server_port=1579;}#1581
	case 'ubuntu' {$platform='Linux';$server_port=1579;}
	case 'COM-PC' {
			#  Sikuli would check the visual signature of the device. program would continue to poll it, acquires experiment configuration. It then informs the server, which should check the todo_phone list and inform the guy that no platform is connected. 
			# What would happen to Client? Client would still be a client!
			$platform_verify = sprintf ("\"c:\\Program Files (x86)\\Sikuli X\\Sikuli-IDE.bat\" -r \"C:\\Users\\COM\\Documents\\Sikuli\\checkplatform.sikuli\" ");
			  $platform ="NOTRECOGNIZED";
			 open PS, "$platform_verify |" or print "Can't open STDOUT: $!";
			  while(my $myIn=<PS>){
					print $myIn;
				  if($myIn=~/IPhone/){
					  $platform = "IPhone";			
				  } 
				  if($myIn=~/WinMobile/){
					  $platform = "WinMobile";
				  }
				  if($myIn=~/Android/){
					  $platform = "Android";		
				  }
			  } 
			close PS;
			print "MobileControl, with $platform attached.\n";
			$server_port=1579;
		
			if($platform=~/ndef/){
				print "This platform requires knowledge about the PHONE connected.\n";
				print "Please use the argumment to control this.\n";
				exit(1);
			} 	
		}
	case 'CUSTOM' { print Timestamp(). "CUSTOM: $platform $host \n";$server_port=1579;}
	else 
		{ 
		    print Timestamp() . " No Host type specified, assumes that platform is detectable via name.\n";
		    $host = "CUSTOM";
		    $platform = hostname();
		    print Timestamp() . " Error when checking platform, unknown type $platform.\n";
		    ##exit(1);
		}
}
print Timestamp() . " Host=$host, Platform=$platform  \n";


$syslog->send('platformControl $platform booting',Priority=>'info');

print Timestamp(). " Syslog sent ($server_ipaddress)\n";	
print Timestamp(). " Will check for jobs on $server_ipaddress:$server_port, identified as $platform.\n";

for ($i = 0 ; $i > -1; $i++){ 
    print Timestamp() . " UpdatePID and sleep $SLEEPTIME \[s\].\n";
    updatePID($pidfile);
    sleep ($SLEEPTIME);
    print Timestamp() . " Sleept.\n";
    # Check for Mobile platform for every case if host is COM-PC
    if ($host =~ /COM-PC/) {
	$platform_verify = sprintf ("\"c:\\Program Files (x86)\\Sikuli X\\Sikuli-IDE.bat\" -r \"C:\\Users\\COM\\Documents\\Sikuli\\checkplatform.sikuli\" ");
	$platform ="NOTRECOGNIZED";
	open PS, "$platform_verify |" or print "Can't open STDOUT: $!";
	while(my $myIn=<PS>){
	    print $myIn;
	    if($myIn=~/IPhone/){
		$platform = "IPhone";			
	    } 
	    if($myIn=~/WinMobile/){
		$platform = "WinMobile";
	    }
	    if($myIn=~/Android/){
		$platform = "Android";		
	    }
	} 
	close PS;
	print "MobileControl, with $platform attached.\n";
	$server_port=1579;
    }
    # Initiate communication
    
    for(my $i=0;$i <= $RETRIES; $i++) {
#	print Timestamp() . "\tSetup socket ($i).\n";
	$socketreceiver = IO::Socket::INET->new(PeerAddr=>$server_ipaddress,PeerPort=>$server_port,Proto=>"tcp",Type=>SOCK_STREAM);
	if(!$socketreceiver){
	    $syslog->send("pC.$platform Could not connect to $server_ipaddress,$server_port, dies.",Priority=>'info');
	    printf Timestamp(). " Cannot connect to $server_ipaddress:$server_port :$!\n";
	    printf "\t\t\t Attempt $i/$RETRIES.\n";
	    sleep(30);
	} else {
	    printf Timestamp(). " Connected to $server_ipaddress:$server_port.\n";
	    last;
	}
    }
    
    
    # Inform server QUERY
    $exp_id = 0;
    $run_id = 0;
    print Timestamp() . " Sending message> QUERY.'$platform;QUERY'\n";
    print $socketreceiver "$platform;QUERY\n";
    $reply=<$socketreceiver>;
    print Timestamp() . " Recv. $reply";
    if( $reply !~/PROCEED/){
	$syslog->send("pC.$platform : No Job.",Priority=>'info');
	close($socketreceiver); 
	next;
    } 
    $syslog->send("pC.$platform: Got a Job.",Priority=>'info');
    informHost ($socketreceiver, "CONFIG");
    #wait for CONFIG and PARSE IT, EXECUTE IT ; report SUCCESS or FAILURE
    waitforconfig ($socketreceiver, "CONFIG",$server_ipaddress,$server_port,$platform);
    # wait for reply 
    if($socketreceiver!=0){
	print "Sending BYE!\n";
	informHost ($socketreceiver, "BYE");
	close($socketreceiver); 
    }
    $syslog->send("pC.$platform: Cycle complete, retarts after 20s",Priority=>'info');
    
    # if reply is NOINFORMATION  sleep (60) else execute a subroutine
    
}
$pidfile->remove;
exit(1);

# Sub_routines ( note the subroutine is slightly modified than original one)
sub informHost{
    my ($SAC,$message) = @_;
    print Timestamp() . " Sending...\n";
    print $SAC "$platform;$message\n";
    print Timestamp() . " Sent...\n";
}


sub waitforreply {
    my ($SAC,$str,$str2) = @_;
    print Timestamp() . " Am waiting.....for....$SAC.......to give me $str..............\n";
    $SAC->autoflush(1);
    
  line: while ($line = <$SAC>) {
      print " I got a msggggg ..:<br> $line </br>\n";
      # next unless /pig/;
      chomp($line);
      if ($line=~ /$str/) {
	  printf "Waiting 20s";
	  sleep (20);
	  print "$SAC $platform;QUERY\n";
	  print $SAC "$platform;QUERY\n" ;
	  waitforreply ($SAC,$str,$str2);
      }
      last line if ($line=~ /$str2/)
  }
    print "Hello World, My Wait for $SAC is over\n";
}

sub waitforconfig {
    my ($SAC,$str,$server_ipaddress,$server_port,$platform) = @_;
    print Timestamp() . " Waiting $SAC to give me $str.\n";
    $SAC->autoflush(1);
  line: while ($line = <$SAC>) {
      print Timestamp() . " ***********************************\n";
      print Timestamp() . "  I got a message ..:$line \n";
      print Timestamp() . "  it was " . length($line) . " chars long.\n";
      print Timestamp() . " ***********************************\n";
      # next unless /pig/;
      chomp($line);
      if ($line=~ /$str/) {
	  @args = split (/,/,$line);
	  $exp_id = $args[1];
	  $run_id = $args[2];
	  $key_id = $args[3];
	  $total_run_id = $args[4];
	  $application_command = decode_base64($args[5]); 
	  $temp = $application_command; 
	  #debug 
	  #print ("Application command is $application_command\n")	
	  #print ("obtained command is $args[5]\n");
	  $application_commandNew = eval('$application_command');
	  #system($application_command);
	  printf Timestamp() . "ApplicationLEn= " . length($application_command) . "\n";
	  printf Timestamp() . "CURRENT Line= $application_command\n";
	  printf Timestamp() . "NEW calling = $application_commandNew\n";
	  $ENV{EXPID} = $exp_id;
	  $ENV{RUNID} = $run_id;	
	  $ENV{KEYID} = $key_id;
	  if ($args[1] == 0) {
	      last line;  
	  }
	  print "Sending BYE!\n";
	  informHost ($SAC, "BYE");
	  close($SAC);
	  
	  if ( $application_command =~ /SIKULI/ )  {
	      @siks = split (' ', $application_command);
	      $sikuli_file_name = $siks[1]; 
	      #WINDOWS
	      if ($platform =~  /Windows/) {
		  $application_command = sprintf ("\"c:\\Program Files (x86)\\Sikuli X\\Sikuli-IDE.bat\" -r \"C:\\Users\\project\\Documents\\sikuli\\$sikuli_file_name\" --args ");
		  for ($i = 2 ; $i < @siks ; $i++) {
		      $t = $siks[$i];
		      $application_command = "$application_command"."$t ";
		  }
	      }
	      #MAC
	      if ($platform =~  /Mac/) {
		  $application_command = sprintf ("/Applications/Sikuli-IDE.app/sikuli-ide.sh -r /Users/com/Documents/sikuli/$sikuli_file_name --args ");
		  for ($i = 2 ; $i < @siks ; $i++) {
		      $t = $siks[$i];
		      $application_command = "$application_command"."$t ";
		  }
		  print "We are in $platform case\n";
		  print "$application_command"."\n";
	      }
	      #LINUX
	      if ($platform =~  /Linux/) {
		  $application_command = sprintf ("/home/com/Sikuli/Sikuli-IDE/sikuli-ide.sh -r /home/com/Sikuli_scripts/$sikuli_file_name --args ");
		  for ($i = 2 ; $i < @siks ; $i++) {
		      $t = $siks[$i];
		      $application_command = "$application_command"."$t ";
		  }
	      }
	      #Android
	      if ($platform =~  /Android/) {
		  $application_command = sprintf ("\"c:\\Program Files (x86)\\Sikuli X\\Sikuli-IDE.bat\" -r \"C:\\Users\\COM\\Documents\\Sikuli\\Android_$sikuli_file_name\" --args ");
		  for ($i = 2 ; $i < @siks ; $i++) {
		      $t = $siks[$i];
		      $application_command = "$application_command"."$t ";
		  }
	      }
	      #IPhone
	      if ($platform =~  /IPhone/) {
		  $application_command = sprintf ("\"c:\\Program Files (x86)\\Sikuli X\\Sikuli-IDE.bat\" -r \"C:\\Users\\COM\\Documents\\Sikuli\\IPhone_$sikuli_file_name\" --args ");
		  for ($i = 2 ; $i < @siks ; $i++) {
		      $t = $siks[$i];
		      $application_command = "$application_command"."$t ";
		  }
	      }	
	      
	      #WinMobile
	      if ($platform =~  /WinMobile/) {
		  $application_command = sprintf ("\"c:\\Program Files (x86)\\Sikuli X\\Sikuli-IDE.bat\" -r \"C:\\Users\\COM\\Documents\\Sikuli\\WinMobile_$sikuli_file_name\" --args ");
		  for ($i = 2 ; $i < @siks ; $i++) {
		      $t = $siks[$i];
		      $application_command = "$application_command"."$t ";
		  }
	      }	
	      
	  }
	  my $execstr = sprintf ("$application_command");
	  
	  print "\nToEXECUTE->$execstr|\n";
	  if ($platform =~  /Windows/){
	      print "(Window exec env)\n";
	      open PS, "$execstr |" or print "Can't open STDOUT: $!";
	  } elsif ($platform =~  /Android/) {
	      print "(Android exec env)\n";
	      open PS, "$execstr |" or print "Can't open STDOUT: $!";
	  } elsif ($platform =~  /IPhone/) { 
	      print "(IPhone exec env)\n";
	      open PS, "$execstr |" or print "Can't open STDOUT: $!";
	  } elsif ($platform =~  /WinMobile/) { 
	      print "(WinMobile exec env)\n";
	      open PS, "$execstr |" or print "Can't open STDOUT: $!";
	  } elsif (($platform =~  /Mac/) || ($platform =~  /Linux/) || ($platform =~ /ubuntu/)){
	      print "(MAC|LINUX|UBUNTU exec env)\n";
	      open PS, "$execstr 2>&1|" or print "Can't open STDOUT: $!";
	  } else {
	      print "(DEFAULT PS open)\n";
	      open PS, "$execstr 2>&1|" or print "Can't open STDOUT: $!";
	  }; 
	  my $response="CRAP";
	  my $bigSTDOUTlog="";
	  print "PARSING OUTPUT...\n\n\n\n";
	  my $lineCounter_temp=0;	
	  while(my $myIn=<PS>){
	      print "[$lineCounter_tmp] -- $myIn";
	      $bigSTDOUTlog.=$myIn;
	      if($myIn=~/SUCCESS/){
		  $response = "SUCCESS";
		  #	  last line;
		  print "YES!";
	      } #End of If
	      if($myIn=~/FAILURE/){
		  $response = "FAILURE";
		  #	  last line;
		  print "NO!!";
	      }
	      $lineCounter_tmp=$lineCounter_tmp+1; 
	  } #End of While
	  close PS;
	  print "END OF INPUT\n\n\n";
	  #Make sure that the environment does not retain a exp/run id.
	  $ENV{EXPID} = 0;
	  $ENV{RUNID} = 0;	
	  $ENV{KEYID} = 0;
	  print "$platform PCSENDERDONE\nToServer:$response\n";
	  $x = "";
	  @std = split (/\n/,$bigSTDOUTlog);
	  for ($i = 0 ; $i < @std ; $i++) {
	      $t = $std[$i];
	      $x = "$x"."GGGGGG$t ";
	  }
	  $xx =encode_base64($x,"");
	  $app = encode_base64($temp,""); 
	  $SAC = IO::Socket::INET->new(PeerAddr=>$server_ipaddress,PeerPort=>$server_port,Proto=>"tcp",Type=>SOCK_STREAM);
	  if(!$SAC){
	      $syslog->send("pC.$platform Could not connect to $server_ipaddress,$server_port, dies.",Priority=>'info');
	      print("Cannot connect to $server_ipaddress:$server_port :$@\n");
	      exit(1);
	  }
	  if ($response=~/CRAP/) {
	      print $SAC "$platform;*CRAP*:$exp_id:$run_id:$keyid:$total_run_id:$app:$xx\n";
	      print "*CRAP*:$exp_id:$run_id:$key_id$:$total_run_id:$application_command:$bigSTDOUTlog\n";	
	  } else {
	      print $SAC "$platform;$response:$exp_id:$run_id:$key_id:$total_run_id:$app:$xx\n";
	      print  "$response:$exp_id:$run_id:$key_id:$total_run_id:$application_command:$bigSTDOUTlog\n";
	  }
#	  my $host = hostname();
#	  my $fname="$host"."_Experiment.txt";
#	  print Timestamp() . "Log to $fname .\n";
	  #open FILE, ">> $fname" or die "cant work with $fname, get $! ";
	  #print FILE "$args[1]-$args[2]-$args[3]-$args[4]-$response-$bigSTDOUTlog Done \n";
	  #close FILE ;
	  
	  last line;
      }
  }
    print Timestamp() . "Done.\n";
}

sub Timestamp {
    #        my ($sec,$min, $hour, $mday, $mon,$year,$wday,$yday,$isdst);
    #        ($sec,$min, $hour, $mday, $mon,$year,$wday,$yday,$isdst)=localtime(time);
    #        $year+=1900;
    #        $mon+=1;
    return strftime("%Y-%m-%d %H:%M:%S ", gmtime time);
    #        return "$year $mon $mday $hour:$min:$sec ";
}


sub updatePID{
    open(PID,">$pidfile");
    print PID time()."\n";
    close(PID);
}

sub INT_handler {
    print "got SIGINT\n";
    $SAC = IO::Socket::INET->new(PeerAddr=>$server_ipaddress,PeerPort=>$server_port,Proto=>"tcp",Type=>SOCK_STREAM);
    
    if(!$SAC){
	$syslog->send("pC.$platform Could not connect to $server_ipaddress,$server_port, dies.",Priority=>'info');
	
	print("Cannot connect to $server_ipaddress:$server_port :$@\n");
	exit(1);
    }
    $response = "FAILURE";
    $xx = "MANUAL RESTART";
    print $SAC "$platform;$response:$exp_id:$run_id:$keyid:$total_run_id:$app:$xx\n";
    print  "$platform;$response:$exp_id:$run_id:$total_run_id:$app:$xx\n";
    print Timestamp() . "Interrupted, informed server. \n";
    exit (0);
}
