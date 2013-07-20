# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Storage::Local do
  let(:model) { Model.new(:test_trigger, 'test label') }
  let(:storage) { Storage::Local.new(model) }
  let(:s) { sequence '' }

  it_behaves_like 'a class that includes Configuration::Helpers'
  it_behaves_like 'a subclass of Storage::Base'

  describe '#initialize' do

    it 'provides default values' do
      expect( storage.storage_id ).to be_nil
      expect( storage.keep       ).to be_nil
      expect( storage.path       ).to eq '~/backups'
    end

    it 'configures the storage' do
      storage = Storage::Local.new(model, :my_id) do |local|
        local.keep = 2
        local.path = '/my/path'
      end

      expect( storage.storage_id ).to eq 'my_id'
      expect( storage.keep       ).to be 2
      expect( storage.path       ).to eq '/my/path'
    end

  end # describe '#initialize'

  describe '#transfer!' do
    let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
    let(:remote_path) {
      File.expand_path(File.join('my/path/test_trigger', timestamp))
    }

    before do
      Timecop.freeze
      storage.package.time = timestamp
      storage.package.stubs(:filenames).returns(
        ['test_trigger.tar-aa', 'test_trigger.tar-ab']
      )
      storage.path = 'my/path'
    end

    after { Timecop.return }

    context 'when the storage is the last for the model' do
      before do
        model.storages << storage
      end

      it 'moves the package files to their destination' do
        FileUtils.expects(:mkdir_p).in_sequence(s).with(remote_path)

        Logger.expects(:warn).never

        src = File.join(Config.tmp_path, 'test_trigger.tar-aa')
        dest = File.join(remote_path, 'test_trigger.tar-aa')
        Logger.expects(:info).in_sequence(s).with("Storing '#{ dest }'...")
        FileUtils.expects(:mv).in_sequence(s).with(src, dest)

        src = File.join(Config.tmp_path, 'test_trigger.tar-ab')
        dest = File.join(remote_path, 'test_trigger.tar-ab')
        Logger.expects(:info).in_sequence(s).with("Storing '#{ dest }'...")
        FileUtils.expects(:mv).in_sequence(s).with(src, dest)

        storage.send(:transfer!)
      end
    end

    context 'when the storage is not the last for the model' do
      before do
        model.storages << storage
        model.storages << Storage::Local.new(model)
      end

      it 'logs a warning and copies the package files to their destination' do
        FileUtils.expects(:mkdir_p).in_sequence(s).with(remote_path)

        Logger.expects(:warn).in_sequence(s).with do |err|
          expect( err ).to be_an_instance_of Storage::Local::Error
          expect( err.message ).to eq <<-EOS.gsub(/^ +/, '  ').strip
            Storage::Local::Error: Local File Copy Warning!
              The final backup file(s) for 'test label' (test_trigger)
              will be *copied* to '#{ remote_path }'
              To avoid this, when using more than one Storage, the 'Local' Storage
              should be added *last* so the files may be *moved* to their destination.
          EOS
        end

        src = File.join(Config.tmp_path, 'test_trigger.tar-aa')
        dest = File.join(remote_path, 'test_trigger.tar-aa')
        Logger.expects(:info).in_sequence(s).with("Storing '#{ dest }'...")
        FileUtils.expects(:cp).in_sequence(s).with(src, dest)

        src = File.join(Config.tmp_path, 'test_trigger.tar-ab')
        dest = File.join(remote_path, 'test_trigger.tar-ab')
        Logger.expects(:info).in_sequence(s).with("Storing '#{ dest }'...")
        FileUtils.expects(:cp).in_sequence(s).with(src, dest)

        storage.send(:transfer!)
      end
    end

  end # describe '#transfer!'

  describe '#remove!' do
    let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
    let(:remote_path) {
      File.expand_path(File.join('my/path/test_trigger', timestamp))
    }
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

      FileUtils.expects(:rm_r).in_sequence(s).with(remote_path)

      storage.send(:remove!, package)
    end
  end # describe '#remove!'

end
end
