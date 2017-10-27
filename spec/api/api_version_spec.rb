require 'spec_helper'
require 'vcap/digester'

RSpec.describe 'Stable API warning system', api_version_check: true do
  API_FOLDER_CHECKSUM = '8df79d06bbf4fb29a323130ddc3aebc2457ea7d9'.freeze

  it 'tells the developer if the API specs change' do
    api_folder = File.expand_path('..', __FILE__)
    filenames = Dir.glob("#{api_folder}/**/*").reject { |filename| File.directory?(filename) || filename == __FILE__ || filename.include?('v3') }.sort

    all_file_checksum = filenames.each_with_object('') do |filename, memo|
      memo << Digester.new.digest_path(filename)
    end

    new_checksum = Digester.new.digest(all_file_checksum)

    expect(new_checksum).to eql(API_FOLDER_CHECKSUM),
      <<~END
        You are about to make a change to the API!

        Stop for a moment and consider: do you really want to do it? If so, then update the checksum (see below) & CC version.

        expected:
            #{API_FOLDER_CHECKSUM}
        got:
            #{new_checksum}
    END
  end
end
