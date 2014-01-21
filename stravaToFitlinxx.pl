#!/usr/bin/perl

## Get Data from Strava dump and write it to fitlinxx
##
## Jeremy Hubble 6/19/2013
##               1/19/2014
##
## Todo: Use Strava API (when available)
##       Support other types of workouts (not just biking)
##

use LWP;
use HTTP::Cookies;
use HTTP::Request::Common qw{ POST GET };
use Data::Dumper;
use LWP::DebugFile qw(+);
use LWP::Debug qw(+ conns);
my $debug = 0;

my ($userid,$password, $infile, $weight) = @ARGV ;

$weight = 170 unless ($weight);

if (!$infile) {
        die "USAGE: $0 userid password filename weight\n Where filename is a text file of tab delimited strava information (from activity detail)\nUserid and password are your fitlinxx logins. Weight is optional. If not present, will default to $weight\n";
}

print "\n\nREADING==============\n";
my @data = readStravaData($infile);
print "\n\nLOGGING IN==============\n";
my $ua = &loginToFitlinxx($userid, $password);
print "\n\nUPDATING==============\n";
for (my $i=0;$i<$#data; $i++) {
        logWorkout($ua,$data[$i]);
}
print "\n\nDONE==================\n";

exit;

sub logWorkout {
        my ($ua, $workout) = @_;

        print "WORKOUT:",Dumper($workout);

        my $url = "https://www.fitlinxx.com/workout/LogCardio2.asp";
        $request = POST( $url, $workout);
        $ua->prepare_request($request);
        $debug && print "REQ:".$request->as_string."\n\n";
        my $response = $ua->send_request($request);
        my $content = $response->as_string();
        $debug && print "RESULT:",$content,"\n";


}

sub loginToFitlinxx {

        ## Go through the whole login process
        ## Some might be skipped, but this makes sure we get all cookies
        my ($userid, $password) = @_;
        my $ua = LWP::UserAgent->new( );
        my $cookie_jar = HTTP::Cookies->new( );
        $ua->cookie_jar( $cookie_jar );

        ## Lets be firefox
        $ua->agent('Mozilla/5.0 (Windows NT 6.1; WOW64; rv:21.0) Gecko/20100101 Firefox/21.0');

        ## Main login page
        my $request = GET('https://flxpro.fitlinxx.com/Login.aspx');
        $ua->prepare_request($request);
        $response = $ua->send_request($request);

        ## extract some form variables
        my $content = $response->as_string;
        $content =~ m/name="__VIEWSTATE".*?value="(.*?)"/ms;
        my $viewstate = $1;

        $content =~ m/name="__EVENTVALIDATION".*?value="(.*?)"/ms;
        my $eventvalidation = $1;


        ## post form
        my $url = 'https://flxpro.fitlinxx.com/Login.aspx';
        my $params = [
                        'id_userpassword' => $password,
                        'id_username' => $userid,
                        '__VIEWSTATE' => $viewstate,
                        '__EVENTTARGET' => 'id_btnLogMeIn',
                        '__EVENTARGUMENT' => '',
                        '__EVENTVALIDATION' => $eventvalidation
        ] ;

        $debug && print "POSTING FORM DATA:",Dumper($params);
        $request = POST( $url, $params);
        $ua->prepare_request($request);

        ## Response should have redirect to a page that does the login
        my $response = $ua->send_request($request);
        my $content = $response->as_string();

        $debug && print "CONTENT FROM INITIAL LOGIN REQUEST:",$content,"\n";

        $content =~ m/Location:(.*$)/m;

        my $location = $1;
        $debug && print "Found Locaiton:",$location, "\n";

        ## If we have redirect, post that
        if ($location) {
                $debug && print "Redirecting...\n";
                my $response = $ua->get($location);
                my $content = $response->as_string();
                $debug && print "REDIRECTED PAGE CONTENT:$content\n";
        }

        ## if we don't have redirect we may be in trouble
        else {
                print STDERR "no login redirect, probably login error\n";
        }



        ## now we have all cookies set for valid logged in user agent
        ## we can go to other pages

        return $ua;
}






