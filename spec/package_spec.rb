# encoding: utf-8

require File.expand_path('../spec_helper.rb', __FILE__)

describe Backup::Package do
  let(:model)   { Backup::Model.new(:test_trigger, 'test label') }
  let(:package) { Backup::Package.new(model) }

  before do
    model.instance_variable_set(:@time, 'model_time')
  end

  describe '#initialize' do
    it 'should set all variables' do
      package.time.should           == 'model_time'
      package.trigger.should        == 'test_trigger'
      package.extension.should      == 'tar'
      package.chunk_suffixes.should == []
      package.version.should        == Backup::Version.current
    end
  end

  describe '#filenames' do
    context 'when the package files were not split' do
      it 'should return an array with the single package filename' do
        package.filenames.should == ['model_time.test_trigger.tar']
      end

      it 'should reflect changes in the extension' do
        package.extension << '.enc'
        package.filenames.should == ['model_time.test_trigger.tar.enc']
      end
    end

    context 'when the package files were split' do
      before { package.chunk_suffixes = ['aa', 'ab'] }
      it 'should return an array of the package filenames' do
        package.filenames.should == ['model_time.test_trigger.tar-aa',
                                     'model_time.test_trigger.tar-ab']
      end

      it 'should reflect changes in the extension' do
        package.extension << '.enc'
        package.filenames.should == ['model_time.test_trigger.tar.enc-aa',
                                     'model_time.test_trigger.tar.enc-ab']
      end
    end
  end

  describe '#basename' do
    it 'should return the base filename for the package' do
      package.basename.should == 'model_time.test_trigger.tar'
    end

    it 'should reflect changes in the extension' do
      package.extension << '.enc'
      package.basename.should == 'model_time.test_trigger.tar.enc'
    end
  end

end
