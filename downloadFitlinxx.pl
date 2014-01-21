#!/usr/bin/perl

## Download all fitlinxx data
##
## Jeremy Hubble 1/19/2014
##
## Download all fitlinxx data to a text file

use LWP;
use HTTP::Cookies;
use HTTP::Request::Common qw{ POST GET };
use Data::Dumper;
use LWP::DebugFile qw(+);
use LWP::Debug qw(+ conns);

# set to debug to one to see detailed output
my $debug = 0;

# save a sample data file and run this to verify basic parsing
#use File::Slurp;
#my $text = read_file("pastSample2.txt");
#my @dates = parseStrength($text, 1);
#print @dates;
#exit;


my ($username,$password) = @ARGV ;


if (!$password) {
        die "USAGE: $0 userid password >output.txt\nDownloads all strength workout history from fitlinxx.\nUserid and password are your fitlinxx logins. Will right tab delimited output to output.txt\n";
}

print STDERR "\n\nLOGGING IN==============\n";
my $ua = &loginToFitlinxx($username, $password);
print STDERR "\n\nGETTING PAGE==============\n";
getStrength($ua);
print STDERR "\n\nDONE==================\n";

exit;


sub parseStrength {
        $debug && print "---parsing---\n";
        my ($html, $getDates) = @_;
        my $date;
        my @dates;
        while ($html =~ m/<OPTION value=([^\s>]+)(.)/g) {
                # It will have a space and then "selected" as a term after the value if it is the selected item
                my $dt = $1;
                my $opt = $2;
                $opt =~ s/\s+//g;
                $debug && print "DATE FOUND: $dt, operator: $opt\n";
                if (!$opt) {
                        ## This is the one that is selected
                        $date = $dt;
                }
                elsif ($getDates) {
                        push @dates, $dt;
                }

        }

        $dbeug && print "DATE:$date\n";
        $date =~ m~(\d*)/(\d*)/(\d*)~;
        my $cdate = $3."-".$1."-".$2;

        #while ( $html =~ m~<td class=content valign=top align=center>([^<]+)(.*?)~msg ) {
        while ( $html =~ m~<td class=content valign=top align=center>([^<]+).*?<table(.*?)</table>.*?<table(.*?)</table>~msg ) {
                my $title = $1;
                my $newbod = $2;
                my $form = $3;
                while (
                        #my ($set,$rep,$weight,$total) = $newbod =~ m~<tr><td class=content width=40 align=right bgcolor=#ffffff>\s*(\d*)</td><td class=content width=40 align=right bgcolor=#ffffff>\s*(\d*)</td><td class=content width=40 align=right bgcolor=#ffffff>\s*(\d*)</td><td class=content width=40 align=right bgcolor=#ffffff>\s*([\d,]*)</td></tr>~gc
                        $newbod =~ m~<tr><td class=content width=40 align=right bgcolor=#ffffff>\s*(\d*)</td><td class=content width=40 align=right bgcolor=#ffffff>\s*(\d*)</td><td class=content width=40 align=right bgcolor=#ffffff>\s*(\d*)</td><td class=content width=40 align=right bgcolor=#ffffff>\s*([\d,]*)</td></tr>~gc
                ) {
                        my $set = $1;
                        my $rep = $2;
                        my $weight = $3;
                        my $total = $4;
                        $total =~ s/,//g;

                        $form =~ m~<tr><td class=content width=40 align=right bgcolor=#ffffff>\s*(\d*)</td><td class=content width=40 align=right bgcolor=#ffffff>\s*(\d*)</td><td class=content width=40 align=right bgcolor=#ffffff>\s*(\d*)</td></tr>~gc;
                        my $formper = $1;
                        my $fast = $2;
                        my $bounce = $3;
                        print "$cdate\t$title\t$set\t$rep\t$weight\t$total\t$formper\t$fast\t$bounce\n";
                }
        }
        if ($getDates) {
                return @dates;
        }
}


sub getStrength {
        my ($ua) = @_;
        ## sum
        my $url = 'https://www.fitlinxx.com/workout/strength/strengthsummary.asp?when=life&m=143';

        ## detail
        my $url = 'https://www.fitlinxx.com/workout/strength/strengthdetail.asp?m=143';

        my $strengthResponse = $ua->get($url);
        my $strengthHTML = $strengthResponse->as_string();
        $debug && print "STRENGTH HTML:".$strengthHTML,"\n";
        print "DATE\tTITLE\tSET\tREPS\tWEIGHT\tTOTAL\t% GOOD FORM\tFAST\tBOUNCE\n";
        my @dates = parseStrength($strengthHTML,1);

        for (my $i=0;$i<=$#dates;$i++) {
                print STDERR "...",$dates[$i],"\n";
                $dates[$i] =~ s~/~%2F~g;
                #my $url = 'https://www.fitlinxx.com/workout/strength/strengthdetail.asp?start_date=08%2F28%2F2013';
                my $url = 'https://www.fitlinxx.com/workout/strength/strengthdetail.asp?start_date='.$dates[$i];
                $debug && print "Getting URL:$url\n";
                my $strengthResponse = $ua->get($url);
                my $strengthHTML = $strengthResponse->as_string();
                $debug && print "STRENGTH HTML:".$strengthHTML,"\n";
                parseStrength($strengthHTML,0);
        }
        ## specific date:

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



