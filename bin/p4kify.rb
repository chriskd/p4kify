require 'open-uri'
require 'uri'
require 'nokogiri'
require 'json'
require 'mail'
require 'optparse'
require 'yaml'

ARGV << '-h' if ARGV.empty?

OPTIONS = {}
OptionParser.new do | opts |
  opts.banner = "Usage: p4kify.rb [OPTIONS]"
	OPTIONS[:config] = YAML.load_file(ENV['HOME'] + "/.p4kify.conf")

  opts.on("-t", "--to-email [EMAIL]", "The email address the report will be mailed to (required)") do |t|
    OPTIONS[:to] = t
   end

  opts.on("-f", "--from-email [EMAIL]", "The email address the report will be mailed from (required)") do |f|
    OPTIONS[:from] = f
  end

  opts.on("-n", "--name [NAME]", "The name used in the email's greeting (required)") do |n|
    OPTIONS[:name] = n
  end

  opts.on("-c", "--config [CONFIG]", "The path to your p4kify.conf file. Defaults to $HOME/.p4kify.conf (optional)") do |c|
    OPTIONS[:config] = YAML.load_file(c)
  end

  opts.on_tail("-h", "--help", "Displays this information, ya dingus") do
    puts opts
    exit
  end
end.parse!

abort("Missing required arguments") if OPTIONS[:to].nil? || OPTIONS[:from].nil? || OPTIONS[:name].nil?

P4kAlbum = Struct.new(:artist, :album_name, :artwork_url, :blurb, :review_url, :review_score, :best_new_music?, :spotify_url, :on_spotify?)

def send_mail_via_gmail(to_addr, from_addr, msg_subject, msg_body)
  options = { 
    :address              => OPTIONS[:config]["smtp_server"],
    :port                 => OPTIONS[:config]["smtp_port"],
    :user_name            => OPTIONS[:config]["email_user_name"],
    :password             => OPTIONS[:config]["email_password"],
    :authentication       => OPTIONS[:config]["authentication"],
    :enable_starttls_auto => OPTIONS[:config]["starttls_auto"]
  }


  abort("Must enter your gmail username and password into the script before it will work. Aborting.") if options[:user_name].empty? && OPTIONS[:password].empty?

  Mail.defaults do
    delivery_method :smtp, options
  end

  Mail.deliver do
    to to_addr
    from from_addr
    subject msg_subject
    html_part do
      content_type 'text/html; charset=UTF-8'
      body msg_body
    end
  end
end

def crawl_p4k
  p4k = Nokogiri::HTML(open('http://pitchfork.com'))
  reviews = []
  p4k.css('#review-day-1').css('.review-detail-info').map do |elem| 
    artist = elem.css('a h1').text.strip
    album = elem.css('a h2').text.strip
    artwork_url = elem.parent.css('.review-cover a div')[0].attr('data-content').match(/src="(.*)"/)[1]
    blurb = elem.css('.content-container').text.strip
    review_url = "http://pitchfork.com#{elem.css('a')[0]['href'].strip}"
    review_page = Nokogiri::HTML(open(review_url))
    review_score = review_page.css('.score').text.strip
    minimum_score = OPTIONS[:config]["minimum_score"] ? OPTIONS[:config]["minimum_score"] : 0
    best_new_music = review_page.css('.bnm-label').text.strip == "Best New Music" ? true : false
    reviews << P4kAlbum.new(artist, album, artwork_url, blurb, review_url, review_score, best_new_music) if review_score.to_f >= minimum_score
  end

  reviews
end

def crawl_spotify(todays_reviews)
  todays_reviews.map do |album|
    spotify_result_hash = JSON.parse(open("https://api.spotify.com/v1/search?q=album:#{URI.encode(album.album_name)}%20artist:#{URI.encode(album.artist)}&type=album&market=US").read)["albums"]["items"][0]
    if spotify_result_hash
      album.spotify_url = spotify_result_hash["external_urls"]["spotify"]
      album[:on_spotify?] = true
    else
      album[:on_spotify?] = false
    end 

    album
  end
end

todays_album_reviews = crawl_spotify(crawl_p4k)

review_text = todays_album_reviews.reduce("") do |acc, album|
  acc += "<img src=\"#{album.artwork_url}\"><br>"
  acc += "<b>Artist</b>: #{album.artist}<br>"
  acc += "<b>Album</b>: <a href='#{album.review_url}'> #{album.album_name} </a><br>"
  acc += "<b>Score</b>: #{album.review_score}"
  acc += album['best_new_music?'] ? " <b style=\"color:red\">BEST NEW MUSIC</b><br>" : "<br>"
  acc += "<b>P4k Sez</b>: #{album.blurb}<br>"
  acc += "<b>Spotify URL</b>: #{album['on_spotify?'] ? album.spotify_url : 'Album not on Spotify :('}<br><br>"

  acc
end

msg = """<html><body>Good morning #{OPTIONS[:name]},<br>
<br>
Here are today's latest Pitchfork reviews!<br>
<br>
#{review_text}
</body></html>"""

send_mail_via_gmail(OPTIONS[:to], OPTIONS[:from], "Today's Pitchfork Reviews", msg)
