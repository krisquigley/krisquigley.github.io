---
title: Replacing the asset pipeline with Webpack 2 in Rails
subtitle: Why replace the asset pipeline?
intro: Don't get me wrong, I think the asset pipeline is great, it allows you to get a web app up and running in no time with zero configuration.  However, when you want to make the move away from coffeescript to using pure ES6 and other JS libraries such as React, things start to get a little more difficult.
date: 2017-02-17
tags: rails, ruby, webpack, asset pipeline, sprockets
published: true
---

Other than Rails devs, no one else uses sprockets as far as I'm aware, and so it is a very small ecosystem used by a small subset of devs.  Therefore, if we want to get these libraries working in Rails, then we either have to port them to sprockets and maintain them ourselves, or hope that someone else within the community will do it for us.

This is why, to me, it feels best if we can use a system which is more actively developed, supported and used by a larger group of users.  Thus, reducing the lead time for implementing the latest front-end libraries and technologies and having access to a greater pool of knowledge and skills.

With this in mind, our options end up being Gulp, Grunt or Webpack.

#### Why Webpack?

I have chosen Webpack for my future projects.  Why? Because it is currently becoming the biggest and most popular bundler for frontend assets.  Sorry I don't have any hard metrics for you right now, this is based on my feeling from how the frontend community is responding to it.

I didn't check comparison tables to see which was the best for my needs, rather, I prefer to go with the most popular approach within the community at any time, as there will be better support for the technology and will be more actively developed, this means using Webpack.

