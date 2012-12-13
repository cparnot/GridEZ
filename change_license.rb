#! /usr/bin/ruby

root_dir = File.dirname(File.expand_path(__FILE__))
puts "root dir: #{root_dir}"

license = File.read("#{root_dir}/LICENSE-BSD.txt")
license = "__BEGIN_LICENSE_GRIDEZ__\nThis file is part of \"GridEZ.framework\". #{license}__END_LICENSE__"
puts "new license:\n#{license}"

def scan_dir(dir_path, new_license)
  Dir.foreach(dir_path) do |entry|
    next if entry =~ /^\./
    entry_path = "#{dir_path}/#{entry}"
    if File.directory?(entry_path)
      scan_dir(entry_path, new_license)
    elsif entry=~ /\.[mh]$/
      puts "modifying license for file: #{entry_path}"
      file_contents = File.read(entry_path)
      file_contents.gsub!(/__BEGIN_LICENSE_GRIDEZ__.*__END_LICENSE__/m, new_license)
      File.open(entry_path, 'w') { |fileio| fileio.write file_contents }
    end
  end
end

scan_dir(root_dir, license)