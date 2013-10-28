# encoding: utf-8

require File.expand_path('../../spec_helper', __FILE__)

module Backup
describe Model do

  specify 'Models may be preconfigured' do
    create_config <<-EOS
      preconfigure 'MyModel' do
        archive :archive_a do |archive|
          archive.add '~/test_data/dir_a'
        end
        compress_with Gzip
      end
    EOS

    create_model :my_backup, <<-EOS
      MyModel.new(:my_backup, 'a description') do
        archive :archive_b do |archive|
          archive.add '~/test_data/dir_a'
        end
        store_with Local
      end
    EOS

    job = backup_perform :my_backup

    expect( job.package.exist? ).to be_true
    expect( job.package ).to match_manifest(%q[
      - my_backup/archives/archive_a.tar.gz
      - my_backup/archives/archive_b.tar.gz
    ])
  end

end
end