Additionally, this is what React use for the bootstrapping app [create-react-app](https://github.com/facebookincubator/create-react-app) and let's face it; React is awesome.

#### Rails 5.1

My decision was further supported by the news that Rails 5.1 will be shipping with both the asset pipeline and Webpack for managing assets.  Webpack (at the time of writing) will only be utilised for JS assets.

I, on the other hand, will be using Webpack for serving all assets in this article.

### Implementing Webpack

#### Preparing Rails

To begin with, we will need to disable the asset pipeline in Rails.

If you are starting a new project from scratch using `rails new` then you can pass the argument `--skip-sprockets` to disable the asset pipeline from the get go.

Otherwise, If you are migrating an existing app to Webpack then you will need to disable sprockets manually.

In your `application.rb` file you can disable it by commenting out the line `require "sprockets/railtie"`.  However, you might have the line `require "rails/all` instead, in that case you can replace that line with the following below:

```ruby
require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
# require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
# require "action_cable/engine"
# require "sprockets/railtie"
# require "rails/test_unit/railtie"
```

Be sure not to comment out any of the frameworks above which you actually need!

Now you will need to go through each of your environment files (production.rb, etc) to comment out any references to `assets` if there are any, additionally, comment out all lines in your `assets.rb` file.

Furthermore, you can now also rip out any gems you needed for assets from your `Gemfile`! (Be sure to write them down though so that you can replace them with the same NPM modules later.)

#### Using Yarn

Another hot tool within the JS community right now is Yarn.  Yarn is a replacement for NPM which offers faster installations and increased security. As of writing, Yarn is unable to do everything that NPM can currently do, but supports all the same packages.

If you are unsure whether or not Yarn does everything you need, then I recommend checking the [migration docs](https://yarnpkg.com/en/docs/migrating-from-npm).

For the purpose of this article, I will be installing packages using Yarn, but you can easily follow along if you prefer to use NPM instead.

#### Installing Webpack

With that out of the way, we can now begin to install Webpack.  First traverse to your project folder and run `yarn global add webpack`.  This will then add Webpack to our path so that we can run it anywhere. 

At the time of this article, the latest version of Webpack is `2.2.1` and so the configuration that follows will be relevant to that version of Webpack.  Many things have changed since v1.0 and may continue to change in the future.  So if you have come to this article from a time where v2.2.1 is considered very old, then your mileage may vary. 

Before we start installing a gazillion node modules, I would recommend adding `/node_modules` to your `.gitignore` at this point.

Now might also be a good time to add our future compiled assets to `.gitignore`, too.

```
/public/javascripts
/public/stylesheets
```

### Using Webpack in development

Webpack comes with a watch mode which will automatically recompile your assets if it detects a change in the filesystem by passing the flag `w`.  Therefore, in development we will be running Webpack as such: `webpack -w`

You could easily add this as another service in Foreman or in Docker, so that it is always running in the background when you boot up your app in development.

### Using Webpack to serve JS

Now comes the fun part, we are going to start configuring Webpack to serve our JS assets.

#### Replacing Coffeescript with ES6

First we are going to begin with transpiling all of our `.coffee` files into ES6.  For me, the biggest reason for us to be migrating from the asset pipeline to Webpack is so that we can drop coffeescript, which is pretty much obsolete now *trollface*, and start using the latest syntax and functions from ES6 and onwards without headaches. 

For this, I recommend using [Decaffeinate](http://decaffeinate-project.org/repl/) as a quick way of getting some ok-ish ES6 code which we can refactor later. 

#### Adding babel

Now that we have our ES6 code in place, we need to start configuring Webpack to transpile our ES6 into ES5 for full browser support.

Let's go ahead and add the packages we need for ES6 support.

`yarn add babel-core babel-loader babel-polyfill babel-preset-es2015 `

You might be wondering what the `babel-loader` package is all about, this will enable Webpack to transpile ES6 using babel.  I will go into this further, shortly.

Yarn will then go ahead and create us a `package.json` and `yarn.lock` file.  These are comparable to `Gemfile` and `Gemfile.lock` respectively.

Now we need to create the file `webpack.config.js` in the root of our project to configure Webpack to our needs.

First we are going to define some libraries that we will need throughout our config file:

```javascript
const path = require('path')
```

Then we are going to define where we want our compiled JS to be exported to:

```javascript
const jsOutputTemplate = 'javascripts/application.js'
```

Next comes all the juicy details which we will be defined within an object:

```javascript
module.exports = {
  // ... Juicy details
}
```

The first key will be our `context`, in which we tell Webpack where we want it to look when we are defining our `entry` points.  `entry` points are where Webpack will begin to read the assets that we want it to transpile.  In this case, I will be following the same directory structure that the asset pipeline uses for JS and CSS.  This is purely to stick to Rails conventions and to make life easier for current Rails developers:

```javascript
  context: path.join(__dirname, '/app/assets'),
  entry: {
    application: './javascripts/application.js'
  },
```

The next key is our output path, where we would like Webpack to save our assets to once they have been transpiled.  We will be referencing our previous `jsOutputTemplate` constant here.

```javascript
  output: {
    path: path.join(__dirname, '/public'),
    filename: jsOutputTemplate
  }
```

Finally, in the `module` key we are going to add another object with the key `loaders` in order to define which loaders we want to use.

```javascript
 module: {
    loaders: [{
      test: /\.js$/,
      exclude: /node_modules/,
      loader: 'babel-loader',
      query: {
        presets: ['es2015']
      }
    }]
  }
```

In this case, we are using the `babel-loader` to transpile any JS files from es2015, i.e. ES6.

Your `webpack.config.js` file should now look something like this:

```javascript
// Import external libraries
const path = require('path')

// Define our compiled asset files
const jsOutputTemplate = 'javascripts/application.js'

module.exports = {
  // Remove this if you are not using Docker
  watchOptions: {
    aggregateTimeout: 300,
    poll: 1000,
    ignored: /node_modules/
  },

  // Define our asset directory
  context: path.join(__dirname, '/app/assets'),

  // What js / CSS files should we read from and generate
  entry: {
    application: './javascripts/application.js'
  },

  // Define where to save assets to
  output: {
    path: path.join(__dirname, '/public'),
    filename: jsOutputTemplate
  },

  // Define how different file types should be transpiled
  module: {
    loaders: [{
      test: /\.js$/,
      exclude: /node_modules/,
      loader: 'babel-loader',
      query: {
        presets: ['es2015']
      }
    }]
  }
}
```

To test that everything is working correctly, make sure you have Webpack fired up with `webpack -w` and add the following HTML somewhere:

```html
<button data-behavior="alert">This is my button</button>
```

Then we are going to create a module to fire off an alert when the button has been clicked:

```javascript
export default (() => {
  let button = document.querySelector("button[data-behavior='alert']")
  button.addEventListener('click', showAlert)

  function showAlert () {
    alert('hi')
  }
})()
```

Save this under `/app/assets/javascripts/modules/alert.js`.

Then in our `application.js` file we can add the line:

```javascript
import './modules/alert'
```

Remember to remove anything else in your `application.js` file, or else you might get compilation errors from Webpack.

Importing files like this, also allows us to stick to the same conventions as we had with the asset pipeline.

Now when you boot up Rails you should get an alert pop up once you click on the button!

#### Using jQuery 

In order enable to jQuery support in Bootstrap, or if you are using some legacy jQuery plugins, then we need to define it as a global function within Webpack.

For this, we will need to use a plugin to assign the jQuery library to some global variables.  This will sit in a new key within our Webpack config module, aptly named `plugins`.  `plugins` is defined as an array and as this will be a custom plugin, we need to require the Webpack library.

Let's add this in now:

```javascript
const path = require('path')
const webpack = require("webpack");
```

Now, after the `module` key we are going to add `plugins` with our custom jQuery plugin:

```javascript
  plugins: [
    new webpack.ProvidePlugin({
      $: 'jquery',
      jQuery: 'jquery',
      'window.jQuery': 'jquery'
    })
  ]
```

Lastly, let's make sure we have jquery installed.

`yarn add jquery`

Your jQuery scripts should now work as expected.

**Another important point**

Should you wish to continue using UJS, then we will need to install the module and import it into our assets.

`yarn add jquery-ujs`

And then we can add the following line to our `application.js` file:

```javascript
import 'jquery-ujs'
```

#### Adding React

Now that we are running Webpack, it makes it very easy for us to start adding React components throughout the project, if this is something which you feel your project would benefit from of course.

Simply install React: `yarn add react react-dom babel-preset-react`

Then tell babel to transpile our React code by adding `react` as another preset:

```javascript
{
  test: /\.js$/,
  exclude: /node_modules/,
  loader: 'babel-loader',
  query: {
    presets: ['es2015', 'react']
  }
}
```

### Using Webpack to serve CSS

By default, Webpack compiles everything into JS, which may or may not be a good thing.  For us traditional asset pipeline devs, we might be like WTF, where did all of my CSS files just go?!

In this case, and the assumption for the rest of the article, we will need to tell Webpack to extract them out into their own files using a plugin.

For this plugin, `extract-text-webpack-plugin`, we will however need to define which version to use as the current 1.x stable branch does not support Webpack 2 (the release candidates also currently break `bootstrap-loader`):

`yarn add extract-text-webpack-plugin@v2.0.0-beta.5 css-loader sass-loader`

With that installed, we can now add the plugin to our config file:

```javascript
...
const ExtractTextPlugin = require("extract-text-webpack-plugin")
...
const cssOutputTemplate = 'stylesheets/application.css'

...

  plugins: [
	  new ExtractTextPlugin({ filename: cssOutputTemplate, allChunks: true }), // Define where to save the CSS file
    ...
  ]
```

We also need to define our CSS file in our entry points. 

```javascript
  entry: {
    application: ["./javascripts/application.js", "./stylesheets/application.sass"]
  },
```

In this example I will be using SASS, for which we will also need a loader in order to transpile our SASS into CSS.  If you are only using plain CSS however, then you will only need the `css-loader`.

`yarn add css-loader sass-loader node-sass`

Now let's add in our new loaders:

```javascript
   module: {
      loaders: [
      	...
        { test: /\.css$/, loaders: ExtractTextPlugin.extract('css-loader') },
        { test: /\.sass$/, loader: ExtractTextPlugin.extract(['css-loader', 'sass-loader']) }
      ]
   }
```

#### Bootstrap

Getting Bootstrap set up and working was quite a major undertaking, I have boiled down here, what took many hours of trial and error.  Hopefully this will save you a lot of time.

For this article, we will be using the `bootstrap-loader` package, so let's go ahead and install it, including it's dependencies:

`yarn add bootstrap-loader bootstrap-sass css-loader node-sass resolve-url-loader sass-loader style-loader url-loader imports-loader file-loader`

Next we need to update our entry point to use `bootstrap-loader`.

```javascript
  entry: {
    application: ['bootstrap-loader', './javascripts/application.js', './stylesheets/application.sass']
  },
```

#### Styles

Now we need to create a `.bootstraprc` file within the root directory of our project and populate it with the following:

```yaml
---
# Major version of Bootstrap: 3 or 4
bootstrapVersion: 3

# If Bootstrap version 3 is used - turn on/off custom icon font path
useCustomIconFontPath: false

# Webpack loaders, order matters
styleLoaders:
  - style-loader
  - css-loader
  - sass-loader

# Extract styles to stand-alone css file
extractStyles: true

# Usually this endpoint-file contains list of @imports of your application styles.
appStyles: ./app/assets/stylesheets/application.sass

### Bootstrap styles
styles:

  # Mixins
  mixins: true

  # Reset and dependencies
  normalize: true
  print: true
  glyphicons: true

  # Core CSS
  scaffolding: true
  type: true
  code: true
  grid: true
  tables: true
  forms: true
  buttons: true

  # Components
  component-animations: true
  dropdowns: true
  button-groups: true
  input-groups: true
  navs: true
  navbar: true
  breadcrumbs: true
  pagination: true
  pager: true
  labels: true
  badges: true
  jumbotron: true
  thumbnails: true
  alerts: true
  progress-bars: true
  media: true
  list-group: true
  panels: true
  wells: true
  responsive-embed: true
  close: true

  # Components w/ JavaScript
  modals: true
  tooltip: true
  popovers: true
  carousel: true

  # Utility classes
  utilities: true
  responsive-utilities: true

### Bootstrap scripts
scripts:
  transition: true
  alert: true
  button: true
  carousel: true
  collapse: true
  dropdown: true
  modal: true
  tooltip: true
  popover: true
  scrollspy: true
  tab: true
  affix: true
```

More options can be found on the [bootstrap-loader](https://github.com/shakacode/bootstrap-loader) project page.

#### Scripts

To enable the various Bootstrap scripts such as modal windows, etc we need to add another loader:

```javascript
{ test: /bootstrap-sass\/assets\/javascripts\//, loader: 'imports-loader?jQuery=jquery' },
```

#### Fonts

In order to render the Bootstrap font icons, we will need to add the following loaders:

```javascript
{ test: /\.(woff2?|svg)$/, loader: 'url-loader?limit=10000&name=/fonts/[name].[ext]' },
{ test: /\.(ttf|eot)$/, loader: 'file-loader?name=/fonts/[name].[ext]' },
```

At this point you should be all good to start using Bootstrap as usual.

### Using Webpack to serve Images

For images, we are going to keep things simple and not use the traditional Rails `/app/assets/images/` folder and just go right ahead and place our images directly into `/public/images` as that is where Rails expects to find them.

If you would like to stick to the old convention here, then we can simply update our Webpack config to copy the files across to the `public` folder.  Going down this route, also allows us to do some post-processing on the images as we copy them across. For this, I would recommend using [image-webpack-loader](https://github.com/tcoopman/image-webpack-loader)

### Using Webpack on Codeship

As we have ignored our compiled assets from being added to our git repo, we will need to configure Codeship to compile our assets before running the test suite.

Under 'Test' in 'Project Settings' we can add the following lines at the end of our 'Setup Commands':

```
nvm use 6.9.5
npm install
./node_modules/.bin/webpack --progress --colors
```

This will then compile our assets before running the test suite.

### Using Webpack in Production

For production we want to be able to uglify our assets in order to reduce file size, we can do that with Webpack by passing the flag `p`.  We will also want to fingerprint them for Rails and gzip them.

We can do this by first tracking if the flag `p` has been passed to Webpack to enable the aforementioned behaviour:

```javascript
// Capture production argument
const prod = process.argv.indexOf('-p') !== -1;
```

#### Fingerprinting assets for production

As Rails fingerprints assets to ensure that the browser re-downloads assets once they have been changed, we will also need to implement this into Webpack so that Rails can function as usual.

Now that we are checking for production mode, we can use this to determine the filename of our assets:

```javascript
// Define our compiled asset files
const jsOutputTemplate = prod ? 'javascripts/[name]-[hash].js' : 'javascripts/[name].js'
const cssOutputTemplate = prod ? 'stylesheets/[name]-[hash].css' : 'stylesheets/[name].css'
```

Now we need to generate a file containing our fingerprint in so that Rails can reference it later:

```javascript
// Import external libraries
const fs = require('fs')
...

  plugins: [
    ...,
	function () {
      // output the fingerprint
      this.plugin('done', function (stats) {
        let output = 'ASSET_FINGERPRINT = "' + stats.hash + '"'
        fs.writeFileSync('config/initializers/fingerprint.rb', output, 'utf8')
      })
    }
    ...
  ]
```

Let's set up a helper to read from either the fingerprinted asset or our development asset:

```ruby
module ApplicationHelper
  def fingerprinted_asset(name)
    Rails.env.production? ? "#{name}-#{ASSET_FINGERPRINT}" : name
  end
end
```

Finally, update our `application.html.erb` layout to use our newly created helper:

```erb
<%= stylesheet_link_tag    fingerprinted_asset('application'), media: 'all' %>
<%= javascript_include_tag fingerprinted_asset('application'), async: !Rails.env.development? %>
```

When Rails boots up it will then use this value to reference our asset files.

A big thanks goes out to [Samuel Mullen](http://pixelatedworks.com/articles/replacing-the-rails-asset-pipeline-with-webpack-and-yarn/) for the above fingerprinting approach.

#### Deploying to Heroku

Now that we have fingerprinting in place, it means that we can use our app in production.  However, there are still a couple of tweaks to be made in order to get it behaving nicely in Heroku.

First of which, we will need to tell Heroku to install our node modules and compile our assets before compiling our Rails app.  This requires us to install the [Nodejs buildpack](https://devcenter.heroku.com/articles/using-multiple-buildpacks-for-an-app) and place it above the Ruby buildpack in the list.

Make sure that the Nodejs buildpack is listed above the Ruby buildpack as we need Heroku to compile our assets and set the fingerprint before building our Ruby app.

Next we need to monkey patch `rake assets:precompile` and `rake assets:clean` as these are no longer needed.

Create the file `assets.rake` in your `/app/lib/tasks` directory and add the following:

```ruby
namespace :assets do
  task :precompile do
    puts "Skipping task as not needed."
  end

  task :clean do
    puts "Skipping task as not needed."
  end
end
```

Finally, we are going to add the following to our `packages.json` file after the `dependencies` key:

```javascript
{
    "dependencies": {
      ...
    },
    "scripts": {
        "heroku-postbuild": "webpack -p"
    }
}
```

Heroku will read this and run Webpack after installing all of our node packages.

#### Compressing assets

One very important point for optimising our web sites, is to gzip assets.  This can be achieved very easily in Webpack through the use of the `compression-webpack-plugin` ...plugin.

`yarn add compression-webpack-plugin`

Then we require the plugin and enable it for static assets if in production mode.

```javascript
const CompressionPlugin = require('compression-webpack-plugin') // Gzip assets

const compressFiles = prod ? [new CompressionPlugin({
  asset: '[path].gz[query]',
  algorithm: 'gzip',
  test: /\.js$|\.css$|\.html$/,
  threshold: 10240,
  minRatio: 0.8
})] : []
```

Finally, we append it to the end of our `plugins` array:

```javascript
  plugins: [
    ...
  ].concat(compressFiles)
```

### Article code

Whilst writing this article, I also built a Rails app to make sure that the code in each step worked correctly.  I have hosted it on github under [webpack-article](https://github.com/krisquigley/webpack-article), if you would like to refer to it.

Your final `webpack.config.js` should look like the [following](https://github.com/krisquigley/webpack-article/blob/master/webpack.config.js).

### Sources

A lot of this article would not have been possible if it were not for the following:

- Samuel Mullen - [Replacing the Rails Asset Pipeline with Webpack and Yarn](http://pixelatedworks.com/articles/replacing-the-rails-asset-pipeline-with-webpack-and-yarn/)

