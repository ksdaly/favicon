Take a look at [live app](https://rocky-chamber-22761.herokuapp.com) on Heroku.

UI implementation notes:
* I used RoR form builder to build this as a quick prototype. For production version a single page React app would be a nicer experience to avoid rerendring the entire page on submit. Additinally, since the favicons are not user specific, they could be cached on the client to avoid database lookups.
* Only urls with http or https scheme are allowed. This is very restrictive, and is more of an example. More granular url validations can be added with either URI or Regexp. In case input is still invalid, or there is some issue with http request, an error will be returned.
* If host is present in the database, the persisted favicon_url will be used to display the favicon image. This is also the case when the host is persisted, but favicon_url is NULL. This reflects that the favicon has not been set for the host. 
* If host is persisted in the database and the favicon_url is invalid, the image displayed to the user will be broken. This should be handled with an option for refresh.
* Currently opts[:refresh] is set to false in favicons controller, but can be exposed in UI if needed. When opts[:refresh] is set to true, the favicon_url is fetched and database record is updated.
* If host is not present in the database, the favicon_url will be looked up, verified, and saved before being returned to the UI. 
* Favicon image is not persisted in the database, it is rendered in the browser every time it is requested. This is to ensure current image, as most hosts will have /favicon.ico path that would return the latest image. If snapshotting is required, favicon_snapshots table can be created with "favicon_url", "encoded_favicon_img" fields, and "site_id" foreign key.
* Index only scan is used for UI lookup to improve performanace. Caveat is that it returns only a subset of fields ("id", "host", "favicon_url").

Favicon URL import implementation notes:
* Duplicate host records are not allowed. There are both RoR validations and database constraints.
* There is an option for unverified url import. If opts[:naive] is set to true, favicon_url will not be verified, i.e., no http calls will be made to check wether it returns an image or redirects. Instead naive_favicon_url will be created and persisted by joining host with /favicon.ico path. This is fast, even despite using RoR model persistence which comes with large overhead. Importing 200,000 records will take about 11 min.However I do not recommend this approach as it returns about 15% failure rate when comparing with verified favicon_url import. Meaning that 1 in 8 records will have a favicon_url that is incorrect (it does not return the image). As a side note, in this scenario further improvements could be made to avoid RoR and database write overhewads. Writing data to a temp file first, and loading the file to the database would skip RoR model, as well as database overhead, but would require reindexing of the table. CSV data can also be processed in batches to generate large SQL insert queries for multiple records at the same time, and thus skip RoR model updates. In both cases this should only be done if input data is guaranteed to be correct, as model validations will not be performed.
* If opts[:naive] is not supplied, favicon_url will be looked up using one or more http requests. This operation varies a lot, generally taking 0.5s to 2.0s per record, but can be much longer, or time out entirely. Time outs and other errors are logged, and then skipped, but retry logic could be implemented. Importing 200,000 records would take about 16h. This is not necessary an issue if done asynchronously. For this purpose I set up sidekiq which creates multiple threads to process jobs simulteniously. When opts[:async] is set to true, batch_import will create records in Redis, which then will be picked up by sidekiq workers. A separate queue can be set up, so favicon import would not interfer with more time sensitive tasks, as well as additional servers could be added to have more workers to speed up the import. 
* Favicon is looked up using the following flow:
  * get /favicon.ico. If 200 code is returned (HTTParty follows redirects automatically), check content_type:
    * if content_type matches a type associated with favicons, assume we got a valid favicon_url and persist the url;
    * if content_type matches html, check for a tag associated with favicons, extract favicon_url, and persist the url;
    * if 200 code is not returned or favicon_url could not be extracted from html, attempt to get index url;
  * get index url. If 200 code is returned (HTTParty follows redirects automatically), check for a tag associated with favicons and extract favicon_url. If favicon_url can't be extracted, assume the host does not have a favicon. This does not currently yield 100% correct results, more debugging and spot checking is needed to ensure that all favicon implementations are captured.
* last_url is persisted, and reflects the correct scheme and host. This should be used for any future favicon_url if present to cut down on overhead related to redirects (not implemented).
* host normalized by stripping scheme and prefixes to avoid duplicate entries when persisting.
* Examples:
  * from /favicon.ico => https://www.google.com
  * from index url => https://www.qq.com/

General implementation notes:
* App is hosted on Heroku free tier and has only 10,000 row limit for database, so it has not been seeded.
  
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

Create databases and migrate
```
rake db:create
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


  
