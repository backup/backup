class Campfire
  include HTTParty

  headers 'Content-Type' => 'application/json'

  def self.room(room_id, subdomain, token)
    Room.new(room_id, subdomain, token)
  end

end

class Room
  attr_reader :room_id, :subdomain, :token

  def initialize(room_id, subdomain, token)
    @room_id = room_id
    @subdomain = subdomain
    @token = token
  end

  def message(message)
    send_message message
  end

  private

  def send_message(message, type = 'Textmessage')
    post 'speak', :body => {:message => {:body => message, :type => type}}.to_json
  end

  def post(action, options = {})
    Campfire.base_uri("https://#{subdomain}.campfirenow.com")
    Campfire.basic_auth(token, 'x')
    Campfire.post room_url_for(action), options
  end

  def room_url_for(action)
    "/room/#{room_id}/#{action}.json"
  end
end