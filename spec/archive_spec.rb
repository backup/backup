# encoding: utf-8

require File.expand_path('../spec_helper.rb', __FILE__)

describe Backup::Archive do
  let(:model) { Backup::Model.new(:test_trigger, 'test model') }
  let(:archive) { Backup::Archive.new(model, :test_archive) }

  describe '#initialize' do

    it 'should have no paths' do
      archive.paths.should == []
    end

    it 'should have no excludes' do
      archive.excludes.should == []
    end

    it 'should have no tar_args' do
      archive.tar_args.should == ''
    end

    it 'should set a reference to the given model' do
      archive.instance_variable_get(:@model).should be(model)
    end

    it 'should convert name to a String' do
      archive.name.should be_a_kind_of String
      archive.name.should == 'test_archive'
    end

    context 'when a configuration block is given' do
      let(:archive) do
        Backup::Archive.new(model, :test_archive) do |a|
          a.add 'added_path'
          a.add 'another/added_path'
          a.exclude 'excluded_path'
          a.exclude 'another/excluded_path'
          a.tar_options '-h --xattrs'
        end
      end

      before do
        File.stubs(:exist?).returns(true)
      end

      it 'should add @paths' do
        archive.paths.should == [
          File.expand_path('added_path'),
          File.expand_path('another/added_path')
        ]
      end

      it 'should add @excludes' do
        archive.excludes.should == [
          File.expand_path('excluded_path'),
          File.expand_path('another/excluded_path')
        ]
      end

      it 'should add @tar_args' do
        archive.tar_args.should == '-h --xattrs'
      end
    end

  end # describe '#initialize'

  describe '#add' do
    it 'should expand and add the path to @paths' do
      archive.add 'foo'
      archive.paths.should == [File.expand_path('foo')]
    end
  end

  describe '#exclude' do
    it 'should expand and add the given path to #excludes' do
      archive.exclude 'path'
      archive.exclude 'another/path'
      archive.excludes.should == [
        File.expand_path('path'),
        File.expand_path('another/path')
      ]
    end
  end

  describe '#tar_options' do
    it 'should set #tar_options to the given string' do
      archive = Backup::Archive.new(model, :test_archive) do |a|
        a.tar_options '-h --xattrs'
      end
      archive.tar_args.should == '-h --xattrs'
    end
  end

  describe '#perform!' do
    let(:archive_path) do
      File.join(Backup::Config.tmp_path, 'test_trigger', 'archives')
    end
    let(:paths) { ['/path/to/add', '/another/path/to/add'] }
    let(:excludes) { ['/path/to/exclude', '/another/path/to/exclude'] }
    let(:pipeline) { mock }
    let(:s) { sequence '' }

    before do
      archive.instance_variable_set(:@paths, paths)
      archive.expects(:utility).with(:tar).returns('tar')
      FileUtils.expects(:mkdir_p).with(archive_path)
      Backup::Pipeline.expects(:new).returns(pipeline)
    end

    context 'when both #paths and #excludes were added' do
      before do
        archive.instance_variable_set(:@excludes, excludes)
      end

      it 'should render the syntax for both' do
        Backup::Logger.expects(:info).in_sequence(s).with(
          "Backup::Archive has started archiving:\n" +
          "  /path/to/add\n" +
          "  /another/path/to/add"
        )

        pipeline.expects(:add).in_sequence(s).with(
          "tar --ignore-failed-read  -cPf - " +
          "--exclude='/path/to/exclude' --exclude='/another/path/to/exclude' " +
          "'/path/to/add' '/another/path/to/add'",
          [0, 1]
        )
        pipeline.expects(:<<).in_sequence(s).with(
          "cat > '#{ File.join(archive_path, 'test_archive.tar') }'"
        )
        pipeline.expects(:run).in_sequence(s)
        pipeline.expects(:success?).in_sequence(s).returns(true)

        Backup::Logger.expects(:info).in_sequence(s).with(
          "Backup::Archive Complete!"
        )

        archive.perform!
      end
    end # context 'when both #paths and #excludes were added'

    context 'when no excludes were added' do
      it 'should render only the syntax for adds' do
        Backup::Logger.expects(:info).in_sequence(s).with(
          "Backup::Archive has started archiving:\n" +
          "  /path/to/add\n" +
          "  /another/path/to/add"
        )

        pipeline.expects(:add).in_sequence(s).with(
          "tar --ignore-failed-read  -cPf -  " +
          "'/path/to/add' '/another/path/to/add'", [0, 1]
        )
        pipeline.expects(:<<).in_sequence(s).with(
          "cat > '#{ File.join(archive_path, 'test_archive.tar') }'"
        )
        pipeline.expects(:run).in_sequence(s)
        pipeline.expects(:success?).in_sequence(s).returns(true)

        Backup::Logger.expects(:info).in_sequence(s).with(
          "Backup::Archive Complete!"
        )

        archive.perform!
      end
    end # context 'when no excludes were added'

    context 'with #paths, #excludes and #tar_args' do
      before do
        archive.instance_variable_set(:@excludes, excludes)
        archive.instance_variable_set(:@tar_args, '-h --xattrs')
      end

      it 'should render the syntax for all three' do
        Backup::Logger.expects(:info).in_sequence(s).with(
          "Backup::Archive has started archiving:\n" +
          "  /path/to/add\n" +
          "  /another/path/to/add"
        )

        pipeline.expects(:add).in_sequence(s).with(
          "tar --ignore-failed-read -h --xattrs -cPf - " +
          "--exclude='/path/to/exclude' --exclude='/another/path/to/exclude' " +
          "'/path/to/add' '/another/path/to/add'",
          [0, 1]
        )
        pipeline.expects(:<<).in_sequence(s).with(
          "cat > '#{ File.join(archive_path, 'test_archive.tar') }'"
        )
        pipeline.expects(:run).in_sequence(s)
        pipeline.expects(:success?).in_sequence(s).returns(true)

        Backup::Logger.expects(:info).in_sequence(s).with(
          "Backup::Archive Complete!"
        )

        archive.perform!
      end
    end # context 'with #paths, #excludes and #tar_args'

    context 'with #paths, #excludes, #tar_args and a Gzip Compressor' do
      before do
        archive.instance_variable_set(:@excludes, excludes)
        archive.instance_variable_set(:@tar_args, '-h --xattrs')
        compressor = mock
        model.expects(:compressor).twice.returns(compressor)
        compressor.expects(:compress_with).yields('gzip', '.gz')
      end

      it 'should render the syntax with compressor modifications' do
        Backup::Logger.expects(:info).in_sequence(s).with(
          "Backup::Archive has started archiving:\n" +
          "  /path/to/add\n" +
          "  /another/path/to/add"
        )

        pipeline.expects(:add).in_sequence(s).with(
          "tar --ignore-failed-read -h --xattrs -cPf - " +
          "--exclude='/path/to/exclude' --exclude='/another/path/to/exclude' " +
          "'/path/to/add' '/another/path/to/add'",
          [0, 1]
        )
        pipeline.expects(:<<).in_sequence(s).with('gzip')
        pipeline.expects(:<<).in_sequence(s).with(
          "cat > '#{ File.join(archive_path, 'test_archive.tar.gz') }'"
        )
        pipeline.expects(:run).in_sequence(s)
        pipeline.expects(:success?).in_sequence(s).returns(true)

        Backup::Logger.expects(:info).in_sequence(s).with(
          "Backup::Archive Complete!"
        )

        archive.perform!
      end
    end # context 'with #paths, #excludes, #tar_args and a Gzip Compressor'

    context 'when pipeline command fails' do
      before do
        pipeline.stubs(:<<)
        pipeline.stubs(:add)
        pipeline.expects(:run)
        pipeline.expects(:success?).returns(false)
        pipeline.expects(:error_messages).returns('pipeline_errors')
      end

      it 'should raise an error' do
        Backup::Logger.expects(:info).with(
          "Backup::Archive has started archiving:\n" +
          "  /path/to/add\n" +
          "  /another/path/to/add"
        )

        expect do
          archive.perform!
        end.to raise_error(
          Backup::Errors::Archive::PipelineError,
          "Archive::PipelineError: Failed to Create Backup Archive\n" +
          "  pipeline_errors"
        )
      end
    end # context 'when pipeline command fails'

  end # describe '#perform!'

  describe '#paths_to_package' do
    before do
      archive.instance_variable_set(
        :@paths,
        ['/home/rspecuser/somefile',
         '/home/rspecuser/logs',
         '/home/rspecuser/dotfiles']
      )
    end

    it 'should return a tar friendly string' do
      archive.send(:paths_to_package).should ==
      "'/home/rspecuser/somefile' '/home/rspecuser/logs' '/home/rspecuser/dotfiles'"
    end
  end

  describe '#paths_to_exclude' do
    context 'when no excludes are added' do
      it 'should return nil' do
        archive.send(:paths_to_exclude).should be_nil
      end
    end

    context 'when excludes are added' do
      before do
        archive.instance_variable_set(
          :@excludes,
          ['/home/rspecuser/badfile',
          '/home/rspecuser/wrongdir']
        )
      end
      it 'should return a tar friendly string' do
        archive.send(:paths_to_exclude).should ==
        "--exclude='/home/rspecuser/badfile' --exclude='/home/rspecuser/wrongdir'"
      end
    end
  end
end
