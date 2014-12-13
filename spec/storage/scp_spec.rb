# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Storage::SCP do
  let(:model)   { Model.new(:test_trigger, 'test label') }
  let(:storage) { Storage::SCP.new(model) }
  let(:s) { sequence '' }

  it_behaves_like 'a class that includes Config::Helpers'
  it_behaves_like 'a subclass of Storage::SSHBase'
  it_behaves_like 'a storage that cycles'

  describe '#transfer!' do
    let(:connection) { mock }
    let(:scp) { mock }
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
      connection.stubs(:scp).returns(scp)
    end

    after { Timecop.return }

    it 'transfers the package files' do
      storage.expects(:connection).in_sequence(s).yields(connection)

      connection.expects(:exec!).in_sequence(s).with(
        "mkdir -p '#{ remote_path }'"
      )

      src = File.join(Config.tmp_path, 'test_trigger.tar-aa')
      dest = File.join(remote_path, 'test_trigger.tar-aa')

      Logger.expects(:info).in_sequence(s).
          with("Storing '123.45.678.90:#{ dest }'...")

      scp.expects(:upload!).in_sequence(s).with(src, dest)

      src = File.join(Config.tmp_path, 'test_trigger.tar-ab')
      dest = File.join(remote_path, 'test_trigger.tar-ab')

      Logger.expects(:info).in_sequence(s).
          with("Storing '123.45.678.90:#{ dest }'...")

      scp.expects(:upload!).in_sequence(s).with(src, dest)

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
        :time       => timestamp
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

      connection.expects(:exec!).in_sequence(s).
          with("rm -r '#{ remote_path }'")

      storage.send(:remove!, package)
    end

    context 'when the ssh connection reports errors' do
      it 'raises an error reporting the errors' do
        Logger.expects(:info).in_sequence(s).
            with("Removing backup package dated #{ timestamp }...")

        storage.expects(:connection).in_sequence(s).yields(connection)

        connection.expects(:exec!).in_sequence(s).
            with("rm -r '#{ remote_path }'").
            yields(:ch, :stderr, 'path not found')

        expect do
          storage.send(:remove!, package)
        end.to raise_error {|err|
          expect( err ).to be_an_instance_of Storage::SSHBase::Error
          expect( err.message ).to eq "Storage::SSHBase::Error: " +
            "Net::SSH reported the following errors:\n" +
            "  path not found"
        }
      end
    end

  end # describe '#remove!'

end
end
