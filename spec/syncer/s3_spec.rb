# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Syncer::S3 do
  let(:syncer) do
    Backup::Syncer::S3.new do |s3|
      s3.access_key_id      = 'my_access_key_id'
      s3.secret_access_key  = 'my_secret_access_key'
      s3.bucket             = 'my-bucket'
      s3.path               = "/my_backups"

      s3.directories do |directory|
        directory.add "/some/directory"
        directory.add "~/home/directory"
      end

      s3.mirror             = true
      s3.additional_options = ['--opt-a', '--opt-b']
    end
  end

  describe '#initialize' do

    it 'should have defined the configuration properly' do
      syncer.access_key_id.should      == 'my_access_key_id'
      syncer.secret_access_key.should  == 'my_secret_access_key'
      syncer.bucket.should             == 'my-bucket'
      syncer.path.should               == '/my_backups'
      syncer.directories.should        == ["/some/directory", "~/home/directory"]
      syncer.mirror.should             == true
      syncer.additional_options.should == ['--opt-a', '--opt-b']
    end

    context 'when options are not set' do
      it 'should use default values' do
        syncer = Backup::Syncer::S3.new
        syncer.access_key_id.should      == nil
        syncer.secret_access_key.should  == nil
        syncer.bucket.should             == nil
        syncer.path.should               == 'backups'
        syncer.directories.should        == []
        syncer.mirror.should             == false
        syncer.additional_options.should == []
      end
    end

    context 'when setting configuration defaults' do
      after { Backup::Configuration::Syncer::S3.clear_defaults! }

      it 'should use the configured defaults' do
        Backup::Configuration::Syncer::S3.defaults do |s3|
          s3.access_key_id      = 'some_access_key_id'
          s3.secret_access_key  = 'some_secret_access_key'
          s3.bucket             = 'some_bucket'
          s3.path               = 'some_path'
          #s3.directories        = 'cannot_have_a_default_value'
          s3.mirror             = 'some_mirror'
          s3.additional_options = 'some_additional_options'
        end
        syncer = Backup::Syncer::S3.new
        syncer.access_key_id.should      == 'some_access_key_id'
        syncer.secret_access_key.should  == 'some_secret_access_key'
        syncer.bucket.should             == 'some_bucket'
        syncer.path.should               == 'some_path'
        syncer.directories.should        == []
        syncer.mirror.should             == 'some_mirror'
        syncer.additional_options.should == 'some_additional_options'
      end

      it 'should override the configured defaults' do
        Backup::Configuration::Syncer::S3.defaults do |s3|
          s3.access_key_id      = 'old_access_key_id'
          s3.secret_access_key  = 'old_secret_access_key'
          s3.bucket             = 'old_bucket'
          s3.path               = 'old_path'
          #s3.directories        = 'cannot_have_a_default_value'
          s3.mirror             = 'old_mirror'
          s3.additional_options = 'old_additional_options'
        end
        syncer = Backup::Syncer::S3.new do |s3|
          s3.access_key_id      = 'new_access_key_id'
          s3.secret_access_key  = 'new_secret_access_key'
          s3.bucket             = 'new_bucket'
          s3.path               = 'new_path'
          s3.directories        = 'new_directories'
          s3.mirror             = 'new_mirror'
          s3.additional_options = 'new_additional_options'
        end

        syncer.access_key_id.should      == 'new_access_key_id'
        syncer.secret_access_key.should  == 'new_secret_access_key'
        syncer.bucket.should             == 'new_bucket'
        syncer.path.should               == 'new_path'
        syncer.directories.should        == 'new_directories'
        syncer.mirror.should             == 'new_mirror'
        syncer.additional_options.should == 'new_additional_options'
      end
    end # context 'when setting configuration defaults'
  end # describe '#initialize'

  describe '#perform!' do
    let(:s) { sequence '' }

    before do
      syncer.expects(:utility).twice.with(:s3sync).returns('s3sync')
      syncer.expects(:options).twice.returns('options_output')
    end

    it 'should sync two directories' do
      syncer.expects(:set_environment_variables!).in_sequence(s)

      # first directory
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Syncer::S3 started syncing '/some/directory'."
      )
      syncer.expects(:run).in_sequence(s).with(
        "s3sync options_output '/some/directory' 'my-bucket:my_backups'"
      ).returns('messages from stdout')
      Backup::Logger.expects(:silent).in_sequence(s).with('messages from stdout')

      # second directory
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Syncer::S3 started syncing '~/home/directory'."
      )
      syncer.expects(:run).in_sequence(s).with(
        "s3sync options_output '#{ File.expand_path('~/home/directory') }' " +
        "'my-bucket:my_backups'"
      ).returns('messages from stdout')
      Backup::Logger.expects(:silent).in_sequence(s).with('messages from stdout')

      syncer.expects(:unset_environment_variables!).in_sequence(s)

      syncer.perform!
    end
  end # describe '#perform!'

  describe '#directories' do
    context 'when no block is given' do
      it 'should return @directories' do
        syncer.directories.should ==
            ['/some/directory', '~/home/directory']
      end
    end

    context 'when a block is given' do
      it 'should evalute the block, allowing #add to add directories' do
        syncer.directories do
          add '/new/path'
          add '~/new/home/path'
        end
        syncer.directories.should == [
          '/some/directory',
          '~/home/directory',
          '/new/path',
          '~/new/home/path'
        ]
      end
    end
  end # describe '#directories'

  describe '#add' do
    it 'should add the given path to @directories' do
      syncer.add '/my/path'
      syncer.directories.should ==
          ['/some/directory', '~/home/directory', '/my/path']
    end
  end

  describe '#dest_path' do
    it 'should remove any preceeding "/" from @path' do
      syncer.send(:dest_path).should == 'my_backups'
    end

    it 'should set @dest_path' do
      syncer.send(:dest_path)
      syncer.instance_variable_get(:@dest_path).should == 'my_backups'
    end

    it 'should return @dest_path if already set' do
      syncer.instance_variable_set(:@dest_path, 'foo')
      syncer.send(:dest_path).should == 'foo'
    end
  end

  describe '#options' do
    context 'when @mirror is true' do
      it 'should return the options with mirroring enabled' do
        syncer.send(:options).should ==
          '--verbose --recursive --delete --opt-a --opt-b'
      end
    end

    context 'when @mirror is false' do
      before { syncer.mirror = false }
      it 'should return the options without mirroring enabled' do
        syncer.send(:options).should ==
          '--verbose --recursive --opt-a --opt-b'
      end
    end

    context 'with no additional options' do
      before { syncer.additional_options = [] }
      it 'should return the options without additional options' do
        syncer.send(:options).should ==
          '--verbose --recursive --delete'
      end
    end
  end # describe '#options'

  describe 'changing environment variables' do
    before  { @env = ENV }
    after   { ENV.replace(@env) }

    it 'should set and unset environment variables' do
      syncer.send(:set_environment_variables!)
      ENV['AWS_ACCESS_KEY_ID'].should     == 'my_access_key_id'
      ENV['AWS_SECRET_ACCESS_KEY'].should == 'my_secret_access_key'
      ENV['AWS_CALLING_FORMAT'].should    == 'SUBDOMAIN'

      syncer.send(:unset_environment_variables!)
      ENV['AWS_ACCESS_KEY_ID'].should     == nil
      ENV['AWS_SECRET_ACCESS_KEY'].should == nil
      ENV['AWS_CALLING_FORMAT'].should    == nil
    end
  end

end
