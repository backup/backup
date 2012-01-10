# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe Backup::Configuration::Syncer::S3 do
  before do
    Backup::Configuration::Syncer::S3.defaults do |s3|
      s3.access_key_id       = 'my_access_key_id'
      s3.secret_access_key   = 'my_secret_access_key'
      s3.bucket              = 'my-bucket'
      s3.path                = '/backups/'
      #s3.directories         = 'cannot_have_a_default_value'
      s3.mirror              = true
      s3.additional_options  = ['--exclude="*.rb"']
    end
  end

  it 'should set the default s3 configuration' do
    s3 = Backup::Configuration::Syncer::S3
    s3.access_key_id.should       == 'my_access_key_id'
    s3.secret_access_key.should   == 'my_secret_access_key'
    s3.bucket.should              == 'my-bucket'
    s3.path.should                == '/backups/'
    s3.mirror.should              == true
    s3.additional_options.should  == ['--exclude="*.rb"']
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Syncer::S3.clear_defaults!

      s3 = Backup::Configuration::Syncer::S3
      s3.access_key_id.should       == nil
      s3.secret_access_key.should   == nil
      s3.bucket.should              == nil
      s3.path.should                == nil
      s3.mirror.should              == nil
      s3.additional_options.should  == nil
    end
  end
end
