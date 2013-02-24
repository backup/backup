# encoding: utf-8

require File.expand_path('../spec_helper.rb', __FILE__)

module Backup
describe Dependency do
  let(:dep_a) {
    Dependency.new('dep-a', {
      :require => 'dep/a',
      :version => '~> 1.2.3',
      :for     => 'Provides A'
    })
  }
  let(:dep_b) {
    Dependency.new('dep-b', {
      :require => 'dep/b',
      :version => ['>= 2.1.0', '<= 2.5.0'],
      :for     => 'Provides B'
    })
  }
  let(:dep_c) {
    Dependency.new('dep-c', {
      :require => 'dep/c',
      :version => '~> 3.4.5',
      :for     => 'Provides C',
      :dependencies => 'dep-a'
    })
  }
  let(:s) { sequence '' }

  before do
    Dependency.stubs(:all).returns([dep_a, dep_b, dep_c])
  end

  describe '.find' do
    it 'finds a dependency by name' do
      expect( Dependency.find('dep-b') ).to be(dep_b)
    end

    it 'returns nil when name is not found' do
      expect( Dependency.find('foo') ).to be_nil
    end
  end

  describe '.load' do
    it 'should find and load the named dependency' do
      dep_b.expects(:load!)
      Dependency.load('dep-b')
    end
  end

  describe '#initialize' do
    it 'creates a new dependency from a name and options' do
      expect( dep_c.name          ).to eq 'dep-c'
      expect( dep_c.require_as    ).to eq 'dep/c'
      expect( dep_c.requirements  ).to eq ['~> 3.4.5']
      expect( dep_c.used_for      ).to eq 'Provides C'
      expect( dep_c.dependencies  ).to eq [dep_a]
    end
  end

  describe '#load!' do
    it 'should load and require given dependency' do
      dep_a.expects(:gem).with('dep-a', '~> 1.2.3')
      dep_a.expects(:require).with('dep/a')
      dep_a.load!
    end

    it 'should accept multiple version requirements' do
      dep_b.expects(:gem).with('dep-b', '>= 2.1.0', '<= 2.5.0')
      dep_b.expects(:require).with('dep/b')
      dep_b.load!
    end

    it 'should load prerequisite gems first' do
      dep_a.expects(:gem).in_sequence(s).with('dep-a', '~> 1.2.3')
      dep_a.expects(:require).in_sequence(s).with('dep/a')

      dep_c.expects(:gem).in_sequence(s).with('dep-c', '~> 3.4.5')
      dep_c.expects(:require).in_sequence(s).with('dep/c')

      dep_c.load!
    end

    it 'raises an error if the dependency fails to load' do
      dep_b.expects(:gem).with('dep-b', '>= 2.1.0', '<= 2.5.0').raises(LoadError)

      expect do
        dep_b.load!
      end.to raise_error(Errors::Dependency::LoadError) {|err|
        expect( err.message ).to eq(
          "Dependency::LoadError: Dependency Missing\n" +
          "  Gem Name: dep-b\n" +
          "  Used for: Provides B\n" +
          "  \n" +
          "  To install the gem, issue the following command:\n" +
          "  > backup dependencies --install dep-b\n" +
          "  Please try again after installing the missing dependency."
        )
      }
    end

    it 'raises an error if a dependency of the dependency fails to load' do
      dep_a.expects(:gem).with('dep-a', '~> 1.2.3').raises(LoadError)

      expect do
        dep_c.load!
      end.to raise_error(Errors::Dependency::LoadError) {|err|
        expect( err.message ).to eq(
          "Dependency::LoadError: Dependency Missing\n" +
          "  Gem Name: dep-a\n" +
          "  Used for: Provides A\n" +
          "  \n" +
          "  To install the gem, issue the following command:\n" +
          "  > backup dependencies --install dep-a\n" +
          "  Please try again after installing the missing dependency."
        )
      }
    end
  end # describe '#load!'

  describe '#installed?' do
    it 'returns true if the dependency is installed' do
      Gem::Specification.expects(:find_by_name).
          with('dep-b', '>= 2.1.0', '<= 2.5.0').returns(:a_spec)

      expect( dep_b.installed? ).to be(true)
    end

    it 'returns false if the dependency is not installed' do
      Gem::Specification.expects(:find_by_name).
          with('dep-b', '>= 2.1.0', '<= 2.5.0').raises(LoadError)

      expect( dep_b.installed? ).to be(false)
    end
  end

  describe '#install!' do
    before do
      require 'rubygems/dependency_installer'
      Gem::DependencyInstaller.expects(:new).never
    end

    context 'when multiple version requirements are defined' do
      it 'finds the version matching all requirements' do
        inst, spec = mock, mock
        Gem::DependencyInstaller.expects(:new).returns(inst)
        inst.expects(:find_spec_by_name_and_version).
            with('dep-b', '>= 2.1.0', '<= 2.5.0').returns([[spec, 'some_uri']])
        spec.expects(:version).returns('2.4.0')

        command = "gem install --no-ri --no-rdoc dep-b -v '2.4.0'"
        dep_b.expects(:puts).with("\nLaunching `#{ command }`")
        dep_b.expects(:exec).with(command)

        dep_b.install!
      end

      it 'uses last requirement if errors occur' do
        Gem::DependencyInstaller.expects(:new).raises('an error')

        command = "gem install --no-ri --no-rdoc dep-b -v '<= 2.5.0'"
        dep_b.expects(:puts).with("\nLaunching `#{ command }`")
        dep_b.expects(:exec).with(command)

        dep_b.install!
      end
    end

    context 'when only a single version requirement is defined' do
      it 'installs the gem using the version requirement' do
        command = "gem install --no-ri --no-rdoc dep-a -v '~> 1.2.3'"
        dep_a.expects(:puts).with("\nLaunching `#{ command }`")
        dep_a.expects(:exec).with(command)

        dep_a.install!
      end
    end
  end # describe '#install!'
end
end
