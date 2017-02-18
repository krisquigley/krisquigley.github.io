---
title: Using Docker For Development with Ruby on Rails
subtitle: A Three Part Series
intro: In the first part of this series, I am going to be talking about how to setup Docker for your development environment.  In part two, I shall be discussing how to prepare Docker for production and finally, part three will look at how to automate deployment.
date: 2017-01-22
tags: rails, ruby, docker, docker-compose
published: true
---
### Why use Docker? 
If you aren't entirely sure what Docker is exactly, or what benefit it can bring to your work flow.  Then I recommend that you read the article [8 Proven Real-World Ways to Use Docker](https://www.airpair.com/docker/posts/8-proven-real-world-ways-to-use-docker).

A lot of what I have learnt throughout my experience with Docker has been through the help of the online community, therefore it is only right that I also share the source of those articles and forums which can be found in the references section below.

### Docker Environment
First off, we need to install Docker before we can do anything.  In this article I will only be talking about the now recommended way of installing and running Docker, using Docker for X, *where X is the OS* rather than the old approach of using Docker toolbox.

Please note, if you are running Windows 10 Home, then you will need to be using Docker toolbox rather than Docker for Windows. As Docker for Windows relies on Hyper-V for virtualisation which only Windows 10 Pro provides.  If you can afford it, I recommend upgrading to the Pro version of Windows in this instance, as it is well worth it.

