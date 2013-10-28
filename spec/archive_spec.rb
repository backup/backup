# encoding: utf-8

require File.expand_path('../spec_helper.rb', __FILE__)

module Backup
describe Archive do
  let(:model) { Model.new(:test_trigger, 'test model') }

  describe '#initialize' do
    it 'sets default values' do
      archive = Archive.new(model, :test_archive) {}

      expect( archive.name ).to eq 'test_archive'
      expect( archive.options[:sudo]        ).to be(false)
      expect( archive.options[:root]        ).to be(false)
      expect( archive.options[:paths]       ).to eq []
      expect( archive.options[:excludes]    ).to eq []
      expect( archive.options[:tar_options] ).to eq ''
    end

    it 'sets configured values' do
      archive = Archive.new(model, :test_archive) do |a|
        a.use_sudo
        a.root 'root/path'
        a.add 'a/path'
        a.add '/another/path'
        a.exclude 'excluded/path'
        a.exclude '/another/excluded/path'
        a.tar_options '-h --xattrs'
      end

      expect( archive.name ).to eq 'test_archive'
      expect( archive.options[:sudo] ).to be(true)
      expect( archive.options[:root] ).to eq 'root/path'

      expect( archive.options[:paths] ).to eq(
        ['a/path', '/another/path']
      )
      expect( archive.options[:excludes] ).to eq(
        ['excluded/path', '/another/excluded/path']
      )
      expect( archive.options[:tar_options] ).to eq '-h --xattrs'
    end
  end # describe '#initialize'

  describe '#perform!' do
    before do
      Archive.any_instance.stubs(:utility).with(:tar).returns('tar')
      Archive.any_instance.stubs(:utility).with(:cat).returns('cat')
      Archive.any_instance.stubs(:utility).with(:sudo).returns('sudo')
      Archive.any_instance.stubs(:with_files_from).yields('')
      Config.stubs(:tmp_path).returns('/tmp/path')
      Pipeline.any_instance.stubs(:success?).returns(true)
    end

    describe 'success/failure messages' do
      let(:archive) { Archive.new(model, :my_archive) {} }

      it 'logs info messages on success' do
        Logger.expects(:info).with("Creating Archive 'my_archive'...")
        Logger.expects(:info).with("Archive 'my_archive' Complete!")

        archive.perform!
      end

      it 'raises error on failure' do
        Pipeline.any_instance.stubs(:success?).returns(false)
        Pipeline.any_instance.stubs(:error_messages).returns('error messages')

        Logger.expects(:info).with("Creating Archive 'my_archive'...")
        Logger.expects(:info).with("Archive 'my_archive' Complete!").never

        expect do
          archive.perform!
        end.to raise_error(Archive::Error) {|err|
          expect( err.message ).to eq(
            "Archive::Error: Failed to Create Archive 'my_archive'\n" +
            "  error messages"
          )
        }
      end
    end

    describe 'using GNU tar' do
      before do
        Pipeline.any_instance.expects(:<<).with(
          "cat > '/tmp/path/test_trigger/archives/my_archive.tar'"
        )
      end

      it 'returns GNU tar options' do
        archive = Archive.new(model, :my_archive) {}

        Pipeline.any_instance.expects(:add).with(
          'tar --ignore-failed-read -cPf -  ', [0, 1]
        )
        archive.perform!
      end

      it 'prepends GNU tar options' do
        archive = Archive.new(model, :my_archive) do |a|
          a.tar_options '-h --xattrs'
        end

        Pipeline.any_instance.expects(:add).with(
          'tar --ignore-failed-read -h --xattrs -cPf -  ', [0, 1]
        )
        archive.perform!
      end
    end

    describe 'using BSD tar' do
      before do
        Archive.any_instance.stubs(:gnu_tar?).returns(false)
        Pipeline.any_instance.expects(:<<).with(
          "cat > '/tmp/path/test_trigger/archives/my_archive.tar'"
        )
      end

      it 'returns no GNU options' do
        archive = Archive.new(model, :my_archive) {}

        Pipeline.any_instance.expects(:add).with('tar  -cPf -  ', [0])
        archive.perform!
      end

      it 'returns only the configured options' do
        archive = Archive.new(model, :my_archive) do |a|
          a.tar_options '-h --xattrs'
        end

        Pipeline.any_instance.expects(:add).with('tar -h --xattrs -cPf -  ', [0])
        archive.perform!
      end
    end

    describe 'root path option' do
      context 'when a root path is given' do
        it 'changes directories to create relative path archives' do
          archive = Archive.new(model, :my_archive) do |a|
            a.root 'root/path'
            a.add 'this/path'
            a.add '/that/path'
            a.exclude 'other/path'
            a.exclude '/another/path'
          end

          archive.expects(:with_files_from).with(
            ['this/path', '/that/path']
          ).yields("-T '/path/to/tmpfile'")

          Pipeline.any_instance.expects(:add).with(
            "tar --ignore-failed-read -cPf - " +
            "-C '#{ File.expand_path('root/path') }' " +
            "--exclude='other/path' --exclude='/another/path' " +
            "-T '/path/to/tmpfile'",
            [0, 1]
          )
          Pipeline.any_instance.expects(:<<).with(
            "cat > '/tmp/path/test_trigger/archives/my_archive.tar'"
          )

          archive.perform!
        end
      end

      context 'when no root path is given' do
        it 'creates archives with expanded paths' do
          archive = Archive.new(model, :my_archive) do |a|
            a.add 'this/path'
            a.add '/that/path'
            a.exclude 'other/path'
            a.exclude '/another/path'
          end

          archive.expects(:with_files_from).with(
            [File.expand_path('this/path'), '/that/path']
          ).yields("-T '/path/to/tmpfile'")

          Pipeline.any_instance.expects(:add).with(
            "tar --ignore-failed-read -cPf - " +
            "--exclude='#{ File.expand_path('other/path') }' " +
            "--exclude='/another/path' " +
            "-T '/path/to/tmpfile'",
            [0, 1]
          )
          Pipeline.any_instance.expects(:<<).with(
            "cat > '/tmp/path/test_trigger/archives/my_archive.tar'"
          )

          archive.perform!
        end
      end
    end # describe 'root path option'

    describe 'compressor usage' do
      let(:archive) { Archive.new(model, :my_archive) {} }

      it 'creates a compressed archive' do
        compressor = mock
        model.stubs(:compressor).returns(compressor)
        compressor.stubs(:compress_with).yields('comp_command', '.comp_ext')

        Pipeline.any_instance.expects(:<<).with('comp_command')
        Pipeline.any_instance.expects(:<<).with(
          "cat > '/tmp/path/test_trigger/archives/my_archive.tar.comp_ext'"
        )

        archive.perform!
      end

      it 'creates an uncompressed archive' do
        Pipeline.any_instance.expects(:<<).with('comp_command').never
        Pipeline.any_instance.expects(:<<).with(
          "cat > '/tmp/path/test_trigger/archives/my_archive.tar'"
        )

        archive.perform!
      end
    end

    specify 'may use sudo' do
      archive = Archive.new(model, :my_archive) {|a| a.use_sudo }

      Pipeline.any_instance.expects(:add).with(
        'sudo -n tar --ignore-failed-read -cPf -  ', [0, 1]
      )
      Pipeline.any_instance.expects(:<<).with(
        "cat > '/tmp/path/test_trigger/archives/my_archive.tar'"
      )
      archive.perform!
    end

  end # describe '#perform!'

  describe '#with_files_from' do
    let(:archive) { Archive.new(model, :test_archive) {} }
    let(:s) { sequence '' }
    let(:tmpfile) { stub(:path => '/path/to/tmpfile') }
    let(:paths) { ['this/path', '/that/path'] }

    # -T is used for BSD compatibility
    it 'yields the tar --files-from option' do
      Tempfile.expects(:new).in_sequence(s).returns(tmpfile)
      tmpfile.expects(:puts).in_sequence(s).with('this/path')
      tmpfile.expects(:puts).in_sequence(s).with('/that/path')
      tmpfile.expects(:close).in_sequence(s)
      tmpfile.expects(:delete).in_sequence(s)

      archive.send(:with_files_from, paths) do |files_from|
        expect( files_from ).to eq "-T '/path/to/tmpfile'"
      end
    end

    it 'ensures the tmpfile is removed' do
      Tempfile.expects(:new).returns(tmpfile)
      tmpfile.expects(:close)
      tmpfile.expects(:delete)
      expect do
        archive.send(:with_files_from, []) do |files_from|
          raise 'foo'
        end
      end.to raise_error('foo')
    end

    it 'writes the given paths to a tempfile' do
      archive.send(:with_files_from, paths) do |files_from|
        path = files_from.match(/-T '(.*)'/)[1]
        expect( File.read(path) ).to eq "this/path\n/that/path\n"
      end
    end
  end

end
end
