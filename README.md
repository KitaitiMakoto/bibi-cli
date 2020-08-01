# bibi publish

* [Homepage](https://rubygems.org/gems/bibi-publish)
* [Documentation](http://rubydoc.info/gems/bibi-publish/frames)
* [Email](mailto:KitaitiMakoto at gmail.com)

## Description

bibi publish a command line tool that uploads EPUB files to S3 and make them readable via web using [Bibi][], an EPUB reader application.

## Features

* Uploads files in EPUB document to Bibi's bookshelf directory on Amazon S3
* Generates HTML file to show given EPUB and uploads to S3

## Examples

    % bibi publish moby-dick.epub
    % bibi publish moby-dick.epub moby-dick-book
    % bibi publish --bibi=s3://yourbucket/subdir/bibi moby-dick.epub moby-dick-book

## Requirements

* AWS account
* Environment that is able to upload files to S3 bucket
* S3 bucket which you can access and is configuread for a static website hosting

## Install

    % gem install bibi-publish

## Synopsis

### Dry run

bibi publish supports `--dry-run` option that shows file to upload but doesn't do it actually.

    % bibi publish --bibi=s3://yourbucket/subdir/bibi path/to/moby-dick.epub moby-dick-book --dry-run

### Uploading to given bucket and path

    % bibi publish --bibi=s3://yourbucket/subdir/bibi path/to/moby-dick.epub

does:

* upload files in EPUB file `moby-dick.epub` to `s3://yourbucket/subdir/bibi-bookshelf/moby-dick`
* upload a HTML file to read the EPUB document using Bibi to `s3://yourbucket/subdir/bibi/moby-dick.html`

Note that:

* bookshelf directory `bibi-bookshelf` is automatically determined by bibi publish
* bookshelf subdirectory name `moby-dick` is automatically determined by bibi publish according to the basename of given EPUB file `moby-dick.epub`

### Specifying directory name under Bibi bookshelf

    % bibi publish --bibi=s3://yourbucket/subdir/bibi path/to/moby-dick.epub moby-dick-book

The second argument `page-blanch-book` is used for subdirectory and HTML file name on S3, which means it uses:

* `s3://yourbucket/subdir/bibi-bookshelf/moby-dick-book` instead of `s3://yourbucket/subdir/bibi-bookshelf/moby-dick`
* `s3://yourbucket/subdir/bibi/moby-dick-book.html` instead of `s3://yourbucket/subdir/bibi/moby-dick.html`

### Not generating HTML file

    % bibi publish --bibi=s3://yourbucket/subdir/bibi --no-page path/to/moby-dick.epub moby-dick-book

Pass `--no-page` option to the command.

Note that you read EPUB by visiting Bibi's usual URI `https://s3.your-region.amazonaws.com/yourbucket/subdir/bibi/?book=moby-dick-book`.

### Inserting arbitrary fragments to generated HTML

bibi publish inserts HTML fragments from given files to at the end of `<head>` and `<body>` by `--head-end` and `--body-end` options respectively.

Assume we want to insert generator name in head element of Bibi HTML:

    % cat ./generator.html
    <meta name="generator" content="bibi publish">

Specify path to the the file by `--head-end` option:

    % bibi publish --bibi=s3://yourbucket/subdir/bibi --head-end=./generator.html path/to/moby-dick.epub

Now the HTML fragment is inserted into HTML file:

    % curl -s https://s3.your-region.amazonaws.com/yourbucket/subdir/bibi/moby-dick.html | rg -B3 -A3 '</head>'
                <meta name="generator" content="bibi publish">
    
    
            </head>
    
    
            <body data-bibi-book="moby-dick">

`--body-end` option inserts HTML fragment in given file at just before `</body>` in HTML.

## Configuration

You can configure bibi publish by the file `~/.config/bibi/publish.toml` in [TOML][] format. This is especially useful for avoiding to specify options such as `--bibi` and `--bookshelf` each time.

Example is here:

~~~ toml
# `default` table is used by default
[default]
bibi = "s3://yourbucket/subdir/bibi"
bookshelf = "s3://yourbucket/epubs"
page = true
~~~

This is equivalent to pass command-line options `--bibi=s3://yourbucket/subdir/bibi`, `--bookshelf=s3://yourbucket/epubs` and `--page`.

If you want to switch set of configuration depending on situation, add another table and specify it by `--profile` option.

~~~ toml
[production]
bibi = "s3://your-production-bucket/bibi"

[staging]
bibi = "s3://your-staging-bucket/bibi"

~~~

    % bibi publish --profile=staging moby-dick.epub

Currently supported keys are `bibi`, `bookshelf`, `page`, `head_end` and `body_end`.

### AWS profile

Use environment variable `AWS_PROFILE`:

    % AWS_PROFILE=publicbibi bibi publish path/to/doc.epub

## See also

* [Bibi][] is an EPUB reader which runs in web browser with beautiful UI.

## Copyright

Copyright (c) 2020 Kitaiti Makoto

See {file:COPYING.txt} for details.

[Bibi]: https://github.com/satorumurmur/bibi
[TOML]: https://toml.io/
