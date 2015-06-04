# p4kify
![Report screenshot](https://raw.github.com/chriskd/p4kify/master/images/report-screenshot.png)

Simple script that will email you a report with the days Pitchfork.com album reviews along with links to Spotify when available. Works best when thrown in cron, the only options that need to be specified are the to/from email addresses and the name that should be used in the greeting. 

## Usage

```
$ ruby p4kify.rb --help
Usage: p4kify.rb [OPTIONS]
    -t, --to-email [EMAIL]           The email address the report will be mailed to
    -f, --from-email [EMAIL]         The email address the report will be mailed from
    -n, --name [NAME]                The name used in the email's greeting
    -c, --config [CONFIG]            The path to your p4kify.conf file. Defaults to $HOME/.p4kify.conf
    -h, --help                       Displays this information, ya dingus
```

```
$ ruby p4kify.rb -t "your@emailaddress.com" -f "from@thisaddress.com" -n "Chris"
```
## p4kify.conf

You must specify your SMTP options in a config file before the script can send you emails. An example using gmail is below.

```
# SMTP Options
email_user_name: "yourgmailaddress@gmail.com"
email_password:  "thepassword"
smtp_server: "smtp.gmail.com"
smtp_port: 587
authentication: "plain"
starttls_auto: true

# Review filters
minimum_score = 0 # Only include reviews with scores that are equal to or greater than the specified score
```

You can specify another path for the config file using the `-c` flag. 

## TODO

There's not much to this silly little project, but I have some ideas on how it can be improved:

* Gemmify it
* Make use of config files rather than having to put config into the script
* Pull album art from Pitchfork instead of Spotify (that way it's always there, even if Spotify doesn't have the album)
* Allow user configerable filters (i.e., don't email any albums rated <> n, hide specific artists, pulling artist genre from last.fm and filtering based on approved genres, etc)
* Last.fm integration -- could be neat to highlight artists you've listened before via checking last.fm history
* Actual tests/exception handling
* Better Spotify integration. Why email? Should be able to create playlists in Spotify daily. Bonus points if a single playlist can be used/re-used every day (i.e, emptied and replenished with the newly reviewed albums)
