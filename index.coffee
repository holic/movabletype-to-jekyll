path = require "path"
url = require "url"
fs = require "fs-extra"
glob = require "glob"
moment = require "moment"
eco = require "eco"
{toMarkdown} = require "to-markdown"
request = require "request"


authors =
	paul: "Paul"
	timo: "Timo"
	norbu09: "Lenz"
	owen: "Owen"
	chall: "Chris"
	manu: "Manu"


template = fs.readFileSync "#{__dirname}/post.yml.eco", "utf8"


input = path.join __dirname, "in"
output = path.join __dirname, "out"

fs.removeSync output
fs.mkdirSync output


files = glob.sync path.join input, "*.txt"
for file in files

	source = fs.readFileSync file, "utf8"
	continue unless source.length

	basename = path.basename file, ".txt"
	target = path.join output, basename
	_posts = path.join target, "_posts"
	_drafts = path.join target, "_drafts"
	images = path.join target, "images"
	fs.mkdirsSync _posts
	fs.mkdirsSync _drafts
	fs.mkdirsSync images

	posts = source.split "--------\n"
	for post in posts
		
		sections = post.split "-----\n"
		continue if sections.length < 3

		[properties, body] = sections

		meta = {}
		body = body.replace /BODY\:\n/, ""
		body = body.replace /(^\s+|\s+$)/, ""

		for property in properties.match /[A-Z ]+\: .+/g
			[name, rest...] = property.split ": "
			value = rest.join ": "

			addCategory = (method, category) ->
				meta.categories ?= []
				index = meta.categories.indexOf category
				meta.categories.splice index, 1 if index > -1
				meta.categories[method] category
			
			switch name
				when "AUTHOR"
					meta.author = authors[value] or value
				when "TITLE"
					if /[':]/.test value
						meta.title = "\"#{value}\""
					else
						meta.title = value
				when "BASENAME"
					meta.slug = value.replace /_/g, "-"
				when "STATUS"
					meta.published = value is "Publish"
				when "DATE"
					meta.date = moment value, "MM/DD/YYYY hh:mm:ss A"
					meta.date_string = meta.date.format "YYYY-MM-DD HH:mm:ss"
					meta.date_filename = meta.date.format "YYYY-MM-DD"
				when "TAGS"
					meta.tags = value.match(/(["]?).*?\1(?=,|$)/g)
						.map((tag) -> tag.replace /^"(.*)"$/, "$1")
						.filter((tag) -> tag.length)
				when "PRIMARY CATEGORY"
					addCategory "unshift", value
				when "CATEGORY"
					addCategory "push", value

		meta.original_url = "https://#{basename}/blog/#{meta.date.format "YYYY/MM"}/#{meta.slug}.html"

		if basename is "iwantmyname.co.nz"
			meta.tags or= []
			meta.tags.unshift "New Zealand", "local"
			addCategory "unshift", "New Zealand"

		# convert HTML to markdown and clean up
		markdown = toMarkdown body
		markdown = markdown.replace /<div>([\w\W]*?)<\/div>/g, "$1"
		markdown = markdown.replace "&nbsp;", " "

		# find images, download to local directory
		matches = markdown.match /\!\[[^\]]*?\]\(([^\) ]+)/g
		if matches then matches.forEach (match) ->
			[_, src] = match.match /\!\[[^\]]*?\]\(([^\) ]+)/
			{pathname} = url.parse src

			imageName = "#{meta.date_filename}-#{path.basename pathname}"
			markdown = markdown.replace match, match.replace src, "{{ site.images_url }}/#{imageName}"

			done = ->
				console.log "Downloaded #{src}"

			request(src, done).pipe fs.createWriteStream path.join images, imageName

		filename = path.join (if meta.published then _posts else _drafts), "#{meta.date_filename}-#{meta.slug}.md"
		compiled = eco.render template, {meta, body, markdown}
		fs.writeFileSync filename, compiled


