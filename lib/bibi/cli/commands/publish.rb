require "bibi/cli/commands"
require "bibi/publish"

module Bibi::CLI::Commands
  class Publish < Dry::CLI::Command
    desc "Publish EPUB file"

    argument :epub, required: true, desc: "EPUB path"
    argument :name, required: false, desc: "directory name in Bibi bookshelf directory"

    option :bibi, desc: "URI of Bibi directory"
    option :bookshelf, desc: "URI of Bibi bookshelf. Defaults to {bibi}/../bibi-bookshelf"
    option :page, type: :boolean, default: true, desc: "Generates HTML page"
    option :head_end, desc: "path to HTML file to be inserted at the end of <head> in html. Effective when page switch is on"
    option :body_end, desc: "path to HTML file to be inserted at the end of <body> in html. Effective when page switch is on"
    option :dryrun, type: :boolean, default: false, desc: "Shows uploading file but doesn't upload actually"

    example [
      "--bibi=s3://mybucket/subdir/bibi path/to/doc.epub"
    ]

    def call(epub:, name: File.basename(epub, ".*"), page:, bibi: nil, bookshelf: nil,  head_end: nil, body_end: nil, **)
      Bibi::Publish.new(epub, name, bibi: bibi, bookshelf: bookshelf, page: page, head_end: head_end, body_end: body_end).run
    end
  end

  register "publish", Publish
end
