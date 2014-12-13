# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Storage::SFTP do
  let(:model)   { Model.new(:test_trigger, 'test label') }
  let(:storage) { Storage::SFTP.new(model) }
  let(:s) { sequence '' }

  it_behaves_like 'a class that includes Config::Helpers'
  it_behaves_like 'a subclass of Storage::SSHBase'
  it_behaves_like 'a storage that cycles'

  describe '#transfer!' do
    let(:connection) { mock }
    let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
    let(:remote_path) { File.join('my/path/test_trigger', timestamp) }

    before do
      Timecop.freeze
      storage.package.time = timestamp
      storage.package.stubs(:filenames).returns(
        ['test_trigger.tar-aa', 'test_trigger.tar-ab']
      )
      storage.ip = '123.45.678.90'
      storage.path = 'my/path'
    end

    after { Timecop.return }

    it 'transfers the package files' do
      storage.expects(:connection).in_sequence(s).yields(connection)

      storage.expects(:create_remote_path).in_sequence(s).with(connection)

      src = File.join(Config.tmp_path, 'test_trigger.tar-aa')
      dest = File.join(remote_path, 'test_trigger.tar-aa')

      Logger.expects(:info).in_sequence(s).
          with("Storing '123.45.678.90:#{ dest }'...")

      connection.expects(:upload!).in_sequence(s).with(src, dest)

      src = File.join(Config.tmp_path, 'test_trigger.tar-ab')
      dest = File.join(remote_path, 'test_trigger.tar-ab')

      Logger.expects(:info).in_sequence(s).
          with("Storing '123.45.678.90:#{ dest }'...")

      connection.expects(:upload!).in_sequence(s).with(src, dest)

      storage.send(:transfer!)
    end
  end # describe '#transfer!'

  describe '#remove!' do
    let(:connection) { mock }
    let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
    let(:remote_path) { File.join('my/path/test_trigger', timestamp) }
    let(:package) {
      stub( # loaded from YAML storage file
        :trigger    => 'test_trigger',
        :time       => timestamp,
        :filenames  => ['test_trigger.tar-aa', 'test_trigger.tar-ab']
      )
    }

    before do
      Timecop.freeze
      storage.path = 'my/path'
    end

    after { Timecop.return }

    it 'removes the given package from the remote' do
      Logger.expects(:info).in_sequence(s).
          with("Removing backup package dated #{ timestamp }...")

      storage.expects(:connection).in_sequence(s).yields(connection)

      target = File.join(remote_path, 'test_trigger.tar-aa')
      connection.expects(:remove!).in_sequence(s).with(target)

      target = File.join(remote_path, 'test_trigger.tar-ab')
      connection.expects(:remove!).in_sequence(s).with(target)

      connection.expects(:rmdir!).in_sequence(s).with(remote_path)

      storage.send(:remove!, package)
    end
  end # describe '#remove!'

  describe '#create_remote_path' do
    let(:connection)  { mock }
    let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
    let(:remote_path) { File.join('my/path/test_trigger', timestamp) }
    let(:sftp_response) { stub(:code => 11, :message => nil) }
    let(:sftp_status_exception) { Net::SFTP::StatusException.new(sftp_response) }

    before do
      Timecop.freeze
      storage.package.time = timestamp
      storage.path = 'my/path'
    end

    after { Timecop.return }

    context 'while properly creating remote directories one by one' do
      it 'should rescue any SFTP::StatusException and continue' do
        connection.expects(:mkdir!).in_sequence(s).
            with("my")
        connection.expects(:mkdir!).in_sequence(s).
            with("my/path").raises(sftp_status_exception)
        connection.expects(:mkdir!).in_sequence(s).
            with("my/path/test_trigger")
        connection.expects(:mkdir!).in_sequence(s).
            with("my/path/test_trigger/#{ timestamp }")

        expect do
          storage.send(:create_remote_path, connection)
        end.not_to raise_error
      end
    end
  end # describe '#create_remote_path'

end
end
