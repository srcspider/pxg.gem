# native
require 'Logger'
require 'fileutils'

# gems
require 'git'
require 'json'

class Pxg

	VERSION = '1.1.4'

	def reimage(argv)
		xml = argv[0]
		new_images = argv[1]
		text = File.read new_images
		text.strip!
		image_urls = text.split "\n"
		# read xml
		xml_data = File.read xml
		# eg image: http://pixelgrade.com/demos/bucket/wp-content/uploads/2013/10/kelly-brooks.jpg
		# locate all images
		rimages = xml_data.scan /(http(s){0,1}:\/\/[^"<>]*\/[0-9]{4}\/[0-9]{2}\/[^"<>]+\.(jpg|jpeg|png|tiff|gif|webp))/
		targets = []
		rimages.each do |arr|
			match_data = arr[0].match /(http(s){0,1}:\/\/[^"<>]*\/)([0-9]{4}\/[0-9]{2}\/[^"<>]+\.(jpg|jpeg|png|tiff|gif|webp))/
			targets.push([match_data[0], match_data[1], arr[0].gsub(match_data[1], '')])
		end#each

		targets.each do |img|
			random_image = image_urls.sample.split ' '
			xml_data.gsub! img[0], random_image[1]
			xml_data.gsub! img[2], img[2][0..7] + random_image[0]
		end#each

		# split xml in parts
		parts1 = xml_data.split '</generator>';
		opening = parts1[0] + '</generator>'
		parts2 = parts1[1].split '</channel>'
		ending = '</channel>' + parts2[1]
		items = parts2[0];

		# split items into item array
		clean_items = ''
		association = {}
		corrections = {}
		ids = [];

		guid_regex = /<guid isPermaLink=\"false\">(http(s){0,1}:\/\/[^"<>]+\.(jpg|jpeg|png|tiff|gif|webp))<\/guid>/m
		id_regex = /<wp:post_id>([0-9]+)<\/wp:post_id>/m

		items.split('</item>').each do |itemstr|
			if itemstr =~ guid_regex
				matches = itemstr.match guid_regex
				idmatch = itemstr.match id_regex
				if ! association.has_key? matches[0]
					association[matches[0]] = idmatch[1]
					itemstr = itemstr + '</item>'
				else # already associated
					corrections[idmatch[1]] = association[matches[0]]
					itemstr = ''
				end#if
			else # not image attachment
				corrections.each do |oldid, newid|
					regex_str = "<wp:meta_key>_thumbnail_id<\/wp:meta_key>\\s*<wp:meta_value><\\!\\[CDATA\\[#{oldid}\\]\\]></wp:meta_value>"
					search_regex = Regexp.new regex_str
					itemstr = itemstr.sub search_regex, "<wp:meta_key>_thumbnail_id</wp:meta_key>\n\t\t\t<wp:meta_value><![CDATA[#{newid}]]></wp:meta_value>"
				end#each
				itemstr = itemstr + '</item>'
			end#if
			clean_items = clean_items + itemstr;
		end#each

		puts opening + clean_items + ending
	end#def

	def find_and_replace(path, search, replace)
		clean_path = path.sub(/(\/)+$/, '') + '/'
		Dir.glob "#{clean_path}**/*.php" do |file|
			next if file == '.' or file == '..'
			text = File.read file
			text = text.gsub search, replace
			File.write file, text
		end#glob
	end#def

	def ensure_copy(rawsrcpath, rawlocalpath, rawthemepath)
		srcpath = File.expand_path(rawsrcpath) + '/'
		localpath = File.expand_path(rawlocalpath) + '/'
		themepath = File.expand_path(rawthemepath) + '/'
		Dir.glob "#{srcpath}**/*" do |file|
			next if file == '.' or file == '..'
			filepath = File.expand_path(file)
			filesubpath = filepath.sub srcpath, ''
			localfilepath = localpath + filesubpath
			if ! File.exists? localfilepath
				localfilesubpath = localfilepath.sub themepath, ''
				puts "   - #{localfilesubpath}"
				text = File.read filepath
				FileUtils.mkpath File.dirname(localfilepath)
				File.write localfilepath, text
			end#if
		end#glob
	end#def

	def force_copy(filepaths, rawsrcpath, rawlocalpath, rawthemepath)
		srcpath = File.expand_path(rawsrcpath) + '/'
		localpath = File.expand_path(rawlocalpath) + '/'
		themepath = File.expand_path(rawthemepath) + '/'
		Dir.glob("#{srcpath}**/*", File::FNM_DOTMATCH) do |file|
			next if file == '.' or file == '..'
			filepath = File.expand_path(file)
			filesubpath = filepath.sub srcpath, ''
			if filepaths.include? filesubpath

				localfilepath = localpath + filesubpath
				localfilesubpath = localfilepath.sub themepath, ''
				text = File.read filepath
				updatefile = false

				if File.exists? localfilepath
					localtext = File.read localfilepath
					if ! localtext.eql? text
						updatefile = true
					end#if
				else # file does not exist
					updatefile = true
				end#if

				if updatefile
					puts "   - #{localfilesubpath}"
					FileUtils.mkpath File.dirname(localfilepath)
					File.write localfilepath, text
				end#if

			end#if
		end#glob
	end#def

	def wp_core(path, conf)
		Dir.chdir path
		themepath = path.sub(/(\/)+$/, '') + '/'
		core_path = conf['path'].sub(/(\/)+$/, '')

		puts "  processing #{core_path}"
		# remove the core if it exists
		FileUtils.rm_rf core_path
		# clone a fresh copy
		puts "  cloning #{conf['repo']} -> #{conf['version']}"
		g = Git.clone conf['repo'], core_path
		g.checkout conf['version']
		FileUtils.rm_rf core_path+'/.git'

		# refactor name space
		if conf.has_key? 'namespace'
			ns_src = conf['namespace']['src']
			ns_target = conf['namespace']['target']
			puts "  refactoring #{core_path}"
			self.find_and_replace core_path, ns_src, ns_target
			self.find_and_replace core_path, ns_src.capitalize, ns_target.capitalize
		end#if

		# ensure partials
		if conf.has_key? 'partials'
			partials_src = core_path + '/' + conf['partials']['src']
			partials_local = themepath + conf['partials']['local']
			puts "  ensuring copy of system partials"
			self.ensure_copy partials_src, partials_local, themepath
		end#if

		# ensure behavior tests
		if conf.has_key? 'features'
			features_src = core_path + '/' + conf['features']['src']
			features_local = themepath + conf['features']['local']
			if conf['features'].has_key? 'ensure'
				rawfilenames = conf['features']['ensure']
				filenames = []
				rawfilenames.each do |file|
					filenames.push (file + '.feature')
				end#each
				puts "  ensuring latest copy of active feature tests"
				self.force_copy filenames, features_src, features_local, themepath
			end#if
		end#if

	end#def

	def compile(args)
		if args.length != 0
			dirpath = args[0].sub(/(\/)+$/,'')+'/'
		else # no parameters, assume .
			dirpath = './'
		end

		if ! File.exist? dirpath
			puts '  Err: target directory does not exist.'
			return;
		end

		jsonconfigfile = dirpath+'pxg.json'
		if ! File.exist? jsonconfigfile
			puts '  Err: Missing pxg.json file in target directory.'
			return;
		end

		conf = JSON.parse(open(jsonconfigfile).read)
		conf_interface = '1.0.0'

		# ensure pxg.json interface isn't newer
		pxgi = Pxg::VERSION.split '.'
		jsoni = conf_interface.split '.'

		if jsoni[0] != pxgi[0]
			self.failed_version_check conf_interface
		else # major versions are equal
			if jsoni[1] > pxgi[1]
				# ie. json requires extra features
				self.failed_version_check conf_interface
			elsif jsoni[1] == pxgi[1] && jsoni[2] > pxgi[2]
				# ie. potential problems with bugfix'es
				self.failed_version_check conf_interface
			end#if
		end#if

		conf['wp-cores'].each do |wpcoreconf|
			self.wp_core dirpath, wpcoreconf
		end#each

		puts ""
		puts "  fin"
	end#def

	def version(args)
		puts "  #{Pxg::VERSION}"
	end#def

	def failed_version_check(interface)
		puts "  Err: Incompatible versions: pxg.json @ #{interface} but pxg.gem @ #{Pxg::VERSION}"
	end#def

end#class