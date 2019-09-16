FROM ruby:2.4.2

RUN bundle config --global frozen 1

WORKDIR /usr/src/app

COPY demo demo
COPY lib lib

WORKDIR demo

RUN bundle install

ENV RACK_ENV=production

EXPOSE 4567

CMD ["ruby", "./app.rb"]
