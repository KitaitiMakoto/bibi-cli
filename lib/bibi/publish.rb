require "dry/configurable"
require "xdg"
require "tomlrb"
require "uri"
require "epub/parser"
require "archive/zip"
require "aws-sdk-s3"
require "digest/md5"
require "base64"
require "erb"

module Bibi
  class Publish
    extend Dry::Configurable

    DEFAULT_MEDIA_TYPE = "application/octet-stream"

    setting(:bibi, default: nil) {|value| URI(value) if value}
    setting(:bookshelf, default: nil) {|value| URI(value) if value}
    setting :page, default: true
    setting :head_end
    setting :body_end
    setting(:endpoint, default: nil) {|value| URI(value) if value}

    def initialize(profile: :default, dry_run: false, **options)
      @profile = profile
      load_config
      update_config options
      @dry_run = dry_run

      $stderr.puts <<EOS
bibi: #{self.bibi}
bookshelf: #{self.bookshelf}
page: #{page?}
head_end: #{self.head_end}
body_end: #{self.body_end}
endpoint: #{endpoint}
EOS
    end

    def run(epub, name)
      @epub = EPUB::Parser.parse(epub)
      @name = name

      raise "bibi or bookshelf URI is required." if bibi.nil? && bookshelf.nil?
      raise "bibi URI is required when generating HTML" if page? && bibi.nil?

      if config[:endpoint]
        # `force_path_style` required to upload to MinIO server
        Aws.config.update endpoint: config[:endpoint], force_path_style: true
      end

      upload_contents
      upload_html if page?
    end

    private

    def config
      self.class.config
    end

    [:bibi, :head_end, :body_end, :endpoint].each do |name|
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

    def dry_run?
      !! @dry_run
    end

    def load_config
      XDG::Config.new.all.uniq.reverse_each do |config_path|
        path = File.join(config_path, "bibi", "publish.toml")
        next unless File.file? path
        c = Tomlrb.load_file(path, symbolize_keys: true)
        next unless c[@profile]
        $stderr.puts "Config loaded from #{path}"
        update_config(c[@profile])
      end
    end

    def update_config(c)
      %i[bibi bookshelf head_end body_end endpoint].each do |name|
        config[name] = c[name] unless c[name].nil?
      end
      config[:page] = c[:page] unless c[:page].nil?
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
      $stderr.puts "Uploading#{dry_run? ? " (dry run)" : ""} #{object.public_url}"
      object.put(body: content, content_type: type) unless dry_run?
    end
  end
end
