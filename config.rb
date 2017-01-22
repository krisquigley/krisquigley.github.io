###
# Compass
###

activate :blog do |blog|
  # set options on blog
  blog.paginate = true
  blog.layout = "blog_layout"
  blog.taglink = "categories/{tag}.html"
end

activate :syntax

set :markdown_engine, :redcarpet
set :markdown, :fenced_code_blocks => true, :smartypants => true

# Change Compass configuration
compass_config do |config|
  config.output_style = :compact
end

# Reload the browser automatically whenever files change
configure :development do
  activate :livereload, host: '127.0.0.1', port: '8080'
end

set :css_dir, 'stylesheets'
set :js_dir, 'javascripts'
set :images_dir, 'images'

# Build-specific configuration
configure :build do
  # For example, change the Compass output style for deployment
  activate :minify_css

  # Minify Javascript on build
  activate :minify_javascript

  # Enable cache buster
  activate :asset_hash

  # Use relative URLs
  activate :relative_assets

end