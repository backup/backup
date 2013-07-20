# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe 'Backup::Storage::Cycler' do
  let(:cycler)        { Backup::Storage::Cycler }
  let(:storage)       { mock }
  let(:package)       { mock }
  let(:storage_file)  { mock }
  let(:pkg_a)         { mock }
  let(:pkg_b)         { mock }
  let(:pkg_c)         { mock }
  let(:s)             { sequence '' }

  before do
    storage.stubs(:package).returns(package)
  end

  describe '#cycle!' do
    it 'should setup variables and initiate cycling' do
      cycler.expects(:storage_file).in_sequence(s).returns(storage_file)
      cycler.expects(:update_storage_file!).in_sequence(s)
      cycler.expects(:remove_packages!).in_sequence(s)
      cycler.cycle!(storage)
      cycler.instance_variable_get(:@storage).should be(storage)
      cycler.instance_variable_get(:@package).should be(package)
      cycler.instance_variable_get(:@storage_file).should be(storage_file)
    end
  end

  describe 'update_storage_file!' do
    before do
      cycler.instance_variable_set(:@storage, storage)
      cycler.instance_variable_set(:@package, package)
      cycler.instance_variable_set(:@storage_file, storage_file)
    end

    it 'should remove entries and set @packages_to_remove' do
      storage.stubs(:keep).returns(2)
      cycler.expects(:yaml_load).in_sequence(s).returns([pkg_a, pkg_b, pkg_c])
      cycler.expects(:yaml_save).in_sequence(s).with([package, pkg_a])
      cycler.send(:update_storage_file!)
      cycler.instance_variable_get(:@packages_to_remove).should == [pkg_b, pkg_c]
    end

    it 'should typecast the value of keep' do
      storage.stubs(:keep).returns('2')
      cycler.expects(:yaml_load).in_sequence(s).returns([pkg_a, pkg_b, pkg_c])
      cycler.expects(:yaml_save).in_sequence(s).with([package, pkg_a])
      cycler.send(:update_storage_file!)
      cycler.instance_variable_get(:@packages_to_remove).should == [pkg_b, pkg_c]
    end
  end

  describe '#remove_packages!' do
    before do
      cycler.instance_variable_set(:@storage, storage)
      cycler.instance_variable_set(:@packages_to_remove, [pkg_a, pkg_b, pkg_c])
      pkg_a.stubs(:no_cycle)
      pkg_b.stubs(:no_cycle)
      pkg_c.stubs(:no_cycle)
    end

    it 'should call the @storage to remove the old packages' do
      storage.expects(:remove!).in_sequence(s).with(pkg_a)
      storage.expects(:remove!).in_sequence(s).with(pkg_b)
      storage.expects(:remove!).in_sequence(s).with(pkg_c)
      cycler.send(:remove_packages!)
    end

    it 'should skip packages marked as no_cycle' do
      pkg_a.stubs(:no_cycle).returns(nil)
      pkg_b.stubs(:no_cycle).returns(true)
      pkg_c.stubs(:no_cycle).returns(false)

      storage.expects(:remove!).with(pkg_a)
      storage.expects(:remove!).with(pkg_b).never
      storage.expects(:remove!).with(pkg_c)
      cycler.send(:remove_packages!)
    end

    context 'when errors occur removing packages' do
      before do
        pkg_b.stubs(:trigger).returns('pkg_trigger')
        pkg_b.stubs(:time).returns('pkg_time')
        pkg_b.stubs(:filenames).returns(['file1', 'file2'])
      end

      it 'should warn and continue' do
        storage.expects(:remove!).in_sequence(s).with(pkg_a)
        storage.expects(:remove!).in_sequence(s).with(pkg_b).raises('error message')
        Backup::Logger.expects(:warn).with do |err|
          err.should be_an_instance_of Backup::Storage::Cycler::Error
          err.message.should include(
            "There was a problem removing the following package:\n" +
            "  Trigger: pkg_trigger :: Dated: pkg_time\n" +
            "  Package included the following 2 file(s):\n" +
            "  file1\n" +
            "  file2"
          )
          err.message.should match('RuntimeError: error message')
        end
        storage.expects(:remove!).in_sequence(s).with(pkg_c)

        cycler.send(:remove_packages!)
      end
    end

  end # describe '#remove_packages!'

  describe '#storage_file' do
    before do
      cycler.instance_variable_set(:@storage, storage)
      storage.stubs(:class).returns('Backup::Storage::S3')
      cycler.instance_variable_set(:@package, package)
      package.stubs(:trigger).returns('pkg_trigger')
    end

    context 'when the @storage.storage_id is not set' do
      before { storage.stubs(:storage_id).returns(nil) }
      it 'returns the path to the YAML storage file with no suffix' do
        cycler.send(:storage_file).should ==
            File.join(Backup::Config.data_path, 'pkg_trigger', 'S3.yml')
      end
    end

    context 'when the @storage.storage_id is set' do
      before { storage.stubs(:storage_id).returns('my_id') }
      it 'appends the storage_id to the filename' do
        cycler.send(:storage_file).should ==
            File.join(Backup::Config.data_path, 'pkg_trigger', 'S3-my_id.yml')
      end
    end

  end # describe '#storage_file'

  describe '#yaml_load' do
    let(:obj_a) { mock }
    let(:obj_b) { mock }
    let(:obj_c) { mock }
    let(:unsorted_objects)  { [obj_a, obj_c, obj_b] }
    let(:sorted_objects)    { [obj_c, obj_b, obj_a] }

    before do
      cycler.instance_variable_set(:@storage_file, storage_file)
      obj_a.instance_variable_set(:@time, '2012.01.01.07.00.00')
      obj_b.instance_variable_set(:@time, '2012.01.01.08.00.00')
      obj_c.instance_variable_set(:@time, '2012.01.01.09.00.00')
    end

    context 'when the storage file exists' do
      before { File.expects(:exist?).with(storage_file).returns(true) }
      context 'when the file is not empty' do
        before { File.expects(:zero?).with(storage_file).returns(false) }
        it 'should return YAML deserialized objects in an array, sorted by time DESC' do
          YAML.expects(:load_file).with(storage_file).returns(unsorted_objects)
          cycler.expects(:check_upgrade).with(sorted_objects).returns(sorted_objects)
          cycler.send(:yaml_load).should be(sorted_objects)
        end
      end
      context 'when the file is empty' do
        before { File.expects(:zero?).with(storage_file).returns(true) }
        it 'should return an empty array' do
          cycler.send(:yaml_load).should == []
        end
      end
    end

    context 'when the storage file does not exist' do
      before { File.expects(:exist?).with(storage_file).returns(false) }
      it 'should return an empty array' do
        cycler.send(:yaml_load).should == []
      end
    end
  end # describe '#yaml_load'

  describe '#yaml_save' do
    let(:file) { mock }
    let(:pkgs) { [ [1, 2, 3], [4, 5, 6] ] }
    let(:pkgs_to_yaml) { pkgs.to_yaml }
    let(:storage_file) { '/path/to/data_path/trigger/file.yml' }

    it 'should save the given packages to the storage file in YAML format' do
      cycler.instance_variable_set(:@storage_file, storage_file)

      FileUtils.expects(:mkdir_p).with('/path/to/data_path/trigger')
      File.expects(:open).with(storage_file, 'w').yields(file)
      file.expects(:write).with(pkgs_to_yaml)
      cycler.send(:yaml_save, pkgs)
    end
  end # describe '#yaml_save'

  describe '#check_upgrade' do
    let(:yaml_v3_0_19) do
      <<-EOF.gsub(/^ +/,'  ').gsub(/^  (-\W\W)/, "\\1")
        ---
        - !ruby/object:Backup::Storage::Local
          time: 2011.11.01.12.01.00
          remote_file: 2011.11.01.12.01.00.backup.tar.gz
        - !ruby/object:Backup::Storage::Local
          time: 2011.11.01.12.02.00
          remote_file: 2011.11.01.12.02.00.backup.tar.gz
        - !ruby/object:Backup::Storage::Local
          time: 2011.11.01.12.03.00
          remote_file: 2011.11.01.12.03.00.backup.tar.gz
      EOF
    end
    let(:yaml_v3_0_20) do
      <<-EOF.gsub(/^ +/,'  ').gsub(/^  (-\W\W)/, "\\1")
        ---
        - !ruby/object:Backup::Storage::Local
          time: 2011.12.01.12.01.00
          chunk_suffixes: []
          filename: 2011.12.01.12.01.00.backup.tar.gz
          version: 3.0.20
        - !ruby/object:Backup::Storage::Local
          time: 2011.12.01.12.02.00
          chunk_suffixes: []
          filename: 2011.12.01.12.02.00.backup.tar.gz
          version: 3.0.20
        - !ruby/object:Backup::Storage::Local
          time: 2011.12.01.12.03.00
          chunk_suffixes:
          - aa
          - ab
          filename: 2011.12.01.12.03.00.backup.tar.gz
          version: 3.0.20
      EOF
    end

    before do
      model = Backup::Model.new('foo', 'foo')
      cycler.instance_variable_set(:@storage, storage)
      storage.instance_variable_set(:@model, model)
    end

    it 'should upgrade v3.0.20 objects' do
      objects = YAML.load(yaml_v3_0_20)
      packages = cycler.send(:check_upgrade, objects)

      packages.all? {|pkg| pkg.is_a? Backup::Package }.should be_true
      packages.all? {|pkg| pkg.extension == 'tar.gz' }.should be_true

      packages[0].time.should == '2011.12.01.12.01.00'
      packages[0].chunk_suffixes.should == []
      packages[1].time.should == '2011.12.01.12.02.00'
      packages[1].chunk_suffixes.should == []
      packages[2].time.should == '2011.12.01.12.03.00'
      packages[2].chunk_suffixes.should == ['aa', 'ab']
    end

    it 'should upgrade v3.0.19 objects' do
      objects = YAML.load(yaml_v3_0_19)
      packages = cycler.send(:check_upgrade, objects)

      packages.all? {|pkg| pkg.is_a? Backup::Package }.should be_true
      packages.all? {|pkg| pkg.extension == 'tar.gz' }.should be_true
      packages.all? {|pkg| pkg.chunk_suffixes == []  }.should be_true

      packages[0].time.should == '2011.11.01.12.01.00'
      packages[1].time.should == '2011.11.01.12.02.00'
      packages[2].time.should == '2011.11.01.12.03.00'
    end
  end # describe '#check_upgrade'

end
