require 'sinatra'
require 'json'

get '/' do
  content_type :json
  { version: 3, url: "http://localhost:8000/package.zip" }.to_json
end
