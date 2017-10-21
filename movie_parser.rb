# Script will parse my goto movie website's page source and notify me about new movies.
# This runs as a cron on my t2.nano EC2 instance.
# TODO: Update this so as to return a JSON which my Google Home can process

require 'net/http'
require 'nokogiri'
require 'sendgrid-ruby'

notify = '<receiver_email>'
SENDGRID_API_TOKEN = "<SENDGRID_API_TOKEN>"

# set this hash to empty so that google doesn't index these URLs from github.
# Key should be the website name and value is the URL.
movie_urls = {

}

# Uses Send Grid to send emails
def send_email(message, receiver, subject, SENDGRID_API_TOKEN)
  include SendGrid

  from_email = 'movie-finder@nmattam.com'
  unless message.nil? && message.empty?
    from = Email.new(email: from_email)
    to = Email.new(email: receiver)
    content = Content.new(type: 'text/html', value: message)
    mail = Mail.new(from, subject, to, content)

    sg = SendGrid::API.new(api_key: SENDGRID_API_TOKEN)
    response = sg.client.mail._('send').post(request_body: mail.to_json)
  end
end

def find_movies(movie_urls, SENDGRID_API_TOKEN)
  movie_count = {}
  greeting_message = "Hello, <br><br>"
  final_greeting = "<br><br>Have fun!!"
  intro_message = "Enjoy: <br>"
  movie_list = ''
  subject = ''
  total_num_movies = 0

  movie_urls.each do |website, web_url|
    num_movies = 0

    latest_movies_file = "./latest_movies_#{website}.txt"
    latest_movie = ''

    escaped_address = URI.escape(web_url)
    uri = URI.parse(escaped_address)
    source = Net::HTTP.get(uri)

    movies = []
    # Find the last latest movies. This file will be my DB to save the latest found movie.
    latest_movie = File.read(latest_movies_file) if File.file?(latest_movies_file)

    #Assuming that the movies are listed inside the h2 tags. Suprisingly works for both the websites today.
    Nokogiri::HTML(source).css("h2").each do |span|
      movie_title = span.content.split('(').first.strip
      break if movie_title == latest_movie
      movies << movie_title
      num_movies = num_movies + 1
    end

    # Update the file with the latest file
    File.open(latest_movies_file, 'w') { |file| file.write(movies.first) } unless num_movies == 0

    if num_movies > 0
      movie_list = (movie_list || '') +'<br><br><u>'+ website +'</u>'
      movie_list += movies.map! { |movie| "<br><b>#{movie}</b>" }.join("")
      movie_count = { "#{website}" => "#{num_movies}" }.merge(movie_count)
      total_num_movies = total_num_movies + num_movies
    end
  end

  subject = "#{total_num_movies} new movies from #{movie_count.keys.join(", ")}"

  if total_num_movies == 0
    subject = "No new movies :-("
    movie_list = "Might be a good idea to check the websites <br><br> #{movie_urls.values.join('<br>')}."
  end
  message = intro_message + movie_list + final_greeting

  send_email(message, notify, subject, SENDGRID_API_TOKEN)
end

# Call find_movies
find_movies(movie_urls, notify, SENDGRID_API_TOKEN)
