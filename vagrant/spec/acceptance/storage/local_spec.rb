# encoding: utf-8

require File.expand_path('../../../spec_helper', __FILE__)

module Backup
describe Storage::Local do

  it 'cycles stored packages' do
    create_model :my_backup, <<-EOS
      Backup::Model.new(:my_backup, 'a description') do
        split_into_chunks_of 1 # 1MB

        archive :my_archive do |archive|
          archive.add '~/test_data'
        end

        store_with Local do |local|
          local.keep = 2
          local.path = '~/Storage'
        end
      end
    EOS

    job_a = backup_perform :my_backup
    expect( job_a.package.files.count ).to be(2)

    job_b = backup_perform :my_backup
    expect( job_b.package.files.count ).to be(2)
    expect( job_a.package.exist? ).to be_true

    job_c = backup_perform :my_backup
    expect( job_c.package.files.count ).to be(2)
    expect( job_b.package.exist? ).to be_true
    expect( job_a.package.removed? ).to be_true
  end
end
end
