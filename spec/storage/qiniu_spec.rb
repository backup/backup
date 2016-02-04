# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
  describe Storage::Qiniu do
    let(:model) { Model.new(:test_trigger, 'test label') }
    let(:required_config) {
      Proc.new do |s3|
        s3.access_key = 'my_access_key'
        s3.secret_key = 'my_secret_key'
        s3.bucket     = 'my_bucket'
      end
    }
    let(:storage) { Storage::Qiniu.new(model, &required_config) }
    let(:s) { sequence '' }

    describe '#initialize' do
      it 'provides default values' do
        # required
        expect( storage.bucket     ).to eq 'my_bucket'
        expect( storage.access_key ).to eq 'my_access_key'
        expect( storage.secret_key ).to eq 'my_secret_key'

        # defaults
        expect( storage.storage_id ).to be_nil
        expect( storage.keep       ).to be_nil
        expect( storage.path       ).to eq 'backups'
      end

      it 'requires access_key secret_key and bucket' do
        expect do
          Storage::Qiniu.new(model)
        end.to raise_error {|err|
          expect( err.message ).to match(/#access_key, #secret_key, #bucket are all required/)
        }
      end

      it 'establishes connection' do
        ::Qiniu.expects(:establish_connection!).with(access_key: 'my_access_key', secret_key: 'my_secret_key')

        pre_config = required_config
        Storage::Qiniu.new(model) do |qiniu|
          pre_config.call(qiniu)
        end
      end
    end

    describe '#transfer!' do
      let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
      let(:remote_path) { File.join('my/path/test_trigger', timestamp) }
      let(:uptoken) { 'uptoken' }

      before do
        Timecop.freeze
        storage.package.time = timestamp
        storage.package.stubs(:filenames).returns(
          ['test_trigger.tar-aa', 'test_trigger.tar-ab']
        )
        storage.path = 'my/path'

        ::Qiniu.stubs(:generate_upload_token).returns(uptoken)
      end

      after { Timecop.return }

      it 'transfers the package files' do
        src = File.join(Config.tmp_path, 'test_trigger.tar-aa')
        dest = File.join(remote_path, 'test_trigger.tar-aa')

        Logger.expects(:info).in_sequence(s).with("Storing '#{ dest }'...")
        ::Qiniu.expects(:upload_file).in_sequence(s).with(uptoken: uptoken,
                                                          bucket: 'my_bucket',
                                                          file: src,
                                                          key: dest)

        src = File.join(Config.tmp_path, 'test_trigger.tar-ab')
        dest = File.join(remote_path, 'test_trigger.tar-ab')

        Logger.expects(:info).in_sequence(s).with("Storing '#{ dest }'...")
        ::Qiniu.expects(:upload_file).in_sequence(s).with(uptoken: uptoken,
                                                          bucket: 'my_bucket',
                                                          file: src,
                                                          key: dest)

        storage.send(:transfer!)
      end

    end

    describe '#remove' do
      let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
      let(:remote_path) { File.join('my/path/test_trigger', timestamp) }
      let(:uptoken) { 'uptoken' }
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
        Logger.expects(:info).in_sequence(s).with("Removing backup package dated #{ timestamp }...")

        dest = File.join(remote_path, 'test_trigger.tar-aa')
        ::Qiniu.expects(:delete).in_sequence(s).with('my_bucket', dest)

        dest = File.join(remote_path, 'test_trigger.tar-ab')
        ::Qiniu.expects(:delete).in_sequence(s).with('my_bucket', dest)

        storage.send(:remove!, package)
      end
    end
  end
end