sub readStravaData {
        my @updates;
        my ($file) = @_;
        open FILE, $file or die "unable to open file: $file\n";

        my %dates;
        while (<FILE>) {
                chomp;
                my @stuff = split (/\t/,$_);
                next unless ($stuff[2] && $stuff[4] && $stuff[5]);
                $stuff[5] =~ s/ mi.*$//;
                my $climb = $stuff[6];
                $climb =~ s/ Ft//;
                my $dt = $stuff[2];
                my $dst = $stuff[5];
                my @time = split(/:/,$stuff[4]);
                my $tm = $time[0]*60*60 + $time[1]*60  + $time[2];

               $debug && print "$dt\t$tm\t$dst\n";


                if (exists $dates{$dt}) {
                        $dates{$dt}{'time'} += $tm;
                        $dates{$dt}{'distance'}  +=$dst;
                        $dates{$dt}{'climb'}  +=$climb;
                }
                else {
                        $dates{$dt}{'time'} = $tm;
                        $dates{$dt}{'distance'} = $dst;
                        $dates{$dt}{'climb'} = $climb;
                }
        }
        foreach my $k (keys %dates) {
                my $w = $dates{$k};
                print "$k\t".$dates{$k}{'time'}."\t".$dates{$k}{'distance'}."\t".$dates{$k}{'climb'};
                print "\t".$dates{$k}{'climb'}/$dates{$k}{'distance'};
                print "\n";

                push @updates,
                        &getUpdateRequest($k, $w->{'distance'}, $w->{'time'});
        }

        return @updates;

}







sub getUpdateRequest {
        my ($date, $distance, $time) = @_;

        print "DATE: $date, DIST: $distance, TIME: $time\n";


        my %formParams = (
                "Browser"        =>      "NS",
                "DupOverride"    =>      "",                    ##force even if dup
                "EnableFitTest"  =>      "False",
                "ExerByt"        =>      "6",                   ##exc cat (for calories)
                "ExerID"         =>      "28",                  ##exercise type
                "PlatForm"       =>      "PC",
                "RangeOverride"  =>      "",
                "averagehr"      =>      "0",
                "baseDistance"   =>      "$distance",           ## *distance (miles)
                "baseIntensity"  =>      "",                    ## intesity
                "baseMins"       =>      "",                    ## *minutes
                "baseSecs"       =>      "0",                   ## *seconds
                "baseTime"       =>      "$time",               ## *total time (in seconds)
                "bodyweight"     =>      "$weight",             ## weight (pounds)
                "calorieCalculation" =>  "on",
                "calorieOverride"=>      "",
                "calories"       =>      "",                    ## *colories (calculated)
                "cardiotype"     =>      "non-machine",
                "deleteit"       =>      "0",
                "displayDistance"=>      "$distance",           ## *disatnce
                "ewday"          =>      "",
                "ewmonth"        =>      "",
                "ewyear"         =>      "",
                "exer"           =>      "28",                  ## same as exerid
                "facilitybodyweight"  => "$weight",                     ## same as weight
                "journal"        =>      "Strava",              ## free text
                "ldap"           =>      "on",
                "logit"          =>      "1",
                "machinetag"     =>      "",
                "mode"           =>      "",
                "mydate"         =>      "$date",               ## *human date
                "peakhr"         =>      "0",
                "recoveryhr"     =>      "0",
                "saveit"         =>      "0",
                "selectedexername"=>     "Cycling Outdoors",    ## human name
                "sngEasy"        =>      "7",                   ## used for calorie calc
                "sngHard"        =>      "12.5",                ## ''
                "sngModerate"    =>      "10.5",                ## ''
                "timestamp"      =>      "",
                "wday"           =>      "",                    ## *day of month (1 based)
                "wmonth"         =>      "",                    ## *month of year (0 based)
                "wyear"          =>      ""                     ## *year
        );

        #$formParams{'baseTime'} = $time;

        my $sec = $time % 60;
        $formParams{'baseSecs'} = $sec;

        my $min = ($time - $sec ) /60;
        $formParams{'baseMins'} = $min;

        #$formParams{'mydate'} = $date;
        my (@darr) = split ('/',$date);
        $formParams{'wyear'} = $darr[2];
        $formParams{'wday'} = $darr[1];
        $formParams{'wmonth'} = $darr[0]-1;

        #$formParams{'displayDistance'} = $distance;
        #$formParams{'baseDistance'} = $distance;

        ## This is the formula for 'EASY' biking.
        ## It could be updated to use other ones based on itensity, speed, etc.
        ##
        $calories = ((($formParams{'bodyweight'}*.454) *
                        $formParams{'sngEasy'} *
                        3.5 ) /200 ) *
                        ($time/60);
        $formParams{'calories'} = sprintf("%.2f",$calories);

        $debug && print Dumper(\%formParams);
        return \%formParams;
}

