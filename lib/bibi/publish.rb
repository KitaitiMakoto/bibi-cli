require 'bibi/publish/version'
require "uri"
require "epub/parser"
require "archive/zip"
require "aws-sdk-s3"
require "digest/md5"
require "base64"
require "erb"

class Bibi::Publish
  DEFAULT_MEDIA_TYPE = "application/octet-stream"

  def initialize(epub_path, name, bibi: nil, bookshelf: nil, page: true, head_end: nil, body_end: nil)
    @epub = EPUB::Parser.parse(epub_path)
    @name = name
    raise "currently, bibi URI is required." unless bibi
    @bibi = bibi
    @bookshelf = bookshelf || "#{bibi}-bookshelf"
    @page = page
    @head_end = File.read(head_end) if page && head_end
    @body_end = File.read(body_end) if page && body_end

    $stderr.puts <<EOS
bibi: #{@bibi}"
bookshelf: #{@bookshelf}
page: #{@page}
head_end: #{head_end}
body_end: #{body_end}
EOS
  end

  def run
    upload_contents
    upload_html if @page
  end

  private

  def upload_contents
    types = Hash.new {|hash, key| hash[key] = DEFAULT_MEDIA_TYPE}
    @epub.resources.each do |item|
      types[item.entry_name] = item.media_type
    end

    uri = URI.parse(@bookshelf)
    unless uri.scheme == "s3"
      raise "Currently, only s3 scheme is supported for bookshelf."
    end
    bucket = Aws::S3::Resource.new.bucket(uri.host)
    bookshelf_path = uri.path[1..]

    Archive::Zip.open @epub.epub_file do |archive|
      archive.each do |entry|
        next unless entry.file?
        path = entry.zip_path.force_encoding("UTF-8");
        type = types[path]
        key = [bookshelf_path, @name, path].join("/")
        content = entry.file_data.read
        upload_to_s3 bucket, key, content, type
      end
    end
  end

  def upload_html
    erb = ERB.new(html_template)
    content = erb.result_with_hash({name: @name, title: @epub.title, head_end: @head_end, body_end: @body_end})
    uri = URI.parse(@bibi)
    unless uri.scheme == "s3"
      raise "Currently, only s3 scheme is supported for bookshelf."
    end
    bucket = Aws::S3::Resource.new.bucket(uri.host)
    bibi_path = uri.path[1..]
    key = [bibi_path, "#{@name}.html"].join("/")
    upload_to_s3 bucket, key, content, "text/html"
  end

  def html_template
    template_path = File.join(__dir__, "publish/bibi.html.erb")
    File.read(template_path)
  end

  def upload_to_s3(bucket, key, content, type)
    object = bucket.object(key)
    etag = Digest::MD5.hexdigest(content)
    if object.exists? && object.etag == "\"#{etag}\"" # seriously?
      $stderr.puts "Skipping #{object.public_url}"
      return
    end
    $stderr.puts "Uploading #{object.public_url}"
    object.put(body: content, content_type: type)
  end
end
