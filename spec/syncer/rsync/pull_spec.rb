# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe Backup::Syncer::RSync::Pull do
  let(:syncer) do
    Backup::Syncer::RSync::Pull.new do |rsync|
      rsync.username  = 'my_username'
      rsync.password  = 'my_password'
      rsync.ip        = '123.45.678.90'
      rsync.port      = 22
      rsync.compress  = true
      rsync.path      = "~/my_backups"

      rsync.directories do |directory|
        directory.add "/some/directory"
        directory.add "~/home/directory"
        directory.add "another/directory"
      end

      rsync.mirror             = true
      rsync.additional_options = ['--opt-a', '--opt-b']
    end
  end

  it 'should be a subclass of RSync::Push' do
    Backup::Syncer::RSync::Pull.superclass.should == Backup::Syncer::RSync::Push
  end

  describe '#perform!' do
    let(:s) { sequence '' }

    it 'should perform the RSync::Pull operation on two directories' do
      syncer.expects(:utility).times(3).with(:rsync).returns('rsync')
      syncer.expects(:options).times(3).returns('options_output')

      syncer.expects(:write_password_file!).in_sequence(s)

      # first directory - uses the given full path
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Syncer::RSync::Pull started syncing '/some/directory'."
      )
      syncer.expects(:run).in_sequence(s).with(
        "rsync options_output 'my_username@123.45.678.90:/some/directory' " +
        "'#{ File.expand_path('~/my_backups') }'"
      )

      # second directory - removes leading '~'
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Syncer::RSync::Pull started syncing '~/home/directory'."
      )
      syncer.expects(:run).in_sequence(s).with(
        "rsync options_output 'my_username@123.45.678.90:home/directory' " +
        "'#{ File.expand_path('~/my_backups') }'"
      )

      # third directory - does not expand path
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Syncer::RSync::Pull started syncing 'another/directory'."
      )
      syncer.expects(:run).in_sequence(s).with(
        "rsync options_output 'my_username@123.45.678.90:another/directory' " +
        "'#{ File.expand_path('~/my_backups') }'"
      )

      syncer.expects(:remove_password_file!).in_sequence(s)

      syncer.perform!
    end

    it 'should ensure passoword file removal' do
      syncer.expects(:write_password_file!).raises('error message')
      syncer.expects(:remove_password_file!)

      expect do
        syncer.perform!
      end.to raise_error(RuntimeError, 'error message')
    end
  end # describe '#perform!'

  describe '#dest_path' do
    it 'should return @path expanded' do
      syncer.send(:dest_path).should == File.expand_path('~/my_backups')
    end

    it 'should set @dest_path' do
      syncer.send(:dest_path)
      syncer.instance_variable_get(:@dest_path).should ==
          File.expand_path('~/my_backups')
    end

    it 'should return @dest_path if already set' do
      syncer.instance_variable_set(:@dest_path, 'foo')
      syncer.send(:dest_path).should == 'foo'
    end
  end

end
