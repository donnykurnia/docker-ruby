FROM donnykurnia/heroku-cedar-libicu:14
LABEL maintainer Terence Lee <terence@heroku.com>
LABEL maintainer Donny Kurnia <donnykurnia@gmail.com>

RUN mkdir -p /app/user
WORKDIR /app/user

ENV GEM_PATH /app/heroku/ruby/bundle/ruby/2.3.0
ENV GEM_HOME /app/heroku/ruby/bundle/ruby/2.3.0
RUN mkdir -p /app/heroku/ruby/bundle/ruby/2.3.0

# Install Ruby
RUN mkdir -p /app/heroku/ruby/ruby-2.3.4
RUN curl -s --retry 3 -L https://heroku-buildpack-ruby.s3.amazonaws.com/cedar-14/ruby-2.3.4.tgz | tar xz -C /app/heroku/ruby/ruby-2.3.4
ENV PATH /app/heroku/ruby/ruby-2.3.4/bin:$PATH

RUN mkdir -p /app/heroku/ruby/rubygems-2.6.14
RUN curl -s --retry 3 -L https://rubygems.org/rubygems/rubygems-2.6.14.tgz | tar xz -C /app/heroku/ruby/rubygems-2.6.14 && cd /app/heroku/ruby/rubygems-2.6.14/rubygems-2.6.14 && ruby setup.rb

# Install Node
RUN curl -s --retry 3 -L http://s3pository.heroku.com/node/v6.11.4/node-v6.11.4-linux-x64.tar.gz | tar xz -C /app/heroku/ruby/
RUN mv /app/heroku/ruby/node-v6.11.4-linux-x64 /app/heroku/ruby/node-6.11.4
ENV PATH /app/heroku/ruby/node-6.11.4/bin:$PATH

# Install Bundler
RUN gem install bundler -v 1.15.4 --no-ri --no-rdoc
ENV PATH /app/user/bin:/app/heroku/ruby/bundle/ruby/2.3.0/bin:$PATH
ENV BUNDLE_APP_CONFIG /app/heroku/ruby/.bundle/config
RUN bundle config disable_shared_gems true && \
    bundle config cache_all true

# Run bundler to cache dependencies
ONBUILD COPY ["Gemfile", "Gemfile.lock", "/app/user/"]
ONBUILD COPY ["vendor/cache", "/app/user/vendor/cache"]
ONBUILD RUN bundle install --path /app/heroku/ruby/bundle --jobs 4 --retry 5
ONBUILD ADD . /app/user

# How to conditionally `rake assets:precompile`?
ONBUILD ENV RAILS_ENV production
ONBUILD ENV SECRET_KEY_BASE $(openssl rand -base64 32)
ONBUILD RUN bundle exec rake assets:precompile

# export env vars during run time
RUN mkdir -p /app/.profile.d/
RUN echo "cd /app/user/" > /app/.profile.d/home.sh
ONBUILD RUN echo "export PATH=\"$PATH\" GEM_PATH=\"$GEM_PATH\" GEM_HOME=\"$GEM_HOME\" RAILS_ENV=\"\${RAILS_ENV:-$RAILS_ENV}\" SECRET_KEY_BASE=\"\${SECRET_KEY_BASE:-$SECRET_KEY_BASE}\" BUNDLE_APP_CONFIG=\"$BUNDLE_APP_CONFIG\"" > /app/.profile.d/ruby.sh

COPY ./init.sh /usr/bin/init.sh
RUN chmod +x /usr/bin/init.sh

ENTRYPOINT ["/usr/bin/init.sh"]
