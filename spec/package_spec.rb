# encoding: utf-8

require File.expand_path('../spec_helper.rb', __FILE__)

module Backup
describe Package do
  let(:model)   { Model.new(:test_trigger, 'test label') }
  let(:package) { Package.new(model) }

  describe '#initialize' do
    it 'sets defaults' do
      expect( package.time            ).to be_nil
      expect( package.trigger         ).to eq 'test_trigger'
      expect( package.extension       ).to eq 'tar'
      expect( package.chunk_suffixes  ).to eq []
      expect( package.no_cycle        ).to be(false)
      expect( package.version         ).to eq VERSION
    end
  end

  it 'allows time to be set' do
    package.time = 'foo'
    expect( package.time ).to eq 'foo'
  end

  it 'allows chunk_suffixes to be set' do
    package.chunk_suffixes = 'foo'
    expect( package.chunk_suffixes ).to eq 'foo'
  end

  it 'allows extension to be updated' do
    package.extension << '.foo'
    expect( package.extension ).to eq 'tar.foo'

    package.extension = 'foo'
    expect( package.extension ).to eq 'foo'
  end

  it 'allows no_cycle to be set' do
    package.no_cycle = true
    expect( package.no_cycle ).to be(true)
  end

  describe '#filenames' do
    context 'when the package files were not split' do
      it 'returns an array with the single package filename' do
        expect( package.filenames ).to eq ['test_trigger.tar']
      end

      it 'reflects changes in the extension' do
        package.extension << '.enc'
        expect( package.filenames ).to eq ['test_trigger.tar.enc']
      end
    end

    context 'when the package files were split' do
      before { package.chunk_suffixes = ['aa', 'ab'] }

      it 'returns an array of the package filenames' do
        expect( package.filenames ).to eq(
          ['test_trigger.tar-aa', 'test_trigger.tar-ab']
        )
      end

      it 'reflects changes in the extension' do
        package.extension << '.enc'
        expect( package.filenames ).to eq(
          ['test_trigger.tar.enc-aa', 'test_trigger.tar.enc-ab']
        )
      end
    end
  end

  describe '#basename' do
    it 'returns the base filename for the package' do
      expect( package.basename ).to eq 'test_trigger.tar'
    end

    it 'reflects changes in the extension' do
      package.extension << '.enc'
      expect( package.basename ).to eq 'test_trigger.tar.enc'
    end
  end

end
end