#### Docker for Windows / Mac / Linux
With that out of the way, head on over to [Docker](https://www.docker.com/products/docker) and download Docker for Windows / Mac / Linux.  In this instance, I shall be installing and running Docker for Windows, however, the contents of this document are the same regardless of which OS you are running (hence the beauty of Docker).

#### Dockerfile
Once you have Docker installed, you are ready to start integrating it into your project, or should I say, integrate your project into Docker...

Docker uses what it calls images; images are effectively snapshots of data, be they complete OS's in themselves, services or just files in their own right.  More often than not, images contain a guest OS with minimal libraries/packages installed (in order to keep the weight down) and a preconfigured service for you to use with other Docker images.

Most official images can be found on Docker's own service called [Docker Hub](https://hub.docker.com/explore/), which is akin to GitHub for Git.

Now, we can either use these images straight out of the box, making no changes to them in order to provide a service for us to interact with, e.g. Redis, Postgres or MongoDB; or we can use it as a base image to build upon.

We are going to do both, but firstly we are going to take an image as our base image, configure it and build our project into it.  This is where the Dockerfile comes into play.  The Dockerfile is where we define which base image we would like to use, what extra packages we might want to install; copy our project files into and then build it into its own bespoke image to later distribute, if we so wish.

### Development Dockerfile
As this is an article for a Dockerised Rails app, we will be using a Ruby base image to start with.  However, the standard Ruby image is rather bloated with many packages that aren't needed for more projects.  Therefore, we will be using the slim variant and installing any extra packages that we need.

Create the file, `Dockerfile` and save it to the root of your project.  The first line we are going to add will be the following:

`FROM ruby:2.4-slim`

This not only reduces bloat in our own Docker image, but saves local disk space and bandwidth.

Next we will install any additional packages we need for our project.  As my rails app makes use of Postgres as it's database, I will need to install the `libpq-dev` package in order to compile the postgres extensions needed by the `pg` gem.

```
RUN apt-get update && apt-get install -y build-essential git libpq-dev
```

The `RUN` command tells Docker that you want to run a command within the image.

After this, we will tell Docker which folder to mount our app in and copy the contents of our project across.

```
ENV app /app
RUN mkdir $app
WORKDIR $app
COPY . $app
```

Finally, we are going to set the `BUNDLE_PATH` to a custom location so that Bundler will install them in an external location.

`ENV BUNDLE_PATH /gems`

We do this as Docker images are stateless, and we do not want to be reinstalling our Gems every time we make some changes to our image.  Why do we point this to `/gems` and how does this become an external location you might ask.  More will be revealed in the next section on Docker Compose.

Your final `Dockerfile` should look like this:

```
FROM ruby:2.4-slim

# Install basic packages
RUN apt-get update && apt-get install -y build-essential git libpq-dev

ENV app /app
RUN mkdir $app
WORKDIR $app
ADD . $app

ENV BUNDLE_PATH /gems
```

### Docker Compose
Docker Compose is a service provided by Docker as part of the installation as a means of booting and managing multiple Docker images at the same time, all in one place.

#### Development docker-compose file
To configure Docker Compose we need to create a `docker-compose.yml` file within the root of our project directory.  As can be determined from the extension, the file makes use of YAML.

For the purpose of this article, we will be making use of version 2.1 of the Docker Compose syntax.  This should be defined at the top of the file.

`version: '2.1'`

After this, we can now start to define our services.  This is the section in which we list which images we are going to be using for the project.

`services:`

##### Ruby app
First lets define our Ruby app service.  We are naming the service `web` as it is our Rails app. Then we tell Docker to build the image from our root directory and save it as an image called `app`.  Docker compose will then make use of our `Dockerfile` that we defined earlier in order to build our `web` service.

```
  web:
    build: .
    image: app
```

Once the image has been built, we want to reuse it later for our Sidekiq instance, otherwise Docker will try to rebuild it again, which is just a waste of resources.

Next we are going to tell Docker what command to run once the image has been built and booted up.  In this instance, we want to install our gems and then boot up puma.

`command: bash -c "bundle install && bundle exec puma -p 3000 -C config/puma.rb"`

**Tip:** By using `bash -c` as the command, we can then pass more than one linux command to our service.

Thirdly, we need to let Docker know to mount the root directory of our app to the `/app` folder that we defined in the `Dockerfile` previously.  We are also going to define the `gem_cache` volume pointing to `/gems` that we talked about earlier in order to store our installed Gems into.  Then we need to map our Puma port `3000` to the outside world, in this case we will leave it as `3000` to keep things simple.

```
  volumes:
      - .:/app
      - gem_cache:/gems
    ports:
      - '3000:3000'
```

Now we need to define the environment variables needed for our app, in this instance Postgres and Redis.  

```
   environment: &default_environment
      DATABASE_URL: 'postgres://postgres:@postgres:5432'
      REDIS_URL: 'redis://redis:6379'
```

Docker provides us with some pretty cool features, like giving us unique schemas such as `postgres://` and `redis://` and then translates them to the proper URI needed for the service.

Finally, we let Docker know that we rely on a couple more services to boot up before we can boot our image, otherwise it will complain that such services do not exist.

```
    depends_on:
      - postgres
      - redis
```

Up to this point our `docker-compose.yml` should look like the following:

```
version: '2.1'

services:
  web:
    build: .
    image: app
    command: bash -c "bundle install && bundle exec puma -p 3000 -C config/puma.rb"
    volumes:
      - .:/app
      - gem_cache:/gems
    ports:
      - '3000:3000'
    environment: &default_environment
      DATABASE_URL: 'postgres://postgres:@postgres:5432'
      REDIS_URL: 'redis://redis:6379'
    depends_on:
      - postgres
      - redis
```
##### Sidekiq instance
As Sidekiq essentially requires the same environment as our web app, we will use the same settings as our we service, but with a few tweaks.

```
  expence_sidekiq:
    image: app
    command: bundle exec sidekiq -c 5 -q critical -q default
    volumes:
      - .:/app
      - gem_cache:/gems
    environment:
      <<: *default_environment
    depends_on:
      - postgres
      - redis
      - web
 ```

The only differences here is that we use the `app` image that we built previously, run a different command, inherit the environment variables we just defined and then also wait until our `web` service has been booted until we boot up Sidekiq.

##### Postgres
For Postgres, we are again going to use an official image from Docker Hub and then explicitly state which version we would like to use.  Finally, we are going to expose the default port in which it runs on, only internally this time as we do not want it to be exposed to the outside world.

```
  postgres:
    image: postgres:9.5
    ports:
      - '5432'
```

##### Redis
Redis is much the same again, exposing it's default port internally.

```
  redis:
    image: redis:3.2
    ports:
      - '6379'
```

##### Volumes
For storing our Gem files, we are going to use the volumes directive.  Volumes are defined at the root level of our `docker-compose` file.  Volumes, at the very least, allow us to define persistent storage locations so that we can access data again leter, even after our containers have been destoye. 

Here we are only going to be using it for our gems.  You might also add more volumes to store postgres and redis data for example.  We will do exactly that in part 2 of the series for our production environment.

```
volumes:
  gem_cache:
```

You should now have the following complete `docker-compose.yml` file in your root directory:

```
version: '2.1'

services:
  web:
    build: .
    image: app
    command: bash -c "bundle install && bundle exec puma -p 3000 -C config/puma.rb"
    volumes:
      - .:/app
      - gem_cache:/gems
    ports:
      - '3000:3000'
    environment: &default_environment
      DATABASE_URL: 'postgres://postgres:@postgres:5432'
      REDIS_URL: 'redis://redis:6379'
    depends_on:
      - postgres
      - redis

  sidekiq:
    image: app
    command: bundle exec sidekiq -c 5 -q critical -q default
    volumes:
      - .:/app
      - gem_cache:/gems
    environment:
      <<: *default_environment
    depends_on:
      - postgres
      - redis
      - web

  postgres:
    image: postgres:9.5
    ports:
      - '5432'

  redis:
    image: redis:3.2
    ports:
      - '6379'

volumes:
  gem_cache:
```

### Scripts
In order to make our lives a little easier, we are going to set up some scripts, rather than type out numerous commands each time we want to do something.

These will be Bash scripts and we can save them in our app directly under the folder `./bin/docker/` for clarity.

#### Boot
`./bin/docker/boot`

First of all, let's set up a boot script so that we can start our app quickly and easily.

```
#!/bin/bash
# spin up our image
docker-compose up --build
```

This tells `docker-compose` to boot up our images from our `docker-compose.yml` file.  However, we also need to pass the `--build` flag as our `app` image needs to be built first before we can spin it up.

Once the image is built and bundler has installed our Gems and booted up, Docker will then spin up Sidekiq, Redis and Postgres.

At this point, your app will now be available at `http://localhost:3000`.

However, as we are using Postgres as our DB, Rails is going to complain that the database does not exist.  So let's prep some more scripts to allow us to do so in a convenient fashion.

#### Docker
`./bin/docker/docker`

The rest of our scripts are going to rely on this `docker` script as an entry point into our `web` image so that we can run the commands necessary inside it.

```
#!/bin/bash
docker-compose run web $@
```

`$@` in this instance will pick up any arguments we pass to `./bin/docker/docker` and pass them through to `docker-compose` and to the `web` service.



#### Bundle
`./bin/docker/bundle`

Now that we have our `docker` script in place, we can reuse that whenever we need to run any additional commands.

```
#!/bin/bash
./bin/docker/docker bundle $@
```

#### Rake
`./bin/docker/rake`

Similarly, our `bundle` script can be reused for running any other commands through Bundler.

```
#!/bin/bash
./bin/docker/bundle exec rake $@
```

Now that we have `rake` in place, we can use this to create and migrate our database.

`./bin/docker/rake db:create`

You will probably find that Rails crashes after it has created the development database when trying to create the test db.  This can be safely ignored.  When you come to creating and migrating the test db, this can be done with the following:

`./bin/docker/rake db:create RAILS_ENV=test`

#### Console
`./bin/docker/console`

```
#!/bin/bash
./bin/docker/bundle exec rails console $@
```

#### Test
`./bin/docker/test`

```
#!/bin/bash
RAILS_ENV=test ./bin/docker/bundle exec rspec $@
```

You could use the same `bundle` pattern for writing any other scripts that you might need to use within your Docker instance, such as Rails itself for quickly generating migrations, etc.

### Docker Series
I hope you have enjoyed this simple article on the basics of using Docker for development.  If you find any errors / alternative approaches, then please let me know in the comments below.

This is just part one of my Docker series, I will be following this article up with how to use Docker in production and also how this process can be automated for quick deployments.

  - Using Docker for Development
  - Using Docker for Production
  - Docker Automation

### Rails 5 Caveats
If you are using Rails 5 then you might find that your code is not being reloaded after you save a file. This is due to how live reloading has changed and doesn't seem to work in Docker currently.

However, this can be changed to work in the way Rails 4 hot reloads by changing the `file-watcher` Class within your `development.rb` with the following:

`config.file_watcher = ActiveSupport::FileUpdateChecker`


### References
Below are some references which I have used in the past to build up my understanding of Docker and are great resources in themselves.

- [How to Cache Bundle Install with Docker](https://medium.com/@fbzga/how-to-cache-bundle-install-with-docker-7bed453a5800#.pla68urub)
- [Code is not reloaded in dev with Docker](https://github.com/rails/rails/issues/25186)