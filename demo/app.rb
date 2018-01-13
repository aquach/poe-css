# frozen_string_literal: true

require 'haml'
require 'sinatra'
require 'sinatra/param'

require_relative '../lib/dependencies'

get '/compile' do
  param :input, String, required: true

  begin
    result = POECSS.compile(params[:input])
    content_type 'text/plain'
    body result
  rescue POECSS::ParseError
    status 400
  end
end

get '/' do
  haml :index
end
