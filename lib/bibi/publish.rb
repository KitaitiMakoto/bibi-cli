require 'bibi/publish/version'
require "dry/configurable"
require "uri"
require "epub/parser"
require "archive/zip"
require "aws-sdk-s3"
require "digest/md5"
require "base64"
require "erb"

class Bibi::Publish
  extend Dry::Configurable

  DEFAULT_MEDIA_TYPE = "application/octet-stream"

  setting(:bibi, nil) {|value| URI(value) if value}
  setting(:bookshelf, nil) {|value| URI(value) if value}
  setting :page, true
  setting :head_end
  setting :body_end

  def initialize(epub_path, name)
    @epub = EPUB::Parser.parse(epub_path)
    @name = name

    raise "currently, bibi URI is required." unless bibi

    $stderr.puts <<EOS
bibi: #{self.bibi}
bookshelf: #{self.bookshelf}
page: #{page?}
head_end: #{self.head_end}
body_end: #{self.body_end}
EOS
  end

  def run
    upload_contents
    upload_html if page?
  end

  private

  def config
    self.class.config
  end

  [:bibi, :head_end, :body_end].each do |name|
    define_method name do
      config[name]
    end
  end

  def bookshelf
    return config.bookshelf if config.bookshelf
    return unless config.bibi
    config.bibi + "bibi-bookshelf"
  end

  def page?
    config.page
  end

  def upload_contents
    types = Hash.new {|hash, key| hash[key] = DEFAULT_MEDIA_TYPE}
    @epub.resources.each do |item|
      types[item.entry_name] = item.media_type
    end

    unless bookshelf.scheme == "s3"
      raise "Currently, only s3 scheme is supported for bookshelf."
    end
    bucket = Aws::S3::Resource.new.bucket(bookshelf.host)
    bookshelf_path = bookshelf.path[1..]

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
    head_end_fragment = File.read(head_end) if head_end
    body_end_fragment = File.read(body_end) if body_end
    content = erb.result_with_hash({name: @name, title: @epub.title, head_end: head_end_fragment, body_end: body_end_fragment})
    unless bibi.scheme == "s3"
      raise "Currently, only s3 scheme is supported for bookshelf."
    end
    bucket = Aws::S3::Resource.new.bucket(bibi.host)
    bibi_path = bibi.path[1..]
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
