Take a look at [live app](https://rocky-chamber-22761.herokuapp.com) on Heroku.

UI implementation notes:
* Only urls with http or https scheme are allowed. More granular url validations can be added with either using URI or Regexp. An error will be returned if the input is invalid or the server encountered an error while fetching the favicon.
* If URL host is present in the db, the persisted favicon_url will be used to display favicon. This is also the case when the host is persisted, but favicon_url is NULL. This reflects that the favicon has not been set for the host. opts[:refresh] is set to false in favicons controller, but can be exposed in UI if needed. When opts[:refresh] is set to true, the favicon_url is fetched and database record is updated.
* If URL host is not present in the db, the favicon_url will be looked up, verified, and saved before being returned to the UI. 
* Favicon image is not persisted in the db, it is rendered in the browser every time it is requested. This is to ensure current image, as most hosts will have /favicon.ico path that would return the latest image. If snapshotting is required, favicon_snapshots table can be created with "favicon_url", "encoded_favicon_img" fields, and "site_id" foreign key.
* Index only scan is used for UI lookup to improve performanace. Caveat is that it returns only a subset of fields ("id", "host", "favicon_url").

General implementation notes:
* Duplicate host records are not allowed.
* If opts[:naive] is set to true, favicon_url will not be verified, i.e., no http calls will be made to check wether it returns an image or redirects. Instead naive_favicon_url will be created and persisted by joining host with favicon.ico path. This is fast, even despite using RoR model persistence which gcomes with large overhead. Importing 200,000 records will take about 11 min. Nevertheless I do not recommend this approach as it returns about 15% discrepancy when comparing with verified favicon_url import, meaning that 1 in 8 records will have a favicon_url that is incorrect. As a side note, in this scenario further improvements can be made by writing data to a temp file first, and loading the file to the database. This would skip RoR model, as well as individual SQL query overhead, but would require reindexing of the table. CSV ata dcan also be processed in batches to generate a single SQL insert query for multiple records, and thus skipping RoR models. In bith casesthis should only be done if we are sure that the data we are working with is valid, as model validations will not be performed.
* If opts[:naive] is not supplied, favicon_url will be looked up using one or more http requests. This operation varies a lot, generally taking 0.5s to 2.0s per record, but can be much longer, or time out (time outs and other errors are logged, and then skipped). Importing 200,000 records would take about 16h. This is not necessary an issue if done asynchronously. For this purpose I set up sidekiq which creates multiple threads to process jobs simulteniously. When opts[:async] is set to true, batch_import will create records in Redis, which then will be picked up by sidekiq workers. A separate queue can be set up, so favicon import would not interfer with more time sensitive tasks, as well as additional servers could be added to have more workers to speed up the import. The following http request will be made:
  * get /favicon.ico. If 200 is returned (HTTParty follows redirects automatically), check content_type:
    * if content_type matches type associated with favicons, assume we got a valid favicon_url and return;
    * if content_type matches html, check for a tag associated with favicons, extract favicon_url, and return;
    * if 200 is not returned or favicon_url could not be extracted, attempt to get root url
  * get root url. If 200 is returned (HTTParty follows redirects automatically), check for a tag associated with favicons and extract favicon_url. If favicon_url can't be extracted, assume the host does not have a favicon.
* last_url is persisted, and reflects the correct scheme and host. This should be used for any future favicon_url if present to cut down on overhead related to redirects (not implemented).
* App is hosted on Heroku free tier and has only 10,000 row limit for database.
* There are no tests. Thus this is not production worthy, and needs adequate test coverage to be considered.
  
Dependencies: 
  * ruby 2.5.0
  * rvm
  * redis
  * postgresql
  
Clone repo
```
git clone git@github.com:ksdaly/favicon.git
```

cd into app
```
cd favicon
```

Install gems
```
bundle
```

Create databases
```
rake db:migrate
```

Start sidekiq if needed
```
bundle exec sidekiq
```

Run batch import in Rails console
```
# arg1: absolute filepath
# arg2: options hash
Site.batch_import("/Users/kdaly/Downloads/top-1m.csv", limit: 100, async: false, naive: false)
```


  
