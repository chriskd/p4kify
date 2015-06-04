#!/usr/bin/env rvm ruby-2.1.2 do ruby

require 'open-uri'
require 'uri'
require 'nokogiri'
require 'json'
require 'mail'
require 'optparse'

options = {}
OptionParser.new do | opts |
	opts.banner = "Usage: p4kify.rb [options]"

	opts.on("-t", "--to-email [EMAIL]", "The email address the report will be mailed to") do |t|
		options[:to] = t
	end

	opts.on("-f", "--from-email [EMAIL]", "The email address the report will be mailed from") do |f|
		options[:from] = f
	end

	opts.on("-n", "--name [NAME]", "The name used in the email's greeting") do |n|
		options[:name] = n
	end

	opts.on_tail("-h", "--help", "Displays this information, ya dingus") do
		puts opts
		exit
	end
end.parse!

P4kAlbum = Struct.new(:artist, :album_name, :blurb, :review_url, :review_score, :best_new_music?, :spotify_url, :artwork_url, :on_spotify?)

def send_mail_via_gmail(to_addr, from_addr, msg_subject, msg_body)
	options = { 
							:address              => "smtp.gmail.com",
							:port                 => 587,
							:user_name            => '',
							:password             => '',
							:authentication       => 'plain',
							:enable_starttls_auto => true  
	}


	abort("Must enter your gmail username and password into the script before it will work. Aborting.") if options[:user_name].empty? && options[:password].empty?

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
	p4k.css('#review-day-1').css('.review-detail-info').map do |elem| 
		artist = elem.css('a h1').text.strip
		album = elem.css('a h2').text.strip
		blurb = elem.css('.content-container').text.strip
		review_url = "http://pitchfork.com#{elem.css('a')[0]['href'].strip}"
		review_page = Nokogiri::HTML(open(review_url))
		review_score = review_page.css('.score').text.strip
		best_new_music = review_page.css('.bnm-label').text.strip == "Best New Music" ? true : false
		P4kAlbum.new(artist, album, blurb, review_url, review_score, best_new_music)
	end
end

def crawl_spotify(todays_reviews)
	todays_reviews.map do |album|
		spotify_result_hash = JSON.parse(open("https://api.spotify.com/v1/search?q=album:#{URI.encode(album.album_name)}%20artist:#{URI.encode(album.artist)}&type=album&market=US").read)["albums"]["items"][0]
		if spotify_result_hash
			album.spotify_url = spotify_result_hash["external_urls"]["spotify"]
			album.artwork_url = spotify_result_hash["images"][1]["url"]
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
	acc += album.best_new_music? ? " <b style=\"color:red\">BEST NEW MUSIC</a><br>" : "<br>"
	acc += "<b>P4k Sez</b>: #{album.blurb}<br>"
	acc += "<b>Spotify URL</b>: #{album.on_spotify? ? album.spotify_url : 'Album not on Spotify :('}<br><br>"
  acc
end

msg = """<html><body>Good morning #{options[:name]},<br>
<br>
Here are today's latest Pitchfork reviews!<br>
<br>
#{review_text}
</body></html>"""

send_mail_via_gmail(options[:to], options[:from], "Today's Pitchfork Reviews", msg)
