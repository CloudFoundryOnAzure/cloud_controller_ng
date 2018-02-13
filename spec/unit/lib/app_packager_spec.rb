require 'spec_helper'
require 'cloud_controller/app_packager'

RSpec.describe AppPackager do
  around do |example|
    Dir.mktmpdir('app_packager_spec') do |tmpdir|
      @tmpdir = tmpdir
      example.call
    end
  end

  subject(:app_packager) { AppPackager.new(input_zip) }

  describe '#size' do
    let(:input_zip) { File.join(Paths::FIXTURES, 'good.zip') }
    let(:size_of_good_zip) { 17 }

    it 'returns the sum of each file size' do
      expect(app_packager.size).to eq(size_of_good_zip)
    end
  end

  describe '#unzip' do
    let(:input_zip) { File.join(Paths::FIXTURES, 'good.zip') }

    it 'unzips the file given' do
      app_packager.unzip(@tmpdir)

      expect(Dir["#{@tmpdir}/**/*"].size).to eq 4
      expect(Dir["#{@tmpdir}/*"].size).to eq 3
      expect(Dir["#{@tmpdir}/subdir/*"].size).to eq 1
    end

    context 'when the zip destination does not exist' do
      it 'raises an exception' do
        expect {
          app_packager.unzip(File.join(@tmpdir, 'blahblah'))
        }.to raise_exception(CloudController::Errors::ApiError, /destination does not exist/i)
      end
    end

    context 'when the zip is empty' do
      let(:input_zip) { File.join(Paths::FIXTURES, 'empty.zip') }

      it 'raises an exception' do
        expect {
          app_packager.unzip(@tmpdir)
        }.to raise_exception(CloudController::Errors::ApiError, /zipfile is empty/)
      end
    end

    describe 'relative paths' do
      context 'when the relative path does NOT leave the root directory' do
        let(:input_zip) { File.join(Paths::FIXTURES, 'good_relative_paths.zip') }

        it 'unzips the archive, ignoring ".."' do
          app_packager.unzip(@tmpdir)

          expect(File.exist?("#{@tmpdir}/bar/cat")).to be true
        end
      end

      context 'when the relative path does leave the root directory' do
        let(:input_zip) { File.join(Paths::FIXTURES, 'bad_relative_paths.zip') }

        it 'unzips the archive, ignoring ".."' do
          app_packager.unzip(@tmpdir)

          expect(File.exist?("#{@tmpdir}/fakezip.zip")).to be true
        end
      end
    end

    describe 'symlinks' do
      context 'when valid' do
        context 'when the zip contains a symlink that does not leave the root dir' do
          context 'simple express zips should be fine' do
            let(:input_zip) { File.join(Paths::FIXTURES, 'express-app-good.zip') }

            it 'unzips them correctly without errors' do
              app_packager.unzip(@tmpdir)

              expect(File.symlink?("#{@tmpdir}/express-app/node_modules/bin/mime")).to be true
              expect(File.exist?("#{@tmpdir}/express-app/node_modules/mime/cli.js")).to be true
              expect(File.exist?("#{@tmpdir}/express-app/node_modules/bin/mime")).to be true

              expect(File.symlink?("#{@tmpdir}/link-same-dir.txt")).to be true
              expect(File.readlink("#{@tmpdir}/link-same-dir.txt")).to eq('target2.txt')

              expect(File.symlink?("#{@tmpdir}/express-app/node_modules/bin/link-up-down.txt")).to be true
              expect(File.readlink("#{@tmpdir}/express-app/node_modules/bin/link-up-down.txt")).to eq '../mime/cli.js'

              expect(File.symlink?("#{@tmpdir}/express-app/node_modules/bin/link2-up-dirs.txt")).to be true
              expect(File.readlink("#{@tmpdir}/express-app/node_modules/bin/link2-up-dirs.txt")).to eq('../../target1.txt')

              expect(File.symlink?("#{@tmpdir}/express-app/link3-down-dirs.txt")).to be true
              expect(File.readlink("#{@tmpdir}/express-app/link3-down-dirs.txt")).to eq('node_modules/mime/cli.js')
            end
          end

          context 'symbolic links contain sub-parts that will be removed (like "../X/<MORE_DIRECTORIES>") ' do
            let(:input_zip) { File.join(Paths::FIXTURES, 'multi_dot_dot_symlinks.zip') }

            it 'unzips them correctly without errors' do
              app_packager.unzip(@tmpdir)
              expect(File.symlink?("#{@tmpdir}/a/b2/c23")).to be true
              expect(File.readlink("#{@tmpdir}/a/b2/c23")).to eq('../x1/../x2/../../a/x3/../b1/c13')
            end
          end
        end
      end

      context 'when invalid' do
        context 'when the zip contains a symlink that lives inside the zipfile root' do
          context 'when the the symlink points to a file out of the root dir' do
            context 'when the symlink is relative' do
              let(:input_zip) { File.join(Paths::FIXTURES, 'bad_symlinks.zip') }

              it 'raises an exception' do
                expect { app_packager.unzip(@tmpdir) }.to raise_exception(CloudController::Errors::ApiError, /symlink.+outside/i)
              end
            end

            context 'when the symlink is absolute' do
              let(:input_zip) { File.join(Paths::FIXTURES, 'absolute_symlink_out_of_parent.zip') }

              it 'raises an exception' do
                expect { app_packager.unzip(@tmpdir) }.to raise_exception(CloudController::Errors::ApiError, /symlink.+outside/i)
              end
            end
          end
        end

        context 'when the zip contains a symlink that lives outside the zipfile root' do
          context 'when the symlink points back into the zipfile root' do
            let(:input_zip) { File.join(Paths::FIXTURES, 'bad-symlink-lives-outside-ziproot-points-in.zip') }

            it 'raises an exception' do
              expect { app_packager.unzip(@tmpdir) }.to raise_exception(CloudController::Errors::ApiError, /symlink.+outside/i)
            end
          end

          context 'when the symlink points out of the zipfile root' do
            let(:input_zip) { File.join(Paths::FIXTURES, 'bad-symlink-lives-outside-ziproot-points-out.zip') }

            it 'raises an exception' do
              expect { app_packager.unzip(@tmpdir) }.to raise_exception(CloudController::Errors::ApiError, /symlink.+outside/i)
            end
          end
        end
      end
    end

    context 'when there is an error unzipping' do
      it 'raises an exception' do
        allow(Open3).to receive(:capture3).and_return(['output', 'error', double(success?: false)])
        expect {
          app_packager.unzip(@tmpdir)
        }.to raise_error(CloudController::Errors::ApiError, /The app package is invalid: Unzipping had errors/)
      end
    end
  end

  describe '#append_dir_contents' do
    let(:input_zip) { File.join(@tmpdir, 'good.zip') }
    let(:additional_files_path) { File.join(Paths::FIXTURES, 'fake_package') }

    before { FileUtils.cp(File.join(Paths::FIXTURES, 'good.zip'), input_zip) }

    it 'adds the files to the zip' do
      app_packager.append_dir_contents(additional_files_path)

      output = `zipinfo #{input_zip}`

      expect(output).not_to include './'
      expect(output).not_to include 'fake_package'

      expect(output).to match /^l.+coming_from_inside$/
      expect(output).to include 'here.txt'
      expect(output).to include 'subdir/'
      expect(output).to include 'subdir/there.txt'

      expect(output).to include 'bye'
      expect(output).to include 'hi'
      expect(output).to include 'subdir/'
      expect(output).to include 'subdir/greetings'

      expect(output).to include '7 files'
    end

    context 'when there are no additional files' do
      let(:additional_files_path) { File.join(@tmpdir, 'empty') }

      it 'results in the existing zip' do
        Dir.mkdir(additional_files_path)

        output = `zipinfo #{input_zip}`

        expect(output).to include 'bye'
        expect(output).to include 'hi'
        expect(output).to include 'subdir/'
        expect(output).to include 'subdir/greeting'

        expect(output).to include '4 files'

        app_packager.append_dir_contents(additional_files_path)

        output = `zipinfo #{input_zip}`

        expect(output).to include 'bye'
        expect(output).to include 'hi'
        expect(output).to include 'subdir/'
        expect(output).to include 'subdir/greeting'

        expect(output).to include '4 files'
      end
    end

    context 'when there is an error zipping' do
      it 'raises an exception' do
        allow(Open3).to receive(:capture3).and_return(['output', 'error', double(success?: false)])
        expect {
          app_packager.append_dir_contents(additional_files_path)
        }.to raise_error(CloudController::Errors::ApiError, /The app package is invalid: Could not zip the package/)
      end
    end
  end

  describe '#fix_subdir_permissions' do
    context 'when the zip has directories without the directory attribute or execute permission (it was created on windows)' do
      let(:input_zip) { File.join(@tmpdir, 'bad_directory_permissions.zip') }

      before { FileUtils.cp(File.join(Paths::FIXTURES, 'app_packager_zips', 'bad_directory_permissions.zip'), input_zip) }

      it 'deletes all directories from the archive' do
        app_packager.fix_subdir_permissions

        has_dirs = Zip::File.open(input_zip) do |in_zip|
          in_zip.any?(&:directory?)
        end

        expect(has_dirs).to be_falsey
      end
    end

    context 'when the zip has directories with special characters' do
      let(:input_zip) { File.join(@tmpdir, 'special_character_names.zip') }

      before { FileUtils.cp(File.join(Paths::FIXTURES, 'app_packager_zips', 'special_character_names.zip'), input_zip) }

      it 'successfully removes and re-adds them' do
        app_packager.fix_subdir_permissions
        expect(`zipinfo #{input_zip}`).to match %r(special_character_names/&&hello::\?\?/)
      end
    end

    context 'when there are many directories' do
      let(:input_zip) { File.join(@tmpdir, 'many_dirs.zip') }

      before { FileUtils.cp(File.join(Paths::FIXTURES, 'app_packager_zips', 'many_dirs.zip'), input_zip) }

      it 'batches the directory deletes so it does not exceed the max command length' do
        allow(Open3).to receive(:capture3).and_call_original
        batch_size = 10
        stub_const('AppPackager::DIRECTORY_DELETE_BATCH_SIZE', batch_size)

        app_packager.fix_subdir_permissions

        output = `zipinfo #{input_zip}`

        (0..20).each do |i|
          expect(output).to include("folder_#{i}/")
          expect(output).to include("folder_#{i}/empty_file")
        end

        number_of_batches = (21.0 / batch_size).ceil
        expect(number_of_batches).to eq(3)
        expect(Open3).to have_received(:capture3).exactly(number_of_batches).times
      end
    end

    context 'when there is an error deleting directories' do
      let(:input_zip) { File.join(@tmpdir, 'bad_directory_permissions.zip') }
      before { FileUtils.cp(File.join(Paths::FIXTURES, 'app_packager_zips', 'bad_directory_permissions.zip'), input_zip) }

      it 'raises an exception' do
        allow(Open3).to receive(:capture3).and_return(['output', 'error', double(success?: false)])
        expect {
          app_packager.fix_subdir_permissions
        }.to raise_error(CloudController::Errors::ApiError, /The app package is invalid: Could not remove the directories/)
      end
    end

    context 'when there is a zip error' do
      let(:input_zip) { 'garbage' }

      it 'raises an exception' do
        allow(Open3).to receive(:capture3).and_return(['output', 'error', double(success?: false)])
        expect {
          app_packager.fix_subdir_permissions
        }.to raise_error(CloudController::Errors::ApiError, /The app upload is invalid: Invalid zip archive./)
      end
    end
  end
end
