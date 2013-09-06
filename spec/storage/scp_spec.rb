# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Storage::SCP do
  let(:model)   { Model.new(:test_trigger, 'test label') }
  let(:storage) { Storage::SCP.new(model) }
  let(:s) { sequence '' }

  it_behaves_like 'a class that includes Configuration::Helpers'
  it_behaves_like 'a subclass of Storage::Base'

  describe '#initialize' do

    it 'provides default values' do
      expect( storage.storage_id  ).to be_nil
      expect( storage.keep        ).to be_nil
      expect( storage.username    ).to be_nil
      expect( storage.password    ).to be_nil
      expect( storage.ssh_options ).to eq({})
      expect( storage.ip          ).to be_nil
      expect( storage.port        ).to be 22
      expect( storage.path        ).to eq 'backups'
    end

    it 'configures the storage' do
      storage = Storage::SCP.new(model, :my_id) do |scp|
        scp.keep = 2
        scp.username    = 'my_username'
        scp.password    = 'my_password'
        scp.ssh_options = { :keys => ['my/key'] }
        scp.ip          = 'my_host'
        scp.port        = 123
        scp.path        = 'my/path'
      end

      expect( storage.storage_id  ).to eq 'my_id'
      expect( storage.keep        ).to be 2
      expect( storage.username    ).to eq 'my_username'
      expect( storage.password    ).to eq 'my_password'
      expect( storage.ssh_options ).to eq :keys => ['my/key']
      expect( storage.ip          ).to eq 'my_host'
      expect( storage.port        ).to be 123
      expect( storage.path        ).to eq 'my/path'
    end

    it 'converts a tilde path to a relative path' do
      storage = Storage::SCP.new(model) do |scp|
        scp.path = '~/my/path'
      end
      expect( storage.path ).to eq 'my/path'
    end

    it 'does not alter an absolute path' do
      storage = Storage::SCP.new(model) do |scp|
        scp.path = '/my/path'
      end
      expect( storage.path ).to eq '/my/path'
    end

  end # describe '#initialize'

  describe '#connection' do
    let(:connection) { mock }

    before do
      storage.ip = '123.45.678.90'
      storage.username = 'my_user'
      storage.password = 'my_pass'
      storage.ssh_options = { :keys => ['my/key'] }
    end

    it 'yields a connection to the remote server' do
      Net::SSH.expects(:start).with(
        '123.45.678.90', 'my_user', :password => 'my_pass', :port => 22,
        :keys => ['my/key']
      ).yields(connection)

      storage.send(:connection) do |scp|
        expect( scp ).to be connection
      end
    end
  end # describe '#connection'

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
          expect( err ).to be_an_instance_of Storage::SCP::Error
          expect( err.message ).to eq "Storage::SCP::Error: " +
            "Net::SSH reported the following errors:\n" +
            "  path not found"
        }
      end
    end

  end # describe '#remove!'

end
end
