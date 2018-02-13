require 'find'
require 'open3'
require 'shellwords'
require 'zip'
require 'zip/filesystem'

class AppPackager
  DIRECTORY_DELETE_BATCH_SIZE = 100

  attr_reader :path

  def initialize(zip_path)
    @path = zip_path
  end

  def unzip(destination_dir)
    raise CloudController::Errors::ApiError.new_from_details('AppBitsUploadInvalid', 'Destination does not exist') unless File.directory?(destination_dir)
    raise CloudController::Errors::ApiError.new_from_details('AppBitsUploadInvalid', 'Symlink(s) point outside of root folder') if any_unsafe_symlinks?(destination_dir)

    output, error, status = Open3.capture3(
      %(unzip -qq -n #{Shellwords.escape(@path)} -d #{Shellwords.escape(destination_dir)})
    )

    unless status.success?
      raise CloudController::Errors::ApiError.new_from_details('AppPackageInvalid',
        "Unzipping had errors\n STDOUT: \"#{output}\"\n STDERR: \"#{error}\"")
    end
  end

  def append_dir_contents(additional_contents_dir)
    unless empty_directory?(additional_contents_dir)
      stdout, error, status = Open3.capture3(
        %(zip -q -r --symlinks #{Shellwords.escape(@path)} .),
        chdir: additional_contents_dir,
      )

      unless status.success?
        raise CloudController::Errors::ApiError.new_from_details('AppPackageInvalid',
          "Could not zip the package\n STDOUT: \"#{stdout}\"\n STDERR: \"#{error}\"")
      end
    end
  end

  def fix_subdir_permissions
    remove_dirs_from_zip(@path, get_dirs_from_zip(@path))
  rescue Zip::Error
    invalid_zip!
  end

  def size
    Zip::File.open(@path) do |in_zip|
      in_zip.reduce(0) { |memo, entry| memo + entry.size }
    end
  rescue Zip::Error
    invalid_zip!
  end

  private

  def get_dirs_from_zip(zip_path)
    Zip::File.open(zip_path) do |in_zip|
      in_zip.select(&:directory?)
    end
  end

  def remove_dirs_from_zip(zip_path, dirs_from_zip)
    dirs_from_zip.each_slice(DIRECTORY_DELETE_BATCH_SIZE) do |directory_slice|
      remove_dir(zip_path, directory_slice)
    end
  end

  def remove_dir(zip_path, directories)
    directory_arg_list    = directories.map { |dir| Shellwords.escape(dir) }.join(' ')
    stdout, error, status = Open3.capture3(
      %(zip -d #{Shellwords.escape(zip_path)}) + ' -- ' + directory_arg_list
    )

    unless status.success?
      raise CloudController::Errors::ApiError.new_from_details('AppPackageInvalid',
        "Could not remove the directories\n STDOUT: \"#{stdout}\"\n STDERR: \"#{error}\"")
    end
  end

  def any_unsafe_symlinks?(destination_dir)
    Zip::File.open(@path) do |in_zip|
      in_zip.any? { |entry| symlink?(entry) && is_unsafe_symlink?(destination_dir, in_zip, entry) }
    end
  rescue Zip::Error
    invalid_zip!
  end

  def is_unsafe_symlink?(destination_dir, in_zip, entry)
    # All bets are off if there's a symlink sitting outside the zipfile root
    return true if !safe_path?(entry.name, destination_dir)

    target_path = in_zip.file.read(entry.name)
    parent_dir = entry.parent_as_string
    if parent_dir
      # This code handles the case where the link and the target can both be relative,
      # and it calculates the actual final location of the target.

      base_dir = File.expand_path(parent_dir, destination_dir)
      final_path = File.expand_path(target_path, base_dir)
    else
      # parent_dir is nil when the link and target are in the same directory
      final_path = File.expand_path(target_path, destination_dir)
    end
    !final_path.starts_with?(destination_dir)
  end

  def symlink?(entry)
    entry.ftype == :symlink
  end

  def safe_path?(path, destination_dir)
    VCAP::CloudController::FilePathChecker.safe_path?(path, destination_dir)
  end

  def empty_directory?(dir)
    (Dir.entries(dir) - %w(.. .)).empty?
  end

  def invalid_zip!
    raise CloudController::Errors::ApiError.new_from_details('AppBitsUploadInvalid', 'Invalid zip archive.')
  end
end
