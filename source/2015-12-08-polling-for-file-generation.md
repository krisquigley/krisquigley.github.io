---
title: Polling for File Generation
subtitle: ...from a worker
intro: I myself, often forget how to do all the Ajax trickery in Rails and Google isn't always the most helpful resource for me in this area.  Therefore, I thought I'd share my process with you and also leave a reminder for myself when I forget how to do it again.
date: 2015-12-08
tags: rails, ruby, background-worker
published: true
---

### Background of the Problem

![Image of Orders Table](images/orders.png)
*A list of orders*

We are currently generating a CSV of orders for a vendor; which at the moment isn't a big problem as we do not have many vendors, or many orders, so the CSV will generate relatively quickly.   

```ruby
class OrdersController < ApplicationController
  #...

  def download_csv
    orders = Order.where(id: order_ids)

    file = Tempfile.new

    CSV.open(file, "wb") do |csv|
      csv << ["Name", "Address", "City", "County", "Postcode", "Email"]
      orders.each do |order|
        csv << [order.name, order.address, order.city, order.county, order.postcode, order.email]
      end
    end

    send_file File.open(file.path)
  end
end
```

However, we know that suppliers and orders are bound to increase, therefore we need to find a better solution for generating files which will scale without blocking our precious ruby processes.

Obviously, this is where workers come in to do all the heavy lifting. By putting this work in a background process, we can free up our ruby processes again.

```ruby
class OrdersController < ApplicationController
  #...

  def download_csv
    GenerateCSVJob.perform_async(params[:order_ids])

    # Code to send file back to user
  end
end
```

However, how can I tell the controller that the file has finished being generated so that it can be sent back to the user?

### The Implementation

It's at this point that we need to do some polling, and the purpose of writing this article. 

Now that we have the controller calling the worker to generate the file we need a way of tracking the file generated.  As we are not using a model for this we don't have any handy IDs to keep track, this is where I like to use timestamps instead.

```ruby
require 'csv'

class GenerateCSVJob
  include Sidekiq::Worker

  def perform(timestamp, order_ids)
    orders = Order.where(id: order_ids)

    file = Tempfile.new(timestamp.to_s)

    CSV.open(file, "wb") do |csv|
      csv << ["Name", "Address", "City", "County", "Postcode", "Email"]
      orders.each do |order|
        csv << [order.name, order.address, order.city, order.county, order.postcode, order.email]
      end
    end

    File.rename(file.path, "/tmp/#{timestamp}_order.csv")
  end
end
```

Now that we have a unique way of identifying the file we have just generated, we have a clear way of identifying the file, in order to pass it back to the user.

```ruby
class OrdersController < ApplicationController
  #...

  def download_csv
    timestamp = Time.zone.now.to_i.to_s
    
    GenerateCSVJob.perform_async(timestamp, params[:order_ids])

    send_file File.open("/tmp/#{timestamp}_order.csv")
  end
end
```

However, it is much cleaner if we just send back the entire URL for them to poll instead.  At this point, that I want to clean up the `OrdersController` and move the logic into it's own controller instead.

```ruby
class CSVExportsController < ApplicationController
  def create
    timestamp = Time.zone.now.to_i.to_s
    
    GenerateCSVJob.perform_async(timestamp, params[:order_ids])

    respond_to do |format|
      format.json { render json: { url: csv_export_path(timestamp) }, 
                           status: :ok }

    end
  end
end
```

Now we need to add an action to check whether the file exists yet or not, and if it does, then send it back to the user.

```ruby
class CSVExportsController < ApplicationController
  def create
    #...
  end

  def show
    timestamp = params[:id]
    if File.exist?("/tmp/#{timestamp}_order.csv") 
      send_file File.open("/tmp/#{timestamp}_order.csv") }
    else
      head :not_found
    end
  end
end
```

However, I prefer to send a link back to the user which they can then use to download the file whenever they want.

```ruby
class CSVExportsController < ApplicationController
  def create
    #...
  end

  def show
    timestamp = params[:id]
    if File.exist?("/tmp/#{timestamp}_order.csv") 
      respond_to do |format|
        format.csv { send_file File.open("/tmp/#{timestamp}_order.csv") }
        format.json do
          render json: { file: csv_export_path(timestamp, format: :csv)}
        end
      end
    else
      head :not_found
    end
  end
end
```

But of course, none of this will work without the Ajax to marry it all up.

```coffeescript
(($) ->
  $ ->
    # Provide some context to the user so they know what is happening after we submit the form
    $('button[data-behavior="generate_csv"]').click -> 
      $('button[data-behavior="generate_csv"]').hide()
      $('div[data-behavior="generating_csv"]').show()

    $('form[data-attribute="generate_csv_form"]').on 'ajax:success', (e, data, xhr) ->
      # Uncheck the checkboxes
      $('input:checkbox').removeAttr('checked')

      # This will be our URL to check if the file exists
      url = data.url
      
      # Set up our polling object
      poll = (url) ->
        $.ajax({
          type: "GET",
          dataType: 'json',
          url:  url,
          error: ->
            # If the file does not exist yet, try again
            setTimeout ( => poll(url) ), 5000
          success: (data, status, xhr) ->
            # Now that the file exists, populate the download link with the download URL and then show it
            $('div[data-behavior="generating_csv"]').hide()
            $('a[data-attribute="download_csv_link"]').attr("href", data.file)
            $('div[data-behavior="download_csv"]').show()
        })

      # Start polling csv_export_path to see if the file exists yet
      poll(url)
) jQuery
```

The great thing about sending a URL back rather than just the file, is that we can add other formats to the `respond_to` block, if we ever need to generate other types of files. For example a PDF of order labels for the supplier to print and stick on their orders.

```ruby
class FileExportsController < ApplicationController
  def create
    #...
  end

  def show
    timestamp = params[:id]
    file_type = params[:file_type] # CSV, PDF, etc
    if File.exist?("/tmp/#{timestamp}_order.#{file_type}") 
      respond_to do |format|
        format.send(file_type) { send_file File.open("/tmp/#{timestamp}_order.#{file_type}") }
        format.json do
          render json: { file: file_export_path(timestamp, format: file_type,
                                                           file_type: file_type)}
        end
      end
    else
      head :not_found
    end
  end
end
```
If you know of an alternative appraoch to achieving the same result, then please let me know in the comments below.

### Resources

An example project with all the relavent code can be found under my [github](https://github.com/krisquigley/poll-worker-for-changes) account.

